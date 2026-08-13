import UIKit
import CoreGraphics

/// Surface multi-touch qui traduit les gestes en messages pour le Mac.
///
/// - 1 doigt qui glisse       : déplacer le curseur (avec accélération)
/// - 1 doigt, appui bref      : clic gauche
/// - 2 doigts qui glissent    : défilement (avec inertie)
/// - 2 doigts qui s'écartent  : pincer pour zoomer
/// - 2 doigts, appui bref     : clic droit
/// - 3 doigts, appui bref     : clic milieu
/// - 3 doigts qui glissent    : glisser-déposer
/// - appui bref puis glisser  : glisser-déposer (comme sur un vrai trackpad)
///
/// Le type de clic est déterminé par le **nombre maximum de doigts posés
/// pendant le geste**, et non par le nombre de doigts levés simultanément :
/// deux doigts ne décollent jamais exactement au même instant, ce qui
/// produisait deux clics gauches au lieu d'un clic droit.
final class TrackpadSurfaceView: UIView {

    // MARK: - Sorties

    var onMove: ((CGFloat, CGFloat) -> Void)?
    var onScroll: ((CGFloat, CGFloat, ScrollPhase) -> Void)?
    var onZoom: ((CGFloat, ScrollPhase) -> Void)?
    var onClick: ((Int, Bool) -> Void)?
    /// Geste système reconnu (Mission Control, changement de bureau…).
    var onGesture: ((GestureAction) -> Void)?

    // MARK: - Réglages

    /// Accélération du curseur (comme sur macOS : lent = précis, rapide = large).
    var pointerAccelerationEnabled = true
    /// Inertie après un défilement rapide.
    var momentumEnabled = true
    /// Retour haptique sur les clics.
    var hapticsEnabled = true
    /// Défilement naturel (le contenu suit le doigt).
    var naturalScrolling = true

    /// À 3 doigts : gestes système comme sur un Mac, ou glisser-déposer.
    ///
    /// Les deux ne peuvent pas coexister — un balayage à 3 doigts est soit
    /// l'un soit l'autre. macOS privilégie les gestes système par défaut, et
    /// le glisser-déposer reste accessible par l'appui-glisser à un doigt.
    var threeFingerGestures = true

    // MARK: - État d'un doigt
    //
    // `committed` est la position au dernier message envoyé, `current` celle
    // de l'événement en cours. Les deltas se calculent toujours entre les deux,
    // puis on « valide » — sans ça, mettre à jour la position avant le calcul
    // écrase l'origine du delta.

    private struct TouchInfo {
        var start: CGPoint
        var committed: CGPoint
        var current: CGPoint
        var startTime: TimeInterval
        var committedTime: TimeInterval
        var currentTime: TimeInterval
    }

    private var touches: [ObjectIdentifier: TouchInfo] = [:]

    // MARK: - État du geste

    private enum Mode {
        case undecided
        case pointer
        case scroll
        case zoom
        /// 3 doigts posés : on ne sait pas encore si c'est un appui bref
        /// (clic milieu) ou un glissement. Aucun clic n'est envoyé tant que
        /// le doigt n'a pas bougé.
        case pendingDrag
        case drag
        /// 4 doigts : écartement ou rapprochement, tranché au relâchement.
        case fourFingers
        /// Un geste vient d'être envoyé. On ignore tout jusqu'à ce que la
        /// main quitte la surface : sans ça, les doigts encore posés après
        /// un balayage repartent aussitôt en défilement.
        case consumed
    }

    /// Écartement moyen des doigts au début d'un geste à 4 doigts, et sa
    /// dernière valeur connue — au moment du bilan, des doigts sont déjà
    /// levés et l'écartement ne serait plus calculable.
    private var startSpread: CGFloat = 0
    private var lastSpread: CGFloat = 0

    private var mode: Mode = .undecided
    private var maxFingers = 0
    private var gestureStart: TimeInterval = 0
    private var movedSignificantly = false

    /// Écartement des deux doigts au dernier envoi de zoom.
    private var committedPinchDistance: CGFloat = 0
    /// Angle de la paire de doigts au dernier envoi de rotation.
    private var committedPairAngle: CGFloat = 0
    /// Instant du dernier appui bref à deux doigts, pour le double appui.
    private var lastTwoFingerTap: TimeInterval = 0

    /// Un appui bref vient d'avoir lieu : si un doigt se repose aussitôt au
    /// même endroit, c'est un « appui-glisser ».
    private var tapDragArmedUntil: TimeInterval = 0
    private var tapDragOrigin: CGPoint = .zero

    // MARK: - Inertie

    private var displayLink: CADisplayLink?
    private var momentumVelocity: CGPoint = .zero
    private var scrollVelocity: CGPoint = .zero

    // MARK: - Constantes

    private let tapMaxMovement: CGFloat = 14
    private let tapMaxDuration: TimeInterval = 0.35
    private let tapDragWindow: TimeInterval = 0.3
    private let tapDragMaxDistance: CGFloat = 44
    private let pinchThreshold: CGFloat = 12
    private let scrollThreshold: CGFloat = 2
    /// Déplacement minimal pour qu'un balayage à 3 doigts compte comme un geste.
    /// Volontairement bas : sur l'écran d'un iPhone, un balayage à trois
    /// doigts parcourt peu de distance avant d'atteindre le bord.
    private let swipeThreshold: CGFloat = 34
    /// Rotation minimale des deux doigts : environ 20°.
    private let rotationThreshold: CGFloat = 0.35
    /// Délai maximal entre deux appuis à deux doigts pour un double appui.
    private let doubleTapWindow: TimeInterval = 0.4
    /// Variation minimale de l'écartement à 4 doigts.
    private let spreadThreshold: CGFloat = 28
    private let momentumMinVelocity: CGFloat = 220   // points/seconde
    private let momentumStopVelocity: CGFloat = 40
    private let momentumDecay: CGFloat = 0.94

    private lazy var haptics: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        return generator
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isMultipleTouchEnabled = true
        // Transparent : c'est `MagicSurface` qui dessine la coque derrière.
        backgroundColor = .clear
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Doigts posés

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        stopMomentum(notify: true)

        if self.touches.isEmpty {
            gestureStart = touches.first?.timestamp ?? now
            maxFingers = 0
            movedSignificantly = false
            mode = .undecided
        }

        for touch in touches {
            let point = touch.location(in: self)
            self.touches[ObjectIdentifier(touch)] = TouchInfo(start: point,
                                                              committed: point,
                                                              current: point,
                                                              startTime: touch.timestamp,
                                                              committedTime: touch.timestamp,
                                                              currentTime: touch.timestamp)
        }

        maxFingers = max(maxFingers, self.touches.count)

        switch self.touches.count {
        case 1:
            let time = touches.first?.timestamp ?? now
            let point = touches.first?.location(in: self) ?? .zero
            if time < tapDragArmedUntil, distance(point, tapDragOrigin) < tapDragMaxDistance {
                tapDragArmedUntil = 0
                beginDrag()
            }

        case 2:
            // Défilement ou zoom : décidé au premier mouvement réel.
            if mode != .drag {
                mode = .undecided
                committedPinchDistance = pinchDistance(\.current)
                committedPairAngle = pairAngle()
            }

        case 3:
            // Le clic n'est émis qu'au premier mouvement : sinon un appui
            // bref à 3 doigts enverrait un clic gauche au lieu du clic milieu.
            if mode != .drag { mode = .pendingDrag }

        case 4:
            // Écarter ou rapprocher 4 doigts : décidé au relâchement, d'après
            // l'évolution de leur écartement.
            if mode != .drag {
                mode = .fourFingers
                startSpread = fingerSpread()
                lastSpread = startSpread
            }

        default:
            break
        }
    }

    // MARK: - Doigts qui glissent

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !self.touches.isEmpty else { return }

        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard var info = self.touches[id] else { continue }
            let point = touch.location(in: self)
            if distance(point, info.start) > tapMaxMovement { movedSignificantly = true }
            info.current = point
            info.currentTime = touch.timestamp
            self.touches[id] = info
        }

        switch mode {
        case .consumed:
            break

        case .fourFingers:
            // Rien à envoyer pendant le geste : seul son bilan compte, mais
            // il faut suivre l'écartement tant que les 4 doigts sont posés.
            lastSpread = fingerSpread()

        case .pendingDrag:
            guard movedSignificantly else { return }
            // Sur un Mac, 3 doigts servent aux gestes système. Le
            // glisser-déposer reste accessible par l'appui-glisser.
            if threeFingerGestures {
                if let action = swipeDirection() {
                    emitGesture(action)
                    mode = .consumed
                }
                return
            }
            beginDrag()
            emitDragMove()

        case .drag:
            emitDragMove()

        case .pointer:
            emitPointerMove()

        case .scroll:
            emitScroll()

        case .zoom:
            emitZoom()

        case .undecided:
            if self.touches.count == 1 {
                mode = .pointer
                emitPointerMove()
            } else if self.touches.count >= 2 {
                decideTwoFingerMode()
            }
        }
    }

    // MARK: - Doigts levés

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches, cancelled: true)
    }

    private func finish(_ touches: Set<UITouch>, cancelled: Bool) {
        let endTime = touches.first?.timestamp ?? now
        let endPoint = touches.first?.location(in: self) ?? .zero

        for touch in touches {
            self.touches[ObjectIdentifier(touch)] = nil
        }

        // Un geste à deux doigts s'arrête dès qu'il n'en reste qu'un.
        if mode == .scroll, self.touches.count < 2 {
            endScroll(cancelled: cancelled)
        }
        if mode == .zoom, self.touches.count < 2 {
            onZoom?(0, .ended)
            mode = .undecided
        }

        // Le bilan d'un geste à 4 doigts se fait au dernier lever, tant que
        // les positions sont encore connues.
        if mode == .fourFingers, self.touches.count < 3, !cancelled {
            let change = lastSpread - startSpread
            if abs(change) > spreadThreshold {
                emitGesture(change > 0 ? .showDesktop : .spotlight)
            }
            // Consommé dans les deux cas : les doigts restants ne doivent pas
            // se transformer en défilement ou en clic en se relevant.
            mode = .consumed
        }

        guard self.touches.isEmpty else { return }

        if mode == .drag {
            // Un glissement était en cours : on relâche le bouton.
            endDrag()
        } else if mode == .consumed {
            // Geste déjà envoyé, rien à ajouter.
        } else if !cancelled, !movedSignificantly, endTime - gestureStart < tapMaxDuration {
            // Couvre aussi `.pendingDrag` : 3 doigts posés puis relevés sans
            // mouvement, donc un clic milieu.
            emitTap(fingers: maxFingers, at: endPoint, time: endTime)
        }

        mode = .undecided
        maxFingers = 0
        movedSignificantly = false
        pointerTouchID = nil
    }

    // MARK: - Curseur

    /// Doigt qui pilote le curseur, figé pour toute la durée du geste.
    ///
    /// Sans ce verrou, un second doigt effleuré puis relevé change le doigt
    /// « premier posé » en cours de route : le delta est alors calculé depuis
    /// une autre position et le curseur saute. C'est la cause principale des
    /// saccades.
    private var pointerTouchID: ObjectIdentifier?

    /// Déplacement à un doigt.
    private func emitPointerMove() {
        if pointerTouchID == nil || touches[pointerTouchID!] == nil {
            pointerTouchID = sortedIDs.first
        }
        guard let id = pointerTouchID, var info = touches[id] else { return }

        let dx = info.current.x - info.committed.x
        let dy = info.current.y - info.committed.y
        guard dx != 0 || dy != 0 else { return }

        emit(dx: dx, dy: dy, interval: info.currentTime - info.committedTime)

        info.committed = info.current
        info.committedTime = info.currentTime
        touches[id] = info
    }

    /// Déplacement pendant un glissement à 3 doigts : on suit le barycentre
    /// de tous les doigts, sinon le curseur sauterait de l'un à l'autre.
    private func emitDragMove() {
        let translation = centroidTranslation()
        guard translation.x != 0 || translation.y != 0 else { return }

        emit(dx: translation.x, dy: translation.y, interval: averageCommitInterval())
        commitAll()
    }

    private func emit(dx: CGFloat, dy: CGFloat, interval: TimeInterval) {
        let output = pointerAccelerationEnabled
            ? accelerate(dx: dx, dy: dy, interval: interval)
            : CGPoint(x: dx, y: dy)
        onMove?(output.x, output.y)
    }

    /// Courbe d'accélération : lent = précis, rapide = grands déplacements.
    ///
    /// L'écran d'un iPhone fait quelques centaines de points de large, celui
    /// d'un Mac plusieurs milliers de pixels. Sans une accélération franche,
    /// traverser l'écran demanderait plusieurs balayages — c'est ce qui donne
    /// l'impression que le réglage de vitesse « ne fait rien ».
    ///
    /// La courbe est quadratique comme celle de macOS : quasi 1:1 sous le
    /// doigt lent, jusqu'à 6× sur un geste rapide.
    private func accelerate(dx: CGFloat, dy: CGFloat, interval: TimeInterval) -> CGPoint {
        let travelled = hypot(dx, dy)
        guard interval > 0, travelled > 0 else { return CGPoint(x: dx, y: dy) }

        let instant = travelled / CGFloat(interval)        // points/seconde

        // La vitesse est lissée et **survit brièvement au lever du doigt** :
        // sinon, reposer le doigt pour continuer un grand déplacement repart
        // de zéro, et le curseur semble redevenir lent à chaque reprise.
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastAccelerationTime > accelerationMemory {
            smoothedSpeed = instant
        } else {
            smoothedSpeed = smoothedSpeed * 0.6 + instant * 0.4
        }
        lastAccelerationTime = now

        let normalised = min(smoothedSpeed / 2200, 1)      // 0 lent → 1 rapide
        let factor = 1 + 5 * normalised * normalised
        return CGPoint(x: dx * factor, y: dy * factor)
    }

    /// Vitesse lissée, et instant du dernier calcul.
    private var smoothedSpeed: CGFloat = 0
    private var lastAccelerationTime: TimeInterval = 0
    /// Au-delà de ce délai sans mouvement, on repart d'une vitesse neuve.
    private let accelerationMemory: TimeInterval = 0.25

    // MARK: - Deux doigts : défilement ou zoom

    private func decideTwoFingerMode() {
        guard touches.count >= 2 else { return }

        let spread = abs(pinchDistance(\.current) - committedPinchDistance)
        let translation = midpointTranslation()
        let slide = hypot(translation.x, translation.y)
        let rotation = pairRotation()

        // Rotation : testée en premier, car elle ne modifie ni l'écartement
        // ni le point milieu, et passerait donc inaperçue.
        if abs(rotation) > rotationThreshold, spread < pinchThreshold, slide < 12 {
            emitGesture(rotation > 0 ? .rotateRight : .rotateLeft)
            // On repart d'un angle neuf plutôt que de consommer le geste :
            // faire pivoter de 90° en quatre fois doit rester possible sans
            // relever les doigts.
            commitAll()
            committedPairAngle = pairAngle()
            movedSignificantly = true
            return
        }

        // Le mode est verrouillé au premier mouvement significatif, sinon le
        // geste oscillerait en permanence entre défilement et zoom.
        if spread > pinchThreshold, spread > slide {
            mode = .zoom
            onZoom?(0, .began)
            emitZoom()
        } else if slide > scrollThreshold {
            mode = .scroll
            scrollVelocity = .zero
            onScroll?(0, 0, .began)
            emitScroll()
        }
    }

    private func emitScroll() {
        guard touches.count >= 2 else { return }

        let translation = midpointTranslation()
        guard translation.x != 0 || translation.y != 0 else { return }

        // Vitesse lissée, pour l'inertie.
        let interval = averageCommitInterval()
        if interval > 0 {
            let instant = CGPoint(x: translation.x / CGFloat(interval),
                                  y: translation.y / CGFloat(interval))
            scrollVelocity = CGPoint(x: scrollVelocity.x * 0.7 + instant.x * 0.3,
                                     y: scrollVelocity.y * 0.7 + instant.y * 0.3)
        }

        let direction: CGFloat = naturalScrolling ? 1 : -1
        onScroll?(translation.x * direction, translation.y * direction, .changed)
        commitAll()
    }

    private func endScroll(cancelled: Bool) {
        onScroll?(0, 0, .ended)
        mode = .undecided

        guard !cancelled, momentumEnabled,
              hypot(scrollVelocity.x, scrollVelocity.y) > momentumMinVelocity else {
            scrollVelocity = .zero
            return
        }
        startMomentum()
    }

    private func emitZoom() {
        guard touches.count >= 2 else { return }

        let current = pinchDistance(\.current)
        guard current > 0, committedPinchDistance > 0 else { return }

        // Variation relative de l'écartement.
        let delta = (current - committedPinchDistance) / committedPinchDistance
        guard abs(delta) > 0.001 else { return }

        committedPinchDistance = current
        onZoom?(delta, .changed)
        commitAll()
    }

    // MARK: - Gestes système

    /// Direction dominante du balayage en cours, si elle est franche.
    ///
    /// On exige un déplacement net et une direction clairement dominante :
    /// sans ça, un simple glissement à 3 doigts déclencherait Mission Control
    /// au moindre tremblement vertical.
    private func swipeDirection() -> GestureAction? {
        let translation = centroidTravel()
        let horizontal = abs(translation.x)
        let vertical = abs(translation.y)

        guard max(horizontal, vertical) > swipeThreshold else { return nil }
        guard max(horizontal, vertical) > min(horizontal, vertical) * 1.6 else { return nil }

        if vertical > horizontal {
            return translation.y < 0 ? .missionControl : .appExpose
        }
        return translation.x < 0 ? .spaceRight : .spaceLeft
    }

    /// Déplacement du barycentre depuis le début du geste, tous doigts confondus.
    private func centroidTravel() -> CGPoint {
        let all = touches.values
        guard !all.isEmpty else { return .zero }
        let count = CGFloat(all.count)
        let dx = all.reduce(CGFloat.zero) { $0 + ($1.current.x - $1.start.x) } / count
        let dy = all.reduce(CGFloat.zero) { $0 + ($1.current.y - $1.start.y) } / count
        return CGPoint(x: dx, y: dy)
    }

    /// Angle formé par les deux premiers doigts, en radians.
    private func pairAngle() -> CGFloat {
        let pair = sortedIDs.prefix(2).compactMap { touches[$0] }
        guard pair.count == 2 else { return 0 }
        return atan2(pair[1].current.y - pair[0].current.y,
                     pair[1].current.x - pair[0].current.x)
    }

    /// Rotation accumulée depuis le dernier envoi. Positive dans le sens
    /// horaire.
    private func pairRotation() -> CGFloat {
        let current = pairAngle()
        var delta = current - committedPairAngle
        // L'angle boucle à ±π : sans recadrage, un passage par cette limite
        // se lirait comme une rotation d'un demi-tour.
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return delta
    }

    /// Écartement moyen des doigts par rapport à leur barycentre.
    private func fingerSpread() -> CGFloat {
        let points = touches.values.map(\.current)
        guard points.count >= 2 else { return 0 }
        let centre = CGPoint(x: points.reduce(0) { $0 + $1.x } / CGFloat(points.count),
                             y: points.reduce(0) { $0 + $1.y } / CGFloat(points.count))
        return points.reduce(CGFloat.zero) { $0 + distance($1, centre) } / CGFloat(points.count)
    }

    private func emitGesture(_ action: GestureAction) {
        fireHaptic()
        onGesture?(action)
    }

    // MARK: - Glisser-déposer

    private func beginDrag() {
        mode = .drag
        fireHaptic()
        onClick?(0, true)
    }

    private func endDrag() {
        onClick?(0, false)
        mode = .undecided
    }

    // MARK: - Appuis brefs

    private func emitTap(fingers: Int, at point: CGPoint, time: TimeInterval) {
        // Double appui à deux doigts : remplace le zoom intelligent de macOS,
        // qui n'est pas simulable. Testé avant le clic droit, sinon le second
        // appui enverrait un menu contextuel de plus.
        if fingers == 2 {
            if time - lastTwoFingerTap < doubleTapWindow {
                lastTwoFingerTap = 0
                emitGesture(.zoomReset)
                return
            }
            lastTwoFingerTap = time
        }

        let button: Int
        switch fingers {
        case 2:  button = 1   // clic droit
        case 3:  button = 2   // clic milieu
        default: button = 0   // clic gauche
        }

        fireHaptic()
        onClick?(button, true)

        // Un clic a une durée, et celui-ci n'en avait aucune.
        //
        // L'appui à **un** doigt enfonce et relâche à deux moments distincts
        // (`touchesBegan` / `touchesEnded`) : il dure naturellement. L'appui à
        // deux ou trois doigts, lui, émettait les deux dans la même
        // milliseconde — et le WindowServer fusionne ce qui arrive ensemble,
        // le même piège que les 12 ms entre frappes clavier.
        //
        // Résultat : le clic gauche fonctionnait, le clic droit non. Le menu
        // contextuel s'ouvrait sur l'enfoncement et se refermait aussitôt sur
        // un relâchement jugé simultané.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.onClick?(button, false)
        }

        // L'appui-glisser ne suit qu'un appui à un doigt.
        if fingers == 1 {
            tapDragArmedUntil = time + tapDragWindow
            tapDragOrigin = point
        }
    }

    private func fireHaptic() {
        guard hapticsEnabled else { return }
        haptics.impactOccurred(intensity: 0.7)
        haptics.prepare()
    }

    // MARK: - Inertie

    private func startMomentum() {
        momentumVelocity = scrollVelocity
        scrollVelocity = .zero

        let link = CADisplayLink(target: self, selector: #selector(stepMomentum))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func stepMomentum(_ link: CADisplayLink) {
        let interval = CGFloat(link.targetTimestamp - link.timestamp)
        let direction: CGFloat = naturalScrolling ? 1 : -1

        onScroll?(momentumVelocity.x * interval * direction,
                  momentumVelocity.y * interval * direction,
                  .momentum)

        momentumVelocity.x *= momentumDecay
        momentumVelocity.y *= momentumDecay

        if hypot(momentumVelocity.x, momentumVelocity.y) < momentumStopVelocity {
            stopMomentum(notify: true)
        }
    }

    /// Arrête l'inertie. `notify` envoie la fin de phase au Mac — inutile
    /// quand aucune inertie n'est en cours.
    private func stopMomentum(notify: Bool) {
        guard displayLink != nil else { return }
        displayLink?.invalidate()
        displayLink = nil
        momentumVelocity = .zero
        if notify { onScroll?(0, 0, .momentumEnded) }
    }

    // MARK: - Helpers géométriques

    /// Identifiants triés par ordre de pose : la paire suivie reste stable
    /// pendant tout le geste, même si un troisième doigt se pose.
    private var sortedIDs: [ObjectIdentifier] {
        touches.keys.sorted { lhs, rhs in
            (touches[lhs]?.startTime ?? 0) < (touches[rhs]?.startTime ?? 0)
        }
    }

    /// Déplacement du point milieu des deux premiers doigts depuis le dernier envoi.
    private func midpointTranslation() -> CGPoint {
        let pair = sortedIDs.prefix(2).compactMap { touches[$0] }
        guard pair.count == 2 else { return .zero }
        let currentMid = CGPoint(x: (pair[0].current.x + pair[1].current.x) / 2,
                                 y: (pair[0].current.y + pair[1].current.y) / 2)
        let committedMid = CGPoint(x: (pair[0].committed.x + pair[1].committed.x) / 2,
                                   y: (pair[0].committed.y + pair[1].committed.y) / 2)
        return CGPoint(x: currentMid.x - committedMid.x,
                       y: currentMid.y - committedMid.y)
    }

    /// Déplacement du barycentre de tous les doigts depuis le dernier envoi.
    private func centroidTranslation() -> CGPoint {
        let all = touches.values
        guard !all.isEmpty else { return .zero }
        let count = CGFloat(all.count)
        let dx = all.reduce(CGFloat.zero) { $0 + ($1.current.x - $1.committed.x) } / count
        let dy = all.reduce(CGFloat.zero) { $0 + ($1.current.y - $1.committed.y) } / count
        return CGPoint(x: dx, y: dy)
    }

    /// Écartement des deux premiers doigts, sur la position choisie.
    private func pinchDistance(_ keyPath: KeyPath<TouchInfo, CGPoint>) -> CGFloat {
        let pair = sortedIDs.prefix(2).compactMap { touches[$0] }
        guard pair.count == 2 else { return 0 }
        return distance(pair[0][keyPath: keyPath], pair[1][keyPath: keyPath])
    }

    private func averageCommitInterval() -> TimeInterval {
        let pair = sortedIDs.prefix(2).compactMap { touches[$0] }
        guard !pair.isEmpty else { return 0 }
        let total = pair.reduce(0.0) { $0 + ($1.currentTime - $1.committedTime) }
        return total / Double(pair.count)
    }

    /// Valide les positions courantes comme nouvelles références de delta.
    private func commitAll() {
        for id in touches.keys {
            guard var info = touches[id] else { continue }
            info.committed = info.current
            info.committedTime = info.currentTime
            touches[id] = info
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
