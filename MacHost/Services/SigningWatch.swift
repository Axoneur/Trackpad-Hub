import Foundation

/// Surveille l'expiration du profil de provisionnement **iOS**.
///
/// ## Pourquoi c'est le Mac qui surveille
///
/// C'est l'app iPhone qui expire au bout de 7 jours, pas celle du Mac —
/// vérifié : le bundle macOS n'embarque aucun profil, il est signé par un
/// simple certificat de développement.
///
/// Mais l'iPhone ne peut rien y faire : la réinstallation part du Mac. Autant
/// que ce soit le Mac qui prévienne, puisque c'est lui qui a le remède.
///
/// Les profils vivent dans le dossier d'Xcode. On y cherche celui de l'app et
/// on lit sa date d'expiration.
@MainActor
final class SigningWatch: ObservableObject {

    @Published private(set) var expiration: Date?
    @Published private(set) var renouvellementEnCours = false
    @Published private(set) var dernierMessage: String?

    /// Chemin du projet, écrit par `reinstall.sh` à chaque installation.
    ///
    /// C'est ce qui permet au bouton « Renouveler » d'exister : sans lui, l'app
    /// ignorerait où se trouve le script.
    static let clefChemin = "cheminProjet"

    var cheminProjet: String? {
        UserDefaults.standard.string(forKey: Self.clefChemin)
    }

    var joursRestants: Int? {
        guard let expiration else { return nil }
        return Int(floor(expiration.timeIntervalSinceNow / 86_400))
    }

    /// Trois jours : assez tôt pour agir sans urgence, assez tard pour ne pas
    /// afficher un avertissement permanent.
    var doitAvertir: Bool {
        guard let jours = joursRestants else { return false }
        return jours <= 3
    }

    var resume: String? {
        guard let jours = joursRestants else { return nil }
        if jours < 0 { return "Signature de l'app iPhone expirée" }
        if jours == 0 { return "L'app iPhone expire aujourd'hui" }
        if jours == 1 { return "L'app iPhone expire demain" }
        return "L'app iPhone expire dans \(jours) jours"
    }

    private var minuterie: Timer?

    init() {
        actualiser()
        // Une app de bureau reste ouverte des jours. Sans relance, la date
        // lue au lancement resterait figée et le palier « expire demain »
        // ne serait jamais franchi tant que l'app n'est pas relancée.
        // Toutes les heures : le palier le plus fin est le jour.
        minuterie = Timer.scheduledTimer(withTimeInterval: 3_600, repeats: true) { _ in
            Task { @MainActor in self.actualiser() }
        }
    }

    // MARK: - Lecture

    func actualiser() {
        expiration = Self.prochaineExpiration()
        // Prévenir hors de l'app : personne ne garde la fenêtre ouverte pour
        // surveiller une date d'expiration.
        if let jours = joursRestants {
            MaintenanceNotifier.signalerExpiration(jours: jours)
        }
    }

    private static func prochaineExpiration() -> Date? {
        let dossier = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/UserData/Provisioning Profiles")
        guard let fichiers = try? FileManager.default.contentsOfDirectory(
            at: dossier, includingPropertiesForKeys: nil) else { return nil }

        let prefixe = Bundle.main.bundleIdentifier?
            .replacingOccurrences(of: ".machost", with: "") ?? "trackpadhub"

        var dates: [Date] = []
        for fichier in fichiers where fichier.pathExtension == "mobileprovision" {
            guard let donnees = try? Data(contentsOf: fichier),
                  let plist = Self.plist(dans: donnees) else { continue }

            // On ne garde que les profils de ce projet : la machine en contient
            // souvent des dizaines, appartenant à d'autres apps.
            let identifiant = ((plist["Entitlements"] as? [String: Any])?["application-identifier"] as? String) ?? ""
            let nom = (plist["Name"] as? String) ?? ""
            guard identifiant.contains(prefixe) || nom.lowercased().contains("trackpad") else { continue }

            if let date = plist["ExpirationDate"] as? Date { dates.append(date) }
        }
        // La plus proche : c'est elle qui décide quand l'app cesse de s'ouvrir.
        return dates.min()
    }

    /// Installe la réinstallation automatique, tous les 6 jours.
    ///
    /// C'est la vraie réponse au problème : plutôt que de se souvenir de
    /// relancer un script chaque semaine, on le laisse tourner tout seul.
    func planifier() {
        guard let chemin = cheminProjet else {
            dernierMessage = "Chemin du projet inconnu."
            return
        }
        let processus = Process()
        processus.executableURL = URL(fileURLWithPath: "/bin/bash")
        processus.arguments = ["\(chemin)/reinstall.sh", "--install"]
        processus.currentDirectoryURL = URL(fileURLWithPath: chemin)
        do {
            try processus.run()
            processus.waitUntilExit()
            dernierMessage = processus.terminationStatus == 0
                ? "Réinstallation planifiée tous les 6 jours. L'iPhone doit être branché à ce moment-là."
                : "La planification a échoué (code \(processus.terminationStatus))."
        } catch {
            dernierMessage = "Lancement impossible : \(error.localizedDescription)"
        }
    }

    /// Le profil est un conteneur signé ; on en extrait le plist en clair.
    private static func plist(dans donnees: Data) -> [String: Any]? {
        guard let debut = donnees.range(of: Data("<?xml".utf8)),
              let fin = donnees.range(of: Data("</plist>".utf8)) else { return nil }
        let extrait = donnees[debut.lowerBound..<fin.upperBound]
        return (try? PropertyListSerialization.propertyList(
            from: extrait, options: [], format: nil)) as? [String: Any]
    }

    // MARK: - Renouvellement

    /// Relance `./reinstall.sh --all` dans le dossier du projet.
    ///
    /// L'app n'est pas en bac à sable : elle peut lancer un processus. C'est ce
    /// qui rend le renouvellement possible en un clic, au lieu d'ouvrir un
    /// terminal et de retrouver le chemin du projet.
    func renouveler() {
        guard let chemin = cheminProjet, !renouvellementEnCours else {
            dernierMessage = "Chemin du projet inconnu. Relancez ./reinstall.sh une fois depuis le dossier."
            return
        }

        let script = URL(fileURLWithPath: chemin).appendingPathComponent("reinstall.sh")
        guard FileManager.default.isExecutableFile(atPath: script.path) else {
            dernierMessage = "Script introuvable dans \(chemin)."
            return
        }

        renouvellementEnCours = true
        dernierMessage = "Réinstallation en cours… l'iPhone doit être branché."

        // Dans un terminal, et non en silence : la compilation dure plusieurs
        // minutes et peut demander une autorisation. Voir défiler la sortie
        // vaut mieux qu'une barre qui tourne sans rien dire.
        let processus = Process()
        processus.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        processus.arguments = ["-a", "Terminal", script.path]
        do {
            try processus.run()
            dernierMessage = "Réinstallation lancée dans le Terminal."
        } catch {
            dernierMessage = "Lancement impossible : \(error.localizedDescription)"
        }
        renouvellementEnCours = false
    }
}
