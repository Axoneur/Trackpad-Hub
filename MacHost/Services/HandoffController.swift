import Foundation
import AppKit

/// Reprise de lecture : ce qui joue sur le Mac, proposé sur l'iPhone.
///
/// ## Pourquoi pas MediaRemote
///
/// Le framework privé `MediaRemote` sait tout du média en cours, et l'app s'en
/// sert déjà pour les commandes lecture/pause. Mais **`MRMediaRemoteGetNowPlayingInfo`
/// ne répond plus** aux apps tierces : Apple l'a restreint aux siennes.
/// Mesuré sur ce Mac — le symbole existe, le rappel n'arrive jamais.
///
/// Et même s'il répondait, il ne donnerait que des métadonnées : titre,
/// artiste, pochette. Or reprendre une lecture demande un **lien**, pas un
/// titre. AppleScript, lui, en fournit un.
///
/// ## Ce qu'on interroge, dans l'ordre
///
/// 1. **Spotify**, s'il joue : il expose l'URI de la piste et la position.
///    C'est le cas idéal — l'iPhone reprend à la seconde près.
/// 2. **Music**, s'il joue : titre, artiste, position. Pas d'URL exploitable,
///    on ouvre donc une recherche dans l'app Musique de l'iPhone.
/// 3. **Le navigateur**, sinon : l'URL de l'onglet actif. C'est le cas le plus
///    courant — vidéo, replay, podcast web — et le lien se rouvre tel quel.
///
/// L'ordre compte : un lecteur dédié qui joue l'emporte sur un onglet de
/// navigateur qui traîne.
final class HandoffController {

    /// Ce que le Mac propose de reprendre.
    private(set) var current: MediaHandoff?

    /// Dernière identité de média journalisée, pour ne pas retracer une
    /// simple avancée de la position de lecture.
    private var derniereIdentiteTracee = ""

    /// Appelé quand la proposition change, pour la pousser vers l'iPhone.
    var onChange: ((MediaHandoff?) -> Void)?

    private var timer: Timer?

    /// File d'interrogation, hors file principale.
    ///
    /// **C'est le point délicat de ce fichier.** `NSAppleScript` exige la file
    /// principale *et* bloque en attendant la réponse de l'app interrogée. Un
    /// sondage périodique y aurait figé, à chaque tour, la file
    /// qui traite aussi l'appairage et les messages de l'iPhone — pour une
    /// fonctionnalité de confort.
    ///
    /// On passe donc par `osascript` dans un processus séparé : il n'a pas
    /// cette contrainte, et son attente ne coûte rien à personne.
    private let queue = DispatchQueue(label: "com.trackpadhub.handoff", qos: .utility)

    // MARK: - Surveillance

    /// Interroge le Mac toutes les cinq secondes.
    ///
    /// Pas plus souvent : chaque tour lance des événements Apple vers deux ou
    /// trois apps, et personne ne change de morceau cinq fois par minute.
    func startWatching() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            let found = self.detect()
            DispatchQueue.main.async {
                guard found != self.current else { return }
                self.current = found

                // Pendant une lecture, `position` avance : l'égalité est donc
                // fausse à chaque sondage et l'envoi part toutes les cinq
                // secondes. C'est **voulu** — l'iPhone s'en sert pour animer
                // sa barre de progression et pour reprendre à la bonne
                // seconde. Le garde ci-dessus n'arrête que les états
                // réellement figés : rien en lecture, ou page inchangée.
                //
                // Le journal, lui, ne doit pas suivre ce rythme : douze lignes
                // identiques par minute noyaient tout le reste, et c'est ce
                // journal qui sert à diagnostiquer les pannes silencieuses.
                // On ne trace donc que les changements d'identité du média.
                let identite = found.map {
                    "\($0.source)|\($0.title)|\($0.url)|\($0.isPlaying)"
                } ?? "rien"
                if identite != self.derniereIdentiteTracee {
                    self.derniereIdentiteTracee = identite
                    Trace.action("média détecté · " + (found.map {
                        "\($0.source) : \($0.title)" } ?? "rien"))
                }

                self.onChange?(found)
            }
        }
    }

    // MARK: - Détection

    private func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    private func detect() -> MediaHandoff? {
        if isRunning("com.spotify.client"), let spotify = fromSpotify() { return spotify }
        if isRunning("com.apple.Music"), let music = fromMusic() { return music }

        // Deux niveaux, dans cet ordre.
        //
        // 1. Ce qui est **réellement lu** — une vidéo en cours, où qu'elle
        //    soit : onglet en arrière-plan, autre fenêtre, ou Picture in
        //    Picture. C'est ce qu'on veut reprendre, et le seul niveau qui
        //    donne une position et une durée.
        // 2. Sinon, la **page ouverte** au premier plan. Toujours disponible,
        //    mais sans savoir si quelque chose y joue.
        if let playing = fromBrowserPlayback() { return playing }

        var page = fromBrowser()
        // Prévenir l'iPhone qu'on ne voit que la page, faute d'autorisation.
        if page != nil, javaScriptChecked, !javaScriptAllowed {
            page?.needsJavaScriptPermission = true
        }
        return page
    }

    /// Safari accepte-t-il `do JavaScript` ? Vérifié une seule fois.
    private var javaScriptChecked = false
    private var javaScriptAllowed = false

    /// Extrait posé dans chaque onglet : renvoie le média en cours, ou rien.
    ///
    /// `querySelector('video, audio')` attrape aussi bien un film qu'un
    /// podcast. `paused` et `ended` écartent une page simplement ouverte.
    private static let playbackProbe =
        "(function(){var v=document.querySelector('video, audio');"
        + "if(!v||v.paused||v.ended)return '';"
        + "var s=String.fromCharCode(31);"
        + "return [document.title,location.href,Math.floor(v.currentTime||0),"
        + "Math.floor(isFinite(v.duration)?v.duration:0)].join(s);})()"

    /// Cherche un média en cours de lecture dans **tous** les onglets.
    ///
    /// Balaie toutes les fenêtres et tous les onglets, pas seulement celui du
    /// premier plan : une vidéo en Picture in Picture continue d'appartenir à
    /// son onglet, même quand on regarde autre chose. C'est précisément le cas
    /// qu'un simple « onglet actif » rate.
    ///
    /// Une seule invocation pour toute la boucle : un `osascript` par onglet
    /// coûterait treize processus sur une fenêtre ordinaire.
    private func fromBrowserPlayback() -> MediaHandoff? {
        for (bundleID, name) in Self.browsers where isRunning(bundleID) {
            let verb = bundleID == "com.apple.Safari" ? "do JavaScript" : "execute javascript"

            if !javaScriptChecked { checkJavaScript(app: name, verb: verb) }
            guard javaScriptAllowed else { continue }

            let escaped = Self.playbackProbe.replacingOccurrences(of: "\"", with: "\\\"")
            let script = """
            tell application "\(name)"
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set r to (\(verb) "\(escaped)" in t)
                            if r is not "" then return r
                        end try
                    end repeat
                end repeat
                return ""
            end tell
            """

            guard let parts = run(script), parts.count >= 4,
                  parts[1].hasPrefix("http") else { continue }

            return MediaHandoff(source: name,
                                title: parts[0].isEmpty ? host(of: parts[1]) : parts[0],
                                subtitle: host(of: parts[1]),
                                url: parts[1],
                                position: Int(parts[2]) ?? 0,
                                duration: Int(parts[3]) ?? 0,
                                isPlaying: true)
        }
        return nil
    }

    /// Le navigateur accepte-t-il d'exécuter du JavaScript ?
    ///
    /// Safari refuse tant que « Autoriser JavaScript depuis les Apple Events »
    /// n'est pas coché dans la section Développement de ses réglages. Sans ce
    /// réglage on ne voit que la page, jamais ce qui s'y joue — d'où le
    /// drapeau remonté jusqu'à l'iPhone, qui explique quoi cocher.
    private func checkJavaScript(app: String, verb: String) {
        javaScriptChecked = true
        let script = """
        tell application "\(app)"
            if (count of windows) is 0 then return ""
            return (\(verb) "'ok'" in current tab of front window) as text
        end tell
        """
        javaScriptAllowed = (run(script)?.first == "ok")
    }

    /// Navigateurs pilotables, du plus courant au plus rare.
    private static let browsers = [
        ("com.apple.Safari", "Safari"),
        ("com.google.Chrome", "Google Chrome"),
        ("com.brave.Browser", "Brave Browser"),
        ("com.microsoft.edgemac", "Microsoft Edge")
    ]

    /// Spotify : le seul à donner une URI reprenable **et** la position.
    private func fromSpotify() -> MediaHandoff? {
        let script = """
        tell application "Spotify"
            if player state is not playing then return ""
            set t to current track
            return (name of t) & "\u{1F}" & (artist of t) & "\u{1F}" & (spotify url of t) \
                & "\u{1F}" & ((player position as integer) as text)
        end tell
        """
        guard let parts = run(script), parts.count >= 4 else { return nil }
        return MediaHandoff(source: "Spotify",
                            title: parts[0],
                            subtitle: parts[1],
                            url: parts[2],
                            position: Int(parts[3]) ?? 0)
    }

    /// Music : pas d'URL exploitable, on ouvrira une recherche sur l'iPhone.
    private func fromMusic() -> MediaHandoff? {
        let script = """
        tell application "Music"
            if player state is not playing then return ""
            set t to current track
            return (name of t) & "\u{1F}" & (artist of t) & "\u{1F}" \
                & ((player position as integer) as text)
        end tell
        """
        guard let parts = run(script), parts.count >= 3 else { return nil }
        let query = "\(parts[0]) \(parts[1])"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return MediaHandoff(source: "Musique",
                            title: parts[0],
                            subtitle: parts[1],
                            url: "music://music.apple.com/search?term=\(query)",
                            position: Int(parts[2]) ?? 0)
    }

    /// Navigateur : l'onglet actif. Le cas le plus courant.
    private func fromBrowser() -> MediaHandoff? {
        for (bundleID, name) in Self.browsers where isRunning(bundleID) {

            let script: String
            if bundleID == "com.apple.Safari" {
                script = """
                tell application "Safari"
                    if (count of windows) is 0 then return ""
                    set t to current tab of front window
                    return (URL of t) & "\u{1F}" & (name of t)
                end tell
                """
            } else {
                script = """
                tell application "\(name)"
                    if (count of windows) is 0 then return ""
                    set t to active tab of window 1
                    return (URL of t) & "\u{1F}" & (title of t)
                end tell
                """
            }

            guard let parts = run(script), parts.count >= 2,
                  parts[0].hasPrefix("http") else { continue }

            return MediaHandoff(source: name,
                                title: parts[1],
                                subtitle: host(of: parts[0]),
                                url: parts[0],
                                position: 0)
        }
        return nil
    }

    private func host(of urlString: String) -> String {
        URL(string: urlString)?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }

    // MARK: - Exécution

    /// Découpe la réponse d'AppleScript.
    ///
    /// Séparateur d'unité ASCII plutôt que virgule : un titre de vidéo en
    /// contient presque toujours une. Même piège que la liste des onglets.
    private func run(_ source: String) -> [String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let value = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return nil }
        return value.components(separatedBy: "\u{1F}")
    }
}
