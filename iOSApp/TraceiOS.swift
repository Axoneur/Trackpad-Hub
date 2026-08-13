import Foundation
import os

/// Journal de l'app iPhone, lisible depuis le Mac.
///
/// Même raison que `Trace` côté macOS : `NSLog` n'atteint pas le journal
/// unifié depuis une app groupée, et un dépôt de notification qui échoue en
/// silence est indétectable — c'est exactement ce qui s'est produit côté Mac,
/// où les notifications étaient refusées sans que rien ne le signale.
///
/// Depuis le Mac, l'iPhone branché :
///
/// ```
/// /usr/bin/log stream --device --predicate 'subsystem == "com.trackpadhub.ios"' --info
/// ```
enum TraceiOS {

    private static let logger = Logger(subsystem: "com.trackpadhub.ios",
                                       category: "app")

    static func action(_ summary: String) {
        logger.notice("action · \(summary, privacy: .public)")
    }

    static func problem(_ summary: String) {
        logger.error("problème · \(summary, privacy: .public)")
    }
}
