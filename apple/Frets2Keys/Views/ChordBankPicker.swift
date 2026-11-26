import SwiftUI
import Frets2KeysCore

/// Pick a root and chord type, which selects it on the instruments, then add it to the song.
/// Shown in the side panel (an inspector), which iPhone presents as a sheet.
struct ChordBankPicker: View {
    /// iPad and Mac: a compact column beside the song at the bottom of the window. Otherwise
    /// (iPhone) a sheet.
    var inBottomPanel = false
    /// Its inset from the edges, matching the song beside or above it.
    var padding: CGFloat = 16
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.isCompactLayout) private var isCompact
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @AppStorage("chordBankRoot") private var root = 0
    @AppStorage("chordBankQuality") private var qualityID = ChordBank.qualities[0].id
    /// The app's key: the bank's key menu and the top bar's are the same setting.
    /// The bank's own key, starting from the app's. Changing it doesn't change the instruments'
    /// key (that's the menu at the top left), and theirs doesn't change it.
    @State private var key: MusicalKey?
    @State private var hasLoadedKey = false
    private var keyBinding: Binding<MusicalKey?> { $key }

    private var quality: ChordQuality {
        ChordBank.qualities.first { $0.id == qualityID } ?? ChordBank.qualities[0]
    }

    private var notes: [Note] { ChordBank.notes(root: root, quality: quality) }


    /// The section additions go to, named on the button when the set has sections.
    private var targetSection: ChordSection? {
        let set = model.state.activeSet
        guard set.sections.count > 1, model.state.usesSections else { return nil }
        let id = model.bankTargetSectionID ?? model.state.activeSectionID
        return set.sections.first { $0.id == id } ?? set.sections.last
    }

    private var addTitle: String {
        guard let section = targetSection,
              let index = model.state.activeSet.sections.firstIndex(of: section) else { return "Add to Song" }
        return "Add to \(section.displayName(index: index))"
    }
    var body: some View {
        layout
        // Dark mode puts the panel on the page color, like the main window.
        .background(theme.isDark ? theme.pageBackground : .clear)
        .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
        #if os(iOS)
        .presentationDetents([.large])
        #endif
        .onAppear {
            guard !hasLoadedKey else { return }
            key = model.state.selectedKey
            hasLoadedKey = true
            keepQualityInKey()
        }
        .onChange(of: key) { keepQualityInKey() }
    }

    /// Each key note's triad numeral (I, ii, iii°...), by root pitch class. Empty with no key or a
    /// scale without seven notes.
    private var diatonicNumerals: [Int: String] {
        Dictionary((key?.diatonicChords() ?? []).map { ($0.root, $0.numeral) }, uniquingKeysWith: { a, _ in a })
    }

    /// The chord types to offer for the root: with a key, only those whose notes are all in the
    /// key (so A in A major has no minor); with no key, all of them.
    private var typeOptions: [ChordQuality] { typeOptions(for: root) }

    private func typeOptions(for root: Int) -> [ChordQuality] {
        guard let key else { return ChordBank.qualities }
        let inKey = ChordBank.qualities.filter { quality in
            quality.intervals.allSatisfy { key.pitchClasses.contains((root + $0) % 12) }
        }
        return inKey.isEmpty ? ChordBank.qualities : inKey
    }

    private func selectRoot(_ pitchClass: Int) {
        root = pitchClass
        keepQualityInKey()
        model.pickBankChord(ChordBank.notes(root: pitchClass, quality: quality))
    }

    /// Keeps the root and type valid for the bank's key: a root in the key, and a type the key
    /// allows on it (the degree's own triad when the current type doesn't fit).
    private func keepQualityInKey() {
        guard let key else { return }
        if !key.pitchClasses.contains(root) { root = key.root }
        let options = typeOptions(for: root)
        guard !options.contains(where: { $0.id == qualityID }) else { return }
        let triad = key.diatonicChords().first { $0.root == root }?.quality
        qualityID = triad.flatMap { t in options.first { $0.id == t.id } }?.id ?? options[0].id
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

    /// A sheet over everything (iPhone, or a narrow iPad window) rather than a sidebar.
    private var isSheet: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    /// The bank scrolls, with the add bar (beside the instruments) or the chosen chord and its
    /// buttons (as a sheet on iPhone) pinned to the bottom.
    @ViewBuilder
    private var layout: some View {
        if inBottomPanel {
            compactBank
        } else {
            ScrollView {
                bank
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer
            }
        }
    }

    /// Beside the song: title and key, the roots on one row (no numerals), the types as small chips, then the
    /// selected chord with Add, all kept short so the instruments above keep their height.
    private var compactBank: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Chord Bank")
                    .font(.system(size: 14, weight: .semibold))
                // The app's key (the only key menu on iPad and Mac).
                KeyPickerMenu(selection: keyBinding, showsScale: false, showsClef: true)
                    .padding(.leading, -8)
                Spacer(minLength: 0)
            }
            // Just the note names (no numerals), to keep the row short.
            let roots = key?.pitchClasses ?? Array(0..<12)
            // Narrow: the type is a menu at the end of the roots' row.
            HStack(alignment: .top, spacing: 8) {
                FlowLayout(spacing: 4) {
                    ForEach(roots, id: \.self) { pitchClass in
                        tile(rootName(pitchClass), isSelected: root == pitchClass, role: rootRole(pitchClass), compact: true) {
                            selectRoot(pitchClass)
                        }
                    }
                }
                if isCompact {
                    // Right after the roots.
                    typeMenu
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isCompact {
            FlowLayout(spacing: 4) {
                ForEach(typeOptions) { option in
                    tile(option.label, isSelected: qualityID == option.id, selectedColor: theme.noteSolid(rootRole(root)), selectedTextColor: theme.noteSolidText(rootRole(root)), compact: true) {
                        qualityID = option.id
                        model.pickBankChord(ChordBank.notes(root: root, quality: option))
                    }
                }
            }
            }
            // The bank's own chord (its chosen root and type), whatever's selected on the instruments.
            SidebarAddBar(inline: true, bankChord: (root, quality), key: key)
                .padding(.top, 2)
        }
        .padding(.horizontal, padding)
        .padding(.vertical, Device.isPhone ? 12 : 16)
    }

    private var bank: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("Chord Bank")
                    .font(.headline)
                // The app's key (the only key menu on iPad and Mac).
                KeyPickerMenu(selection: keyBinding, showsScale: true, showsClef: true)
                Spacer(minLength: 0)
                if isSheet {
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
            }

            chordChoices
        }
        .padding(20)
    }

    private var chordChoices: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                // With a key, just its notes in scale order on one row, each under its numeral;
                // otherwise all twelve.
                let roots = key?.pitchClasses ?? Array(0..<12)
                let numerals = diatonicNumerals
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: key == nil ? 6 : roots.count), spacing: 6) {
                    ForEach(roots, id: \.self) { pitchClass in
                        tile(rootName(pitchClass), caption: numerals[pitchClass], isSelected: root == pitchClass, role: rootRole(pitchClass)) {
                            selectRoot(pitchClass)
                        }
                    }
                }
            }

            Group {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 6)], spacing: 6) {
                    ForEach(typeOptions) { option in
                        tile(option.label, isSelected: qualityID == option.id, selectedColor: theme.noteSolid(rootRole(root)), selectedTextColor: theme.noteSolidText(rootRole(root))) {
                            qualityID = option.id
                            model.pickBankChord(ChordBank.notes(root: root, quality: option))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if showsChordFooter {
            chordFooter
        } else {
            // Beside the instruments: whatever's selected (from the bank or the instruments), with
            // Add right under the bank.
            SidebarAddBar()
        }
    }

    /// A picked chord is selected on the instruments, so beside them (iPad, Mac) it shows in the
    /// selected-chord card, which has Add to set. As a sheet over everything (iPhone) that card is
    /// hidden, so the chord and its buttons are pinned to the bottom of the sheet instead.
    private var showsChordFooter: Bool { isSheet }

    /// The chosen chord's name and notes, with Select / Add to Set.
    private var chordFooter: some View {
        let isFull = model.state.savedChords.count >= AppState.maxSavedChords
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                noteText(chordDisplayName(ChordBank.name(root: root, quality: quality)), size: 15, weight: .semibold)
                HStack(spacing: 4) {
                    ForEach(notes, id: \.self) { note in
                        noteText(note.name, size: 12, weight: .medium)
                            .foregroundStyle(theme.noteSolidText(NoteAppearance.colorRole(for: note, key: key)))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                theme.noteSolid(NoteAppearance.colorRole(for: note, key: key)),
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
                .buttonStyle(BankButtonStyle(prominent: false))
                .help("Show this chord on the instruments without saving it")

                Button {
                    model.addBankChord(notes)
                    closeIfCoveringContent()
                } label: {
                    Text(addTitle)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BankButtonStyle(prominent: true))
                .disabled(isFull)
                .help("Save this chord in \(model.state.activeSet.name)")
            }

            if isFull {
                Text("This song has \(AppState.maxSavedChords) chords and scales, the maximum. Delete one to add more.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .modifier(BankFooterStyle())
    }

    /// Root names spelled for the bank's key (flats in flat keys) unless "Sharps only" is on.
    private func rootName(_ pitchClass: Int) -> String {
        displayName(for: Note(midi: 60 + pitchClass), key: key, sharpsOnly: model.state.sharpsOnly)
    }

    /// Uncolored tiles: the card surface in dark mode, so they sit on the page like the instruments.
    private var neutralTileFill: Color? { theme.isDark ? theme.instrumentBackground : nil }

    /// The instruments' color for a root note under the bank's key: scale-degree colors in a key,
    /// one color per pitch class with no key.
    private func rootRole(_ pitchClass: Int) -> NoteColorRole {
        NoteAppearance.colorRole(for: Note(midi: 60 + pitchClass), key: key)
    }

    /// The chord type as a menu (narrow layouts), filled like a selected type chip.
    private var typeMenu: some View {
        let role = rootRole(root)
        return Menu {
            ForEach(typeOptions) { option in
                Button {
                    qualityID = option.id
                    model.pickBankChord(ChordBank.notes(root: root, quality: option))
                } label: {
                    if option.id == qualityID {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                noteText(quality.label, size: 13, weight: .semibold)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(theme.noteSolidText(role))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(theme.noteSolid(role), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Chord type")
        .accessibilityLabel("Chord type: \(quality.label)")
    }

    /// A choice tile. With a note `role`, it's tinted like that note and filled when selected (like
    /// a selected note); otherwise it's neutral and fills with `selectedColor` when selected.
    private func tile(
        _ title: String,
        caption: String? = nil,
        isSelected: Bool,
        role: NoteColorRole? = nil,
        selectedColor: Color = .accentColor,
        selectedTextColor: Color = .white,
        compact: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                // A small label above the name (a root's numeral in the key).
                if let caption {
                    noteText(caption, size: compact ? 9 : 10, weight: .semibold)
                        .opacity(0.8)
                }
                noteText(title, size: compact ? 13 : 14, weight: isSelected ? .semibold : .regular)
            }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.vertical, caption == nil ? 0 : (compact ? 3 : 4))
                // Compact tiles keep their natural width, like the song's chord chips.
                .padding(.horizontal, compact ? 9 : 0)
                .modifier(NoteTileStyle(
                    role: role,
                    isSelected: isSelected,
                    selectedColor: selectedColor,
                    selectedTextColor: selectedTextColor,
                    fillsWidth: !compact,
                    minHeight: compact ? 26 : 34,
                    showsColorBorder: !theme.isDark,
                    neutralFill: neutralTileFill
                ))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Pinned to the bottom of the sidebar: the selected chord and an Add button, with a menu to pick
/// which of the song's sections it goes into.
private struct SidebarAddBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    /// One row (the chord, then Add) inside the compact bank, rather than a pinned footer.
    var inline = false
    /// The chord picked in the bank (nil until one is), which Add adds.
    var bankChord: (root: Int, quality: ChordQuality)?
    /// The bank's key, which colors its notes.
    var key: MusicalKey?

    private var notes: [Note] {
        bankChord.map { ChordBank.notes(root: $0.root, quality: $0.quality) } ?? []
    }

    private func noteRole(for note: Note) -> NoteColorRole {
        NoteAppearance.colorRole(for: note, key: key)
    }

    var body: some View {
        let state = model.state
        let isFull = state.savedChords.count >= AppState.maxSavedChords
        if inline {
            // The chord and its Add button together on one small card.
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            HStack(spacing: 12) {
                summary
                Spacer(minLength: 0)
                addButton
                    .fixedSize()
            }
            .padding(.leading, 12)
            .padding(.trailing, 5)
            .padding(.vertical, 5)
            .background(theme.instrumentBackground, in: shape)
            .overlay(shape.strokeBorder(theme.cardBorder, lineWidth: 1))
            .help(isFull ? "This song has \(AppState.maxSavedChords) chords and scales, the maximum. Delete one to add more." : "")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                summary
                addButton
                if isFull {
                    Text("This song has \(AppState.maxSavedChords) chords and scales, the maximum. Delete one to add more.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .modifier(BankFooterStyle())
        }
    }

    @ViewBuilder
    private var summary: some View {
        if let bankChord {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    noteText(chordDisplayName(ChordBank.name(root: bankChord.root, quality: bankChord.quality)), size: 15, weight: .semibold)
                        .fixedSize()
                    HStack(spacing: 4) {
                        ForEach(notes, id: \.self) { note in
                            let role = noteRole(for: note)
                            noteText(note.name, size: 12, weight: .medium)
                                .foregroundStyle(theme.noteSolidText(role))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.noteSolid(role), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .accessibilityElement(children: .combine)
        } else {
            Text("Pick a chord")
                .font(.system(size: 13))
                .foregroundStyle(theme.mutedText)
                .lineLimit(1)
        }
    }

    /// "Add to Verse ▾" for the bank's chord.
    private var addButton: some View {
        let canAdd = bankChord != nil && model.state.savedChords.count < AppState.maxSavedChords
        // In the bank chord's color (its root's, like the song's chips), blue until one's picked.
        let role = bankChord.map { noteRole(for: Note(midi: 60 + $0.root)) }
        return AddToSectionButton(role: role, canAdd: canAdd, height: inline ? 30 : 36, fillsWidth: !inline) {
            model.addBankChord(notes)
        }
    }
}

/// "Add to Verse" with a ▾ listing the song's sections ("Add to Song" for a one-section song).
/// Picking a section from the ▾ adds there and makes it the default for later adds. Filled with
/// the chord's color.
struct AddToSectionButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.isCompactLayout) private var isCompact
    let role: NoteColorRole?
    let canAdd: Bool
    var height: CGFloat = 30
    var fillsWidth = false
    /// The key that does the same, for the tooltip.
    var shortcut: String?
    /// Adds the chord to `model.addTargetSectionID` (set first when picked from the menu).
    let add: () -> Void

    private var target: (section: ChordSection, index: Int)? {
        // Sections off: one list, so no section to name.
        let sections = model.visibleSections
        guard sections.count > 1 else { return nil }
        let id = model.addTargetSectionID ?? model.state.activeSectionID
        let index = sections.firstIndex { $0.id == id } ?? sections.count - 1
        return (sections[index], index)
    }

    var body: some View {
        let sections = model.visibleSections
        let name = target.map { $0.section.displayName(index: $0.index) }
        // Gray while there's nothing to add (no chord picked), else the chord's color.
        let fill = canAdd ? (role.map(theme.noteSolid) ?? theme.primaryButton) : theme.cardButton
        let textColor = canAdd ? (role.map(theme.noteSolidText) ?? .white) : theme.iconDisabled
        if isCompact {
            compactBody(sections: sections, fill: fill, textColor: textColor)
        } else {
        HStack(spacing: 0) {
            Button(action: add) {
                Text(name.map { "Add to \($0)" } ?? "Add to Song")
                    .lineLimit(1)
                    .padding(.horizontal, fillsWidth ? 0 : 14)
                    .frame(maxWidth: fillsWidth ? .infinity : nil)
                    .frame(height: height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
            .help("Add this chord to \(name ?? model.state.activeSet.name)" + (shortcut.map { " (\($0))" } ?? ""))

            if sections.count > 1 {
                Rectangle()
                    .fill(textColor.opacity(0.3))
                    .frame(width: 1, height: 20)
                Menu {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        Button {
                            model.bankTargetSectionID = section.id
                            if canAdd { add() }
                        } label: {
                            if target?.section.id == section.id {
                                Label(section.displayName(index: index), systemImage: "checkmark")
                            } else {
                                Text(section.displayName(index: index))
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: height, height: height)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Add to another section, and add there from now on")
                .accessibilityLabel("Add to another section")
            }
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(textColor)
        .background(fill, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    /// Narrow: just "Add". With sections it opens a menu of them; picking one adds there and makes
    /// it the default.
    @ViewBuilder
    private func compactBody(sections: [ChordSection], fill: Color, textColor: Color) -> some View {
        if Device.isPhone {
            phoneBody(sections: sections)
        } else {
            labeledCompactBody(sections: sections, fill: fill, textColor: textColor)
        }
    }

    /// iPhone: a plain + icon button like the others beside it, opening the sections menu.
    @ViewBuilder
    private func phoneBody(sections: [ChordSection]) -> some View {
        let icon = Image(systemName: "plus")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(canAdd ? theme.icon : theme.iconDisabled)
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
        if sections.count > 1 {
            Menu {
                sectionItems(sections)
            } label: {
                icon.iconHoverFill()
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Add to the song")
        } else {
            Button(action: add) { icon }
                .buttonStyle(HighlightButtonStyle(highlighted: theme.hover, cornerRadius: 8))
                .disabled(!canAdd)
                .accessibilityLabel("Add to the song")
        }
    }

    /// One "Add to …" item per section; picking one adds there and makes it the default.
    private func sectionItems(_ sections: [ChordSection]) -> some View {
        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
            // No checkmark on the default: picking is the point here.
            Button("Add to \(section.displayName(index: index))") {
                model.bankTargetSectionID = section.id
                if canAdd { add() }
            }
        }
    }

    @ViewBuilder
    private func labeledCompactBody(sections: [ChordSection], fill: Color, textColor: Color) -> some View {
        let label = HStack(spacing: 6) {
            Text("Add")
            if sections.count > 1 {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: height)
        .contentShape(Rectangle())

        Group {
            if sections.count > 1 {
                Menu {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        Button {
                            model.bankTargetSectionID = section.id
                            if canAdd { add() }
                        } label: {
                            if target?.section.id == section.id {
                                Label("Add to \(section.displayName(index: index))", systemImage: "checkmark")
                            } else {
                                Text("Add to \(section.displayName(index: index))")
                            }
                        }
                    }
                } label: {
                    label
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
            } else {
                Button(action: add) { label }
                    .buttonStyle(.plain)
                    .disabled(!canAdd)
            }
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(textColor)
        .background(fill, in: RoundedRectangle(cornerRadius: 8))
        .help("Add this chord to the song")
    }
}

/// The chord bank's pinned footer: a bar across the panel in light mode; in dark mode a card,
/// like the selected chord's under the instruments.
private struct BankFooterStyle: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        if theme.isDark {
            InstrumentCard {
                content.padding(16)
            }
            .padding(12)
            .background(theme.pageBackground)
        } else {
            content
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
        }
    }
}

/// The footer's two buttons: a quiet one and a blue one, sized alike.
private struct BankButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        BankButtonBody(configuration: configuration, prominent: prominent)
    }

    private struct BankButtonBody: View {
        let configuration: Configuration
        let prominent: Bool
        @Environment(\.theme) private var theme
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            let highlighted = isEnabled && (isHovered || configuration.isPressed)
            let fill = prominent
                ? (highlighted ? theme.primaryButtonHover : theme.primaryButton)
                : (highlighted ? theme.hover : .clear)
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(prominent ? Color.white : theme.secondaryText)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(fill, in: RoundedRectangle(cornerRadius: 8))
                .opacity(isEnabled ? 1 : 0.4)
                .contentShape(RoundedRectangle(cornerRadius: 8))
                #if os(macOS)
                .onHover { isHovered = $0 }
                #endif
        }
    }
}
