import Foundation

/// Un onglet du navigateur du Mac, tel que l'iPhone l'affiche.
struct BrowserTab: Codable, Identifiable, Equatable {
    /// Index AppleScript, qui commence à **1** et non à 0.
    ///
    /// La convention est conservée de bout en bout plutôt que convertie deux
    /// fois : c'est cet index qui repart vers le Mac pour sélectionner ou
    /// fermer l'onglet.
    let index: Int
    let title: String
    /// L'onglet actuellement au premier plan.
    let isCurrent: Bool

    var id: Int { index }
}

/// Ce qu'on peut faire à un onglet depuis l'iPhone.
enum BrowserTabAction: String, Codable, CaseIterable, Identifiable {
    case select
    case close
    case closeCurrent
    case new
    case next
    case previous
    case reopen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .select:       return "Aller à l'onglet"
        case .close:        return "Fermer l'onglet"
        case .closeCurrent: return "Fermer"
        case .new:          return "Nouvel onglet"
        case .next:         return "Suivant"
        case .previous:     return "Précédent"
        case .reopen:       return "Rouvrir"
        }
    }

    var icon: String {
        switch self {
        case .select:       return "arrow.right.circle"
        case .close:        return "xmark"
        case .closeCurrent: return "xmark.circle"
        case .new:          return "plus"
        case .next:         return "chevron.right"
        case .previous:     return "chevron.left"
        case .reopen:       return "arrow.uturn.backward"
        }
    }

    /// Les commandes proposées en grille, hors sélection et fermeture d'un
    /// onglet précis — celles-là s'obtiennent en touchant la ligne.
    static let buttons: [BrowserTabAction] = [.previous, .next, .new, .closeCurrent, .reopen]
}
