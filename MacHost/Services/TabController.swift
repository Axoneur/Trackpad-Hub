import Foundation
import AppKit

/// Onglets du navigateur au premier plan.
///
/// Passe par AppleScript : c'est la seule voie publique pour lire et piloter
/// les onglets d'un navigateur tiers. Exige donc l'autorisation
/// **Automatisation**, la même que les gestes de bureaux — mais accordée
/// séparément pour chaque application ciblée. macOS demandera à part pour
/// Safari, puis pour Chrome le cas échéant.
///
/// Firefox est absent volontairement : il n'expose pas ses onglets à
/// AppleScript, il n'y a rien à en tirer.
final class TabController {

    /// Navigateurs pilotables, avec leur dialecte AppleScript.
    ///
    /// Safari et la famille Chrome ne parlent pas la même langue : Safari dit
    /// `current tab of front window`, Chrome dit `active tab index of window 1`.
    /// D'où les deux jeux de scripts plutôt qu'un seul paramétré.
    enum Browser: String, CaseIterable {
        case safari = "com.apple.Safari"
        case chrome = "com.google.Chrome"
        case brave  = "com.brave.Browser"
        case edge   = "com.microsoft.edgemac"

        var applicationName: String {
            switch self {
            case .safari: return "Safari"
            case .chrome: return "Google Chrome"
            case .brave:  return "Brave Browser"
            case .edge:   return "Microsoft Edge"
            }
        }

        /// Vrai pour tout ce qui parle le dialecte de Chrome.
        var isChromeFamily: Bool { self != .safari }
    }

    /// Dernière erreur, affichée dans le diagnostic.
    private(set) var lastError: String?

    // MARK: - Navigateur courant

    /// Le navigateur au premier plan, sinon le premier navigateur ouvert.
    ///
    /// Retomber sur un navigateur ouvert mais en arrière-plan est voulu :
    /// quand la commande vient de l'iPhone, c'est souvent TrackPad Hub ou
    /// autre chose qui est au premier plan sur le Mac.
    private func currentBrowser() -> Browser? {
        if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           let browser = Browser(rawValue: front) {
            return browser
        }
        let running = NSWorkspace.shared.runningApplications.compactMap {
            $0.bundleIdentifier.flatMap(Browser.init(rawValue:))
        }
        return running.first
    }

    // MARK: - Lecture

    /// Sépare les champs renvoyés par AppleScript.
    ///
    /// Un titre de page contient très souvent une virgule, parfois un
    /// point-virgule : la liste séparée par des virgules que renvoie
    /// AppleScript par défaut est donc inexploitable. On impose le séparateur
    /// d'unité ASCII (0x1F), qu'aucun titre ne contient.
    private static let separator = "\u{1F}"

    func tabs(completion: @escaping ([BrowserTab]) -> Void) {
        guard let browser = currentBrowser() else {
            lastError = "Aucun navigateur pilotable n'est ouvert."
            completion([])
            return
        }

        let script = browser.isChromeFamily ? chromeListScript(browser) : safariListScript()
        run(script) { [weak self] output in
            guard let output else {
                completion([])
                return
            }
            let parts = output.components(separatedBy: Self.separator)
            guard parts.count >= 1, let current = Int(parts[0]) else {
                self?.lastError = "Réponse du navigateur illisible."
                completion([])
                return
            }
            let titles = Array(parts.dropFirst())
            let tabs = titles.enumerated().map { index, title in
                // AppleScript indexe à partir de 1 : on garde cette convention
                // de bout en bout plutôt que de convertir deux fois.
                BrowserTab(index: index + 1,
                           title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                           isCurrent: index + 1 == current)
            }
            completion(tabs)
        }
    }

    private func safariListScript() -> String {
        """
        tell application "Safari"
            if (count of windows) is 0 then return ""
            set w to front window
            set c to current tab of w
            set titles to {}
            set idx to 0
            repeat with i from 1 to count of tabs of w
                set t to tab i of w
                set end of titles to (name of t)
                if t is c then set idx to i
            end repeat
            set AppleScript's text item delimiters to (ASCII character 31)
            set out to (idx as text) & (ASCII character 31) & (titles as text)
            set AppleScript's text item delimiters to ""
            return out
        end tell
        """
    }

    private func chromeListScript(_ browser: Browser) -> String {
        """
        tell application "\(browser.applicationName)"
            if (count of windows) is 0 then return ""
            set w to window 1
            set idx to active tab index of w
            set titles to {}
            repeat with t in tabs of w
                set end of titles to (title of t)
            end repeat
            set AppleScript's text item delimiters to (ASCII character 31)
            set out to (idx as text) & (ASCII character 31) & (titles as text)
            set AppleScript's text item delimiters to ""
            return out
        end tell
        """
    }

    // MARK: - Actions

    func handle(action rawValue: String, index: Int?) {
        guard let action = BrowserTabAction(rawValue: rawValue) else { return }
        guard let browser = currentBrowser() else {
            lastError = "Aucun navigateur pilotable n'est ouvert."
            return
        }
        let script = browser.isChromeFamily
            ? chromeActionScript(action, index: index, browser: browser)
            : safariActionScript(action, index: index)
        guard let script else { return }
        run(script) { _ in }
    }

    private func safariActionScript(_ action: BrowserTabAction, index: Int?) -> String? {
        let app = "tell application \"Safari\""
        switch action {
        case .select:
            guard let index else { return nil }
            return "\(app) to set current tab of front window to tab \(index) of front window"
        case .close:
            guard let index else { return nil }
            return "\(app) to close tab \(index) of front window"
        case .new:
            // `activate` d'abord : un onglet neuf créé dans une fenêtre en
            // arrière-plan passerait inaperçu.
            return """
            tell application "Safari"
                activate
                if (count of windows) is 0 then
                    make new document
                else
                    tell front window to set current tab to (make new tab at end of tabs)
                end if
            end tell
            """
        case .closeCurrent:
            return "\(app) to close current tab of front window"
        case .next:
            return cycleScript(offset: 1, safari: true)
        case .previous:
            return cycleScript(offset: -1, safari: true)
        case .reopen:
            // Pas d'équivalent AppleScript : on rejoue ⇧⌘T, que Safari et
            // Chrome comprennent tous les deux.
            return """
            tell application "Safari" to activate
            tell application "System Events" to keystroke "t" using {command down, shift down}
            """
        }
    }

    private func chromeActionScript(_ action: BrowserTabAction, index: Int?, browser: Browser) -> String? {
        let name = browser.applicationName
        let app = "tell application \"\(name)\""
        switch action {
        case .select:
            guard let index else { return nil }
            return "\(app) to set active tab index of window 1 to \(index)"
        case .close:
            guard let index else { return nil }
            return "\(app) to close tab \(index) of window 1"
        case .new:
            return """
            tell application "\(name)"
                activate
                if (count of windows) is 0 then
                    make new window
                else
                    tell window 1 to make new tab
                end if
            end tell
            """
        case .closeCurrent:
            return "\(app) to close active tab of window 1"
        case .next:
            return cycleScript(offset: 1, safari: false, name: name)
        case .previous:
            return cycleScript(offset: -1, safari: false, name: name)
        case .reopen:
            return """
            tell application "\(name)" to activate
            tell application "System Events" to keystroke "t" using {command down, shift down}
            """
        }
    }

    /// Onglet suivant ou précédent, en bouclant aux extrémités.
    ///
    /// Calculé dans le script plutôt que côté Swift : sans ça il faudrait un
    /// aller-retour pour lire l'index courant, et l'utilisateur qui enchaîne
    /// les appuis verrait ses commandes se marcher dessus.
    private func cycleScript(offset: Int, safari: Bool, name: String = "Safari") -> String {
        if safari {
            return """
            tell application "Safari"
                set w to front window
                set n to count of tabs of w
                if n is 0 then return
                set c to current tab of w
                set idx to 1
                repeat with i from 1 to n
                    if (tab i of w) is c then set idx to i
                end repeat
                set target to ((idx + \(offset) + n - 1) mod n) + 1
                set current tab of w to tab target of w
            end tell
            """
        }
        return """
        tell application "\(name)"
            set w to window 1
            set n to count of tabs of w
            if n is 0 then return
            set idx to active tab index of w
            set target to ((idx + \(offset) + n - 1) mod n) + 1
            set active tab index of w to target
        end tell
        """
    }

    // MARK: - Exécution

    /// `NSAppleScript` **exige la file principale** : lancé ailleurs il échoue
    /// sans erreur et sans jamais déclencher la demande d'autorisation. Même
    /// piège que `SystemController`.
    private func run(_ source: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                self?.lastError = "Script invalide."
                completion(nil)
                return
            }
            let result = script.executeAndReturnError(&error)

            if let error {
                let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                if code == -1743 {
                    self?.lastError = "Autorisation « Automatisation » refusée pour le navigateur. Réglages Système → Confidentialité et sécurité → Automatisation → TrackPad Hub."
                } else {
                    self?.lastError = error[NSAppleScript.errorMessage] as? String ?? "erreur \(code)"
                }
                completion(nil)
                return
            }

            self?.lastError = nil
            completion(result.stringValue)
        }
    }
}
