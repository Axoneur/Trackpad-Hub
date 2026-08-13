import Foundation
import AppKit
import CoreGraphics
import Carbon.HIToolbox

/// Envoie des frappes clavier au système.
/// Nécessite l'autorisation « Accessibilité ».
///
/// Les caractères sont résolus contre la disposition clavier du Mac
/// (voir `KeyboardLayout`), ce qui rend les raccourcis corrects quelle que
/// soit la disposition — AZERTY comprise.
final class KeyboardController: ObservableObject {

    private let source = CGEventSource(stateID: .hidSystemState)

    /// Trace d'une frappe, pour diagnostiquer les raccourcis qui n'aboutissent
    /// pas là où on les attend.
    struct Trace: Identifiable {
        let id = UUID()
        let date = Date()
        /// Ce que l'iPhone a demandé.
        let requested: String
        /// Touche physique réellement postée.
        let keycode: UInt16
        /// Modificateurs appliqués.
        let modifiers: String
        /// Disposition utilisée pour la traduction.
        let layout: String
        /// Caractère que cette touche produit dans cette disposition.
        let produces: String

        var summary: String {
            "\(modifiers)\(requested)  →  touche \(keycode) (« \(produces) ») · \(layout)"
        }
    }

    /// Les dernières frappes, la plus récente en tête.
    @Published private(set) var traces: [Trace] = []

    private func record(requested: String, keycode: UInt16, flags: Int,
                        layout: KeyboardLayout?) {
        var symbols = ""
        if flags & ModFlag.control != 0 { symbols += "⌃" }
        if flags & ModFlag.option  != 0 { symbols += "⌥" }
        if flags & ModFlag.shift   != 0 { symbols += "⇧" }
        if flags & ModFlag.command != 0 { symbols += "⌘" }

        // Ce que la disposition produirait vraiment pour ce keycode : c'est la
        // valeur qui compte, celle que macOS lira à la réception.
        let produced = layout?.character(forKeycode: keycode, flags: flags).map(String.init) ?? "?"

        let trace = Trace(requested: requested,
                          keycode: keycode,
                          modifiers: symbols,
                          layout: layout?.name ?? "inconnue",
                          produces: produced)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.traces.insert(trace, at: 0)
            if self.traces.count > 12 { self.traces.removeLast() }
        }
    }

    func clearTraces() {
        traces.removeAll()
    }

    /// Clé UserDefaults : identifiant de disposition forcée, vide = suivre
    /// la disposition active du Mac.
    static let forcedLayoutKey = "forcedKeyboardLayoutID"

    // MARK: - Disposition

    /// Instantané des dispositions, préparé sur la file principale.
    ///
    /// **Les API Carbon de source de saisie exigent la file principale.**
    /// `TISCopyCurrentKeyboardLayoutInputSource`, `TISCreateInputSourceList`
    /// et `TISGetInputSourceProperty` passent tous par
    /// `islGetInputSourceListWithAdditions`, qui appelle `dispatch_assert_queue`.
    /// Appelées depuis `keyQueue`, elles ne renvoient pas d'erreur : elles
    /// tuent le processus sur `EXC_BREAKPOINT`. Mesuré le 12 août 2026, deux
    /// rapports identiques dans `~/Library/Logs/DiagnosticReports/`, pile
    /// `_dispatch_assert_queue_fail → TSMGetInputSourceProperty →
    /// KeyboardLayout.currentSourceID → postTap`.
    ///
    /// Même famille que le piège `NSAppleScript` : une API système qui exige
    /// la file principale, appelée depuis une file d'arrière-plan.
    ///
    /// D'où ce découpage : Carbon n'est plus jamais interrogé pendant une
    /// frappe. Les tables sont construites à l'avance sur la file principale,
    /// et le chemin critique ne fait qu'une lecture sous verrou. C'est aussi
    /// **plus rapide** qu'avant, où chaque frappe lisait l'identifiant de la
    /// disposition active.
    private let snapshotLock = NSLock()
    private var activeLayout: KeyboardLayout?
    private var forcedLayout: KeyboardLayout?

    init() {
        refreshLayouts()

        // Rafraîchir quand l'utilisateur change de disposition en cours de
        // route (menu Saisie, ⌃Espace). Sans ça, l'instantané resterait figé
        // sur la disposition du démarrage et les raccourcis repartiraient
        // ailleurs — exactement le bug que ce projet a déjà payé cher.
        DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshLayouts()
        }
    }

    /// Reconstruit les tables. **Toujours sur la file principale**, au besoin
    /// en s'y déplaçant.
    ///
    /// Coûteux — 512 appels à `UCKeyTranslate` par disposition — mais appelé
    /// seulement au démarrage, au changement de disposition, et quand
    /// l'utilisateur fige une disposition dans les réglages. Jamais pendant
    /// une frappe.
    private func refreshLayouts() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.refreshLayouts() }
            return
        }

        let active = KeyboardLayout.current()
        let forcedID = UserDefaults.standard.string(forKey: Self.forcedLayoutKey) ?? ""
        let forced = forcedID.isEmpty ? nil : KeyboardLayout.layout(withID: forcedID)

        snapshotLock.lock()
        activeLayout = active
        forcedLayout = forced
        snapshotLock.unlock()
    }

    /// Disposition utilisée pour traduire un caractère en touche physique.
    ///
    /// - `respectForced: false` impose la disposition **active** du Mac.
    ///   Indispensable pour les raccourcis : on envoie un keycode, et c'est
    ///   macOS qui le réinterprète avec sa disposition courante. Résoudre
    ///   « a » avec une disposition française (keycode 12) pendant que le Mac
    ///   lit en QWERTY donne « q » — et ⌘A devient ⌘Q, qui quitte l'app.
    ///
    /// - `respectForced: true` autorise la disposition choisie dans les
    ///   réglages, utile seulement pour la saisie de texte simple.
    ///
    /// Appelable depuis n'importe quelle file : simple lecture d'instantané.
    private func layout(respectForced: Bool) -> KeyboardLayout? {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        // Repli sur la disposition active si la disposition figée a disparu
        // du système depuis son choix.
        return respectForced ? (forcedLayout ?? activeLayout) : activeLayout
    }

    /// Disposition réellement en vigueur, pour affichage dans l'interface.
    var activeLayoutName: String {
        layout(respectForced: true)?.name ?? "inconnue"
    }

    /// Force une disposition (ou nil pour suivre celle du Mac).
    func setForcedLayout(id: String?) {
        UserDefaults.standard.set(id ?? "", forKey: Self.forcedLayoutKey)
        refreshLayouts()
    }

    // MARK: - Modificateurs

    private func cgFlags(from raw: Int) -> CGEventFlags {
        var flags = CGEventFlags()
        if raw & ModFlag.command != 0 { flags.insert(.maskCommand) }
        if raw & ModFlag.option  != 0 { flags.insert(.maskAlternate) }
        if raw & ModFlag.control != 0 { flags.insert(.maskControl) }
        if raw & ModFlag.shift   != 0 { flags.insert(.maskShift) }
        return flags
    }

    // MARK: - Envoi

    /// Keycodes des touches modificatrices elles-mêmes.
    private static let modifierKeycodes: [(mask: Int, keycode: UInt16)] = [
        (ModFlag.command, 55),
        (ModFlag.shift,   56),
        (ModFlag.option,  58),
        (ModFlag.control, 59)
    ]

    /// Frappe complète (appui + relâchement) d'une touche physique.
    ///
    /// Les modificateurs sont enfoncés puis relâchés comme de **vraies
    /// touches**, et pas seulement posés en drapeau sur l'événement.
    /// Les raccourcis d'application se contentent du drapeau, mais les
    /// raccourcis **système** — Mission Control, changement de bureau,
    /// affichage du bureau — sont interceptés plus bas par le WindowServer,
    /// qui exige de voir les modificateurs enfoncés.
    /// Pause entre deux événements d'un même raccourci.
    ///
    /// Sans elle, les raccourcis **système** — Mission Control, bureaux,
    /// affichage du bureau — ne se déclenchent pas : le WindowServer, qui les
    /// intercepte avant toute application, fusionne les événements arrivés
    /// dans la même milliseconde et ne voit jamais le modificateur enfoncé au
    /// moment de la touche. Les raccourcis d'application, eux, tolèrent
    /// l'absence de pause — d'où un symptôme trompeur où seule une partie
    /// des raccourcis échoue.
    private static let eventGap: useconds_t = 12_000   // 12 ms

    /// File dédiée aux frappes.
    ///
    /// Les pauses entre événements ne doivent pas geler l'interface, et une
    /// file série garantit qu'une frappe n'est jamais entrelacée avec une
    /// autre — deux raccourcis mélangés produiraient une combinaison qui n'a
    /// été demandée par personne.
    private let keyQueue = DispatchQueue(label: "com.trackpadhub.keyboard")

    func tap(keycode: UInt16, flags: Int = 0) {
        keyQueue.async { [weak self] in
            self?.postTap(keycode: keycode, flags: flags)
        }
    }

    private func postTap(keycode: UInt16, flags: Int) {
        // Tracé même pour les touches nommées et les gestes : c'est le seul
        // moyen de vérifier que le Mac a bien tenté la frappe. On passe la
        // disposition pour que la trace nomme la touche — sans elle, une
        // flèche s'affichait comme « inconnue » avec une alerte rouge, ce qui
        // laissait croire à un échec alors que la frappe partait bien.
        record(requested: SpecialKey.name(forKeycode: keycode) ?? "touche \(keycode)",
               keycode: keycode, flags: flags,
               layout: layout(respectForced: false))

        let modifiers = Self.modifierKeycodes.filter { flags & $0.mask != 0 }

        // Enfoncement des modificateurs, en accumulant les drapeaux au fur
        // et à mesure : chaque événement doit refléter l'état courant.
        var accumulated = 0
        for modifier in modifiers {
            accumulated |= modifier.mask
            postModifier(keycode: modifier.keycode, flags: accumulated)
            usleep(Self.eventGap)
        }

        post(keycode: keycode, flags: flags, down: true)
        usleep(Self.eventGap)
        post(keycode: keycode, flags: flags, down: false)

        // Relâchement dans l'ordre inverse, en retirant les drapeaux.
        for modifier in modifiers.reversed() {
            usleep(Self.eventGap)
            accumulated &= ~modifier.mask
            postModifier(keycode: modifier.keycode, flags: accumulated)
        }
    }

    /// Une touche modificatrice ne produit pas un `keyDown` mais un
    /// `flagsChanged` : c'est ce type d'événement que le système attend pour
    /// considérer le modificateur comme réellement enfoncé.
    private func postModifier(keycode: UInt16, flags: Int) {
        guard let event = CGEvent(keyboardEventSource: source,
                                  virtualKey: keycode,
                                  keyDown: true) else { return }
        event.type = .flagsChanged
        event.flags = cgFlags(from: flags)
        event.post(tap: .cghidEventTap)
    }

    func post(keycode: UInt16, flags: Int, down: Bool) {
        guard let event = CGEvent(keyboardEventSource: source,
                                  virtualKey: keycode,
                                  keyDown: down) else { return }
        event.flags = cgFlags(from: flags)
        event.post(tap: .cghidEventTap)
    }

    /// Touche nommée : keycode stable, aucune traduction nécessaire.
    func send(special: SpecialKey, flags: Int) {
        tap(keycode: special.keycode, flags: flags)
    }

    /// Frappe d'un caractère.
    ///
    /// - Si la disposition du Mac permet de le produire, on envoie la vraie
    ///   touche physique : les raccourcis et les apps qui lisent les keycodes
    ///   (terminaux, jeux, éditeurs) fonctionnent normalement.
    /// - Sinon, on injecte directement le caractère Unicode dans l'événement.
    /// Maintient ou relâche une touche, sans la relâcher aussitôt.
    ///
    /// Indispensable au mode jeu : avancer suppose de garder « Z » enfoncé,
    /// pas de le taper cent fois. `send(character:)` produit un appui **et**
    /// un relâchement — parfait pour écrire, inutilisable pour se déplacer.
    ///
    /// Passe par la touche physique résolue contre la disposition active :
    /// un jeu lit les keycodes, pas les caractères. Sur un clavier AZERTY,
    /// « z » est donc la touche que le joueur a réellement sous le doigt.
    func hold(character: Character, down: Bool) {
        guard let stroke = layout(respectForced: false)?.stroke(for: character) else { return }
        keyQueue.async { [weak self] in
            guard let self, let source = self.source else { return }
            guard let event = CGEvent(keyboardEventSource: source,
                                      virtualKey: stroke.keycode,
                                      keyDown: down) else { return }
            event.post(tap: .cghidEventTap)
        }
    }

    /// Relâche toutes les touches restées enfoncées.
    ///
    /// Quitter l'écran de jeu ou perdre la liaison avec « Z » enfoncé ferait
    /// avancer le personnage indéfiniment, sans rien pour l'expliquer.
    func releaseAllHeldKeys(_ characters: [Character]) {
        for character in characters { hold(character: character, down: false) }
    }

    func send(character: Character, flags: Int) {
        // Un raccourci est résolu contre la disposition active, jamais contre
        // celle forcée dans les réglages : c'est macOS qui réinterprétera le
        // keycode, et il le fera toujours avec la disposition active.
        let isShortcut = flags & (ModFlag.command | ModFlag.control | ModFlag.option) != 0
        let resolved = layout(respectForced: !isShortcut)

        if let stroke = resolved?.stroke(for: character) {
            let combined = flags | stroke.flags
            record(requested: String(character), keycode: stroke.keycode,
                   flags: combined, layout: resolved)
            // Les modificateurs demandés s'ajoutent à ceux requis par la
            // disposition (Maj, Alt) pour obtenir le caractère.
            tap(keycode: stroke.keycode, flags: combined)
            return
        }

        // Un raccourci avec un caractère introuvable n'a pas de sens : on ne
        // tente l'injection Unicode que pour de la saisie simple.
        guard !isShortcut else { return }
        insert(String(character))
    }

    /// Saisit un texte complet.
    func type(text: String) {
        guard !text.isEmpty else { return }

        // Un texte long passe d'un bloc : plus rapide et sans risque de
        // désordre entre les frappes.
        if text.count > 8 {
            insert(text)
            return
        }
        for character in text {
            send(character: character, flags: 0)
        }
    }

    /// Insère du texte tel quel, sans passer par une touche physique.
    ///
    /// Remplace l'ancien détour par le presse-papiers (Cmd+V), qui écrasait
    /// le contenu copié par l'utilisateur.
    private func insert(_ string: String) {
        // Même file que les frappes : sinon un texte inséré pourrait doubler
        // une touche encore en cours d'envoi.
        keyQueue.async { [weak self] in
            self?.postInsert(string)
        }
    }

    private func postInsert(_ string: String) {
        let units = Array(string.utf16)
        guard !units.isEmpty else { return }

        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source,
                                      virtualKey: 0,
                                      keyDown: down) else { return }
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            event.post(tap: .cghidEventTap)
        }
    }
}
