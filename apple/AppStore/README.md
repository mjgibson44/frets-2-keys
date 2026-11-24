# App Store assets

| Folder | Size | App Store Connect slot |
| --- | --- | --- |
| `Screenshots/iPhone-6.9` | 1320×2868 | iPhone 6.9" display |
| `Screenshots/iPad-13` | 2064×2752 | iPad 13" display |
| `Screenshots/Mac` | 2880×1800 | Mac |
| `Previews/iPhone-6.9-preview.mp4` | 886×1920, 30 fps, 24 s | iPhone 6.9" app preview |
| `Previews/iPad-13-preview.mp4` | 1200×1600, 30 fps, 27 s | iPad 13" app preview |

The previews have a silent audio track (App Store Connect requires one); add music before uploading if you want sound.

## Retaking them

The screenshots use a demo chord set ("Song Ideas", with Verse and Chorus sections and a saved A minor pentatonic scale).

- **iPhone and iPad:** use dedicated simulators. Before each launch, write the demo state into the app's `frets2keys_appState` default, and set the status bar to 9:41 with `xcrun simctl status_bar`.
- **Mac:** Debug builds accept launch arguments that keep everything away from your own saved chords and iCloud:
  - `-ScreenshotState <base64 JSON>` starts from that saved state, in a separate store with iCloud sync off.
  - `-ScreenshotSelect "F3 A3 C4 E4"` selects a chord.
  - `-ScreenshotBank` opens the chord bank.

  In this mode the window opens at 1440×900 without taking keyboard focus. Capture it with `screencapture -o -l <window id>`.
