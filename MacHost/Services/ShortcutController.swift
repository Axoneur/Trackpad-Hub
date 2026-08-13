import Foundation
import AppKit

/// Exécute les raccourcis demandés depuis l'iPhone :
/// - lancer une application (par bundle ID)
/// - ouvrir une URL
/// - lancer un raccourci de l'app « Raccourcis »
final class ShortcutController {

    func handle(action: String, target: String?, name: String?) {
        switch action {
        case "launch":
            if let target { launchApp(bundleID: target) }
        case "url":
            if let target, let url = URL(string: target) {
                NSWorkspace.shared.open(url)
            }
        case "shortcut":
            if let name { runShortcut(named: name) }
        default:
            break
        }
    }

    private func launchApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    private func runShortcut(named name: String) {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "shortcuts://run-shortcut?name=\(encoded)") else { return }
        NSWorkspace.shared.open(url)
    }
}
