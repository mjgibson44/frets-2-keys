import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    private let actions: [(symbol: String, text: String)] = [
        (ActionIcon.clear, "Clear your selection of notes."),
        (ActionIcon.saveNew, "Save as a new chord."),
        (ActionIcon.update, "Update a previously saved chord."),
        (ActionIcon.transposeUp, "Transpose notes up/down."),
        (ActionIcon.play, "Play the chord once."),
        (ActionIcon.loop, "Play chords continuously in a loop."),
    ]

    private let shortcuts: [(action: String, keys: String)] = [
        ("Clear selection", "Delete"),
        ("Save as new chord", "A"),
        ("Update saved chord", "S"),
        ("Transpose up", "+ / ="),
        ("Transpose down", "- / _"),
        ("Play chord", "Return"),
        ("Toggle loop", "Space"),
        ("Notes / degrees / intervals", "N"),
        ("Previous chord", "←"),
        ("Next chord", "→"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome to Frets 2 Keys")
                            .font(.title2.bold())
                        Text("Created by Matt Gibson in 2026")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("This app allows you to visually translate chords from piano to a stringed instrument, like guitar, by interacting with either instrument. You can hear notes/chords, save them, transpose them, and also view different major/minor keys to help learn chords/notes within those keys.")
                        .bodyStyle()

                    section("Setting up the interface") {
                        Text("You can choose to have anywhere from 0 to 2 stringed instruments. Each stringed instrument's tuning, number of strings, and capo can be configured in the settings menu in the top right.")
                            .bodyStyle()
                    }

                    section("Keys") {
                        Text("You can choose to select a major/minor key from the menu in the top left to have notes highlighted for that selected key. More Scales has modes, pentatonics, blues and more. You can also choose how those notes will be displayed by going to the settings. You can hide notes outside of the key. You can also select \"No key\" and it will show all the notes without any highlighting.")
                            .bodyStyle()
                        Text("Notes can be labeled by name, by scale degree in the key (1, 2, ♭3…), or by interval from the selected chord's root (R, 3, 5, ♭7…). Switch in the key menu, or press N.")
                            .bodyStyle()
                    }

                    section("Core Actions") {
                        Text("Once you have selected one or more notes there are several actions you can do:")
                            .bodyStyle()
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(actions, id: \.symbol) { action in
                                HStack(spacing: 12) {
                                    Image(systemName: action.symbol)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(theme.icon)
                                        .frame(width: 32, height: 32)
                                        .background(theme.chip, in: RoundedRectangle(cornerRadius: 8))
                                    Text(action.text).bodyStyle()
                                }
                            }
                        }
                        Text("These controls sit under your saved chords, next to the chord you've selected. Saved chords can be reordered by dragging them, or from their context menu.")
                            .bodyStyle()
                    }

                    section("Chord Sets") {
                        Text("Saved chords belong to a chord set, such as a song or a practice routine. Use the set menu at the top of the chord panel to switch sets, or to create, rename, duplicate and delete them.")
                            .bodyStyle()
                        Text("Split a set into sections, like a verse and chorus, with the Add Section button. Drag chords between sections, drag a section's name to reorder it, or use the section's menu. Looping plays through the whole set, section by section, and each section can loop on its own.")
                            .bodyStyle()
                        Text("Your chord sets sync through iCloud to your other devices signed in to the same Apple Account.")
                            .bodyStyle()
                    }

                    section("Chord Bank") {
                        Text("Tap Add Chord to pick from common chords by root and type. You'll hear each one as you choose; then add it to the current set, or just select it to see it on the instruments. The Scales tab works the same way for scales: a saved scale shows on the instruments when you tap it, so you can see a chord against it.")
                            .bodyStyle()
                    }

                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        section("Landscape") {
                            Text("Turn your iPhone sideways to see one instrument at a time, as large as the screen allows. Switch between guitar and piano with the toggle at the top.")
                                .bodyStyle()
                        }
                    }
                    #endif

                    section("Keyboard Shortcuts") {
                        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                            ForEach(shortcuts, id: \.action) { shortcut in
                                GridRow {
                                    Text(shortcut.action).bodyStyle()
                                    Text(shortcut.keys)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(theme.chip, in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, idealWidth: 560, minHeight: 520, idealHeight: 680)
        #endif
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }
}

private extension Text {
    func bodyStyle() -> some View {
        self.font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
