import Foundation

/// Une étape de macro : un message, et le temps écoulé depuis le précédent.
///
/// Le délai est conservé parce qu'une séquence rejouée d'un bloc ne marche
/// pas : ouvrir Spotlight puis taper immédiatement perd les premières lettres,
/// le temps que la fenêtre apparaisse. Rejouer au rythme d'origine reproduit
/// ce que l'utilisateur a fait, y compris ses pauses.
struct MacroStep: Codable, Identifiable, Equatable {
    let id: UUID
    let message: Message
    /// Secondes écoulées depuis l'étape précédente, bornées à 5 s.
    let delay: Double

    init(message: Message, delay: Double) {
        self.id = UUID()
        self.message = message
        // Une pause de trois minutes parce qu'on a été interrompu ne fait pas
        // partie de la macro.
        self.delay = min(max(delay, 0), 5)
    }
}

/// Une séquence enregistrée, rejouable d'un appui.
struct Macro: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var steps: [MacroStep]

    init(id: UUID = UUID(), name: String, icon: String = "wand.and.rays", steps: [MacroStep]) {
        self.id = id
        self.name = name
        self.icon = icon
        self.steps = steps
    }

    /// Durée totale, pour l'afficher avant de lancer.
    var duration: Double { steps.reduce(0) { $0 + $1.delay } }

    /// Résumé lisible : « 12 étapes · 3,4 s ».
    var summary: String {
        let count = steps.count
        let unit = count > 1 ? "étapes" : "étape"
        return String(format: "%d %@ · %.1f s", count, unit, duration)
    }
}

extension Message {
    /// Vrai si ce message mérite d'être enregistré dans une macro.
    ///
    /// Les déplacements, défilements et zooms sont exclus : ils arrivent par
    /// centaines et dépendent de l'endroit exact où se trouvait le curseur.
    /// Les rejouer produirait un gribouillage, pas une automatisation. Ce
    /// qu'on garde, ce sont les actions discrètes — touches, clics,
    /// raccourcis, commandes système.
    var isRecordable: Bool {
        switch kind {
        case Kind.trackpad, Kind.scroll, Kind.zoom:
            return false
        default:
            return isControlMessage
        }
    }

    /// Description courte, pour la liste des étapes.
    var stepDescription: String {
        switch kind {
        case Kind.character:  return "Touche « \(text ?? "?") »"
        case Kind.specialKey: return "Touche \(name ?? "?")"
        case Kind.text:       return "Texte « \(text ?? "") »"
        case Kind.click:      return (down ?? false) ? "Clic enfoncé" : "Clic relâché"
        case Kind.media:      return "Média : \(command ?? "?")"
        case Kind.system:     return "Système : \(action ?? "?")"
        case Kind.gesture:    return "Geste : \(action ?? "?")"
        case Kind.window:     return "Fenêtre : \(action ?? "?")"
        case Kind.appLaunch:  return "Ouvrir \(target ?? "?")"
        case Kind.shortcut:   return "Raccourci \(name ?? action ?? "?")"
        default:              return kind
        }
    }
}
