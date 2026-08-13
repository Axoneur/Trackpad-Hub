import SwiftUI

/// Gestion des applications du Mac : celles qui tournent et celles qui sont
/// installées.
struct AppsView: View {
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var mac: MacState

    enum Scope: String, CaseIterable, Identifiable {
        case running, installed
        var id: String { rawValue }
        var label: String { self == .running ? "Ouvertes" : "Installées" }
    }

    @State private var scope: Scope = .running
    @State private var search = ""
    @State private var selected: RunningApp?
    @State private var timer: Timer?

    private var isPaired: Bool { connection.pairingState == .paired }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: Design.Space.normal) {
                Picker("", selection: $scope) {
                    ForEach(Scope.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Design.Space.wide)

                if scope == .running {
                    runningList
                } else {
                    installedList
                }
            }
            .padding(.top, Design.Space.tight)
        }
        .navigationTitle("Applications")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Rechercher une app")
        .onAppear { startRefreshing() }
        .onDisappear { stopRefreshing() }
        .onChange(of: scope) { _, _ in refresh() }
        .sheet(item: $selected) { app in
            AppActionsSheet(app: app) { action in
                connection.send(.appAction(action, bundleID: app.bundleID))
                selected = nil
                // La liste met un instant à refléter le changement d'état.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { refresh() }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Apps ouvertes

    private var runningList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredRunning) { app in
                    Button {
                        selected = app
                    } label: {
                        AppRow(name: app.name,
                               iconBase64: app.iconBase64,
                               badge: badge(for: app),
                               trailing: "ellipsis.circle")
                    }
                    .buttonStyle(.plain)
                }

                if filteredRunning.isEmpty {
                    emptyState("Aucune app ouverte",
                               detail: isPaired ? "Rien ne tourne au premier plan sur le Mac."
                                                : "Connectez-vous à votre Mac.")
                }
            }
            .padding(.horizontal, Design.Space.wide)
            .padding(.bottom, Design.Space.wide)
        }
    }

    private func badge(for app: RunningApp) -> (String, Color)? {
        if app.isSuspended { return ("Suspendue", .orange) }
        if app.isHidden { return ("Masquée", .secondary) }
        if app.isActive { return ("Au premier plan", .accentColor) }
        return nil
    }

    // MARK: - Apps installées

    private var installedList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredInstalled) { app in
                    Button {
                        connection.send(.launchApp(bundleID: app.bundleID))
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { refresh() }
                    } label: {
                        AppRow(name: app.name,
                               iconBase64: app.iconBase64,
                               badge: app.isRunning ? ("Ouverte", .green) : nil,
                               trailing: "arrow.up.forward.app")
                    }
                    .buttonStyle(.plain)
                }

                if filteredInstalled.isEmpty {
                    emptyState("Aucune app trouvée",
                               detail: "La liste se charge depuis le Mac.")
                }
            }
            .padding(.horizontal, Design.Space.wide)
            .padding(.bottom, Design.Space.wide)
        }
    }

    // MARK: - Filtrage

    private var filteredRunning: [RunningApp] {
        guard !search.isEmpty else { return mac.apps }
        return mac.apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var filteredInstalled: [InstalledApp] {
        guard !search.isEmpty else { return mac.installedApps }
        return mac.installedApps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        GlassTile {
            VStack(spacing: 8) {
                Image(systemName: "square.dashed")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(title).font(.headline)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
        }
    }

    // MARK: - Rafraîchissement

    private func refresh() {
        guard isPaired else { return }
        if scope == .running {
            connection.send(.appsRequest())
        } else {
            connection.send(.installedRequest())
        }
    }

    private func startRefreshing() {
        refresh()
        stopRefreshing()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            Task { @MainActor in
                // Les apps installées changent rarement : inutile de les
                // redemander en boucle.
                if scope == .running { refresh() }
            }
        }
    }

    private func stopRefreshing() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Ligne d'application

struct AppRow: View {
    let name: String
    let iconBase64: String?
    let badge: (String, Color)?
    let trailing: String

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(base64: iconBase64)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let badge {
                    Text(badge.0)
                        .font(.caption2)
                        .foregroundStyle(badge.1)
                }
            }

            Spacer()

            Image(systemName: trailing)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.rect)
        .glassSurface(cornerRadius: Design.Radius.tile, interactive: true)
    }
}

struct AppIcon: View {
    let base64: String?

    var body: some View {
        if let base64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 9)
                .fill(.tertiary)
                .overlay(Image(systemName: "app.dashed").foregroundStyle(.secondary))
        }
    }
}

// MARK: - Feuille d'actions

struct AppActionsSheet: View {
    let app: RunningApp
    let perform: (AppAction) -> Void

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: Design.Space.normal) {
                VStack(spacing: 8) {
                    AppIcon(base64: app.iconBase64)
                        .frame(width: 60, height: 60)
                    Text(app.name).font(.headline)
                    if app.isSuspended {
                        Text("Suspendue — elle ne consomme plus de processeur")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 24)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                          spacing: 10) {
                    ForEach(app.availableActions) { action in
                        GlassActionButton(icon: action.icon,
                                          label: action.label,
                                          tint: action.isDestructive ? .red : nil) {
                            perform(action)
                        }
                    }
                }
                .padding(.horizontal, Design.Space.wide)

                Spacer()
            }
        }
    }
}
