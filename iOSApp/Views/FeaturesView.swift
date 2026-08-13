import SwiftUI
import CoreMotion
import AVFoundation

/// Inventaire de toutes les fonctionnalités, avec leur état réel et l'endroit
/// exact où les trouver.
///
/// Plusieurs d'entre elles vivent hors de l'app — widgets sur l'écran
/// d'accueil, raccourcis dans Siri, clavier dans les réglages d'iOS — ou ne
/// s'affichent que dans certaines conditions. Sans cet écran, rien n'indique
/// qu'elles existent.
struct FeaturesView: View {
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var mac: MacState

    @AppStorage(MessageConnection.wakeMacAddressKey) private var wakeMacAddress = ""

    private var isPaired: Bool { connection.pairingState == .paired }

    enum State {
        case active(String)
        case conditional(String)
        case toEnable(String)

        var icon: String {
            switch self {
            case .active:      return "checkmark.circle.fill"
            case .conditional: return "clock.badge.questionmark"
            case .toEnable:    return "exclamationmark.circle"
            }
        }

        var tint: Color {
            switch self {
            case .active:      return .green
            case .conditional: return .secondary
            case .toEnable:    return .orange
            }
        }

        var detail: String {
            switch self {
            case .active(let text), .conditional(let text), .toEnable(let text): return text
            }
        }
    }

    struct Feature: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        /// Où la trouver, en clair.
        let location: String
        let state: State
    }

    var body: some View {
        List {
            Section {
                ForEach(inApp) { feature in row(feature) }
            } header: {
                Text("Dans l'app")
            }

            Section {
                ForEach(outsideApp) { feature in row(feature) }
            } header: {
                Text("Hors de l'app")
            } footer: {
                Text("Ces fonctionnalités s'utilisent depuis l'iPhone ou le Mac, pas depuis cet écran.")
            }

            Section {
                ForEach(onMac) { feature in row(feature) }
            } header: {
                Text("Sur le Mac")
            }
        }
        .navigationTitle("Fonctionnalités")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ feature: Feature) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feature.icon)
                .frame(width: 26)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.name).font(.subheadline.weight(.medium))
                Text(feature.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(feature.state.detail, systemImage: feature.state.icon)
                    .font(.caption2)
                    .foregroundStyle(feature.state.tint)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Inventaire

    private var inApp: [Feature] {
        [
            Feature(name: "Trackpad multi-touch",
                    icon: "rectangle.and.hand.point.up.left",
                    location: "Onglet Trackpad",
                    state: .active("1 doigt curseur · 2 défilement et zoom · 3 glisser")),

            Feature(name: "Souris gyroscopique",
                    icon: "dot.circle.and.hand.point.up.left.fill",
                    location: "Onglet Trackpad, icône de main",
                    state: CMMotionManager().isDeviceMotionAvailable
                        ? .active("Capteurs disponibles")
                        : .toEnable("Capteurs indisponibles sur cet appareil")),

            Feature(name: "Clavier et raccourcis",
                    icon: "keyboard",
                    location: "Onglet Clavier",
                    state: .active("Lettres, modificateurs, F1 à F12, navigation")),

            Feature(name: "Dictée vocale",
                    icon: "mic.fill",
                    location: "Onglet Clavier, bouton Dictée",
                    state: microphoneState),

            Feature(name: "Presse-papiers partagé",
                    icon: "doc.on.clipboard",
                    location: "Onglet Clavier",
                    state: .active("Bidirectionnel, texte seulement")),

            Feature(name: "Média, volume, luminosité",
                    icon: "playpause.fill",
                    location: "Onglet Média",
                    state: .active("Curseur de volume précis inclus")),

            Feature(name: "Mode présentation",
                    icon: "rectangle.on.rectangle",
                    location: "Onglet Média, bas de l'écran",
                    state: .active("Minuteur vibrant à chaque minute")),

            Feature(name: "Applications du Mac",
                    icon: "square.stack",
                    location: "Onglet Mac, puis « Tout voir »",
                    state: mac.installedApps.isEmpty
                        ? .conditional("Liste chargée à la connexion")
                        : .active("\(mac.installedApps.count) apps détectées")),

            Feature(name: "Transfert de fichiers",
                    icon: "paperplane.fill",
                    location: "Onglet Mac, « Envoyer un fichier »",
                    state: .active("Photos, documents, presse-papiers")),

            Feature(name: "Contrôles système",
                    icon: "power",
                    location: "Onglet Mac, section Alimentation",
                    state: .active("Veille, verrouillage, redémarrage, extinction")),

            Feature(name: "Raccourcis personnalisés",
                    icon: "bolt.fill",
                    location: "Onglet Mac, « Raccourcis »",
                    state: .active("Apps, liens, raccourcis du Mac")),

            Feature(name: "Constantes du Mac",
                    icon: "chart.bar.fill",
                    location: "Onglet Mac, en haut",
                    state: mac.vitals == nil
                        ? .conditional("Relevées une fois connecté")
                        : .active("Batterie, processeur, mémoire, disque"))
        ]
    }

    private var outsideApp: [Feature] {
        [
            Feature(name: "Widgets d'écran d'accueil",
                    icon: "square.grid.2x2",
                    location: "Écran d'accueil : appui long → Modifier → Ajouter un widget → TrackPad Hub",
                    state: .toEnable("À ajouter vous-même, deux widgets disponibles")),

            Feature(name: "Raccourcis Siri",
                    icon: "mic.circle",
                    location: "App Raccourcis, ou « Dis Siri, verrouille mon Mac »",
                    state: .toEnable("7 actions proposées automatiquement")),

            Feature(name: "Clavier système",
                    icon: "globe",
                    location: "Réglages iOS → Général → Clavier → Claviers",
                    state: .toEnable("Ajouter le clavier, puis autoriser l'accès complet")),

            Feature(name: "Réveil du Mac à distance",
                    icon: "bolt.horizontal",
                    location: "Onglet Mac, apparaît seulement quand le Mac est injoignable",
                    state: wakeMacAddress.isEmpty
                        ? .conditional("Disponible après un premier appairage")
                        : (isPaired
                           ? .conditional("Masqué : le Mac répond déjà")
                           : .active("Prêt, le Mac est injoignable")))
        ]
    }

    private var onMac: [Feature] {
        [
            Feature(name: "Icône dans la barre des menus",
                    icon: "menubar.rectangle",
                    location: "En haut à droite de l'écran du Mac",
                    state: .active("État, code d'appairage, appareils autorisés")),

            Feature(name: "Lancement au démarrage",
                    icon: "power.circle",
                    location: "Menu de la barre des menus du Mac",
                    state: .toEnable("À cocher une fois")),

            Feature(name: "Diagnostic du clavier",
                    icon: "stethoscope",
                    location: "Fenêtre de l'app Mac, bouton en bas",
                    state: .active("Montre ce que le Mac reçoit réellement")),

            Feature(name: "Disposition du clavier",
                    icon: "keyboard.badge.ellipsis",
                    location: "Fenêtre de l'app Mac",
                    state: .active("Suit le clavier actif, ou se fige au choix"))
        ]
    }

    private var microphoneState: State {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:  return .active("Micro autorisé, reconnaissance en français")
        case .denied:   return .toEnable("Micro refusé, à réactiver dans les Réglages iOS")
        default:        return .conditional("Autorisation demandée à la première utilisation")
        }
    }
}
