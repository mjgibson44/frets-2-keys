# App icon

`icon.svg` is the source of the app icon: three strings looping from a guitar headstock to piano keys. It's square and full-bleed, because iOS rounds the corners itself.

It's one of the variations that `gen.py` draws. `CHOSEN` at the top of `gen.py` names the one the app uses, and `gen.py` writes that one as `icon.svg`.

## Updating the icon in the app

```bash
python3 gen.py                                    # rewrites icon.svg and the other variations
qlmanage -t -s 1024 -o /tmp/f2k-icon icon.svg
swift export.swift /tmp/f2k-icon/icon.svg.png ../../apple/Frets2Keys/Assets.xcassets/AppIcon.appiconset
```

`export.swift` writes `icon-1024.png` for iPhone and iPad (square, no alpha channel) and `icon-mac-*.png` for the Mac (Apple's rounded icon shape on a transparent canvas, with a soft shadow).

## The other variations

`gen.py` also draws the variations that were considered: more strings, larger and smaller instruments, other string colours and styles, half loops, and strings fanning into keys. They're generated files and aren't checked in.

Both scripts below take slug prefixes to show only some of them, for example `python3 gallery.py a11 a20`.

- `python3 gallery.py` builds `gallery.html`: each one large and at home-screen sizes.
- `python3 homescreen.py` builds `homescreen.html`: each one on a mocked-up iPhone home screen.
