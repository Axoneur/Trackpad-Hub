import Foundation
import AppKit
import CoreAudio
import AudioToolbox
import Darwin

/// Contrôle des médias et du volume système.
///
/// - Lecture/pause, piste suivante/précédente : framework privé MediaRemote,
///   avec repli sur les touches média HID si Apple le bloque (ce qui est le
///   cas sur les versions récentes de macOS pour les apps non signées par Apple).
/// - Volume : CoreAudio directement, sans lancer de processus.
final class MediaController {

    // MARK: - MediaRemote (framework privé)

    private typealias SendCommandFn = @convention(c) (Int32, CFDictionary?, (@convention(block) () -> Void)?) -> Void

    private var resolvedSendCommand: SendCommandFn?
    private var didAttemptResolve = false

    private var sendCommand: SendCommandFn? {
        if !didAttemptResolve {
            didAttemptResolve = true
            if let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
                                   RTLD_LAZY),
               let symbol = dlsym(handle, "MRMediaRemoteSendCommand") {
                resolvedSendCommand = unsafeBitCast(symbol, to: SendCommandFn.self)
            } else {
                NSLog("TrackPadHub: MediaRemote indisponible, repli sur les touches média")
            }
        }
        return resolvedSendCommand
    }

    // MARK: - Commandes

    func handle(command: String) {
        switch command {
        case "playpause": playback(mediaRemote: 2, key: NX_KEYTYPE_PLAY)
        case "next":      playback(mediaRemote: 4, key: NX_KEYTYPE_FAST)
        case "prev":      playback(mediaRemote: 5, key: NX_KEYTYPE_REWIND)
        case "volup":     adjustVolume(by: +0.0625)
        case "voldown":   adjustVolume(by: -0.0625)
        case "mute":      toggleMute()
        case "brightup":  pressMediaKey(NX_KEYTYPE_BRIGHTNESS_UP)
        case "brightdown": pressMediaKey(NX_KEYTYPE_BRIGHTNESS_DOWN)
        default:
            // « volume:0.42 » : réglage direct depuis le curseur de l'iPhone.
            if command.hasPrefix("volume:"),
               let value = Double(command.dropFirst("volume:".count)) {
                setVolume(Float(min(max(value, 0), 1)))
            }
        }
    }

    /// Volume actuel, pour positionner le curseur de l'iPhone.
    func currentVolume() -> Float? {
        defaultOutputDevice().flatMap { volume(of: $0) }
    }

    private func setVolume(_ value: Float) {
        guard let device = defaultOutputDevice() else { return }
        if value > 0, isMuted(device) { setMuted(false, on: device) }
        setVolume(value, on: device)
    }

    /// MediaRemote si disponible, sinon la touche média du clavier —
    /// que macOS route vers l'app en cours de lecture.
    private func playback(mediaRemote command: Int32, key: Int32) {
        if let sendCommand {
            sendCommand(command, nil, nil)
        } else {
            pressMediaKey(key)
        }
    }

    /// Les touches média passent par des NSEvent système (type 14, sous-type 8),
    /// et non par des CGEvent clavier classiques.
    private func pressMediaKey(_ key: Int32) {
        for isDown in [true, false] {
            let data1 = Int((key << 16) | ((isDown ? 0xA : 0xB) << 8))
            guard let event = NSEvent.otherEvent(with: .systemDefined,
                                                 location: .zero,
                                                 modifierFlags: [],
                                                 timestamp: 0,
                                                 windowNumber: 0,
                                                 context: nil,
                                                 subtype: 8,
                                                 data1: data1,
                                                 data2: -1) else { return }
            event.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Volume (CoreAudio)

    private func adjustVolume(by delta: Float) {
        guard let device = defaultOutputDevice() else { return }

        // Sortir de la sourdine dès qu'on monte le son.
        if delta > 0, isMuted(device) {
            setMuted(false, on: device)
        }

        let current = volume(of: device) ?? 0
        setVolume(min(max(current + delta, 0), 1), on: device)
    }

    private func toggleMute() {
        guard let device = defaultOutputDevice() else { return }
        setMuted(!isMuted(device), on: device)
    }

    private func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                &address, 0, nil, &size, &device)
        return status == noErr && device != 0 ? device : nil
    }

    private func volume(of device: AudioDeviceID) -> Float? {
        var address = volumeAddress
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private func setVolume(_ value: Float, on device: AudioDeviceID) {
        var address = volumeAddress
        guard AudioObjectHasProperty(device, &address) else { return }

        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
              settable.boolValue else { return }

        var newValue = Float32(value)
        AudioObjectSetPropertyData(device, &address, 0, nil,
                                   UInt32(MemoryLayout<Float32>.size), &newValue)
    }

    private func isMuted(_ device: AudioDeviceID) -> Bool {
        var address = muteAddress
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr && value == 1
    }

    private func setMuted(_ muted: Bool, on device: AudioDeviceID) {
        var address = muteAddress
        guard AudioObjectHasProperty(device, &address) else { return }

        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(device, &address, 0, nil,
                                   UInt32(MemoryLayout<UInt32>.size), &value)
    }

    private var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
    }

    private var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
    }
}
