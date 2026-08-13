import SwiftUI
import os

/// Statistiques d'utilisation, tenues localement sur l'iPhone.
///
/// ## Le point délicat : le chemin critique
///
/// Compter passe par `MessageConnection.onSend`, appelé pour **chaque**
/// message — déplacements du curseur compris, jusqu'à 120 par seconde. Une
/// tâche créée à chaque appel avait déjà noyé l'acteur principal et fait
/// tomber la liaison une fois : ici on n'incrémente que des entiers sous un
/// verrou non bloquant, sans allocation.
///
/// L'agrégat n'est publié qu'à la demande, quand l'écran s'ouvre.
@MainActor
final class UsageStats: ObservableObject {

    /// Ce qu'on compte, par famille d'action.
    struct Snapshot: Codable, Equatable {
        var pointer = 0
        var clicks = 0
        var scrolls = 0
        var keys = 0
        var gestures = 0
        var media = 0
        var windows = 0
        var other = 0
        /// Secondes passées connecté au Mac.
        var connectedSeconds = 0

        var total: Int {
            pointer + clicks + scrolls + keys + gestures + media + windows + other
        }
    }

    @Published private(set) var snapshot = Snapshot()

    private let key = "usageStats"
    /// Verrou léger : pris et relâché des millions de fois, il ne doit rien
    /// allouer.
    private let lock = OSAllocatedUnfairLock(initialState: Snapshot())
    private var flushTimer: Timer?
    private var connectedSince: Date?

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = decoded
            lock.withLock { $0 = decoded }
        }
    }

    /// Branche le comptage sur la connexion.
    func attach(to connection: MessageConnection) {
        let existing = connection.onSend
        connection.onSend = { [weak self] message in
            // La chaîne existante d'abord : les macros comptent aussi sur ce
            // crochet, et le dernier branché ne doit pas effacer le premier.
            existing?(message)
            self?.count(message)
        }
    }

    /// Incrémente le bon compteur. **Aucune allocation, aucun saut de file.**
    private nonisolated func count(_ message: Message) {
        lock.withLock { state in
            switch message.kind {
            case Message.Kind.trackpad:   state.pointer += 1
            case Message.Kind.click:      state.clicks += 1
            case Message.Kind.scroll,
                 Message.Kind.zoom:       state.scrolls += 1
            case Message.Kind.character,
                 Message.Kind.specialKey,
                 Message.Kind.text,
                 Message.Kind.keyHold:    state.keys += 1
            case Message.Kind.gesture:    state.gestures += 1
            case Message.Kind.media:      state.media += 1
            case Message.Kind.window:     state.windows += 1
            default:
                // Les messages d'appairage ne sont pas de l'usage.
                if message.isControlMessage { state.other += 1 }
            }
        }
    }

    // MARK: - Temps de connexion

    func markConnected() {
        guard connectedSince == nil else { return }
        connectedSince = Date()
    }

    func markDisconnected() {
        guard let since = connectedSince else { return }
        let elapsed = Int(Date().timeIntervalSince(since))
        connectedSince = nil
        lock.withLock { $0.connectedSeconds += max(0, elapsed) }
    }

    // MARK: - Publication

    /// Recopie les compteurs vers l'interface et les enregistre.
    func publish() {
        var current = lock.withLock { $0 }
        if let since = connectedSince {
            current.connectedSeconds += Int(Date().timeIntervalSince(since))
        }
        snapshot = current
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func reset() {
        lock.withLock { $0 = Snapshot() }
        connectedSince = Date()
        snapshot = Snapshot()
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Durée lisible, « 3 h 12 ».
    static func duration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours) h \(minutes)" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(seconds) s"
    }
}
