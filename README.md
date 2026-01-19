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
