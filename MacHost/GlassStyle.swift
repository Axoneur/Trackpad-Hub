import SwiftUI

/// Adoption de Liquid Glass, le langage visuel de macOS 26.
///
/// Pourquoi ce fichier existe : une app compilée avec le SDK 26 hérite
/// automatiquement du nouveau look **sur le chrome standard seulement** —
/// barre d'outils, barre latérale, feuilles, contrôles système. L'interface de
/// TrackPad Hub était une pile de `VStack` séparés par des `Divider` : aucun
/// chrome, donc aucun verre. Il n'y avait rien à habiller.
///
/// Le motif de base de Liquid Glass est la **carte flottante** : un panneau
/// translucide, arrondi, qui laisse deviner ce qu'il y a derrière. On regroupe
/// donc le contenu en cartes plutôt que de le séparer par des traits.
///
/// La cible de déploiement reste macOS 14 (`project.yml`), d'où le
/// `if #available` systématique. Les replis ne cherchent pas à imiter le
/// verre — ils rendent la même hiérarchie visuelle en matériau classique.

// MARK: - Cartes

extension View {

    /// Carte flottante en verre. Le bloc de construction de cette interface.
    func glassCard(cornerRadius: CGFloat = 16, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// Carte teintée par la couleur d'accentuation, pour un élément à mettre
    /// en avant — ici le code d'appairage.
    func glassAccentCard(cornerRadius: CGFloat = 12, padding: CGFloat = 14) -> some View {
        modifier(GlassAccentCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let card = content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)

        if #available(macOS 26.0, *) {
            card.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            card.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            )
        }
    }
}

private struct GlassAccentCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let card = content
            .padding(padding)
            .frame(maxWidth: .infinity)

        if #available(macOS 26.0, *) {
            card.glassEffect(.regular.tint(.accentColor), in: .rect(cornerRadius: cornerRadius))
        } else {
            card.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            )
        }
    }
}

// MARK: - Regroupement

/// Pile de cartes déclarée dans un `GlassEffectContainer`.
///
/// Le conteneur n'est pas décoratif : c'est lui qui permet aux cartes proches
/// de partager leurs réflexions et de fusionner quand elles se rapprochent.
/// Sans lui, chaque carte calcule son verre dans son coin et le rendu paraît
/// plat.
struct GlassStack<Content: View>: View {
    var spacing: CGFloat = 14
    var alignment: HorizontalAlignment = .leading
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                VStack(alignment: alignment, spacing: spacing, content: content)
            }
        } else {
            VStack(alignment: alignment, spacing: spacing, content: content)
        }
    }
}

// MARK: - Boutons

extension View {

    /// Bouton en verre. `prominent` pour l'action principale d'un écran —
    /// une seule par écran, sinon l'accent ne veut plus rien dire.
    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Fenêtre

extension View {

    /// Fond de fenêtre translucide.
    ///
    /// Indispensable : du verre posé sur un fond opaque ne réfracte rien et
    /// ressemble à du gris. C'est ce qui manquait le plus ici.
    ///
    /// `ContainerBackgroundPlacement.window` est apparu en **macOS 15**, pas
    /// en 14 comme `containerBackground(_:for:)` lui-même — vérifié au
    /// compilateur. Sur 14, on se contente d'un matériau derrière le contenu.
    @ViewBuilder
    func glassWindowBackground() -> some View {
        if #available(macOS 15.0, *) {
            containerBackground(.thinMaterial, for: .window)
        } else {
            background(.ultraThinMaterial)
        }
    }

    /// Efface le fond opaque de la barre de titre.
    ///
    /// Sans ça, `containerBackground` peint bien toute la fenêtre, mais la
    /// barre de titre repeint **par-dessus** son propre matériau opaque : on
    /// obtient un bandeau gris franc au-dessus d'un contenu translucide, la
    /// couture visible exactement là où l'œil se pose en premier.
    ///
    /// Une fois le fond masqué, le verre de la fenêtre court d'un bord à
    /// l'autre et les commandes de la barre d'outils flottent dessus — c'est
    /// le comportement attendu sous macOS 26.
    func clearTitleBarBackground() -> some View {
        toolbarBackground(.hidden, for: .windowToolbar)
    }

    /// Estompe le contenu qui passe sous la barre de titre au défilement,
    /// au lieu de le laisser se couper net.
    @ViewBuilder
    func softScrollEdges() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}
