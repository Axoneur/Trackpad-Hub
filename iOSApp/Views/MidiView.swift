import SwiftUI

/// Surface de contrôle MIDI.
///
/// Le Mac se présente comme un appareil MIDI nommé « TrackPad Hub ». Serato,
/// Traktor, Ableton, Logic, Final Cut et la plupart des plugins d'égalisation
/// savent apprendre un contrôleur : on bouge un curseur ici, on clique
/// « MIDI learn » là-bas, c'est associé. Aucun son ne transite, donc aucun
/// pilote à installer — c'est ce qui rend possibles le mode DJ et l'égaliseur
/// sans le pilote audio virtuel qu'ils semblaient exiger.
struct MidiView: View {
    @EnvironmentObject private var connection: MessageConnection

    /// Quatre curseurs, contrôleurs 1 à 4 sur le canal 1.
    @State private var faders: [Double] = [64, 64, 64, 64]

    /// Numéro du dernier pad enfoncé, pour l'affichage.
    @State private var activePad: Int?

    private let padCount = 8
    /// Do central et les sept notes suivantes : la plage que les logiciels
    /// proposent par défaut à l'apprentissage.
    private let firstNote = 60

    var body: some View {
        GlassScreen(title: "MIDI",
                    isConnected: connection.pairingState == .paired,
                    statusText: "Appareil « TrackPad Hub »") {
            explanation
            fadersSection
            padsSection
        }
    }

    private var explanation: some View {
        Text("Dans votre logiciel, activez « MIDI learn », puis bougez un curseur ou touchez un pad ici pour l'associer.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fadersSection: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Curseurs", systemImage: "slider.vertical.3")
            ForEach(0..<faders.count, id: \.self) { index in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Contrôleur \(index + 1)")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("\(Int(faders[index]))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { faders[index] },
                        set: { newValue in
                            faders[index] = newValue
                            connection.send(.midiControl(channel: 0,
                                                         controller: index + 1,
                                                         value: Int(newValue)))
                        }
                    ), in: 0...127)
                }
                .padding(Design.Space.normal)
                .glassSurface()
            }
        }
    }

    private var padsSection: some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: "Pads", systemImage: "square.grid.2x2")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                      spacing: 10) {
                ForEach(0..<padCount, id: \.self) { index in
                    padButton(index)
                }
            }
        }
    }

    private func padButton(_ index: Int) -> some View {
        Text("\(index + 1)")
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .glassSurface(interactive: true)
            .overlay {
                if activePad == index {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
            // Note enfoncée au toucher et relâchée au lever, comme un vrai
            // pad : les logiciels distinguent les deux, et un déclenchement
            // qui ne se relâche jamais laisse la note bloquée.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard activePad != index else { return }
                        activePad = index
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        connection.send(.midiNote(channel: 0, note: firstNote + index,
                                                  velocity: 127, on: true))
                    }
                    .onEnded { _ in
                        activePad = nil
                        connection.send(.midiNote(channel: 0, note: firstNote + index,
                                                  velocity: 0, on: false))
                    }
            )
    }
}
