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

### Building

Requires Xcode 16 or later.

```bash
open apple/Frets2Keys.xcodeproj
```

Pick the **Frets2Keys** scheme and choose an iPhone/iPad simulator or **My Mac**, then Run. To install on a physical iPhone or iPad, select your team under *Signing & Capabilities* first.

### Layout

- `apple/Frets2KeysCore/`: a Swift package with the music logic (notes, keys, tunings, chord recognition, app state, loop sequencing, and the synth's sound generation), plus its unit tests. Run them with `cd apple/Frets2KeysCore && swift test`.
- `apple/Frets2Keys/`: the SwiftUI app (views, audio engine, persistence, menus and keyboard handling).
- `apple/project.yml`: the [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec the Xcode project is generated from. After adding or removing source files, run `xcodegen generate` in `apple/` (install with `brew install xcodegen`).
- `apple/tools/make-icon.swift`: redraws the app icon.

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
