import Foundation
import CryptoKit

/// Chiffrement d'une session, partagé par tous les transports.
///
/// Extrait de `DirectLink` pour que le Bluetooth puisse s'en servir aussi.
/// Sans ça, brancher un second transport aurait fait circuler les frappes
/// clavier en clair — sur les ondes, où n'importe qui à dix mètres écoute.
///
/// ## Ce qu'il garantit
///
/// - **Confidentialité** : AES-GCM, clé dérivée par HKDF-SHA256 du jeton
///   d'appairage, salée par le défi de la connexion en cours. La clé change
///   donc à chaque connexion.
/// - **Anti-rejeu** : le nonce porte un compteur strictement croissant, par
///   canal. Un paquet capté ne peut être ni rejoué plus tard, ni rejoué sur
///   un autre canal.
///
/// ## Canaux
///
/// Un canal est un sens de circulation sur un transport donné. Les séparer
/// n'est pas cosmétique : deux compteurs indépendants qui repartent de zéro
/// produiraient deux fois le même nonce avec la même clé, ce qui casse GCM.
enum CipherChannel: UInt8 {
    case tcpFromHost = 0
    case tcpFromClient = 1
    case udpFromHost = 2
    case udpFromClient = 3
    case bleFromHost = 4
    case bleFromClient = 5
    case usbFromHost = 6
    case usbFromClient = 7
}

final class SessionCipher {

    /// Marque de trame scellée. Ne peut être confondue ni avec un JSON, qui
    /// commence par `{` (0x7B), ni avec un `FastPacket`, qui commence par
    /// 0x01.
    static let sealedMarker: UInt8 = 0x02

    private let key: SymmetricKey
    private let lock = NSLock()
    private var sendCounters: [UInt8: UInt64] = [:]
    private var lastSeen: [UInt8: UInt64] = [:]

    /// - `token` : le jeton d'appairage, secret partagé des deux côtés.
    /// - `nonce` : le défi de cette connexion, qui sale la clé.
    ///
    /// Le jeton n'est pas employé tel quel : il sert aussi de secret HMAC pour
    /// l'appairage, et réutiliser une même valeur pour deux usages
    /// cryptographiques distincts est une mauvaise habitude qui finit par
    /// coûter cher.
    init(token: String, nonce: String) {
        key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(token.utf8)),
            salt: Data("TrackPadHub.\(nonce)".utf8),
            info: Data("session".utf8),
            outputByteCount: 32)
    }

    // MARK: - Scellement

    func seal(_ payload: Data, channel: CipherChannel) -> Data {
        lock.lock()
        let counter = (sendCounters[channel.rawValue] ?? 0) + 1
        sendCounters[channel.rawValue] = counter
        lock.unlock()

        var raw = Data([channel.rawValue])
        var big = counter.bigEndian
        withUnsafeBytes(of: &big) { raw.append(contentsOf: $0) }
        raw.append(contentsOf: [0, 0, 0])

        guard let gcmNonce = try? AES.GCM.Nonce(data: raw),
              let box = try? AES.GCM.seal(payload, using: key, nonce: gcmNonce),
              let combined = box.combined else { return payload }
        return Data([Self.sealedMarker]) + combined
    }

    /// Ouvre une trame scellée, ou renvoie nil si elle est illisible, forgée,
    /// ou déjà vue.
    func open(_ data: Data, channel: CipherChannel) -> Data? {
        guard let first = data.first, first == Self.sealedMarker else { return nil }

        let combined = data.subdata(in: (data.startIndex + 1)..<data.endIndex)
        guard let box = try? AES.GCM.SealedBox(combined: combined),
              let payload = try? AES.GCM.open(box, using: key) else { return nil }

        let nonce = Data(box.nonce)
        guard nonce.count == 12, nonce[nonce.startIndex] == channel.rawValue else { return nil }
        let counter = nonce.subdata(in: (nonce.startIndex + 1)..<(nonce.startIndex + 9))
            .reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }

        lock.lock()
        defer { lock.unlock() }
        // Strictement croissant. Pour un datagramme UDP arrivé en retard,
        // écarter est le bon comportement : sur un delta de curseur, seul le
        // plus récent compte.
        guard counter > (lastSeen[channel.rawValue] ?? 0) else { return nil }
        lastSeen[channel.rawValue] = counter
        return payload
    }
}
