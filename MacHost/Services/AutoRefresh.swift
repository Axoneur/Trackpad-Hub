import Foundation
import Combine

/// Rafraîchit l'app iPhone toute seule, quand le câble est là pour le faire.
///
/// ## Le problème que ça résout
///
/// Le renouvellement demande deux choses au même moment : un iPhone branché,
/// et quelqu'un pour lancer le script. La première arrive tous les jours, la
/// seconde ne se produit qu'après avoir vu passer un avertissement. D'où des
/// expirations alors même que le téléphone était branché la veille.
///
/// Ici, le branchement suffit : le Mac s'en occupe.
///
/// ## Pourquoi pas à chaque branchement
///
/// Parce que ça ne servirait à rien la plupart du temps. Mesuré le 13 août
/// 2026 : réinstaller alors qu'il restait 4 jours n'a **pas** déplacé la date
/// d'expiration d'une heure — Apple ne délivre un profil neuf que lorsque
/// l'ancien approche de sa fin, sinon Xcode réutilise celui qui existe. Une
/// compilation de deux minutes à chaque fois qu'on met le téléphone à charger,
/// pour un résultat identique, serait du bruit pur.
///
/// Le seuil reste réglable, « à chaque branchement » compris.
/// Dernière ligne lue sur la sortie du script, protégée par un verrou.
///
/// Elle est **écrite** depuis la file d'entrée/sortie du tube et **relue**
/// depuis le gestionnaire de fin du processus, qui s'exécute sur une autre
/// file. Une simple variable capturée serait une course de données — Swift 6
/// refuse d'ailleurs de compiler ce motif.
private final class LigneCourante: @unchecked Sendable {
    private let verrou = NSLock()
    private var valeur = ""

    func ecrire(_ texte: String) {
        verrou.lock(); defer { verrou.unlock() }
        valeur = texte
    }

    func lire() -> String {
        verrou.lock(); defer { verrou.unlock() }
        return valeur
    }
}

@MainActor
final class AutoRefresh: ObservableObject {

    // MARK: - Réglages

    static let clefActif = "rafraichissementAuto"
    static let clefSeuil = "rafraichissementSeuil"

    /// Valeur de seuil signifiant « sans condition ».
    static let seuilToujours = 99

    static func enregistrerDefauts() {
        UserDefaults.standard.register(defaults: [clefActif: true, clefSeuil: 3])
    }

    // MARK: - État

    enum Etat: Equatable {
        case repos
        /// Secondes restantes avant le démarrage automatique.
        case compteARebours(Int)
        case enCours(String)
        case reussi(String)
        case echoue(String)
    }

    @Published private(set) var etat: Etat = .repos
    /// Pilote l'affichage de la fenêtre de rafraîchissement.
    @Published var visible = false

    private let signature: SigningWatch
    private var minuterie: Timer?
    private var processus: Process?

    /// Vrai tant que l'appareil actuellement branché a déjà été traité.
    ///
    /// Sans ce garde-fou, un `Attached` renvoyé par `usbmuxd` après une
    /// reconnexion — et la réinstallation elle-même en provoque une —
    /// relancerait le rafraîchissement en boucle.
    private var dejaTraite = false

    /// Vrai entre une annulation et la fin effective du processus.
    ///
    /// `terminate()` fait sortir bash avec un code non nul : sans ce drapeau,
    /// le gestionnaire de fin écraserait l'état par `.echoue` **après**
    /// l'annulation. L'état ne revenant jamais à `.repos`, tout
    /// rafraîchissement ultérieur serait bloqué par le garde-fou d'entrée —
    /// une annulation désactivait donc la fonction jusqu'au redémarrage.
    private var annulationDemandee = false

    init(signature: SigningWatch) {
        self.signature = signature
    }

    // MARK: - Décision

    /// Délai avant démarrage, en secondes.
    ///
    /// Assez court pour que ça reste automatique, assez long pour qu'on puisse
    /// dire non : la réinstallation coupe la liaison en cours.
    static let delai = 6

    func appareilBranche() {
        // Chaque refus est tracé : un rafraîchissement qui ne part pas sans
        // qu'on sache pourquoi est exactement le genre de panne muette qui
        // fait conclure « ça ne marche pas ».
        guard !dejaTraite, etat == .repos else {
            Trace.action("rafraîchissement · ignoré, appareil déjà traité")
            return
        }
        guard UserDefaults.standard.bool(forKey: Self.clefActif) else {
            Trace.action("rafraîchissement · désactivé dans les réglages")
            return
        }

        let seuil = UserDefaults.standard.integer(forKey: Self.clefSeuil)
        // Sans date lisible, on ne fait rien plutôt que de compiler à l'aveugle.
        guard let jours = signature.joursRestants else {
            Trace.problem("rafraîchissement · échéance illisible, rien tenté")
            return
        }
        guard seuil == Self.seuilToujours || jours <= seuil else {
            Trace.action("rafraîchissement · pas encore utile · \(jours) j restants, seuil \(seuil)")
            return
        }
        guard signature.cheminProjet != nil else {
            Trace.problem("rafraîchissement · chemin du projet inconnu")
            return
        }

        Trace.action("rafraîchissement · iPhone branché, \(jours) j restants — départ")
        dejaTraite = true
        visible = true
        demarrerCompteARebours()
    }

    func appareilDebranche() {
        dejaTraite = false
        // Un débranchement pendant le compte à rebours annule : le script
        // échouerait de toute façon, faute d'appareil.
        if case .compteARebours = etat { annuler() }
    }

    // MARK: - Compte à rebours

    private func demarrerCompteARebours() {
        var restant = Self.delai
        etat = .compteARebours(restant)
        minuterie?.invalidate()
        minuterie = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, case .compteARebours = self.etat else { return }
                restant -= 1
                if restant <= 0 {
                    self.minuterie?.invalidate()
                    self.lancer()
                } else {
                    self.etat = .compteARebours(restant)
                }
            }
        }
    }

    func annuler() {
        minuterie?.invalidate()
        minuterie = nil
        if processus != nil {
            annulationDemandee = true
            processus?.terminate()
        }
        processus = nil
        etat = .repos
        visible = false
        Trace.action("rafraîchissement · annulé")
    }

    // MARK: - Exécution

    /// Lance `./reinstall.sh` **sans argument**.
    ///
    /// Sans argument, le script ne traite que l'iPhone. C'est indispensable
    /// ici : `--all` recompile et **relance l'app macOS**, c'est-à-dire tue le
    /// processus qui est en train de piloter le rafraîchissement. L'app du Mac
    /// n'expire pas, elle n'a de toute façon rien à y gagner.
    func lancer() {
        guard let chemin = signature.cheminProjet else {
            etat = .echoue("Chemin du projet inconnu — lancez ./reinstall.sh une fois à la main.")
            return
        }
        let script = URL(fileURLWithPath: chemin).appendingPathComponent("reinstall.sh")
        guard FileManager.default.isExecutableFile(atPath: script.path) else {
            etat = .echoue("Script introuvable dans \(chemin).")
            return
        }

        Trace.action("rafraîchissement · lancement de reinstall.sh")
        annulationDemandee = false
        etat = .enCours("Compilation de l'app iPhone…")

        let tube = Pipe()
        let processus = Process()
        processus.executableURL = URL(fileURLWithPath: "/bin/bash")
        processus.arguments = [script.path]
        processus.currentDirectoryURL = URL(fileURLWithPath: chemin)
        processus.standardOutput = tube
        processus.standardError = tube
        self.processus = processus

        // La dernière ligne utile du script sert d'indicateur d'avancement :
        // une barre qui tourne sans rien dire pendant deux minutes laisse
        // croire à un blocage.
        let derniereLigne = LigneCourante()
        tube.fileHandleForReading.readabilityHandler = { poignee in
            let morceau = poignee.availableData
            guard !morceau.isEmpty, let texte = String(data: morceau, encoding: .utf8)
            else { return }
            let lignes = texte.split(separator: "\n").map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard let derniere = lignes.last else { return }
            derniereLigne.ecrire(derniere)
            Task { @MainActor [weak self] in
                guard let self, case .enCours = self.etat else { return }
                self.etat = .enCours(derniere)
            }
        }

        processus.terminationHandler = { [weak self] fini in
            tube.fileHandleForReading.readabilityHandler = nil
            let code = fini.terminationStatus
            let sortie = derniereLigne.lire()
            Task { @MainActor in
                guard let self else { return }
                self.processus = nil
                guard !self.annulationDemandee else {
                    self.annulationDemandee = false
                    self.etat = .repos
                    return
                }
                if code == 0 {
                    Trace.action("rafraîchissement · terminé")
                    self.signature.actualiser()
                    self.etat = .reussi(self.signature.resume ?? "Application rafraîchie.")
                } else {
                    Trace.problem("rafraîchissement · échec code \(code) · \(sortie)")
                    self.etat = .echoue(sortie.isEmpty
                                        ? "La réinstallation a échoué (code \(code))."
                                        : sortie)
                }
            }
        }

        do {
            try processus.run()
        } catch {
            self.processus = nil
            etat = .echoue("Lancement impossible : \(error.localizedDescription)")
        }
    }

    func terminer() {
        etat = .repos
        visible = false
    }
}
