import Foundation
import Network

/// Liaison filaire, par le câble USB-C.
///
/// ## Ce qu'elle apporte
///
/// C'est le seul transport qui donne ce que le Wi-Fi ne peut pas : une latence
/// de l'ordre de 1 à 2 ms, **constante**, sans les à-coups d'un réseau
/// encombré. Pour dessiner ou jouer, c'est la différence entre « ça suit » et
/// « ça suit toujours ». L'iPhone se recharge en prime.
///
/// ## Comment ça marche
///
/// Il n'existe aucune API publique pour parler en USB à un iPhone depuis une
/// app Mac. Mais macOS fait déjà tourner `usbmuxd`, le démon qu'utilise Xcode
/// pour joindre les appareils branchés. On lui parle par sa socket Unix
/// `/var/run/usbmuxd`, et il **tunnelise** une connexion TCP vers un port
/// ouvert sur l'iPhone.
///
/// D'où le partage des rôles, inverse de tous les autres transports :
/// - l'**iPhone écoute** sur un port TCP local ;
/// - le **Mac se connecte** à ce port à travers `usbmuxd`.
///
/// Vérifié avant d'écrire une ligne : `ListDevices` renvoie bien l'iPhone
/// branché, et `Connect` sur un port fermé répond « 3 » — port refusé. Le
/// chemin est donc complet, il n'y manquait qu'un écouteur.
///
/// ## Limite à connaître
///
/// iOS suspend les apps en arrière-plan : l'écouteur ne répond que lorsque
/// TrackPad Hub est au premier plan sur l'iPhone. Ce n'est pas gênant en
/// pratique — on tient le téléphone pour s'en servir de trackpad — mais la
/// liaison filaire ne survit pas au verrouillage de l'écran.
final class USBLink {

    /// Port TCP écouté sur l'iPhone.
    ///
    /// Fixe des deux côtés : `usbmuxd` ne sait pas découvrir, il faut lui dire
    /// où frapper.
    static let devicePort: UInt16 = 24680

    // MARK: - Rappels

    var onConnected: (() -> Void)?
    var onLost: (() -> Void)?
    var onData: ((Data) -> Void)?

    private(set) var isConnected = false {
        didSet {
            guard isConnected != oldValue else { return }
            isConnected ? onConnected?() : onLost?()
        }
    }

    private let isHost: Bool
    private let queue = DispatchQueue(label: "com.trackpadhub.usb")

    /// Tampon de réassemblage : le tunnel est un flux d'octets, pas de messages.
    private var inbox = Data()

    init(isHost: Bool) {
        self.isHost = isHost
    }

    // MARK: - Découpage en trames

    /// Même cadrage que le canal TCP de `DirectLink` : longueur sur quatre
    /// octets en gros-boutiste, puis la charge. Sans lui, deux messages
    /// collés seraient illisibles.
    private static func frame(_ payload: Data) -> Data {
        var packet = Data()
        let length = UInt32(payload.count)
        packet.append(UInt8((length >> 24) & 0xFF))
        packet.append(UInt8((length >> 16) & 0xFF))
        packet.append(UInt8((length >> 8) & 0xFF))
        packet.append(UInt8(length & 0xFF))
        packet.append(payload)
        return packet
    }

    /// Plafond de sécurité, comme sur le canal TCP : une longueur aberrante
    /// ferait grossir le tampon sans fin.
    private static let maxFrameLength: UInt32 = 8 * 1024 * 1024

    private func drain() {
        while inbox.count >= 4 {
            let length = inbox.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length <= Self.maxFrameLength else {
                inbox.removeAll()
                return
            }
            let total = 4 + Int(length)
            guard inbox.count >= total else { return }
            let payload = inbox.subdata(in: 4..<total)
            inbox.removeSubrange(0..<total)
            onData?(payload)
        }
    }

#if os(macOS)

    // MARK: - Mac : client d'usbmuxd

    /// Socket de notification (attente d'un appareil), puis socket du tunnel.
    private var watchSocket: Int32 = -1
    private var tunnelSocket: Int32 = -1
    private var isRunning = false

    func start() {
        queue.async { [weak self] in
            guard let self, !self.isRunning else { return }
            self.isRunning = true
            self.watchForDevice()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isRunning = false
            self.closeSockets()
            self.isConnected = false
        }
    }

    private func closeSockets() {
        if watchSocket >= 0 { close(watchSocket); watchSocket = -1 }
        if tunnelSocket >= 0 { close(tunnelSocket); tunnelSocket = -1 }
        inbox.removeAll()
    }

    /// Ouvre une socket vers `usbmuxd`.
    private func openMuxSocket() -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return -1 }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

        // Le chemin est recopié depuis un tableau local, et la taille lue sur
        // le tampon lui-même. Interroger `address.sun_path` pendant qu'on le
        // modifie serait un accès chevauchant, que Swift refuse.
        let path = Array("/var/run/usbmuxd".utf8)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            let count = min(path.count, buffer.count - 1)
            buffer.copyBytes(from: path[0..<count])
            buffer[count] = 0
        }

        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if connected != 0 {
            close(fd)
            return -1
        }
        return fd
    }

    /// En-tête du protocole d'`usbmuxd` : longueur, version, type, étiquette,
    /// tous en **petit-boutiste**.
    private func sendPlist(_ payload: [String: Any], on fd: Int32, tag: UInt32 = 1) -> Bool {
        guard let body = try? PropertyListSerialization.data(
            fromPropertyList: payload, format: .xml, options: 0) else { return false }

        var header = Data()
        for value in [UInt32(16 + body.count), UInt32(1), UInt32(8), tag] {
            withUnsafeBytes(of: value.littleEndian) { header.append(contentsOf: $0) }
        }
        var packet = header
        packet.append(body)

        return packet.withUnsafeBytes { raw in
            write(fd, raw.baseAddress, raw.count) == raw.count
        }
    }

    private func readPlist(on fd: Int32) -> [String: Any]? {
        var header = [UInt8](repeating: 0, count: 16)
        guard read(fd, &header, 16) == 16 else { return nil }
        let length = header.prefix(4).enumerated().reduce(UInt32(0)) { total, item in
            total | (UInt32(item.element) << (8 * UInt32(item.offset)))
        }
        guard length > 16, length < 1 << 20 else { return nil }

        var body = Data()
        var remaining = Int(length) - 16
        var buffer = [UInt8](repeating: 0, count: min(remaining, 8192))
        while remaining > 0 {
            let count = read(fd, &buffer, min(remaining, buffer.count))
            guard count > 0 else { return nil }
            body.append(contentsOf: buffer[0..<count])
            remaining -= count
        }
        return (try? PropertyListSerialization.propertyList(
            from: body, options: [], format: nil)) as? [String: Any]
    }

    private var baseRequest: [String: Any] {
        ["ClientVersionString": "TrackPad Hub",
         "ProgName": "TrackPad Hub",
         "kLibUSBMuxVersion": 3]
    }

    /// Attend qu'un iPhone soit branché, puis ouvre le tunnel.
    private func watchForDevice() {
        guard isRunning else { return }

        watchSocket = openMuxSocket()
        guard watchSocket >= 0 else {
            retryLater()
            return
        }

        var request = baseRequest
        request["MessageType"] = "Listen"
        guard sendPlist(request, on: watchSocket) else {
            retryLater()
            return
        }

        // Boucle d'écoute des branchements. `Attached` porte l'identifiant
        // dont `Connect` a besoin.
        while isRunning, let message = readPlist(on: watchSocket) {
            guard let type = message["MessageType"] as? String else { continue }
            if type == "Attached",
               let deviceID = message["DeviceID"] as? Int,
               let properties = message["Properties"] as? [String: Any],
               (properties["ConnectionType"] as? String) == "USB" {
                openTunnel(to: deviceID)
            } else if type == "Detached" {
                closeTunnel()
            }
        }
        retryLater()
    }

    private func retryLater() {
        closeSockets()
        isConnected = false
        guard isRunning else { return }
        queue.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.watchForDevice()
        }
    }

    private func openTunnel(to deviceID: Int) {
        closeTunnel()
        let fd = openMuxSocket()
        guard fd >= 0 else { return }

        var request = baseRequest
        request["MessageType"] = "Connect"
        request["DeviceID"] = deviceID
        // **Le port se donne en gros-boutiste**, seul champ du protocole à
        // faire exception. Le donner en petit-boutiste vise un port qui
        // n'existe pas, et `usbmuxd` répond « refusé » sans expliquer
        // pourquoi.
        request["PortNumber"] = Int(Self.devicePort.bigEndian)

        guard sendPlist(request, on: fd),
              let reply = readPlist(on: fd),
              (reply["Number"] as? Int) == 0 else {
            close(fd)
            // L'app iPhone n'est pas au premier plan : on retentera au
            // prochain branchement, ou à la prochaine tentative.
            queue.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self, self.isRunning, self.tunnelSocket < 0 else { return }
                self.openTunnel(to: deviceID)
            }
            return
        }

        tunnelSocket = fd
        isConnected = true
        readTunnel()
    }

    private func closeTunnel() {
        if tunnelSocket >= 0 { close(tunnelSocket); tunnelSocket = -1 }
        inbox.removeAll()
        isConnected = false
    }

    /// Lecture du tunnel, sur sa propre file : `read` bloque.
    private func readTunnel() {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self else { return }
            var buffer = [UInt8](repeating: 0, count: 16 * 1024)
            while self.tunnelSocket >= 0 {
                let count = read(self.tunnelSocket, &buffer, buffer.count)
                guard count > 0 else { break }
                let chunk = Data(buffer[0..<count])
                self.queue.async {
                    self.inbox.append(chunk)
                    self.drain()
                }
            }
            self.queue.async { self.closeTunnel() }
        }
    }

    func send(_ payload: Data) {
        queue.async { [weak self] in
            guard let self, self.tunnelSocket >= 0 else { return }
            let packet = Self.frame(payload)
            _ = packet.withUnsafeBytes { raw in
                write(self.tunnelSocket, raw.baseAddress, raw.count)
            }
        }
    }

#else

    // MARK: - iPhone : écouteur local

    private var listener: NWListener?
    private var connection: NWConnection?

    func start() {
        queue.async { [weak self] in
            guard let self, self.listener == nil else { return }
            do {
                let parameters = NWParameters.tcp
                if let tcp = parameters.defaultProtocolStack.internetProtocol
                    as? NWProtocolTCP.Options {
                    tcp.noDelay = true
                }
                // Réutilisation autorisée : après une coupure de câble, le
                // port reste réservé quelques secondes et l'écouteur refuserait
                // de repartir.
                parameters.allowLocalEndpointReuse = true

                let listener = try NWListener(
                    using: parameters,
                    on: NWEndpoint.Port(rawValue: Self.devicePort) ?? .any)
                listener.newConnectionHandler = { [weak self] connection in
                    self?.accept(connection)
                }
                listener.start(queue: self.queue)
                self.listener = listener
            } catch {
                NSLog("TrackPadHub: écoute USB impossible — %@", "\(error)")
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.connection?.cancel()
            self.connection = nil
            self.listener?.cancel()
            self.listener = nil
            self.inbox.removeAll()
            self.isConnected = false
        }
    }

    private func accept(_ incoming: NWConnection) {
        connection?.cancel()
        connection = incoming
        incoming.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.isConnected = true
                self.receive(incoming)
            case .failed, .cancelled:
                if self.connection === incoming {
                    self.connection = nil
                    self.inbox.removeAll()
                    self.isConnected = false
                }
            default:
                break
            }
        }
        incoming.start(queue: queue)
    }

    private func receive(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.inbox.append(data)
                self.drain()
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receive(connection)
        }
    }

    func send(_ payload: Data) {
        queue.async { [weak self] in
            guard let self, let connection = self.connection else { return }
            connection.send(content: Self.frame(payload), completion: .idempotent)
        }
    }

#endif
}
