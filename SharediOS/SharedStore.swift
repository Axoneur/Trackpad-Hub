import Foundation

/// Données partagées entre l'app, le clavier système et les widgets.
///
/// Les widgets tournent dans un processus séparé et n'ont aucun accès au
/// réseau local : ils affichent le dernier état transmis par l'app.
///
/// Le transport passe par le **trousseau** et non par un App Group : les App
/// Groups exigent une adhésion Apple payante, alors que le partage de
/// trousseau est plus largement disponible. Si le partage est refusé, chaque
/// processus lit et écrit dans son propre espace — les widgets affichent
/// alors « Ouvrez l'app », sans que rien ne casse.
enum SharedStore {

    private enum Key {
        static let vitals = "shared.vitals"
        static let vitalsDate = "shared.vitalsDate"
        static let hostName = "shared.hostName"
        static let isPaired = "shared.isPaired"
        static let pendingAction = "shared.pendingAction"
    }

    /// Ce qui est écrit dans le trousseau pour les widgets.
    private struct Snapshot: Codable {
        var vitals: MacVitals
        var date: Date
    }

    // MARK: - Constantes du Mac

    static func save(vitals: MacVitals) {
        KeychainBox.encode(Snapshot(vitals: vitals, date: Date()), for: Key.vitals)
        KeychainBox.set(vitals.hostName, for: Key.hostName)
    }

    static func loadVitals() -> (vitals: MacVitals, date: Date)? {
        guard let snapshot = KeychainBox.decode(Snapshot.self, Key.vitals) else { return nil }
        return (snapshot.vitals, snapshot.date)
    }

    static var hostName: String {
        KeychainBox.string(Key.hostName) ?? "Mac"
    }

    // MARK: - État de connexion

    static var isPaired: Bool {
        get { KeychainBox.string(Key.isPaired) == "1" }
        set { KeychainBox.set(newValue ? "1" : "0", for: Key.isPaired) }
    }

    // MARK: - Action en attente

    /// Une intention lancée depuis un widget ou Siri dépose ici l'action ;
    /// l'app l'exécute dès qu'elle est appairée.
    static func store(pending message: Message) {
        KeychainBox.encode(message, for: Key.pendingAction)
    }

    static func takePending() -> Message? {
        let message = KeychainBox.decode(Message.self, Key.pendingAction)
        KeychainBox.remove(Key.pendingAction)
        return message
    }
}
