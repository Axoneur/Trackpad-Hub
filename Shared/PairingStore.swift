import Foundation

/// Un appareil autorisé à piloter le Mac.
struct PairedDevice: Codable, Equatable {
    /// Secret partagé, prouvé par HMAC à chaque connexion.
    var token: String
    /// Nom lisible, pour l'affichage sur le Mac.
    var name: String
}

/// Stockage des secrets d'appairage dans le trousseau.
///
/// Volontairement pas dans `UserDefaults` : le jeton donne le contrôle
/// complet du Mac, il n'a rien à faire dans un fichier de préférences ni
/// dans une sauvegarde en clair.
///
/// Côté iOS, l'app et l'extension de clavier partagent le même groupe de
/// trousseau (voir les fichiers `.entitlements`) : l'extension hérite alors
/// de l'appairage fait dans l'app. Si le partage est refusé par le compte
/// Apple utilisé, l'extension demandera simplement son propre code une fois.
enum PairingStore {

    /// Compte réservé à l'identifiant permanent de cet appareil.
    private static let identityAccount = "device-identity"
    /// Préfixe des comptes utilisés pour les appareils appairés.
    private static let devicePrefix = "device:"
    /// Préfixe des comptes utilisés pour les jetons reçus d'un Mac.
    private static let hostPrefix = "host:"

    // MARK: - Appareils appairés (côté Mac)

    /// Appareils explicitement oubliés.
    ///
    /// Supprimer l'élément du trousseau ne suffit pas toujours : sur macOS, un
    /// élément appartient à la signature de l'app qui l'a créé, et une app
    /// recompilée peut ne plus avoir le droit de l'effacer. La suppression
    /// échoue alors sans erreur visible, et « Oublier » ne fait rien.
    ///
    /// Cette liste tranche : un appareil qui y figure est refusé, que son
    /// jeton traîne encore ou non.
    private static let revokedKey = "revokedDevices"

    private static var revoked: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: revokedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: revokedKey) }
    }

    static func device(for deviceID: String) -> PairedDevice? {
        guard !revoked.contains(deviceID) else { return nil }
        return KeychainBox.decode(PairedDevice.self, devicePrefix + deviceID)
    }

    @discardableResult
    static func setDevice(_ device: PairedDevice, for deviceID: String) -> Bool {
        // Un nouvel appairage lève la révocation.
        revoked.remove(deviceID)
        return KeychainBox.encode(device, for: devicePrefix + deviceID)
    }

    /// Renomme un appareil appairé.
    ///
    /// Le nom envoyé par l'iPhone est celui de l'appareil, et iOS renvoie
    /// « iPhone » pour tout le monde depuis qu'il masque le nom réel. Sans
    /// renommage, deux téléphones sont indiscernables dans la liste.
    @discardableResult
    static func rename(_ deviceID: String, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var device = device(for: deviceID) else { return false }
        device.name = trimmed
        return KeychainBox.encode(device, for: devicePrefix + deviceID)
    }

    static func removeDevice(_ deviceID: String) {
        KeychainBox.remove(devicePrefix + deviceID)
        // Révoqué dans tous les cas, même si l'effacement a échoué.
        revoked.insert(deviceID)
    }

    /// Tous les appareils appairés : (identifiant, appareil).
    static func pairedDevices() -> [(id: String, device: PairedDevice)] {
        let revokedNow = revoked
        return KeychainBox.accounts()
            .filter { $0.hasPrefix(devicePrefix) }
            .compactMap { account in
                let id = String(account.dropFirst(devicePrefix.count))
                // Un appareil révoqué disparaît de la liste même si son
                // élément de trousseau n'a pas pu être effacé.
                guard !revokedNow.contains(id), let device = device(for: id) else { return nil }
                return (id: id, device: device)
            }
            .sorted { $0.device.name.localizedCaseInsensitiveCompare($1.device.name) == .orderedAscending }
    }

    // MARK: - Secret partagé (côté iPhone)

    /// Jeton reçu d'un Mac donné.
    static func token(forHost host: String) -> String? {
        KeychainBox.string(hostPrefix + host)
    }

    @discardableResult
    static func setToken(_ token: String, forHost host: String) -> Bool {
        KeychainBox.set(token, for: hostPrefix + host)
    }

    static func removeToken(forHost host: String) {
        KeychainBox.remove(hostPrefix + host)
    }

    /// Macs auxquels cet iPhone est déjà appairé.
    static func knownHosts() -> [String] {
        KeychainBox.accounts()
            .filter { $0.hasPrefix(hostPrefix) }
            .map { String($0.dropFirst(hostPrefix.count)) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Identité permanente de l'appareil

    /// Identifiant stable de cet appareil, partagé entre l'app et l'extension
    /// de clavier. Le nom du pair ne peut pas servir : il change avec le nom
    /// de l'iPhone et diffère entre l'app et l'extension.
    static func deviceIdentity() -> String {
        if let existing = KeychainBox.string(identityAccount), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        KeychainBox.set(created, for: identityAccount)
        return created
    }

    static func removeAll() {
        for account in KeychainBox.accounts() {
            KeychainBox.remove(account)
        }
    }
}
