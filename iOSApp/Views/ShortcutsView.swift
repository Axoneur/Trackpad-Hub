import SwiftUI

/// Raccourcis à déclencher sur le Mac : lancer une app, ouvrir une URL,
/// exécuter un raccourci de l'app Raccourcis.
struct ShortcutsView: View {
    @EnvironmentObject private var connection: MessageConnection
    @StateObject private var store = ShortcutStore()
    @State private var showAddSheet = false

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]
    private var isPaired: Bool { connection.pairingState == .paired }

    var body: some View {
        NavigationStack {
            GlassScreen(title: "Raccourcis",
                        isConnected: isPaired,
                        statusText: isPaired
                            ? "Connecté · un toucher lance le raccourci"
                            : "Non connecté au Mac") {
                if store.items.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.items) { item in
                            ShortcutButton(item: item) {
                                send(item)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation { store.remove(item) }
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddShortcutSheet { store.add($0) }
            }
        }
    }

    private var emptyState: some View {
        GlassTile {
            VStack(spacing: 10) {
                Image(systemName: "bolt.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Aucun raccourci").font(.headline)
                Text("Ajoutez des applications, liens ou raccourcis pour les lancer d'un toucher sur votre Mac.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private func send(_ item: ShortcutItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        connection.send(.shortcut(action: item.action,
                                  target: item.target,
                                  name: item.shortcutName))
    }
}

struct ShortcutButton: View {
    let item: ShortcutItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.tint)
                Text(item.name)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 86)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassSurface(cornerRadius: Design.Radius.tile, interactive: true)
    }
}
