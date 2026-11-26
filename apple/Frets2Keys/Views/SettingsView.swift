import SwiftUI
import Frets2KeysCore

struct SettingsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case playback = "Playback"
        case labels = "Labels"
        case instruments = "Instruments"
        var id: Self { self }
    }

    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("settingsTab") private var tab = Tab.general

    var body: some View {
        VStack(spacing: 0) {
            // Title, tabs and Done along the top, divided off like the main window's top bar.
            HStack(spacing: 12) {
                Text("Settings")
                    .font(.headline)
                Spacer(minLength: 0)
                Button("Done") { dismiss() }
                    .buttonStyle(SettingsButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)
            HStack(spacing: 4) {
                ForEach(Tab.allCases) { option in
                    tabButton(option)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            SectionDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch tab {
                    case .general: general
                    case .playback: playback
                    case .labels: labels
                    case .instruments: instruments
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(theme.pageBackground.ignoresSafeArea())
        .foregroundStyle(theme.primaryText)
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 560, idealHeight: 680)
        #endif
    }

    private func tabButton(_ option: Tab) -> some View {
        let isSelected = tab == option
        return Button {
            tab = option
        } label: {
            Text(option.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? theme.primaryText : theme.mutedText)
                .padding(.horizontal, 12)
                .frame(height: 28)
        }
        .buttonStyle(HighlightButtonStyle(
            normal: isSelected ? theme.cardButtonHover : .clear,
            highlighted: isSelected ? theme.cardButtonHover : theme.cardButton,
            cornerRadius: 6
        ))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Tabs

    @ViewBuilder
    private var general: some View {
        SettingsCard(title: "Help") {
            SettingsRow("Tutorial") {
                Button("View Tutorial") {
                    // Shown once this sheet has finished dismissing (see ContentView).
                    model.showTutorialAfterSettings = true
                    dismiss()
                }
                .buttonStyle(SettingsButtonStyle())
            }
        }
        SettingsCard(title: "Sync") {
            Label("Your songs sync through iCloud to your other devices signed in to the same Apple Account.", systemImage: "icloud")
                .font(.system(size: 13))
                .foregroundStyle(theme.secondaryText)
        }
    }

    @ViewBuilder
    private var playback: some View {
        @Bindable var model = model
        SettingsCard(title: "Playback", footer: "A looped chord lasts one beat; arpeggios play two notes a beat.") {
            Picker("Playback Mode", selection: $model.state.playMode) {
                Text("Chord").tag(PlayMode.chord)
                Text("Arpeggio").tag(PlayMode.arpeggio)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            SettingsRow("Sound") {
                Picker("Sound", selection: Binding(
                    get: { model.state.instrument },
                    set: { model.setInstrument($0) }
                )) {
                    ForEach(SynthInstrument.allCases) { instrument in
                        Text(instrument.name).tag(instrument)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            TempoControl(tempo: $model.state.tempo)
        }
        SettingsCard(title: "Looping", footer: "While looping, the instruments show the next chord's notes in a lighter color over each chord's last two beats.") {
            Toggle("Show next chord", isOn: $model.state.showNextChord)
        }
    }

    @ViewBuilder
    private var labels: some View {
        @Bindable var model = model
        SettingsCard(title: "Label notes with", footer: "Degrees number notes in the key (1, 2, ♭3…). Intervals measure from the selected chord's root (R, 3, 5, ♭7…). Without a key or chord, notes show their names. Press N to switch.") {
            Picker("Label Notes With", selection: $model.state.noteLabelContent) {
                ForEach(NoteLabelContent.allCases) { content in
                    Text(content.title).tag(content)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        SettingsCard(title: "Accidentals") {
            Picker("Accidentals", selection: $model.state.noteLabelMode) {
                Text("Sharps and Flats").tag(NoteLabelMode.sharpsAndFlats)
                Text("Sharps only").tag(NoteLabelMode.sharpsOnly)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        SettingsCard(title: "Notes outside the key", footer: model.state.selectedKey == nil ? "Choose a key to hide notes outside of it." : nil) {
            Picker("Notes outside the key", selection: $model.state.keyLabelMode) {
                Text("Hide").tag(KeyLabelMode.onlyInKey)
                Text("Show dimmed").tag(KeyLabelMode.showAll)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(model.state.selectedKey == nil)
        }
    }

    @ViewBuilder
    private var instruments: some View {
        @Bindable var model = model
        SettingsCard(title: "Show") {
            Toggle("Guitar 1", isOn: Binding(
                get: { model.state.fretboards.count >= 1 },
                set: { model.state.setFretboardCount($0 ? max(1, model.state.fretboards.count) : 0) }
            ))
            Toggle("Guitar 2", isOn: Binding(
                get: { model.state.fretboards.count == 2 },
                set: { model.state.setFretboardCount($0 ? 2 : 1) }
            ))
            Toggle("Piano", isOn: $model.state.showPiano)
        }
        ForEach(0..<AppState.maxFretboards, id: \.self) { index in
            TuningSection(index: index)
        }
    }
}

/// A titled group of settings on a card, like the instruments', with an optional note below.
private struct SettingsCard<Accessory: View, Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    var footer: String?
    let accessory: Accessory
    @ViewBuilder let content: Content

    init(title: String, footer: String? = nil, @ViewBuilder accessory: () -> Accessory, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.mutedText)
                Spacer(minLength: 0)
                accessory
            }
            InstrumentCard {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension SettingsCard where Accessory == EmptyView {
    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, footer: footer, accessory: { EmptyView() }, content: content)
    }
}

/// A label on the left and its control on the right.
private struct SettingsRow<Control: View>: View {
    let label: String
    @ViewBuilder let control: Control

    init(_ label: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .lineLimit(1)
            Spacer(minLength: 0)
            control
        }
    }
}

/// A quiet button on the settings' cards, like the selected chord's buttons.
private struct SettingsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SettingsButtonBody(configuration: configuration)
    }

    private struct SettingsButtonBody: View {
        let configuration: Configuration
        @Environment(\.theme) private var theme
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    (isHovered || configuration.isPressed) && isEnabled ? theme.hover : .clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .opacity(isEnabled ? 1 : 0.4)
                .contentShape(RoundedRectangle(cornerRadius: 6))
                #if os(macOS)
                .onHover { isHovered = $0 }
                #endif
        }
    }
}

/// Tempo in beats per minute: a slider for quick changes and a field for an exact number.
private struct TempoControl: View {
    @Binding var tempo: Int
    @State private var text = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        let range = AppState.tempoRange
        VStack(spacing: 8) {
            HStack {
                Text("Tempo")
                Spacer()
                HStack(spacing: 4) {
                    // Forms on the Mac show a control's label beside it, so hide it (VoiceOver still reads it).
                    TextField("BPM", text: $text)
                        .labelsHidden()
                        .focused($isEditing)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 44)
                        .monospacedDigit()
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #else
                        .textFieldStyle(.roundedBorder)
                        #endif
                        .onSubmit(commit)
                        .accessibilityLabel("Tempo in beats per minute")
                    Text("BPM")
                        .foregroundStyle(.secondary)
                }
                .fixedSize()
            }
            // Rounded here rather than with `step`, which draws a tick for every value.
            Slider(
                value: Binding(get: { Double(tempo) }, set: { tempo = Int($0.rounded()) }),
                in: Double(range.lowerBound)...Double(range.upperBound)
            ) {
                Text("Tempo")
            } minimumValueLabel: {
                Image(systemName: "tortoise.fill").foregroundStyle(.secondary)
            } maximumValueLabel: {
                Image(systemName: "hare.fill").foregroundStyle(.secondary)
            }
            .labelsHidden()
            .accessibilityValue("\(tempo) beats per minute")
        }
        .onAppear { text = "\(tempo)" }
        .onChange(of: tempo) { _, newValue in
            if !isEditing { text = "\(newValue)" }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { commit() }
        }
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isEditing = false }
            }
        }
        #endif
    }

    /// Applies the typed number, kept within range; anything else puts the current tempo back.
    private func commit() {
        if let value = Int(text.trimmingCharacters(in: .whitespaces)) {
            tempo = AppState.clampedTempo(value)
        }
        text = "\(tempo)"
    }
}

/// Tuning, string count and capo controls for one fretboard.
private struct TuningSection: View {
    @Environment(AppModel.self) private var model
    let index: Int

    var body: some View {
        let fretboard = model.state.fretboards.indices.contains(index) ? model.state.fretboards[index] : nil
        let tuning = fretboard?.tuning ?? Tunings.standard
        let capo = fretboard?.capo ?? 0

        SettingsCard(title: "Guitar \(index + 1) tuning") {
            Button("Reset") {
                if let fretboard { model.state.resetTuning(for: fretboard.id) }
            }
            .buttonStyle(SettingsButtonStyle())
        } content: {
            SettingsRow("Preset") {
                Picker("Preset", selection: presetBinding(fretboard)) {
                    Text("Custom").tag("")
                    ForEach(TuningPreset.categories, id: \.self) { category in
                        Section(category) {
                            ForEach(TuningPreset.all.filter { $0.category == category }) { preset in
                                Text(preset.name).tag(preset.id)
                            }
                        }
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            SettingsRow("Number of strings") {
                Stepper(value: stringCountBinding(fretboard, count: tuning.count), in: Tunings.minStrings...Tunings.maxStrings) {
                    Text("\(tuning.count)").monospacedDigit()
                }
                .fixedSize()
            }

            // Highest string first, numbered like a guitar (string 1 = high E).
            ForEach(Array(tuning.indices.reversed()), id: \.self) { stringIndex in
                let number = tuning.count - stringIndex
                SettingsRow(Tunings.stringLabel(number: number, totalStrings: tuning.count)) {
                    HStack(spacing: 8) {
                        StepButton(symbol: "minus", label: "Lower string \(number)") {
                            if let fretboard { model.state.adjustString(stringIndex, by: -1, for: fretboard.id) }
                        }
                        NoteField(note: tuning[stringIndex]) { note in
                            if let fretboard { model.state.setString(stringIndex, to: note, for: fretboard.id) }
                        }
                        .accessibilityLabel("String \(number) tuning")
                        StepButton(symbol: "plus", label: "Raise string \(number)") {
                            if let fretboard { model.state.adjustString(stringIndex, by: 1, for: fretboard.id) }
                        }
                    }
                }
            }

            SettingsRow("Capo") {
                HStack(spacing: 8) {
                    if capo > 0 {
                        Button {
                            if let fretboard { model.state.setCapo(0, for: fretboard.id) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Clear capo")
                        .accessibilityLabel("Clear capo")
                    }
                    Stepper(value: capoBinding(fretboard, capo: capo), in: 0...Tunings.maxCapo) {
                        Text(capo == 0 ? "None" : "Fret \(capo)").monospacedDigit()
                    }
                    .fixedSize()
                }
            }
        }
        .disabled(fretboard == nil)
        .opacity(fretboard == nil ? 0.4 : 1)
    }

    private func presetBinding(_ fretboard: Fretboard?) -> Binding<String> {
        Binding(
            get: { fretboard.flatMap { TuningPreset.matching($0.tuning)?.id } ?? "" },
            set: { id in
                guard let fretboard, let preset = TuningPreset.all.first(where: { $0.id == id }) else { return }
                model.state.setTuning(preset.tuning, for: fretboard.id)
            }
        )
    }

    private func stringCountBinding(_ fretboard: Fretboard?, count: Int) -> Binding<Int> {
        Binding(
            get: { count },
            set: { newCount in
                if let fretboard { model.state.setStringCount(newCount, for: fretboard.id) }
            }
        )
    }

    private func capoBinding(_ fretboard: Fretboard?, capo: Int) -> Binding<Int> {
        Binding(
            get: { capo },
            set: { newCapo in
                if let fretboard { model.state.setCapo(newCapo, for: fretboard.id) }
            }
        )
    }
}

private struct StepButton: View {
    @Environment(\.theme) private var theme
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(HighlightButtonStyle(highlighted: theme.hover, cornerRadius: 6))
        .accessibilityLabel(label)
    }
}

/// Text field for a note name like "E2" or "Bb3". Valid input is applied as you type;
/// invalid input is reverted when editing ends.
private struct NoteField: View {
    let note: Note
    let onCommit: (Note) -> Void
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Note", text: $text)
            .multilineTextAlignment(.center)
            .frame(width: 56)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.characters)
            #endif
            .focused($isFocused)
            .onAppear { text = note.description }
            .onChange(of: note) { _, newNote in
                if Note(parsing: text) != newNote { text = newNote.description }
            }
            .onChange(of: text) { _, newText in
                if let parsed = Note(parsing: newText), parsed != note { onCommit(parsed) }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { text = note.description }
            }
            .onSubmit { text = note.description }
    }
}
