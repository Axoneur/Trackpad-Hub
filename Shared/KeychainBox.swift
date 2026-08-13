import Foundation
import Security

/// Accès brut au trousseau, partagé par tous les stockages de l'app.
///
/// Le trousseau sert ici de canal entre des processus séparés — l'app, le
/// clavier système et les widgets — parce qu'il est le seul mécanisme de
/// partage disponible sans adhésion Apple payante. Un App Group serait plus
/// naturel, mais il est réservé aux comptes payants.
///
/// Si même le partage de trousseau est refusé, les écritures atterrissent
/// dans l'espace privé de chaque processus : rien ne casse, chaque cible
/// travaille simplement avec ses propres données.
enum KeychainBox {

    static let service = "com.trackpadhub.shared"

    static func data(_ account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    static func set(_ data: Data, for account: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)

        var item = base
        item[kSecValueData as String] = data
        // Lisible après le premier déverrouillage : les widgets se
        // rafraîchissent écran verrouillé, ils doivent pouvoir lire.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        // Pas de kSecAttrAccessGroup explicite : l'élément va dans le premier
        // groupe déclaré par les entitlements, donc le groupe partagé quand
        // il est autorisé, l'espace privé sinon.
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func remove(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func accounts() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    // MARK: - Confort

    static func string(_ account: String) -> String? {
        data(account).flatMap { String(data: $0, encoding: .utf8) }
    }

    @discardableResult
    static func set(_ string: String, for account: String) -> Bool {
        set(Data(string.utf8), for: account)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ account: String) -> T? {
        data(account).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    @discardableResult
    static func encode<T: Encodable>(_ value: T, for account: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return set(data, for: account)
    }
}
