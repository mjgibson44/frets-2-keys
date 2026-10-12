import SwiftUI
import Frets2KeysCore

/// Pick a root and chord type, hear it, then add it to the active set or just select it.
struct ChordBankPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("chordBankRoot") private var root = 0
    @AppStorage("chordBankQuality") private var qualityID = ChordBank.qualities[0].id

    private var quality: ChordQuality {
        ChordBank.qualities.first { $0.id == qualityID } ?? ChordBank.qualities[0]
    }

    private var notes: [Note] { ChordBank.notes(root: root, quality: quality) }

    var body: some View {
        let isFull = model.state.savedChords.count >= AppState.maxSavedChords
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Chord Bank")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)
            }

            section("Root") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(0..<12, id: \.self) { pitchClass in
                        tile(noteNamesSharp[pitchClass], isSelected: root == pitchClass) {
                            root = pitchClass
                            model.preview(ChordBank.notes(root: pitchClass, quality: quality))
                        }
                    }
                }
            }

            section("Type") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 6)], spacing: 6) {
                    ForEach(ChordBank.qualities) { option in
                        tile(option.label, isSelected: qualityID == option.id) {
                            qualityID = option.id
                            model.preview(ChordBank.notes(root: root, quality: option))
                        }
                    }
                }
            }

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
                                NotePalette.solid(for: NoteAppearance.colorRole(for: note, key: model.state.selectedKey)),
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
                    dismiss()
                } label: {
                    Text("Select").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Show this chord on the instruments without saving it")

                Button {
                    model.addBankChord(notes)
                    dismiss()
                } label: {
                    Text("Add to Set")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
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
        .padding(20)
        .frame(idealWidth: 400, maxWidth: 460)
        #if os(iOS)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        #endif
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func tile(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? .white : theme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(isSelected ? Color.accentColor : theme.chip, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
