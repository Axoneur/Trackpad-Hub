import Foundation
import CryptoKit

/// Primitives d'appairage entre l'iPhone et le Mac.
///
/// Le secret (code à 6 chiffres, puis jeton permanent) ne circule **jamais**
/// sur le réseau : l'iPhone prouve qu'il le connaît en signant un défi
/// aléatoire fourni par le Mac (HMAC-SHA256).
enum Pairing {

    /// Code d'appairage affiché sur le Mac.
    static func makePin() -> String {
        String(format: "%06d", Int.random(in: 0..<1_000_000))
    }

    /// Défi aléatoire, renouvelé à chaque connexion : empêche le rejeu d'une
    /// preuve interceptée.
    static func makeNonce() -> String {
        randomBytes(32).base64EncodedString()
    }

    /// Jeton permanent remis à l'iPhone après un appairage réussi.
    static func makeToken() -> String {
        randomBytes(32).base64EncodedString()
    }

    /// Preuve de connaissance du secret.
    static func proof(secret: String, nonce: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let code = HMAC<SHA256>.authenticationCode(for: Data(nonce.utf8), using: key)
        return Data(code).base64EncodedString()
    }

    /// Comparaison à temps constant : une comparaison classique laisserait
    /// fuiter le préfixe correct par le temps de réponse.
    static func matches(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        guard a.count == b.count else { return false }
        var difference: UInt8 = 0
        for index in a.indices {
            difference |= a[index] ^ b[index]
        }
        return difference == 0
    }

    private static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        if SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess {
            return Data(bytes)
        }
        // Repli : ne devrait jamais servir, mais mieux vaut un aléa faible
        // qu'un secret constant.
        return Data((0..<count).map { _ in UInt8.random(in: 0...255) })
    }
}
