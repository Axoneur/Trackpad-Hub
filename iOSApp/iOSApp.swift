import SwiftUI

@main
struct iOSApp: App {
    @StateObject private var connection: MessageConnection
    @StateObject private var macState = MacState()
    @StateObject private var macros = MacroStore()
    @StateObject private var stats = UsageStats()
    @StateObject private var releases = ReleaseChecker()

    init() {
        // Avant toute lecture : le programmateur des rappels lit les
        // préférences hors de toute vue, et obtiendrait `false` partout tant
        // que les valeurs par défaut ne sont pas enregistrées.
        ReglagesRappels.enregistrerDefauts()

        let name = UIDevice.current.name.isEmpty ? "iPhone" : UIDevice.current.name
        _connection = StateObject(wrappedValue: MessageConnection(displayName: name, isHost: false))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connection)
                .environmentObject(macState)
                .environmentObject(macros)
                .environmentObject(stats)
                .environmentObject(releases)
                .onAppear {
                    // Les réponses du Mac (apps, presse-papiers, constantes)
                    // alimentent le miroir local.
                    connection.onMessage = { [weak macState] message, _ in
                        Task { @MainActor in macState?.handle(message) }
                    }
                    // Capture des actions émises, pour l'enregistrement des
                    // macros. Branché ici plutôt que dans chaque écran : tout
                    // passe par ce point unique.
                    macros.attach(to: connection)
                    // Après les macros : le comptage chaîne le crochet
                    // existant au lieu de l'écraser.
                    stats.attach(to: connection)
                    connection.start()
                    // Au lancement, une fois par jour au plus.
                    releases.verifier()
                    // Déposées d'avance : quand la signature expire, l'app ne
                    // s'ouvre plus et ne peut donc plus prévenir de rien.
                    // Ne demande aucune autorisation : c'est la présentation
                    // ci-dessous qui s'en charge, après avoir expliqué.
                    ExpiryNotice.programmer()

                }
                .onChange(of: connection.pairingState) { _, state in
                    SharedStore.isPaired = (state == .paired)
                    state == .paired ? stats.markConnected() : stats.markDisconnected()
                    // Une intention Siri ou un bouton de widget a ouvert
                    // l'app : on exécute l'action dès que la liaison est
                    // autorisée.
                    guard state == .paired, let pending = SharedStore.takePending() else { return }
                    connection.send(pending)
                }
        }
    }
}
