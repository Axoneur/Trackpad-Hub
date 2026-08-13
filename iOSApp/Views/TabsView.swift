import SwiftUI

/// Onglets du navigateur du Mac.
///
/// La liste est demandée à l'ouverture puis après chaque action : le Mac ne
/// pousse rien de lui-même, l'utilisateur peut très bien changer d'onglet à la
/// main pendant que cet écran est ouvert.
struct TabsView: View {
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var mac: MacState

    var body: some View {
        GlassScreen(title: "Onglets",
                    isConnected: connection.pairingState == .paired,
                    statusText: statusText) {

            commandsSection
            listSection
        }
        .onAppear(perform: refresh)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { refresh() } label: { Image(systemName: "arrow.clockwise") }
            }
        }
    }

    private var statusText: String {
        mac.tabs.isEmpty ? "Aucun onglet" : "\(mac.tabs.count) onglets"
    }

    private var commandsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                  spacing: 10) {
            ForEach(BrowserTabAction.buttons) { action in
                GlassActionButton(icon: action.icon, label: action.label) {
                    connection.send(.tabAction(action))
                    // Le navigateur met un instant à appliquer l'ordre : on
                    // relit après coup, sinon la liste affiche l'état d'avant.
                    refreshSoon()
                }
            }
        }
    }

    @ViewBuilder
    private var listSection: some View {
        if mac.tabs.isEmpty {
            Text("Aucun navigateur pilotable ouvert sur le Mac, ou l'autorisation « Automatisation » n'a pas encore été accordée pour lui.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: Design.Space.tight) {
                SectionHeader(title: "Ouverts", systemImage: "square.on.square")
                ForEach(mac.tabs) { tab in
                    HStack(spacing: 12) {
                        Image(systemName: tab.isCurrent ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(tab.isCurrent ? Color.accentColor : .secondary)
                        Text(tab.title.isEmpty ? "Sans titre" : tab.title)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            connection.send(.tabAction(.close, index: tab.index))
                            refreshSoon()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        connection.send(.tabAction(.select, index: tab.index))
                        refreshSoon()
                    }
                }
            }
        }
    }

    private func refresh() {
        connection.send(.tabsRequest())
    }

    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: refresh)
    }
}
