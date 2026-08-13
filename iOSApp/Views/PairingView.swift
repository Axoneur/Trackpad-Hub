import SwiftUI
import AVFoundation

/// Autorisation de l'iPhone auprès du Mac : par scan du QR code, ou par
/// saisie du code à 6 chiffres.
///
/// Tant que l'appairage n'est pas fait, aucun message de contrôle ne part
/// de l'iPhone : cet écran recouvre l'app.
struct PairingView: View {
    @EnvironmentObject private var connection: MessageConnection

    enum Method: String, CaseIterable, Identifiable {
        case scan, code
        var id: String { rawValue }
        var label: String { self == .scan ? "Scanner" : "Saisir le code" }
    }

    @State private var method: Method = .scan
    @State private var pin = ""
    @State private var scanError: String?
    @State private var scannedHost: String?
    @State private var scannerReset = 0
    @FocusState private var focused: Bool

    private var isRefused: Bool { connection.pairingState == .refused }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 20) {
                // Sortie toujours possible : l'écran s'imposait sans aucun
                // moyen d'en sortir tant que le Mac réclamait un code.
                HStack {
                    Spacer()
                    Button("Fermer") {
                        connection.cancelPinEntry()
                    }
                    .padding(.trailing, 20)
                }

                header

                Picker("", selection: $method) {
                    ForEach(Method.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)

                if method == .scan {
                    scanner
                } else {
                    manualEntry
                }

                Spacer(minLength: 0)

                Label("Le code ne circule jamais sur le réseau.",
                      systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 20)
            }
            .padding(.top, 28)
        }
        .onChange(of: connection.pairingState) { _, state in
            if state == .refused {
                pin = ""
                scannedHost = nil
                // Réarme le scanner : sans ça, un premier QR refusé bloquait
                // définitivement la caméra.
                scannerReset += 1
            }
        }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: isRefused ? "lock.trianglebadge.exclamationmark" : "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(isRefused ? Color.orange : Color.accentColor)

            Text(isRefused ? "Code incorrect" : "Autoriser cet iPhone")
                .font(.title2.bold())

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var subtitle: String {
        if isRefused {
            return "Vérifiez le code affiché sur votre Mac et réessayez."
        }
        if let scannedHost {
            return "QR code de « \(scannedHost) » reconnu, vérification…"
        }
        if let scanError {
            return scanError
        }
        return method == .scan
            ? "Pointez la caméra vers le QR code affiché dans l'app TrackPad Hub de votre Mac."
            : "Saisissez le code à 6 chiffres affiché sur votre Mac."
    }

    // MARK: - Scan

    private var scanner: some View {
        QRScannerView(onScan: { payload in
            scannedHost = payload.host
            scanError = nil
            connection.submitPin(payload.pin)
        }, onFailure: { message in
            scanError = message
            method = .code
        }, resetToken: scannerReset)
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.surface, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius.surface, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
        )
        .overlay(alignment: .bottom) {
            Text("Recherche d'un QR code…")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassSurface(cornerRadius: Design.Radius.pill)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Saisie manuelle

    private var manualEntry: some View {
        VStack(spacing: 18) {
            TextField("000000", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .focused($focused)
                .padding(.vertical, 14)
                .glassSurface(cornerRadius: 16)
                .padding(.horizontal, 48)
                .onChange(of: pin) { _, newValue in
                    // Chiffres uniquement, 6 maximum.
                    let digits = newValue.filter(\.isNumber)
                    pin = String(digits.prefix(6))
                    if pin.count == 6 { submit() }
                }

            Button("Valider", action: submit)
                .prominentGlassButton()
                .disabled(pin.count != 6)
        }
        .onAppear { focused = true }
    }

    private func submit() {
        guard pin.count == 6 else { return }
        connection.submitPin(pin)
    }
}
