import SwiftUI

/// Bandeau d'entretien : signature qui expire, mise à jour disponible.
///
/// Volontairement discret — il n'apparaît que lorsqu'il y a quelque chose à
/// faire, et disparaît sinon. Un bandeau permanent qui répète « tout va bien »
/// finit par ne plus être lu.
struct MaintenanceCard: View {
    @EnvironmentObject private var releases: ReleaseChecker

    var body: some View {
        VStack(spacing: Design.Space.tight) {
            if SigningExpiry.isExpiringSoon { signature }
            if let sortie = releases.disponible { miseAJour(sortie) }
        }
    }

    // MARK: - Signature

    private var signature: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(SigningExpiry.summary ?? "", systemImage: "clock.badge.exclamationmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SigningExpiry.isExpired ? .red : .orange)

            Text(SigningExpiry.isExpired
                 ? "L'app ne s'ouvrira plus tant qu'elle n'aura pas été réinstallée. Ce n'est pas une panne : un compte Apple gratuit signe pour 7 jours."
                 : "Un compte Apple gratuit signe pour 7 jours. Passé ce délai l'app cesse de s'ouvrir — ce n'est pas une panne.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Sur le Mac, dans le dossier du projet :")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

            Text("./reinstall.sh --all")
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))

            Text("« ./reinstall.sh --install » le fait tout seul tous les 6 jours.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Design.Space.normal)
        .glassSurface()
    }

    // MARK: - Mise à jour

    private func miseAJour(_ sortie: ReleaseChecker.Release) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Version \(sortie.version) disponible", systemImage: "arrow.down.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)

            Text("Vous utilisez la \(ReleaseChecker.versionActuelle).")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !sortie.notes.isEmpty {
                Text(sortie.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            Link(destination: sortie.url) {
                Label("Voir les nouveautés", systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Design.Space.normal)
        .glassSurface()
    }
}
