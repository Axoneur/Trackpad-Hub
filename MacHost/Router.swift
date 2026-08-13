import Foundation
import Combine

/// Reçoit les messages réseau et les dispatche aux contrôleurs du Mac.
///
/// Certaines commandes attendent une réponse (liste des apps, presse-papiers,
/// constantes) : le routeur la renvoie via `reply`.
final class Router: ObservableObject {

    let mouse = MouseController()
    let keyboard = KeyboardController()
    let media = MediaController()
    let shortcuts = ShortcutController()
    let apps = AppController()
    let clipboard = ClipboardController()
    let vitals = VitalsController()
    let windows = WindowController()
    let tabs = TabController()
    let midi = MIDIController()
    let notes = NoteController()
    let handoff = HandoffController()
    private(set) lazy var system = SystemController(keyboard: keyboard)

    /// Canal de réponse vers l'iPhone, branché par `MacHostApp`.
    var reply: ((Message) -> Void)?

    /// Pair dont provient le message en cours de traitement.
    ///
    /// C'est à lui que partent les réponses. Sans ça, une réponse choisit son
    /// transport par ordre de priorité et peut ne jamais arriver.
    var replyPeer: MessageConnection.Peer?

    /// Journal des messages reçus, le plus récent en tête.
    ///
    /// Sert à trancher, quand une commande n'a pas d'effet, entre « l'iPhone
    /// n'a rien envoyé » et « le Mac n'a pas su l'exécuter ». Sans cette
    /// trace, les deux se ressemblent exactement.
    struct Received: Identifiable {
        let id = UUID()
        let date = Date()
        let summary: String
    }

    @Published private(set) var received: [Received] = []

    /// Les déplacements du curseur arrivent par centaines : les journaliser
    /// noierait tout le reste.
    private static let noisyKinds: Set<String> = [
        Message.Kind.trackpad, Message.Kind.scroll, Message.Kind.zoom
    ]

    private func trace(_ message: Message) {
        guard !Self.noisyKinds.contains(message.kind) else { return }

        var parts = [message.kind]
        if let action = message.action { parts.append(action) }
        if let target = message.target { parts.append(target) }
        if let text = message.text, text.count < 24 { parts.append("« \(text) »") }
        if let button = message.button { parts.append("bouton \(button)") }
        if let flags = message.flags, flags != 0 { parts.append("mod \(flags)") }

        let summary = parts.joined(separator: " · ")

        // Trace aussi dans le journal système, et pas seulement dans le
        // panneau de diagnostic.
        //
        // Le panneau exige d'être devant le Mac ; le journal se lit à
        // distance, en dix secondes :
        //
        //     /usr/bin/log stream --predicate 'process == "MacHost"' \
        //         --info | grep "TrackPadHub: reçu"
        //
        // Sans ça, « telle commande ne marche pas » reste indécidable entre
        // « l'iPhone n'envoie rien » et « le Mac ne sait pas l'exécuter » —
        // ce qui a coûté plusieurs allers-retours sur le clic.
        Trace.received(summary)

        let entry = Received(summary: summary)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.received.insert(entry, at: 0)
            if self.received.count > 20 { self.received.removeLast() }
        }
    }

    func clearReceived() {
        received.removeAll()
    }

    private let encoder = JSONEncoder()

    init() {
        // Une copie faite sur le Mac remonte automatiquement vers l'iPhone.
        clipboard.onChange = { [weak self] text in
            self?.reply?(.clipboardData(text))
        }
        // Un changement de média part tout seul vers l'iPhone : c'est le
        // cœur de la fonctionnalité, la proposition doit arriver sans qu'on
        // la demande.
        handoff.onChange = { [weak self] media in
            guard let self else { return }
            self.reply?(.handoffData(json: self.encode(media) ?? ""))
        }
    }

    func handle(_ message: Message) {
        trace(message)

        switch message.kind {

        // MARK: Pointeur
        case Message.Kind.trackpad:
            mouse.move(dx: message.dx ?? 0, dy: message.dy ?? 0)
        case Message.Kind.click:
            mouse.click(button: message.button ?? 0, down: message.down ?? false)
        case Message.Kind.scroll:
            mouse.scroll(dx: message.dx ?? 0,
                         dy: message.dy ?? 0,
                         phase: message.phase ?? .changed)
        case Message.Kind.zoom:
            mouse.zoom(magnification: message.dx ?? 0,
                       phase: message.phase ?? .changed)

        // MARK: Clavier
        case Message.Kind.text:
            keyboard.type(text: message.text ?? "")
        case Message.Kind.character:
            guard let character = message.text?.first else { break }
            keyboard.send(character: character, flags: message.flags ?? 0)
        case Message.Kind.keyHold:
            guard let character = message.text?.first else { break }
            keyboard.hold(character: character, down: message.down ?? false)
        case Message.Kind.specialKey:
            guard let name = message.name, let key = SpecialKey(rawValue: name) else { break }
            keyboard.send(special: key, flags: message.flags ?? 0)

        // MARK: Média et raccourcis
        case Message.Kind.media:
            media.handle(command: message.command ?? "")
        case Message.Kind.shortcut:
            shortcuts.handle(action: message.action ?? "",
                             target: message.target,
                             name: message.name)

        // MARK: Système
        case Message.Kind.system:
            system.handle(action: message.action ?? "")
        case Message.Kind.present:
            system.handle(presentation: message.action ?? "")
        case Message.Kind.gesture:
            system.handle(gesture: message.action ?? "")

        // MARK: Fenêtres
        case Message.Kind.window:
            windows.handle(placement: message.action ?? "")

        // MARK: Reprise de lecture
        case Message.Kind.handoffRequest:
            handoff.refresh()
            reply?(.handoffData(json: encode(handoff.current) ?? ""))

        // MARK: Notes rapides
        case Message.Kind.note:
            notes.receive(message.text ?? "")

        // MARK: MIDI
        case Message.Kind.midi:
            let channel = message.button ?? 0
            let number = Int(message.keycode ?? 0)
            let value = message.flags ?? 0
            if message.action == "note" {
                midi.note(channel: channel, note: number,
                          velocity: value, on: message.down ?? true)
            } else {
                midi.controlChange(channel: channel, controller: number, value: value)
            }

        // MARK: Onglets du navigateur
        case Message.Kind.tabsRequest:
            tabs.tabs { [weak self] list in
                guard let self, let json = self.encode(list) else { return }
                self.reply?(.tabsList(json: json))
            }
        case Message.Kind.tabAction:
            tabs.handle(action: message.action ?? "",
                        index: message.target.flatMap(Int.init))

        // MARK: Applications
        case Message.Kind.appsRequest:
            if let json = encode(apps.runningApps()) {
                reply?(.appsList(json: json))
            }
        case Message.Kind.installedRequest:
            if let json = encode(apps.installedApps()) {
                reply?(.installedList(json: json))
            }
        case Message.Kind.appAction:
            guard let bundleID = message.target,
                  let raw = message.action,
                  let action = AppAction(rawValue: raw) else { break }
            apps.perform(action, on: bundleID)
        case Message.Kind.appLaunch:
            guard let bundleID = message.target else { break }
            apps.launch(bundleID: bundleID)

        // MARK: Presse-papiers
        case Message.Kind.clipboardPush:
            clipboard.set(message.text ?? "")
        case Message.Kind.clipboardRequest:
            reply?(.clipboardData(clipboard.currentText() ?? ""))
        case Message.Kind.clipboardHistoryRequest:
            if let json = encode(clipboard.history) {
                reply?(.clipboardHistory(json: json))
            }
        case Message.Kind.clipboardRestore:
            guard let text = message.text else { break }
            clipboard.restore(text)
            reply?(.clipboardData(text))
        case Message.Kind.clipboardClearHistory:
            clipboard.clearHistory()
            if let json = encode(clipboard.history) {
                reply?(.clipboardHistory(json: json))
            }

        // MARK: Constantes
        case Message.Kind.vitalsRequest:
            if let json = encode(vitals.snapshot()) {
                reply?(.vitalsData(json: json))
            }

        default:
            break
        }
    }

    /// État courant de la reprise de lecture, prêt à être envoyé.
    func encodedHandoff() -> String {
        encode(handoff.current) ?? ""
    }

    private func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
