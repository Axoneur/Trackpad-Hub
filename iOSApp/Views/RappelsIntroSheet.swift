import SwiftUI

/// Présentation affichée **une seule fois**, au tout premier lancement.
///
/// ## Pourquoi une explication avant la demande d'autorisation
///
/// iOS n'affiche l'alerte « autoriser les notifications » qu'**une fois**.
/// Refusée, elle ne revient jamais : seuls les Réglages du système peuvent
/// alors débloquer la situation, et personne n'y va spontanément.
///
/// Une alerte système qui surgit au premier lancement, sans contexte, est
/// refusée par réflexe. Elle est donc précédée de la seule information qui
/// rende le choix sensé : cette app **cesse de fonctionner au bout de 7
/// jours**, et ces notifications sont ce qui prévient avant que ça arrive.
///
/// C'est le même piège que celui mesuré côté Mac, où les notifications
/// étaient refusées de longue date sans que rien ne le signale.
struct RappelsIntroSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Vrai une fois la présentation passée, quel que soit le choix fait.
    @AppStorage(ReglagesRappels.presentationVue) private var vue = false

    @State private var demandeEnCours = false

    var body: some View {
        VStack(spacing: Design.Space.wide) {
            Spacer(minLength: 0)

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: Design.Space.tight) {
                Text("Cette app expire tous les 7 jours")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("C'est une règle d'Apple pour les comptes de développeur gratuits, pas un défaut de TrackPad Hub. Passé ce délai, l'app **refuse simplement de s'ouvrir**. Rien n'est perdu, il suffit de la réinstaller depuis le Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Design.Space.tight) {
                ligne("calendar.badge.clock",
                      "Trois rappels", "Trois jours avant, la veille, puis le jour même. Jamais plus.")
                ligne("iphone.slash",
                      "Déposés à l'avance", "Une fois expirée, l'app ne s'ouvre plus : elle ne pourrait plus vous prévenir. Les rappels partent donc dès maintenant.")
                ligne("slider.horizontal.3",
                      "Réglables", "Délai et heure se changent à tout moment dans Réglages.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Design.Space.normal)
            .glassSurface()

            Spacer(minLength: 0)

            VStack(spacing: Design.Space.tight) {
                Button {
                    demandeEnCours = true
                    ExpiryNotice.demanderPuisProgrammer { _ in
                        // Le refus n'est pas traité à part : l'écran des
                        // réglages affiche l'état réel et le chemin de
                        // rattrapage. Insister ici ne changerait rien, iOS ne
                        // redemandera plus.
                        vue = true
                        dismiss()
                    }
                } label: {
                    Text("Me prévenir avant l'expiration")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(demandeEnCours)

                Button("Plus tard") {
                    vue = true
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(Design.Space.wide)
        .interactiveDismissDisabled()
    }

    private func ligne(_ icone: String, _ titre: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Design.Space.normal) {
            Image(systemName: icone)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(titre).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
