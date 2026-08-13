import Foundation

/// Date d'expiration de la signature de l'app.
///
/// ## Pourquoi cette classe existe
///
/// Avec un compte Apple **gratuit**, un profil de provisionnement vaut
/// **7 jours**. Passé ce délai l'app cesse de s'ouvrir — sans message, sans
/// explication. Beaucoup de gens croient alors que l'app est cassée.
///
/// L'app connaît pourtant sa propre date d'expiration : elle est écrite dans le
/// profil embarqué dans son bundle. Autant la lire et prévenir.
///
/// **Le Mac n'a pas de profil** : il est signé par un simple certificat de
/// développement, sans provisionnement. Seul l'iPhone est concerné — vérifié
/// sur l'app installée, `Contents/embedded.provisionprofile` n'existe pas.
enum SigningExpiry {

    /// Date d'expiration, ou nil quand l'app n'embarque aucun profil.
    static let date: Date? = readExpiration()

    /// Jours restants, arrondis vers le bas. Négatif si déjà expiré.
    static var daysRemaining: Int? {
        guard let date else { return nil }
        let secondes = date.timeIntervalSinceNow
        return Int(floor(secondes / 86_400))
    }

    /// Vrai quand il reste trois jours ou moins : le moment d'avertir, assez
    /// tôt pour réinstaller sans urgence.
    static var isExpiringSoon: Bool {
        guard let jours = daysRemaining else { return false }
        return jours <= 3
    }

    static var isExpired: Bool {
        guard let jours = daysRemaining else { return false }
        return jours < 0
    }

    /// Formulation courte, prête à afficher.
    static var summary: String? {
        guard let jours = daysRemaining else { return nil }
        if jours < 0 { return "Signature expirée" }
        if jours == 0 { return "Signature expire aujourd'hui" }
        if jours == 1 { return "Signature expire demain" }
        return "Signature valable \(jours) jours"
    }

    // MARK: - Lecture du profil

    private static func readExpiration() -> Date? {
        // iOS embarque `embedded.mobileprovision` à la racine du bundle ;
        // macOS, quand il en a un, le range dans `Contents/`.
        let candidats = [
            Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/embedded.provisionprofile")
        ].compactMap { $0 }

        for url in candidats {
            guard let donnees = try? Data(contentsOf: url),
                  let date = expiration(dans: donnees) else { continue }
            return date
        }
        return nil
    }

    /// Extrait la date du plist enrobé dans la signature CMS.
    ///
    /// Le fichier est un conteneur signé : on ne peut pas l'analyser
    /// directement. Plutôt que de dépendre de `Security` pour dérouler le CMS,
    /// on découpe entre les balises du plist en clair qu'il contient — c'est
    /// suffisant, stable, et sans dépendance.
    private static func expiration(dans donnees: Data) -> Date? {
        guard let debut = donnees.range(of: Data("<?xml".utf8)),
              let fin = donnees.range(of: Data("</plist>".utf8)) else { return nil }
        let plist = donnees[debut.lowerBound..<fin.upperBound]

        guard let objet = try? PropertyListSerialization.propertyList(
                from: plist, options: [], format: nil),
              let dictionnaire = objet as? [String: Any] else { return nil }
        return dictionnaire["ExpirationDate"] as? Date
    }
}
