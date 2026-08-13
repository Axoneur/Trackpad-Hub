import SwiftUI

/// Historique du presse-papiers du Mac.
///
/// L'historique vit dans la mémoire de l'app Mac et disparaît avec elle :
/// un presse-papiers contient régulièrement des mots de passe, les écrire sur
/// disque leur donnerait une durée de vie que personne n'a demandée.
struct ClipboardHistoryView: View {
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var mac: MacState

    @State private var copied: UUID?

    var body: some View {
        GlassScreen(title: "Presse-papiers",
                    isConnected: connection.pairingState == .paired,
                    statusText: statusText) {
            content
        }
        .onAppear { connection.send(.clipboardHistoryRequest()) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    connection.send(.clipboardHistoryRequest())
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    connection.send(.clipboardClearHistory())
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(mac.clipboardHistory.isEmpty)
            }
        }
    }

    private var statusText: String {
        mac.clipboardHistory.isEmpty
            ? "Rien de copié"
            : "\(mac.clipboardHistory.count) entrées"
    }

    @ViewBuilder
    private var content: some View {
        if mac.clipboardHistory.isEmpty {
            Text("Rien pour l'instant. Copiez du texte sur le Mac : il apparaîtra ici.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: Design.Space.tight) {
                ForEach(mac.clipboardHistory) { entry in
                    row(entry)
                }
            }
        }
    }

    private func row(_ entry: ClipboardEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.preview)
                .font(.callout)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                // Deux destinations distinctes, et la confusion serait fâcheuse :
                // « Sur le Mac » remet le texte dans le presse-papiers du Mac
                // pour le coller là-bas ; « Copier » le met dans celui de
                // l'iPhone.
                Button("Sur le Mac") {
                    connection.send(.clipboardRestore(entry.text))
                    copied = entry.id
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                .font(.caption.weight(.semibold))
                Button("Copier") {
                    UIPasteboard.general.string = entry.text
                    copied = entry.id
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                .font(.caption.weight(.semibold))
            }
            if copied == entry.id {
                Text("Fait")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(Design.Space.normal)
        .glassSurface()
    }
}
