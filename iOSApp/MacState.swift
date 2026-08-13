import SwiftUI
import Combine
import WidgetKit

/// Miroir, côté iPhone, de ce que le Mac renvoie : applications ouvertes,
/// presse-papiers, constantes système.
@MainActor
final class MacState: ObservableObject {

    @Published private(set) var apps: [RunningApp] = []
    @Published private(set) var installedApps: [InstalledApp] = []
    @Published private(set) var vitals: MacVitals?
    @Published private(set) var clipboard: String = ""
    /// Onglets du navigateur au premier plan sur le Mac.
    @Published private(set) var tabs: [BrowserTab] = []
    /// Historique du presse-papiers du Mac, le plus récent en tête.
    @Published private(set) var clipboardHistory: [ClipboardEntry] = []
    /// Média en cours sur le Mac, proposé à la reprise.
    @Published private(set) var handoff: MediaHandoff?
    @Published private(set) var lastUpdate: Date?

    private let decoder = JSONDecoder()

    /// Traite une réponse venue du Mac.
    func handle(_ message: Message) {
        switch message.kind {
        case Message.Kind.appsList:
            guard let data = message.text?.data(using: .utf8),
                  let list = try? decoder.decode([RunningApp].self, from: data) else { return }
            apps = list
            lastUpdate = Date()

        case Message.Kind.installedList:
            guard let data = message.text?.data(using: .utf8),
                  let list = try? decoder.decode([InstalledApp].self, from: data) else { return }
            installedApps = list

        case Message.Kind.handoffData:
            guard let text = message.text, !text.isEmpty,
                  let data = text.data(using: .utf8),
                  let media = try? decoder.decode(MediaHandoff.self, from: data) else {
                handoff = nil
                return
            }
            handoff = media

        case Message.Kind.clipboardHistory:
            guard let data = message.text?.data(using: .utf8),
                  let list = try? decoder.decode([ClipboardEntry].self, from: data) else { return }
            clipboardHistory = list

        case Message.Kind.tabsList:
            guard let data = message.text?.data(using: .utf8),
                  let list = try? decoder.decode([BrowserTab].self, from: data) else { return }
            tabs = list

        case Message.Kind.vitalsData:
            guard let data = message.text?.data(using: .utf8),
                  let snapshot = try? decoder.decode(MacVitals.self, from: data) else { return }
            vitals = snapshot
            lastUpdate = Date()
            // Les widgets n'ont pas accès au réseau : ils lisent ce dépôt.
            SharedStore.save(vitals: snapshot)
            WidgetCenter.shared.reloadAllTimelines()

        case Message.Kind.clipboardData:
            clipboard = message.text ?? ""

        default:
            break
        }
    }

    func reset() {
        apps = []
        vitals = nil
        clipboard = ""
        lastUpdate = nil
    }
}
