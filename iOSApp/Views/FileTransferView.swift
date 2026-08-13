import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Envoi de fichiers et de photos vers le Mac.
///
/// Sens unique iPhone → Mac : c'est le besoin réel. Dans l'autre sens, le Mac
/// dispose déjà d'AirDrop, et parcourir son disque depuis l'iPhone demanderait
/// une interface de navigation entière pour un usage rare.
struct FileTransferView: View {
    @EnvironmentObject private var connection: MessageConnection

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false
    @State private var log: [Entry] = []
    @State private var isPreparing = false

    private var isPaired: Bool { connection.pairingState == .paired }

    struct Entry: Identifiable {
        let id = UUID()
        let name: String
        let success: Bool
        let detail: String
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: Design.Space.normal) {
                    ConnectionPill(isConnected: isPaired,
                                   text: isPaired
                                       ? "Les fichiers arrivent dans Téléchargements › TrackPad Hub"
                                       : "Connectez-vous à votre Mac")

                    if let progress = connection.transferProgress {
                        transferCard(progress: progress)
                    }

                    actions
                    if !log.isEmpty { history }
                }
                .padding(.horizontal, Design.Space.wide)
                .padding(.bottom, Design.Space.wide)
            }
        }
        .navigationTitle("Envoyer un fichier")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: photoPickerBinding,
                      selection: $photoItems,
                      maxSelectionCount: 10,
                      matching: .any(of: [.images, .videos]))
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await sendPhotos(items) }
        }
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Progression

    private func transferCard(progress: Double) -> some View {
        GlassTile(tint: .accentColor) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill").foregroundStyle(.tint)
                    Text(connection.transferName ?? "Transfert…")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(progress * 100)) %")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
            }
        }
    }

    // MARK: - Boutons

    @State private var showPhotoPicker = false

    private var photoPickerBinding: Binding<Bool> {
        Binding(get: { showPhotoPicker }, set: { showPhotoPicker = $0 })
    }

    private var actions: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Envoyer vers le Mac", systemImage: "paperplane")

            HStack(spacing: 10) {
                GlassActionButton(icon: "photo.on.rectangle",
                                  label: "Photos",
                                  tint: .accentColor,
                                  isProminent: true) {
                    showPhotoPicker = true
                }
                .disabled(!isPaired || isPreparing)

                GlassActionButton(icon: "folder", label: "Fichiers") {
                    showFileImporter = true
                }
                .disabled(!isPaired || isPreparing)

                GlassActionButton(icon: "doc.on.clipboard", label: "Presse-papiers") {
                    sendClipboardImage()
                }
                .disabled(!isPaired || isPreparing)
            }

            if isPreparing {
                Text("Préparation…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Historique

    private var history: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Envoyés", systemImage: "clock")
            ForEach(log) { entry in
                HStack(spacing: 10) {
                    Image(systemName: entry.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(entry.success ? .green : .orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.name).font(.footnote.weight(.medium)).lineLimit(1)
                        Text(entry.detail).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassSurface()
            }
        }
    }

    // MARK: - Envoi

    private func sendPhotos(_ items: [PhotosPickerItem]) async {
        isPreparing = true
        defer { isPreparing = false; photoItems = [] }

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                record("Photo", success: false, detail: "Lecture impossible")
                continue
            }
            // Nom lisible plutôt que l'identifiant opaque de la photothèque.
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let name = "IMG_\(Self.stamp()).\(ext)"
            await send(data: data, named: name)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else {
            if case .failure(let error) = result {
                record("Fichier", success: false, detail: error.localizedDescription)
            }
            return
        }

        Task {
            isPreparing = true
            defer { isPreparing = false }

            for url in urls {
                // Les fichiers du sélecteur sont hors du bac à sable : il faut
                // demander l'accès puis le relâcher.
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }

                guard let data = try? Data(contentsOf: url) else {
                    record(url.lastPathComponent, success: false, detail: "Lecture impossible")
                    continue
                }
                await send(data: data, named: url.lastPathComponent)
            }
        }
    }

    private func sendClipboardImage() {
        guard let image = UIPasteboard.general.image,
              let data = image.pngData() else {
            record("Presse-papiers", success: false, detail: "Aucune image copiée")
            return
        }
        Task { await send(data: data, named: "Capture_\(Self.stamp()).png") }
    }

    /// Écrit la donnée dans un fichier temporaire, seul format accepté par
    /// l'envoi de ressources, puis le transmet.
    private func send(data: Data, named name: String) async {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: temporary, options: .atomic)
        } catch {
            record(name, success: false, detail: "Écriture temporaire impossible")
            return
        }

        await withCheckedContinuation { continuation in
            connection.sendFile(at: temporary) { error in
                try? FileManager.default.removeItem(at: temporary)
                if let error {
                    record(name, success: false, detail: error.localizedDescription)
                } else {
                    record(name, success: true, detail: Self.readableSize(data.count))
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Helpers

    private func record(_ name: String, success: Bool, detail: String) {
        log.insert(Entry(name: name, success: success, detail: detail), at: 0)
        if log.count > 12 { log.removeLast() }
        UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error)
    }

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private static func readableSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
