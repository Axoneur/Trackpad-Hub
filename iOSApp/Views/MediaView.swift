import SwiftUI

/// Contrôles média et mode présentation.
struct MediaView: View {
    @EnvironmentObject private var connection: MessageConnection

    @State private var presenting = false
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?

    private var isPaired: Bool { connection.pairingState == .paired }

    var body: some View {
        NavigationStack {
            GlassScreen(title: "Média",
                        isConnected: isPaired,
                        statusText: isPaired
                            ? "Connecté · contrôles envoyés à votre Mac"
                            : "Non connecté au Mac") {
                HandoffCard()
                transportSection
                volumeSection
                brightnessSection
                presentationSection
            }
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Lecture

    private var transportSection: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Lecture", systemImage: "music.note")
            HStack(spacing: 10) {
                GlassActionButton(icon: "backward.fill", label: "Précédent") {
                    connection.send(.media("prev"))
                }
                GlassActionButton(icon: "playpause.fill", label: "Lecture",
                                  tint: .accentColor, isProminent: true) {
                    connection.send(.media("playpause"))
                }
                GlassActionButton(icon: "forward.fill", label: "Suivant") {
                    connection.send(.media("next"))
                }
            }
        }
    }

    // MARK: - Volume

    @State private var volume: Double = 0.5

    private var volumeSection: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Volume", systemImage: "speaker.wave.2")

            GlassTile {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $volume, in: 0...1) { editing in
                            // On n'envoie qu'au relâchement : un curseur émet
                            // des dizaines de valeurs par seconde, inutile de
                            // toutes les faire traverser le réseau.
                            if !editing { connection.send(.media("volume:\(volume)")) }
                        }
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                        Text("\(Int(volume * 100))")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }

                    HStack(spacing: 10) {
                        GlassActionButton(icon: "speaker.minus.fill", label: "Baisser") {
                            connection.send(.media("voldown"))
                            volume = max(volume - 0.0625, 0)
                        }
                        GlassActionButton(icon: "speaker.slash.fill", label: "Muet") {
                            connection.send(.media("mute"))
                        }
                        GlassActionButton(icon: "speaker.plus.fill", label: "Monter") {
                            connection.send(.media("volup"))
                            volume = min(volume + 0.0625, 1)
                        }
                    }
                }
            }
        }
    }

    private var brightnessSection: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Écran", systemImage: "sun.max")
            HStack(spacing: 10) {
                GlassActionButton(icon: "sun.min", label: "Moins clair") {
                    connection.send(.media("brightdown"))
                }
                GlassActionButton(icon: "sun.max.fill", label: "Plus clair") {
                    connection.send(.media("brightup"))
                }
                GlassActionButton(icon: "display", label: "Éteindre") {
                    connection.send(.system(.displaySleep))
                }
            }
        }
    }

    // MARK: - Présentation

    private var presentationSection: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Présentation", systemImage: "rectangle.on.rectangle")

            GlassTile {
                VStack(spacing: 14) {
                    HStack {
                        Text(formattedElapsed)
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Spacer()
                        Button(presenting ? "Arrêter" : "Démarrer") {
                            presenting ? endPresentation() : beginPresentation()
                        }
                        .prominentGlassButton()
                        .tint(presenting ? .red : .accentColor)
                    }

                    HStack(spacing: 10) {
                        GlassActionButton(icon: "chevron.left", label: "Précédente") {
                            connection.send(.presentation(.previous))
                        }
                        GlassActionButton(icon: "chevron.right", label: "Suivante",
                                          tint: .accentColor, isProminent: true) {
                            connection.send(.presentation(.next))
                        }
                    }

                    HStack(spacing: 10) {
                        GlassActionButton(icon: "moon.stars.fill", label: "Écran noir") {
                            connection.send(.presentation(.blackScreen))
                        }
                        GlassActionButton(icon: "sun.max.fill", label: "Écran blanc") {
                            connection.send(.presentation(.whiteScreen))
                        }
                    }

                    Text("Fonctionne avec Keynote, PowerPoint, Google Slides et Aperçu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var formattedElapsed: String {
        let total = Int(elapsed)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func beginPresentation() {
        presenting = true
        elapsed = 0
        connection.send(.presentation(.start))
        startTimer()
    }

    private func endPresentation() {
        presenting = false
        connection.send(.presentation(.end))
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsed += 1
                // Vibration discrète à chaque minute, pour suivre son temps
                // sans regarder l'écran.
                if Int(elapsed) % 60 == 0 {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
