import Foundation
import Carbon.HIToolbox
import AppKit

/// Résolution « caractère → touche physique » d'après une disposition
/// clavier réelle de macOS.
///
/// Indispensable parce qu'un keycode désigne une **position** sur le clavier,
/// pas une lettre : la touche 0 produit `a` en QWERTY US et `q` en AZERTY
/// français. Une table figée enverrait donc ⌘Q (quitter) au lieu de ⌘A
/// (tout sélectionner) sur un Mac français.
final class KeyboardLayout: Identifiable {

    struct Stroke: Equatable {
        let keycode: UInt16
        /// Modificateurs nécessaires pour obtenir le caractère (ModFlag).
        let flags: Int
    }

    /// Ex. « com.apple.keylayout.French ».
    let id: String
    /// Ex. « Français ».
    let name: String

    private var strokes: [Character: Stroke] = [:]
    /// Table inverse : ce qu'une touche physique produit, sans modificateur.
    /// Sert à vérifier qu'un raccourci arrivera bien là où on l'attend.
    private var characters: [UInt16: Character] = [:]

    // MARK: - Construction

    init?(source: TISInputSource) {
        guard let id = Self.string(source, kTISPropertyInputSourceID),
              let name = Self.string(source, kTISPropertyLocalizedName),
              let data = Self.layoutData(source) else { return nil }

        self.id = id
        self.name = name
        build(from: data)

        // Une disposition sans lettre exploitable (saisie chinoise, japonaise…)
        // ne nous sert à rien.
        guard !strokes.isEmpty else { return nil }
    }

    /// Parcourt toutes les touches physiques × combinaisons de modificateurs
    /// pour construire la table inverse.
    private func build(from data: Data) {
        // Les combinaisons sont essayées de la plus simple à la plus complexe :
        // la première qui produit un caractère gagne, donc `A` sera « Maj+a »
        // et non une combinaison exotique équivalente.
        let combinations: [(carbon: UInt32, flags: Int)] = [
            (0, 0),
            (UInt32(shiftKey), ModFlag.shift),
            (UInt32(optionKey), ModFlag.option),
            (UInt32(shiftKey | optionKey), ModFlag.shift | ModFlag.option)
        ]

        let keyboardType = UInt32(LMGetKbdType())

        data.withUnsafeBytes { raw in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }

            for combination in combinations {
                for keycode in UInt16(0)...UInt16(127) {
                    var deadKeyState: UInt32 = 0
                    var length = 0
                    var characters = [UniChar](repeating: 0, count: 4)

                    let status = UCKeyTranslate(layout,
                                                keycode,
                                                UInt16(kUCKeyActionDown),
                                                (combination.carbon >> 8) & 0xFF,
                                                keyboardType,
                                                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                                &deadKeyState,
                                                characters.count,
                                                &length,
                                                &characters)

                    guard status == noErr, length == 1 else { continue }

                    let scalarValue = characters[0]
                    guard let scalar = Unicode.Scalar(scalarValue) else { continue }
                    let character = Character(scalar)

                    // On ignore les caractères de contrôle : ils sont gérés
                    // par les touches nommées (entrée, tabulation…).
                    guard !character.isNewline, scalarValue >= 32, scalarValue != 127 else { continue }

                    if strokes[character] == nil {
                        strokes[character] = Stroke(keycode: keycode, flags: combination.flags)
                    }
                    // Seule la frappe nue nous intéresse en sens inverse :
                    // c'est elle que macOS compare aux raccourcis de menu.
                    // `self.` est nécessaire : le tampon local `characters`
                    // masque la table du même nom.
                    if combination.flags == 0, self.characters[keycode] == nil {
                        self.characters[keycode] = character
                    }
                }
            }
        }
    }

    // MARK: - Utilisation

    /// Touche à frapper pour produire ce caractère, ou nil si la disposition
    /// ne permet pas de le saisir directement.
    func stroke(for character: Character) -> Stroke? {
        strokes[character]
    }

    /// Caractère produit par cette touche physique, sans modificateur.
    func character(forKeycode keycode: UInt16, flags: Int = 0) -> Character? {
        characters[keycode]
    }

    /// Nombre de caractères couverts — utile pour diagnostiquer.
    var coverage: Int { strokes.count }

    // MARK: - Sources disponibles

    /// Disposition actuellement active sur le Mac.
    static func current() -> KeyboardLayout? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else { return nil }
        return KeyboardLayout(source: source)
    }

    /// Identifiant de la disposition active, **sans** construire la table.
    ///
    /// Construire une `KeyboardLayout` coûte 512 appels à `UCKeyTranslate` :
    /// le faire à chaque frappe pour ne comparer que l'identifiant serait
    /// absurde.
    static func currentSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else { return nil }
        return string(source, kTISPropertyInputSourceID)
    }

    /// Toutes les dispositions installées, pour laisser le choix à l'utilisateur.
    static func installed() -> [KeyboardLayout] {
        let filter: [String: Any] = [
            kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?
            .takeRetainedValue() as? [TISInputSource] else { return [] }

        return list
            .compactMap(KeyboardLayout.init(source:))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Disposition portant cet identifiant.
    ///
    /// On interroge directement Carbon avec un filtre plutôt que de construire
    /// toutes les dispositions installées pour n'en garder qu'une.
    static func layout(withID id: String) -> KeyboardLayout? {
        let filter: [String: Any] = [kTISPropertyInputSourceID as String: id]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?
                .takeRetainedValue() as? [TISInputSource],
              let source = list.first else { return nil }
        return KeyboardLayout(source: source)
    }

    // MARK: - Lecture des propriétés Carbon

    private static func string(_ source: TISInputSource, _ key: CFString!) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private static func layoutData(_ source: TISInputSource) -> Data? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        return Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
    }
}
