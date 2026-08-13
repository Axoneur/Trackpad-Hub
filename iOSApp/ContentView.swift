import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connection: MessageConnection

    var body: some View {
        TabView {
            Tab("Trackpad", systemImage: "rectangle.and.hand.point.up.left") {
                TrackpadView()
            }
            Tab("Clavier", systemImage: "keyboard") {
                KeyboardView()
            }
            Tab("Média", systemImage: "playpause.fill") {
                MediaView()
            }
            // Cinq onglets au maximum : au-delà, iOS replie le surplus dans un
            // onglet « More » qui casse la lecture. Les raccourcis vivent donc
            // dans l'onglet Mac.
            Tab("Mac", systemImage: "desktopcomputer") {
                MacView()
            }
            Tab("Réglages", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        // L'appairage recouvre l'app : sans lui, aucune commande ne part.
        .overlay {
            if needsPairing {
                PairingView()
                    .background(.regularMaterial)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: needsPairing)
    }

    /// Point d'entrée unique de l'écran d'appairage : celui que le Mac
    /// réclame, et celui que l'utilisateur ouvre depuis les réglages.
    private var needsPairing: Bool {
        connection.pairingState == .awaitingPin
            || connection.pairingState == .refused
            || connection.isPairingRequested
    }
}
