import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connection: MessageConnection

    /// Faux tant que la présentation du premier lancement n'a pas été vue.
    @AppStorage(ReglagesRappels.presentationVue) private var presentationVue = false
    @State private var montrerPresentation = false

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
        // Portée par la vue, et non par la structure `App` : une feuille
        // demandée depuis un `@State` de l'`App` n'est pas présentée — mesuré,
        // le drapeau passait bien à vrai sans que rien n'apparaisse.
        //
        // `.task` plutôt que `.onAppear` : la feuille est demandée après
        // l'installation de la hiérarchie, pas pendant.
        .sheet(isPresented: $montrerPresentation) {
            RappelsIntroSheet()
        }
        .task {
            guard !presentationVue else { return }
            montrerPresentation = true
            TraceiOS.action("présentation du premier lancement affichée")
        }
    }

    /// Point d'entrée unique de l'écran d'appairage : celui que le Mac
    /// réclame, et celui que l'utilisateur ouvre depuis les réglages.
    private var needsPairing: Bool {
        connection.pairingState == .awaitingPin
            || connection.pairingState == .refused
            || connection.isPairingRequested
    }
}
