import SwiftUI

/// Feuille d'ajout d'un raccourci (application, lien, ou raccourci Raccourcis).
///
/// Les applications proposées sont celles **réellement installées sur le Mac**,
/// pas une liste figée : une liste écrite en dur produit des boutons qui ne
/// lancent rien quand l'app n'est pas là.
struct AddShortcutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var mac: MacState

    enum Kind: String, CaseIterable {
        case app = "Application"
        case link = "Lien"
        case shortcut = "Raccourci"
    }

    let onAdd: (ShortcutItem) -> Void

    @State private var kind: Kind = .app
    @State private var search = ""
    @State private var name = ""
    @State private var url = ""
    @State private var shortcutName = ""

    private var filteredApps: [InstalledApp] {
        guard !search.isEmpty else { return mac.installedApps }
        return mac.installedApps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    /// Apps du Mac regroupées par catégorie du catalogue. Celles que le
    /// catalogue ne connaît pas atterrissent dans « Autres » — elles restent
    /// donc accessibles, on ne cache rien.
    private var grouped: [(category: String, icon: String, apps: [InstalledApp])] {
        var buckets: [String: [InstalledApp]] = [:]
        var icons: [String: String] = [:]

        for app in filteredApps {
            let category = AppCatalog.category(of: app.bundleID)
            let key = category?.rawValue ?? "Autres"
            icons[key] = category?.icon ?? "square.grid.2x2"
            buckets[key, default: []].append(app)
        }

        // L'ordre du catalogue d'abord, « Autres » en dernier.
        var ordered = AppCatalog.Category.allCases.compactMap { category -> (String, String, [InstalledApp])? in
            guard let apps = buckets[category.rawValue] else { return nil }
            return (category.rawValue, category.icon, apps)
        }
        if let others = buckets["Autres"] {
            ordered.append(("Autres", "square.grid.2x2", others))
        }
        return ordered.map { (category: $0.0, icon: $0.1, apps: $0.2) }
    }

    /// Apps connues du catalogue mais absentes du Mac : affichées grisées,
    /// pour expliquer pourquoi elles ne sont pas proposées.
    private var missing: [AppCatalog.Entry] {
        guard !mac.installedApps.isEmpty else { return [] }
        let absent = AppCatalog.missing(among: mac.installedApps)
        guard !search.isEmpty else { return absent }
        return absent.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch kind {
                case .app:      appList
                case .link:     linkForm
                case .shortcut: shortcutForm
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Type", selection: $kind) {
                    ForEach(Kind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .navigationTitle("Nouveau raccourci")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        .onAppear {
            // La liste vient du Mac : on la demande à l'ouverture.
            connection.send(.installedRequest())
        }
    }

    // MARK: - Applications du Mac

    private var appList: some View {
        List {
            if mac.installedApps.isEmpty {
                ContentUnavailableView {
                    Label("Applications non chargées", systemImage: "desktopcomputer.trianglebadge.exclamationmark")
                } description: {
                    Text(connection.pairingState == .paired
                         ? "La liste arrive du Mac, patientez un instant."
                         : "Connectez-vous à votre Mac pour voir ses applications.")
                }
            } else {
                ForEach(grouped, id: \.category) { group in
                    Section {
                        ForEach(group.apps) { app in
                            Button {
                                add(ShortcutItem(name: app.name,
                                                 action: "launch",
                                                 target: app.bundleID,
                                                 shortcutName: nil,
                                                 icon: AppCatalog.entries
                                                     .first { $0.bundleID == app.bundleID }?.icon ?? "app.fill"))
                            } label: {
                                HStack(spacing: 12) {
                                    AppIcon(base64: app.iconBase64)
                                        .frame(width: 30, height: 30)
                                    Text(app.name)
                                    Spacer()
                                    if app.isRunning {
                                        Circle().fill(.green).frame(width: 6, height: 6)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    } header: {
                        Label("\(group.category) · \(group.apps.count)", systemImage: group.icon)
                    }
                }

                if !missing.isEmpty {
                    Section {
                        ForEach(missing) { entry in
                            HStack(spacing: 12) {
                                Image(systemName: entry.icon)
                                    .frame(width: 30)
                                    .foregroundStyle(.tertiary)
                                Text(entry.name)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("non installée")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } header: {
                        Label("Absentes de ce Mac", systemImage: "questionmark.app.dashed")
                    } footer: {
                        Text("Ces applications ne sont pas sur votre Mac. Installez-les et rouvrez cet écran pour les ajouter.")
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Rechercher parmi \(mac.installedApps.count) apps")
    }

    // MARK: - Lien

    private var linkForm: some View {
        Form {
            Section("Lien") {
                TextField("Nom", text: $name)
                TextField("URL (https://…)", text: $url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section {
                Button("Ajouter") {
                    add(ShortcutItem(name: name,
                                     action: "url",
                                     target: normalisedURL,
                                     shortcutName: nil,
                                     icon: "link"))
                }
                .disabled(name.isEmpty || url.isEmpty)
            }
        }
    }

    /// « exemple.fr » sans schéma ne s'ouvrirait pas : on complète.
    private var normalisedURL: String {
        url.contains("://") ? url : "https://\(url)"
    }

    // MARK: - Raccourci

    private var shortcutForm: some View {
        Form {
            Section("Raccourci") {
                TextField("Nom exact du raccourci", text: $shortcutName)
                    .autocorrectionDisabled()
                Text("Le nom doit correspondre exactement à celui d'un raccourci de l'app Raccourcis de votre Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Ajouter") {
                    add(ShortcutItem(name: shortcutName,
                                     action: "shortcut",
                                     target: nil,
                                     shortcutName: shortcutName,
                                     icon: "bolt.fill"))
                }
                .disabled(shortcutName.isEmpty)
            }
        }
    }

    private func add(_ item: ShortcutItem) {
        onAdd(item)
        dismiss()
    }
}
