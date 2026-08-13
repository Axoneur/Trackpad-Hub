import Foundation
import UserNotifications

/// Prévient l'utilisateur hors de l'app : expiration proche, version publiée.
///
/// ## Le piège à éviter
///
/// Une notification quotidienne qui répète la même chose est désactivée au
/// bout de trois jours, et l'avertissement utile qui suit ne sera jamais lu.
///
/// D'où deux garde-fous :
/// - des **paliers** — 3 jours, 1 jour, expiré — plutôt qu'un rappel par jour ;
/// - un **souvenir de ce qui a déjà été annoncé**, pour ne jamais répéter le
///   même palier ni la même version.
enum MaintenanceNotifier {

    private static let clefPalier = "dernierPalierNotifie"
    private static let clefVersion = "derniereVersionNotifiee"

    /// Paliers d'alerte, du plus lointain au plus pressant.
    ///
    /// Trois jours laisse le temps d'agir sans urgence ; un jour rattrape ceux
    /// qui n'ont pas réagi ; zéro constate.
    private static let paliers = [3, 1, 0]

    // MARK: - Expiration de la signature

    /// - `jours` : jours restants avant expiration, négatif si déjà expiré.
    static func signalerExpiration(jours: Int) {
        // Le palier atteint : le **plus pressant** de ceux qu'on a franchis.
        //
        // `first` renverrait 3 pour toute valeur inférieure — vérifié sur
        // banc : après la notification des 3 jours, celles de « demain » et
        // « expiré » n'auraient jamais été émises, puisque le palier mémorisé
        // serait resté le même. `last` sur une liste décroissante donne bien
        // l'escalade 3 → 3 → 1 → 0.
        guard let palier = paliers.last(where: { jours <= $0 }) else {
            // Encore loin : on efface la mémoire pour que le cycle suivant
            // puisse à nouveau prévenir.
            UserDefaults.standard.removeObject(forKey: clefPalier)
            return
        }

        let deja = UserDefaults.standard.object(forKey: clefPalier) as? Int
        guard deja != palier else { return }
        UserDefaults.standard.set(palier, forKey: clefPalier)

        let titre: String
        let corps: String
        switch palier {
        case 3:
            titre = "L'app iPhone expire dans 3 jours"
            corps = "Un compte Apple gratuit signe pour 7 jours. Ouvrez TrackPad Hub sur le Mac pour renouveler en un clic, ou automatiser."
        case 1:
            titre = "L'app iPhone expire demain"
            corps = "Après demain elle refusera de s'ouvrir. Branchez l'iPhone et renouvelez depuis l'app macOS."
        default:
            titre = "L'app iPhone a expiré"
            corps = "Ce n'est pas une panne : la signature d'un compte gratuit dure 7 jours. Branchez l'iPhone et réinstallez."
        }
        poster(titre: titre, corps: corps, identifiant: "expiration-\(palier)")
    }

    // MARK: - Mise à jour

    static func signalerVersion(_ version: String, notes: String) {
        // Une version n'est annoncée qu'une fois, même si l'app est relancée
        // dix fois dans la journée.
        guard UserDefaults.standard.string(forKey: clefVersion) != version else { return }
        UserDefaults.standard.set(version, forKey: clefVersion)

        let extrait = notes
            .split(separator: "\n")
            .first
            .map(String.init) ?? ""

        poster(titre: "TrackPad Hub \(version) est disponible",
               corps: extrait.isEmpty
                   ? "Sur le Mac : « git pull » puis « ./reinstall.sh --all »."
                   : extrait,
               identifiant: "version-\(version)")
    }

    // MARK: - Diagnostic

    /// État réel de l'autorisation, journalisé au lancement.
    ///
    /// Distingue les deux cas que « refusé » confond : jamais demandé — la
    /// demande affichera une alerte — et refusé par l'utilisateur — la demande
    /// échouera toujours, seuls les Réglages Système peuvent le débloquer.
    /// - Parameter bloquees: appelé sur la file principale, vrai si seuls les
    ///   Réglages Système peuvent débloquer la situation.
    static func diagnostiquer(bloquees: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().getNotificationSettings { reglages in
            let etat: String
            switch reglages.authorizationStatus {
            case .notDetermined: etat = "jamais demandé"
            case .denied:        etat = "refusé par l'utilisateur"
            case .authorized:    etat = "autorisé"
            case .provisional:   etat = "provisoire"
            case .ephemeral:     etat = "éphémère"
            @unknown default:    etat = "inconnu"
            }
            Trace.action("autorisation notifications · \(etat)")
            let refuse = reglages.authorizationStatus == .denied
            DispatchQueue.main.async { bloquees(refuse) }
        }
    }

    // MARK: - Envoi

    private static func poster(titre: String, corps: String, identifiant: String) {
        let contenu = UNMutableNotificationContent()
        contenu.title = titre
        contenu.body = corps
        contenu.sound = .default

        // On redemande à chaque envoi plutôt que de supposer qu'un autre
        // service l'a fait : c'est idempotent, et une notification silencieuse
        // faute d'autorisation serait indétectable.
        let centre = UNUserNotificationCenter.current()
        centre.requestAuthorization(options: [.alert, .sound]) { accorde, erreur in
            guard accorde else {
                // L'erreur est journalisée : « refusé » sans motif ne permet
                // pas de distinguer un refus de l'utilisateur d'un bundle mal
                // enregistré, et les deux se corrigent différemment.
                Trace.problem("notification refusée · \(erreur.map { "\($0)" } ?? "sans erreur (refus utilisateur)") · \(titre)")
                return
            }
            centre.add(UNNotificationRequest(
                identifier: identifiant, content: contenu, trigger: nil))
            Trace.action("notification · \(titre)")
        }
    }
}
