import Foundation

/// Emplacements de la fenêtre active du Mac, à la manière de Magnet ou
/// Rectangle.
///
/// Nommé `WindowSlot` et non `WindowPlacement` : SwiftUI expose déjà un
/// `WindowPlacement`, disponible sur macOS seulement. Le nôtre était masqué
/// par le sien dans les fichiers SwiftUI, et la compilation iOS échouait sur
/// un « unavailable in iOS » parfaitement déroutant.
///
/// Partagé : l'iPhone en tire les libellés et les icônes de sa grille,
/// `MacHost/Services/WindowController.swift` en tire le calcul du cadre.
/// Une seule liste, donc pas de dérive entre ce qu'affiche l'iPhone et ce que
/// le Mac sait exécuter.
enum WindowSlot: String, Codable, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird
    case leftTwoThirds, rightTwoThirds
    case maximize, center, restore
    case nextDisplay
    /// Réduire dans le Dock, et plein écran natif.
    ///
    /// Manquaient, alors que ce sont les deux gestes les plus courants sur une
    /// fenêtre. Passent par les attributs d'accessibilité `AXMinimized` et
    /// `AXFullScreen`, et non par ⌘M : un raccourci clavier ne s'applique qu'à
    /// la fenêtre active de l'app active, alors qu'ici on vise la fenêtre
    /// qu'on vient de placer.
    case minimize, fullscreen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leftHalf:       return "Gauche"
        case .rightHalf:      return "Droite"
        case .topHalf:        return "Haut"
        case .bottomHalf:     return "Bas"
        case .topLeft:        return "Haut gauche"
        case .topRight:       return "Haut droit"
        case .bottomLeft:     return "Bas gauche"
        case .bottomRight:    return "Bas droit"
        case .leftThird:      return "Tiers gauche"
        case .centerThird:    return "Tiers centre"
        case .rightThird:     return "Tiers droit"
        case .leftTwoThirds:  return "⅔ gauche"
        case .rightTwoThirds: return "⅔ droite"
        case .maximize:       return "Plein écran"
        case .center:         return "Centrer"
        case .restore:        return "Rétablir"
        case .nextDisplay:    return "Écran suivant"
        case .minimize:       return "Réduire"
        case .fullscreen:     return "Plein écran natif"
        }
    }

    /// Les symboles `rectangle.*half.filled` montrent la zone occupée : la
    /// grille se lit d'un coup d'œil, sans avoir à déchiffrer les libellés.
    var icon: String {
        switch self {
        case .leftHalf:       return "rectangle.lefthalf.filled"
        case .rightHalf:      return "rectangle.righthalf.filled"
        case .topHalf:        return "rectangle.tophalf.filled"
        case .bottomHalf:     return "rectangle.bottomhalf.filled"
        case .topLeft:        return "rectangle.inset.topleft.filled"
        case .topRight:       return "rectangle.inset.topright.filled"
        case .bottomLeft:     return "rectangle.inset.bottomleft.filled"
        case .bottomRight:    return "rectangle.inset.bottomright.filled"
        case .leftThird:      return "rectangle.lefthalf.inset.filled"
        case .centerThird:    return "rectangle.center.inset.filled"
        case .rightThird:     return "rectangle.righthalf.inset.filled"
        case .leftTwoThirds:  return "rectangle.leadingthird.inset.filled"
        case .rightTwoThirds: return "rectangle.trailingthird.inset.filled"
        case .maximize:       return "rectangle.fill"
        case .center:         return "rectangle.center.inset.filled"
        case .restore:        return "arrow.uturn.backward"
        case .nextDisplay:    return "display.2"
        case .minimize:       return "arrow.down.right.and.arrow.up.left"
        case .fullscreen:     return "arrow.up.left.and.arrow.down.right"
        }
    }

    /// Moitiés et plein écran : ce qu'on utilise dix fois par jour.
    static let common: [WindowSlot] = [
        .leftHalf, .rightHalf, .topHalf, .bottomHalf,
        .maximize, .center, .minimize, .restore
    ]

    /// Quarts, pour partager un écran entre quatre fenêtres.
    static let quarters: [WindowSlot] = [.topLeft, .topRight, .bottomLeft, .bottomRight]

    /// Tiers, surtout utiles sur un écran large où une moitié fait déjà trop.
    static let thirds: [WindowSlot] = [
        .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds
    ]

    /// Actions qui ne déplacent pas la fenêtre mais changent son état.
    static let states: [WindowSlot] = [.fullscreen, .nextDisplay]
}
