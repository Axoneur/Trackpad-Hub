import SwiftUI

/// Système de design de l'app : Liquid Glass (iOS 26) et vocabulaire visuel
/// emprunté aux périphériques Apple — Magic Mouse et Magic Trackpad.
///
/// Le principe du Liquid Glass est que le matériau réagit au contenu situé
/// derrière lui. On l'applique donc sur des surfaces posées **au-dessus** du
/// contenu (barres d'action, tuiles, boutons), jamais sur le fond lui-même.
enum Design {

    /// Rayons repris des coins d'appareils Apple.
    enum Radius {
        static let tile: CGFloat = 22
        static let surface: CGFloat = 28
        static let pill: CGFloat = 999
    }

    enum Space {
        static let tight: CGFloat = 8
        static let normal: CGFloat = 14
        static let wide: CGFloat = 20
    }

    /// Blanc légèrement froid du plastique d'une Magic Mouse.
    static let deviceLight = Color(red: 0.97, green: 0.975, blue: 0.98)
    static let deviceShade = Color(red: 0.86, green: 0.87, blue: 0.89)
    /// Gris anthracite de la variante noire.
    static let deviceDark = Color(red: 0.16, green: 0.17, blue: 0.19)
    static let deviceDarkShade = Color(red: 0.09, green: 0.10, blue: 0.11)
}

// MARK: - Matériau adaptatif
//
// Le Liquid Glass n'existe qu'à partir d'iOS 26. Sous les versions
// antérieures, on retombe sur un matériau translucide qui reprend la même
// hiérarchie visuelle : surface flottante, bord clair, teinte facultative.
// Tout passe par ce point unique, pour n'avoir à tester la disponibilité
// qu'à un seul endroit de l'app.

struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = Design.Radius.tile
    var tint: Color?
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(modernGlass, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.fill(tint?.opacity(0.16) ?? Color.clear))
                .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @available(iOS 26.0, *)
    private var modernGlass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint.opacity(0.5)) }
        return interactive ? glass.interactive() : glass
    }
}

extension View {
    /// Surface flottante : Liquid Glass sur iOS 26, matériau translucide avant.
    func glassSurface(cornerRadius: CGFloat = Design.Radius.tile,
                      tint: Color? = nil,
                      interactive: Bool = false) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius,
                              tint: tint,
                              interactive: interactive))
    }

    /// Bouton d'action principal.
    @ViewBuilder
    func prominentGlassButton(tint: Color = .accentColor) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent).tint(tint)
        } else {
            buttonStyle(.borderedProminent).tint(tint)
        }
    }
}

/// Regroupe plusieurs surfaces pour qu'elles fusionnent visuellement quand
/// elles se rapprochent. Sans Liquid Glass, il n'y a rien à fusionner.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

// MARK: - Tuile en verre

/// Tuile standard : un bloc de contenu posé sur le fond.
struct GlassTile<Content: View>: View {
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Design.Space.normal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(tint: tint)
    }
}

// MARK: - Bouton d'action

/// Bouton carré à icône + libellé, l'élément de base des grilles de commandes.
struct GlassActionButton: View {
    let icon: String
    let label: String
    var tint: Color?
    var isProminent = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint ?? .primary)
        // `interactive` fait réagir le matériau au toucher : c'est ce qui
        // donne l'impression que le verre se déforme sous le doigt.
        .glassSurface(tint: isProminent ? tint : nil, interactive: true)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

// MARK: - Pastille d'état

/// Bandeau de connexion, présent en haut de chaque écran.
struct ConnectionPill: View {
    let isConnected: Bool
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(isConnected ? Color.green.opacity(0.35) : .clear, lineWidth: 5)
                )
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassSurface(cornerRadius: Design.Radius.pill)
    }
}

// MARK: - En-tête de section

struct SectionHeader: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Fond de l'app

/// Fond dégradé discret : le Liquid Glass a besoin de matière derrière lui
/// pour produire ses réfractions — sur un aplat uni, l'effet disparaît.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.07, green: 0.08, blue: 0.11),
                   Color(red: 0.12, green: 0.11, blue: 0.16),
                   Color(red: 0.06, green: 0.07, blue: 0.09)]
                : [Color(red: 0.90, green: 0.92, blue: 0.96),
                   Color(red: 0.96, green: 0.95, blue: 0.98),
                   Color(red: 0.88, green: 0.91, blue: 0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Écran standard

/// Structure commune à tous les onglets : fond, bandeau de connexion, contenu.
struct GlassScreen<Content: View>: View {
    let title: String
    let isConnected: Bool
    let statusText: String
    var scrolls = true
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: Design.Space.normal) {
                ConnectionPill(isConnected: isConnected, text: statusText)
                    .padding(.horizontal, Design.Space.wide)

                if scrolls {
                    ScrollView {
                        VStack(spacing: Design.Space.normal) {
                            content
                        }
                        .padding(.horizontal, Design.Space.wide)
                        .padding(.bottom, Design.Space.wide)
                    }
                } else {
                    VStack(spacing: Design.Space.normal) {
                        content
                    }
                    .padding(.horizontal, Design.Space.wide)
                    .padding(.bottom, Design.Space.tight)
                }
            }
            .padding(.top, Design.Space.tight)
        }
        .navigationTitle(title)
    }
}
