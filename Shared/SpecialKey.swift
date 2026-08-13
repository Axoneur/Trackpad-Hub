import Foundation

/// Touches désignées par leur nom plutôt que par un caractère.
///
/// Leurs keycodes sont les seuls réellement stables d'une disposition à
/// l'autre : la touche « entrée » est au même endroit en QWERTY et en AZERTY,
/// contrairement aux lettres. Tout le reste transite sous forme de caractères
/// et c'est le Mac qui le traduit selon **sa** disposition.
enum SpecialKey: String, Codable, CaseIterable {
    case escape
    case tab
    case delete            // ⌫ retour arrière
    case forwardDelete     // ⌦
    case `return`
    case space
    case up, down, left, right
    case home, end, pageUp, pageDown
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

    /// Keycode macOS (identique quelle que soit la disposition).
    var keycode: UInt16 {
        switch self {
        case .escape:        return 53
        case .tab:           return 48
        case .delete:        return 51
        case .forwardDelete: return 117
        case .return:        return 36
        case .space:         return 49
        case .up:            return 126
        case .down:          return 125
        case .left:          return 123
        case .right:         return 124
        case .home:          return 115
        case .end:           return 119
        case .pageUp:        return 116
        case .pageDown:      return 121

        // Touches de fonction : positions fixes, comme les flèches.
        case .f1:  return 122
        case .f2:  return 120
        case .f3:  return 99
        case .f4:  return 118
        case .f5:  return 96
        case .f6:  return 97
        case .f7:  return 98
        case .f8:  return 100
        case .f9:  return 101
        case .f10: return 109
        case .f11: return 103
        case .f12: return 111
        }
    }

    /// Nom lisible d'une touche à partir de son keycode, pour les traces.
    static func name(forKeycode keycode: UInt16) -> String? {
        allCases.first { $0.keycode == keycode }?.label
    }

    /// Les douze touches de fonction, dans l'ordre d'un clavier.
    static let functionKeys: [SpecialKey] = [
        .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12
    ]

    /// Libellé affiché sur l'iPhone.
    var label: String {
        switch self {
        case .escape:        return "Échap"
        case .tab:           return "Tab"
        case .delete:        return "⌫"
        case .forwardDelete: return "⌦"
        case .return:        return "↵"
        case .space:         return "Espace"
        case .up:            return "↑"
        case .down:          return "↓"
        case .left:          return "←"
        case .right:         return "→"
        case .home:          return "Début"
        case .end:           return "Fin"
        case .pageUp:        return "Page ↑"
        case .pageDown:      return "Page ↓"
        default:             return rawValue.uppercased()
        }
    }
}
