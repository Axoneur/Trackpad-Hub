import Foundation

/// Disposition **affichée** sur l'iPhone (clavier intégré et extension).
///
/// À ne pas confondre avec la disposition du Mac : celle-ci ne concerne que
/// les lettres dessinées sur les touches. Le Mac reçoit des caractères et les
/// traduit selon sa propre disposition.
enum KeyboardStyle: String, Codable, CaseIterable, Identifiable {
    case azerty
    case qwerty
    case qwertz

    var id: String { rawValue }

    var name: String {
        switch self {
        case .azerty: return "AZERTY (français)"
        case .qwerty: return "QWERTY (anglais)"
        case .qwertz: return "QWERTZ (allemand)"
        }
    }

    /// Les trois rangées de lettres, en minuscules.
    var rows: [[String]] {
        switch self {
        case .azerty:
            return [
                ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
                ["w", "x", "c", "v", "b", "n"]
            ]
        case .qwerty:
            return [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["z", "x", "c", "v", "b", "n", "m"]
            ]
        case .qwertz:
            return [
                ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["y", "x", "c", "v", "b", "n", "m"]
            ]
        }
    }

    /// Clé de préférence partagée par l'app et l'extension de clavier.
    static let storageKey = "keyboardStyle"

    static var current: KeyboardStyle {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return KeyboardStyle(rawValue: raw) ?? .azerty
    }
}
