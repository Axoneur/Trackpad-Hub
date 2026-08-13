import Foundation
import AppKit
import UserNotifications

/// Réception des fichiers envoyés par l'iPhone.
///
/// Les fichiers atterrissent dans un sous-dossier de Téléchargements plutôt
/// que directement dedans : on évite de noyer les téléchargements du
/// navigateur, et on retrouve tout au même endroit.
final class FileReceiver {

    /// Dossier de destination, créé à la demande.
    static var destination: URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        let folder = downloads.appendingPathComponent("TrackPad Hub", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Déplace un fichier reçu vers sa destination définitive.
    ///
    /// MultipeerConnectivity supprime l'URL temporaire dès le retour du
    /// callback : le déplacement doit être synchrone.
    @discardableResult
    func receive(from temporaryURL: URL, named name: String) -> URL? {
        let target = Self.uniqueURL(for: name)
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: target)
        } catch {
            // Le déplacement échoue entre volumes différents : on copie.
            guard (try? FileManager.default.copyItem(at: temporaryURL, to: target)) != nil else {
                NSLog("TrackPadHub: réception de %@ impossible — %@", name, error.localizedDescription)
                return nil
            }
        }
        notify(name: name, at: target)
        return target
    }

    /// Évite d'écraser un fichier existant : « photo.jpg » devient
    /// « photo 2.jpg », puis « photo 3.jpg ».
    private static func uniqueURL(for name: String) -> URL {
        let folder = destination
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension

        var candidate = folder.appendingPathComponent(name)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            candidate = folder.appendingPathComponent(numbered)
            index += 1
        }
        return candidate
    }

    private func notify(name: String, at url: URL) {
        let content = UNMutableNotificationContent()
        content.title = "Fichier reçu"
        content.body = name
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)

        // Rebond du Dock : visible même si les notifications sont refusées.
        DispatchQueue.main.async {
            NSApp.requestUserAttention(.informationalRequest)
        }
    }

    /// Ouvre le dossier de réception dans le Finder.
    static func revealFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([destination])
    }

    /// Demande l'autorisation d'afficher des notifications, une seule fois.
    static func requestNotificationAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
