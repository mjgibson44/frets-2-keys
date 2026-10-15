import SwiftUI
import Frets2KeysCore

/// The bottom of the window: two glass cards. The selected chord and its controls sit above the
/// chord set's saved chords. The selection card always shows (with a hint when nothing is
/// selected) so the instruments above don't jump.
struct ChordPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// A sideways iPhone has little height, so the saved chords share one scrolling row.
    private var usesSingleRow: Bool {
        Device.isPhone && verticalSizeClass == .compact
    }

    /// Upright on iPhone, saved chords wrap up to about three rows, then scroll within them.
    private static let phoneChipsMaxHeight: CGFloat = 3 * 37 + 2 * 8

    private var padding: CGFloat { Device.isPhone ? 14 : 16 }

    var body: some View {
        GlassCardGroup(spacing: 8) {
            VStack(spacing: 8) {
                SelectionBar()
                    .padding(.horizontal, padding)
                    .padding(.vertical, Device.isPhone ? 8 : 10)
                    .glassCard()
                setsCard
                    .glassCard()
            }
        }
    }

    /// The set menu, Add Chord and the set's sections, sized to its content.
    @ViewBuilder
    private var setsCard: some View {
        if usesSingleRow {
            // One row: set menu, saved chords scrolling sideways, then Add.
            HStack(spacing: 8) {
                SetMenu()
                ScrollView(.horizontal, showsIndicators: false) {
                    SectionsRow()
                        .padding(.vertical, 2)
                }
                AddChordButton(compact: true)
            }
            .padding(.horizontal, padding)
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: Device.isPhone ? 10 : 12) {
                HStack(spacing: 8) {
                    SetMenu()
                    Spacer(minLength: 0)
                    AddSectionButton()
                    AddChordButton()
                }
                if Device.isPhone {
                    // Grows with the set until it hits the cap, then scrolls.
                    let maxHeight = model.state.activeSet.sections.count > 1 ? Self.phoneSectionsMaxHeight : Self.phoneChipsMaxHeight
                    ViewThatFits(in: .vertical) {
                        SectionsList()
                        ScrollView(.vertical) {
                            SectionsList()
                        }
                        .scrollIndicators(.visible)
                    }
                    .frame(maxHeight: maxHeight)
                } else {
                    SectionsList()
                }
            }
            .padding(padding)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// With sections, a little more room before scrolling, for their headers.
    private static let phoneSectionsMaxHeight: CGFloat = 210
}

/// Groups glass cards so they blend together and morph as cards appear (iOS 26 and macOS 26).
struct GlassCardGroup<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension View {
    /// A floating Liquid Glass card, or a frosted material card before iOS 26 / macOS 26.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = cardCornerRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26, macOS 26, *) {
            frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: shape)
        } else {
            frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: shape)
        }
    }
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
            normal: model.isChordBankPresented ? theme.chipActive : theme.pageChip,
            highlighted: theme.chipHover,
            cornerRadius: 6
        ))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.pageChipBorder, lineWidth: 1))
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

/// Adds a section to the set (and asks for its name).
private struct AddSectionButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            withAnimation(.snappy) { model.addSection() }
        } label: {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .frame(width: 30, height: 27)
        }
        .buttonStyle(HighlightButtonStyle(normal: theme.pageChip, highlighted: theme.chipHover, cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.pageChipBorder, lineWidth: 1))
        .help("Add a section, like a verse or chorus")
        .accessibilityLabel("Add Section")
    }
}

// MARK: - Set menu

/// Shows the active set's name; the menu switches between sets and manages them.
struct SetMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        let state = model.state
        Menu {
            Section("Chord Sets") {
                ForEach(state.chordSets) { set in
                    Toggle(isOn: Binding(
                        get: { set.id == model.state.activeSetID },
                        set: { if $0 { model.selectSet(set.id) } }
                    )) {
                        Text(set.name)
                        Text(set.chords.count == 1 ? "1 item" : "\(set.chords.count) items")
                    }
                }
            }
            Divider()
            SetActions(model: model)
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
            .background(isHovered ? theme.hover : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        #if os(macOS)
        .onHover { isHovered = $0 }
        #else
        .hoverEffect(.highlight)
        #endif
        .padding(.leading, -8)
        .accessibilityLabel("Chord set: \(state.activeSet.name)")
    }
}

/// New / rename / duplicate / delete, shared by the set menu and the Mac menu bar.
struct SetActions: View {
    let model: AppModel

    var body: some View {
        let active = model.state.activeSetID
        Button("New Set", systemImage: "plus") { model.createSet() }
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

/// Which sections are collapsed on this device (not synced), as comma-separated IDs.
private struct CollapsedSections: DynamicProperty {
    @AppStorage("collapsedSections") private var stored = ""

    private var ids: Set<String> { Set(stored.split(separator: ",").map(String.init)) }

    func contains(_ id: UUID) -> Bool { ids.contains(id.uuidString) }

    func toggle(_ id: UUID) {
        var ids = ids
        if ids.contains(id.uuidString) { ids.remove(id.uuidString) } else { ids.insert(id.uuidString) }
        stored = ids.sorted().joined(separator: ",")
    }
}

/// The set's sections, one under another. A set with a single section shows just its chords, as
/// before sections existed.
private struct SectionsList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let sections = model.state.activeSet.sections
        if sections.count == 1, let only = sections.first {
            SectionChips(section: only, layout: .wrapping)
                .sectionDropTarget(only.id, model: model)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    SectionView(section: section, index: index, count: sections.count)
                }
            }
        }
    }
}

/// One section: a header (name, loop, add, menu) over its chords.
private struct SectionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var isDropTarget = false
    private let collapsed = CollapsedSections()
    let section: ChordSection
    let index: Int
    let count: Int

    var body: some View {
        let isCollapsed = collapsed.contains(section.id)
        VStack(alignment: .leading, spacing: 6) {
            header(isCollapsed: isCollapsed)
            if !isCollapsed {
                SectionChips(section: section, layout: .wrapping)
            }
        }
        .padding(6)
        .background {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 8).fill(Tailwind.blue500.opacity(0.08))
            }
        }
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Tailwind.blue500.opacity(0.6), lineWidth: 1.5)
            }
        }
        .padding(-6)
        .sectionDropTarget(section.id, model: model, isTargeted: $isDropTarget)
    }

    private func header(isCollapsed: Bool) -> some View {
        let name = section.displayName(index: index)
        let isLooping = model.loopingSectionID == section.id
        let chordCount = section.chords.filter { !$0.isScale }.count
        return HStack(spacing: 4) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { collapsed.toggle(section.id) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        .foregroundStyle(Tailwind.zinc500)
                        .frame(width: 12)
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                    if isCollapsed || section.chords.isEmpty {
                        Text("\(section.chords.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.mutedText)
                    }
                }
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name), \(section.chords.count) items")
            .accessibilityHint(isCollapsed ? "Expands the section" : "Collapses the section")
            // Drag a section by its header to reorder.
            .draggable(PanelDragItem.section(section.id).payload) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.chip, in: RoundedRectangle(cornerRadius: 6))
            }

            Spacer(minLength: 0)

            smallButton(
                isLooping ? "stop.fill" : ActionIcon.loop,
                help: isLooping ? "Stop looping \(name)" : "Loop \(name)",
                isEnabled: chordCount > 0 || isLooping,
                isActive: isLooping
            ) {
                model.toggleLoop(section: section.id)
            }
            smallButton("plus", help: "Add a chord or scale to \(name)") {
                withAnimation { model.openChordBank(section: section.id) }
            }
            Menu {
                Button("Rename…", systemImage: "pencil") { model.sectionBeingRenamed = section.id }
                Button("Add Chord or Scale", systemImage: "plus") { model.openChordBank(section: section.id) }
                Button(isLooping ? "Stop Loop" : "Loop Section", systemImage: ActionIcon.loop) { model.toggleLoop(section: section.id) }
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.icon)
                    .frame(width: 26, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Section options")
            .accessibilityLabel("\(name) options")
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Move Up") { model.shiftSection(section.id, by: -1) }
        .accessibilityAction(named: "Move Down") { model.shiftSection(section.id, by: 1) }
    }

    private func smallButton(_ symbol: String, help: String, isEnabled: Bool = true, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? .white : (isEnabled ? theme.icon : theme.iconDisabled))
                .frame(width: 26, height: 24)
        }
        .buttonStyle(HighlightButtonStyle(
            normal: isActive ? Tailwind.green500 : .clear,
            highlighted: isActive ? Color(hex: 0x16A34A) : theme.hover,
            cornerRadius: 6
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
            if showsEmptyText {
                let isOnly = model.state.activeSet.sections.count == 1
                Text(isOnly ? "No saved chords" : "Drag chords here, or tap +")
                    .font(.system(size: isOnly ? 14 : 13))
                    .foregroundStyle(theme.mutedText)
                    .frame(maxWidth: layout == .wrapping ? .infinity : nil, alignment: layout == .wrapping && isOnly ? .center : .leading)
                    .padding(.vertical, 4)
                    .padding(.leading, isOnly ? 0 : 18)
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
        let title = chord.scale?.shortName(sharpsOnly: state.sharpsOnly) ?? chord.name
        let spokenName = chord.scale.map { "\($0.name(sharpsOnly: state.sharpsOnly)) scale" } ?? chord.name
        let otherSections = state.activeSet.sections.enumerated().filter { $0.element.id != section.id }

        return HStack(spacing: 8) {
            HStack(spacing: 5) {
                if chord.isScale {
                    Image(systemName: "stairs")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.8)
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            Button {
                model.deleteChord(chord.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? .white.opacity(0.85) : theme.icon)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(HighlightButtonStyle(highlighted: (isActive ? Color.white : theme.icon).opacity(0.2), cornerRadius: 4))
            .help(chord.isScale ? "Delete scale" : "Delete chord")
            .accessibilityLabel("Delete \(spokenName)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        .help(chord.isScale ? "Show \(spokenName) on the instruments" : chord.name)
        .draggable(PanelDragItem.chord(chord.id).payload) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
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

/// The current selection (chord name and notes) with the actions that apply to it.
private struct SelectionBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        if Device.isPhone && verticalSizeClass == .regular {
            // Upright iPhone: the chord on one line, its controls spread across the next.
            VStack(alignment: .leading, spacing: 4) {
                summaryStrip
                controls(spread: true)
            }
        } else {
            // One row: a long chord's notes scroll sideways, the controls stay put.
            HStack(spacing: 8) {
                summaryStrip
                controls(spread: false)
            }
        }
    }

    private static let summaryHeight: CGFloat = 24

    private var summaryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            summary
                .padding(.vertical, 2)
                // Same height with or without a selection, so the card never resizes.
                .frame(minHeight: Self.summaryHeight)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    @ViewBuilder
    private var summary: some View {
        let state = model.state
        if state.hasSelection {
            HStack(spacing: 8) {
                if let chordName = state.chordName {
                    Text(chordName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityLabel("Chord: \(chordName)")
                }
                let context = state.noteLabelContext
                HStack(spacing: 4) {
                    ForEach(state.selectedNotes, id: \.self) { note in
                        // The web app shows sharp names here regardless of key; degrees and
                        // intervals match the instruments.
                        Text(state.noteLabelContent == .names ? note.name : context.label(for: note))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                NotePalette.solid(for: NoteAppearance.colorRole(for: note, key: state.selectedKey)),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                    }
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Selected notes: " + state.selectedNotes.map(\.description).joined(separator: ", "))
            }
        } else {
            // Short on phones so the hint and controls share one row.
            Text(layoutWidth >= 600 || verticalSizeClass == .regular ? "Tap notes to build a chord" : "Select notes")
                .font(.system(size: 13))
                .foregroundStyle(theme.mutedText)
                .lineLimit(1)
                .fixedSize()
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
}
