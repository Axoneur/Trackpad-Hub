import SwiftUI

/// Clavier calqué sur celui d'iOS.
///
/// Reprend sa disposition exacte : trois rangées de lettres, la troisième
/// encadrée par ⇧ et ⌫, puis une rangée de commandes. Les rangées courtes
/// sont centrées comme sur le clavier système, ce qui rend les touches
/// aussi larges que possible plutôt que de les étirer artificiellement.
struct RemoteKeyboard: View {

    let style: KeyboardStyle
    @Binding var shift: Bool
    @Binding var symbols: Bool

    let onCharacter: (Character) -> Void
    let onSpecial: (SpecialKey) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Espacement identique à celui du clavier iOS.
    private let gap: CGFloat = 6
    private let rowGap: CGFloat = 10

    private var isWide: Bool { sizeClass == .regular }
    private var keyHeight: CGFloat { isWide ? 56 : 48 }
    private var fontSize: CGFloat { isWide ? 24 : 22 }

    /// Symboles de la rangée du haut, comme sur iOS quand on bascule en 123.
    private static let symbolRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "€", "&", "@", "\""],
        [".", ",", "?", "!", "'", "«", "»"]
    ]

    private var rows: [[String]] {
        symbols ? Self.symbolRows : style.rows
    }

    var body: some View {
        GeometryReader { geometry in
            let unit = keyWidth(in: geometry.size.width)

            VStack(spacing: rowGap) {
                // Rangées 1 et 2 : lettres seules, centrées.
                ForEach(0..<min(2, rows.count), id: \.self) { index in
                    HStack(spacing: gap) {
                        ForEach(rows[index], id: \.self) { letter in
                            letterKey(letter, width: unit)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Rangée 3 : ⇧ et ⌫ encadrent les lettres, comme sur iOS.
                if rows.count > 2 {
                    HStack(spacing: gap) {
                        commandKey(symbols ? "#+=" : "⇧",
                                   width: unit * 1.5,
                                   active: shift) {
                            shift.toggle()
                        }
                        ForEach(rows[2], id: \.self) { letter in
                            letterKey(letter, width: unit)
                        }
                        commandKey("⌫", width: unit * 1.5, active: false) {
                            onSpecial(.delete)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Rangée de commandes.
                HStack(spacing: gap) {
                    commandKey(symbols ? "ABC" : "123", width: unit * 1.5, active: false) {
                        symbols.toggle()
                        shift = false
                    }
                    commandKey("⇥", width: unit * 1.2, active: false) {
                        onSpecial(.tab)
                    }
                    commandKey("espace", width: .infinity, active: false) {
                        onSpecial(.space)
                    }
                    commandKey("↵", width: unit * 2, active: false) {
                        onSpecial(.return)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: totalHeight)
    }

    private var totalHeight: CGFloat {
        let rowCount = CGFloat(min(rows.count, 3) + 1)
        return rowCount * keyHeight + (rowCount - 1) * rowGap
    }

    /// Largeur d'une touche : dix par rangée, comme sur le clavier iOS, quelle
    /// que soit la rangée réellement affichée. Les rangées plus courtes sont
    /// alors naturellement centrées.
    private func keyWidth(in available: CGFloat) -> CGFloat {
        max((available - gap * 9) / 10, 24)
    }

    private func letterKey(_ label: String, width: CGFloat) -> some View {
        let display = shift && !symbols ? label.uppercased() : label
        return Button {
            onCharacter(Character(display))
            // La majuscule ne vaut que pour une frappe, comme sur iOS.
            if shift && !symbols { shift = false }
        } label: {
            Text(display)
                .font(.system(size: fontSize, weight: .regular))
                .frame(width: width, height: keyHeight)
        }
        .buttonStyle(KeyStyle())
    }

    private func commandKey(_ label: String, width: CGFloat,
                            active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: label.count > 2 ? fontSize * 0.7 : fontSize,
                              weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: width == .infinity ? .infinity : width)
                .frame(height: keyHeight)
        }
        .buttonStyle(KeyStyle(prominent: active))
    }
}

/// Aspect d'une touche : réaction immédiate à l'appui, comme sur iOS.
private struct KeyStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(prominent ? Color.accentColor : Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            }
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
