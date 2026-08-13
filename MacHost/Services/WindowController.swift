import Foundation
import AppKit
import ApplicationServices

/// Placement des fenêtres du Mac, à la manière de Magnet ou Rectangle.
///
/// Passe par l'API Accessibilité (`AXUIElement`), déjà autorisée puisque tout
/// le reste de l'app en dépend : aucune autorisation supplémentaire à
/// demander. Le WindowServer n'entre pas en jeu ici, contrairement aux
/// raccourcis de bureaux — c'est une manipulation directe de la fenêtre.
final class WindowController {

    /// L'énumération vit dans `Shared/WindowSlot.swift` : l'iPhone en
    /// tire sa grille, le Mac le calcul du cadre. Une seule liste, pas de
    /// dérive entre les deux.
    typealias Placement = WindowSlot

    // MARK: - Géométrie

    /// Calcule le cadre voulu, en coordonnées AppKit (origine en bas à gauche).
    ///
    /// Fonction **pure** : elle ne touche à aucune fenêtre réelle. C'est là que
    /// se cachent les erreurs de placement, et c'est la seule partie qu'on
    /// puisse éprouver sans piloter le système.
    ///
    /// - `visible` : la zone utile de l'écran, barre des menus et Dock exclus.
    /// - `current` : le cadre actuel de la fenêtre, utile pour « centrer ».
    static func frame(for placement: Placement,
                      in visible: CGRect,
                      current: CGRect) -> CGRect? {
        let halfWidth = visible.width / 2
        let halfHeight = visible.height / 2
        let third = visible.width / 3

        switch placement {
        case .leftHalf:
            return CGRect(x: visible.minX, y: visible.minY,
                          width: halfWidth, height: visible.height)
        case .rightHalf:
            return CGRect(x: visible.midX, y: visible.minY,
                          width: halfWidth, height: visible.height)
        case .topHalf:
            return CGRect(x: visible.minX, y: visible.midY,
                          width: visible.width, height: halfHeight)
        case .bottomHalf:
            return CGRect(x: visible.minX, y: visible.minY,
                          width: visible.width, height: halfHeight)

        case .topLeft:
            return CGRect(x: visible.minX, y: visible.midY,
                          width: halfWidth, height: halfHeight)
        case .topRight:
            return CGRect(x: visible.midX, y: visible.midY,
                          width: halfWidth, height: halfHeight)
        case .bottomLeft:
            return CGRect(x: visible.minX, y: visible.minY,
                          width: halfWidth, height: halfHeight)
        case .bottomRight:
            return CGRect(x: visible.midX, y: visible.minY,
                          width: halfWidth, height: halfHeight)

        case .leftThird:
            return CGRect(x: visible.minX, y: visible.minY,
                          width: third, height: visible.height)
        case .centerThird:
            return CGRect(x: visible.minX + third, y: visible.minY,
                          width: third, height: visible.height)
        case .rightThird:
            return CGRect(x: visible.minX + 2 * third, y: visible.minY,
                          width: third, height: visible.height)
        case .leftTwoThirds:
            return CGRect(x: visible.minX, y: visible.minY,
                          width: 2 * third, height: visible.height)
        case .rightTwoThirds:
            return CGRect(x: visible.minX + third, y: visible.minY,
                          width: 2 * third, height: visible.height)

        case .maximize:
            return visible

        case .center:
            // On garde la taille, on ne déplace que le centre — et on borne à
            // la zone utile, sinon une fenêtre plus grande que l'écran
            // ressortirait sous la barre des menus.
            let width = min(current.width, visible.width)
            let height = min(current.height, visible.height)
            return CGRect(x: visible.midX - width / 2,
                          y: visible.midY - height / 2,
                          width: width, height: height)

        // Ceux-là ne se calculent pas ici : « rétablir » relit un cadre
        // mémorisé, « écran suivant » a besoin de l'écran d'arrivée, et
        // réduire ou passer en plein écran ne sont pas des géométries mais
        // des attributs de la fenêtre.
        case .restore, .nextDisplay, .minimize, .fullscreen:
            return nil
        }
    }

    // MARK: - Application

    /// Dernier cadre connu avant déplacement, par application.
    ///
    /// Indexé par PID : deux fenêtres d'une même app se partagent l'entrée,
    /// ce qui suffit pour un « rétablir » qui annule le dernier geste.
    private var previousFrames: [pid_t: CGRect] = [:]

    /// Dernière erreur, affichée dans le diagnostic.
    private(set) var lastError: String?

    func handle(placement rawValue: String) {
        guard let placement = Placement(rawValue: rawValue) else { return }
        // L'API Accessibilité veut la file principale, comme le reste d'AppKit.
        DispatchQueue.main.async { [weak self] in
            self?.apply(placement)
        }
    }

    private func apply(_ placement: Placement) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            lastError = "Aucune application au premier plan."
            return
        }
        let pid = app.processIdentifier

        // Ne pas déplacer sa propre fenêtre : la commande vient de l'iPhone,
        // la fenêtre attendue est celle que l'utilisateur regarde.
        guard pid != ProcessInfo.processInfo.processIdentifier else {
            lastError = "TrackPad Hub est au premier plan. Activez d'abord la fenêtre à déplacer."
            return
        }

        let element = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,
                                            kAXFocusedWindowAttribute as CFString,
                                            &windowRef) == .success,
              let window = windowRef else {
            lastError = "\(app.localizedName ?? "L'app") n'expose aucune fenêtre active."
            return
        }
        let axWindow = window as! AXUIElement

        guard let currentAX = readFrame(axWindow) else {
            lastError = "Cadre de la fenêtre illisible."
            return
        }
        let current = Self.appKitRect(fromAX: currentAX)

        guard let screen = screenContaining(current) else {
            lastError = "Écran introuvable."
            return
        }

        // Réduire et plein écran ne se calculent pas : on bascule un attribut
        // et on s'arrête là.
        switch placement {
        case .minimize:
            setBool(true, attribute: kAXMinimizedAttribute, on: axWindow)
            lastError = nil
            return
        case .fullscreen:
            // « AXFullScreen » n'a pas de constante publique — Apple ne
            // l'expose pas, alors que l'attribut existe et fonctionne depuis
            // Lion. D'où la chaîne littérale, isolée ici.
            let current = readBool(Self.fullScreenAttribute, on: axWindow) ?? false
            setBool(!current, attribute: Self.fullScreenAttribute, on: axWindow)
            if current == readBool(Self.fullScreenAttribute, on: axWindow) {
                lastError = "Cette fenêtre refuse le plein écran."
            } else {
                lastError = nil
            }
            return
        default:
            break
        }

        let target: CGRect?
        switch placement {
        case .restore:
            target = previousFrames[pid]
        case .nextDisplay:
            target = frameOnNextDisplay(from: current, currentScreen: screen)
        default:
            target = Self.frame(for: placement, in: screen.visibleFrame, current: current)
        }

        guard let target else {
            lastError = placement == .restore
                ? "Rien à rétablir."
                : "Un seul écran détecté."
            return
        }

        previousFrames[pid] = current
        write(target, to: axWindow)
        lastError = nil
    }

    /// Même position relative, sur l'écran suivant.
    private func frameOnNextDisplay(from current: CGRect, currentScreen: NSScreen) -> CGRect? {
        let screens = NSScreen.screens
        guard screens.count > 1,
              let index = screens.firstIndex(of: currentScreen) else { return nil }
        let next = screens[(index + 1) % screens.count]

        let from = currentScreen.visibleFrame
        let to = next.visibleFrame
        // Proportions conservées : une fenêtre en moitié gauche reste en
        // moitié gauche, même si le second écran n'a pas la même taille.
        let ratioX = from.width  > 0 ? (current.minX - from.minX) / from.width  : 0
        let ratioY = from.height > 0 ? (current.minY - from.minY) / from.height : 0
        let ratioW = from.width  > 0 ? current.width  / from.width  : 1
        let ratioH = from.height > 0 ? current.height / from.height : 1

        return CGRect(x: to.minX + ratioX * to.width,
                      y: to.minY + ratioY * to.height,
                      width: ratioW * to.width,
                      height: ratioH * to.height)
    }

    private func screenContaining(_ frame: CGRect) -> NSScreen? {
        // Celui qui recouvre le plus la fenêtre, et non celui qui contient son
        // coin : une fenêtre à cheval doit suivre l'écran où elle est
        // majoritairement visible.
        NSScreen.screens.max { a, b in
            a.frame.intersection(frame).area < b.frame.intersection(frame).area
        } ?? NSScreen.main
    }

    // MARK: - Attributs booléens

    /// Attribut de plein écran, sans constante publique dans le SDK.
    private static let fullScreenAttribute = "AXFullScreen"

    private func setBool(_ value: Bool, attribute: String, on window: AXUIElement) {
        AXUIElementSetAttributeValue(window, attribute as CFString, value as CFBoolean)
    }

    private func readBool(_ attribute: String, on window: AXUIElement) -> Bool? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &ref) == .success,
              let value = ref as? Bool else { return nil }
        return value
    }

    // MARK: - Lecture et écriture AX

    private func readFrame(_ window: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    private func write(_ frame: CGRect, to window: AXUIElement) {
        let ax = Self.axRect(fromAppKit: frame)
        var origin = ax.origin
        var size = ax.size

        // La taille d'abord, puis la position, puis la taille à nouveau.
        //
        // Une fenêtre qui refuse de rétrécir tant qu'elle est près d'un bord
        // se retrouve mal placée si l'on ne fait qu'un passage : on pose la
        // taille, on déplace, puis on repose la taille une fois la fenêtre
        // là où il y a la place.
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
    }

    // MARK: - Conversion de repère

    /// Repère AppKit → repère Accessibilité, et retour.
    ///
    /// **Le piège de ce fichier.** AppKit place l'origine en bas à gauche de
    /// l'écran principal, avec Y qui monte. L'API Accessibilité la place en
    /// haut à gauche, avec Y qui descend. Confondre les deux ne produit pas
    /// une erreur : la fenêtre part simplement dans le mauvais sens, d'autant
    /// plus loin qu'elle était basse — un symptôme facile à prendre pour un
    /// mauvais calcul de moitié d'écran.
    ///
    /// La bascule se fait autour du **haut de l'écran principal**, qui est
    /// l'origine commune aux deux repères.
    private static var primaryTop: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    static func axRect(fromAppKit rect: CGRect) -> CGRect {
        CGRect(x: rect.minX,
               y: primaryTop - rect.maxY,
               width: rect.width,
               height: rect.height)
    }

    static func appKitRect(fromAX rect: CGRect) -> CGRect {
        CGRect(x: rect.minX,
               y: primaryTop - rect.maxY,
               width: rect.width,
               height: rect.height)
    }
}

private extension CGRect {
    /// Aire, nulle si le rectangle est vide — `intersection` renvoie
    /// `.null` quand il n'y a aucun recouvrement, dont les dimensions sont
    /// infinies.
    var area: CGFloat {
        isNull || isInfinite ? 0 : width * height
    }
}
