import Foundation

/// Une entrée de l'historique du presse-papiers du Mac.
struct ClipboardEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let text: String

    init(text: String, date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.text = text
    }

    /// Aperçu court, pour la liste sur l'iPhone.
    ///
    /// Les retours à la ligne sont remplacés : un extrait de code copié
    /// occuperait sinon dix lignes dans une liste qui en prévoit une.
    var preview: String {
        let flat = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flat.count > 120 ? String(flat.prefix(120)) + "…" : flat
    }
}
