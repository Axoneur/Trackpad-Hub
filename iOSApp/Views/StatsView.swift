import SwiftUI

/// Statistiques d'utilisation.
struct StatsView: View {
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var stats: UsageStats

    @State private var showsReset = false

    var body: some View {
        GlassScreen(title: "Statistiques",
                    isConnected: connection.pairingState == .paired,
                    statusText: "\(stats.snapshot.total) actions envoyées") {
            timeCard
            breakdown
            note
        }
        .onAppear { stats.publish() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { showsReset = true } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
        }
        .alert("Remettre à zéro ?", isPresented: $showsReset) {
            Button("Effacer", role: .destructive) { stats.reset() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les compteurs repartent de zéro. Rien n'est envoyé nulle part : ces chiffres n'ont jamais quitté l'iPhone.")
        }
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Temps connecté")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(UsageStats.duration(stats.snapshot.connectedSeconds))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Design.Space.normal)
        .glassSurface()
    }

    private var breakdown: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Par type d'action", systemImage: "chart.bar.fill")
            ForEach(rows, id: \.label) { row in
                HStack {
                    Image(systemName: row.icon)
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    Text(row.label)
                        .font(.subheadline)
                    Spacer()
                    Text("\(row.value)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                }
                .padding(.horizontal, Design.Space.normal)
                .padding(.vertical, 10)
                .glassSurface()
            }
        }
    }

    /// Trié par fréquence : le geste le plus utilisé en tête, ce qui est
    /// précisément ce qu'on vient chercher ici.
    private var rows: [(label: String, icon: String, value: Int)] {
        let s = stats.snapshot
        return [
            ("Déplacements", "cursorarrow.motionlines", s.pointer),
            ("Clics", "cursorarrow.click", s.clicks),
            ("Défilement et zoom", "arrow.up.and.down", s.scrolls),
            ("Touches", "keyboard", s.keys),
            ("Gestes système", "hand.draw", s.gestures),
            ("Média", "play.rectangle", s.media),
            ("Fenêtres", "macwindow", s.windows),
            ("Autres", "ellipsis.circle", s.other)
        ]
        .filter { $0.2 > 0 }
        .sorted { $0.2 > $1.2 }
    }

    private var note: some View {
        Text("Ces chiffres restent sur cet iPhone. Ils ne sont ni envoyés au Mac, ni transmis ailleurs.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Design.Space.normal)
            .glassSurface()
    }
}
