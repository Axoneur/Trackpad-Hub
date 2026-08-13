import SwiftUI

struct TrackpadView: View {
    @EnvironmentObject private var connection: MessageConnection
    @StateObject private var airMouse = AirMouse()
    @StateObject private var tilt = TiltScroll()
    @StateObject private var pocket = PocketMode()

    @AppStorage("pointerSensitivity") private var pointerSensitivity: Double = 2.2
    @AppStorage("scrollSensitivity") private var scrollSensitivity: Double = 2.0
    @AppStorage("pointerAcceleration") private var pointerAcceleration = true
    @AppStorage("scrollMomentum") private var scrollMomentum = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("naturalScrolling") private var naturalScrolling = true
    @AppStorage("airMouseSensitivity") private var airSensitivity: Double = 1.0
    @AppStorage("threeFingerGestures") private var threeFingerGestures = true
    @AppStorage("tiltSensitivity") private var tiltSensitivity: Double = 1.0
    @AppStorage("pocketModeEnabled") private var pocketModeEnabled = false
    @AppStorage("highContrast") private var highContrast = false
    @AppStorage("oneHanded") private var oneHanded = false

    @State private var showSpeeds = false
    @State private var showKeyboard = false
    /// Le rappel des gestes disparaît dès qu'on touche la surface.
    @State private var hasTouched = false

    /// Vrai quand le bouton gauche est maintenu enfoncé sur le Mac.
    @State private var isHoldingClick = false

    private var isPaired: Bool { connection.pairingState == .paired }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: Design.Space.normal) {
                ConnectionPill(isConnected: isPaired, text: statusText)

                MagicSurface {
                    TrackpadSurface(pointerSensitivity: pointerSensitivity,
                                    scrollSensitivity: scrollSensitivity,
                                    pointerAcceleration: pointerAcceleration,
                                    momentum: scrollMomentum,
                                    haptics: hapticsEnabled,
                                    naturalScrolling: naturalScrolling,
                                    threeFingerGestures: threeFingerGestures,
                                    send: send)
                        .overlay { gestureHint }
                }

                buttonRow
                actionBar

                if showSpeeds { speeds }
            }
            .padding(.horizontal, Design.Space.wide)
            // Mode une main : les commandes remontent du bas de l'écran pour
            // rester à portée du pouce, et la surface perd un peu de hauteur.
            .padding(.bottom, oneHanded ? Design.Space.wide * 2 : Design.Space.tight)
            // `colorSchemeContrast` est en lecture seule : on ne peut pas
            // l'imposer. On agit donc sur ce qui est réglable — graisse du
            // texte et contour des surfaces.
            .environment(\.legibilityWeight, highContrast ? .bold : nil)
        }
        .onAppear {
            configureAirMouse()
            configureTilt()
            if pocketModeEnabled { pocket.enable() }
        }
        .onDisappear {
            airMouse.stop()
            tilt.stop()
            pocket.disable()
            releaseHeldClick()
        }
        .onChange(of: pocketModeEnabled) { _, enabled in
            enabled ? pocket.enable() : pocket.disable()
        }
        .onChange(of: pocket.isCovered) { _, covered in
            // Le téléphone vient d'être couvert alors qu'un clic était
            // maintenu : le relâcher, sinon le Mac reste bloqué en glissement
            // pendant que l'iPhone est dans la poche.
            if covered { releaseHeldClick() }
        }
        .overlay { if pocket.isCovered { pocketOverlay } }
        .sheet(isPresented: $showKeyboard) {
            NavigationStack {
                KeyboardView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fermer") { showKeyboard = false }
                        }
                    }
            }
            // Hauteur ajustable : on garde le trackpad visible en dessous
            // quand on n'a que quelques touches à envoyer.
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }

    private var statusText: String {
        guard isPaired else { return "Recherche du Mac…" }
        return airMouse.isRunning
            ? "Souris en l'air · inclinez l'iPhone"
            : "1 doigt : curseur · 2 : défilement · 3 : glisser"
    }

    // MARK: - Rappel des gestes

    /// Occupe la surface tant qu'elle est vierge, puis s'efface — une grande
    /// zone blanche sans indication ne dit pas ce qu'on peut y faire.
    @ViewBuilder
    private var gestureHint: some View {
        if !hasTouched {
            VStack(spacing: 18) {
                hintRow("hand.point.up.left.fill", "1 doigt", "déplacer le curseur")
                hintRow("hand.draw.fill", "2 doigts", "défiler · écarter pour zoomer")
                hintRow("hand.raised.fill", "3 doigts",
                        threeFingerGestures ? "Mission Control · bureaux" : "glisser-déposer")
                hintRow("hand.point.up.braille.fill", "4 doigts", "bureau · recherche")
            }
            .foregroundStyle(.secondary)
            .opacity(0.55)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func hintRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.footnote.weight(.semibold))
                Text(detail).font(.caption2)
            }
            Spacer()
        }
        .frame(width: 210)
    }

    // MARK: - Boutons physiques

    /// Deux zones de clic sous la surface, comme les boutons intégrés d'un
    /// Magic Trackpad.
    private var buttonRow: some View {
        HStack(spacing: 10) {
            MouseButton(label: "Clic gauche", systemImage: "cursorarrow.click") {
                click(0)
            }
            MouseButton(label: "Clic droit", systemImage: "cursorarrow.click.2") {
                click(1)
            }
            // Clic maintenu : le bouton gauche reste enfoncé jusqu'au
            // prochain appui.
            //
            // C'est ce qui manquait pour **déplacer une fenêtre** ou la
            // **redimensionner** : ces deux gestes demandent de garder le
            // bouton enfoncé pendant qu'on déplace le curseur, ce qu'aucun
            // appui bref ne permet. L'appui-glisser et le glisser à trois
            // doigts n'y suffisent pas non plus, puisqu'ils relâchent dès que
            // le doigt se lève.
            MouseButton(label: isHoldingClick ? "Relâcher le clic" : "Maintenir le clic",
                        systemImage: isHoldingClick ? "hand.raised.fill" : "hand.raised",
                        isActive: isHoldingClick) {
                toggleHoldClick()
            }
        }
        // Boutons plus hauts en mode une main : le pouce vise moins bien que
        // l'index, une cible de 54 points lui demande de la précision.
        .frame(height: oneHanded ? 72 : 54)
    }

    // MARK: - Barre d'actions

    private var actionBar: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                toolButton("dot.circle.and.hand.point.up.left.fill",
                           active: airMouse.isRunning,
                           disabled: !airMouse.isAvailable) {
                    toggleAirMouse()
                }
                toolButton("scope", active: false, disabled: !airMouse.isRunning) {
                    airMouse.recenter()
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
                // Défilement par inclinaison : le doigt reste libre.
                toolButton("arrow.up.and.down.circle",
                           active: tilt.isRunning,
                           disabled: !tilt.isAvailable) {
                    toggleTilt()
                }
                toolButton("speedometer", active: showSpeeds, disabled: false) {
                    withAnimation(.snappy) { showSpeeds.toggle() }
                }
                // Le clavier s'ouvre en feuille par-dessus le trackpad : on
                // revient d'un geste, sans changer d'onglet ni perdre sa
                // place. Passer par l'onglet Clavier oblige à faire un
                // aller-retour à chaque mot.
                toolButton("keyboard", active: showKeyboard, disabled: false) {
                    showKeyboard = true
                }
            }
        }
    }

    private func toolButton(_ icon: String, active: Bool, disabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.white : Color.primary)
        .glassSurface(tint: active ? .accentColor : nil, interactive: true)
        .opacity(disabled ? 0.35 : 1)
        .disabled(disabled)
    }

    // MARK: - Vitesses

    private var speeds: some View {
        GlassTile {
            VStack(spacing: 10) {
                slider("Curseur", value: $pointerSensitivity, range: 0.5...4)
                slider("Défilement", value: $scrollSensitivity, range: 0.5...6)
                if airMouse.isRunning {
                    slider("Souris en l'air", value: $airSensitivity, range: 0.3...3)
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.1f×", value.wrappedValue)).monospacedDigit()
            }
            .font(.footnote)
            Slider(value: value, in: range, step: 0.1)
                .onChange(of: value.wrappedValue) { _, new in
                    if title == "Souris en l'air" { airMouse.sensitivity = new }
                }
        }
    }

    // MARK: - Envoi

    private func send(_ message: Message) {
        // Mode poche : rien ne sort tant que l'écran est couvert.
        //
        // Le filtre est ici, sur le seul chemin qu'empruntent les gestes de la
        // surface — pas dans chaque geste. Un téléphone rangé sans verrouiller
        // envoyait sinon des clics et des mouvements au hasard, et le curseur
        // partait tout seul sans qu'on comprenne d'où ça venait.
        guard !pocket.isCovered else { return }

        if !hasTouched {
            withAnimation(.easeOut(duration: 0.35)) { hasTouched = true }
        }
        // Un clic perdu laisserait le bouton coincé : il part en fiable.
        connection.send(message, reliable: message.kind == Message.Kind.click)
    }

    /// Maintient ou relâche le bouton gauche sur le Mac.
    private func toggleHoldClick() {
        isHoldingClick.toggle()
        if hapticsEnabled {
            // Appui franc à la prise, léger au relâchement : on sait dans quel
            // sens on vient de basculer sans regarder l'écran.
            UIImpactFeedbackGenerator(style: isHoldingClick ? .heavy : .light)
                .impactOccurred()
        }
        connection.send(.click(button: 0, down: isHoldingClick))
    }

    /// Relâche un clic resté maintenu.
    ///
    /// Sans ça, quitter l'écran laisserait le bouton enfoncé sur le Mac : tout
    /// mouvement de curseur deviendrait un glissement, et rien sur l'iPhone
    /// n'expliquerait pourquoi.
    private func releaseHeldClick() {
        guard isHoldingClick else { return }
        isHoldingClick = false
        connection.send(.click(button: 0, down: false))
    }

    private func click(_ button: Int) {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        }
        connection.send(.click(button: button, down: true))

        // Un clic a une durée. L'enfoncement et le relâchement partaient
        // jusqu'ici dans la même milliseconde, et le WindowServer fusionne
        // les événements arrivés ensemble — c'est le même piège que les 12 ms
        // entre frappes clavier, déjà payé une fois dans ce projet.
        //
        // Le clic gauche y survivait, le clic droit non : le menu contextuel
        // s'ouvre sur l'enfoncement et se referme aussitôt sur un
        // relâchement jugé simultané.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [connection] in
            connection.send(.click(button: button, down: false))
        }
    }

    /// Voile affiché quand le téléphone est couvert.
    ///
    /// Visible plutôt que silencieux : sans repère, on croirait l'app plantée.
    private var pocketOverlay: some View {
        ZStack {
            Color.black.opacity(0.82)
            VStack(spacing: 10) {
                Image(systemName: "hand.raised.slash.fill")
                    .font(.system(size: 40))
                Text("Mode poche")
                    .font(.headline)
                Text("Entrées ignorées tant que l'écran est couvert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .animation(.easeOut(duration: 0.2), value: pocket.isCovered)
    }

    // MARK: - Défilement par inclinaison

    private func configureTilt() {
        tilt.sensitivity = tiltSensitivity
        tilt.onScroll = { [connection] amount in
            connection.send(.scroll(dx: 0, dy: amount, phase: .changed), reliable: false)
        }
    }

    private func toggleTilt() {
        if tilt.isRunning {
            tilt.stop()
        } else {
            configureTilt()
            tilt.start()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Souris gyroscopique

    private func configureAirMouse() {
        airMouse.sensitivity = airSensitivity
        airMouse.onMove = { dx, dy in
            connection.send(.trackpad(dx: dx * pointerSensitivity,
                                      dy: dy * pointerSensitivity),
                            reliable: false)
        }
    }

    private func toggleAirMouse() {
        if airMouse.isRunning {
            airMouse.stop()
        } else {
            airMouse.start()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Surface Magic Mouse

/// Habillage de la surface tactile : galbe, reflet et ombre d'un périphérique
/// Apple posé sur le bureau.
struct MagicSurface<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(shell)
            .clipShape(RoundedRectangle(cornerRadius: Design.Radius.surface, style: .continuous))
            .overlay(highlight)
            .overlay(
                RoundedRectangle(cornerRadius: Design.Radius.surface, style: .continuous)
                    .strokeBorder(scheme == .dark
                                  ? Color.white.opacity(0.10)
                                  : Color.black.opacity(0.08),
                                  lineWidth: 1)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.18),
                    radius: 18, x: 0, y: 10)
    }

    /// Dégradé vertical : le galbe d'une Magic Mouse capte plus de lumière
    /// sur le haut de la coque.
    private var shell: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Design.deviceDark, Design.deviceDarkShade]
                : [Design.deviceLight, Design.deviceShade],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Reflet allongé dans le haut de la coque, plus la couture qui sépare la
    /// zone tactile du corps sur une Magic Mouse.
    private var highlight: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: Design.Radius.surface, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(scheme == .dark ? 0.10 : 0.55),
                                 Color.white.opacity(0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            Capsule()
                .fill(scheme == .dark
                      ? Color.white.opacity(0.10)
                      : Color.black.opacity(0.07))
                .frame(width: 54, height: 4)
                .padding(.top, 12)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Bouton de clic

struct MouseButton: View {
    let label: String
    let systemImage: String
    /// Bouton à bascule resté enfoncé : il doit se voir d'un coup d'œil,
    /// sinon on oublie que le bouton de la souris est maintenu et tout ce
    /// qu'on touche ensuite devient un glissement.
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.footnote.weight(.medium))
                .labelStyle(.iconOnly)
                .foregroundStyle(isActive ? Color.accentColor : .primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassSurface(cornerRadius: Design.Radius.tile, interactive: true)
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: Design.Radius.tile, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
