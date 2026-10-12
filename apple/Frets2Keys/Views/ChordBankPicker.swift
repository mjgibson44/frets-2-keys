import SwiftUI
import Frets2KeysCore

/// Pick a root and chord type, hear it, then add it to the active set or just select it.
/// Shown in the side panel (an inspector), which iPhone presents as a sheet.
struct ChordBankPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @AppStorage("chordBankRoot") private var root = 0
    @AppStorage("chordBankQuality") private var qualityID = ChordBank.qualities[0].id
    /// The bank's own key, starting from the app's key. Changing it doesn't change the app's key.
    @State private var key: MusicalKey?
    @State private var hasLoadedKey = false

    private var quality: ChordQuality {
        ChordBank.qualities.first { $0.id == qualityID } ?? ChordBank.qualities[0]
    }

    private var notes: [Note] { ChordBank.notes(root: root, quality: quality) }

    var body: some View {
        ScrollView {
            content
        }
        // The chosen chord and its actions stay pinned to the bottom while the choices scroll.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
        #if os(iOS)
        .presentationDetents([.large])
        #endif
        .onAppear {
            guard !hasLoadedKey else { return }
            key = model.state.selectedKey
            hasLoadedKey = true
        }
    }

    private func close() {
        model.isChordBankPresented = false
    }

    /// Beside the instruments (iPad, Mac) the panel stays open so several chords can be added in a
    /// row; as a sheet over everything (iPhone) it closes so the result is visible.
    private func closeIfCoveringContent() {
        #if os(iOS)
        if horizontalSizeClass == .compact { close() }
        #endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Chord Bank")
                    .font(.headline)
                Spacer()
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Close the chord bank")
                .accessibilityLabel("Close")
            }

            HStack(spacing: 8) {
                Text("Key")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                KeyPickerMenu(selection: $key, showsScale: true)
                    .padding(.leading, -8)
                Spacer(minLength: 0)
            }

            if let key {
                section("Chords in \(key.name(sharpsOnly: model.state.sharpsOnly))") {
                    VStack(spacing: 6) {
                        diatonicRow(key.diatonicChords())
                        diatonicRow(key.diatonicChords(sevenths: true))
                    }
                }
            }

            section("Root") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(0..<12, id: \.self) { pitchClass in
                        tile(rootName(pitchClass), isSelected: root == pitchClass, color: rootColor(pitchClass)) {
                            root = pitchClass
                            model.preview(ChordBank.notes(root: pitchClass, quality: quality))
                        }
                        // Roots outside the chosen key are dimmed.
                        .opacity(key.map { $0.pitchClasses.contains(pitchClass) } ?? true ? 1 : 0.45)
                    }
                }
            }

            section("Type") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 6)], spacing: 6) {
                    ForEach(ChordBank.qualities) { option in
                        tile(option.label, isSelected: qualityID == option.id, selectedColor: rootColor(root)) {
                            qualityID = option.id
                            model.preview(ChordBank.notes(root: root, quality: option))
                        }
                    }
                }
            }

        }
        .padding(20)
    }

    /// The chosen chord's name and notes, with Select / Add to Set.
    private var footer: some View {
        let isFull = model.state.savedChords.count >= AppState.maxSavedChords
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(ChordBank.name(root: root, quality: quality))
                    .font(.system(size: 15, weight: .semibold))
                HStack(spacing: 4) {
                    ForEach(notes, id: \.self) { note in
                        Text(note.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                NotePalette.solid(for: NoteAppearance.colorRole(for: note, key: key)),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                    }
                }
                Spacer(minLength: 0)
                Button {
                    model.preview(notes)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .buttonStyle(.borderless)
                .help("Hear this chord")
                .accessibilityLabel("Hear this chord")
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 8) {
                Button {
                    model.selectBankChord(notes)
                    closeIfCoveringContent()
                } label: {
                    Text("Select").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Show this chord on the instruments without saving it")

                Button {
                    model.addBankChord(notes)
                    closeIfCoveringContent()
                } label: {
                    Text("Add to Set")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                // Sheets and side panels don't reliably pass the accent color down, so set it here.
                .tint(Tailwind.blue500)
                .disabled(isFull)
                .help("Save this chord in \(model.state.activeSet.name)")
            }
            .controlSize(.large)

            if isFull {
                Text("This set has \(AppState.maxSavedChords) chords, the maximum. Delete one to add more.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    /// Root names spelled for the bank's key (flats in flat keys) unless "Sharps only" is on.
    private func rootName(_ pitchClass: Int) -> String {
        displayName(for: Note(midi: 60 + pitchClass), key: key, sharpsOnly: model.state.sharpsOnly)
    }

    /// One tile per scale degree: the Roman numeral over the chord name.
    private func diatonicRow(_ chords: [DiatonicChord]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(chords, id: \.numeral) { chord in
                let isSelected = root == chord.root && qualityID == chord.quality.id
                Button {
                    root = chord.root
                    qualityID = chord.quality.id
                    model.preview(ChordBank.notes(root: chord.root, quality: chord.quality))
                } label: {
                    VStack(spacing: 1) {
                        Text(chord.numeral)
                            .font(.system(size: 11, weight: .semibold))
                        Text(rootName(chord.root) + chordSuffix(chord.quality))
                            .font(.system(size: 11))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .modifier(NoteTileStyle(color: rootColor(chord.root), isSelected: isSelected, minHeight: 38))
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(chord.numeral): \(rootName(chord.root)) \(chord.quality.label)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    /// Compact chord suffix for the diatonic tiles ("" for major, "m", "°", "maj7", ...).
    private func chordSuffix(_ quality: ChordQuality) -> String {
        switch quality.id {
        case "maj": return ""
        case "dim": return "°"
        case "m7b5": return "ø7"
        default: return quality.id
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    /// The instruments' color for a root note under the bank's key: scale-degree colors in a key,
    /// one color per pitch class with no key.
    private func rootColor(_ pitchClass: Int) -> Color {
        NotePalette.solid(for: NoteAppearance.colorRole(for: Note(midi: 60 + pitchClass), key: key))
    }

    /// A choice tile. With `color`, it's tinted in that color and filled when selected (like a
    /// selected note); otherwise it's neutral and fills with `selectedColor` when selected.
    private func tile(
        _ title: String,
        isSelected: Bool,
        color: Color? = nil,
        selectedColor: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .modifier(NoteTileStyle(color: color, isSelected: isSelected, selectedColor: selectedColor, minHeight: 34))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Colors a chord bank tile the way the instruments color notes: a light tint with a matching
/// border when unselected, solid with white text when selected.
private struct NoteTileStyle: ViewModifier {
    @Environment(\.theme) private var theme
    let color: Color?
    let isSelected: Bool
    var selectedColor: Color = .accentColor
    let minHeight: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6)
        content
            .foregroundStyle(isSelected ? .white : theme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(fill, in: shape)
            .overlay {
                if let color, !isSelected {
                    shape.strokeBorder(color.opacity(theme.isDark ? 0.7 : 0.55), lineWidth: 1)
                }
            }
            .contentShape(shape)
    }

    private var fill: Color {
        if isSelected { return color ?? selectedColor }
        if let color { return color.opacity(theme.isDark ? 0.22 : 0.12) }
        return theme.chip
    }
}
