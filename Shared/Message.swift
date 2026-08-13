import Foundation

/// Étapes d'un geste de défilement, reprises telles quelles par macOS.
/// Elles permettent aux apps (Safari, Aperçu, Plans…) de réagir comme à un
/// vrai trackpad : rebond en fin de page, inertie, annulation.
enum ScrollPhase: String, Codable {
    /// Les doigts viennent de se poser.
    case began
    /// Les doigts glissent.
    case changed
    /// Les doigts se lèvent, sans inertie.
    case ended
    /// Inertie après le lever des doigts.
    case momentum
    /// Fin de l'inertie.
    case momentumEnded
}

/// Enveloppe JSON unique échangée entre l'iPhone et le Mac.
/// Les champs optionnels sont remplis selon `kind`.
struct Message: Codable, Equatable {
    var kind: String

    // Trackpad / scroll
    var dx: Double?
    var dy: Double?

    // Phase du geste de défilement
    var phase: ScrollPhase?

    // Clic
    var button: Int?

    // Touche clavier
    var keycode: UInt16?
    var flags: Int?
    var down: Bool?

    // Texte
    var text: String?

    // Média
    var command: String?

    // Raccourcis
    var action: String?
    var target: String?
    var name: String?

    // Appairage
    var nonce: String?
    var proof: String?
    var token: String?
    var deviceID: String?

    init(kind: String,
         dx: Double? = nil,
         dy: Double? = nil,
         phase: ScrollPhase? = nil,
         button: Int? = nil,
         keycode: UInt16? = nil,
         flags: Int? = nil,
         down: Bool? = nil,
         text: String? = nil,
         command: String? = nil,
         action: String? = nil,
         target: String? = nil,
         name: String? = nil,
         nonce: String? = nil,
         proof: String? = nil,
         token: String? = nil,
         deviceID: String? = nil) {
        self.kind = kind
        self.dx = dx
        self.dy = dy
        self.phase = phase
        self.button = button
        self.keycode = keycode
        self.flags = flags
        self.down = down
        self.text = text
        self.command = command
        self.action = action
        self.target = target
        self.name = name
        self.nonce = nonce
        self.proof = proof
        self.token = token
        self.deviceID = deviceID
    }

    /// Vrai pour les messages qui pilotent réellement le Mac. Ceux-là sont
    /// rejetés tant que l'appareil n'est pas appairé.
    var isControlMessage: Bool {
        !Kind.authKinds.contains(kind)
    }
}

// MARK: - Types de messages

extension Message {
    enum Kind {
        // Contrôle
        static let trackpad = "trackpad"
        static let click    = "click"
        static let scroll   = "scroll"
        static let zoom     = "zoom"
        static let character  = "char"
        static let specialKey = "specialKey"
        static let text       = "text"
        /// Touche maintenue enfoncée ou relâchée (mode jeu).
        static let keyHold    = "key.hold"
        static let media    = "media"
        static let shortcut = "shortcut"

        // Système
        static let system   = "system"
        static let present  = "present"
        static let gesture  = "gesture"
        /// Placement de la fenêtre active du Mac.
        static let window   = "window"

        /// Surface de contrôle MIDI.
        static let midi = "midi"

        /// Note rapide envoyée de l'iPhone au Mac.
        static let note = "note"

        /// Reprise de lecture : ce qui joue sur le Mac.
        static let handoffRequest = "handoff.request"
        static let handoffData    = "handoff.data"

        // Onglets du navigateur
        static let tabsRequest = "tabs.request"
        static let tabsList    = "tabs.list"
        static let tabAction   = "tab.action"

        // Applications (requête iPhone → Mac, réponse Mac → iPhone)
        static let appsRequest      = "apps.request"
        static let appsList         = "apps.list"
        static let installedRequest = "apps.installed.request"
        static let installedList    = "apps.installed.list"
        static let appAction        = "app.action"
        static let appLaunch        = "app.launch"

        // Presse-papiers
        static let clipboardPush    = "clipboard.push"
        static let clipboardRequest = "clipboard.request"
        static let clipboardData    = "clipboard.data"
        static let clipboardHistoryRequest = "clipboard.history.request"
        static let clipboardHistory        = "clipboard.history"
        /// Remet une entrée de l'historique dans le presse-papiers du Mac.
        static let clipboardRestore        = "clipboard.restore"
        static let clipboardClearHistory   = "clipboard.history.clear"

        // Constantes système
        static let vitalsRequest = "vitals.request"
        static let vitalsData    = "vitals.data"

        // Appairage
        static let authChallenge = "auth.challenge"
        static let authResponse  = "auth.response"
        static let authPinNeeded = "auth.pinNeeded"
        static let authGranted   = "auth.granted"
        static let authDenied    = "auth.denied"

        static let authKinds: Set<String> = [
            authChallenge, authResponse, authPinNeeded, authGranted, authDenied
        ]
    }
}

// MARK: - Constructeurs

extension Message {
    static func trackpad(dx: Double, dy: Double) -> Message {
        Message(kind: "trackpad", dx: dx, dy: dy)
    }

    static func click(button: Int, down: Bool) -> Message {
        Message(kind: "click", button: button, down: down)
    }

    static func scroll(dx: Double, dy: Double, phase: ScrollPhase) -> Message {
        Message(kind: "scroll", dx: dx, dy: dy, phase: phase)
    }

    /// Pincer pour zoomer. `dx` porte le facteur d'échelle relatif
    /// (> 0 : agrandir, < 0 : réduire).
    static func zoom(magnification: Double, phase: ScrollPhase) -> Message {
        Message(kind: "zoom", dx: magnification, phase: phase)
    }

    /// Frappe d'un caractère, éventuellement combiné à des modificateurs.
    ///
    /// C'est le Mac qui décide quelle touche physique presser, d'après **sa**
    /// disposition : envoyer un keycode depuis l'iPhone transformerait ⌘A en
    /// ⌘Q sur un clavier français.
    static func character(_ character: Character, flags: Int = 0) -> Message {
        Message(kind: Kind.character, flags: flags, text: String(character))
    }

    /// Touche nommée (entrée, tabulation, flèches…), dont le keycode ne
    /// dépend pas de la disposition.
    static func specialKey(_ key: SpecialKey, flags: Int = 0) -> Message {
        Message(kind: Kind.specialKey, flags: flags, name: key.rawValue)
    }

    /// Texte libre inséré d'un bloc (champ « envoyer du texte »).
    static func text(_ text: String) -> Message {
        Message(kind: Kind.text, text: text)
    }

    static func media(_ command: String) -> Message {
        Message(kind: "media", command: command)
    }

    static func shortcut(action: String, target: String?, name: String?) -> Message {
        Message(kind: "shortcut", action: action, target: target, name: name)
    }

    // MARK: Système

    static func system(_ action: SystemAction) -> Message {
        Message(kind: Kind.system, action: action.rawValue)
    }

    static func presentation(_ action: PresentationAction) -> Message {
        Message(kind: Kind.present, action: action.rawValue)
    }

    static func gesture(_ action: GestureAction) -> Message {
        Message(kind: Kind.gesture, action: action.rawValue)
    }

    /// Placement de la fenêtre active du Mac (moitiés, quarts, tiers…).
    static func window(_ placement: String) -> Message {
        Message(kind: Kind.window, action: placement)
    }

    // MARK: Onglets du navigateur

    /// Note rapide vers le Mac : notification, et texte mis dans le
    /// presse-papiers du Mac.
    static func note(_ text: String) -> Message {
        Message(kind: Kind.note, text: text)
    }

    /// Maintient ou relâche une touche. Pour le mode jeu, où avancer suppose
    /// de garder la touche enfoncée.
    static func keyHold(_ character: Character, down: Bool) -> Message {
        Message(kind: Kind.keyHold, down: down, text: String(character))
    }

    // MARK: Reprise de lecture

    static func handoffRequest() -> Message {
        Message(kind: Kind.handoffRequest)
    }

    /// `json` vide signifie « rien à reprendre ».
    static func handoffData(json: String) -> Message {
        Message(kind: Kind.handoffData, text: json)
    }

    // MARK: MIDI

    /// Contrôleur continu : curseur, roulette, potentiomètre.
    ///
    /// Les champs numériques existants sont réutilisés plutôt que d'en
    /// ajouter trois : `Message` est une struct plate envoyée pour **tous**
    /// les messages, chaque champ nouveau pèse sur ceux qui ne s'en servent
    /// pas.
    static func midiControl(channel: Int, controller: Int, value: Int) -> Message {
        Message(kind: Kind.midi, button: channel, keycode: UInt16(controller),
                flags: value, action: "cc")
    }

    static func midiNote(channel: Int, note: Int, velocity: Int, on: Bool) -> Message {
        Message(kind: Kind.midi, button: channel, keycode: UInt16(note),
                flags: velocity, down: on, action: "note")
    }

    // MARK: Historique du presse-papiers

    static func clipboardHistoryRequest() -> Message {
        Message(kind: Kind.clipboardHistoryRequest)
    }

    static func clipboardHistory(json: String) -> Message {
        Message(kind: Kind.clipboardHistory, text: json)
    }

    static func clipboardRestore(_ text: String) -> Message {
        Message(kind: Kind.clipboardRestore, text: text)
    }

    static func clipboardClearHistory() -> Message {
        Message(kind: Kind.clipboardClearHistory)
    }

    static func tabsRequest() -> Message {
        Message(kind: Kind.tabsRequest)
    }

    static func tabsList(json: String) -> Message {
        Message(kind: Kind.tabsList, text: json)
    }

    /// `index` est l'index AppleScript, à partir de 1.
    static func tabAction(_ action: BrowserTabAction, index: Int? = nil) -> Message {
        Message(kind: Kind.tabAction,
                action: action.rawValue,
                target: index.map(String.init))
    }

    // MARK: Applications

    static func appsRequest() -> Message {
        Message(kind: Kind.appsRequest)
    }

    static func appsList(json: String) -> Message {
        Message(kind: Kind.appsList, text: json)
    }

    static func installedRequest() -> Message {
        Message(kind: Kind.installedRequest)
    }

    static func installedList(json: String) -> Message {
        Message(kind: Kind.installedList, text: json)
    }

    static func appAction(_ action: AppAction, bundleID: String) -> Message {
        Message(kind: Kind.appAction, action: action.rawValue, target: bundleID)
    }

    static func launchApp(bundleID: String) -> Message {
        Message(kind: Kind.appLaunch, target: bundleID)
    }

    // MARK: Presse-papiers

    static func clipboardPush(_ text: String) -> Message {
        Message(kind: Kind.clipboardPush, text: text)
    }

    static func clipboardRequest() -> Message {
        Message(kind: Kind.clipboardRequest)
    }

    static func clipboardData(_ text: String) -> Message {
        Message(kind: Kind.clipboardData, text: text)
    }

    // MARK: Constantes

    static func vitalsRequest() -> Message {
        Message(kind: Kind.vitalsRequest)
    }

    static func vitalsData(json: String) -> Message {
        Message(kind: Kind.vitalsData, text: json)
    }

    // MARK: Appairage

    /// Mac → iPhone : défi aléatoire à signer.
    static func authChallenge(nonce: String) -> Message {
        Message(kind: Kind.authChallenge, nonce: nonce)
    }

    /// iPhone → Mac : preuve signée, accompagnée de l'identité permanente de
    /// l'appareil. `proof` nil = « je n'ai pas de jeton, demande-moi le code ».
    static func authResponse(proof: String?, deviceID: String, name: String) -> Message {
        Message(kind: Kind.authResponse, name: name, proof: proof, deviceID: deviceID)
    }

    /// Mac → iPhone : affiche l'écran de saisie du code.
    static func authPinNeeded() -> Message {
        Message(kind: Kind.authPinNeeded)
    }

    /// Mac → iPhone : appairage accepté. `target` porte l'adresse MAC du Mac
    /// et `command` son adresse de diffusion, pour le réveil à distance.
    static func authGranted(token: String?,
                            macAddress: String? = nil,
                            broadcast: String? = nil) -> Message {
        Message(kind: Kind.authGranted, command: broadcast, target: macAddress, token: token)
    }

    /// Mac → iPhone : preuve refusée.
    static func authDenied() -> Message {
        Message(kind: Kind.authDenied)
    }
}

// MARK: - Drapeaux de modification (bitmask partagé)

enum ModFlag {
    static let command = 1 << 0
    static let option  = 1 << 1
    static let control = 1 << 2
    static let shift   = 1 << 3
}
