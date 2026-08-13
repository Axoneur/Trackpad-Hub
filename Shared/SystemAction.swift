import Foundation

/// Actions système déclenchables depuis l'iPhone.
enum SystemAction: String, Codable, CaseIterable, Identifiable {
    case sleep
    case lock
    case restart
    case shutdown
    case logout
    case showDesktop
    case missionControl
    case launchpad
    case spotlight
    case screensaver
    case displaySleep
    /// Bascule un **mode de concentration** macOS (Ne pas déranger, Travail,
    /// Sommeil, Personnel…).
    ///
    /// **Passe par un raccourci que l'utilisateur doit créer.** macOS n'expose
    /// aucune API publique pour changer de mode Focus : ni AppleScript, ni
    /// `defaults`, qui ne fonctionne plus depuis des années. La seule voie
    /// supportée est l'action « Régler le mode de concentration » de l'app
    /// Raccourcis, lancée par `shortcuts run`.
    ///
    /// Le raccourci doit s'appeler exactement `TrackPad Hub Focus`. L'app le
    /// dit clairement quand il manque, plutôt que de ne rien faire.
    case focusToggle
    /// Sous-titres en direct de macOS.
    ///
    /// Alternative aux sous-titres temps réel « maison », qui auraient exigé
    /// de capter le son du système, donc un pilote audio virtuel. macOS sait
    /// déjà le faire — autant l'allumer plutôt que le refaire.
    ///
    /// Aucune API publique là non plus : ni domaine `defaults`, ni
    /// AppleScript. Même schéma que la concentration — un raccourci s'il
    /// existe, sinon on ouvre le bon volet des Réglages.
    case liveCaptions

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sleep:          return "Veille"
        case .lock:           return "Verrouiller"
        case .restart:        return "Redémarrer"
        case .shutdown:       return "Éteindre"
        case .logout:         return "Déconnexion"
        case .showDesktop:    return "Bureau"
        case .missionControl: return "Mission Control"
        case .launchpad:      return "Fenêtre suivante"
        case .spotlight:      return "Spotlight"
        case .screensaver:    return "Écran de veille"
        case .displaySleep:   return "Éteindre l'écran"
        case .focusToggle:    return "Concentration"
        case .liveCaptions:   return "Sous-titres"
        }
    }

    var icon: String {
        switch self {
        case .sleep:          return "moon.fill"
        case .lock:           return "lock.fill"
        case .restart:        return "arrow.clockwise"
        case .shutdown:       return "power"
        case .logout:         return "rectangle.portrait.and.arrow.right"
        case .showDesktop:    return "menubar.dock.rectangle"
        case .missionControl: return "square.grid.3x2"
        case .launchpad:      return "macwindow.on.rectangle"
        case .spotlight:      return "magnifyingglass"
        case .screensaver:    return "display"
        case .displaySleep:   return "display.trianglebadge.exclamationmark"
        case .focusToggle:    return "moon.circle.fill"
        case .liveCaptions:   return "captions.bubble.fill"
        }
    }

    /// Ces actions font perdre du travail non enregistré : l'iPhone demande
    /// confirmation avant de les envoyer.
    var needsConfirmation: Bool {
        switch self {
        case .restart, .shutdown, .logout: return true
        default: return false
        }
    }

    /// Actions groupées pour l'affichage.
    static let power: [SystemAction] = [.sleep, .lock, .displaySleep, .screensaver, .logout, .restart, .shutdown]
    static let navigation: [SystemAction] = [.showDesktop, .missionControl, .launchpad, .spotlight, .focusToggle, .liveCaptions]
}

/// Gestes système de macOS, déclenchés par un balayage sur l'iPhone.
///
/// macOS n'expose aucune API publique pour fabriquer un événement de geste
/// (balayage, rotation, zoom intelligent). On passe donc par les raccourcis
/// clavier équivalents, qui sont exactement ce que le système déclenche
/// lui-même derrière ces gestes.
enum GestureAction: String, Codable, CaseIterable, Identifiable {
    case missionControl
    case appExpose
    case spaceLeft
    case spaceRight
    case showDesktop
    case spotlight
    case lookUp
    /// Remplace le geste de rotation, que macOS ne permet pas de simuler.
    case rotateLeft
    case rotateRight
    /// Remplace le zoom intelligent : revient à la taille réelle.
    case zoomReset

    var id: String { rawValue }

    var label: String {
        switch self {
        case .missionControl: return "Mission Control"
        case .appExpose:      return "App Exposé"
        case .spaceLeft:      return "Bureau précédent"
        case .spaceRight:     return "Bureau suivant"
        case .showDesktop:    return "Afficher le bureau"
        case .spotlight:      return "Recherche"
        case .lookUp:         return "Rechercher le mot"
        case .rotateLeft:     return "Pivoter à gauche"
        case .rotateRight:    return "Pivoter à droite"
        case .zoomReset:      return "Taille réelle"
        }
    }

    /// Geste qui la déclenche, pour l'affichage dans l'aide.
    var gesture: String {
        switch self {
        case .missionControl: return "3 doigts vers le haut"
        case .appExpose:      return "3 doigts vers le bas"
        case .spaceLeft:      return "3 doigts vers la gauche"
        case .spaceRight:     return "3 doigts vers la droite"
        case .showDesktop:    return "4 doigts qu'on écarte"
        case .spotlight:      return "4 doigts qu'on rapproche"
        case .lookUp:         return "Appui long à un doigt"
        case .rotateLeft:     return "2 doigts qui pivotent vers la gauche"
        case .rotateRight:    return "2 doigts qui pivotent vers la droite"
        case .zoomReset:      return "2 doigts, double appui"
        }
    }
}

/// Actions du mode présentation.
enum PresentationAction: String, Codable, CaseIterable, Identifiable {
    case next
    case previous
    case start
    case end
    case blackScreen
    case whiteScreen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .next:        return "Suivante"
        case .previous:    return "Précédente"
        case .start:       return "Démarrer"
        case .end:         return "Quitter"
        case .blackScreen: return "Écran noir"
        case .whiteScreen: return "Écran blanc"
        }
    }

    var icon: String {
        switch self {
        case .next:        return "chevron.right"
        case .previous:    return "chevron.left"
        case .start:       return "play.rectangle.fill"
        case .end:         return "xmark.rectangle"
        case .blackScreen: return "moon.stars.fill"
        case .whiteScreen: return "sun.max.fill"
        }
    }
}

/// Ce qu'on peut faire d'une app du Mac depuis l'iPhone.
enum AppAction: String, Codable, CaseIterable, Identifiable {
    case activate
    case hide
    case unhide
    /// Gèle le processus (SIGSTOP) : il cesse de consommer du processeur
    /// sans perdre son état.
    case suspend
    case resume
    case quit
    /// Fermeture forcée, pour une app qui ne répond plus.
    case forceQuit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .activate:  return "Afficher"
        case .hide:      return "Masquer"
        case .unhide:    return "Démasquer"
        case .suspend:   return "Suspendre"
        case .resume:    return "Reprendre"
        case .quit:      return "Quitter"
        case .forceQuit: return "Forcer à quitter"
        }
    }

    var icon: String {
        switch self {
        case .activate:  return "arrow.up.forward.app"
        case .hide:      return "eye.slash"
        case .unhide:    return "eye"
        case .suspend:   return "pause.circle"
        case .resume:    return "play.circle"
        case .quit:      return "xmark.circle"
        case .forceQuit: return "exclamationmark.octagon"
        }
    }

    var isDestructive: Bool {
        self == .quit || self == .forceQuit
    }
}

/// Une app en cours d'exécution sur le Mac.
struct RunningApp: Codable, Identifiable, Equatable {
    var bundleID: String
    var name: String
    /// Icône PNG encodée en base64, redimensionnée côté Mac.
    var iconBase64: String?
    var isActive: Bool
    var isHidden: Bool = false
    var isSuspended: Bool = false

    var id: String { bundleID }

    /// Actions pertinentes selon l'état courant : proposer « Reprendre » sur
    /// une app qui tourne n'aurait pas de sens.
    var availableActions: [AppAction] {
        var actions: [AppAction] = [.activate]
        actions.append(isHidden ? .unhide : .hide)
        actions.append(isSuspended ? .resume : .suspend)
        actions.append(contentsOf: [.quit, .forceQuit])
        return actions
    }
}

/// Une app installée sur le Mac, ouverte ou non.
struct InstalledApp: Codable, Identifiable, Equatable {
    var bundleID: String
    var name: String
    var iconBase64: String?
    var isRunning: Bool

    var id: String { bundleID }
}

/// Constantes système du Mac.
struct MacVitals: Codable, Equatable {
    var batteryPercent: Int?
    var isCharging: Bool?
    var diskFreeGB: Double
    var diskTotalGB: Double
    var memoryUsedGB: Double
    var memoryTotalGB: Double
    var cpuPercent: Double
    var uptime: String
    var hostName: String
}
