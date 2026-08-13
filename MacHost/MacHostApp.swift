import SwiftUI

@main
struct MacHostApp: App {
    @StateObject private var connection: MessageConnection
    @StateObject private var router: Router
    @StateObject private var menuBar = MenuBarController()
    @Environment(\.openWindow) private var openWindow

    @StateObject private var panels = PanelState()

    static let mainWindow = "main"

    /// Panneaux ouverts dans la fenêtre principale, pilotables depuis la
    /// barre des menus.
    @MainActor
    final class PanelState: ObservableObject {
        @Published var showDiagnostics = false
    }

    init() {
        let router = Router()
        let hostName = Host.current().localizedName ?? "Mac"
        let connection = MessageConnection(displayName: hostName, isHost: true)
        connection.onMessage = { [weak router] message, peer in
            router?.replyPeer = peer
            router?.handle(message)
        }
        // Un iPhone qui disparaît au milieu d'un glisser-déposer laisserait
        // le bouton de la souris enfoncé.
        connection.onPeerLost = { [weak router] _ in
            router?.mouse.releaseAllButtons()
        }
        // Canal de retour : liste des apps, presse-papiers, constantes.
        router.reply = { [weak connection, weak router] message in
            guard let connection else { return }
            // Au pair qui a posé la question, et à personne d'autre.
            if let peer = router?.replyPeer {
                connection.reply(message, to: peer)
            } else {
                connection.send(message)
            }
        }
        // Un appareil qui vient d'être autorisé reçoit l'état courant. Le
        // média en lecture ne change pas forcément après sa connexion : sans
        // cet envoi, il ne le verrait jamais.
        connection.onPeerAuthenticated = { [weak router, weak connection] peer in
            guard let router, let connection else { return }
            connection.reply(.handoffData(json: router.encodedHandoff()), to: peer)
        }

        // Transmis à l'iPhone lors de l'appairage, pour qu'il puisse réveiller
        // ce Mac quand il dort.
        connection.hostNetworkIdentity = (NetworkIdentity.macAddress(),
                                          NetworkIdentity.broadcastAddress())

        // Fichiers envoyés depuis l'iPhone.
        let receiver = FileReceiver()
        connection.onFileReceived = { url, name in
            receiver.receive(from: url, named: name)
        }
        FileReceiver.requestNotificationAccess()
        _connection = StateObject(wrappedValue: connection)
        _router = StateObject(wrappedValue: router)
    }

    var body: some Scene {
        // Une seule scène, volontairement.
        //
        // Une seconde fenêtre déclarée à côté faisait démarrer l'app sur
        // celle-ci, et macOS restaurait ensuite cet état à chaque lancement.
        // Le diagnostic est donc un panneau *dans* cette fenêtre, ouvert par
        // un drapeau partagé que la barre des menus peut lever.
        WindowGroup(id: Self.mainWindow) {
            ContentView()
                .environmentObject(connection)
                .environmentObject(router)
                .environmentObject(panels)
                .frame(minWidth: 460, minHeight: 620)
                .onAppear {
                    connection.start()
                    router.clipboard.startWatching()
                    router.handoff.startWatching()

                    // Demande d'automatisation au lancement, au calme.
                    //
                    // La réclamer au milieu d'un geste est le pire moment :
                    // la fenêtre système vole le focus et le geste échoue.
                    // Au lancement, l'utilisateur répond une fois pour toutes.
                    //
                    // Ce script s'exécute sur la file principale : lancé en
                    // arrière-plan, il n'atteignait jamais le gestionnaire
                    // d'événements Apple, et aucune fenêtre n'apparaissait.
                    router.system.requestAutomationAccess()
                    menuBar.attach(connection: connection, router: router)
                    menuBar.onShowWindow = { openWindow(id: Self.mainWindow) }
                    menuBar.onShowDiagnostics = { [weak panels] in
                        openWindow(id: Self.mainWindow)
                        panels?.showDiagnostics = true
                    }
                }
        }
    }
}
