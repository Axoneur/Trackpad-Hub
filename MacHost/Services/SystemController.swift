import Foundation
import AppKit
import CoreGraphics

/// Actions système : veille, verrouillage, alimentation, navigation macOS.
///
/// Les actions d'alimentation passent par System Events (AppleScript) : c'est
/// la seule voie qui ne demande pas les droits root. macOS demandera une fois
/// l'autorisation « Automatisation » — voir NSAppleEventsUsageDescription.
final class SystemController: ObservableObject {

    private let keyboard: KeyboardController

    init(keyboard: KeyboardController) {
        self.keyboard = keyboard
    }

    func handle(action rawValue: String) {
        guard let action = SystemAction(rawValue: rawValue) else { return }

        switch action {
        case .sleep:
            // `pmset sleepnow` n'exige aucune autorisation. S'il échoue —
            // droits insuffisants selon la configuration du Mac — on retombe
            // sur System Events, qui réclame le droit « Automatisation ».
            if !shell("/usr/bin/pmset", "sleepnow") {
                systemEvents("sleep")
            }
        case .restart:
            systemEvents("restart")
        case .shutdown:
            systemEvents("shut down")
        case .logout:
            systemEvents("log out")

        case .lock:
            // ⌃⌘Q. On passe par le **caractère** « q » : un keycode en dur
            // désignerait une position physique, qui produit « a » en AZERTY —
            // le verrouillage enverrait alors ⌃⌘A.
            keyboard.send(character: "q", flags: ModFlag.command | ModFlag.control)

        case .displaySleep:
            shell("/usr/bin/pmset", "displaysleepnow")

        case .screensaver:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))

        case .missionControl:
            // Même voie que le geste : ouvrir l'app, sans autorisation.
            launchBundle("com.apple.exposelauncher")

        case .launchpad:
            // Launchpad a bien été retiré de macOS 26. Le remplaçant utile est
            // le passage d'une fenêtre à l'autre dans l'app active, ⌘`.
            keyboard.send(character: "`", flags: ModFlag.command)

        case .showDesktop:
            // F11 déclenche « Bureau » dans la configuration par défaut.
            keyboard.tap(keycode: SpecialKey.f11.keycode, flags: 0)

        case .spotlight:
            // ⌘Espace : passe par la touche physique de l'espace, donc valable
            // quelle que soit la disposition.
            keyboard.tap(keycode: SpecialKey.space.keycode, flags: ModFlag.command)

        case .focusToggle:
            runShortcut(named: Self.focusShortcutName,
                        fallbackPane: nil,
                        hint: """
                            Créez un raccourci nommé « \(Self.focusShortcutName) » dans \
                            l'app Raccourcis, avec l'action « Régler le mode de \
                            concentration ». macOS ne permet pas de changer de mode \
                            de concentration autrement.
                            """)

        case .liveCaptions:
            runShortcut(named: Self.captionsShortcutName,
                        fallbackPane: "x-apple.systempreferences:com.apple.preference.universalaccess",
                        hint: """
                            Réglages ouverts sur l'Accessibilité : activez « Sous-titres \
                            en direct ». Pour un vrai interrupteur depuis l'iPhone, créez \
                            un raccourci nommé « \(Self.captionsShortcutName) ».
                            """)
        }
    }

    /// Noms exacts des raccourcis attendus dans l'app Raccourcis.
    static let focusShortcutName = "TrackPad Hub Focus"
    static let captionsShortcutName = "TrackPad Hub Sous-titres"

    /// Lance un raccourci de l'app Raccourcis, avec repli.
    ///
    /// **Pourquoi ce détour.** Ni les modes de concentration ni les
    /// sous-titres en direct n'ont d'API publique : pas d'AppleScript, pas de
    /// domaine `defaults` — vérifié, `com.apple.LiveTranscriptionAgent`
    /// n'existe même pas. `shortcuts run` est la seule voie supportée, et
    /// elle suppose un raccourci créé par l'utilisateur.
    ///
    /// Quand il manque, on ne reste pas muet : on ouvre le volet des Réglages
    /// concerné s'il y en a un, et on explique quoi créer.
    private func runShortcut(named name: String, fallbackPane: String?, hint: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                report(nil)
                return
            }
        } catch {
            report("L'app Raccourcis est introuvable sur ce Mac.")
            return
        }

        if let pane = fallbackPane, let url = URL(string: pane) {
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
        }
        report(hint)
    }

    // MARK: - Gestes système

    /// Traduit un geste de l'iPhone en raccourci macOS.
    ///
    /// Les raccourcis utilisés sont ceux que macOS associe par défaut à ces
    /// gestes : ⌃↑ pour Mission Control, ⌃← et ⌃→ pour changer de bureau.
    /// Si l'utilisateur les a modifiés dans les Réglages Système, il faut
    /// aligner les siens.
    func handle(gesture rawValue: String) {
        guard let action = GestureAction(rawValue: rawValue) else {
            Trace.problem("geste inconnu « \(rawValue) »")
            return
        }
        Trace.action("geste \(rawValue)")

        switch action {
        // Mission Control est une vraie app, dans /System/Applications —
        // et non dans /System/Library/CoreServices où je l'avais cherchée en
        // vain. L'ouvrir ne demande **aucune autorisation**, contrairement au
        // raccourci clavier que le WindowServer ignore quand il vient d'une
        // app tierce.
        case .missionControl:
            launchBundle("com.apple.exposelauncher")
        // Ces trois-là exigent System Events, et c'est vérifié : le Mac a
        // bien posté ⌃← et ⌃→ en CGEvent, avec six bureaux configurés et les
        // raccourcis actifs — sans que rien ne se produise. Le WindowServer
        // filtre donc ces raccourcis-là quand ils viennent d'une app tierce,
        // alors qu'il laisse passer ⌘Espace. Seul un processus de confiance
        // peut les déclencher.
        case .appExpose:
            systemEventsKey(125, modifiers: ["control down"])
        case .spaceLeft:
            systemEventsKey(123, modifiers: ["control down"])
        case .spaceRight:
            systemEventsKey(124, modifiers: ["control down"])
        case .showDesktop:
            systemEventsKey(103, modifiers: [])
        case .spotlight:
            keyboard.tap(keycode: SpecialKey.space.keycode, flags: ModFlag.command)
        case .lookUp:
            // ⌃⌘D : dictionnaire et aperçu du mot sous le curseur, ce que
            // produit un clic fort sur un Mac.
            //
            // Le vrai clic fort, lui, n'est pas synthétisable : il naît dans
            // le pilote du trackpad, et AppKit refuse même de fabriquer
            // l'événement de pression. Ce qui manquait pour déplacer et
            // redimensionner n'était d'ailleurs pas la pression mais le
            // **maintien** du bouton — voir le bouton « Maintenir le clic ».
            keyboard.send(character: "d", flags: ModFlag.control | ModFlag.command)

        // macOS ne permet pas de fabriquer un événement de rotation ni de
        // zoom intelligent : on envoie les raccourcis que les apps concernées
        // associent aux mêmes actions. Aperçu, Photos et le Finder répondent
        // à ⌘L et ⌘R ; ⌘0 revient à la taille réelle un peu partout.
        case .rotateLeft:
            keyboard.send(character: "l", flags: ModFlag.command)
        case .rotateRight:
            keyboard.send(character: "r", flags: ModFlag.command)
        case .zoomReset:
            keyboard.send(character: "0", flags: ModFlag.command)
        }
    }

    // MARK: - Présentation

    /// Les raccourcis de présentation sont communs à Keynote, PowerPoint,
    /// Google Slides et Aperçu : flèches pour naviguer, B/W pour masquer.
    func handle(presentation rawValue: String) {
        guard let action = PresentationAction(rawValue: rawValue) else { return }

        switch action {
        case .next:
            keyboard.send(special: .right, flags: 0)
        case .previous:
            keyboard.send(special: .left, flags: 0)
        case .start:
            // ⌥⌘P (Keynote) ; F5 sur PowerPoint — on envoie les deux.
            keyboard.send(character: "p", flags: ModFlag.command | ModFlag.option)
        case .end:
            keyboard.send(special: .escape, flags: 0)
        case .blackScreen:
            keyboard.send(character: "b", flags: 0)
        case .whiteScreen:
            keyboard.send(character: "w", flags: 0)
        }
    }

    // MARK: - Exécution

    private func systemEvents(_ command: String) {
        runAppleScript("tell application \"System Events\" to \(command)")
    }

    /// Envoie une touche via System Events plutôt que par CGEvent.
    ///
    /// System Events poste depuis un processus reconnu par le système, ce qui
    /// lui permet de déclencher les raccourcis que le WindowServer refuse
    /// d'un événement synthétique venu d'une app tierce.
    ///
    /// Demande l'autorisation « Automatisation » à la première utilisation.
    private func systemEventsKey(_ keycode: Int, modifiers: [String]) {
        let using = modifiers.isEmpty
            ? ""
            : " using {\(modifiers.joined(separator: ", "))}"
        runAppleScript("tell application \"System Events\" to key code \(keycode)\(using)",
                       label: "touche \(keycode)\(using)")
    }

    /// Ouvre une app système par son identifiant, sans autorisation.
    private func launchBundle(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            NSLog("TrackPadHub: %@ introuvable", bundleID)
            report("« \(bundleID) » introuvable sur ce Mac.")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, error in
            if let error {
                self?.report("Ouverture refusée : \(error.localizedDescription)")
            } else {
                self?.report(nil)
            }
        }
    }

    private func launchCoreService(_ name: String) {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/\(name).app")
        guard FileManager.default.fileExists(atPath: url.path) else {
            NSLog("TrackPadHub: %@ introuvable", name)
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func runAppleScript(_ source: String, label: String? = nil) {
        // **Sur la file principale**, obligatoirement.
        //
        // `NSAppleScript` s'appuie sur le gestionnaire d'événements Apple, qui
        // exige une boucle d'exécution principale. Exécuté sur une file
        // d'arrière-plan, il échoue sans erreur ni demande d'autorisation :
        // c'est exactement le symptôme observé — aucun effet, aucun message,
        // et l'app qui n'apparaît jamais dans les Réglages Système.
        DispatchQueue.main.async { [weak self] in
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                self?.report("Script invalide.")
                return
            }
            script.executeAndReturnError(&error)

            guard let error else {
                self?.report(nil)
                return
            }

            // Le code −1743 est le refus d'automatisation : le message brut
            // d'AppleScript n'aide personne, on le traduit.
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            let message: String
            if code == -1743 {
                message = "Autorisation « Automatisation » refusée. Réglages Système → Confidentialité et sécurité → Automatisation → TrackPad Hub → cochez System Events."
            } else {
                let raw = error[NSAppleScript.errorMessage] as? String ?? "erreur \(code)"
                message = "\(label ?? "AppleScript") : \(raw)"
            }
            NSLog("TrackPadHub: %@", message)
            self?.report(message)
        }
    }

    /// Dernière erreur d'automatisation, affichée dans le diagnostic.
    @Published private(set) var lastAutomationError: String?

    /// Provoque la demande d'autorisation « Automatisation ».
    ///
    /// Comme pour l'Accessibilité, l'app n'apparaît dans la liste des
    /// Réglages Système qu'après avoir tenté un premier événement Apple.
    /// Cette commande est sans effet visible : elle ne sert qu'à déclencher
    /// la demande.
    func requestAutomationAccess() {
        runAppleScript("tell application \"System Events\" to get name",
                       label: "demande d'autorisation")
    }

    private func report(_ message: String?) {
        if Thread.isMainThread {
            lastAutomationError = message
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.lastAutomationError = message
            }
        }
    }

    /// Lance une commande et attend son verdict.
    ///
    /// Sans l'attente, `run()` réussit dès que le processus démarre : une
    /// commande refusée pour cause de droits insuffisants passait pour un
    /// succès, et le repli n'était jamais tenté.
    @discardableResult
    private func shell(_ launchPath: String, _ arguments: String...) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                NSLog("TrackPadHub: %@ a renvoyé %d", launchPath, process.terminationStatus)
                return false
            }
            return true
        } catch {
            NSLog("TrackPadHub: échec de %@ : %@", launchPath, error.localizedDescription)
            return false
        }
    }
}

