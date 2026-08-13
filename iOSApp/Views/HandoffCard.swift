import SwiftUI

/// Proposition de reprendre sur l'iPhone ce qui joue sur le Mac.
///
/// Volontairement discrète : elle apparaît quand il y a quelque chose à
/// reprendre et disparaît sinon. Une carte permanente qui dirait « rien à
/// reprendre » n'apporterait rien et occuperait l'écran.
struct HandoffCard: View {
    @EnvironmentObject private var connection: MessageConnection
    @EnvironmentObject private var mac: MacState

    /// Met le Mac en pause en reprenant ici — sans quoi le son sortirait des
    /// deux appareils à la fois, ce qui n'est jamais ce qu'on veut.
    @AppStorage("handoffPausesMac") private var pausesMac = true

    var body: some View {
        Group {
            if let media = mac.handoff {
                card(media)
            }
        }
        // Demander en arrivant, et non attendre que le Mac pousse.
        //
        // Le Mac n'envoie que les *changements* : un morceau déjà en cours
        // depuis dix minutes ne produit aucun événement. Sans cette demande,
        // la carte n'apparaissait qu'en changeant de média pendant que
        // l'écran était ouvert.
        .onAppear { connection.send(.handoffRequest()) }
        .onChange(of: connection.pairingState) { _, state in
            if state == .paired { connection.send(.handoffRequest()) }
        }
    }

    private func card(_ media: MediaHandoff) -> some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            HStack(spacing: 8) {
                // Deux états bien distincts : une vidéo qui joue n'est pas la
                // même proposition qu'une page simplement ouverte.
                Image(systemName: media.isPlaying
                      ? "play.circle.fill" : "safari")
                    .foregroundStyle(media.isPlaying ? Color.accentColor : .secondary)
                Text(media.isPlaying ? "Lecture en cours sur le Mac" : "Page ouverte sur le Mac")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(media.source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(media.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            HStack(spacing: 6) {
                if !media.subtitle.isEmpty {
                    Text(media.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let progress = media.progress {
                    Text("· \(progress)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Barre d'avancement : d'un coup d'œil, on sait si on reprend au
            // début ou aux trois quarts.
            if media.duration > 0, media.position > 0 {
                ProgressView(value: Double(media.position),
                             total: Double(media.duration))
                    .tint(.accentColor)
            }

            // Le Mac ne voit que la page : dire quoi cocher, une fois.
            if media.needsJavaScriptPermission {
                Text("Pour détecter ce qui est réellement lu — y compris en Picture in Picture — activez « Autoriser JavaScript depuis les Apple Events » dans Safari : Réglages > Avancé > Fonctionnalités pour développeurs web, puis menu Développement.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                resume(media)
            } label: {
                Label(media.isPlaying ? "Reprendre sur l'iPhone" : "Ouvrir sur l'iPhone",
                      systemImage: "iphone.and.arrow.right.outward")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 2)

            // La pause n'a de sens que si quelque chose joue : sur une page
            // simplement ouverte, l'option n'aurait rien à mettre en pause.
            if media.isPlaying {
                Toggle("Mettre le Mac en pause", isOn: $pausesMac)
                    .font(.caption)
                    .toggleStyle(.switch)
                    .tint(.accentColor)
            }
        }
        .padding(Design.Space.normal)
        .glassSurface()
    }

    private func resume(_ media: MediaHandoff) {
        guard let url = URL(string: media.resumeURL) else { return }
        // Mettre en pause seulement si quelque chose joue vraiment.
        if pausesMac, media.isPlaying {
            connection.send(.media("playpause"))
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIApplication.shared.open(url)
    }
}
