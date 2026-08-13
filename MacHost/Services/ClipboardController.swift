import Foundation
import AppKit

/// Presse-papiers partagé entre l'iPhone et le Mac.
final class ClipboardController {

    private let pasteboard = NSPasteboard.general

    /// Dernier compteur observé : le presse-papiers macOS n'émet aucune
    /// notification de changement, il faut comparer `changeCount`.
    private var lastChangeCount: Int

    /// Appelé quand le contenu du Mac change, pour le pousser vers l'iPhone.
    var onChange: ((String) -> Void)?

    private var timer: Timer?

    /// Historique des textes copiés sur le Mac, le plus récent en tête.
    ///
    /// En mémoire seulement, et volontairement : un presse-papiers contient
    /// régulièrement des mots de passe et des jetons. Les écrire sur disque
    /// leur donnerait une durée de vie que personne n'a demandée. L'historique
    /// disparaît donc avec l'app.
    private(set) var history: [ClipboardEntry] = []

    /// Au-delà, les entrées les plus anciennes sont oubliées.
    private let historyLimit = 30

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    deinit {
        timer?.invalidate()
    }

    /// Contenu texte actuel du presse-papiers du Mac.
    func currentText() -> String? {
        pasteboard.string(forType: .string)
    }

    /// Remplace le presse-papiers du Mac par le texte venu de l'iPhone.
    func set(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Évite de renvoyer immédiatement à l'iPhone ce qu'il vient d'envoyer.
        lastChangeCount = pasteboard.changeCount
    }

    /// Surveille le presse-papiers pour propager les copies faites sur le Mac.
    func startWatching() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let count = self.pasteboard.changeCount
            guard count != self.lastChangeCount else { return }
            self.lastChangeCount = count
            if let text = self.pasteboard.string(forType: .string), !text.isEmpty {
                self.remember(text)
                self.onChange?(text)
            }
        }
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Historique

    /// Ajoute un texte en tête, sans doublon consécutif ni répétition.
    private func remember(_ text: String) {
        // Recopier un texte déjà présent le remonte en tête plutôt que de
        // créer un doublon : c'est ce qu'on attend d'un historique.
        history.removeAll { $0.text == text }
        history.insert(ClipboardEntry(text: text), at: 0)
        if history.count > historyLimit {
            history.removeLast(history.count - historyLimit)
        }
    }

    /// Remet une entrée de l'historique dans le presse-papiers du Mac.
    ///
    /// Ne passe pas par `set(_:)` : on veut que le contenu **remonte** en tête
    /// de l'historique, alors que `set` sert aux textes venus de l'iPhone,
    /// qu'on ne réémet pas.
    func restore(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        remember(text)
    }

    func clearHistory() {
        history.removeAll()
    }
}
