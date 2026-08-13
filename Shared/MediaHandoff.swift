import Foundation

/// Ce que le Mac propose de reprendre sur l'iPhone.
struct MediaHandoff: Codable, Equatable {
    /// D'où ça vient : « Spotify », « Musique », « Safari »…
    let source: String
    let title: String
    /// Artiste, ou nom du site.
    let subtitle: String
    /// Lien à ouvrir sur l'iPhone.
    let url: String
    /// Position en secondes, 0 si inconnue.
    let position: Int
    /// Durée totale en secondes, 0 si inconnue.
    var duration: Int = 0
    /// Vrai quand un média est **réellement en cours de lecture** — vidéo,
    /// film, y compris en Picture in Picture. Faux quand on ne propose que la
    /// page ouverte.
    var isPlaying: Bool = false
    /// Vrai quand Safari refuse d'exécuter du JavaScript : on ne peut alors
    /// détecter que la page, pas ce qui y est lu.
    var needsJavaScriptPermission: Bool = false

    /// Lien enrichi de la position quand le site sait la reprendre.
    ///
    /// YouTube accepte `&t=` en secondes ; c'est le seul cas assez répandu
    /// pour valoir un traitement à part. Ailleurs on ouvre le lien tel quel
    /// plutôt que de fabriquer un paramètre que le site ignorerait.
    var resumeURL: String {
        guard position > 5, url.contains("youtube.com") || url.contains("youtu.be"),
              !url.contains("t=") else { return url }
        return url + (url.contains("?") ? "&" : "?") + "t=\(position)"
    }

    /// Avancement lisible, « 3 min 12 s / 1 h 42 ».
    var progress: String? {
        guard let elapsed else { return nil }
        guard duration > 0 else { return elapsed }
        return "\(elapsed) / \(Self.format(duration))"
    }

    static func format(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours) h \(minutes)" }
        return "\(minutes) min"
    }

    /// Position lisible, « 3 min 12 s ».
    var elapsed: String? {
        guard position > 0 else { return nil }
        let minutes = position / 60
        let seconds = position % 60
        return minutes > 0 ? "\(minutes) min \(seconds) s" : "\(seconds) s"
    }
}
