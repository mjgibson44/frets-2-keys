# App icon

`a-refined.svg` is the source of the app icon: six strings looping from a guitar headstock to piano keys. It's square and full-bleed, because iOS rounds the corners itself.

## Updating the icon in the app

```bash
python3 gen.py                                    # rewrites a-refined.svg and the other variations
qlmanage -t -s 1024 -o /tmp/f2k-icon a-refined.svg
swift export.swift /tmp/f2k-icon/a-refined.svg.png ../../apple/Frets2Keys/Assets.xcassets/AppIcon.appiconset
```

`export.swift` writes `icon-1024.png` for iPhone and iPad (square, no alpha channel) and `icon-mac-*.png` for the Mac (Apple's rounded icon shape on a transparent canvas, with a soft shadow).

## The other variations

`gen.py` also draws the variations that were considered (half loops, coloured strings, strings fanning into keys). They're generated files and aren't checked in.

- `python3 gallery.py` builds `gallery.html`: each one large and at home-screen sizes.
- `python3 homescreen.py` builds `homescreen.html`: each one on a mocked-up iPhone home screen.
