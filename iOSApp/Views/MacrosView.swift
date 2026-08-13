import SwiftUI

/// Macros : enregistrer une séquence d'actions, la rejouer d'un appui.
struct MacrosView: View {
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var macros: MacroStore

    @State private var showsNaming = false
    @State private var draftName = ""
    @State private var draftIcon = "wand.and.rays"

    private let icons = ["wand.and.rays", "bolt.fill", "square.stack.3d.up.fill",
                         "arrow.triangle.2.circlepath", "text.badge.plus", "hammer.fill"]

    var body: some View {
        GlassScreen(title: "Macros",
                    isConnected: connection.pairingState == .paired,
                    statusText: statusText) {
            recorder
            if !macros.macros.isEmpty { list }
            explanation
        }
        .alert("Nom de la macro", isPresented: $showsNaming) {
            TextField("Ex. : Ouvrir mes onglets", text: $draftName)
            Button("Enregistrer") { macros.commit(name: draftName, icon: draftIcon); draftName = "" }
            Button("Annuler", role: .cancel) { macros.cancelRecording(); draftName = "" }
        } message: {
            Text("\(macros.draft.count) actions capturées.")
        }
    }

    private var statusText: String {
        if macros.isRecording { return "Enregistrement — \(macros.draft.count) actions" }
        return macros.macros.isEmpty ? "Aucune macro" : "\(macros.macros.count) macros"
    }

    // MARK: - Enregistrement

    private var recorder: some View {
        VStack(spacing: Design.Space.tight) {
            if macros.isRecording {
                HStack(spacing: 10) {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Text("Enregistrement en cours")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(macros.draft.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let last = macros.draft.last {
                    Text("Dernière : \(last.message.stepDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if macros.ignoredCount > 0 {
                    Text("\(macros.ignoredCount) mouvements ignorés — touchez une touche, un clic ou un raccourci pour enregistrer une action.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Faites une action à enregistrer : touche, clic, raccourci, fenêtre…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Button("Terminer") {
                        macros.stopRecording()
                        showsNaming = !macros.draft.isEmpty
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Annuler", role: .destructive) { macros.cancelRecording() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    macros.startRecording()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Enregistrer une macro", systemImage: "record.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(connection.pairingState != .paired)
            }
        }
        .padding(Design.Space.normal)
        .glassSurface()
    }

    // MARK: - Liste

    private var list: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Enregistrées", systemImage: "list.bullet")
            ForEach(macros.macros) { macro in
                HStack(spacing: 12) {
                    Image(systemName: macro.icon)
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(macro.name)
                            .font(.subheadline.weight(.semibold))
                        Text(macro.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if macros.playing == macro.id {
                        Button {
                            macros.stopPlaying()
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            macros.play(macro, on: connection)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                        .disabled(connection.pairingState != .paired)
                    }
                }
                .padding(Design.Space.normal)
                .glassSurface()
                .contextMenu {
                    Button("Supprimer", systemImage: "trash", role: .destructive) {
                        macros.remove(macro)
                    }
                }
            }
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ce qui est enregistré")
                .font(.caption.weight(.semibold))
            Text("Touches, clics, raccourcis, commandes système, fenêtres et onglets — avec les pauses que vous faites entre eux. Les déplacements du curseur, le défilement et le zoom sont ignorés : ils dépendent de l'endroit exact où se trouvait le curseur et ne se rejouent pas.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Design.Space.normal)
        .glassSurface()
    }
}
