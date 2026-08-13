import Foundation
import AppKit
import UserNotifications

/// Notes rapides envoyées de l'iPhone vers le Mac.
///
/// Remplace le « chat intégré » demandé, qui supposait un serveur et des
/// comptes. Ici il n'y a rien à héberger : la liaison entre l'iPhone et le
/// Mac existe déjà, une note l'emprunte comme n'importe quel message.
///
/// Ce n'est donc pas une messagerie entre utilisateurs, mais le cas d'usage
/// réel derrière la demande — s'envoyer à soi-même une adresse, un code, une
/// idée, sans changer d'appareil.
final class NoteController {

    /// Une note reçue.
    struct Note: Identifiable {
        let id = UUID()
        let date = Date()
        let text: String
    }

    /// Les dernières notes, la plus récente en tête. En mémoire seulement :
    /// une note contient souvent ce qu'on ne veut pas laisser sur un disque.
    private(set) var notes: [Note] = []
    private let limit = 50

    /// Appelé à chaque note reçue, pour rafraîchir l'interface du Mac.
    var onChange: (() -> Void)?

    func receive(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.notes.insert(Note(text: trimmed), at: 0)
            if self.notes.count > self.limit {
                self.notes.removeLast(self.notes.count - self.limit)
            }
            self.onChange?()
            self.notify(trimmed)
        }
    }

    func clear() {
        notes.removeAll()
        onChange?()
    }

    /// Notification système, avec le texte déjà dans le presse-papiers.
    ///
    /// Mettre la note dans le presse-papiers tout de suite est le geste utile :
    /// on envoie presque toujours une note pour la coller quelque part.
    private func notify(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let content = UNMutableNotificationContent()
        content.title = "Note de l'iPhone"
        content.body = text.count > 200 ? String(text.prefix(200)) + "…" : text
        content.subtitle = "Copiée dans le presse-papiers"
        content.sound = .default

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))

        // Rebond du Dock : visible même si les notifications sont refusées.
        NSApp.requestUserAttention(.informationalRequest)
    }
}
