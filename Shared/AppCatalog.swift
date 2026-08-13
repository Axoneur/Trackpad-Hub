import Foundation

/// Catalogue d'applications Mac courantes, rangées par usage.
///
/// Sert uniquement à **proposer** et à ranger : rien n'est affiché comme
/// disponible sans avoir été confirmé par le Mac. Un bouton qui ne lance rien
/// est pire que pas de bouton.
enum AppCatalog {

    struct Entry: Identifiable, Hashable {
        let bundleID: String
        let name: String
        let category: Category
        /// Symbole de repli quand le Mac n'a pas encore envoyé l'icône.
        let icon: String

        var id: String { bundleID }
    }

    enum Category: String, CaseIterable, Identifiable {
        case apple = "Apple"
        case navigateurs = "Navigateurs"
        case communication = "Communication"
        case travail = "Travail"
        case creation = "Création"
        case developpement = "Développement"
        case media = "Musique et vidéo"
        case jeux = "Jeux"
        case utilitaires = "Utilitaires"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .apple:         return "apple.logo"
            case .navigateurs:   return "globe"
            case .communication: return "bubble.left.and.bubble.right"
            case .travail:       return "briefcase"
            case .creation:      return "paintbrush"
            case .developpement: return "chevron.left.forwardslash.chevron.right"
            case .media:         return "play.rectangle"
            case .jeux:          return "gamecontroller"
            case .utilitaires:   return "wrench.and.screwdriver"
            }
        }
    }

    static let entries: [Entry] = [
        // Apple
        Entry(bundleID: "com.apple.Safari", name: "Safari", category: .apple, icon: "safari"),
        Entry(bundleID: "com.apple.mail", name: "Mail", category: .apple, icon: "envelope"),
        Entry(bundleID: "com.apple.MobileSMS", name: "Messages", category: .apple, icon: "message"),
        Entry(bundleID: "com.apple.FaceTime", name: "FaceTime", category: .apple, icon: "video"),
        Entry(bundleID: "com.apple.Photos", name: "Photos", category: .apple, icon: "photo"),
        Entry(bundleID: "com.apple.iCal", name: "Calendrier", category: .apple, icon: "calendar"),
        Entry(bundleID: "com.apple.Notes", name: "Notes", category: .apple, icon: "note.text"),
        Entry(bundleID: "com.apple.reminders", name: "Rappels", category: .apple, icon: "checklist"),
        Entry(bundleID: "com.apple.AddressBook", name: "Contacts", category: .apple, icon: "person.crop.circle"),
        Entry(bundleID: "com.apple.Maps", name: "Plans", category: .apple, icon: "map"),
        Entry(bundleID: "com.apple.finder", name: "Finder", category: .apple, icon: "folder"),
        Entry(bundleID: "com.apple.systempreferences", name: "Réglages Système", category: .apple, icon: "gearshape"),
        Entry(bundleID: "com.apple.Preview", name: "Aperçu", category: .apple, icon: "doc.text.image"),
        Entry(bundleID: "com.apple.iWork.Pages", name: "Pages", category: .apple, icon: "doc.richtext"),
        Entry(bundleID: "com.apple.iWork.Numbers", name: "Numbers", category: .apple, icon: "tablecells"),
        Entry(bundleID: "com.apple.iWork.Keynote", name: "Keynote", category: .apple, icon: "rectangle.on.rectangle"),
        Entry(bundleID: "com.apple.freeform", name: "Freeform", category: .apple, icon: "scribble"),
        Entry(bundleID: "com.apple.shortcuts", name: "Raccourcis", category: .apple, icon: "bolt"),
        Entry(bundleID: "com.apple.AppStore", name: "App Store", category: .apple, icon: "bag"),

        // Navigateurs
        Entry(bundleID: "com.google.Chrome", name: "Chrome", category: .navigateurs, icon: "globe"),
        Entry(bundleID: "org.mozilla.firefox", name: "Firefox", category: .navigateurs, icon: "globe"),
        Entry(bundleID: "com.microsoft.edgemac", name: "Edge", category: .navigateurs, icon: "globe"),
        Entry(bundleID: "com.brave.Browser", name: "Brave", category: .navigateurs, icon: "globe"),
        Entry(bundleID: "company.thebrowser.Browser", name: "Arc", category: .navigateurs, icon: "globe"),
        Entry(bundleID: "com.operasoftware.Opera", name: "Opera", category: .navigateurs, icon: "globe"),

        // Communication
        Entry(bundleID: "com.tinyspeck.slackmacgap", name: "Slack", category: .communication, icon: "number"),
        Entry(bundleID: "com.hnc.Discord", name: "Discord", category: .communication, icon: "bubble.left"),
        Entry(bundleID: "ru.keepcoder.Telegram", name: "Telegram", category: .communication, icon: "paperplane"),
        Entry(bundleID: "net.whatsapp.WhatsApp", name: "WhatsApp", category: .communication, icon: "phone"),
        Entry(bundleID: "us.zoom.xos", name: "Zoom", category: .communication, icon: "video"),
        Entry(bundleID: "com.microsoft.teams2", name: "Teams", category: .communication, icon: "person.2"),
        Entry(bundleID: "com.readdle.smartemail-Mac", name: "Spark", category: .communication, icon: "envelope"),

        // Travail
        Entry(bundleID: "com.microsoft.Word", name: "Word", category: .travail, icon: "doc.text"),
        Entry(bundleID: "com.microsoft.Excel", name: "Excel", category: .travail, icon: "tablecells"),
        Entry(bundleID: "com.microsoft.Powerpoint", name: "PowerPoint", category: .travail, icon: "rectangle.on.rectangle"),
        Entry(bundleID: "com.microsoft.Outlook", name: "Outlook", category: .travail, icon: "envelope"),
        Entry(bundleID: "notion.id", name: "Notion", category: .travail, icon: "doc.plaintext"),
        Entry(bundleID: "md.obsidian", name: "Obsidian", category: .travail, icon: "doc.plaintext"),
        Entry(bundleID: "com.culturedcode.ThingsMac", name: "Things", category: .travail, icon: "checklist"),
        Entry(bundleID: "com.todoist.mac.Todoist", name: "Todoist", category: .travail, icon: "checklist"),

        // Création
        Entry(bundleID: "com.figma.Desktop", name: "Figma", category: .creation, icon: "square.on.circle"),
        Entry(bundleID: "com.adobe.Photoshop", name: "Photoshop", category: .creation, icon: "paintbrush"),
        Entry(bundleID: "com.adobe.illustrator", name: "Illustrator", category: .creation, icon: "pencil.and.outline"),
        Entry(bundleID: "com.adobe.PremierePro", name: "Premiere Pro", category: .creation, icon: "film"),
        Entry(bundleID: "com.bohemiancoding.sketch3", name: "Sketch", category: .creation, icon: "pencil"),
        Entry(bundleID: "com.blender.blender", name: "Blender", category: .creation, icon: "cube"),
        Entry(bundleID: "com.apple.FinalCut", name: "Final Cut Pro", category: .creation, icon: "film"),
        Entry(bundleID: "com.apple.logic10", name: "Logic Pro", category: .creation, icon: "waveform"),

        // Développement
        Entry(bundleID: "com.apple.dt.Xcode", name: "Xcode", category: .developpement, icon: "hammer"),
        Entry(bundleID: "com.microsoft.VSCode", name: "VS Code", category: .developpement, icon: "chevron.left.forwardslash.chevron.right"),
        Entry(bundleID: "com.apple.Terminal", name: "Terminal", category: .developpement, icon: "terminal"),
        Entry(bundleID: "com.googlecode.iterm2", name: "iTerm", category: .developpement, icon: "terminal"),
        Entry(bundleID: "com.jetbrains.intellij", name: "IntelliJ", category: .developpement, icon: "hammer"),
        Entry(bundleID: "com.postmanlabs.mac", name: "Postman", category: .developpement, icon: "arrow.up.arrow.down"),
        Entry(bundleID: "com.docker.docker", name: "Docker", category: .developpement, icon: "shippingbox"),
        Entry(bundleID: "com.github.GitHubClient", name: "GitHub Desktop", category: .developpement, icon: "chevron.left.forwardslash.chevron.right"),

        // Musique et vidéo
        Entry(bundleID: "com.apple.Music", name: "Musique", category: .media, icon: "music.note"),
        Entry(bundleID: "com.apple.TV", name: "Apple TV", category: .media, icon: "tv"),
        Entry(bundleID: "com.spotify.client", name: "Spotify", category: .media, icon: "music.note"),
        Entry(bundleID: "org.videolan.vlc", name: "VLC", category: .media, icon: "play.rectangle"),
        Entry(bundleID: "com.colliderli.iina", name: "IINA", category: .media, icon: "play.rectangle"),
        Entry(bundleID: "tv.plex.desktop", name: "Plex", category: .media, icon: "play.tv"),
        Entry(bundleID: "com.apple.podcasts", name: "Podcasts", category: .media, icon: "mic"),

        // Jeux
        Entry(bundleID: "com.valvesoftware.steam", name: "Steam", category: .jeux, icon: "gamecontroller"),
        Entry(bundleID: "com.epicgames.EpicGamesLauncher", name: "Epic Games", category: .jeux, icon: "gamecontroller"),
        Entry(bundleID: "com.riotgames.RiotClient", name: "Riot Client", category: .jeux, icon: "gamecontroller"),

        // Utilitaires
        Entry(bundleID: "com.apple.ActivityMonitor", name: "Moniteur d'activité", category: .utilitaires, icon: "chart.line.uptrend.xyaxis"),
        Entry(bundleID: "com.apple.DiskUtility", name: "Utilitaire de disque", category: .utilitaires, icon: "internaldrive"),
        Entry(bundleID: "com.apple.ScreenSharing", name: "Partage d'écran", category: .utilitaires, icon: "display.2"),
        Entry(bundleID: "com.raycast.macos", name: "Raycast", category: .utilitaires, icon: "magnifyingglass"),
        Entry(bundleID: "com.runningwithcrayons.Alfred", name: "Alfred", category: .utilitaires, icon: "magnifyingglass"),
        Entry(bundleID: "com.if.Amphetamine", name: "Amphetamine", category: .utilitaires, icon: "cup.and.saucer"),
        Entry(bundleID: "com.macpaw.CleanMyMac", name: "CleanMyMac", category: .utilitaires, icon: "sparkles"),
        Entry(bundleID: "com.1password.1password", name: "1Password", category: .utilitaires, icon: "key")
    ]

    /// Entrées du catalogue effectivement présentes sur le Mac.
    ///
    /// Le croisement se fait sur le bundle ID, seul identifiant fiable : deux
    /// apps peuvent porter le même nom, et un nom peut être traduit.
    static func available(among installed: [InstalledApp]) -> [Entry] {
        let present = Set(installed.map(\.bundleID))
        return entries.filter { present.contains($0.bundleID) }
    }

    /// Entrées du catalogue absentes du Mac, pour information.
    static func missing(among installed: [InstalledApp]) -> [Entry] {
        let present = Set(installed.map(\.bundleID))
        return entries.filter { !present.contains($0.bundleID) }
    }

    /// Catégorie d'une app installée, si le catalogue la connaît.
    static func category(of bundleID: String) -> Category? {
        entries.first { $0.bundleID == bundleID }?.category
    }
}
