import Foundation
import CoreMotion

/// Défilement par inclinaison de l'iPhone.
///
/// Le doigt reste libre : on incline le téléphone vers soi ou en avant, et la
/// page défile. Pratique pour lire d'une main, ou quand l'autre main est prise.
///
/// ## Zone morte et repos
///
/// Un téléphone tenu à la main n'est jamais parfaitement immobile. Sans zone
/// morte, la page dériverait en permanence. On mémorise donc l'inclinaison au
/// moment où l'on active, et on ne défile qu'au-delà de quelques degrés
/// d'écart.
@MainActor
final class TiltScroll: ObservableObject {

    @Published private(set) var isRunning = false

    /// Vitesse maximale, en points par seconde à inclinaison pleine.
    var sensitivity: Double = 1.0

    /// Appelé à cadence régulière avec le défilement à appliquer.
    var onScroll: ((Double) -> Void)?

    private let motion = CMMotionManager()

    /// Inclinaison de référence, prise à l'activation.
    private var restPitch: Double = 0

    /// En deçà, on ne défile pas : c'est le tremblement de la main.
    private let deadZone = 0.12          // ≈ 7°
    /// Au-delà, on ne va pas plus vite : incliner davantage devient inconfortable.
    private let fullTilt = 0.55          // ≈ 31°

    var isAvailable: Bool { motion.isDeviceMotionAvailable }

    func start() {
        guard isAvailable, !isRunning else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        restPitch = .nan
        isRunning = true

        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let pitch = data?.attitude.pitch else { return }
            // Première mesure : elle devient le repos, quelle que soit la
            // façon dont le téléphone est tenu.
            if self.restPitch.isNaN {
                self.restPitch = pitch
                return
            }
            self.apply(pitch: pitch)
        }
    }

    func stop() {
        guard isRunning else { return }
        motion.stopDeviceMotionUpdates()
        isRunning = false
    }

    /// Reprend l'inclinaison actuelle comme position de repos.
    func recenter() {
        restPitch = .nan
    }

    private func apply(pitch: Double) {
        let offset = pitch - restPitch
        let magnitude = abs(offset)
        guard magnitude > deadZone else { return }

        // Progression linéaire entre la zone morte et l'inclinaison pleine,
        // puis mise au carré : les petits gestes restent fins, les grands
        // deviennent francs. Même principe que l'accélération du curseur.
        let ratio = min((magnitude - deadZone) / (fullTilt - deadZone), 1)
        let speed = ratio * ratio * 22 * sensitivity
        onScroll?(offset > 0 ? speed : -speed)
    }
}
