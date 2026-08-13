import SwiftUI

/// Onglet « Mac » : applications ouvertes, contrôles système, constantes.
struct MacView: View {
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var mac: MacState

    @State private var pendingAction: SystemAction?
    @State private var refreshTimer: Timer?
    @State private var wakeMessage: String?

    @AppStorage(MessageConnection.wakeMacAddressKey) private var wakeMacAddress = ""
    @AppStorage(MessageConnection.lastHostNameKey) private var lastHostName = ""

    private var isPaired: Bool { connection.pairingState == .paired }

    var body: some View {
        NavigationStack {
            GlassScreen(title: "Mac",
                        isConnected: connection.pairingState == .paired,
                        statusText: statusText) {

                wakeSection
                vitalsSection
                appsSection
                windowsSection
                tabsLink
                clipboardLink
                midiLink
                notesLink
                macrosLink
                gamingLink
                statsLink
                filesLink
                shortcutsLink
                navigationSection
                powerSection
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HelpView()
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear { startRefreshing() }
        .onDisappear { stopRefreshing() }
        .confirmationDialog(pendingAction?.label ?? "",
                            isPresented: confirmationBinding,
                            titleVisibility: .visible) {
            Button(pendingAction?.label ?? "", role: .destructive) {
                if let action = pendingAction {
                    connection.send(.system(action))
                }
                pendingAction = nil
            }
            Button("Annuler", role: .cancel) { pendingAction = nil }
        } message: {
            Text("Le travail non enregistré sur votre Mac sera perdu.")
        }
    }

    private var statusText: String {
        guard connection.pairingState == .paired else { return "Non connecté au Mac" }
        if let vitals = mac.vitals { return vitals.hostName }
        return "Connecté"
    }

    // MARK: - Réveil à distance

    /// N'apparaît que lorsque le Mac est injoignable : c'est le seul moment
    /// où réveiller a du sens.
    @ViewBuilder
    private var wakeSection: some View {
        if !isPaired, !wakeMacAddress.isEmpty {
            GlassTile(tint: .indigo) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "powersleep")
                            .font(.title3)
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(lastHostName.isEmpty ? "Votre Mac" : lastHostName)
                                .font(.subheadline.weight(.semibold))
                            Text("Injoignable · il dort peut-être")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Button {
                        wake()
                    } label: {
                        Label("Réveiller le Mac", systemImage: "bolt.horizontal")
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .prominentGlassButton()

                    if let wakeMessage {
                        Text(wakeMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func wake() {
        let broadcast = UserDefaults.standard.string(forKey: MessageConnection.wakeBroadcastKey)
        do {
            try WakeOnLAN.wake(macAddress: wakeMacAddress,
                               broadcast: broadcast?.isEmpty == false ? broadcast! : "255.255.255.255")
            wakeMessage = "Paquet envoyé. Le Mac met quelques secondes à répondre."
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            wakeMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Constantes

    @ViewBuilder
    private var vitalsSection: some View {
        if let vitals = mac.vitals {
            GlassTile {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "desktopcomputer")
                            .font(.title3)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(vitals.hostName)
                                .font(.subheadline.weight(.semibold))
                            Text("Allumé depuis \(vitals.uptime)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let percent = vitals.batteryPercent {
                            batteryBadge(percent: percent, charging: vitals.isCharging ?? false)
                        }
                    }

                    gauge("Processeur", value: vitals.cpuPercent / 100,
                          detail: "\(Int(vitals.cpuPercent)) %", tint: .orange)
                    gauge("Mémoire", value: vitals.memoryUsedGB / max(vitals.memoryTotalGB, 1),
                          detail: "\(String(format: "%.1f", vitals.memoryUsedGB)) / \(String(format: "%.0f", vitals.memoryTotalGB)) Go",
                          tint: .purple)
                    gauge("Disque", value: 1 - vitals.diskFreeGB / max(vitals.diskTotalGB, 1),
                          detail: "\(String(format: "%.0f", vitals.diskFreeGB)) Go libres",
                          tint: .blue)
                }
            }
        }
    }

    private func batteryBadge(percent: Int, charging: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: charging ? "battery.100.bolt" : batteryIcon(percent))
                .foregroundStyle(charging ? .green : (percent <= 20 ? .red : .primary))
            Text("\(percent) %")
                .font(.footnote.weight(.medium))
                .monospacedDigit()
        }
    }

    private func batteryIcon(_ percent: Int) -> String {
        switch percent {
        case ..<13:  return "battery.0"
        case ..<38:  return "battery.25"
        case ..<63:  return "battery.50"
        case ..<88:  return "battery.75"
        default:     return "battery.100"
        }
    }

    private func gauge(_ title: String, value: Double, detail: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text(detail).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(value, 0), 1))
                .tint(tint)
        }
    }

    // MARK: - Applications

    @ViewBuilder
    private var appsSection: some View {
        if !mac.apps.isEmpty {
            VStack(spacing: Design.Space.tight) {
                HStack {
                    SectionHeader(title: "Applications ouvertes", systemImage: "square.stack")
                    NavigationLink {
                        AppsView()
                    } label: {
                        Text("Tout voir")
                            .font(.footnote.weight(.medium))
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(mac.apps) { app in
                            AppDockItem(app: app) {
                                connection.send(.appAction(.activate, bundleID: app.bundleID))
                            } onQuit: {
                                connection.send(.appAction(.quit, bundleID: app.bundleID))
                                // La liste met un instant à refléter la fermeture.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { refresh() }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    // MARK: - Raccourcis

    private var shortcutsLink: some View {
        NavigationLink {
            ShortcutsView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Raccourcis")
                        .font(.subheadline.weight(.semibold))
                    Text("Lancer une app, un lien ou un raccourci")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Design.Space.normal)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassSurface(cornerRadius: Design.Radius.tile, interactive: true)
    }

    // MARK: - Transfert de fichiers

    private var filesLink: some View {
        NavigationLink {
            FileTransferView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Envoyer un fichier")
                        .font(.subheadline.weight(.semibold))
                    Text("Photos, documents, capture du presse-papiers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Design.Space.normal)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassSurface(interactive: true)
    }

    // MARK: - Navigation macOS

    private var gamingLink: some View {
        NavigationLink {
            GamingView()
        } label: {
            linkLabel(icon: "gamecontroller.fill", title: "Mode jeu",
                      subtitle: "Joystick et boutons, en touches maintenues")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassSurface(interactive: true)
    }

    private var statsLink: some View {
        NavigationLink {
            StatsView()
        } label: {
            linkLabel(icon: "chart.bar.fill", title: "Statistiques",
                      subtitle: "Temps connecté et gestes les plus utilisés")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassSurface(interactive: true)
    }

    /// Gabarit commun des liens : sept répétitions du même bloc valaient bien
    /// une fonction.
    private func linkLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(Design.Space.normal)
        .contentShape(.rect)
    }

    private var macrosLink: some View {
        NavigationLink {
            MacrosView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.rays")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Macros")
                        .font(.subheadline.weight(.semibold))
                    Text("Enregistrer une séquence, la rejouer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Design.Space.normal)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassSurface(interactive: true)
    }

    private var notesLink: some View {
        NavigationLink {
            NotesView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Notes rapides")
                        .font(.subheadline.weight(.semibold))
                    Text("Envoyer un texte au Mac, sans serveur")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Design.Space.normal)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassSurface(interactive: true)
    }

    private var midiLink: some View {
        NavigationLink {
            MidiView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "pianokeys")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Surface MIDI")
                        .font(.subheadline.weight(.semibold))
                    Text("DJ, égaliseur, palettes, via MIDI learn")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Design.Space.normal)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassSurface(interactive: true)
    }

    private var clipboardLink: some View {
        NavigationLink {
            ClipboardHistoryView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Historique du presse-papiers")
                        .font(.subheadline.weight(.semibold))
                    Text("Ce qui a été copié sur le Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Design.Space.normal)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassSurface(interactive: true)
    }

    private var tabsLink: some View {
        NavigationLink {
            TabsView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.on.square")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Onglets du navigateur")
                        .font(.subheadline.weight(.semibold))
                    Text("Naviguer, fermer, rouvrir")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Design.Space.normal)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassSurface(interactive: true)
    }

    // MARK: - Fenêtres

    /// Placement de la fenêtre active du Mac.
    ///
    /// Trois rangées plutôt qu'une grille unique : les moitiés servent tous
    /// les jours, les quarts et les tiers beaucoup moins. Les mélanger
    /// noierait les huit boutons utiles au milieu de dix-sept.
    @State private var showsAllPlacements = false

    private var windowsSection: some View {
        VStack(spacing: Design.Space.tight) {
            HStack {
                SectionHeader(title: "Fenêtres", systemImage: "macwindow.on.rectangle")
                Spacer()
                Button(showsAllPlacements ? "Moins" : "Plus") {
                    withAnimation(.snappy(duration: 0.2)) { showsAllPlacements.toggle() }
                }
                .font(.footnote)
            }

            placementGrid(WindowSlot.common)

            if showsAllPlacements {
                placementGrid(WindowSlot.quarters)
                placementGrid(WindowSlot.thirds)
                placementGrid(WindowSlot.states)
            }

            Text("Agit sur la fenêtre active du Mac. Activez-la d'abord : si TrackPad Hub est au premier plan, il n'y a rien à déplacer.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func placementGrid(_ placements: [WindowSlot]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                  spacing: 10) {
            ForEach(placements) { placement in
                GlassActionButton(icon: placement.icon, label: placement.label) {
                    connection.send(.window(placement.rawValue))
                }
            }
        }
    }

    private var navigationSection: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Navigation", systemImage: "rectangle.3.group")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                      spacing: 10) {
                ForEach(SystemAction.navigation) { action in
                    GlassActionButton(icon: action.icon, label: action.label) {
                        connection.send(.system(action))
                    }
                }
            }
        }
    }

    // MARK: - Alimentation

    private var powerSection: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Alimentation", systemImage: "power")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                      spacing: 10) {
                ForEach(SystemAction.power) { action in
                    GlassActionButton(icon: action.icon,
                                      label: action.label,
                                      tint: action.needsConfirmation ? .red : nil) {
                        if action.needsConfirmation {
                            pendingAction = action
                        } else {
                            connection.send(.system(action))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Rafraîchissement

    private var confirmationBinding: Binding<Bool> {
        Binding(get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } })
    }

    private func refresh() {
        guard connection.pairingState == .paired else { return }
        connection.send(.appsRequest())
        connection.send(.vitalsRequest())
    }

    private func startRefreshing() {
        refresh()
        stopRefreshing()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            Task { @MainActor in refresh() }
        }
    }

    private func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

/// Vignette d'application, façon Dock macOS.
struct AppDockItem: View {
    let app: RunningApp
    let onActivate: () -> Void
    let onQuit: () -> Void

    var body: some View {
        Button(action: onActivate) {
            VStack(spacing: 6) {
                icon
                    .frame(width: 46, height: 46)
                Text(app.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 62)
                Circle()
                    .fill(app.isActive ? Color.accentColor : .clear)
                    .frame(width: 4, height: 4)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { onQuit() } label: {
                Label("Quitter", systemImage: "xmark.circle")
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let encoded = app.iconBase64,
           let data = Data(base64Encoded: encoded),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.tertiary)
                .overlay(Image(systemName: "app.dashed").foregroundStyle(.secondary))
        }
    }
}
