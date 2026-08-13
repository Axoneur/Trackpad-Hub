import Foundation
import Speech
import AVFoundation
import Combine

/// Dictée vocale : la parole est transcrite sur l'iPhone puis tapée sur le Mac.
///
/// La reconnaissance se fait sur l'appareil quand le modèle est disponible,
/// ce qui évite d'envoyer l'audio à Apple.
@MainActor
final class Dictation: ObservableObject {

    enum State: Equatable {
        case idle
        case denied(String)
        case listening
        case error(String)
    }

    @Published private(set) var state: State = .idle
    /// Transcription en cours, affichée pendant qu'on parle.
    @Published private(set) var transcript = ""

    /// Appelé avec le texte définitif quand on arrête la dictée.
    var onFinalText: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var isListening: Bool { state == .listening }

    // MARK: - Autorisations

    func requestAccess() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else {
            state = .denied("Autorisez la reconnaissance vocale dans Réglages > TrackPad Hub.")
            return false
        }

        let microphone = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard microphone else {
            state = .denied("Autorisez le micro dans Réglages > TrackPad Hub.")
            return false
        }
        return true
    }

    // MARK: - Cycle

    func toggle() async {
        isListening ? stop() : await start()
    }

    func start() async {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            state = .error("Reconnaissance vocale indisponible.")
            return
        }
        guard await requestAccess() else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Traitement local si le modèle est présent : l'audio ne quitte
            // pas l'iPhone.
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            self.request = request

            let input = engine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }

            engine.prepare()
            try engine.start()

            transcript = ""
            state = .listening

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if error != nil || (result?.isFinal ?? false) {
                        self.finish()
                    }
                }
            }
        } catch {
            state = .error("Micro indisponible : \(error.localizedDescription)")
            teardown()
        }
    }

    func stop() {
        guard isListening else { return }
        finish()
    }

    private func finish() {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        teardown()
        state = .idle
        if !text.isEmpty {
            onFinalText?(text)
        }
    }

    private func teardown() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
