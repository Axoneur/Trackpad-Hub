import SwiftUI
import AVFoundation

/// Caméra dédiée à la lecture du QR d'appairage.
///
/// Volontairement limitée aux QR TrackPad Hub : un QR quelconque est ignoré
/// silencieusement plutôt que de faire croire à un échec.
struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (PairingPayload) -> Void
    let onFailure: (String) -> Void
    /// Incrémenté pour réarmer le scanner après un échec.
    var resetToken: Int = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        // Sans ce réarmement, un scan refusé bloquait la caméra : le verrou
        // anti-répétition restait levé et plus aucun QR n'était accepté.
        context.coordinator.rearm(if: resetToken)
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onScan: (PairingPayload) -> Void
        /// Un QR est relu 30 fois par seconde : sans ce verrou, on enverrait
        /// des dizaines de tentatives d'appairage.
        private var hasScanned = false

        private var lastResetToken = 0

        init(onScan: @escaping (PairingPayload) -> Void) {
            self.onScan = onScan
        }

        /// Réautorise la lecture quand la vue signale un nouvel essai.
        func rearm(if token: Int) {
            guard token != lastResetToken else { return }
            lastResetToken = token
            hasScanned = false
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !hasScanned else { return }
            for object in objects {
                guard let readable = object as? AVMetadataMachineReadableCodeObject,
                      readable.type == .qr,
                      let text = readable.stringValue,
                      let payload = PairingPayload(scanned: text) else { continue }

                hasScanned = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onScan(payload)
                return
            }
        }
    }
}

/// Contrôleur de la session caméra.
final class ScannerViewController: UIViewController {

    weak var delegate: AVCaptureMetadataOutputObjectsDelegate?
    var onFailure: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !session.isRunning else { return }
        // `startRunning` bloque : hors de la file principale, sinon l'interface
        // se fige à l'ouverture de l'écran.
        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.stopRunning()
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onFailure?("Caméra indisponible sur cet appareil.")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onFailure?("Lecture de QR code indisponible.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(delegate, queue: .main)
        // À définir après `addOutput`, sinon `.qr` n'est pas encore proposé.
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        preview = layer
    }
}
