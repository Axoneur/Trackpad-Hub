import Foundation
import Combine

/// État de l'appairage, tel qu'affiché dans l'interface.
enum PairingState: Equatable {
    /// Aucun pair connecté.
    case idle
    /// Session réseau établie, appairage en cours de vérification.
    case verifying
    /// Le Mac attend que le code affiché soit saisi sur l'iPhone.
    case awaitingPin
    /// Appairé : les messages de contrôle passent.
    case paired
    /// Code refusé.
    case refused
}

/// Appairage et acheminement des messages, au-dessus de `DirectLink`.
///
/// Le transport est une liaison directe TCP + UDP en Network.framework : le
/// Mac annonce le service Bonjour, l'iPhone le cherche. MultipeerConnectivity
/// a été retiré — sa surcouche de session coûtait trop cher sur le chemin du
/// curseur. Voir `DirectLink` pour le détail des deux canaux.
///
/// ## Sécurité
///
/// Établir la connexion ne donne **aucun** droit : tant qu'un pair n'a pas
/// prouvé qu'il connaît le code d'appairage (ou son jeton permanent), tous
/// ses messages de contrôle sont jetés. Sans cette étape, n'importe quel
/// appareil du réseau Wi-Fi prendrait la main sur le Mac.
///
/// Le chiffrement de la liaison démarre **après** l'appairage, avec une clé
/// dérivée du jeton. Les messages d'appairage voyagent donc en clair — c'est
/// sans danger par construction, seule une preuve HMAC circule.
final class MessageConnection: NSObject, ObservableObject {

    /// Identité d'un pair. Remplace l'ancien `MCPeerID`.
    typealias Peer = DirectLink.Peer

    /// Clés de préférences utilisées pour le réveil à distance.
    static let wakeMacAddressKey = "wakeMacAddress"
    static let wakeBroadcastKey = "wakeBroadcastAddress"
    static let lastHostNameKey = "lastHostName"

    @Published private(set) var connectedPeers: [Peer] = []
    @Published private(set) var isConnected = false
    @Published private(set) var pairingState: PairingState = .idle

    /// Code à 6 chiffres affiché sur le Mac pendant un appairage.
    @Published private(set) var displayedPin: String?

    /// Appareils déjà appairés (affichés dans les réglages du Mac).
    @Published private(set) var pairedDevices: [(id: String, device: PairedDevice)] = []

    let displayName: String
    let isHost: Bool

    /// Callback des messages reçus — uniquement ceux de pairs appairés.
    var onMessage: ((Message, Peer) -> Void)?

    /// Appelé quand un appareil vient d'être autorisé.
    ///
    /// Sert à lui envoyer tout de suite l'état courant du Mac — média en
    /// lecture, par exemple. Sans ça, un état qui ne change plus n'est jamais
    /// transmis à un appareil qui se connecte après coup.
    var onPeerAuthenticated: ((Peer) -> Void)?

    /// Appelé pour chaque message **émis**.
    ///
    /// Sert à l'enregistrement des macros : plutôt que d'instrumenter chaque
    /// bouton de l'interface, on capte le seul endroit par lequel tout passe.
    /// Une action ajoutée demain sera enregistrable sans qu'on y pense.
    var onSend: ((Message) -> Void)?

    /// Appelé quand un pair se déconnecte, pour relâcher les boutons restés
    /// enfoncés côté Mac.
    var onPeerLost: ((Peer) -> Void)?

    /// Progression d'un transfert de fichier, de 0 à 1. Nil = aucun transfert.
    @Published private(set) var transferProgress: Double?
    /// Nom du fichier en cours de transfert.
    @Published private(set) var transferName: String?

    /// Fichier reçu : (URL temporaire, nom d'origine).
    ///
    /// Le temporaire nous appartient désormais — MultipeerConnectivity
    /// l'effaçait dès le retour du callback, ce qui n'est plus le cas.
    var onFileReceived: ((URL, String) -> Void)?

    private let link: DirectLink
    private var isStarted = false

    // MARK: Secours Bluetooth

    /// Liaison de secours. Elle ne sert que si le Wi-Fi n'aboutit pas.
    private let bluetooth: BluetoothLink

    /// Pair synthétique du Bluetooth : il n'y a qu'un appareil en face, mais
    /// toute la logique d'appairage raisonne en `Peer`.
    private static let bluetoothPeer = Peer(id: "bluetooth", displayName: "Bluetooth")

    /// Chiffrement du canal Bluetooth, posé au même moment que celui du Wi-Fi.
    private var bluetoothCipher: SessionCipher?

    /// Vrai quand le Wi-Fi ne porte aucun pair : c'est la condition du repli.
    private var isWiFiIdle: Bool { link.peers.isEmpty }

    // MARK: Liaison filaire

    /// Liaison par le câble. **Prioritaire sur tout le reste** quand elle
    /// existe : 1 à 2 ms constantes, là où le Wi-Fi varie et où le Bluetooth
    /// plafonne à 15-30 ms.
    private let usb: USBLink

    private static let usbPeer = Peer(id: "usb", displayName: "USB")
    private var usbCipher: SessionCipher?

    // MARK: État d'appairage

    /// Côté Mac : défi envoyé à chaque pair, en attente de réponse.
    private var pendingNonces: [Peer: String] = [:]

    /// Code d'appairage en cours, valable pour **tout** appareil qui se
    /// présente, et non pour un pair précis.
    ///
    /// L'utilisateur l'affiche quand il veut ajouter un appareil ; il ne
    /// dépend donc pas d'un iPhone déjà connu du Mac. Un code lié à un pair
    /// n'apparaissait qu'après une tentative de connexion, ce qui rendait son
    /// affichage imprévisible.
    private var activePin: String?
    private var pinExpiry: Date?

    /// Durée de validité du code affiché.
    private let pinLifetime: TimeInterval = 300   // 5 minutes
    /// Pairs autorisés à piloter le Mac.
    private var authenticatedPeers: Set<Peer> = []
    /// Identité permanente annoncée par chaque pair.
    private var peerDeviceIDs: [Peer: String] = [:]
    /// Tentatives ratées, pour bloquer le brute-force sur 6 chiffres.
    private var failedAttempts: [Peer: Int] = [:]

    /// Côté iPhone : dernier défi reçu, conservé pour la saisie du code.
    private var currentNonce: String?
    private var hostPeerName: String?

    private let maxAttempts = 5

    init(displayName: String, isHost: Bool) {
        self.displayName = displayName
        self.isHost = isHost
        self.link = DirectLink(displayName: MessageConnection.sanitize(displayName),
                               isHost: isHost)
        self.bluetooth = BluetoothLink(isHost: isHost)
        self.usb = USBLink(isHost: isHost)
        super.init()
        wireLink()
        if isHost {
            pairedDevices = PairingStore.pairedDevices()
        }
    }

    /// Bonjour refuse un nom vide, et le tronque au-delà de 63 octets UTF-8.
    private static func sanitize(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Appareil" : trimmed
        var result = base
        while result.utf8.count > 63 {
            result.removeLast()
        }
        return result
    }

    // MARK: - Branchement du transport

    private func wireLink() {
        link.onPeerConnected = { [weak self] peer in
            DispatchQueue.main.async {
                guard let self else { return }
                self.connectedPeers = self.link.peers
                self.isConnected = !self.link.peers.isEmpty
                // C'est l'hôte qui ouvre l'appairage, dès qu'un appareil se
                // présente : le défi part avant tout autre échange.
                if self.isHost { self.challenge(peer) }
            }
        }

        link.onPeerLost = { [weak self] peer in
            DispatchQueue.main.async {
                guard let self else { return }
                self.connectedPeers = self.link.peers
                self.isConnected = !self.link.peers.isEmpty
                self.mutateAuthenticated { $0.remove(peer) }
                self.pendingNonces[peer] = nil
                self.peerDeviceIDs[peer] = nil
                self.onPeerLost?(peer)
                if self.link.peers.isEmpty {
                    self.displayedPin = nil
                    self.currentNonce = nil
                    self.pairingState = .idle
                }
            }
        }

        link.onData = { [weak self] data, peer in
            self?.receive(data, from: peer)
        }

        link.onFileReceived = { [weak self] url, name, peer in
            guard let self else { return }
            // Un pair non appairé n'a pas le droit de déposer un fichier.
            guard !self.isHost || self.isAuthenticated(peer) else { return }
            self.onFileReceived?(url, name)
        }

        link.onFileProgress = { [weak self] name, fraction in
            DispatchQueue.main.async {
                self?.transferName = name
                self?.transferProgress = fraction
            }
        }

        wireBluetooth()
        wireUSB()
    }

    /// Branchement de la liaison filaire.
    ///
    /// Même protocole, même appairage, même chiffrement que les deux autres
    /// transports : seul le tuyau change. Le câble ne donne aucun droit
    /// supplémentaire — brancher un iPhone inconnu ne le rend pas maître du
    /// Mac.
    private func wireUSB() {
        usb.onConnected = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isConnected = true
                if self.isHost { self.challenge(Self.usbPeer) }
            }
        }

        usb.onLost = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.usbCipher = nil
                self.mutateAuthenticated { $0.remove(Self.usbPeer) }
                if self.isWiFiIdle && !self.bluetooth.isConnected {
                    self.isConnected = false
                    self.pairingState = .idle
                }
            }
        }

        usb.onData = { [weak self] data in
            guard let self else { return }
            let payload: Data?
            if let cipher = self.usbCipher {
                payload = cipher.open(data, channel: self.isHost ? .usbFromClient : .usbFromHost)
            } else {
                payload = data
            }
            guard let payload else { return }
            self.receive(payload, from: Self.usbPeer)
        }
    }

    /// Branchement du secours Bluetooth.
    ///
    /// Le protocole est le même que sur le Wi-Fi — mêmes messages, même
    /// appairage, même chiffrement. Seul le tuyau change. C'est ce qui permet
    /// de basculer sans rien réapprendre côté application.
    private func wireBluetooth() {
        bluetooth.onConnected = { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.isWiFiIdle else { return }
                self.isConnected = true
                // L'hôte ouvre l'appairage ici aussi : la liaison Bluetooth ne
                // donne pas plus de droits que la Wi-Fi tant que la preuve
                // n'est pas faite.
                if self.isHost { self.challenge(Self.bluetoothPeer) }
            }
        }

        bluetooth.onLost = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.bluetoothCipher = nil
                self.mutateAuthenticated { $0.remove(Self.bluetoothPeer) }
                if self.isWiFiIdle {
                    self.isConnected = false
                    self.pairingState = .idle
                }
            }
        }

        bluetooth.onData = { [weak self] data in
            guard let self else { return }
            // Avant appairage, les messages voyagent en clair — ils ne portent
            // aucun secret. Après, le clair est refusé.
            let payload: Data?
            if let cipher = self.bluetoothCipher {
                payload = cipher.open(data, channel: self.isHost ? .bleFromClient : .bleFromHost)
            } else {
                payload = data
            }
            guard let payload else { return }
            self.receive(payload, from: Self.bluetoothPeer)
        }
    }

    // MARK: - Cycle de vie

    func start() {
        guard !isStarted else { return }
        isStarted = true
        link.start()
        // Le Bluetooth démarre en même temps mais ne sert qu'en dernier
        // recours : annoncer et scanner coûte peu, découvrir au moment où le
        // Wi-Fi tombe coûterait plusieurs secondes d'attente.
        bluetooth.start()
        usb.start()
    }

    func stop() {
        isStarted = false
        link.stop()
        bluetooth.stop()
        usb.stop()
        bluetoothCipher = nil
        usbCipher = nil
        resetPairingState()
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.start()
        }
    }

    private func resetPairingState() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.mutateAuthenticated { $0.removeAll() }
            self.pendingNonces.removeAll()
            self.peerDeviceIDs.removeAll()
            self.failedAttempts.removeAll()
            self.currentNonce = nil
            self.displayedPin = nil
            self.pairingState = .idle
            self.isConnected = false
            self.connectedPeers = []
        }
    }

    // MARK: - Envoi

    func send(_ message: Message, reliable: Bool = true) {
        // Côté iPhone : rien ne part tant que l'appairage n'est pas fait,
        // à l'exception des messages d'appairage eux-mêmes.
        if !isHost, message.isControlMessage, pairingState != .paired { return }
        onSend?(message)
        transmit(message, to: nil, reliable: reliable)
    }

    /// Réponse adressée **au pair qui a posé la question**.
    ///
    /// Indispensable dès qu'il y a plusieurs transports : une réponse envoyée
    /// « à la cantonade » part sur le premier transport de la liste de
    /// priorité, qui n'est pas forcément celui d'où venait la demande. C'est
    /// ce qui faisait disparaître la liste des apps et la carte média — elles
    /// partaient dans un tunnel USB dont plus personne n'écoutait l'autre bout.
    func reply(_ message: Message, to peer: Peer) {
        transmit(message, to: peer, reliable: true)
    }

    /// Envoi ciblé (appairage). `peer` nil = tous les pairs connectés.
    private func send(_ message: Message, to peer: Peer?) {
        transmit(message, to: peer, reliable: true)
    }

    /// File des événements de pointage : série pour garder l'ordre, et de
    /// priorité maximale car c'est elle qui porte la sensation de réactivité.
    private let inputQueue = DispatchQueue(label: "com.trackpadhub.input",
                                           qos: .userInteractive)

    /// Verrou sur la liste des pairs autorisés, désormais lue depuis deux
    /// files distinctes.
    private let authLock = NSLock()

    private func isAuthenticated(_ peer: Peer) -> Bool {
        authLock.lock()
        defer { authLock.unlock() }
        return authenticatedPeers.contains(peer)
    }

    /// Toute modification de la liste passe par ici : elle est désormais lue
    /// depuis la file d'entrée comme depuis la file principale.
    private func mutateAuthenticated(_ change: (inout Set<Peer>) -> Void) {
        authLock.lock()
        change(&authenticatedPeers)
        authLock.unlock()
    }

    private var isAuthenticatedEmpty: Bool {
        authLock.lock()
        defer { authLock.unlock() }
        return authenticatedPeers.isEmpty
    }

    private func isPointerEvent(_ message: Message) -> Bool {
        switch message.kind {
        case Message.Kind.trackpad, Message.Kind.scroll,
             Message.Kind.zoom, Message.Kind.click:
            return true
        default:
            return false
        }
    }

    /// Encodeur et décodeur réutilisés.
    ///
    /// En construire un neuf à chaque message coûtait une allocation et une
    /// mise en place complètes, jusqu'à 120 fois par seconde.
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func transmit(_ message: Message, to peer: Peer?, reliable: Bool) {
        // Format compact pour les messages fréquents, JSON pour le reste.
        let data: Data?
        if let fast = FastPacket.encode(message) {
            data = fast
        } else {
            data = try? encoder.encode(message)
        }
        guard let data else { return }

        // `DirectLink.send` bascule aussitôt sur sa propre file série : l'envoi
        // quitte donc la file appelante, ce qui compte quand l'appel vient de
        // `touchesMoved` — sinon le doigt bougeait déjà que l'app émettait
        // encore le mouvement précédent.
        //
        // Pas de file intermédiaire ici : elle ferait perdre l'ordre relatif
        // entre un message et l'installation de la clé de session, qui passe
        // directement par la file du transport.
        // **Un message adressé part sur le transport de son destinataire.**
        //
        // C'est le point qu'il ne faut pas rater : l'appairage s'adresse à un
        // pair précis. Envoyer le défi destiné à un pair Wi-Fi sur le câble
        // — au motif que le câble est plus rapide — laisse la poignée de main
        // Wi-Fi sans réponse, définitivement. C'est exactement ce qui cassait
        // la connexion dès que l'iPhone était branché.
        if let peer {
            switch peer {
            case Self.usbPeer:
                sendOverUSB(data)
            case Self.bluetoothPeer:
                sendOverBluetooth(data)
            default:
                link.send(data, to: peer, reliable: reliable)
            }
            return
        }

        // Sans destinataire, on choisit le plus rapide disponible : le câble,
        // puis le Wi-Fi, puis le Bluetooth.
        if usb.isConnected {
            sendOverUSB(data)
        } else if !isWiFiIdle {
            link.send(data, to: nil, reliable: reliable)
        } else if bluetooth.isConnected {
            sendOverBluetooth(data)
        }
    }

    private func sendOverUSB(_ data: Data) {
        let channel: CipherChannel = isHost ? .usbFromHost : .usbFromClient
        usb.send(usbCipher?.seal(data, channel: channel) ?? data)
    }

    private func sendOverBluetooth(_ data: Data) {
        guard bluetooth.isConnected else { return }
        let channel: CipherChannel = isHost ? .bleFromHost : .bleFromClient
        bluetooth.send(bluetoothCipher?.seal(data, channel: channel) ?? data)
    }

    // MARK: - Transfert de fichiers

    /// Envoie un fichier au pair connecté, sur le canal fiable.
    ///
    /// Découpé en tranches par `DirectLink` : un message unique tiendrait tout
    /// le fichier en mémoire des deux côtés et ne donnerait aucune progression.
    func sendFile(at url: URL, completion: @escaping (Error?) -> Void) {
        guard pairingState == .paired, let peer = link.peers.first else {
            completion(TransferError.notConnected)
            return
        }

        transferName = url.lastPathComponent
        transferProgress = 0

        link.sendFile(at: url, to: peer) { [weak self] fraction in
            self?.transferProgress = fraction
        } completion: { [weak self] error in
            DispatchQueue.main.async {
                self?.transferProgress = nil
                self?.transferName = nil
                completion(error)
            }
        }
    }

    typealias TransferError = DirectLink.TransferError

    // MARK: - Appairage, côté Mac

    /// Renomme un appareil appairé. Le nom est propre au Mac : l'iPhone n'en
    /// sait rien et continue d'annoncer le sien.
    func renameDevice(id deviceID: String, to name: String) {
        guard PairingStore.rename(deviceID, to: name) else { return }
        pairedDevices = PairingStore.pairedDevices()
        renamedDevices.insert(deviceID)
    }

    /// Appareils renommés à la main : leur nom ne doit plus être écrasé par
    /// celui qu'annonce l'iPhone à chaque reconnexion.
    private var renamedDevices: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "renamedDevices") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "renamedDevices") }
    }

    /// Oublie un appareil : il devra ressaisir un code.
    func forgetDevice(id deviceID: String) {
        PairingStore.removeDevice(deviceID)

        // Retirer le jeton ne suffit pas : la session en cours reste ouverte
        // et l'appareil garde le contrôle jusqu'à sa prochaine reconnexion.
        // Rien ne changeait donc à l'écran, et l'iPhone continuait de piloter
        // le Mac — l'inverse de ce qu'on demande en cliquant « Oublier ».
        for (peer, id) in peerDeviceIDs where id == deviceID {
            mutateAuthenticated { $0.remove(peer) }
            peerDeviceIDs[peer] = nil
            pendingNonces[peer] = nil
            failedAttempts[peer] = nil
        }

        pairedDevices = PairingStore.pairedDevices()
        if isAuthenticatedEmpty {
            pairingState = .idle
            displayedPin = nil
        }

        // On coupe et on relance : l'appareil se reconnectera sans jeton
        // valable et devra ressaisir un code, ce qui rend l'oubli visible.
        restart()
    }

    /// Affiche un code d'appairage, à la demande de l'utilisateur.
    func beginPairing() {
        let pin = Pairing.makePin()
        activePin = pin
        pinExpiry = Date().addingTimeInterval(pinLifetime)
        displayedPin = pin
        failedAttempts.removeAll()

        // Les appareils déjà connectés mais non autorisés reçoivent l'invite
        // tout de suite, sans avoir à se reconnecter.
        for peer in link.peers where !isAuthenticated(peer) {
            send(.authPinNeeded(), to: peer)
        }
    }

    /// Retire le code affiché.
    func cancelPairing() {
        activePin = nil
        pinExpiry = nil
        displayedPin = nil
    }

    /// Code encore valable, ou nil s'il a expiré.
    private var validPin: String? {
        guard let activePin, let pinExpiry, pinExpiry > Date() else { return nil }
        return activePin
    }

    private func challenge(_ peer: Peer) {
        let nonce = Pairing.makeNonce()
        pendingNonces[peer] = nonce
        pairingState = .verifying
        send(.authChallenge(nonce: nonce), to: peer)
    }

    private func handleAuthResponse(_ message: Message, from peer: Peer) {
        guard let nonce = pendingNonces[peer],
              let deviceID = message.deviceID, !deviceID.isEmpty else { return }

        peerDeviceIDs[peer] = deviceID
        let deviceName = message.name ?? peer.displayName

        guard (failedAttempts[peer] ?? 0) < maxAttempts else {
            send(.authDenied(), to: peer)
            return
        }

        // Pas de preuve : l'iPhone n'a pas de jeton. On l'invite à saisir le
        // code affiché — sans en générer un nouveau, sinon le code changerait
        // sous les yeux de l'utilisateur à chaque tentative.
        guard let proof = message.proof else {
            // Si aucun code n'est affiché, on en produit un : sans ça,
            // l'iPhone attendrait un code que le Mac ne montre nulle part.
            if validPin == nil { beginPairing() }
            pairingState = .awaitingPin
            send(.authPinNeeded(), to: peer)
            return
        }

        // 1) Jeton permanent déjà connu ? (app ou extension de clavier du
        //    même iPhone : elles partagent la même identité)
        if let known = PairingStore.device(for: deviceID),
           Pairing.matches(proof, Pairing.proof(secret: known.token, nonce: nonce)) {
            grant(peer, newToken: nil, sessionToken: known.token)
            return
        }

        // 2) Sinon, le code actuellement affiché sur le Mac.
        if let pin = validPin,
           Pairing.matches(proof, Pairing.proof(secret: pin, nonce: nonce)) {
            let token = Pairing.makeToken()
            // Un nom choisi à la main sur le Mac l'emporte sur celui annoncé
            // par l'iPhone, qui vaut « iPhone » pour tout le monde.
            let name = renamedDevices.contains(deviceID)
                ? (PairingStore.device(for: deviceID)?.name ?? deviceName)
                : deviceName
            PairingStore.setDevice(PairedDevice(token: token, name: name), for: deviceID)
            pairedDevices = PairingStore.pairedDevices()
            grant(peer, newToken: token, sessionToken: token)
            return
        }

        // 3) Aucun code n'est affiché : l'appareil présente un jeton périmé —
        //    oublié, ou Mac réinstallé. Ce n'est pas une erreur de saisie, on
        //    l'invite simplement à demander un code, sans compter d'échec.
        //    Sans ça, l'iPhone renvoyait son ancien jeton indéfiniment et
        //    finissait bloqué au bout de cinq tentatives.
        guard validPin != nil else {
            failedAttempts[peer] = nil
            beginPairing()
            pairingState = .awaitingPin
            send(.authPinNeeded(), to: peer)
            return
        }

        // 4) Un code était affiché et la preuve ne correspond pas : là, c'est
        //    bien une saisie erronée.
        failedAttempts[peer, default: 0] += 1
        if failedAttempts[peer] ?? 0 >= maxAttempts {
            displayedPin = nil
            pairingState = .refused
            send(.authDenied(), to: peer)
        } else {
            // Nouveau défi : la preuve précédente ne peut plus être rejouée.
            let fresh = Pairing.makeNonce()
            pendingNonces[peer] = fresh
            send(.authDenied(), to: peer)
            send(.authChallenge(nonce: fresh), to: peer)
        }
    }

    /// Identité réseau du Mac, fournie par l'app hôte pour le Wake on LAN.
    var hostNetworkIdentity: (macAddress: String?, broadcast: String?) = (nil, nil)

    /// - `newToken` : jeton à transmettre à l'iPhone, nil s'il garde le sien.
    /// - `sessionToken` : jeton effectif, dont la clé de chiffrement est
    ///   dérivée. Les deux diffèrent lors d'une reconnexion silencieuse.
    private func grant(_ peer: Peer, newToken: String?, sessionToken: String) {
        mutateAuthenticated { $0.insert(peer) }
        failedAttempts[peer] = nil
        displayedPin = nil
        pairingState = .paired

        // L'ordre compte : cet accord part **en clair**, puisque l'iPhone n'a
        // pas encore installé sa clé. On ne chiffre qu'ensuite. Les deux
        // appels empruntent la même file série du transport, donc l'accord
        // est bien émis avant que la clé ne prenne effet.
        send(.authGranted(token: newToken,
                          macAddress: hostNetworkIdentity.macAddress,
                          broadcast: hostNetworkIdentity.broadcast),
             to: peer)
        // Le défi de cet appairage sale la clé : elle change à chaque
        // connexion, sans quoi un paquet capté serait rejouable la fois
        // suivante.
        if let nonce = pendingNonces[peer] {
            switch peer {
            case Self.bluetoothPeer:
                bluetoothCipher = SessionCipher(token: sessionToken, nonce: nonce)
            case Self.usbPeer:
                usbCipher = SessionCipher(token: sessionToken, nonce: nonce)
            default:
                link.secure(peer, with: sessionToken, nonce: nonce)
            }
        }

        // **En dernier**, une fois l'accord parti et la clé posée.
        //
        // Placé avant, l'état courant partait devant `authGranted` : l'iPhone
        // n'était pas encore appairé de son côté et le jetait.
        onPeerAuthenticated?(peer)
    }

    // MARK: - Appairage, côté iPhone

    /// Macs déjà appairés depuis cet iPhone.
    @Published private(set) var knownHosts: [String] = []

    func refreshKnownHosts() {
        knownHosts = PairingStore.knownHosts()
    }

    /// Oublie un Mac : cet iPhone devra ressaisir un code pour y revenir.
    func forgetHost(_ host: String) {
        PairingStore.removeToken(forHost: host)
        refreshKnownHosts()
        // La session en cours doit tomber, sinon rien ne change à l'écran.
        restart()
    }

    /// Code saisi ou scanné par l'utilisateur, conservé jusqu'à ce qu'il
    /// aboutisse.
    ///
    /// Une preuve est calculée à partir du défi en cours. Or ce défi change à
    /// chaque connexion : entre le moment où l'on scanne et celui où la preuve
    /// part, il peut avoir été renouvelé — la preuve est alors rejetée sans
    /// que rien ne l'explique. En gardant le code, on le rejoue sur chaque
    /// nouveau défi jusqu'à réussite.
    private var pendingUserPin: String?

    /// Saisie du code affiché sur le Mac.
    func submitPin(_ pin: String) {
        pendingUserPin = pin
        pairingState = .verifying

        guard let nonce = currentNonce else {
            // Pas encore de défi : le code partira dès l'arrivée du premier.
            // Scanner avant que la liaison soit établie ne doit pas échouer.
            return
        }
        sendPinProof(pin, nonce: nonce)
    }

    /// Vrai quand l'utilisateur a demandé lui-même l'écran d'appairage.
    ///
    /// Une seule variable pilote cet écran, où qu'on l'ouvre. Le présenter à
    /// deux endroits — recouvrement automatique et feuille des réglages —
    /// faisait cohabiter deux scanners, qui se disputaient la caméra.
    @Published private(set) var isPairingRequested = false

    func requestPairingScreen() {
        isPairingRequested = true
    }

    /// Abandonne l'appairage en cours côté iPhone.
    func cancelPinEntry() {
        pendingUserPin = nil
        isPairingRequested = false
    }

    private func sendPinProof(_ pin: String, nonce: String) {
        send(.authResponse(proof: Pairing.proof(secret: pin, nonce: nonce),
                           deviceID: PairingStore.deviceIdentity(),
                           name: displayName),
             to: nil)
    }

    private func handleHostMessage(_ message: Message, from peer: Peer) {
        switch message.kind {
        case Message.Kind.authChallenge:
            guard let nonce = message.nonce else { return }
            currentNonce = nonce
            hostPeerName = peer.displayName
            pairingState = .verifying

            // Un code saisi ou scanné a priorité : il est rejoué sur ce défi
            // tout neuf. C'est ce qui rend l'appairage insensible au moment
            // exact où l'on scanne.
            if let pin = pendingUserPin {
                sendPinProof(pin, nonce: nonce)
                return
            }

            let identity = PairingStore.deviceIdentity()
            // Jeton déjà en poche : reconnexion silencieuse. L'extension de
            // clavier lit le même trousseau partagé, elle ne redemande donc
            // jamais de code.
            let token = PairingStore.token(forHost: peer.displayName)
            send(.authResponse(proof: token.map { Pairing.proof(secret: $0, nonce: nonce) },
                               deviceID: identity,
                               name: displayName),
                 to: peer)

        case Message.Kind.authPinNeeded:
            pairingState = .awaitingPin

        case Message.Kind.authGranted:
            if let token = message.token, let host = hostPeerName {
                PairingStore.setToken(token, forHost: host)
            }
            // Conservé pour pouvoir réveiller le Mac quand il dort — donc
            // quand il n'y a plus personne pour nous les envoyer.
            if let mac = message.target, !mac.isEmpty {
                UserDefaults.standard.set(mac, forKey: Self.wakeMacAddressKey)
            }
            if let broadcast = message.command, !broadcast.isEmpty {
                UserDefaults.standard.set(broadcast, forKey: Self.wakeBroadcastKey)
            }
            if let host = hostPeerName {
                UserDefaults.standard.set(host, forKey: Self.lastHostNameKey)
            }
            pendingUserPin = nil
            isPairingRequested = false
            pairingState = .paired

            // Même clé de l'autre côté : celle qu'on vient de recevoir, ou
            // celle qu'on avait déjà en cas de reconnexion silencieuse.
            if let host = hostPeerName,
               let token = message.token ?? PairingStore.token(forHost: host),
               let nonce = currentNonce {
                switch peer {
                case Self.bluetoothPeer:
                    bluetoothCipher = SessionCipher(token: token, nonce: nonce)
                case Self.usbPeer:
                    usbCipher = SessionCipher(token: token, nonce: nonce)
                default:
                    link.secure(peer, with: token, nonce: nonce)
                }
            }

        case Message.Kind.authDenied:
            // Le code proposé est faux : on l'oublie, sinon il serait rejoué
            // en boucle sur chaque nouveau défi et l'appareil finirait bloqué.
            pendingUserPin = nil
            // Le jeton conservé ne vaut plus rien : le garder ferait échouer
            // toutes les tentatives suivantes, puisqu'il serait renvoyé à
            // chaque défi au lieu de demander un code.
            if let host = hostPeerName {
                PairingStore.removeToken(forHost: host)
            }
            pairingState = .refused

        default:
            break
        }
    }
}


// MARK: - Réception

extension MessageConnection {

    /// Aiguillage d'une charge utile reçue, déjà déchiffrée par `DirectLink`.
    fileprivate func receive(_ data: Data, from peer: Peer) {
        let message: Message
        if let fast = FastPacket.decode(data) {
            message = fast
        } else if let json = try? decoder.decode(Message.self, from: data) {
            message = json
        } else {
            return
        }

        // Les événements de pointage empruntent une file dédiée, prioritaire
        // et séparée de l'interface.
        //
        // Les faire transiter par la file principale les plaçait derrière le
        // rendu SwiftUI : à 120 messages par seconde, la file s'allonge et le
        // curseur traîne. Cette file est série, donc l'ordre est préservé —
        // un clic ne peut pas doubler un déplacement.
        if isHost, isPointerEvent(message) {
            inputQueue.async { [weak self] in
                guard let self, self.isAuthenticated(peer) else { return }
                self.onMessage?(message, peer)
            }
            return
        }

        // Le reste passe par la file principale : ces messages touchent à
        // AppKit ou à l'état publié de l'interface.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if message.isControlMessage {
                // Le filtre de sécurité : un pair non appairé n'a aucun effet.
                if self.isHost {
                    guard self.isAuthenticated(peer) else { return }
                } else {
                    // Côté iPhone : on n'accepte les réponses (liste des apps,
                    // presse-papiers, constantes) qu'une fois appairé.
                    guard self.pairingState == .paired else { return }
                }
                self.onMessage?(message, peer)
                return
            }

            if self.isHost {
                if message.kind == Message.Kind.authResponse {
                    self.handleAuthResponse(message, from: peer)
                }
            } else {
                self.handleHostMessage(message, from: peer)
            }
        }
    }
}
