import Foundation

/// Vérifie s'il existe une version plus récente sur GitHub.
///
/// Interroge l'API publique des *releases* au lancement, compare avec la
/// version du bundle, et n'annonce rien s'il n'y a rien à annoncer.
///
/// Aucune clé d'API, aucun compte : l'endpoint est public. La limite est de
/// 60 requêtes par heure et par adresse — une consultation au lancement en
/// consomme une, ce qui laisse une marge confortable.
@MainActor
final class ReleaseChecker: ObservableObject {

    /// Dépôt interrogé. À changer si vous publiez votre propre fork.
    static let depot = "Axoneur/Trackpad-Hub"

    struct Release: Equatable {
        let version: String
        let titre: String
        let notes: String
        let url: URL
        let date: Date?
    }

    /// Renseigné seulement quand une version **plus récente** existe.
    @Published private(set) var disponible: Release?
    @Published private(set) var verificationEnCours = false

    /// Version de cette app, telle qu'écrite dans `project.yml`.
    static var versionActuelle: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Ne pas harceler l'utilisateur : une vérification par jour suffit.
    private static let intervalle: TimeInterval = 86_400
    private static let cleDerniereVerification = "derniereVerificationMiseAJour"

    func verifier(force: Bool = false) {
        guard !verificationEnCours else { return }

        if !force {
            let derniere = UserDefaults.standard.double(forKey: Self.cleDerniereVerification)
            guard Date().timeIntervalSince1970 - derniere > Self.intervalle else { return }
        }

        verificationEnCours = true
        Task { [weak self] in
            let trouvee = await Self.dernierePubliee()
            await MainActor.run {
                guard let self else { return }
                self.verificationEnCours = false
                UserDefaults.standard.set(Date().timeIntervalSince1970,
                                          forKey: Self.cleDerniereVerification)
                guard let trouvee,
                      Self.estPlusRecente(trouvee.version, que: Self.versionActuelle) else {
                    self.disponible = nil
                    return
                }
                self.disponible = trouvee
            }
        }
    }

    private static func dernierePubliee() async -> Release? {
        guard let url = URL(string: "https://api.github.com/repos/\(depot)/releases/latest")
        else { return nil }

        var requete = URLRequest(url: url)
        requete.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // Sans délai court, une coupure réseau ferait attendre l'écran de
        // réglages plusieurs dizaines de secondes.
        requete.timeoutInterval = 8

        guard let (donnees, reponse) = try? await URLSession.shared.data(for: requete),
              (reponse as? HTTPURLResponse)?.statusCode == 200,
              let objet = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any]
        else { return nil }

        guard let tag = objet["tag_name"] as? String,
              let lien = objet["html_url"] as? String,
              let url = URL(string: lien) else { return nil }

        let formateur = ISO8601DateFormatter()
        return Release(version: tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV")),
                       titre: (objet["name"] as? String) ?? tag,
                       notes: (objet["body"] as? String) ?? "",
                       url: url,
                       date: (objet["published_at"] as? String).flatMap(formateur.date(from:)))
    }

    /// Compare deux versions « 1.2.3 » nombre par nombre.
    ///
    /// Une comparaison de chaînes dirait que « 1.10 » précède « 1.9 », ce qui
    /// ferait rater une mise à jour au dixième numéro de version.
    static func estPlusRecente(_ candidate: String, que actuelle: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = actuelle.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
