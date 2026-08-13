import Foundation
import AppKit
import CoreGraphics

/// Contrôle la souris du Mac via des événements synthétiques CGEvent.
/// Nécessite l'autorisation « Accessibilité » (Réglages Système > Confidentialité).
final class MouseController {

    /// Une source unique pour tous les événements : macOS les traite alors
    /// comme provenant du même périphérique (important pour l'enchaînement
    /// appui → glissement → relâchement).
    private let source = CGEventSource(stateID: .hidSystemState)

    /// Boutons actuellement enfoncés (0 = gauche, 1 = droit, 2 = milieu).
    private var buttonsDown: Set<Int> = []

    /// Les unités de molette sont entières : on cumule les fractions pour ne
    /// pas perdre les petits mouvements lents.
    private var scrollRemainder = CGPoint.zero

    /// Suivi des doubles/triples clics.
    private var lastClickTime: TimeInterval = 0
    private var lastClickButton = -1
    private var clickState: Int64 = 1

    /// L'inertie doit émettre `Begin` une seule fois, puis `Continue`.
    private var momentumStarted = false

    // MARK: - Champs CGEvent non exposés par l'enum Swift

    private enum Field {
        /// kCGScrollWheelEventIsContinuous
        static let isContinuous = CGEventField(rawValue: 88)!
        /// kCGScrollWheelEventScrollPhase
        static let scrollPhase = CGEventField(rawValue: 99)!
        /// kCGScrollWheelEventMomentumPhase
        static let momentumPhase = CGEventField(rawValue: 123)!
    }

    // MARK: - Position

    /// Position courante du curseur, en coordonnées globales CoreGraphics
    /// (origine en haut à gauche de l'écran principal, y vers le bas).
    ///
    /// Un événement « null » n'est jamais posté : il sert uniquement à lire
    /// la position, ce qui est l'usage documenté.
    private var currentLocation: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    // MARK: - Déplacement

    /// Déplacement relatif du curseur.
    ///
    /// Si un bouton est maintenu, on émet un événement de *glissement* et non
    /// un simple déplacement — sinon macOS interrompt le glisser-déposer.
    func move(dx: Double, dy: Double) {
        guard dx != 0 || dy != 0 else { return }

        let origin = currentLocation
        let target = clamped(CGPoint(x: origin.x + dx, y: origin.y + dy))

        // Delta réellement appliqué après recadrage sur les écrans.
        let appliedX = target.x - origin.x
        let appliedY = target.y - origin.y

        let type: CGEventType
        let button: CGMouseButton
        if buttonsDown.contains(0)      { type = .leftMouseDragged;  button = .left }
        else if buttonsDown.contains(1) { type = .rightMouseDragged; button = .right }
        else if buttonsDown.contains(2) { type = .otherMouseDragged; button = .center }
        else                            { type = .mouseMoved;        button = .left }

        guard let event = CGEvent(mouseEventSource: source,
                                  mouseType: type,
                                  mouseCursorPosition: target,
                                  mouseButton: button) else { return }

        // Certaines apps (jeux, éditeurs 3D) lisent les deltas bruts plutôt
        // que la position absolue.
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(appliedX.rounded()))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(appliedY.rounded()))
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Clics

    /// Clic. `button` : 0 = gauche, 1 = droit, 2 = milieu.
    func click(button: Int, down: Bool) {
        let type: CGEventType
        let mouseButton: CGMouseButton
        switch button {
        case 1:
            type = down ? .rightMouseDown : .rightMouseUp
            mouseButton = .right
        case 2:
            type = down ? .otherMouseDown : .otherMouseUp
            mouseButton = .center
        default:
            type = down ? .leftMouseDown : .leftMouseUp
            mouseButton = .left
        }

        if down {
            // Sans clickState, un double-clic n'est jamais reconnu par le
            // Finder ni par les champs de texte.
            let now = ProcessInfo.processInfo.systemUptime
            if button == lastClickButton, now - lastClickTime <= NSEvent.doubleClickInterval {
                clickState = min(clickState + 1, 3)
            } else {
                clickState = 1
            }
            lastClickTime = now
            lastClickButton = button
            buttonsDown.insert(button)
        } else {
            buttonsDown.remove(button)
        }

        guard let event = CGEvent(mouseEventSource: source,
                                  mouseType: type,
                                  mouseCursorPosition: currentLocation,
                                  mouseButton: mouseButton) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: clickState)
        event.post(tap: .cghidEventTap)

        // Tracé systématique : un clic qui n'aboutit pas ne laisse sinon
        // aucune trace, et il devient impossible de trancher entre « l'iPhone
        // n'envoie rien » et « le Mac poste au mauvais endroit ».
        Trace.action("clic bouton \(button) \(down ? "enfoncé" : "relâché"), état \(clickState)")
    }

    /// Relâche tout bouton resté enfoncé (déconnexion, app mise en veille…).
    func releaseAllButtons() {
        for button in buttonsDown.sorted() {
            click(button: button, down: false)
        }
    }

    // MARK: - Défilement

    /// Défilement en pixels. `dy` positif = contenu vers le bas.
    func scroll(dx: Double, dy: Double, phase: ScrollPhase) {
        if phase == .began {
            scrollRemainder = .zero
            momentumStarted = false
        }

        // Cumul des fractions perdues à l'arrondi.
        let totalX = dx + Double(scrollRemainder.x)
        let totalY = dy + Double(scrollRemainder.y)
        let stepX = totalX.rounded(.towardZero)
        let stepY = totalY.rounded(.towardZero)
        scrollRemainder = CGPoint(x: totalX - stepX, y: totalY - stepY)

        // Les phases de début/fin doivent passer même sans déplacement.
        let isBoundary = (phase != .changed && phase != .momentum)
        guard stepX != 0 || stepY != 0 || isBoundary else { return }

        guard let event = CGEvent(scrollWheelEvent2Source: source,
                                  units: .pixel,
                                  wheelCount: 2,
                                  wheel1: Int32(clamp(-stepY)),
                                  wheel2: Int32(clamp(-stepX)),
                                  wheel3: 0) else { return }

        event.setIntegerValueField(Field.isContinuous, value: 1)

        switch phase {
        case .began:
            event.setIntegerValueField(Field.scrollPhase, value: 1)   // Began
        case .changed:
            event.setIntegerValueField(Field.scrollPhase, value: 2)   // Changed
        case .ended:
            event.setIntegerValueField(Field.scrollPhase, value: 4)   // Ended
        case .momentum:
            event.setIntegerValueField(Field.momentumPhase,
                                       value: momentumStarted ? 2 : 1) // Continue / Begin
            momentumStarted = true
        case .momentumEnded:
            event.setIntegerValueField(Field.momentumPhase, value: 3)  // End
            momentumStarted = false
        }

        event.post(tap: .cghidEventTap)
    }

    // MARK: - Pincer pour zoomer

    /// macOS n'expose pas d'API publique pour fabriquer un événement de
    /// magnification. On envoie donc ⌘ + défilement, que Safari, Aperçu,
    /// Plans, Xcode et VS Code interprètent comme un zoom.
    func zoom(magnification: Double, phase: ScrollPhase) {
        let steps = (magnification * 100).rounded()
        guard steps != 0 else { return }

        guard let event = CGEvent(scrollWheelEvent2Source: source,
                                  units: .pixel,
                                  wheelCount: 1,
                                  wheel1: Int32(clamp(steps)),
                                  wheel2: 0,
                                  wheel3: 0) else { return }
        event.flags = .maskCommand
        event.setIntegerValueField(Field.isContinuous, value: 1)
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Écrans

    /// Empêche le curseur de sortir des écrans : `CGEvent` accepte des
    /// coordonnées hors limites, le curseur se retrouverait bloqué.
    private func clamped(_ point: CGPoint) -> CGPoint {
        let screens = displayBounds()
        guard !screens.isEmpty else { return point }
        if screens.contains(where: { $0.contains(point) }) { return point }

        // Hors de tout écran : on ramène vers l'écran le plus proche.
        var best = point
        var bestDistance = Double.greatestFiniteMagnitude
        for bounds in screens {
            let candidate = CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX - 1),
                                    y: min(max(point.y, bounds.minY), bounds.maxY - 1))
            let distance = pow(candidate.x - point.x, 2) + pow(candidate.y - point.y, 2)
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return best
    }

    /// Bornes des écrans actifs, mises en cache : `move` est appelé jusqu'à
    /// 120 fois par seconde, on ne peut pas interroger CoreGraphics à chaque fois.
    private var cachedBounds: [CGRect] = []
    private var cachedBoundsDate: TimeInterval = 0

    private func displayBounds() -> [CGRect] {
        let now = ProcessInfo.processInfo.systemUptime
        if now - cachedBoundsDate < 2, !cachedBounds.isEmpty {
            return cachedBounds
        }

        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }

        cachedBounds = ids.prefix(Int(count)).map { CGDisplayBounds($0) }
        cachedBoundsDate = now
        return cachedBounds
    }

    /// `Int32(...)` piège sur une valeur hors bornes ; un message corrompu ne
    /// doit pas faire planter l'app.
    private func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, -10_000), 10_000)
    }
}
