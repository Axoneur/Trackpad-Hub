import Foundation
import AppKit
import Darwin

/// Lanceur, sélecteur et gestionnaire d'applications, façon Dock macOS.
final class AppController {

    /// Taille des icônes transmises : au-delà, chaque rafraîchissement
    /// enverrait plusieurs mégaoctets sur le réseau local.
    private let iconSize = NSSize(width: 64, height: 64)

    /// Cache des icônes encodées : le ré-encodage PNG à chaque rafraîchissement
    /// serait le poste de coût principal.
    private var iconCache: [String: String] = [:]

    /// Apps gelées par nos soins. macOS n'expose pas cet état : si on ne le
    /// mémorise pas, impossible de proposer « Reprendre ».
    private var suspended: Set<String> = []

    /// Cache de la liste des apps installées : parcourir /Applications à
    /// chaque requête serait inutilement coûteux.
    private var installedCache: [InstalledApp] = []
    private var installedCacheDate: Date?

    // MARK: - Apps ouvertes

    /// Applications visibles dans le Dock, l'app active en premier.
    func runningApps() -> [RunningApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return RunningApp(bundleID: bundleID,
                                  name: app.localizedName ?? bundleID,
                                  iconBase64: encodedIcon(app.icon, for: bundleID),
                                  isActive: app.isActive,
                                  isHidden: app.isHidden,
                                  isSuspended: suspended.contains(bundleID))
            }
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive { return lhs.isActive }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    // MARK: - Apps installées

    /// Toutes les apps des dossiers Applications, pour pouvoir en lancer une
    /// qui n'est pas encore ouverte.
    func installedApps() -> [InstalledApp] {
        if let date = installedCacheDate, Date().timeIntervalSince(date) < 60, !installedCache.isEmpty {
            return refreshRunningFlags(on: installedCache)
        }

        let home = NSHomeDirectory()
        let roots = ["/Applications",
                     "/System/Applications",
                     "\(home)/Applications",
                     // Emplacements courants d'apps installées hors Finder.
                     "/Applications/Setapp",
                     "/usr/local/Caskroom",
                     "\(home)/Library/Application Support/JetBrains/Toolbox/apps"]

        var seen = Set<String>()
        var results: [InstalledApp] = []

        for root in roots {
            for entry in bundles(under: URL(fileURLWithPath: root), depth: 3) {
                guard let bundle = Bundle(url: entry),
                      let bundleID = bundle.bundleIdentifier,
                      !seen.contains(bundleID) else { continue }
                seen.insert(bundleID)

                let name = FileManager.default.displayName(atPath: entry.path)
                    .replacingOccurrences(of: ".app", with: "")
                let icon = NSWorkspace.shared.icon(forFile: entry.path)

                results.append(InstalledApp(bundleID: bundleID,
                                            name: name,
                                            iconBase64: encodedIcon(icon, for: bundleID),
                                            isRunning: false))
            }
        }

        // Complément par LaunchServices : le balayage de dossiers rate des
        // apps pourtant bien installées (Finder vit dans CoreServices, et
        // certains bundles système ne se lisent pas depuis un simple parcours).
        // LaunchServices, lui, fait autorité — c'est la base que macOS utilise
        // pour ouvrir les apps.
        for entry in AppCatalog.entries where !seen.contains(entry.bundleID) {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleID) else { continue }
            seen.insert(entry.bundleID)

            let name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            let icon = NSWorkspace.shared.icon(forFile: url.path)

            results.append(InstalledApp(bundleID: entry.bundleID,
                                        name: name.isEmpty ? entry.name : name,
                                        iconBase64: encodedIcon(icon, for: entry.bundleID),
                                        isRunning: false))
        }

        installedCache = results.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        installedCacheDate = Date()
        return refreshRunningFlags(on: installedCache)
    }

    /// Bundles `.app` trouvés sous un dossier, en descendant de quelques
    /// niveaux.
    ///
    /// Un balayage à plat rate tout ce qui vit dans un sous-dossier —
    /// Adobe, Microsoft Office, les utilitaires rangés par famille. On
    /// s'arrête à `depth` pour ne pas parcourir l'intérieur des bundles,
    /// qui contiennent eux-mêmes des `.app` d'aide.
    private func bundles(under url: URL, depth: Int) -> [URL] {
        guard depth > 0,
              let entries = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }

        var found: [URL] = []
        for entry in entries {
            if entry.pathExtension == "app" {
                found.append(entry)
                continue
            }
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                found.append(contentsOf: bundles(under: entry, depth: depth - 1))
            }
        }
        return found
    }

    private func refreshRunningFlags(on apps: [InstalledApp]) -> [InstalledApp] {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return apps.map { app in
            var copy = app
            copy.isRunning = running.contains(app.bundleID)
            return copy
        }
    }

    // MARK: - Actions

    func perform(_ action: AppAction, on bundleID: String) {
        let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)

        switch action {
        case .activate:
            guard let app = instances.first else {
                launch(bundleID: bundleID)
                return
            }
            // Une app gelée ne peut pas redessiner ses fenêtres : on la
            // réveille avant de la mettre au premier plan.
            if suspended.contains(bundleID) { resume(instances, bundleID: bundleID) }
            if app.isHidden { app.unhide() }
            app.activate(options: [.activateAllWindows])

            // `activate` ne suffit pas toujours : une app sans fenêtre
            // ouverte, ou masquée depuis longtemps, reste en arrière-plan.
            // Rouvrir son bundle demande en plus à l'app de créer une
            // fenêtre, ce qui correspond à ce qu'attend l'utilisateur quand
            // il touche une vignette.
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            }

        case .hide:
            instances.forEach { $0.hide() }

        case .unhide:
            instances.forEach { $0.unhide() }

        case .suspend:
            signal(instances, SIGSTOP)
            suspended.insert(bundleID)

        case .resume:
            resume(instances, bundleID: bundleID)

        case .quit:
            // Une app gelée n'a aucun moyen de traiter la demande de fermeture.
            if suspended.contains(bundleID) { resume(instances, bundleID: bundleID) }
            instances.forEach { $0.terminate() }

        case .forceQuit:
            if suspended.contains(bundleID) { resume(instances, bundleID: bundleID) }
            instances.forEach { $0.forceTerminate() }
        }
    }

    func launch(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func resume(_ instances: [NSRunningApplication], bundleID: String) {
        signal(instances, SIGCONT)
        suspended.remove(bundleID)
    }

    private func signal(_ instances: [NSRunningApplication], _ code: Int32) {
        for app in instances where app.processIdentifier > 0 {
            kill(app.processIdentifier, code)
        }
    }

    // MARK: - Icônes

    private func encodedIcon(_ icon: NSImage?, for bundleID: String) -> String? {
        if let cached = iconCache[bundleID] { return cached }
        guard let icon else { return nil }

        let resized = NSImage(size: iconSize)
        resized.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: iconSize),
                  from: .zero,
                  operation: .sourceOver,
                  fraction: 1)
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }

        let encoded = png.base64EncodedString()
        iconCache[bundleID] = encoded
        return encoded
    }
}
