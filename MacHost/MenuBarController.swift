import AppKit
import SwiftUI
import Combine
import ServiceManagement

/// Icône de la barre des menus.
///
/// C'est le mode d'usage naturel de l'app : elle n'a aucune raison d'occuper
/// une fenêtre ni une place dans le Dock une fois l'appairage fait. L'icône
/// indique d'un coup d'œil si un iPhone est connecté.
@MainActor
final class MenuBarController: NSObject, ObservableObject {

    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    private weak var connection: MessageConnection?
    private weak var router: Router?

    /// Ouvre la fenêtre principale, branché par l'app.
    var onShowWindow: (() -> Void)?
    /// Ouvre la fenêtre de diagnostic.
    var onShowDiagnostics: (() -> Void)?

    func attach(connection: MessageConnection, router: Router) {
        self.connection = connection
        self.router = router

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = Self.icon(connected: false)
        item.button?.image?.isTemplate = true
        item.menu = buildMenu()
        statusItem = item

        // L'icône reflète l'état en direct.
        connection.$pairingState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.statusItem?.button?.image = Self.icon(connected: state == .paired)
                self?.statusItem?.button?.image?.isTemplate = true
                self?.statusItem?.menu = self?.buildMenu()
            }
            .store(in: &cancellables)
    }

    // MARK: - Icône

    /// Dessinée par le code plutôt que chargée depuis un fichier : une image
    /// modèle doit être monochrome pour suivre le thème de la barre des menus,
    /// et s'adapter automatiquement au mode sombre.
    private static func icon(connected: Bool) -> NSImage {
        let size = NSSize(width: 17, height: 17)
        let image = NSImage(size: size, flipped: false) { rect in
            let body = NSBezierPath(roundedRect: NSRect(x: 4.5, y: 1.5, width: 8, height: 14),
                                    xRadius: 4, yRadius: 4)
            body.lineWidth = 1.4
            NSColor.black.setStroke()
            body.stroke()

            // Point plein quand un iPhone est appairé : lisible même en 17 px.
            if connected {
                let dot = NSBezierPath(ovalIn: NSRect(x: 7, y: 9.5, width: 3, height: 3))
                NSColor.black.setFill()
                dot.fill()
            } else {
                let seam = NSBezierPath()
                seam.move(to: NSPoint(x: 6.5, y: 11))
                seam.line(to: NSPoint(x: 10.5, y: 11))
                seam.lineWidth = 1
                NSColor.black.setStroke()
                seam.stroke()
            }
            _ = rect
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let paired = connection?.pairingState == .paired
        let title = paired
            ? "Connecté — \(connection?.connectedPeers.first?.displayName ?? "iPhone")"
            : "En attente d'un iPhone…"
        let status = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if let pin = connection?.displayedPin {
            let code = NSMenuItem(title: "Code d'appairage : \(pin)", action: nil, keyEquivalent: "")
            code.isEnabled = false
            menu.addItem(code)
        }

        menu.addItem(.separator())

        menu.addItem(withTitle: "Ouvrir TrackPad Hub…",
                     action: #selector(showWindow), keyEquivalent: "")
            .target = self

        menu.addItem(withTitle: "Diagnostic du clavier…",
                     action: #selector(showDiagnostics), keyEquivalent: "")
            .target = self

        let devices = connection?.pairedDevices ?? []
        if !devices.isEmpty {
            let submenu = NSMenu()
            for entry in devices {
                let item = NSMenuItem(title: "Oublier « \(entry.device.name) »",
                                      action: #selector(forgetDevice(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = entry.id
                submenu.addItem(item)
            }
            let parent = NSMenuItem(title: "Appareils autorisés", action: nil, keyEquivalent: "")
            menu.addItem(parent)
            menu.setSubmenu(submenu, for: parent)
        }

        menu.addItem(.separator())

        let launch = NSMenuItem(title: "Lancer au démarrage",
                                action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = Self.launchesAtLogin ? .on : .off
        menu.addItem(launch)

        menu.addItem(withTitle: "Relancer la connexion",
                     action: #selector(restartConnection), keyEquivalent: "")
            .target = self

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quitter TrackPad Hub",
                     action: #selector(quit), keyEquivalent: "q")
            .target = self

        return menu
    }

    // MARK: - Actions

    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Si une fenêtre existe encore, la remonter suffit. Sinon on demande
        // à SwiftUI d'en recréer une : sans ça, fermer la fenêtre rendait
        // l'app définitivement inaccessible.
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && $0.contentView != nil }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            onShowWindow?()
        }
    }

    @objc private func showDiagnostics() {
        NSApp.activate(ignoringOtherApps: true)
        onShowDiagnostics?()
    }

    @objc private func forgetDevice(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        connection?.forgetDevice(id: id)
        statusItem?.menu = buildMenu()
    }

    @objc private func restartConnection() {
        connection?.restart()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Lancement au démarrage

    static var launchesAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if Self.launchesAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("TrackPadHub: lancement au démarrage — %@", error.localizedDescription)
        }
        statusItem?.menu = buildMenu()
    }
}

/// `addItem(withTitle:action:keyEquivalent:)` renvoie l'élément créé, mais
/// AppKit ne le déclare pas comme tel — cette surcharge évite d'écrire
/// trois lignes à chaque entrée de menu.
private extension NSMenu {
    @discardableResult
    func addItem(withTitle title: String, action: Selector?, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        addItem(item)
        return item
    }
}
