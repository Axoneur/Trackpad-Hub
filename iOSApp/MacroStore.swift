import SwiftUI
import Combine

/// Enregistrement et rejeu des macros.
///
/// L'enregistrement ne surveille pas l'interface bouton par bouton : il capte
/// `MessageConnection.onSend`, le seul point par lequel passent toutes les
/// actions envoyées au Mac. Une fonctionnalité ajoutée plus tard devient donc
/// enregistrable sans qu'on ait à y penser.
@MainActor
final class MacroStore: ObservableObject {

    @Published private(set) var macros: [Macro] = [] {
        didSet { save() }
    }

    /// Vrai pendant l'enregistrement.
    @Published private(set) var isRecording = false
    /// Étapes captées depuis le début de l'enregistrement.
    @Published private(set) var draft: [MacroStep] = []
    /// Actions vues mais écartées — déplacements, défilement, zoom.
    ///
    /// Affiché pendant l'enregistrement : sans ce compteur, quelqu'un qui ne
    /// fait que bouger le curseur voit « 0 action » sans comprendre pourquoi.
    @Published private(set) var ignoredCount = 0
    /// Macro en cours de rejeu, pour l'afficher.
    @Published private(set) var playing: UUID?

    private let key = "macros"
    private var lastStamp: Date?

    /// Drapeau lu depuis le **chemin critique**, hors acteur principal.
    ///
    /// `isRecording` est isolé sur l'acteur principal : le consulter depuis le
    /// crochet d'envoi imposerait un saut de file. Or ce crochet est appelé
    /// pour *chaque* message, déplacements du curseur compris — jusqu'à 120
    /// par seconde. Ce doublon non isolé permet de sortir immédiatement quand
    /// on n'enregistre pas, sans rien allouer.
    private nonisolated(unsafe) var captureEnabled = false
    private var replayTask: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Macro].self, from: data) {
            macros = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(macros) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Enregistrement

    /// Branche la capture sur la connexion. À appeler une fois au démarrage.
    func attach(to connection: MessageConnection) {
        connection.onSend = { [weak self] message in
            // **Le chemin critique passe ici.** Deux tests, puis on sort.
            //
            // Créer une tâche par message noyait l'acteur principal de
            // l'iPhone à 120 messages par seconde : l'app se figeait et la
            // liaison tombait. Un déplacement de curseur ne doit rien coûter
            // quand aucun enregistrement n'est en cours — c'est-à-dire
            // presque toujours.
            guard let self, self.captureEnabled else { return }
            let recordable = message.isRecordable
            Task { @MainActor in
                if recordable { self.capture(message) } else { self.ignoredCount += 1 }
            }
        }
    }

    func startRecording() {
        draft.removeAll()
        ignoredCount = 0
        lastStamp = nil
        isRecording = true
        captureEnabled = true
    }

    func stopRecording() {
        isRecording = false
        captureEnabled = false
        lastStamp = nil
    }

    func cancelRecording() {
        stopRecording()
        draft.removeAll()
    }

    private func capture(_ message: Message) {
        guard isRecording, message.isRecordable else { return }
        let now = Date()
        // Première étape sans attente : la macro démarre quand on la lance,
        // pas après le temps qu'on a mis à appuyer la première fois.
        let delay = lastStamp.map { now.timeIntervalSince($0) } ?? 0
        lastStamp = now
        draft.append(MacroStep(message: message, delay: delay))
    }

    /// Enregistre le brouillon sous un nom.
    func commit(name: String, icon: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else { return }
        macros.append(Macro(name: trimmed.isEmpty ? "Macro \(macros.count + 1)" : trimmed,
                            icon: icon,
                            steps: draft))
        draft.removeAll()
    }

    func remove(_ macro: Macro) {
        macros.removeAll { $0.id == macro.id }
    }

    func rename(_ macro: Macro, to name: String) {
        guard let index = macros.firstIndex(where: { $0.id == macro.id }) else { return }
        macros[index].name = name
    }

    // MARK: - Rejeu

    /// Rejoue une macro en respectant les pauses d'origine.
    ///
    /// L'enregistrement est suspendu pendant le rejeu : sans ça, lancer une
    /// macro pendant qu'on en enregistre une autre la recopierait dans
    /// celle-ci.
    func play(_ macro: Macro, on connection: MessageConnection) {
        replayTask?.cancel()
        let wasRecording = isRecording
        isRecording = false
        captureEnabled = false
        playing = macro.id

        replayTask = Task { @MainActor in
            for step in macro.steps {
                if Task.isCancelled { break }
                if step.delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(step.delay * 1_000_000_000))
                }
                if Task.isCancelled { break }
                connection.send(step.message)
            }
            playing = nil
            isRecording = wasRecording
            captureEnabled = wasRecording
        }
    }

    func stopPlaying() {
        replayTask?.cancel()
        replayTask = nil
        playing = nil
    }
}
