import Foundation
import os

/// Journal de l'app, interrogeable à distance.
///
/// **Pourquoi pas `NSLog`.** Mesuré le 13 août 2026 : sur 653 lignes émises
/// par l'app en une minute, **aucune** ne provenait de nos `NSLog`. Ils
/// n'atteignent pas le journal unifié depuis une app groupée — le message est
/// écrit, mais `log show` ne le restitue pas.
///
/// Ce silence a coûté cher : il a fait conclure « l'iPhone n'envoie rien »
/// alors que la trace censée le prouver n'existait tout simplement pas, et il
/// a masqué qu'une fonctionnalité entière ne tournait pas.
///
/// `os.Logger` avec un sous-système explicite est interrogeable sans
/// ambiguïté :
///
/// ```
/// /usr/bin/log stream --predicate 'subsystem == "com.trackpadhub.machost"' --info
/// ```
enum Trace {

    private static let logger = Logger(subsystem: "com.trackpadhub.machost",
                                       category: "app")

    /// Message reçu de l'iPhone.
    static func received(_ summary: String) {
        logger.notice("reçu · \(summary, privacy: .public)")
    }

    /// Action exécutée sur le Mac.
    static func action(_ summary: String) {
        logger.notice("action · \(summary, privacy: .public)")
    }

    /// Anomalie : autorisation refusée, script en échec, cadre illisible.
    static func problem(_ summary: String) {
        logger.error("problème · \(summary, privacy: .public)")
    }
}
