import SwiftUI

/// Mode jeu : une vraie manette, plein écran.
///
/// ## Pourquoi plein écran et sans défilement
///
/// Une manette se tient à deux mains, pouces aux extrémités, sans regarder.
/// Des boutons posés dans une page qui défile obligent à viser, et un
/// glissement du pouce fait défiler la page au lieu de bouger le personnage.
/// D'où un écran dédié : barre de navigation masquée, aucun défilement, tout
/// dimensionné à partir de la taille réelle de l'écran.
///
/// ## Ce qu'envoie chaque commande
///
/// Des **touches maintenues**, pas des frappes. Un vrai gamepad supposerait un
/// pilote HID virtuel installé sur le Mac — projet séparé, avec installeur.
/// Les jeux Mac lisent presque tous le clavier, ce qui rend cette voie
/// suffisante et sans rien à installer.
struct GamingView: View {
    @EnvironmentObject private var connection: MessageConnection

    /// Directions, dans l'ordre haut, gauche, bas, droite.
    @AppStorage("gamingKeys") private var directionsRaw = "zqsd"
    /// Boutons de face, dans l'ordre haut, gauche, bas, droite du losange.
    @AppStorage("gamingButtons") private var faceRaw = "ef r"
    /// Gâchettes : L1, R1, L2, R2.
    @AppStorage("gamingShoulders") private var shouldersRaw = "ac12"

    @State private var held: Set<Character> = []
    @State private var stick: CGSize = .zero
    @State private var showsSettings = false

    private var directions: [Character] { padded(directionsRaw) }
    private var face: [Character] { padded(faceRaw) }
    private var shoulders: [Character] { padded(shouldersRaw) }

    /// Quatre caractères, quoi qu'il arrive : un réglage incomplet ne doit pas
    /// faire disparaître des boutons.
    private func padded(_ raw: String) -> [Character] {
        let characters = Array(raw)
        return (0..<4).map { $0 < characters.count ? characters[$0] : " " }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()

                VStack(spacing: 0) {
                    shoulderRow(width: geometry.size.width)
                    Spacer(minLength: 0)
                    mainRow(in: geometry.size)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                statusOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // Filet de sécurité : sortir avec une touche enfoncée ferait avancer
        // le personnage indéfiniment, sans rien pour l'expliquer.
        .onDisappear { releaseAll() }
        .sheet(isPresented: $showsSettings) { settingsSheet }
    }

    // MARK: - Gâchettes

    private func shoulderRow(width: CGFloat) -> some View {
        HStack {
            HStack(spacing: 10) {
                trigger(shoulders[0], label: "L1", wide: true)
                trigger(shoulders[2], label: "L2", wide: false)
            }
            Spacer()
            Button {
                showsSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(10)
            }
            Spacer()
            HStack(spacing: 10) {
                trigger(shoulders[3], label: "R2", wide: false)
                trigger(shoulders[1], label: "R1", wide: true)
            }
        }
    }

    private func trigger(_ key: Character, label: String, wide: Bool) -> some View {
        Text(label)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .frame(width: wide ? 86 : 62, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(held.contains(key) ? Color.accentColor : Color.white.opacity(0.12)))
            .foregroundStyle(held.contains(key) ? .white : .white.opacity(0.75))
            .contentShape(.rect)
            .gesture(hold(key))
    }

    // MARK: - Rangée principale

    private func mainRow(in size: CGSize) -> some View {
        // Le manche et le losange occupent chacun un tiers de la largeur, avec
        // un vide au centre : c'est là que se posent les paumes.
        let side = min(max(size.height * 0.62, 180), size.width * 0.34)
        return HStack(alignment: .center) {
            joystick(diameter: side)
            Spacer(minLength: 0)
            faceButtons(diameter: side)
        }
    }

    // MARK: - Manche

    private func joystick(diameter: CGFloat) -> some View {
        let limit = diameter * 0.32
        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 2))
            Circle()
                .fill(Color.accentColor.opacity(0.9))
                .frame(width: diameter * 0.38, height: diameter * 0.38)
                .offset(stick)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Le manche reste dans son cercle : on borne le rayon au
                    // lieu de borner chaque axe, sinon les diagonales
                    // sortiraient du disque.
                    let raw = CGVector(dx: value.translation.width,
                                       dy: value.translation.height)
                    let distance = max(sqrt(raw.dx * raw.dx + raw.dy * raw.dy), 0.001)
                    let scale = min(distance, limit) / distance
                    stick = CGSize(width: raw.dx * scale, height: raw.dy * scale)
                    updateDirections(limit: limit)
                }
                .onEnded { _ in
                    stick = .zero
                    releaseDirections()
                }
        )
    }

    /// Traduit la position du manche en touches maintenues.
    ///
    /// Seuil au tiers de la course : sans zone morte, un pouce simplement posé
    /// enverrait déjà une direction.
    private func updateDirections(limit: CGFloat) {
        let threshold = limit / 3
        let wanted: [Character] = [
            stick.height < -threshold ? directions[0] : nil,
            stick.width  < -threshold ? directions[1] : nil,
            stick.height >  threshold ? directions[2] : nil,
            stick.width  >  threshold ? directions[3] : nil
        ].compactMap { $0 }

        // On n'émet que les changements : réémettre « enfoncé » soixante fois
        // par seconde saturerait la liaison sans rien apporter.
        for key in wanted where !held.contains(key) { press(key, down: true) }
        for key in held.subtracting(wanted) where directions.contains(key) {
            press(key, down: false)
        }
    }

    private func releaseDirections() {
        for key in held where directions.contains(key) { press(key, down: false) }
    }

    // MARK: - Boutons de face

    private func faceButtons(diameter: CGFloat) -> some View {
        let button = diameter * 0.40
        return ZStack {
            faceButton(face[0], size: button).offset(y: -diameter * 0.30)
            faceButton(face[1], size: button).offset(x: -diameter * 0.30)
            faceButton(face[2], size: button).offset(y: diameter * 0.30)
            faceButton(face[3], size: button).offset(x: diameter * 0.30)
        }
        .frame(width: diameter, height: diameter)
    }

    private func faceButton(_ key: Character, size: CGFloat) -> some View {
        Text(key == " " ? "␣" : String(key).uppercased())
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .frame(width: size, height: size)
            .background(
                Circle().fill(held.contains(key)
                              ? Color.accentColor
                              : Color.white.opacity(0.13)))
            .foregroundStyle(held.contains(key) ? .white : .white.opacity(0.85))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            .contentShape(Circle())
            .gesture(hold(key))
    }

    // MARK: - Appui maintenu

    /// Un même geste pour tous les boutons : enfoncé au contact, relâché au
    /// lever. `minimumDistance: 0` déclenche dès le toucher, là où un `Button`
    /// n'agit qu'au relâchement — inutilisable pour maintenir une direction.
    private func hold(_ key: Character) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in if !held.contains(key) { press(key, down: true) } }
            .onEnded { _ in press(key, down: false) }
    }

    private func press(_ key: Character, down: Bool) {
        guard key != " " || down else {
            held.remove(key)
            connection.send(.keyHold(key, down: false))
            return
        }
        if down {
            held.insert(key)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.65)
        } else {
            held.remove(key)
        }
        connection.send(.keyHold(key, down: down))
    }

    private func releaseAll() {
        for key in held { connection.send(.keyHold(key, down: false)) }
        held.removeAll()
        stick = .zero
    }

    // MARK: - État

    private var statusOverlay: some View {
        VStack {
            Spacer()
            if connection.pairingState != .paired {
                Text("Non connecté au Mac")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.black.opacity(0.6)))
                    .padding(.bottom, 8)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Réglages

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Directions") {
                    keyField("Haut, gauche, bas, droite", text: $directionsRaw)
                }
                Section("Boutons de face") {
                    keyField("Haut, gauche, bas, droite du losange", text: $faceRaw)
                }
                Section("Gâchettes") {
                    keyField("L1, R1, L2, R2", text: $shouldersRaw)
                }
                Section {
                    Text("Quatre caractères par ligne, dans l'ordre indiqué. Un espace laisse le bouton en place mais envoie la barre d'espace.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Par défaut ZQSD, adapté aux claviers AZERTY. Le Mac résout la touche physique contre sa disposition active : la touche visée est bien celle que vous avez sous le doigt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Touches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { showsSettings = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func keyField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(label, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
