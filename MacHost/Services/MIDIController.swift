import Foundation
import CoreMIDI

/// Surface de contrôle MIDI : le Mac se présente comme un appareil MIDI que
/// n'importe quel logiciel peut apprendre.
///
/// ## Pourquoi cette voie
///
/// Trois fonctionnalités demandées butaient sur le même mur : mode DJ,
/// égaliseur audio, palettes et roulettes pour les apps créatives. Toutes
/// supposaient de capter ou de traiter le son du système, ce qui exige un
/// pilote audio virtuel installé sur le Mac — un projet séparé, avec son
/// propre installeur.
///
/// Le MIDI contourne le mur entièrement. Serato, Traktor, Ableton, Logic,
/// Final Cut, Photoshop et la plupart des plugins d'égalisation savent
/// **apprendre** un contrôleur MIDI : on bouge un curseur ici, on clique
/// « MIDI learn » là-bas, et c'est associé. Aucun son ne transite, donc aucun
/// pilote.
///
/// `MIDISourceCreateWithProtocol` est une API publique et ne demande aucune
/// autorisation. Vérifié : la source apparaît dans le système et les messages
/// émis arrivent intacts.
final class MIDIController {

    /// Nom qui apparaîtra dans la liste des appareils MIDI des autres apps.
    static let sourceName = "TrackPad Hub"

    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()
    private(set) var isAvailable = false
    private(set) var lastError: String?

    init() {
        setUp()
    }

    deinit {
        if client != 0 { MIDIClientDispose(client) }
    }

    private func setUp() {
        var status = MIDIClientCreate("TrackPadHub" as CFString, nil, nil, &client)
        guard status == noErr else {
            lastError = "Client MIDI refusé (\(status))."
            return
        }
        status = MIDISourceCreateWithProtocol(client, Self.sourceName as CFString, ._1_0, &source)
        guard status == noErr else {
            lastError = "Source MIDI refusée (\(status))."
            return
        }
        isAvailable = true
    }

    // MARK: - Envoi

    /// Statuts MIDI, quartet haut du message de canal.
    private enum Status: UInt8 {
        case noteOff = 0x8
        case noteOn  = 0x9
        case control = 0xB
        case pitch   = 0xE
    }

    /// Change de contrôleur continu — curseurs, roulettes, potentiomètres.
    ///
    /// `controller` et `value` sont bornés à 0–127 : le MIDI 1.0 code ses
    /// données sur sept bits, et un dépassement produirait un octet de statut
    /// à la place d'une donnée, donc un message que le logiciel receveur
    /// interpréterait comme tout autre chose.
    func controlChange(channel: Int, controller: Int, value: Int) {
        send(.control,
             channel: UInt8(clamping: channel),
             data1: UInt8(clamping: controller),
             data2: UInt8(clamping: value))
    }

    /// Pad ou touche. `velocity` à 0 vaut relâchement, comme le veut l'usage.
    func note(channel: Int, note: Int, velocity: Int, on: Bool) {
        send(on && velocity > 0 ? .noteOn : .noteOff,
             channel: UInt8(clamping: channel),
             data1: UInt8(clamping: note),
             data2: UInt8(clamping: velocity))
    }

    private func send(_ status: Status, channel: UInt8, data1: UInt8, data2: UInt8) {
        guard isAvailable else { return }

        var list = MIDIEventList()
        var packet = MIDIEventListInit(&list, ._1_0)
        let word = MIDI1UPChannelVoiceMessage(0,
                                              status.rawValue,
                                              min(channel, 15),
                                              min(data1, 127),
                                              min(data2, 127))
        packet = MIDIEventListAdd(&list, 1024, packet, 0, 1, [word])

        let result = MIDIReceivedEventList(source, &list)
        if result != noErr {
            lastError = "Envoi MIDI refusé (\(result))."
        }
    }
}

private extension UInt8 {
    /// Borne dans 0–127 sans jamais déborder, quel que soit l'entier reçu.
    init(clamping value: Int) {
        self = UInt8(Swift.max(0, Swift.min(127, value)))
    }
}
