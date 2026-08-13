import SwiftUI

/// Un raccourci personnalisé envoyé au Mac.
struct ShortcutItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var action: String // "launch" | "url" | "shortcut"
    var target: String?
    var shortcutName: String?
    var icon: String

    init(id: UUID = UUID(), name: String, action: String, target: String?, shortcutName: String?, icon: String) {
        self.id = id
        self.name = name
        self.action = action
        self.target = target
        self.shortcutName = shortcutName
        self.icon = icon
    }
}

/// Stocke les raccourcis dans UserDefaults (JSON).
@MainActor
final class ShortcutStore: ObservableObject {
    @Published private(set) var items: [ShortcutItem] {
        didSet { save() }
    }

    private let key = "shortcuts"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ShortcutItem].self, from: data) {
            items = decoded
        } else {
            // Uniquement des apps livrées avec macOS : un raccourci par défaut
            // vers une app non installée serait un bouton qui ne fait rien.
            items = [
                ShortcutItem(name: "Safari", action: "launch", target: "com.apple.Safari",
                             shortcutName: nil, icon: "safari"),
                ShortcutItem(name: "Finder", action: "launch", target: "com.apple.finder",
                             shortcutName: nil, icon: "folder"),
                ShortcutItem(name: "Terminal", action: "launch", target: "com.apple.Terminal",
                             shortcutName: nil, icon: "terminal")
            ]
        }
    }

    func add(_ item: ShortcutItem) {
        items.append(item)
    }

    func remove(_ item: ShortcutItem) {
        items.removeAll { $0.id == item.id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
