import Foundation
import ApplicationServices
import AppKit
import Combine

/// Suit l'autorisation « Accessibilité », indispensable pour poster les
/// événements souris et clavier.
///
/// macOS ne notifie pas l'app quand l'utilisateur coche la case dans les
/// Réglages Système : sans sondage, l'interface resterait bloquée sur
/// « autorisation manquante » jusqu'au prochain redémarrage de l'app.
@MainActor
final class AccessibilityManager: ObservableObject {

    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()

    private var timer: Timer?

    init() {
        startPolling()

        // Une app n'apparaît dans la liste « Accessibilité » qu'après avoir
        // demandé l'autorisation au moins une fois. Sans cet appel, elle reste
        // introuvable dans les Réglages Système, et l'utilisateur ne peut même
        // pas la cocher à la main.
        //
        // L'autorisation étant liée à l'emplacement du bundle, déplacer l'app
        // — de Xcode vers /Applications, par exemple — la remet à zéro.
        if !isTrusted {
            request()
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = AXIsProcessTrusted()
                if trusted != self.isTrusted {
                    self.isTrusted = trusted
                    // Une fois accordée, l'autorisation ne se retire quasiment
                    // jamais : on arrête de sonder.
                    if trusted { self.timer?.invalidate() }
                }
            }
        }
    }

    /// Affiche la demande système (et ajoute l'app à la liste).
    func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
