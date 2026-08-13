import AppIntents
import Foundation
import UIKit

/// Actions exposées à Siri, à l'app Raccourcis et aux widgets.
///
/// Une intention ne peut pas piloter le Mac depuis l'arrière-plan : la session
/// MultipeerConnectivity vit dans l'app. Chaque intention dépose donc l'action
/// dans le groupe partagé et ouvre l'app, qui l'exécute dès qu'elle est
/// appairée.
///
/// Ce fichier est compilé dans l'app **et** dans l'extension de widgets, pour
/// que les boutons des widgets déclenchent exactement les mêmes actions.

// MARK: - Contrôles système

struct LockMacIntent: AppIntent {
    static var title: LocalizedStringResource = "Verrouiller le Mac"
    static var description = IntentDescription("Verrouille l'écran de votre Mac.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        SharedStore.store(pending: .system(.lock))
        return .result()
    }
}

struct SleepMacIntent: AppIntent {
    static var title: LocalizedStringResource = "Mettre le Mac en veille"
    static var description = IntentDescription("Endort votre Mac.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        SharedStore.store(pending: .system(.sleep))
        return .result()
    }
}

struct ShowDesktopIntent: AppIntent {
    static var title: LocalizedStringResource = "Afficher le bureau du Mac"
    static var description = IntentDescription("Écarte toutes les fenêtres pour montrer le bureau.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        SharedStore.store(pending: .system(.showDesktop))
        return .result()
    }
}

// MARK: - Média

struct PlayPauseMacIntent: AppIntent {
    static var title: LocalizedStringResource = "Lecture ou pause sur le Mac"
    static var description = IntentDescription("Bascule la lecture de l'app qui joue sur votre Mac.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        SharedStore.store(pending: .media("playpause"))
        return .result()
    }
}

struct NextTrackMacIntent: AppIntent {
    static var title: LocalizedStringResource = "Piste suivante sur le Mac"
    static var description = IntentDescription("Passe au morceau suivant.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        SharedStore.store(pending: .media("next"))
        return .result()
    }
}

// MARK: - Presse-papiers

struct SendClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Envoyer le presse-papiers au Mac"
    static var description = IntentDescription("Copie le contenu du presse-papiers de l'iPhone vers le Mac.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        if let text = UIPasteboard.general.string, !text.isEmpty {
            SharedStore.store(pending: .clipboardPush(text))
        }
        return .result()
    }
}

// MARK: - Réveil

struct WakeMacIntent: AppIntent {
    static var title: LocalizedStringResource = "Réveiller le Mac"
    static var description = IntentDescription("Envoie un paquet magique pour sortir le Mac de veille.")
    /// Seule intention à ne pas ouvrir l'app : le paquet part directement,
    /// sans avoir besoin d'une session établie.
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults.standard
        guard let mac = defaults.string(forKey: MessageConnection.wakeMacAddressKey),
              !mac.isEmpty else {
            return .result(dialog: "Aucun Mac appairé. Connectez-vous une fois depuis l'app.")
        }

        let broadcast = defaults.string(forKey: MessageConnection.wakeBroadcastKey)
        do {
            try WakeOnLAN.wake(macAddress: mac,
                               broadcast: broadcast?.isEmpty == false ? broadcast! : "255.255.255.255")
            return .result(dialog: "Signal de réveil envoyé à votre Mac.")
        } catch {
            return .result(dialog: "Échec : \(error.localizedDescription)")
        }
    }
}
