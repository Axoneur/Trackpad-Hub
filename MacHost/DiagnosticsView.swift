import SwiftUI

/// Panneau de diagnostic du clavier.
///
/// Un raccourci qui n'aboutit pas là où on l'attend est presque toujours une
/// affaire de disposition : le Mac réinterprète le keycode reçu avec **sa**
/// disposition active. Cet écran montre les deux bouts de la chaîne, ce qui
/// évite d'avoir à deviner.
struct DiagnosticsView: View {
    @EnvironmentObject private var router: Router
    @State private var layouts: [KeyboardLayout] = []

    /// Date de compilation, pour vérifier qu'on exécute bien la dernière
    /// version — un correctif appliqué mais pas recompilé est indétectable
    /// autrement.
    private static let buildStamp: String = {
        guard let url = Bundle.main.executableURL,
              let date = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                  .contentModificationDate else { return "inconnue" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy 'à' HH:mm"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }()

    var body: some View {
        ScrollView {
            GlassStack(spacing: 12) {
                header
                layoutSection.glassCard()
                automationSection.glassCard()
                receivedSection.glassCard()
                traceSection.glassCard()
            }
            .padding(16)
        }
        .softScrollEdges()
        // Plus de `.background(.quaternary)` : l'inspecteur fournit lui-même
        // son fond en verre, et un aplat par-dessus l'aurait bouché.
        .onAppear { layouts = KeyboardLayout.installed() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Diagnostic du clavier").font(.title3.bold())
            Text("Version compilée le \(Self.buildStamp)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // MARK: - Disposition

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Disposition").font(.headline)

            LabeledContent("Active sur ce Mac") {
                Text(KeyboardLayout.currentSourceID() ?? "introuvable")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            LabeledContent("Utilisée pour traduire") {
                Text(router.keyboard.activeLayoutName)
            }
            LabeledContent("Installées") {
                Text(layouts.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .lineLimit(2)
            }

            Text("Les raccourcis utilisent toujours la disposition active, jamais celle forcée dans les réglages.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Automatisation

    /// Les gestes système passent par System Events. S'il est refusé, rien ne
    /// se produit et aucune erreur n'est visible ailleurs.
    @ViewBuilder
    private var automationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Gestes système").font(.headline)

            if let error = router.system.lastAutomationError {
                Label {
                    Text(error).font(.callout)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .textSelection(.enabled)
            } else {
                Label("Aucune erreur signalée.", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            }

            HStack {
                // Sans première demande, l'app n'apparaît nulle part dans les
                // Réglages Système : impossible même de la cocher à la main.
                Button("Demander l'autorisation") {
                    router.system.requestAutomationAccess()
                }
                .glassButton()
                Button("Ouvrir les réglages") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .glassButton()
            }
            .controlSize(.small)

            Text("TrackPad Hub n'apparaît dans « Automatisation » qu'après avoir demandé l'autorisation au moins une fois. Touchez le bouton ci-dessus pour provoquer la demande.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Les bureaux, App Exposé et l'affichage du bureau passent par System Events : le WindowServer ignore ces raccourcis quand ils viennent d'une app tierce. Mission Control, lui, ouvre une app et ne demande aucune autorisation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Messages reçus

    private var receivedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Messages reçus de l'iPhone").font(.headline)
                Spacer()
                Button("Effacer") { router.clearReceived() }
                    .glassButton()
                    .controlSize(.small)
                    .disabled(router.received.isEmpty)
            }

            if router.received.isEmpty {
                Text("Rien reçu. Si une commande ne fait rien et n'apparaît pas ici, c'est que l'iPhone ne l'envoie pas.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(router.received) { entry in
                            HStack(spacing: 8) {
                                Text(entry.date, format: .dateTime.hour().minute().second())
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                                Text(entry.summary)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                Spacer()
                            }
                        }
                    }
                }
                .frame(maxHeight: 140)
            }

            Text("Les déplacements du curseur sont volontairement omis : ils arrivent par centaines.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Journal

    private var traceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Dernières frappes reçues").font(.headline)
                Spacer()
                Button("Effacer") { router.keyboard.clearTraces() }
                    .glassButton()
                    .controlSize(.small)
                    .disabled(router.keyboard.traces.isEmpty)
            }

            if router.keyboard.traces.isEmpty {
                Text("Appuyez sur une touche depuis l'iPhone pour voir ce que ce Mac reçoit.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(router.keyboard.traces) { trace in
                            HStack(spacing: 8) {
                                // Rouge quand la touche envoyée ne produit pas
                                // le caractère demandé : c'est exactement le
                                // cas où ⌘A partirait en ⌘Q.
                                Image(systemName: trace.requested == trace.produces
                                      ? "checkmark.circle.fill"
                                      : "exclamationmark.triangle.fill")
                                    .foregroundStyle(trace.requested == trace.produces ? .green : .red)
                                Text(trace.summary)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                Spacer()
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }
}
