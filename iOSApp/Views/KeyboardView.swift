import SwiftUI

/// Clavier intégré à l'app : texte, dictée, presse-papiers partagé,
/// touches spéciales et raccourcis.
///
/// Aucun keycode n'est calculé ici : on envoie des caractères, et c'est le Mac
/// qui choisit la touche physique selon sa disposition.
struct KeyboardView: View {
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var mac: MacState
    @StateObject private var dictation = Dictation()

    @AppStorage(KeyboardStyle.storageKey) private var styleRaw = KeyboardStyle.azerty.rawValue

    @State private var text = ""
    @State private var clipboardFeedback: String?
    @State private var cmd = false
    @State private var opt = false
    @State private var ctrl = false
    @State private var shift = false

    private var isPaired: Bool { connection.pairingState == .paired }

    private var rows: [[String]] {
        (KeyboardStyle(rawValue: styleRaw) ?? .azerty).rows
    }

    private var currentFlags: Int {
        var flags = 0
        if cmd   { flags |= ModFlag.command }
        if opt   { flags |= ModFlag.option }
        if ctrl  { flags |= ModFlag.control }
        if shift { flags |= ModFlag.shift }
        return flags
    }

    var body: some View {
        NavigationStack {
            GlassScreen(title: "Clavier",
                        isConnected: isPaired,
                        statusText: statusText) {
                inputSection
                clipboardSection
                modifiersSection
                specialKeysSection
                functionKeysSection
                letterRows
            }
        }
        .onAppear {
            // Le texte dicté atterrit dans le champ de saisie, pas directement
            // sur le Mac : on peut le relire, le corriger, ou l'annuler avant
            // de l'envoyer. Une reconnaissance vocale se trompe trop souvent
            // pour partir sans relecture.
            dictation.onFinalText = { spoken in
                text = text.isEmpty ? spoken : text + " " + spoken
            }
        }
        .onDisappear { dictation.stop() }
    }

    private var statusText: String {
        if dictation.isListening { return "Dictée en cours · parlez" }
        if case .denied(let reason) = dictation.state { return reason }
        if case .error(let reason) = dictation.state { return reason }
        return isPaired ? "Connecté · texte et raccourcis" : "Non connecté au Mac"
    }

    // MARK: - Saisie et dictée

    private var inputSection: some View {
        GlassTile {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Écrire du texte à envoyer…", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .glassSurface(cornerRadius: 14)

                    Button {
                        guard !text.isEmpty else { return }
                        connection.send(.text(text))
                        text = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .frame(width: 40, height: 40)
                    }
                    .prominentGlassButton()
                    .disabled(text.isEmpty)
                }

                if dictation.isListening {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .foregroundStyle(.red)
                            .symbolEffect(.variableColor.iterative)
                        Text(dictation.transcript.isEmpty
                             ? "Parlez, le texte apparaîtra ici…"
                             : dictation.transcript)
                            .font(.footnote)
                            .foregroundStyle(dictation.transcript.isEmpty ? .secondary : .primary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }

                if !text.isEmpty {
                    HStack(spacing: 8) {
                        Button("Effacer") { text = "" }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(text.count) caractères")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Button {
                    Task { await dictation.toggle() }
                } label: {
                    Label(dictation.isListening ? "Arrêter la dictée" : "Dictée vocale",
                          systemImage: dictation.isListening ? "stop.circle.fill" : "mic.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(dictation.isListening ? Color.white : Color.primary)
                .glassSurface(cornerRadius: 14,
                              tint: dictation.isListening ? .red : nil,
                              interactive: true)
            }
        }
    }

    // MARK: - Presse-papiers partagé

    private var clipboardSection: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Presse-papiers partagé", systemImage: "doc.on.clipboard")

            GlassTile {
                VStack(alignment: .leading, spacing: 12) {
                    // Le contenu du Mac, montré tel quel : c'est lui qui rend
                    // les deux boutons compréhensibles.
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Copié sur le Mac")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(mac.clipboard.isEmpty ? "rien pour l'instant" : mac.clipboard)
                            .font(.footnote)
                            .foregroundStyle(mac.clipboard.isEmpty ? .tertiary : .primary)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // Deux sens, deux lignes, chacune dite en toutes lettres.
                    Button {
                        guard !mac.clipboard.isEmpty else {
                            clipboardFeedback = "Le presse-papiers du Mac est vide."
                            return
                        }
                        UIPasteboard.general.string = mac.clipboard
                        clipboardFeedback = "Collé dans le presse-papiers de l'iPhone."
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        transferRow(icon: "iphone.and.arrow.right.inward",
                                    title: "Récupérer sur l'iPhone",
                                    detail: "Colle ensuite où vous voulez sur le téléphone")
                    }
                    .buttonStyle(.plain)

                    PasteButton(payloadType: String.self) { strings in
                        guard let copied = strings.first, !copied.isEmpty else { return }
                        connection.send(.clipboardPush(copied))
                        clipboardFeedback = "Envoyé, collez avec ⌘V sur le Mac."
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Le bouton ci-dessus envoie le presse-papiers de l'iPhone vers le Mac. iOS demande votre accord à chaque fois, c'est lui qui l'impose.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if let clipboardFeedback {
                        Label(clipboardFeedback, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
            }
        }
    }

    private func transferRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .foregroundStyle(.primary)
        .contentShape(.rect)
    }

    // MARK: - Modificateurs

    private var modifiersSection: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Modificateurs", systemImage: "command")
            GlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    modifier("⌘", active: cmd) { cmd.toggle() }
                    modifier("⌥", active: opt) { opt.toggle() }
                    modifier("⌃", active: ctrl) { ctrl.toggle() }
                    modifier("⇧", active: shift) { shift.toggle() }
                }
            }
        }
    }

    private func modifier(_ symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 19, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
        }
        .buttonStyle(PressedKeyStyle())
        .foregroundStyle(active ? Color.white : Color.primary)
        .glassSurface(cornerRadius: 14,
                      tint: active ? .accentColor : nil,
                      interactive: true)
    }

    // MARK: - Touches spéciales

    private var specialKeysSection: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Touches", systemImage: "arrow.up.left.and.arrow.down.right")
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    key("Échap") { sendKey(.escape) }
                    key("Tab") { sendKey(.tab) }
                    key("Espace") { sendKey(.space) }
                    // « ↩ » (U+21A9) a une présentation emoji par défaut ;
                    // « ↵ » reste un glyphe texte.
                    key("↵") { sendKey(.return) }
                    key("⌫") { sendKey(.delete) }
                }
                HStack(spacing: 8) {
                    key("←") { sendKey(.left) }
                    key("↑") { sendKey(.up) }
                    key("↓") { sendKey(.down) }
                    key("→") { sendKey(.right) }
                }
                // Navigation dans un document : indispensable dès qu'on édite
                // du texte à distance.
                HStack(spacing: 8) {
                    key("⌦") { sendKey(.forwardDelete) }
                    key("Début") { sendKey(.home) }
                    key("Fin") { sendKey(.end) }
                    key("Page ↑") { sendKey(.pageUp) }
                    key("Page ↓") { sendKey(.pageDown) }
                }
            }
        }
    }

    // MARK: - Touches de fonction

    @AppStorage("showFunctionKeys") private var showFunctionKeys = false

    private var functionKeysSection: some View {
        VStack(spacing: Design.Space.tight) {
            HStack {
                SectionHeader(title: "Touches de fonction", systemImage: "f.square")
                Button(showFunctionKeys ? "Masquer" : "Afficher") {
                    withAnimation(.snappy) { showFunctionKeys.toggle() }
                }
                .font(.footnote.weight(.medium))
            }

            if showFunctionKeys {
                // Six par rangée : douze d'affilée seraient illisibles sur un
                // écran d'iPhone.
                ForEach(0..<2) { row in
                    HStack(spacing: 5) {
                        ForEach(SpecialKey.functionKeys[(row * 6)..<(row * 6 + 6)], id: \.self) { function in
                            key(function.label) { sendKey(function) }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Lettres

    @State private var symbols = false

    private var letterRows: some View {
        VStack(spacing: 6) {
            HStack {
                SectionHeader(title: "Clavier", systemImage: "keyboard")
                Text("Tournez l'iPhone pour des touches plus grandes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            RemoteKeyboard(style: KeyboardStyle(rawValue: styleRaw) ?? .azerty,
                           shift: $shift,
                           symbols: $symbols,
                           onCharacter: { sendChar($0) },
                           onSpecial: { sendKey($0) })
        }
    }

    /// Hauteur des touches, plus généreuse en paysage où la largeur permet
    /// des touches réellement confortables.
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var keyHeight: CGFloat { isLandscape ? 58 : 52 }
    private var keyFontSize: CGFloat { isLandscape ? 22 : 19 }

    private var isLandscape: Bool {
        sizeClass == .regular
    }

    private func key(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: keyFontSize, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
                .frame(height: keyHeight)
        }
        .buttonStyle(PressedKeyStyle())
        .glassSurface(cornerRadius: 12, interactive: true)
    }

    // MARK: - Envoi

    private func sendKey(_ key: SpecialKey) {
        connection.send(.specialKey(key, flags: currentFlags))
        resetOneShotModifiers()
    }

    private func sendChar(_ char: Character) {
        connection.send(.character(char, flags: currentFlags))
        resetOneShotModifiers()
    }

    /// Les modificateurs ne valent que pour la frappe suivante, comme sur un
    /// vrai clavier où on les relâche après le raccourci.
    ///
    /// La majuscule est gérée par le clavier lui-même, qui la relâche déjà
    /// après une lettre : la remettre à zéro ici l'empêcherait de servir
    /// comme modificateur d'un raccourci.
    private func resetOneShotModifiers() {
        guard cmd || opt || ctrl else { return }
        cmd = false
        opt = false
        ctrl = false
    }
}


// MARK: - Animation d'enfoncement

/// Une touche qui s'enfonce sous le doigt.
///
/// Sur un clavier physique, la touche descend : c'est ce mouvement qui dit
/// « c'est parti », avant même que le Mac ait réagi. Sans lui, on ne sait pas
/// si l'appui a été pris en compte, et on tape deux fois.
///
/// L'aller est **instantané** et le retour progressif : une animation à
/// l'enfoncement retarderait le retour visuel, ce qui est exactement l'inverse
/// du but recherché. Le retour, lui, peut prendre son temps.
struct PressedKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .brightness(configuration.isPressed ? 0.18 : 0)
            .animation(configuration.isPressed ? nil : .easeOut(duration: 0.18),
                       value: configuration.isPressed)
            .contentShape(.rect)
    }
}
