import SwiftUI
import Frets2KeysCore

/// The song along the bottom of the window. On iPhone the selected chord and its controls sit
/// above it, divided by a hairline; iPad and Mac give the selection its own card above the
/// instruments, and the song panel can be turned off.
struct ChordPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// A sideways iPhone has little height, so the saved chords share one scrolling row.
    private var usesSingleRow: Bool { false }

    /// Upright on iPhone, saved chords wrap up to about three rows, then scroll within them.
    private static let phoneChipsMaxHeight: CGFloat = 3 * 27 + 2 * 6

    /// The inset from the window's edges, lining the contents up with the top bar's.
    var padding: CGFloat = 16
    /// In the sidebar above the chord bank: just the set, with no Add Chord (the bank is right there).
    var inSidebar = false
    /// Grows to fit every section rather than scrolling within its own cap (when an outer area
    /// scrolls instead).
    var unboundedHeight = false

    var body: some View {
        // The selection has its own card in the top bar.
        setsCard
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The set menu, Add Chord and the set's sections, sized to its content.
    @ViewBuilder
    private var setsCard: some View {
        if usesSingleRow {
            // One row: set menu, saved chords scrolling sideways, then Add.
            HStack(spacing: 8) {
                SetMenu()
                SongPlayButton()
                SongActionsMenu()
                ScrollView(.horizontal, showsIndicators: false) {
                    SectionsRow()
                        .padding(.vertical, 2)
                }
                AddChordButton(compact: true)
            }
            .padding(.horizontal, padding)
            .padding(.vertical, 8)
        } else {
            let sections = model.state.activeSet.sections
            // An empty set says so on the same row as its menu and buttons.
            let emptySection = sections.count == 1 && sections[0].chords.isEmpty ? sections[0] : nil
            VStack(alignment: .leading, spacing: 12) {
                    // The song's name at the top left; its buttons at the right, lined up with the
                    // sections' (play over play, "..." over "...").
                    HStack(alignment: .center, spacing: 12) {
                        SetMenu()
                        if emptySection != nil {
                            Text("No saved chords")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.mutedText)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 4) {
                            // Where a section has its +.
                            Color.clear.frame(width: 28, height: 1)
                            SongPlayButton()
                            SongActionsMenu()
                        }
                        .frame(width: SectionView.buttonsWidth, alignment: .leading)
                    }
                if emptySection != nil {
                    EmptyView()
                } else if unboundedHeight {
                    SectionsList()
                } else {
                    // Grows with the song, then scrolls, so the instruments keep their room.
                    ViewThatFits(in: .vertical) {
                        SectionsList()
                        ScrollView(.vertical) {
                            SectionsList()
                        }
                    }
                    .frame(maxHeight: Self.songMaxHeight)
                }
            }
            .padding(.horizontal, padding)
            .padding(.vertical, inSidebar ? 0 : (Device.isPhone ? 12 : 16))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// iPad and Mac: about five sections' rows before the song scrolls.
    private static let songMaxHeight: CGFloat = 220

    /// With sections, room for the one section's header as well as its chords.
    private static let phoneSectionsMaxHeight: CGFloat = phoneChipsMaxHeight + 36
}

// MARK: - Add chord

/// Opens (or closes) the chord bank side panel.
private struct AddChordButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    /// Icon only, for the single-row iPhone layout.
    var compact = false

    var body: some View {
        Button {
            withAnimation {
                if model.isChordBankPresented {
                    model.isChordBankPresented = false
                } else {
                    model.openChordBank()
                }
            }
        } label: {
            Label("Add Chord", systemImage: "plus")
                .labelStyle(AddChordLabelStyle(compact: compact))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, compact ? 0 : 10)
                .padding(.vertical, compact ? 0 : 5)
                .frame(minWidth: compact ? 36 : nil, minHeight: compact ? 36 : nil)
        }
        .buttonStyle(HighlightButtonStyle(
            normal: model.isChordBankPresented ? theme.chipActive : .clear,
            highlighted: theme.hover,
            cornerRadius: 6
        ))
        .help("Choose a chord or scale from the chord bank")
        // The compact (icon-only) style still needs a spoken name.
        .accessibilityLabel("Add Chord")
        .accessibilityAddTraits(model.isChordBankPresented ? .isSelected : [])
    }
}

private struct AddChordLabelStyle: LabelStyle {
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        if compact {
            configuration.icon.font(.system(size: 15, weight: .semibold))
        } else {
            Label(configuration)
        }
    }
}

// MARK: - Set menu

/// The active song's name; it opens a searchable list that switches songs. Managing songs is in
/// `SongActionsMenu`.
struct SetMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var isHovered = false
    @State private var isOpen = false

    var body: some View {
        let state = model.state
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(state.activeSet.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tailwind.zinc500)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHovered || isOpen ? theme.hover : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        #if os(macOS)
        .onHover { isHovered = $0 }
        #else
        .hoverEffect(.highlight)
        #endif
        .padding(.leading, -8)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            SongSearchList { isOpen = false }
                .environment(\.theme, theme)
                .presentationCompactAdaptation(.popover)
        }
        .help("Switch songs")
        .accessibilityLabel("Song: \(state.activeSet.name)")
        .accessibilityHint("Shows the songs to switch to")
    }
}

/// A search field over your songs and the song bank; picking one of yours (or pressing Return for
/// the first match) switches to it, and picking a bank song adds a copy of it.
private struct SongSearchList: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool
    let onPick: () -> Void

    private var matches: [ChordSet] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return model.state.chordSets }
        return model.state.chordSets.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var bankMatches: [PresetSong] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return SongBank.songs }
        return SongBank.songs.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) || $0.artist.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search songs", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onSubmit {
                    if let first = matches.first {
                        pick(first)
                    } else if let first = bankMatches.first {
                        model.addSongFromBank(first)
                        onPick()
                    }
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if matches.isEmpty && bankMatches.isEmpty {
                        Text("No songs match")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.mutedText)
                            .padding(8)
                    }
                    ForEach(matches) { song in
                        row(song)
                    }
                    if !bankMatches.isEmpty {
                        // Popular songs to start from: picking one adds a copy to your songs.
                        Text("Song Bank")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.mutedText)
                            .padding(.horizontal, 8)
                            .padding(.top, matches.isEmpty ? 0 : 10)
                            .padding(.bottom, 2)
                        ForEach(bankMatches) { preset in
                            bankRow(preset)
                        }
                    }
                }
            }
            .frame(maxHeight: 360)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(width: 300)
        .onAppear { isSearchFocused = true }
    }

    private func row(_ song: ChordSet) -> some View {
        let isActive = song.id == model.state.activeSetID
        return Button {
            pick(song)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(isActive ? 1 : 0)
                Text(song.name)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(song.chords.count == 1 ? "1 item" : "\(song.chords.count) items")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedText)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
        }
        .buttonStyle(HighlightButtonStyle(highlighted: theme.hover, cornerRadius: 6))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func bankRow(_ preset: PresetSong) -> some View {
        Button {
            model.addSongFromBank(preset)
            onPick()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.icon)
                Text(preset.title)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(preset.artist)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
        }
        .buttonStyle(HighlightButtonStyle(highlighted: theme.hover, cornerRadius: 6))
        .help("Add a copy of \(preset.title) to your songs")
    }

    private func pick(_ song: ChordSet) {
        model.selectSet(song.id)
        onPick()
    }
}

/// Plays the whole song on a loop, or stops it. Green while the song is playing.
private struct SongPlayButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        let isPlaying = model.isLooping && model.loopingSectionID == nil && !model.isLoopingSelection
        let isEnabled = model.state.canLoop || isPlaying
        Button {
            model.toggleSongLoop()
        } label: {
            Image(systemName: isPlaying ? ActionIcon.stop : ActionIcon.play)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isPlaying ? .white : (isEnabled ? theme.icon : theme.iconDisabled))
                .frame(width: 28, height: 27)
        }
        .buttonStyle(HighlightButtonStyle(
            normal: isPlaying ? Tailwind.green500 : .clear,
            highlighted: isPlaying ? Color(hex: 0x16A34A) : theme.hover,
            cornerRadius: 8
        ))
        .disabled(!isEnabled)
        .help(isPlaying ? "Stop the song" : "Play the song")
        .accessibilityLabel(isPlaying ? "Stop the song" : "Play the song")
    }
}

/// The "..." beside the song: new, rename, duplicate, delete and add a section.
struct SongActionsMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            SetActions(model: model)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.icon)
                .frame(width: 28, height: 27)
                .contentShape(Rectangle())
                .iconHoverFill()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Song options")
        .accessibilityLabel("Song options")
    }
}

/// New / rename / duplicate / delete, shared by the song menu and the Mac menu bar.
struct SetActions: View {
    let model: AppModel

    var body: some View {
        let active = model.state.activeSetID
        Button("New Song", systemImage: "plus") { model.createSet() }
        Button("Rename…", systemImage: "pencil") { model.setBeingRenamed = active }
        Button("Duplicate", systemImage: "plus.square.on.square") { model.duplicateSet(active) }
        Button("Delete…", systemImage: "trash", role: .destructive) { model.setPendingDeletion = active }
        Divider()
        Button("Add Section", systemImage: "rectangle.stack.badge.plus") { model.addSection() }
    }
}

// MARK: - Sections

/// What's being dragged around the chord panel: a chord (or scale), or a whole section.
enum PanelDragItem {
    case chord(UUID)
    case section(UUID)

    private static let chordPrefix = "f2k-chord:"
    private static let sectionPrefix = "f2k-section:"

    var payload: String {
        switch self {
        case .chord(let id): return Self.chordPrefix + id.uuidString
        case .section(let id): return Self.sectionPrefix + id.uuidString
        }
    }

    init?(_ payload: String) {
        if payload.hasPrefix(Self.chordPrefix), let id = UUID(uuidString: String(payload.dropFirst(Self.chordPrefix.count))) {
            self = .chord(id)
        } else if payload.hasPrefix(Self.sectionPrefix), let id = UUID(uuidString: String(payload.dropFirst(Self.sectionPrefix.count))) {
            self = .section(id)
        } else {
            return nil
        }
    }
}

/// The set's sections, one under another. A set with a single section shows just its chords, as
/// before sections existed.
private struct SectionsList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let sections = model.state.activeSet.sections
        // One row per section, even a lone one.
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                SectionView(section: section, index: index, count: sections.count)
            }
        }
    }
}

/// Upright iPhone: one section at a time, to keep the panel short. It follows the chord being
/// played or picked, and a newly added section.
private struct OneSectionList: View {
    @Environment(AppModel.self) private var model
    /// The section showing on this device (not synced).
    @AppStorage("phoneSectionID") private var shownID = ""

    var body: some View {
        let sections = model.state.activeSet.sections
        Group {
            if sections.count == 1, let only = sections.first {
                SectionChips(section: only, layout: .wrapping)
                    .sectionDropTarget(only.id, model: model)
            } else {
                let index = sections.firstIndex { $0.id.uuidString == shownID } ?? 0
                SectionView(section: sections[index], index: index, count: sections.count) { id in
                    shownID = id.uuidString
                }
            }
        }
        .onChange(of: model.state.activeChordID) { _, id in
            if let id, let section = sections.first(where: { $0.chords.contains { $0.id == id } }) {
                shownID = section.id.uuidString
            }
        }
        .onChange(of: model.sectionBeingRenamed) { _, id in
            if let id { shownID = id.uuidString }
        }
    }
}

/// One section: a header (name, loop, menu) over its chords.
private struct SectionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var isDropTarget = false
    @State private var isHovered = false
    @Environment(\.isCompactLayout) private var isCompact
    let section: ChordSection
    let index: Int
    let count: Int
    /// iPhone, one section at a time: the section's name becomes a menu that switches to another.
    var onSwitch: ((UUID) -> Void)?

    /// The song panel's columns (iPad and Mac): names, chords, then buttons (+, play, menu) at the right.
    static let nameWidth: CGFloat = 96
    static let buttonsWidth: CGFloat = 3 * 28 + 2 * 4

    /// iPad and Mac lay a section out as one row: name, its chords, then its buttons.
    private var isRow: Bool { onSwitch == nil }

    var body: some View {
        Group {
            if isRow && isCompact {
                // Narrow: the name and buttons on one line, the chords underneath.
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        title(name: section.displayName(index: index))
                        Spacer(minLength: 0)
                        buttons
                            .frame(width: Self.buttonsWidth, alignment: .leading)
                    }
                    SectionChips(section: section, layout: .wrapping, showsEmptyText: false)
                }
            } else if isRow {
                HStack(alignment: .top, spacing: 12) {
                    title(name: section.displayName(index: index))
                        .frame(width: Self.nameWidth, alignment: .leading)
                        .padding(.top, 4)
                    SectionChips(section: section, layout: .wrapping, showsEmptyText: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 1)
                    buttons
                        .frame(width: Self.buttonsWidth, alignment: .leading)
                }
                .accessibilityElement(children: .contain)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    header
                    SectionChips(section: section, layout: .wrapping)
                }
            }
        }
        .padding(6)
        .background {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 8).fill(Tailwind.blue500.opacity(0.08))
            } else if isHovered {
                // Hovering anywhere on a section shades the whole row.
                RoundedRectangle(cornerRadius: 8).fill(theme.cardButton)
            }
        }
        #if os(macOS)
        .onHover { isHovered = $0 }
        #endif
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Tailwind.blue500.opacity(0.6), lineWidth: 1.5)
            }
        }
        .padding(-6)
        .sectionDropTarget(section.id, model: model, isTargeted: $isDropTarget)
    }

    private var header: some View {
        let name = section.displayName(index: index)
        return HStack(spacing: 4) {
            if let onSwitch {
                switcher(name: name, onSwitch: onSwitch)
            } else {
                title(name: name)
            }

            Spacer(minLength: 0)

            buttons
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Move Up") { model.shiftSection(section.id, by: -1) }
        .accessibilityAction(named: "Move Down") { model.shiftSection(section.id, by: 1) }
    }

    /// The chord bank's target (iPad and Mac), play, and the section's menu.
    private var buttons: some View {
        let name = section.displayName(index: index)
        let isLooping = model.loopingSectionID == section.id
        let chordCount = section.chords.filter { !$0.isScale }.count
        return HStack(spacing: 4) {
            if isRow {
                smallButton("plus", help: "Add chords from the chord bank to \(name)") {
                    withAnimation { model.openChordBank(section: section.id) }
                }
            }
            smallButton(
                isLooping ? ActionIcon.stop : ActionIcon.play,
                help: isLooping ? "Stop \(name)" : "Play \(name)",
                isEnabled: chordCount > 0 || isLooping,
                isActive: isLooping
            ) {
                model.toggleLoop(section: section.id)
            }
            Menu {
                Button("Rename…", systemImage: "pencil") { model.sectionBeingRenamed = section.id }
                Button("Add Chord or Scale", systemImage: "plus") { model.openChordBank(section: section.id) }
                Button(isLooping ? "Stop" : "Play Section", systemImage: isLooping ? ActionIcon.stop : ActionIcon.play) { model.toggleLoop(section: section.id) }
                    .disabled(chordCount == 0 && !isLooping)
                Divider()
                Button("Move Up", systemImage: "arrow.up") { withAnimation(.snappy) { model.shiftSection(section.id, by: -1) } }
                    .disabled(index == 0)
                Button("Move Down", systemImage: "arrow.down") { withAnimation(.snappy) { model.shiftSection(section.id, by: 1) } }
                    .disabled(index == count - 1)
                Divider()
                Button("Delete Section…", systemImage: "trash", role: .destructive) { model.requestDeleteSection(section.id) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.icon)
                    .frame(width: 28, height: 27)
                    .contentShape(Rectangle())
                    .iconHoverFill()
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Section options")
            .accessibilityLabel("\(name) options")
        }
    }

    /// The section's name.
    private func title(name: String) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(theme.mutedText)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(section.chords.count) items")
        // Drag a section by its header to reorder.
        .draggable(PanelDragItem.section(section.id).payload) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.chip, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    /// The section's name, with a menu of the set's sections to switch to.
    private func switcher(name: String, onSwitch: @escaping (UUID) -> Void) -> some View {
        let sections = model.state.activeSet.sections
        return Menu {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, other in
                Toggle(isOn: Binding(get: { other.id == section.id }, set: { if $0 { onSwitch(other.id) } })) {
                    Text(other.displayName(index: index))
                    Text(other.chords.count == 1 ? "1 item" : "\(other.chords.count) items")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                Text("\(index + 1) of \(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.mutedText)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tailwind.zinc500)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Section: \(name), \(index + 1) of \(count)")
        .accessibilityHint("Shows another section")
    }

    private func smallButton(_ symbol: String, help: String, isEnabled: Bool = true, isActive: Bool = false, isOn: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? .white : (isOn ? theme.primaryText : (isEnabled ? theme.icon : theme.iconDisabled)))
                .frame(width: 28, height: 27)
        }
        .buttonStyle(HighlightButtonStyle(
            normal: isActive ? Tailwind.green500 : (isOn ? theme.hover : .clear),
            highlighted: isActive ? Color(hex: 0x16A34A) : (isOn ? theme.chipHover : theme.hover),
            cornerRadius: 8
        ))
        .disabled(!isEnabled)
        .help(help)
        .accessibilityLabel(help)
    }
}

private extension View {
    /// Dropping a chord here moves it to the end of the section; dropping a section here moves
    /// that section to this one's place.
    func sectionDropTarget(_ sectionID: UUID, model: AppModel, isTargeted: Binding<Bool>? = nil) -> some View {
        dropDestination(for: String.self) { items, _ in
            guard let payload = items.first, let item = PanelDragItem(payload) else { return false }
            withAnimation(.snappy) {
                switch item {
                case .chord(let id): model.moveChord(id, toSection: sectionID)
                case .section(let id): model.moveSection(id, to: sectionID)
                }
            }
            return true
        } isTargeted: { targeted in
            isTargeted?.wrappedValue = targeted
        }
    }
}

/// Every section's chords in one sideways row, with section names between them (a sideways iPhone).
private struct SectionsRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        let sections = model.state.activeSet.sections
        HStack(spacing: 8) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                if sections.count > 1 {
                    Text(section.displayName(index: index))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.mutedText)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.leading, index == 0 ? 0 : 4)
                        .sectionDropTarget(section.id, model: model)
                }
                SectionChips(section: section, layout: .row, showsEmptyText: sections.count == 1)
            }
        }
    }
}

// MARK: - Saved chord chips

private struct SectionChips: View {
    enum Layout { case wrapping, row }

    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var dropTargetID: UUID?
    let section: ChordSection
    let layout: Layout
    var showsEmptyText = true

    var body: some View {
        let chords = section.chords
        if chords.isEmpty {
            // A lone empty section says so; an empty one among others just shows its header.
            if showsEmptyText && model.state.activeSet.sections.count == 1 {
                Text("No saved chords")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.mutedText)
                    .frame(maxWidth: layout == .wrapping ? .infinity : nil, alignment: layout == .wrapping ? .center : .leading)
                    .padding(.vertical, 4)
            }
        } else {
            let container = layout == .row ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(FlowLayout(spacing: 8))
            container {
                ForEach(chords) { chord in
                    chip(chord)
                }
            }
        }
    }

    private func chip(_ chord: SavedChord) -> some View {
        let state = model.state
        let isActive = chord.scale.map { $0 == state.selectedKey } ?? (chord.id == state.activeChordID)
        let isDropTarget = chord.id == dropTargetID
        // Colored by the chord's root, like that note on the instruments (for the app's key).
        let role = chord.rootPitchClass.map { NoteAppearance.colorRole(for: Note(midi: 60 + $0), key: state.selectedKey) }
        let title = chord.scale?.shortName(sharpsOnly: state.sharpsOnly) ?? chordDisplayName(chord.name)
        let spokenName = chord.scale.map { "\($0.name(sharpsOnly: state.sharpsOnly)) scale" } ?? chord.name
        let otherSections = state.activeSet.sections.enumerated().filter { $0.element.id != section.id }

        return HStack(spacing: 4) {
            HStack(spacing: 5) {
                if chord.isScale {
                    Image(systemName: "stairs")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.8)
                }
                noteText(title, size: 13, weight: .medium)
                    .lineLimit(1)
                    .fixedSize()
            }
            Button {
                model.deleteChord(chord.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isActive ? (role.map(theme.noteSolidText) ?? .white).opacity(0.85) : theme.icon)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(HighlightButtonStyle(highlighted: isActive ? (role.map(theme.noteSolidText) ?? .white).opacity(0.2) : theme.hover, cornerRadius: 4))
            .help(chord.isScale ? "Delete scale" : "Delete chord")
            .accessibilityLabel("Delete \(spokenName)")
        }
        .padding(.leading, 9)
        .padding(.trailing, 5)
        .padding(.vertical, 5)
        .modifier(NoteTileStyle(
            role: role,
            isSelected: isActive,
            selectedColor: theme.chipActive,
            fillsWidth: false,
            cornerRadius: chord.isScale ? 14 : 4,
            neutralBorder: theme.pageChipBorder,
            showsColorBorder: chord.isScale,
            neutralFill: theme.pageChip
        ))
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: chord.isScale ? 14 : 4).stroke(Tailwind.blue500, lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 4))
        .onTapGesture { model.selectChord(chord.id) }
        .help(chord.isScale ? "Show \(spokenName) on the instruments" : chordDisplayName(chord.name))
        .draggable(PanelDragItem.chord(chord.id).payload) {
            noteText(title, size: 14, weight: .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.chip, in: RoundedRectangle(cornerRadius: 4))
        }
        .dropDestination(for: String.self) { items, _ in
            guard let payload = items.first, let item = PanelDragItem(payload) else { return false }
            withAnimation(.snappy) {
                switch item {
                case .chord(let id): model.moveChord(id, to: chord.id)
                case .section(let id): model.moveSection(id, to: section.id)
                }
            }
            return true
        } isTargeted: { targeted in
            if targeted {
                dropTargetID = chord.id
            } else if dropTargetID == chord.id {
                dropTargetID = nil
            }
        }
        .contextMenu {
            Button("Move Left", systemImage: "arrow.left") { model.shiftChord(chord.id, by: -1) }
                .disabled(!state.canShiftChord(id: chord.id, by: -1))
            Button("Move Right", systemImage: "arrow.right") { model.shiftChord(chord.id, by: 1) }
                .disabled(!state.canShiftChord(id: chord.id, by: 1))
            if !otherSections.isEmpty {
                Menu("Move to Section", systemImage: "rectangle.stack") {
                    ForEach(otherSections, id: \.element.id) { index, other in
                        Button(other.displayName(index: index)) { model.moveChord(chord.id, toSection: other.id) }
                    }
                }
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { model.deleteChord(chord.id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenName)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.selectChord(chord.id) }
        .accessibilityAction(named: "Delete") { model.deleteChord(chord.id) }
        .accessibilityAction(named: "Move Left") { model.shiftChord(chord.id, by: -1) }
        .accessibilityAction(named: "Move Right") { model.shiftChord(chord.id, by: 1) }
    }
}

// MARK: - Selection bar

/// The selected chord and its actions, in the top bar (iPad and Mac).
struct SelectionCard: View {
    var body: some View {
        SelectionBar(textControls: true)
    }
}

/// The current selection (chord name and notes) with the actions that apply to it.
private struct SelectionBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.isCompactLayout) private var isCompact
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// Labeled buttons instead of icons, for the roomier card on iPad and Mac.
    var textControls = false

    var body: some View {
        if textControls {
            // The key, the chord, its icon buttons, then Add to ▾.
            let state = model.state
            let role = state.chordRootPitchClass.map { NoteAppearance.colorRole(for: Note(midi: 60 + $0), key: state.selectedKey) }
            // The instruments' key (the chord bank has its own).
            let keyMenu = KeyPickerMenu(selection: Binding(
                get: { model.state.selectedKey },
                set: { model.state.selectedKey = $0 }
            ), showsScale: false, showsClef: true)
            .padding(.leading, -8)
            let add = AddToSectionButton(role: role, canAdd: state.canSaveAsNew, shortcut: "A") {
                model.saveAsNewChord()
            }
            .fixedSize()
            // A plain bar (no card or dividers).
            if isCompact {
                // Narrow windows and iPhone: the key and controls on one line, the chord beneath.
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 10) {
                        keyMenu
                        Spacer(minLength: 0)
                        iconControls
                        add
                    }
                    summaryStrip
                        .padding(.bottom, 4)
                }
            } else {
                HStack(spacing: 12) {
                    keyMenu
                    summaryStrip
                    iconControls
                    add
                }
            }
        } else {
            // One row: a long chord's notes scroll sideways, the controls stay put at the end.
            HStack(spacing: 8) {
                summaryStrip
                controls(spread: false)
            }
        }
    }

    private static let summaryHeight: CGFloat = 24

    /// The chord and as many of its notes as fit (at most 8), then "+X" for the rest.
    private var summaryStrip: some View {
        ViewThatFits(in: .horizontal) {
            summary(maxNotes: 8)
            summary(maxNotes: 7)
            summary(maxNotes: 6)
            summary(maxNotes: 5)
            summary(maxNotes: 4)
            summary(maxNotes: 3)
            summary(maxNotes: 2)
            summary(maxNotes: 1)
        }
        .padding(.vertical, 2)
        // Same height with or without a selection, so the card never resizes.
        .frame(minHeight: Self.summaryHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    @ViewBuilder
    private func summary(maxNotes: Int) -> some View {
        let state = model.state
        if state.hasSelection {
            HStack(spacing: 8) {
                if let chordName = state.chordName {
                    noteText(chordDisplayName(chordName), size: 14, weight: .semibold)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityLabel("Chord: \(chordName)")
                }
                let context = state.noteLabelContext
                let notes = state.selectedNotes
                let hidden = max(0, notes.count - maxNotes)
                HStack(spacing: 4) {
                    ForEach(notes.prefix(maxNotes), id: \.self) { note in
                        // The web app shows sharp names here regardless of key; degrees and
                        // intervals match the instruments.
                        noteText(state.noteLabelContent == .names ? note.name : context.label(for: note), size: 12, weight: .medium)
                            .foregroundStyle(theme.noteSolidText(NoteAppearance.colorRole(for: note, key: state.selectedKey)))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                theme.noteSolid(NoteAppearance.colorRole(for: note, key: state.selectedKey)),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                    }
                    if hidden > 0 {
                        Text("+\(hidden)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.cardButtonHover, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Selected notes: " + state.selectedNotes.map(\.description).joined(separator: ", "))
            }
        } else {
            // Short in narrow layouts; it truncates rather than pushing the bar wider.
            Text(isCompact ? "Tap notes" : "Tap notes to build a chord")
                .font(.system(size: 13))
                .foregroundStyle(theme.mutedText)
                .lineLimit(1)
        }
    }

    private func controls(spread: Bool) -> some View {
        let state = model.state
        let size: CGFloat = layoutWidth >= 600 && !spread ? 32 : 36
        return HStack(spacing: 0) {
            IconButton(symbol: ActionIcon.clear, help: "Clear selection (Delete)", size: size, isEnabled: state.hasSelection) {
                model.clearSelection()
            }
            IconButton(symbol: ActionIcon.update, help: "Update saved chord (S)", size: size, isEnabled: state.canUpdateActiveChord) {
                model.updateActiveChord()
            }
            IconButton(symbol: ActionIcon.saveNew, help: "Save as new chord (A)", size: size, isEnabled: state.canSaveAsNew) {
                model.saveAsNewChord()
            }
            IconButton(symbol: ActionIcon.transposeUp, help: "Transpose up 1 semitone (+)", size: size, isEnabled: state.hasSelection) {
                model.transpose(by: 1)
            }
            IconButton(symbol: ActionIcon.transposeDown, help: "Transpose down 1 semitone (-)", size: size, isEnabled: state.hasSelection) {
                model.transpose(by: -1)
            }
        }
        // Spread across the line, or packed at the end of the single row.
        .environment(\.iconButtonFillsWidth, spread)
        .fixedSize(horizontal: !spread, vertical: true)
    }

    /// Play, clear and transpose, as icon buttons. (Updating a saved chord is on the S key and the
    /// Chord menu.)
    private var iconControls: some View {
        let state = model.state
        return HStack(spacing: 0) {
            // Plays on a loop until pressed again, green while playing.
            // Repeats just this chord (the song's play button plays the song).
            IconButton(
                symbol: model.isLoopingSelection ? ActionIcon.stop : ActionIcon.play,
                help: model.isLoopingSelection ? "Stop (Space)" : "Play this chord on repeat (Space)",
                size: 30,
                isEnabled: state.hasSelection || model.isLoopingSelection,
                isActive: model.isLoopingSelection
            ) {
                model.toggleSelectionLoop()
            }
            IconButton(symbol: ActionIcon.clear, help: "Clear selection (Delete)", size: 30, isEnabled: state.hasSelection) {
                model.clearSelection()
            }
            IconButton(symbol: ActionIcon.transposeUp, help: "Transpose up 1 semitone (+)", size: 30, isEnabled: state.hasSelection) {
                model.transpose(by: 1)
            }
            IconButton(symbol: ActionIcon.transposeDown, help: "Transpose down 1 semitone (-)", size: 30, isEnabled: state.hasSelection) {
                model.transpose(by: -1)
            }
        }
        .fixedSize()
    }
}

