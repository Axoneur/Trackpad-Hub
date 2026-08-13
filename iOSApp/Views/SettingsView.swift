import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var releases: ReleaseChecker

    @AppStorage(KeyboardStyle.storageKey) private var keyboardStyle = KeyboardStyle.azerty.rawValue
    @AppStorage("pointerAcceleration") private var pointerAcceleration = true
    @AppStorage("scrollMomentum") private var scrollMomentum = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("naturalScrolling") private var naturalScrolling = true
    @AppStorage("threeFingerGestures") private var threeFingerGestures = true
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue
    @AppStorage("tiltSensitivity") private var tiltSensitivity: Double = 1.0
    @AppStorage("pocketModeEnabled") private var pocketModeEnabled = false
    @AppStorage("highContrast") private var highContrast = false
    @AppStorage("oneHanded") private var oneHanded = false

    @AppStorage(ReglagesRappels.actifs)  private var rappelsActifs = true
    @AppStorage(ReglagesRappels.premier) private var rappelPremier = 3
    @AppStorage(ReglagesRappels.veille)  private var rappelVeille = true
    @AppStorage(ReglagesRappels.jourJ)   private var rappelJourJ = true
    @AppStorage(ReglagesRappels.heure)   private var rappelHeure = 9

    @State private var autorisation: UNAuthorizationStatus = .notDetermined


    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "Système"
            case .light:  return "Clair"
            case .dark:   return "Sombre"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if SigningExpiry.isExpiringSoon || releases.disponible != nil {
                    Section { MaintenanceCard() }
                }

                Section {
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Aide et tutoriels")
                                Text("Chaque fonctionnalité expliquée pas à pas")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }

                // Symétrique de la section « Ajouter un appareil » du Mac :
                // on appaire quand on le décide, sans attendre que l'écran
                // d'appairage s'impose de lui-même.
                Section("Ajouter un Mac") {
                    Button {
                        connection.requestPairingScreen()
                    } label: {
                        Label("Scanner un QR code ou saisir un code",
                              systemImage: "qrcode.viewfinder")
                    }
                    Text("Sur le Mac : fenêtre TrackPad Hub → « Ajouter un appareil » → « Afficher le code d'appairage ».")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Connexion") {
                    LabeledContent("Statut") {
                        Text(stateLabel)
                            .foregroundStyle(connection.pairingState == .paired ? .green : .secondary)
                    }
                    ForEach(connection.connectedPeers, id: \.displayName) { peer in
                        Label(peer.displayName, systemImage: "desktopcomputer")
                    }
                    Button("Redémarrer la connexion") { connection.restart() }
                }

                if !connection.knownHosts.isEmpty {
                    Section("Macs appairés") {
                        ForEach(connection.knownHosts, id: \.self) { host in
                            HStack {
                                Label(host, systemImage: "checkmark.shield.fill")
                                Spacer()
                                Button("Oublier", role: .destructive) {
                                    connection.forgetHost(host)
                                }
                                .font(.footnote)
                            }
                        }
                    }
                }

                Section {
                    NavigationLink {
                        FeaturesView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Fonctionnalités")
                                Text("Ce qui est actif, et ce qui reste à activer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }

                Section("Apparence") {
                    Picker("Thème", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Clavier") {
                    Picker("Disposition affichée", selection: $keyboardStyle) {
                        ForEach(KeyboardStyle.allCases) { style in
                            Text(style.name).tag(style.rawValue)
                        }
                    }
                    Text("Ne change que les lettres dessinées sur les touches. Le Mac traduit ensuite selon sa propre disposition — réglable dans l'app macOS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Gestes") {
                    Toggle("Gestes système à 3 doigts", isOn: $threeFingerGestures)
                    Text(threeFingerGestures
                         ? "3 doigts : Mission Control vers le haut, App Exposé vers le bas, bureaux sur les côtés. Le glisser-déposer reste accessible par appui bref puis glissement."
                         : "3 doigts : glisser-déposer. Les gestes système sont désactivés.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("4 doigts : écarter affiche le bureau, rapprocher ouvre la recherche.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Trackpad") {
                    Toggle("Accélération du curseur", isOn: $pointerAcceleration)
                    Toggle("Inertie du défilement", isOn: $scrollMomentum)
                    Toggle("Défilement naturel", isOn: $naturalScrolling)
                    Toggle("Retour haptique", isOn: $hapticsEnabled)
                    Text("Si le défilement part dans le mauvais sens, changez « Défilement naturel ».")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Capteurs") {
                    Toggle("Mode poche", isOn: $pocketModeEnabled)
                    Text("Ignore le tactile quand le capteur de proximité est couvert — poche, table. Évite qu'un téléphone rangé sans verrouiller envoie des clics au hasard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Vitesse d'inclinaison") {
                            Text(String(format: "%.1f×", tiltSensitivity))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $tiltSensitivity, in: 0.3...2.5)
                    }
                    Text("Le défilement par inclinaison s'active depuis l'icône flèches, sous le trackpad. La position de départ sert de repos : inclinez ensuite vers l'avant ou vers vous.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Accessibilité") {
                    Toggle("Fort contraste", isOn: $highContrast)
                    Text("Textes et bordures renforcés, transparences réduites.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Mode une main", isOn: $oneHanded)
                    Text("Boutons plus grands et rapprochés du bas de l'écran, à portée du pouce.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Clavier complet (extension)") {
                    steps([
                        "Réglages > Claviers > Claviers > Ajouter un clavier.",
                        "Choisissez « Clavier TrackPad Hub ».",
                        "Touchez son nom, puis activez « Autoriser l'accès complet ».",
                        "Aucun code à ressaisir : l'extension réutilise l'appairage de cette app."
                    ])
                }

                rappelsSection

                Section("Sur votre Mac") {
                    steps([
                        "Ouvrez l'app « TrackPad Hub » (macOS).",
                        "Cliquez sur « Accorder l'accès », puis autorisez l'Accessibilité.",
                        "Pour les gestes de bureaux et l'alimentation, acceptez aussi la demande « Automatisation ».",
                        "L'iPhone doit être sur le même réseau Wi-Fi."
                    ])
                }

                Section("Gestes") {
                    tip("1 doigt : curseur", "hand.draw")
                    tip("2 doigts : défilement, écarter pour zoomer", "arrow.up.and.down")
                    tip("Appuis : 1 doigt = clic · 2 = clic droit · 3 = clic milieu", "hand.tap")
                    tip("3 doigts en mouvement, ou appui puis glisser : glisser-déposer", "hand.raised")
                }

                Section {
                    HStack {
                        Spacer()
                        Text("TrackPad Hub · v1.1")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Réglages")
            .onAppear {
                connection.refreshKnownHosts()
                ExpiryNotice.autorisation { autorisation = $0 }
            }
            // Un réglage changé doit valoir tout de suite : les notifications
            // sont déposées d'avance, celles déjà en place seraient sinon
            // restées sur l'ancien horaire jusqu'au prochain lancement.
            .onChange(of: rappelsActifs)  { _, _ in ExpiryNotice.programmer() }
            .onChange(of: rappelPremier)  { _, _ in ExpiryNotice.programmer() }
            .onChange(of: rappelVeille)   { _, _ in ExpiryNotice.programmer() }
            .onChange(of: rappelJourJ)    { _, _ in ExpiryNotice.programmer() }
            .onChange(of: rappelHeure)    { _, _ in ExpiryNotice.programmer() }
            .onChange(of: connection.pairingState) { _, state in
                if state == .paired { connection.refreshKnownHosts() }
            }
        }
        .preferredColorScheme(colorScheme)
    }

    // MARK: - Rappels d'expiration

    /// Réglage des rappels qui invitent à rafraîchir l'app avant sa date
    /// limite.
    ///
    /// La section affiche **les dates réellement programmées**, calculées par
    /// le même code que celui qui dépose les notifications. Une description
    /// écrite à la main finirait par diverger du comportement, et c'est
    /// exactement le genre d'écart qu'on ne remarque qu'au moment où le rappel
    /// n'arrive pas.
    @ViewBuilder
    private var rappelsSection: some View {
        Section {
            Toggle("Me rappeler de rafraîchir l'app", isOn: $rappelsActifs)

            if rappelsActifs {
                Picker("Premier rappel", selection: $rappelPremier) {
                    ForEach(ReglagesRappels.avancesPossibles, id: \.self) { jours in
                        Text(jours == 1 ? "La veille" : "\(jours) jours avant").tag(jours)
                    }
                }
                Toggle("Rappel la veille", isOn: $rappelVeille)
                Toggle("Au moment de l'expiration", isOn: $rappelJourJ)

                Picker("Heure des rappels", selection: $rappelHeure) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02dh00", h)).tag(h)
                    }
                }
            }
        } header: {
            Text("Rappels d'expiration")
        } footer: {
            rappelsPied
        }

        if rappelsActifs, autorisation == .denied {
            Section {
                Label("Notifications refusées", systemImage: "bell.slash.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Aucun rappel ne peut partir. iOS ne redemande jamais après un refus : l'autorisation se rétablit uniquement depuis les Réglages du système.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Ouvrir les Réglages iOS") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var rappelsPied: some View {
        if !rappelsActifs {
            Text("L'app cessera de s'ouvrir à sa date limite sans aucun avertissement préalable.")
        } else if let expiration = SigningExpiry.date {
            let moments = ExpiryNotice.moments(pour: expiration)
            VStack(alignment: .leading, spacing: 4) {
                if moments.isEmpty && !rappelJourJ {
                    Text("Aucun rappel programmé : les délais choisis sont déjà passés.")
                } else {
                    Text("Rappels programmés :")
                    ForEach(moments, id: \.0) { quand, _ in
                        Text("• " + quand.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                    }
                    if rappelJourJ {
                        Text("• " + expiration.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()) + " — expiration")
                    }
                }
                Text("Rafraîchir l'app depuis le Mac : ./reinstall.sh --all")
                    .padding(.top, 2)
            }
        } else {
            Text("La date limite n'a pas pu être lue. Les rappels se programmeront à la prochaine installation depuis le Mac.")
        }
    }

    private var colorScheme: ColorScheme? {
        switch Appearance(rawValue: appearance) ?? .system {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    private var stateLabel: String {
        switch connection.pairingState {
        case .paired:     return "Appairé"
        case .verifying:  return "Vérification…"
        case .awaitingPin: return "Code attendu"
        case .refused:    return "Refusé"
        case .idle:       return connection.isConnected ? "Connecté" : "Recherche…"
        }
    }

    private func steps(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, text in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.accentColor))
                    Text(text)
                }
            }
        }
        .font(.footnote)
    }

    private func tip(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
