import Foundation
import UserNotifications

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
/// Elles sont reprogrammées à chaque lancement : une réinstallation repousse
/// la date, et les anciennes seraient devenues fausses.
enum ExpiryNotice {

    private static let prefixe = "expiration-"

    /// Jours avant l'échéance où prévenir.
    private static let avances = [3, 1]

    static func programmer() {
        let centre = UNUserNotificationCenter.current()

        centre.requestAuthorization(options: [.alert, .sound]) { accorde, erreur in
            guard accorde else {
                TraceiOS.problem("notifications refusées · " +
                                 (erreur.map { "\($0)" } ?? "refus utilisateur"))
                return
            }
            Task { await poser(centre) }
        }
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

        for avance in avances {
            let quand = expiration.addingTimeInterval(-Double(avance) * 86_400)
            guard quand > Date() else { continue }

            let contenu = UNMutableNotificationContent()
            contenu.title = avance == 1
                ? "TrackPad Hub expire demain"
                : "TrackPad Hub expire dans \(avance) jours"
            contenu.body = "Un compte Apple gratuit signe pour 7 jours. Sur le Mac : ouvrez TrackPad Hub et touchez « Renouveler maintenant »."
            contenu.sound = .default

            let composantes = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: quand)
            let declencheur = UNCalendarNotificationTrigger(
                dateMatching: composantes, repeats: false)

            // `try?` : un dépôt refusé ne doit pas empêcher les autres
            // avertissements d'être posés.
            try? await centre.add(
                UNNotificationRequest(identifier: "\(prefixe)\(avance)",
                                      content: contenu,
                                      trigger: declencheur))
        }

        TraceiOS.action("avertissements d'expiration déposés · échéance \(expiration)")

        // Et le jour même, quand l'app ne s'ouvrira plus.
        if expiration > Date() {
            let contenu = UNMutableNotificationContent()
            contenu.title = "TrackPad Hub a expiré"
            contenu.body = "Ce n'est pas une panne : la signature d'un compte gratuit dure 7 jours. Branchez l'iPhone au Mac et réinstallez."
            contenu.sound = .default
            let composantes = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: expiration)
            try? await centre.add(UNNotificationRequest(
                identifier: "\(prefixe)0",
                content: contenu,
                trigger: UNCalendarNotificationTrigger(dateMatching: composantes, repeats: false)))
        }
    }
}
