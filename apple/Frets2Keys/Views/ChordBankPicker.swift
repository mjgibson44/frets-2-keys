import SwiftUI
import Frets2KeysCore

/// Pick a root and chord type (or scale), hear it, then add it to the active set or just show it.
/// Shown in the side panel (an inspector), which iPhone presents as a sheet.
struct ChordBankPicker: View {
    enum Mode: String, CaseIterable {
        case chords = "Chords"
        case scales = "Scales"
    }

    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @AppStorage("chordBankRoot") private var root = 0
    @AppStorage("chordBankQuality") private var qualityID = ChordBank.qualities[0].id
    @AppStorage("chordBankMode") private var mode = Mode.chords
    @AppStorage("scaleBankType") private var scaleType = ScaleType.major
    /// The bank's own key, starting from the app's key. Changing it doesn't change the app's key.
    @State private var key: MusicalKey?
    @State private var hasLoadedKey = false

    private var quality: ChordQuality {
        ChordBank.qualities.first { $0.id == qualityID } ?? ChordBank.qualities[0]
    }

    private var notes: [Note] { ChordBank.notes(root: root, quality: quality) }

    private var scale: MusicalKey { MusicalKey(root: root, type: scaleType) }

    /// The section additions go to, named on the button when the set has sections.
    private var targetSection: ChordSection? {
        let set = model.state.activeSet
        guard set.sections.count > 1 else { return nil }
        let id = model.bankTargetSectionID ?? model.state.activeSectionID
        return set.sections.first { $0.id == id } ?? set.sections.last
    }

    private var addTitle: String {
        guard let section = targetSection,
              let index = model.state.activeSet.sections.firstIndex(of: section) else { return "Add to Set" }
        return "Add to \(section.displayName(index: index))"
    }
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
        model.bankTargetSectionID = nil
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

            Picker("Add", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch mode {
            case .chords: chordChoices
            case .scales: scaleChoices
            }
        }
        .padding(20)
    }

    private var chordChoices: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Key")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                KeyPickerMenu(selection: $key, showsScale: true)
                    .padding(.leading, -8)
                Spacer(minLength: 0)
            }

            if let key, key.isHeptatonic {
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
                        tile(rootName(pitchClass), isSelected: root == pitchClass, role: rootRole(pitchClass)) {
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
                        tile(option.label, isSelected: qualityID == option.id, selectedColor: NotePalette.solid(for: rootRole(root))) {
                            qualityID = option.id
                            model.preview(ChordBank.notes(root: root, quality: option))
                        }
                    }
                }
            }
        }
    }

    private var scaleChoices: some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Root") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(0..<12, id: \.self) { pitchClass in
                        tile(rootName(pitchClass), isSelected: root == pitchClass, role: .chromatic(pitchClass)) {
                            root = pitchClass
                            model.previewScale(MusicalKey(root: pitchClass, type: scaleType))
                        }
                    }
                }
            }

            ForEach(ScaleType.Family.allCases, id: \.self) { family in
                section(family.rawValue) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], spacing: 6) {
                        ForEach(family.types) { type in
                            tile(
                                type.name.prefix(1).uppercased() + type.name.dropFirst(),
                                isSelected: scaleType == type,
                                selectedColor: NotePalette.chromatic[root]
                            ) {
                                scaleType = type
                                model.previewScale(MusicalKey(root: root, type: type))
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch mode {
        case .chords: chordFooter
        case .scales: scaleFooter
        }
    }

    /// The chosen scale's name, notes and degrees, with Show / Add to Set.
    private var scaleFooter: some View {
        let isFull = model.state.savedChords.count >= AppState.maxSavedChords
        let sharpsOnly = model.state.sharpsOnly
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(scale.name(sharpsOnly: sharpsOnly))
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button {
                    model.previewScale(scale)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .buttonStyle(.borderless)
                .help("Hear this scale")
                .accessibilityLabel("Hear this scale")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(zip(scale.noteNames(sharpsOnly: sharpsOnly), scale.type.degrees)), id: \.1) { name, degree in
                        VStack(spacing: 1) {
                            Text(name).font(.system(size: 12, weight: .medium))
                            Text(degree.label).font(.system(size: 10)).opacity(0.85)
                        }
                        .foregroundStyle(.white)
                        .frame(minWidth: 28)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(NotePalette.solid(for: .scaleDegree(degree.number - 1)), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(zip(scale.noteNames(sharpsOnly: sharpsOnly), scale.degreeLabels).map { "\($0) \($1)" }.joined(separator: ", "))

            HStack(spacing: 8) {
                Button {
                    model.showScale(scale)
                    closeIfCoveringContent()
                } label: {
                    Text("Show").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Highlight this scale on the instruments without saving it")

                Button {
                    model.addScale(scale)
                    closeIfCoveringContent()
                } label: {
                    Text(addTitle)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tailwind.blue500)
                .disabled(isFull)
                .help("Save this scale in \(model.state.activeSet.name)")
            }
            .controlSize(.large)

            if isFull {
                Text("This set has \(AppState.maxSavedChords) chords and scales, the maximum. Delete one to add more.")
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

    /// The chosen chord's name and notes, with Select / Add to Set.
    private var chordFooter: some View {
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
                    Text(addTitle)
                        .lineLimit(1)
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
                Text("This set has \(AppState.maxSavedChords) chords and scales, the maximum. Delete one to add more.")
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
                    .modifier(NoteTileStyle(role: rootRole(chord.root), isSelected: isSelected, minHeight: 38))
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
        case "dim7": return "°7"
        case "aug": return "+"
        case "augMaj7": return "+maj7"
        case "mMaj7": return "m(maj7)"
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
    private func rootRole(_ pitchClass: Int) -> NoteColorRole {
        NoteAppearance.colorRole(for: Note(midi: 60 + pitchClass), key: key)
    }

    /// A choice tile. With a note `role`, it's tinted like that note and filled when selected (like
    /// a selected note); otherwise it's neutral and fills with `selectedColor` when selected.
    private func tile(
        _ title: String,
        isSelected: Bool,
        role: NoteColorRole? = nil,
        selectedColor: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .modifier(NoteTileStyle(role: role, isSelected: isSelected, selectedColor: selectedColor, minHeight: 34))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
