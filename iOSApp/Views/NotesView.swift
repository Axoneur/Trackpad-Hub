import SwiftUI

/// Notes rapides vers le Mac.
///
/// Remplace le « chat intégré » demandé, qui supposait un serveur et des
/// comptes. Le cas d'usage réel derrière la demande — s'envoyer à soi-même une
/// adresse, un code, une idée — n'a besoin de rien de tout ça : la liaison
/// existe déjà.
///
/// Sur le Mac, la note apparaît en notification **et** atterrit dans le
/// presse-papiers, parce qu'on envoie presque toujours une note pour la coller
/// quelque part.
struct NotesView: View {
    @EnvironmentObject private var connection: MessageConnection

    @State private var draft = ""
    @State private var sent: [String] = []
    @FocusState private var focused: Bool

    private var canSend: Bool {
        connection.pairingState == .paired &&
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GlassScreen(title: "Notes",
                    isConnected: connection.pairingState == .paired,
                    statusText: "Vers le Mac") {
            composer
            if !sent.isEmpty { history }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            TextField("Une adresse, un code, une idée…", text: $draft, axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(.plain)
                .focused($focused)
                .padding(Design.Space.normal)
                .glassSurface()

            HStack {
                Text("Arrive en notification sur le Mac, et dans son presse-papiers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    send()
                } label: {
                    Label("Envoyer", systemImage: "paperplane.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .disabled(!canSend)
            }
        }
    }

    private var history: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Envoyées", systemImage: "clock.arrow.circlepath")
            ForEach(Array(sent.enumerated()), id: \.offset) { _, text in
                HStack {
                    Text(text)
                        .font(.callout)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // Renvoyer sans retaper : une note utile l'est souvent
                    // deux fois.
                    Button {
                        connection.send(.note(text))
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(Design.Space.normal)
                .glassSurface()
            }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        connection.send(.note(text))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        sent.insert(text, at: 0)
        if sent.count > 20 { sent.removeLast() }
        draft = ""
        focused = false
    }
}
