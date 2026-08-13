import UIKit
import Combine

/// Mode poche : ignorer le tactile quand l'iPhone est contre quelque chose.
///
/// Le capteur de proximité — celui qui éteint l'écran pendant un appel —
/// détecte le tissu d'une poche ou une table. Tant qu'il est couvert, plus
/// aucune action ne part vers le Mac.
///
/// Sans ça, un téléphone rangé sans verrouiller envoie des clics et des
/// mouvements aléatoires, et le curseur part tout seul à l'autre bout du
/// bureau — sans qu'on comprenne d'où ça vient.
@MainActor
final class PocketMode: ObservableObject {

    /// Vrai quand quelque chose couvre le haut de l'écran.
    @Published private(set) var isCovered = false

    /// Vrai quand la surveillance est active.
    @Published private(set) var isEnabled = false

    private var observer: NSObjectProtocol?

    var isAvailable: Bool {
        // Le capteur n'existe pas sur tous les modèles, et l'activer est le
        // seul moyen de le savoir : la propriété reste fausse s'il est absent.
        let device = UIDevice.current
        let previous = device.isProximityMonitoringEnabled
        device.isProximityMonitoringEnabled = true
        let available = device.isProximityMonitoringEnabled
        device.isProximityMonitoringEnabled = previous
        return available
    }

    func enable() {
        guard !isEnabled else { return }
        UIDevice.current.isProximityMonitoringEnabled = true
        guard UIDevice.current.isProximityMonitoringEnabled else { return }
        isEnabled = true

        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isCovered = UIDevice.current.proximityState
            }
        }
    }

    func disable() {
        guard isEnabled else { return }
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        UIDevice.current.isProximityMonitoringEnabled = false
        isEnabled = false
        isCovered = false
    }
}
