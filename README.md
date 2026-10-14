# Frets 2 Keys

A visual tool for translating chords between piano and stringed instruments like guitar. Click notes on either instrument to see them highlighted on the other, hear how they sound, save chords, transpose them, and explore different musical keys.

## Features

- **Interactive Instruments** - Click notes on the guitar fretboard or piano keyboard to select them
- **Visual Translation** - See the same notes highlighted across both instruments
- **Audio Playback** - Hear notes as you click, play chords, or loop through saved progressions
- **Chord Recognition** - Automatically identifies chord names from selected notes
- **Save & Organize Chords** - Save up to 20 chords, drag to reorder, cycle through with arrow keys
- **Key Highlighting** - Select a major/minor key to see which notes belong to it
- **Customizable Tuning** - Configure string count (4-8), tuning, and capo position
- **Instrument Presets** - Guitar, bass, ukulele, mandolin, banjo tunings built-in
- **Multiple Fretboards** - Display up to 2 guitar fretboards with different tunings
- **Transpose** - Shift selected notes up or down by semitones
- **Dark Mode** - Toggle between light and dark themes
- **Keyboard Shortcuts** - Quick access to common actions
- **Persistent State** - Your settings and saved chords are preserved between sessions

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (version 18 or higher recommended)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/mjgibson44/frets-2-keys.git
   cd frets-2-keys
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm run dev
   ```

4. Open [http://localhost:3000](http://localhost:3000) in your browser

## iPhone, iPad and Mac App

A native SwiftUI version of Frets 2 Keys lives in [`apple/`](apple). One multiplatform target runs on iOS 17+, iPadOS 17+ and macOS 14+, with the same features as the web app: both instruments, chord recognition, saved chords (drag to reorder, or use the context menu), transpose, chord/arpeggio playback and looping, keys, tuning presets, capo, dark mode, keyboard shortcuts (hardware keyboards on iPad, and the **Chord** menu on Mac), and saved state.

The native app also adds:

- **Chord sets**: named groups of saved chords you can switch between, rename, duplicate and delete. Existing saved chords become "Set 1".
- **Chord bank**: pick common chords (21 types on any root) instead of building them note by note.
- **Scales**: choose any of 15 scales and modes (Dorian, pentatonics, blues, harmonic minor…) as the key, or save them in a set. Tapping a saved scale highlights it on the instruments, so you can see a chord against it.
- **Degrees and intervals**: label notes by name, by scale degree in the key (1 2 ♭3…), or by interval from the selected chord's root (R 3 5 ♭7…). Press N to switch.
- **Show next chord**: while looping, the instruments show the next chord's notes in a lighter color over each chord's last two beats.
- **Tempo and sounds**: set the tempo (60–180 BPM) and pick from seven synthesized sounds; notes flash as they play.
- **Sections**: split a set into sections like a verse and chorus. Drag chords between sections, reorder sections, and loop one section or the whole set.
- **iCloud sync**: chord sets sync between your iPhone, iPad and Mac through iCloud key-value storage. Each set merges independently, with the newest edit winning.
- **iPhone landscape**: turn the phone sideways to see just the guitar or just the piano, enlarged.

### Building

Requires Xcode 16 or later.

```bash
open apple/Frets2Keys.xcodeproj
```

Pick the **Frets2Keys** scheme and choose an iPhone/iPad simulator or **My Mac**, then Run. Signing uses team `YP8F3MJ2Y3` with the iCloud (key-value storage) capability, so Xcode needs to be signed in to that team's Apple Account.

### Layout

- `apple/Frets2KeysCore/`: a Swift package with the music logic (notes, keys, tunings, chord recognition, app state, loop sequencing, and the synth's sound generation), plus its unit tests. Run them with `cd apple/Frets2KeysCore && swift test`.
- `apple/Frets2Keys/`: the SwiftUI app (views, audio engine, persistence, iCloud sync, menus and keyboard handling).
- `apple/Frets2KeysUITests/`: UI tests (iPhone landscape mode).
- `apple/project.yml`: the [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec the Xcode project is generated from. After adding or removing source files, run `xcodegen generate` in `apple/` (install with `brew install xcodegen`).

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Clear selection | `Delete` / `Backspace` |
| Save as new chord | `A` |
| Update saved chord | `S` |
| Transpose up | `+` / `=` |
| Transpose down | `-` / `_` |
| Play chord | `Enter` |
| Toggle loop | `Space` |
| Previous chord | `Left Arrow` |
| Next chord | `Right Arrow` |

## Built With

- [Next.js](https://nextjs.org/) - React framework
- [Tailwind CSS](https://tailwindcss.com/) - Styling
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API) - Sound synthesis

## Author

Created by Matt Gibson in 2026
