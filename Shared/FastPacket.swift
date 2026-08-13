import Foundation

/// Encodage compact des messages à haute fréquence.
///
/// Un déplacement de curseur part jusqu'à 120 fois par seconde. En JSON, il
/// pèse une centaine d'octets — noms de champs compris — et demande un
/// encodage complet à chaque fois. Ici : **11 octets**, sans allocation ni
/// analyse syntaxique.
///
/// Le premier octet distingue les deux formats. Un document JSON commence
/// toujours par `{` (0x7B) : la marque 0x01 ne peut donc pas être confondue,
/// et les deux encodages cohabitent sur la même liaison.
enum FastPacket {

    static let marker: UInt8 = 0x01

    private enum Kind: UInt8 {
        case move   = 1
        case scroll = 2
        case zoom   = 3
        case click  = 4
    }

    /// Phases de défilement, codées sur un octet.
    private static let phaseOrder: [ScrollPhase] = [
        .began, .changed, .ended, .momentum, .momentumEnded
    ]

    // MARK: - Encodage

    /// Renvoie la version compacte d'un message, ou nil s'il n'est pas
    /// éligible — les messages rares restent en JSON, plus lisible et plus
    /// souple.
    static func encode(_ message: Message) -> Data? {
        switch message.kind {
        case Message.Kind.trackpad:
            return packet(.move, message.dx ?? 0, message.dy ?? 0, 0)

        case Message.Kind.scroll:
            let phase = phaseOrder.firstIndex(of: message.phase ?? .changed) ?? 1
            return packet(.scroll, message.dx ?? 0, message.dy ?? 0, UInt8(phase))

        case Message.Kind.zoom:
            let phase = phaseOrder.firstIndex(of: message.phase ?? .changed) ?? 1
            return packet(.zoom, message.dx ?? 0, 0, UInt8(phase))

        case Message.Kind.click:
            // Bouton sur les 2 bits bas, état enfoncé sur le bit 7.
            let button = UInt8(min(max(message.button ?? 0, 0), 3))
            let flags = button | ((message.down ?? false) ? 0x80 : 0)
            return packet(.click, 0, 0, flags)

        default:
            return nil
        }
    }

    private static func packet(_ kind: Kind, _ dx: Double, _ dy: Double, _ flags: UInt8) -> Data {
        var data = Data(capacity: 11)
        data.append(marker)
        data.append(kind.rawValue)
        // Float32 suffit : un delta de curseur ne dépasse jamais quelques
        // milliers de points, et la précision au millième est inutile.
        withUnsafeBytes(of: Float(dx).bitPattern.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: Float(dy).bitPattern.littleEndian) { data.append(contentsOf: $0) }
        data.append(flags)
        return data
    }

    // MARK: - Décodage

    static func decode(_ data: Data) -> Message? {
        guard data.count == 11, data[data.startIndex] == marker,
              let kind = Kind(rawValue: data[data.startIndex + 1]) else { return nil }

        let dx = Double(float(from: data, at: data.startIndex + 2))
        let dy = Double(float(from: data, at: data.startIndex + 6))
        let flags = data[data.startIndex + 10]

        switch kind {
        case .move:
            return .trackpad(dx: dx, dy: dy)
        case .scroll:
            return .scroll(dx: dx, dy: dy, phase: phase(flags))
        case .zoom:
            return .zoom(magnification: dx, phase: phase(flags))
        case .click:
            return .click(button: Int(flags & 0x03), down: flags & 0x80 != 0)
        }
    }

    private static func phase(_ raw: UInt8) -> ScrollPhase {
        let index = Int(raw)
        return phaseOrder.indices.contains(index) ? phaseOrder[index] : .changed
    }

    private static func float(from data: Data, at offset: Int) -> Float {
        var bits: UInt32 = 0
        for byte in 0..<4 {
            bits |= UInt32(data[offset + byte]) << (8 * byte)
        }
        return Float(bitPattern: bits)
    }
}
