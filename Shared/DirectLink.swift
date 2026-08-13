import Foundation
import Network
import CryptoKit

/// Liaison directe entre l'iPhone et le Mac, en remplacement de
/// MultipeerConnectivity.
///
/// ## Pourquoi
///
/// MPC empile sa propre session chiffrée, son routage multi-pairs et sa
/// couche de fiabilité au-dessus du réseau. Cette surcouche est
/// incompressible et se paie en latence sur le seul chemin qui compte :
/// le déplacement du curseur, envoyé jusqu'à 120 fois par seconde.
///
/// ## Deux canaux, pas un
///
/// - **UDP** pour le chemin chaud — déplacement, défilement, zoom. Ce sont
///   des deltas : un paquet perdu est remplacé par le suivant deux
///   millisecondes plus tard. Attendre une retransmission coûterait plus cher
///   que la perte.
/// - **TCP** pour tout ce qui ne se rattrape pas — clics, touches, appairage,
///   listes d'apps, presse-papiers, fichiers. Un clic perdu ne se devine pas.
///
/// Une seule découverte Bonjour (`_trackpadhub._tcp`) : le Mac annonce,
/// l'iPhone cherche. Le port UDP voyage sur le canal TCP une fois l'appairage
/// fait — inutile de l'annoncer à la cantonade.
///
/// ## Chiffrement
///
/// MPC chiffrait la session. Ne rien mettre à la place ferait circuler les
/// frappes clavier et le presse-papiers en clair sur le Wi-Fi. Une fois
/// l'appairage réussi, les deux bouts dérivent une clé du **jeton** déjà
/// partagé (HKDF-SHA256) et scellent chaque trame en AES-GCM.
///
/// Les messages d'appairage eux-mêmes restent en clair : ils sont sûrs par
/// conception, le secret ne circule jamais — seule une preuve HMAC voyage.
///
/// Le nonce GCM porte un compteur strictement croissant par direction et par
/// canal, ce qui interdit le rejeu : un clic capté sur le réseau ne peut pas
/// être renvoyé plus tard.
final class DirectLink {

    /// Type de service Bonjour. Changer cette chaîne casse la découverte
    /// entre deux versions de l'app.
    static let serviceType = "_trackpadhub._tcp"

    /// Taille maximale d'une trame TCP. Les tranches de fichier font 32 Ko,
    /// les messages quelques centaines d'octets : 8 Mo laisse une marge
    /// confortable tout en bornant ce qu'une trame forgée peut faire allouer.
    private static let maxFrameLength: UInt32 = 8 * 1024 * 1024

    /// Un pair connecté. Remplace `MCPeerID`.
    struct Peer: Hashable, Identifiable {
        let id: String
        let displayName: String
    }

    // MARK: - Rappels

    var onPeerConnected: ((Peer) -> Void)?
    var onPeerLost: ((Peer) -> Void)?
    /// Charge utile applicative, déjà déchiffrée.
    var onData: ((Data, Peer) -> Void)?
    /// Fichier reçu : URL temporaire, nom d'origine, et pair émetteur — sans
    /// lui, impossible de refuser un fichier venu d'un appareil non appairé.
    var onFileReceived: ((URL, String, Peer) -> Void)?
    /// Progression d'une réception : nom, fraction de 0 à 1, nil à la fin.
    var onFileProgress: ((String?, Double?) -> Void)?

    // MARK: - Configuration

    let displayName: String
    let isHost: Bool

    /// Type de service effectif. Surchargeable pour qu'un banc d'essai puisse
    /// faire dialoguer deux instances sans tomber sur l'app réelle, qui
    /// annonce le même service sur le même Mac.
    private let serviceType: String

    init(displayName: String, isHost: Bool, serviceType: String = DirectLink.serviceType) {
        self.displayName = displayName
        self.isHost = isHost
        self.serviceType = serviceType
    }

    // MARK: - Files

    /// File du transport. Série : l'ordre des trames est garanti sans verrou
    /// supplémentaire sur l'état des pairs.
    private let queue = DispatchQueue(label: "com.trackpadhub.link", qos: .userInteractive)

    /// File des transferts de fichiers, séparée pour ne jamais retenir le
    /// transport pendant qu'un fichier défile.
    private let fileQueue = DispatchQueue(label: "com.trackpadhub.link.files", qos: .utility)

    // MARK: - État

    private var tcpListener: NWListener?
    private var udpListener: NWListener?
    private var browser: NWBrowser?
    /// Vrai entre `start()` et `stop()`. Sans lui, la boucle de reconnexion
    /// continuerait de tourner après un arrêt volontaire.
    private var isRunning = false

    /// Un pair et tout ce qui s'y rattache.
    private final class Session {
        /// Muable : le nom définitif n'arrive qu'avec la trame `hello`, et
        /// remplacer l'objet Session laisserait la boucle de réception en
        /// cours écrire dans l'ancien tampon.
        var peer: Peer
        let tcp: NWConnection
        var udp: NWConnection?
        /// Chiffrement de la session, présent seulement après appairage.
        var cipher: SessionCipher?
        /// Jeton d'association du canal UDP au pair.
        var ticket: Data?
        /// Tampon de réassemblage TCP.
        var inbox = Data()
        /// Réception de fichier en cours.
        var incoming: IncomingFile?

        init(peer: Peer, tcp: NWConnection) {
            self.peer = peer
            self.tcp = tcp
        }
    }

    private final class IncomingFile {
        let name: String
        let size: Int
        let url: URL
        var handle: FileHandle?
        var written: Int = 0
        init(name: String, size: Int, url: URL) {
            self.name = name
            self.size = size
            self.url = url
        }
    }

    private var sessions: [String: Session] = [:]
    /// Correspondance endpoint UDP → identifiant de pair, établie par ticket.
    private var udpBindings: [String: String] = [:]

    /// Liste des pairs, lisible depuis n'importe quelle file.
    private let peersLock = NSLock()
    private var peerList: [Peer] = []

    var peers: [Peer] {
        peersLock.lock()
        defer { peersLock.unlock() }
        return peerList
    }

    private func publishPeers() {
        let list = sessions.values.map(\.peer)
        peersLock.lock()
        peerList = list
        peersLock.unlock()
    }

    // MARK: - Types de trame

    private enum Frame: UInt8 {
        case message    = 1
        case fileHeader = 2
        case fileChunk  = 3
        case fileEnd    = 4
        case hello      = 5
        case udpInfo    = 6
        case udpTicket  = 7
    }

    private var outboundTCP: CipherChannel { isHost ? .tcpFromHost : .tcpFromClient }
    private var outboundUDP: CipherChannel { isHost ? .udpFromHost : .udpFromClient }
    private var inboundTCP: CipherChannel { isHost ? .tcpFromClient : .tcpFromHost }
    private var inboundUDP: CipherChannel { isHost ? .udpFromClient : .udpFromHost }

    // MARK: - Cycle de vie

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isRunning = true
            if self.isHost {
                self.startListening()
            } else {
                self.startBrowsing()
                self.scheduleReconnect()
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isRunning = false
            self.browser?.cancel()
            self.browser = nil
            self.tcpListener?.cancel()
            self.tcpListener = nil
            self.udpListener?.cancel()
            self.udpListener = nil
            for session in self.sessions.values {
                session.tcp.cancel()
                session.udp?.cancel()
            }
            self.sessions.removeAll()
            self.udpBindings.removeAll()
            self.publishPeers()
        }
    }

    // MARK: - Côté Mac : écoute

    private func tcpParameters() -> NWParameters {
        let parameters = NWParameters.tcp
        // Sans délai de Nagle : un clic de 12 octets ne doit pas attendre
        // qu'un second paquet vienne remplir le segment.
        if let tcp = parameters.defaultProtocolStack.internetProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
            tcp.connectionTimeout = 5
        }
        // Conserve la capacité « à proximité » qu'offrait MultipeerConnectivity
        // via AWDL, sans réseau Wi-Fi commun.
        parameters.includePeerToPeer = true
        return parameters
    }

    private func startListening() {
        do {
            let listener = try NWListener(using: tcpParameters())
            listener.service = NWListener.Service(name: displayName, type: serviceType)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    NSLog("TrackPadHub: écoute TCP en échec : %@", "\(error)")
                }
            }
            listener.start(queue: queue)
            tcpListener = listener
        } catch {
            NSLog("TrackPadHub: impossible d'ouvrir l'écoute TCP : %@", "\(error)")
        }

        do {
            let listener = try NWListener(using: .udp)
            listener.newConnectionHandler = { [weak self] connection in
                self?.acceptUDP(connection)
            }
            listener.start(queue: queue)
            udpListener = listener
        } catch {
            NSLog("TrackPadHub: impossible d'ouvrir l'écoute UDP : %@", "\(error)")
        }
    }

    private func accept(_ connection: NWConnection) {
        let peer = Peer(id: UUID().uuidString, displayName: "Appareil")
        let session = Session(peer: peer, tcp: connection)
        sessions[peer.id] = session

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.receiveTCP(session)
            case .failed, .cancelled:
                self.drop(session.peer.id)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func acceptUDP(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .ready = state { self.receiveUDP(connection) }
        }
        connection.start(queue: queue)
    }

    // MARK: - Côté iPhone : recherche

    private func startBrowsing() {
        let parameters = tcpParameters()
        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)
        browser.browseResultsChangedHandler = { [weak self] _, _ in
            self?.connectToBestResult()
        }
        browser.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                NSLog("TrackPadHub: recherche en échec : %@", "\(error)")
            }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    /// Tente une connexion vers le Mac annoncé, s'il y en a un et qu'on n'est
    /// pas déjà connecté.
    ///
    /// **Séparé du rappel du navigateur, et c'est le point important.**
    /// `browseResultsChangedHandler` ne se déclenche qu'au *changement* de la
    /// liste. Si la liaison tombe alors que le Mac continue d'annoncer, la
    /// liste ne bouge pas, aucun rappel n'arrive, et l'iPhone ne se reconnecte
    /// jamais — il fallait quitter l'app. MultipeerConnectivity réessayait
    /// tout seul ; ici c'est à nous de le faire.
    private func connectToBestResult() {
        guard !isHost, sessions.isEmpty, let browser else { return }
        // Un seul Mac à la fois : le premier trouvé. Un choix explicite entre
        // plusieurs Macs serait une fonctionnalité à part entière.
        guard let result = browser.browseResults.first else { return }
        var name = "Mac"
        if case .service(let serviceName, _, _, _) = result.endpoint {
            name = serviceName
        }
        connect(to: result.endpoint, named: name)
    }

    /// Replanifie une tentative de connexion après une coupure.
    private func scheduleReconnect() {
        guard !isHost, isRunning else { return }
        queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.isRunning else { return }
            self.connectToBestResult()
            // Tant que rien n'est connecté, on retente : le Mac peut être en
            // veille, ou revenir sur le réseau plus tard.
            if self.sessions.isEmpty { self.scheduleReconnect() }
        }
    }

    private func connect(to endpoint: NWEndpoint, named name: String) {
        let connection = NWConnection(to: endpoint, using: tcpParameters())
        let peer = Peer(id: UUID().uuidString, displayName: name)
        let session = Session(peer: peer, tcp: connection)
        sessions[peer.id] = session

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.receiveTCP(session)
                // L'hôte doit savoir à qui il parle : il ne connaît pour
                // l'instant qu'une adresse.
                self.sendFrame(.hello, body: Data(self.displayName.utf8), on: session)
                self.publishPeers()
                self.onPeerConnected?(peer)
            case .failed, .cancelled:
                self.drop(session.peer.id)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    // MARK: - Réception TCP

    private func receiveTCP(_ session: Session) {
        session.tcp.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                session.inbox.append(data)
                self.drainInbox(session)
            }
            if isComplete || error != nil {
                self.drop(session.peer.id)
                return
            }
            self.receiveTCP(session)
        }
    }

    /// Découpe le flux TCP en trames.
    ///
    /// TCP est un flux d'octets, pas un flux de messages : deux envois
    /// peuvent arriver collés, un envoi peut arriver coupé en deux. D'où le
    /// préfixe de longueur — sans lui, un paquet de déplacement pourrait être
    /// interprété au beau milieu d'un autre.
    private func drainInbox(_ session: Session) {
        while session.inbox.count >= 5 {
            let length = session.inbox.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            // Borne haute : sans elle, une longueur aberrante — trame
            // corrompue ou forgée — ferait grossir le tampon sans fin en
            // attendant des octets qui n'arriveront jamais.
            guard length >= 1, length <= Self.maxFrameLength else {
                NSLog("TrackPadHub: trame de longueur invalide (%u), liaison coupée", length)
                drop(session.peer.id)
                return
            }
            let total = 4 + Int(length)
            guard session.inbox.count >= total else { return }

            let frame = session.inbox.subdata(in: 4..<total)
            session.inbox.removeSubrange(0..<total)

            guard let type = Frame(rawValue: frame[frame.startIndex]) else { continue }
            let body = frame.subdata(in: (frame.startIndex + 1)..<frame.endIndex)
            handle(type, body: body, on: session, viaUDP: false)
        }
    }

    private func handle(_ type: Frame, body: Data, on session: Session, viaUDP: Bool) {
        switch type {
        case .hello:
            // Le nom annoncé par le client remplace le provisoire.
            let name = String(data: body, encoding: .utf8) ?? "Appareil"
            session.peer = Peer(id: session.peer.id, displayName: name)
            publishPeers()
            onPeerConnected?(session.peer)

        case .message:
            let channel = viaUDP ? inboundUDP : inboundTCP
            guard let payload = open(body, on: session, channel: channel) else { return }
            onData?(payload, session.peer)

        case .udpInfo:
            // L'hôte annonce son port UDP et le ticket qui identifiera ce pair.
            guard body.count > 2 else { return }
            let port = UInt16(body[body.startIndex]) << 8 | UInt16(body[body.startIndex + 1])
            let ticket = body.subdata(in: (body.startIndex + 2)..<body.endIndex)
            openFastPath(to: port, ticket: ticket, on: session)

        case .udpTicket:
            // Côté hôte : ce datagramme prouve à quel pair appartient
            // l'endpoint UDP d'où il vient.
            break

        case .fileHeader:
            guard let header = try? JSONDecoder().decode(FileHeader.self, from: body) else { return }
            beginReceiving(header, on: session)

        case .fileChunk:
            guard let incoming = session.incoming else { return }
            guard let payload = open(body, on: session, channel: inboundTCP) else { return }
            incoming.handle?.write(payload)
            incoming.written += payload.count
            let fraction = incoming.size > 0 ? Double(incoming.written) / Double(incoming.size) : 0
            onFileProgress?(incoming.name, min(fraction, 1))

        case .fileEnd:
            guard let incoming = session.incoming else { return }
            try? incoming.handle?.close()
            session.incoming = nil
            onFileProgress?(nil, nil)
            onFileReceived?(incoming.url, incoming.name, session.peer)
        }
    }

    private struct FileHeader: Codable {
        let name: String
        let size: Int
    }

    private func beginReceiving(_ header: FileHeader, on session: Session) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension((header.name as NSString).pathExtension)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let incoming = IncomingFile(name: header.name, size: header.size, url: url)
        incoming.handle = try? FileHandle(forWritingTo: url)
        session.incoming = incoming
        onFileProgress?(header.name, 0)
    }

    // MARK: - Réception UDP

    private func receiveUDP(_ connection: NWConnection, boundTo bound: Session? = nil) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            defer { if error == nil { self.receiveUDP(connection, boundTo: bound) } }
            guard let data, data.count >= 1 else { return }

            let key = Self.endpointKey(connection.endpoint)
            let type = Frame(rawValue: data[data.startIndex])
            let body = data.subdata(in: (data.startIndex + 1)..<data.endIndex)

            // Côté client, la connexion UDP est déjà rattachée à son unique
            // pair : pas de ticket à retrouver.
            if let bound, let type, type != .udpTicket {
                self.handle(type, body: body, on: bound, viaUDP: true)
                return
            }

            if type == .udpTicket {
                // Association de l'endpoint au pair, par ticket : c'est ce qui
                // empêche n'importe quelle machine du réseau d'injecter des
                // déplacements en se faisant passer pour l'iPhone appairé.
                for session in self.sessions.values where session.ticket == body {
                    self.udpBindings[key] = session.peer.id
                    session.udp = connection
                }
                return
            }

            guard let type,
                  let peerID = self.udpBindings[key],
                  let session = self.sessions[peerID] else { return }
            self.handle(type, body: body, on: session, viaUDP: true)
        }
    }

    private static func endpointKey(_ endpoint: NWEndpoint) -> String {
        "\(endpoint)"
    }

    // MARK: - Canal rapide

    /// Côté hôte : ouvre le canal rapide pour ce pair et lui en donne l'adresse.
    private func announceFastPath(_ session: Session) {
        guard isHost, let port = udpListener?.port else { return }
        var ticket = Data(count: 16)
        ticket.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            _ = SecRandomCopyBytes(kSecRandomDefault, 16, base)
        }
        session.ticket = ticket

        var body = Data()
        body.append(UInt8(port.rawValue >> 8))
        body.append(UInt8(port.rawValue & 0xFF))
        body.append(ticket)
        sendFrame(.udpInfo, body: body, on: session)
    }

    /// Côté client : ouvre la connexion UDP vers l'hôte et se présente.
    private func openFastPath(to port: UInt16, ticket: Data, on session: Session) {
        // L'adresse de l'hôte est celle qu'a résolue la connexion TCP : pas de
        // seconde résolution Bonjour, et le canal rapide emprunte forcément la
        // même interface.
        guard let remote = session.tcp.currentPath?.remoteEndpoint,
              case .hostPort(let host, _) = remote else { return }

        let connection = NWConnection(host: host,
                                      port: NWEndpoint.Port(rawValue: port) ?? .any,
                                      using: .udp)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self, case .ready = state else { return }
            var packet = Data([Frame.udpTicket.rawValue])
            packet.append(ticket)
            connection.send(content: packet, completion: .idempotent)
            self.receiveUDP(connection, boundTo: session)
        }
        connection.start(queue: queue)
        session.udp = connection
    }

    // MARK: - Chiffrement

    /// Installe la clé de session dérivée du jeton d'appairage, et ouvre le
    /// canal rapide. À appeler des deux côtés dès que l'appairage aboutit.
    /// - `nonce` : le défi de cet appairage-ci. Il **sale** la clé, ce qui la
    ///   rend différente à chaque connexion.
    ///
    ///   Sans ce sel, la clé ne dépendrait que du jeton, donc serait la même
    ///   d'une session à l'autre — alors que les compteurs anti-rejeu, eux,
    ///   repartent de zéro à chaque connexion. Un paquet capté sur le réseau
    ///   lors d'une session pourrait donc être rejoué lors de la suivante.
    func secure(_ peer: Peer, with token: String, nonce: String) {
        queue.async { [weak self] in
            guard let self, let session = self.sessions[peer.id] else { return }
            session.cipher = SessionCipher(token: token, nonce: nonce)
            if self.isHost { self.announceFastPath(session) }
        }
    }

    /// Scelle une charge. Sans chiffrement — donc avant appairage — elle part
    /// telle quelle : les messages d'appairage ne portent aucun secret.
    private func seal(_ payload: Data, on session: Session, channel: CipherChannel) -> Data {
        session.cipher?.seal(payload, channel: channel) ?? payload
    }

    /// Ouvre une charge. Après appairage, le clair est refusé.
    private func open(_ data: Data, on session: Session, channel: CipherChannel) -> Data? {
        guard let cipher = session.cipher else { return data }
        return cipher.open(data, channel: channel)
    }

    // MARK: - Envoi

    /// Envoie une charge utile applicative.
    ///
    /// `reliable: false` emprunte le canal UDP quand il est ouvert. Sinon tout
    /// passe par TCP — y compris pendant l'appairage, avant que le canal
    /// rapide n'existe.
    func send(_ payload: Data, to peer: Peer?, reliable: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            let targets = peer.flatMap { self.sessions[$0.id].map { [$0] } }
                ?? Array(self.sessions.values)

            for session in targets {
                if !reliable, let udp = session.udp, session.cipher != nil {
                    let sealed = self.seal(payload, on: session, channel: self.outboundUDP)
                    var packet = Data([Frame.message.rawValue])
                    packet.append(sealed)
                    udp.send(content: packet, completion: .idempotent)
                } else {
                    let sealed = self.seal(payload, on: session, channel: self.outboundTCP)
                    self.sendFrame(.message, body: sealed, on: session)
                }
            }
        }
    }

    private func sendFrame(_ type: Frame, body: Data, on session: Session) {
        var packet = Data()
        let length = UInt32(body.count + 1)
        packet.append(UInt8((length >> 24) & 0xFF))
        packet.append(UInt8((length >> 16) & 0xFF))
        packet.append(UInt8((length >> 8) & 0xFF))
        packet.append(UInt8(length & 0xFF))
        packet.append(type.rawValue)
        packet.append(body)
        session.tcp.send(content: packet, completion: .idempotent)
    }

    // MARK: - Fichiers

    /// Envoie un fichier sur le canal fiable, par tranches.
    ///
    /// Découpé, et non porté d'un bloc : un message unique tiendrait tout le
    /// fichier en mémoire des deux côtés, et ne donnerait aucune progression.
    func sendFile(at url: URL,
                  to peer: Peer,
                  progress: @escaping (Double) -> Void,
                  completion: @escaping (Error?) -> Void) {
        // Sur une file à part, et non sur celle du transport.
        //
        // Lire et découper un fichier prend du temps ; le faire sur la file du
        // transport la bloquerait du premier au dernier octet, et le curseur
        // se figerait pendant tout l'envoi. Chaque tranche repasse par la file
        // du transport le temps d'être scellée et émise — assez pour garder
        // les compteurs anti-rejeu cohérents, assez peu pour qu'un déplacement
        // puisse toujours se glisser entre deux tranches.
        fileQueue.async { [weak self] in
            guard let self else { return }
            var session: Session?
            self.queue.sync { session = self.sessions[peer.id] }
            guard let session else {
                completion(TransferError.notConnected)
                return
            }
            guard let handle = try? FileHandle(forReadingFrom: url) else {
                completion(TransferError.failed)
                return
            }
            defer { try? handle.close() }

            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
            let header = FileHeader(name: url.lastPathComponent, size: size)
            guard let headerData = try? JSONEncoder().encode(header) else {
                completion(TransferError.failed)
                return
            }
            self.queue.sync { self.sendFrame(.fileHeader, body: headerData, on: session) }

            var sent = 0
            let chunkSize = 32 * 1024
            while let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty {
                self.queue.sync {
                    let sealed = self.seal(chunk, on: session, channel: self.outboundTCP)
                    self.sendFrame(.fileChunk, body: sealed, on: session)
                }
                sent += chunk.count
                let fraction = size > 0 ? Double(sent) / Double(size) : 0
                DispatchQueue.main.async { progress(min(fraction, 1)) }
            }

            self.queue.sync { self.sendFrame(.fileEnd, body: Data(), on: session) }
            DispatchQueue.main.async { completion(nil) }
        }
    }

    enum TransferError: LocalizedError {
        case notConnected
        case failed

        var errorDescription: String? {
            switch self {
            case .notConnected: return "Aucun appareil appairé."
            case .failed:       return "Le transfert n'a pas pu démarrer."
            }
        }
    }

    // MARK: - Perte

    /// Coupe la liaison en laissant le navigateur Bonjour tourner.
    ///
    /// Existe pour le banc d'essai : c'est le seul moyen de reproduire le cas
    /// qui comptait — la connexion tombe alors que le Mac continue d'annoncer,
    /// donc la liste Bonjour ne change pas et le rappel du navigateur ne se
    /// redéclenche jamais. Passer par `stop()` puis `start()` recrée un
    /// navigateur et masque le problème.
    func severForTesting() {
        queue.async { [weak self] in
            guard let self else { return }
            for id in Array(self.sessions.keys) { self.drop(id) }
        }
    }

    private func drop(_ peerID: String) {
        guard let session = sessions.removeValue(forKey: peerID) else { return }
        session.tcp.cancel()
        session.udp?.cancel()
        udpBindings = udpBindings.filter { $0.value != peerID }
        publishPeers()
        onPeerLost?(session.peer)
        scheduleReconnect()
    }
}
