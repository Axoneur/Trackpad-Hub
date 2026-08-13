import Foundation
import CoreMotion
import Combine

/// Souris gyroscopique : l'inclinaison de l'iPhone déplace le curseur.
///
/// On utilise l'attitude fusionnée (`deviceMotion`) plutôt que le gyroscope
/// brut : elle est déjà débruitée et corrigée de la dérive, ce qui évite au
/// curseur de partir tout seul quand l'iPhone est immobile.
@MainActor
final class AirMouse: ObservableObject {

    @Published private(set) var isRunning = false
    @Published private(set) var isAvailable: Bool

    /// Sensibilité, réglable par l'utilisateur.
    var sensitivity: Double = 1.0

    /// Émet les déplacements à appliquer au curseur.
    var onMove: ((Double, Double) -> Void)?

    private let motion = CMMotionManager()

    /// Attitude prise pour origine lors du dernier calibrage.
    private var referenceYaw: Double = 0
    private var referencePitch: Double = 0
    private var lastYaw: Double = 0
    private var lastPitch: Double = 0
    private var hasReference = false

    /// En dessous de ce mouvement angulaire, on considère la main immobile :
    /// sans ce seuil, le tremblement naturel fait vibrer le curseur.
    private let deadZone: Double = 0.0016

    init() {
        isAvailable = motion.isDeviceMotionAvailable
    }

    func start() {
        guard motion.isDeviceMotionAvailable, !isRunning else { return }

        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        hasReference = false
        isRunning = true

        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
            guard let self, let attitude = data?.attitude else { return }
            self.process(yaw: attitude.yaw, pitch: attitude.pitch)
        }
    }

    func stop() {
        guard isRunning else { return }
        motion.stopDeviceMotionUpdates()
        isRunning = false
        hasReference = false
    }

    /// Remet l'orientation courante au centre — l'équivalent de soulever une
    /// souris pour la reposer au milieu du tapis.
    func recenter() {
        hasReference = false
    }

    private func process(yaw: Double, pitch: Double) {
        guard hasReference else {
            referenceYaw = yaw
            referencePitch = pitch
            lastYaw = yaw
            lastPitch = pitch
            hasReference = true
            return
        }

        // Le lacet passe de +π à −π : sans recadrage, le curseur ferait un
        // bond d'un bout à l'autre de l'écran.
        var deltaYaw = yaw - lastYaw
        if deltaYaw > .pi { deltaYaw -= 2 * .pi }
        if deltaYaw < -.pi { deltaYaw += 2 * .pi }

        let deltaPitch = pitch - lastPitch

        lastYaw = yaw
        lastPitch = pitch

        guard abs(deltaYaw) > deadZone || abs(deltaPitch) > deadZone else { return }

        // Radians → points. Le lacet est inversé : tourner l'iPhone vers la
        // droite doit envoyer le curseur vers la droite.
        let gain = 1400.0 * sensitivity
        onMove?(-deltaYaw * gain, deltaPitch * gain)
    }
}
