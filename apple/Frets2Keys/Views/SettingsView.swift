import SwiftUI
import Frets2KeysCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Button {
                        // Shown once this sheet has finished dismissing (see ContentView).
                        model.showTutorialAfterSettings = true
                        dismiss()
                    } label: {
                        Label("View Tutorial", systemImage: "info.circle.fill")
                    }
                }

                Section("Playback Mode") {
                    Picker("Playback Mode", selection: $model.state.playMode) {
                        Text("Chord").tag(PlayMode.chord)
                        Text("Arpeggio").tag(PlayMode.arpeggio)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    Picker("Key Labels", selection: $model.state.keyLabelMode) {
                        Text("Only show notes in key").tag(KeyLabelMode.onlyInKey)
                        Text("Show all notes").tag(KeyLabelMode.showAll)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .disabled(model.state.selectedKey == nil)
                } header: {
                    Text("Key Labels")
                } footer: {
                    if model.state.selectedKey == nil {
                        Text("Choose a key to hide notes outside of it.")
                    }
                }

                Section("Note Labels") {
                    Picker("Note Labels", selection: $model.state.noteLabelMode) {
                        Text("Sharps and Flats").tag(NoteLabelMode.sharpsAndFlats)
                        Text("Sharps only").tag(NoteLabelMode.sharpsOnly)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section("Instruments") {
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
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 560, idealHeight: 720)
        #endif
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

        Section {
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

            Stepper(value: stringCountBinding(fretboard, count: tuning.count), in: Tunings.minStrings...Tunings.maxStrings) {
                LabeledContent("Number of strings", value: "\(tuning.count)")
            }

            // Highest string first, numbered like a guitar (string 1 = high E).
            ForEach(Array(tuning.indices.reversed()), id: \.self) { stringIndex in
                let number = tuning.count - stringIndex
                LabeledContent(Tunings.stringLabel(number: number, totalStrings: tuning.count)) {
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

            HStack {
                Stepper(value: capoBinding(fretboard, capo: capo), in: 0...Tunings.maxCapo) {
                    LabeledContent("Capo", value: capo == 0 ? "None" : "Fret \(capo)")
                }
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
            }
        } header: {
            HStack {
                Text("Guitar \(index + 1) Tuning")
                Spacer()
                Button("Reset") {
                    if let fretboard { model.state.resetTuning(for: fretboard.id) }
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .disabled(fretboard == nil)
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
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
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
