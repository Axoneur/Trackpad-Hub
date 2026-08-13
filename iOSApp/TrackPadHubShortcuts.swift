import AppIntents

/// Déclaration des raccourcis proposés automatiquement par Siri, Spotlight
/// et l'app Raccourcis.
///
/// Uniquement dans l'app : un `AppShortcutsProvider` doit être unique pour
/// tout le bundle. Les intentions elles-mêmes vivent dans `SharediOS`, pour
/// être partagées avec les widgets.
struct TrackPadHubShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Chaque formulation doit contenir le nom de l'app, sinon Siri ne
        // saurait pas à quelle app adresser la demande.
        AppShortcut(intent: LockMacIntent(),
                    phrases: ["Verrouille mon Mac avec \(.applicationName)",
                              "Verrouiller le Mac dans \(.applicationName)"],
                    shortTitle: "Verrouiller le Mac",
                    systemImageName: "lock.fill")

        AppShortcut(intent: SleepMacIntent(),
                    phrases: ["Endors mon Mac avec \(.applicationName)",
                              "Mettre le Mac en veille dans \(.applicationName)"],
                    shortTitle: "Veille du Mac",
                    systemImageName: "moon.fill")

        AppShortcut(intent: WakeMacIntent(),
                    phrases: ["Réveille mon Mac avec \(.applicationName)",
                              "Réveiller le Mac dans \(.applicationName)"],
                    shortTitle: "Réveiller le Mac",
                    systemImageName: "bolt.horizontal")

        AppShortcut(intent: PlayPauseMacIntent(),
                    phrases: ["Lecture pause sur le Mac avec \(.applicationName)"],
                    shortTitle: "Lecture / pause",
                    systemImageName: "playpause.fill")

        AppShortcut(intent: NextTrackMacIntent(),
                    phrases: ["Piste suivante sur le Mac avec \(.applicationName)"],
                    shortTitle: "Piste suivante",
                    systemImageName: "forward.fill")

        AppShortcut(intent: SendClipboardIntent(),
                    phrases: ["Envoie mon presse-papiers au Mac avec \(.applicationName)"],
                    shortTitle: "Presse-papiers vers le Mac",
                    systemImageName: "doc.on.clipboard")

        AppShortcut(intent: ShowDesktopIntent(),
                    phrases: ["Affiche le bureau du Mac avec \(.applicationName)"],
                    shortTitle: "Afficher le bureau",
                    systemImageName: "menubar.dock.rectangle")
    }
}
