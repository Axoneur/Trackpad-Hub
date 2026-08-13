import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var router: Router
    @StateObject private var accessibility = AccessibilityManager()
    @StateObject private var releases = ReleaseChecker()
    @StateObject private var signature = SigningWatch()
    @State private var notificationsBloquees = false
    @StateObject private var refresh: AutoRefresh

    init() {
        // `SigningWatch` et `AutoRefresh` partagent la même instance : le
        // rafraîchissement lit l'échéance et la relit une fois terminé.
        let watch = SigningWatch()
        _signature = StateObject(wrappedValue: watch)
        _refresh = StateObject(wrappedValue: AutoRefresh(signature: watch))
    }
    @EnvironmentObject private var panels: MacHostApp.PanelState

    /// Vide = suivre la disposition active du Mac.
    @AppStorage(KeyboardController.forcedLayoutKey) private var forcedLayoutID = ""
    @State private var layouts: [KeyboardLayout] = []

    var body: some View {
        // Deux colonnes plutôt qu'une feuille : le diagnostic doit s'ouvrir
        // *à côté* du reste, pas par-dessus. On garde ainsi sous les yeux
        // l'état de la connexion pendant qu'on lit les messages reçus.
        mainColumn
            // Un inspecteur, et non plus un `HStack` avec un `Divider`.
            //
            // La contrainte d'origine tient toujours — le diagnostic s'ouvre
            // *à côté* du reste, dans la même fenêtre, pas par-dessus — mais
            // c'est le conteneur que macOS prévoit pour ça : il reçoit le
            // verre automatiquement sous macOS 26, avec sa poignée de
            // redimensionnement et son bouton de barre d'outils, là où le
            // `Divider` fait maintenant tache entre deux panneaux
            // translucides.
            .inspector(isPresented: $panels.showDiagnostics) {
                DiagnosticsView()
                    .inspectorColumnWidth(min: 460, ideal: 520, max: 720)
            }
        // Sans fond de fenêtre translucide, le verre n'a rien à réfracter et
        // rend un gris terne. C'est la moitié de l'effet.
        .glassWindowBackground()
        // L'autre moitié : la barre de titre repeignait son fond opaque
        // par-dessus, d'où le bandeau gris en haut de la fenêtre.
        .clearTitleBarBackground()
        // La barre d'outils reçoit le verre automatiquement sous macOS 26 :
        // c'est la façon la moins coûteuse d'ancrer la fenêtre dans le
        // nouveau langage visuel. Le diagnostic y trouve mieux sa place qu'en
        // pied de fenêtre, où il passait pour une note de bas de page.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    panels.showDiagnostics.toggle()
                } label: {
                    Label(panels.showDiagnostics ? "Masquer le diagnostic" : "Diagnostic clavier",
                          systemImage: "stethoscope")
                }
                .help("Disposition active, messages reçus de l'iPhone, frappes émises")
            }
        }
    }

    /// Colonne principale, en cartes de verre.
    ///
    /// Les `Divider` d'origine ont disparu : dans Liquid Glass, ce sont les
    /// cartes qui séparent, pas les traits. Un trait posé entre deux panneaux
    /// translucides ajoute du bruit sans rien délimiter.
    private var mainColumn: some View {
        ScrollView {
            GlassStack(spacing: 14) {
                header

                if signature.doitAvertir { signatureSection.glassCard() }
                if notificationsBloquees { notificationsSection.glassCard() }
                if releases.disponible != nil { updateSection.glassCard() }

                addDeviceSection
                    .glassCard()

                peersSection
                    .glassCard()

                if !connection.pairedDevices.isEmpty {
                    pairedDevicesSection
                        .glassCard()
                }

                permissionsSection
                    .glassCard()

                keyboardLayoutSection
                    .glassCard()

                footer
            }
            .padding(16)
        }
        .softScrollEdges()
        .onAppear {
            layouts = KeyboardLayout.installed()
            // Notifier avant de vérifier : `verifier()` peut répondre tout de
            // suite depuis son cache, et le rappel serait alors posé trop tard.
            releases.onNouvelleVersion = { sortie in
                MaintenanceNotifier.signalerVersion(sortie.version, notes: sortie.notes)
            }
            MaintenanceNotifier.diagnostiquer { notificationsBloquees = $0 }
            AutoRefresh.enregistrerDefauts()
            releases.verifier()
            // Avant l'examen du branchement : la décision de rafraîchir se
            // prend sur les jours restants, qui viennent d'ici.
            signature.actualiser()
            // Un iPhone déjà branché à l'ouverture de l'app compte aussi :
            // `usbmuxd` annonce « Attached » pour les appareils déjà présents,
            // mais ce message peut être arrivé avant que la vue n'existe.
            if connection.isDeviceAttached { refresh.appareilBranche() }
        }
        .onChange(of: connection.isDeviceAttached) { _, branche in
            branche ? refresh.appareilBranche() : refresh.appareilDebranche()
        }
        .sheet(isPresented: $refresh.visible) {
            RefreshSheet(refresh: refresh)
        }
    }

    /// Notifications refusées : l'avertissement d'expiration n'arrivera pas.
    ///
    /// Affiché seulement dans ce cas. Une fois le refus enregistré, macOS
    /// n'affichera plus jamais d'alerte de demande : redemander ne sert à
    /// rien, seuls les Réglages Système débloquent. Sans cette carte, l'app
    /// resterait muette et l'utilisateur découvrirait l'expiration en
    /// constatant que l'app iPhone ne s'ouvre plus.
    @ViewBuilder
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notifications désactivées", systemImage: "bell.slash")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("TrackPad Hub ne pourra pas vous prévenir avant l'expiration de la signature. L'avertissement restera visible ici, dans cette fenêtre, mais seulement si vous l'ouvrez.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button("Ouvrir les Réglages") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .glassButton(prominent: true)
                Button("Revérifier") {
                    MaintenanceNotifier.diagnostiquer { notificationsBloquees = $0 }
                }
                .glassButton()
                Spacer()
            }
            .controlSize(.small)
        }
    }

    /// Expiration de la signature de l'app iPhone.
    ///
    /// Affichée sur le **Mac** alors qu'elle concerne l'iPhone : c'est le Mac
    /// qui détient le remède, puisque la réinstallation part d'ici.
    @ViewBuilder
    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(signature.resume ?? "", systemImage: "clock.badge.exclamationmark")
                .font(.headline)
                .foregroundStyle((signature.joursRestants ?? 1) < 0 ? .red : .orange)

            Text("Un compte Apple gratuit signe pour 7 jours. Passé ce délai, l'app iPhone cesse de s'ouvrir. Ce n'est pas une panne.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button("Renouveler maintenant") { signature.renouveler() }
                    .glassButton(prominent: true)
                    .disabled(signature.cheminProjet == nil)
                Button("Automatiser tous les 6 jours") { signature.planifier() }
                    .glassButton()
                Spacer()
            }
            .controlSize(.small)

            if let message = signature.dernierMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Mise à jour publiée sur GitHub.
    ///
    /// N'apparaît que s'il y a réellement une version plus récente : un
    /// bandeau permanent qui répète « à jour » finit par ne plus être lu.
    @ViewBuilder
    private var updateSection: some View {
        if let sortie = releases.disponible {
            VStack(alignment: .leading, spacing: 6) {
                Label("Version \(sortie.version) disponible", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                Text("Vous utilisez la \(ReleaseChecker.versionActuelle). Dans le dossier du projet : « git pull » puis « ./reinstall.sh --all ».")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Link("Voir les nouveautés", destination: sortie.url)
                    .font(.callout)
            }
        }
    }

    /// Disposition utilisée pour traduire les caractères reçus en touches.
    private var keyboardLayoutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Disposition du clavier").font(.headline)

            Picker("", selection: $forcedLayoutID) {
                Text("Suivre le clavier actif du Mac").tag("")
                Divider()
                ForEach(layouts) { layout in
                    Text(layout.name).tag(layout.id)
                }
            }
            .labelsHidden()
            .onChange(of: forcedLayoutID) { _, newValue in
                router.keyboard.setForcedLayout(id: newValue.isEmpty ? nil : newValue)
            }

            Text(forcedLayoutID.isEmpty
                 ? "Les lettres envoyées depuis l'iPhone suivent automatiquement la disposition en cours d'utilisation."
                 : "Disposition figée : utile si vous tapez sur un clavier externe différent.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.connected.to.line.below")
                .font(.system(size: 34))
                .foregroundStyle(connection.isConnected ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("TrackPad Hub")
                    .font(.title2.bold())
                Text(connection.isConnected
                     ? "Connecté · votre iPhone est actif"
                     : "En attente d'un iPhone…")
                    .foregroundStyle(connection.isConnected ? .green : .secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    /// Section permanente : on ajoute un appareil quand on le décide, pas
    /// quand un iPhone se manifeste. Le code n'apparaissait auparavant qu'en
    /// réaction à une tentative de connexion, ce qui le rendait imprévisible.
    @ViewBuilder
    private var addDeviceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Ajouter un appareil", systemImage: "plus.circle")
                    .font(.headline)
                Spacer()
                if connection.displayedPin != nil {
                    Button("Masquer le code") { connection.cancelPairing() }
                        .glassButton()
                        .controlSize(.small)
                }
            }

            if let pin = connection.displayedPin {
                pairingSection(pin: pin)
            } else {
                Text("Affichez un code, puis scannez-le depuis l'app de votre iPhone.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                // Action principale de l'écran, et la seule en verre
                // proéminent : deux accents concurrents et l'accent ne
                // désigne plus rien.
                Button {
                    connection.beginPairing()
                } label: {
                    Label("Afficher le code d'appairage", systemImage: "qrcode")
                }
                .glassButton(prominent: true)
            }
        }
    }

    /// Code d'appairage : affiché ici, à recopier ou à scanner depuis l'iPhone.
    private func pairingSection(pin: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scannez le QR code depuis l'app sur votre iPhone, ou saisissez le code à la main. Il reste valable cinq minutes.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 16) {
                if let qr = qrImage(pin: pin) {
                    Image(nsImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 148, height: 148)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary.opacity(0.1))
                        )
                }

                VStack(spacing: 6) {
                    Text(formatted(pin))
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                    Text("Code valable pour cet appairage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .glassAccentCard()
            }
        }
    }

    private func qrImage(pin: String) -> NSImage? {
        let payload = PairingPayload(host: Host.current().localizedName ?? "Mac", pin: pin)
        return QRCodeRenderer.image(for: payload.url)
    }

    /// Espacement du code par groupes de 3, plus lisible à distance.
    private func formatted(_ pin: String) -> String {
        guard pin.count == 6 else { return pin }
        let middle = pin.index(pin.startIndex, offsetBy: 3)
        return "\(pin[pin.startIndex..<middle]) \(pin[middle...])"
    }

    @State private var renamingID: String?
    @State private var draftName = ""

    private func commitRename(_ id: String) {
        connection.renameDevice(id: id, to: draftName)
        renamingID = nil
    }

    private var pairedDevicesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Appareils autorisés").font(.headline)
            ForEach(connection.pairedDevices, id: \.id) { entry in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)

                    if renamingID == entry.id {
                        TextField("Nom", text: $draftName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { commitRename(entry.id) }
                        Button("OK") { commitRename(entry.id) }
                            .glassButton(prominent: true)
                            .controlSize(.small)
                        Button("Annuler") { renamingID = nil }
                            .glassButton()
                            .controlSize(.small)
                    } else {
                        Text(entry.device.name)
                        Spacer()
                        // iOS annonce « iPhone » pour tous les appareils :
                        // sans renommage, deux téléphones sont impossibles à
                        // distinguer dans cette liste.
                        Button("Renommer") {
                            draftName = entry.device.name
                            renamingID = entry.id
                        }
                        .glassButton()
                        .controlSize(.small)
                        Button("Oublier") {
                            connection.forgetDevice(id: entry.id)
                        }
                        .glassButton()
                        .controlSize(.small)
                    }
                }
                .font(.callout)
            }
        }
        .padding(.top, 4)
    }

    private var peersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Appareils").font(.headline)
            if connection.connectedPeers.isEmpty {
                Text("Aucun appareil connecté pour le moment.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(connection.connectedPeers, id: \.displayName) { peer in
                    HStack {
                        Image(systemName: "iphone").foregroundStyle(.blue)
                        Text(peer.displayName)
                        Spacer()
                        Circle().fill(.green).frame(width: 8, height: 8)
                    }
                    .font(.callout)
                }
            }
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Autorisations").font(.headline)
            HStack(spacing: 8) {
                Image(systemName: accessibility.isTrusted
                      ? "checkmark.seal.fill"
                      : "exclamationmark.triangle.fill")
                    .foregroundStyle(accessibility.isTrusted ? .green : .orange)
                Text(accessibility.isTrusted
                     ? "Accès Accessibilité accordé"
                     : "Autorisez l'accès « Accessibilité » pour contrôler la souris et le clavier.")
                    .font(.callout)
                Spacer()
            }
            if !accessibility.isTrusted {
                HStack {
                    Button("Accorder l'accès") { accessibility.request() }
                        .glassButton(prominent: true)
                    Button("Ouvrir les réglages") { accessibility.openSettings() }
                        .glassButton()
                    Spacer()
                }
                .controlSize(.small)
            }

            // Seconde autorisation. Elle n'est **pas** cosmétique : les quatre
            // gestes de navigation en dépendent autant que l'alimentation.
            //
            // Le WindowServer filtre ⌃←, ⌃→, ⌃↓ et F11 quand ils viennent en
            // CGEvent d'une app tierce (vérifié avec six bureaux configurés :
            // la frappe part, rien ne se passe). Ces quatre-là passent donc
            // obligatoirement par System Events — voir `handle(gesture:)`
            // dans SystemController.
            //
            // Ce qui ne dépend de rien : Mission Control, qui ouvre une app,
            // et la veille, qui passe par `pmset` — System Events ne lui sert
            // que de repli.
            if router.system.lastAutomationError != nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Automatisation non accordée : changer de bureau, App Exposé, afficher le bureau, redémarrer, éteindre et se déconnecter resteront sans effet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            if router.system.lastAutomationError != nil {
                HStack {
                    Button("Demander l'accès") { router.system.requestAutomationAccess() }
                        .glassButton()
                    Button("Ouvrir les réglages") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .glassButton()
                    Spacer()
                }
                .controlSize(.small)
            }
        }
    }

    /// Le diagnostic est passé en barre d'outils : il ne reste ici que le
    /// rappel réseau et la sortie.
    private var footer: some View {
        HStack {
            Text("L'iPhone doit être sur le même réseau Wi-Fi (ou à proximité en Bluetooth).")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quitter") {
                NSApplication.shared.terminate(nil)
            }
            .glassButton()
            .controlSize(.small)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}
