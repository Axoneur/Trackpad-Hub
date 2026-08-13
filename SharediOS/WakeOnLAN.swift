import Foundation
import Darwin

/// Réveille un Mac endormi en lui envoyant un « paquet magique ».
///
/// Le paquet est diffusé sur le réseau local : le Mac est éteint côté logiciel,
/// seule sa carte réseau écoute encore. Il n'y a donc aucune connexion à
/// établir — on tire, sans accusé de réception.
enum WakeOnLAN {

    enum Failure: LocalizedError {
        case invalidAddress
        case socketUnavailable
        case sendFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .invalidAddress:
                return "Adresse MAC du Mac invalide."
            case .socketUnavailable:
                return "Impossible d'ouvrir une socket réseau."
            case .sendFailed(let code):
                return "Envoi refusé par le système (code \(code)). Vérifiez que l'iPhone est sur le Wi-Fi."
            }
        }
    }

    /// Port 9 (discard) : la convention pour le Wake on LAN.
    static func wake(macAddress: String,
                     broadcast: String = "255.255.255.255",
                     port: UInt16 = 9) throws {
        let packet = try magicPacket(for: macAddress)

        let handle = socket(AF_INET, SOCK_DGRAM, 0)
        guard handle >= 0 else { throw Failure.socketUnavailable }
        defer { close(handle) }

        var enabled: Int32 = 1
        setsockopt(handle, SOL_SOCKET, SO_BROADCAST, &enabled, socklen_t(MemoryLayout<Int32>.size))

        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = port.bigEndian
        destination.sin_addr.s_addr = inet_addr(broadcast)

        let sent = packet.withUnsafeBytes { buffer -> Int in
            withUnsafePointer(to: &destination) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                    sendto(handle, buffer.baseAddress, buffer.count, 0,
                           address, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        guard sent > 0 else { throw Failure.sendFailed(errno) }
    }

    /// 6 octets à 0xFF, puis 16 répétitions de l'adresse MAC.
    static func magicPacket(for macAddress: String) throws -> Data {
        let bytes = macAddress
            .split(whereSeparator: { $0 == ":" || $0 == "-" })
            .compactMap { UInt8($0, radix: 16) }

        guard bytes.count == 6 else { throw Failure.invalidAddress }

        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: bytes)
        }
        return packet
    }
}
