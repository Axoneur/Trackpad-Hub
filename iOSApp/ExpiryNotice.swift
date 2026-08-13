import Foundation
import UserNotifications

/// Réglages des rappels d'expiration, partagés entre l'écran de réglages et
/// le programmateur.
///
/// Les valeurs par défaut sont **enregistrées** auprès de `UserDefaults` au
/// lancement, et non seulement écrites dans les `@AppStorage` de la vue :
/// sans ça, le programmateur — qui lit les préférences hors de toute vue —
/// obtiendrait `false` et `0` tant que l'utilisateur n'a pas ouvert l'écran
/// des réglages. Les rappels seraient alors silencieusement désactivés pour
/// quiconque ne va jamais dans les réglages, c'est-à-dire presque tout le
/// monde.
enum ReglagesRappels {

    static let actifs = "rappelsExpirationActifs"
    static let premier = "rappelExpirationPremier"
    static let veille = "rappelExpirationVeille"
    static let jourJ = "rappelExpirationJourJ"
    static let heure = "rappelExpirationHeure"
    /// Vrai une fois la présentation du premier lancement passée.
    static let presentationVue = "rappelsPresentationVue"

    /// Choix proposés pour le premier rappel, en jours avant l'échéance.
    ///
    /// Plafonné à 5 : le profil ne dure que 7 jours, un premier rappel plus
    /// tôt tomberait le jour même de l'installation.
    static let avancesPossibles = [5, 3, 2, 1]

    static func enregistrerDefauts() {
        UserDefaults.standard.register(defaults: [
            actifs: true,
            premier: 3,
            veille: true,
            jourJ: true,
            heure: 9,
            presentationVue: false
        ])
    }
}

/// Programme les avertissements d'expiration sur l'iPhone.
///
/// ## Pourquoi programmer à l'avance
///
/// Quand la signature expire, l'app **refuse de s'ouvrir**. Elle ne peut donc
/// plus prévenir de rien : au moment où l'avertissement serait le plus utile,
/// il est trop tard pour l'émettre.
///
/// La seule façon d'être averti, c'est de **déposer les notifications
/// d'avance**, tant que l'app fonctionne encore. iOS les délivrera même si
/// l'app ne s'ouvre plus.
///
/// Elles sont reprogrammées à chaque lancement et à chaque changement de
/// réglage : une réinstallation repousse la date, et les anciennes seraient
/// devenues fausses.
enum ExpiryNotice {

    private static let prefixe = "expiration-"

    // MARK: - Autorisation

    /// Demande l'autorisation, puis programme.
    ///
    /// Appelé **depuis la présentation du premier lancement**, jamais au
    /// démarrage brut. Une alerte système qui surgit sans explication est
    /// refusée par réflexe — et un refus est définitif, iOS ne redemande
    /// jamais. Mesuré sur le Mac de développement, où les notifications
    /// étaient précisément dans cet état.
    static func demanderPuisProgrammer(_ ensuite: @escaping (Bool) -> Void = { _ in }) {
        let centre = UNUserNotificationCenter.current()
        centre.requestAuthorization(options: [.alert, .sound]) { accorde, erreur in
            if !accorde {
                TraceiOS.problem("notifications refusées · " +
                                 (erreur.map { "\($0)" } ?? "refus utilisateur"))
            }
            Task {
                if accorde { await poser(centre) }
                await MainActor.run { ensuite(accorde) }
            }
        }
    }

    /// Reprogramme sans jamais demander l'autorisation.
    ///
    /// À appeler à chaque lancement et après chaque changement de réglage.
    /// Si l'autorisation n'a pas encore été accordée, il n'y a rien à faire :
    /// c'est la présentation qui s'en charge.
    static func programmer() {
        let centre = UNUserNotificationCenter.current()
        centre.getNotificationSettings { reglages in
            guard reglages.authorizationStatus == .authorized
                    || reglages.authorizationStatus == .provisional else { return }
            Task { await poser(centre) }
        }
    }

    /// État de l'autorisation, pour l'affichage dans les réglages.
    static func autorisation(_ retour: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { reglages in
            DispatchQueue.main.async { retour(reglages.authorizationStatus) }
        }
    }

    // MARK: - Programmation

    /// Les moments retenus, dans l'ordre chronologique.
    ///
    /// Exposé pour que l'écran des réglages affiche exactement ce qui sera
    /// déposé, plutôt qu'une description approchée qui pourrait diverger du
    /// comportement réel.
    static func moments(pour expiration: Date, maintenant: Date = Date()) -> [(Date, String)] {
        let prefs = UserDefaults.standard
        guard prefs.bool(forKey: ReglagesRappels.actifs) else { return [] }

        let calendrier = Calendar.current
        let heure = prefs.integer(forKey: ReglagesRappels.heure)
        var resultat: [(Date, String)] = []

        /// Le jour dit, à l'heure choisie.
        func moment(_ jours: Int) -> Date? {
            guard let jour = calendrier.date(byAdding: .day, value: -jours, to: expiration)
            else { return nil }
            return calendrier.date(bySettingHour: heure, minute: 0, second: 0, of: jour)
        }

        let premier = prefs.integer(forKey: ReglagesRappels.premier)
        if premier > 1, let quand = moment(premier) {
            resultat.append((quand, "dans \(premier) jours"))
        }
        if prefs.bool(forKey: ReglagesRappels.veille), let quand = moment(1) {
            resultat.append((quand, "demain"))
        }

        // Un rappel qui tomberait après l'expiration n'apprendrait plus rien :
        // l'app aurait déjà cessé de s'ouvrir. Cas réel quand l'échéance est
        // tôt le matin et l'heure choisie tard dans la journée.
        return resultat
            .filter { $0.0 > maintenant && $0.0 < expiration }
            .sorted { $0.0 < $1.0 }
    }

    private static func poser(_ centre: UNUserNotificationCenter) async {
        // On efface les anciennes : après une réinstallation, elles
        // annonceraient une date dépassée.
        let existantes = await centre.pendingNotificationRequests()
        centre.removePendingNotificationRequests(
            withIdentifiers: existantes.map(\.identifier).filter { $0.hasPrefix(prefixe) })

        guard let expiration = SigningExpiry.date else {
            TraceiOS.problem("aucune date d'expiration lisible dans le profil")
            return
        }

        var posees = 0
        for (index, (quand, echeance)) in moments(pour: expiration).enumerated() {
            let contenu = UNMutableNotificationContent()
            contenu.title = "TrackPad Hub expire \(echeance)"
            contenu.body = "Un compte Apple gratuit signe pour 7 jours. Sur le Mac : ouvrez TrackPad Hub et touchez « Renouveler maintenant »."
            contenu.sound = .default

            let composantes = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: quand)

            // `try?` : un dépôt refusé ne doit pas empêcher les autres
            // avertissements d'être posés.
            try? await centre.add(
                UNNotificationRequest(
                    identifier: "\(prefixe)\(index)",
                    content: contenu,
                    trigger: UNCalendarNotificationTrigger(dateMatching: composantes,
                                                           repeats: false)))
            posees += 1
        }

        // Le constat, à l'instant exact où l'app cesse de s'ouvrir — et non à
        // l'heure choisie pour les rappels, qui n'aurait ici aucun sens.
        if UserDefaults.standard.bool(forKey: ReglagesRappels.actifs),
           UserDefaults.standard.bool(forKey: ReglagesRappels.jourJ),
           expiration > Date() {
            let contenu = UNMutableNotificationContent()
            contenu.title = "TrackPad Hub a expiré"
            contenu.body = "Ce n'est pas une panne : la signature d'un compte gratuit dure 7 jours. Branchez l'iPhone au Mac et réinstallez."
            contenu.sound = .default
            let composantes = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: expiration)
            try? await centre.add(UNNotificationRequest(
                identifier: "\(prefixe)jourJ",
                content: contenu,
                trigger: UNCalendarNotificationTrigger(dateMatching: composantes, repeats: false)))
            posees += 1
        }

        TraceiOS.action("rappels d'expiration déposés · \(posees) · échéance \(expiration)")
    }
}
