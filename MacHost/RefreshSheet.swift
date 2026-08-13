import SwiftUI

/// Fenêtre de rafraîchissement, affichée quand l'iPhone est branché.
///
/// Elle s'ouvre seule et se lance seule. Le bouton d'annulation existe pour
/// une raison précise : la réinstallation **coupe la liaison en cours**. Si on
/// est justement en train de se servir du téléphone comme trackpad, il faut
/// pouvoir dire « pas maintenant ».
struct RefreshSheet: View {
    @ObservedObject var refresh: AutoRefresh

    @AppStorage(AutoRefresh.clefActif) private var actif = true
    @AppStorage(AutoRefresh.clefSeuil) private var seuil = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Rafraîchissement de l'application", systemImage: "arrow.triangle.2.circlepath")
                .font(.title3.weight(.semibold))

            contenu

            Divider()

            reglages

            HStack {
                Spacer()
                boutons
            }
        }
        .padding(22)
        .frame(width: 460)
        // Sinon Échap referme la feuille sans rien arrêter : le compte à
        // rebours continuerait et une réinstallation de deux minutes
        // démarrerait sans plus rien à l'écran pour le dire.
        .interactiveDismissDisabled()
    }

    // MARK: - Contenu selon l'état

    @ViewBuilder
    private var contenu: some View {
        switch refresh.etat {
        case .repos:
            Text("Rien à faire pour le moment.")
                .foregroundStyle(.secondary)

        case .compteARebours(let secondes):
            VStack(alignment: .leading, spacing: 8) {
                Text("L'iPhone est branché et sa signature arrive à échéance. Le rafraîchissement démarre dans \(secondes) seconde\(secondes > 1 ? "s" : "").")
                Text("Il dure une à deux minutes, coupe la liaison en cours, et repart pour 7 jours. L'iPhone doit rester branché et déverrouillé.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(AutoRefresh.delai - secondes),
                             total: Double(AutoRefresh.delai))
            }

        case .enCours(let ligne):
            VStack(alignment: .leading, spacing: 8) {
                ProgressView().controlSize(.small)
                Text(ligne)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Laissez l'iPhone branché et déverrouillé.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

        case .reussi(let resume):
            Label(resume, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .echoue(let raison):
            VStack(alignment: .leading, spacing: 6) {
                Label("Le rafraîchissement a échoué", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(raison)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("L'iPhone doit être branché, déverrouillé, et avoir accepté « Se fier à cet ordinateur ».")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Réglages

    private var reglages: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Rafraîchir automatiquement quand l'iPhone est branché", isOn: $actif)

            Picker("Déclencher", selection: $seuil) {
                Text("À chaque branchement").tag(AutoRefresh.seuilToujours)
                Text("3 jours avant l'expiration").tag(3)
                Text("1 jour avant l'expiration").tag(1)
            }
            .disabled(!actif)

            Text("Réinstaller trop tôt ne sert à rien : Apple ne délivre un profil neuf que lorsque l'ancien approche de sa fin. Entre-temps, la date d'expiration ne bouge pas.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Boutons

    @ViewBuilder
    private var boutons: some View {
        switch refresh.etat {
        case .compteARebours:
            Button("Pas maintenant") { refresh.annuler() }
            Button("Rafraîchir tout de suite") { refresh.lancer() }
                .keyboardShortcut(.defaultAction)

        case .enCours:
            Button("Interrompre") { refresh.annuler() }

        case .reussi, .echoue:
            if case .echoue = refresh.etat {
                Button("Réessayer") { refresh.lancer() }
            }
            Button("Fermer") { refresh.terminer() }
                .keyboardShortcut(.defaultAction)

        case .repos:
            Button("Fermer") { refresh.terminer() }
                .keyboardShortcut(.defaultAction)
        }
    }
}
