# Builds gallery.html from gen.py's variants: each one large, then at home-screen, Spotlight and
# Settings sizes on light and dark wallpaper.
import base64, pathlib, subprocess, sys
here = pathlib.Path(__file__).parent
subprocess.run([sys.executable, str(here / "gen.py")], check=True, stdout=subprocess.DEVNULL)
sys.path.insert(0, str(here))
import gen

NEW = {"a11a-inset", "a11b-inset", "a20a-inset", "a20b-inset", "a21a-inset", "a21b-inset"}
# Slug prefixes to show, e.g. `python3 gallery.py a-refined a3 a4`; everything when none are given.
SHOW = tuple(sys.argv[1:])
GROUPS = [("A", "Strings loop from the headstock to the keys, in gold."),
          ("B", "The same idea in the app's scale-degree colours."),
          ("C", "Six strings become the six gaps between seven white keys.")]

def card(slug, name, desc):
    uri = "data:image/svg+xml;base64," + base64.b64encode((here / f"{slug}.svg").read_bytes()).decode()
    tag = '<span class="new">New</span>' if slug in NEW else ""
    sizes = "".join(f'<img src="{uri}" class="s{n}" alt="">' for n in (60, 40, 20))
    return f'''<section><img class="big" src="{uri}" alt="{name}">
<div class="meta"><h3>{name}{tag}</h3><p>{desc}</p>
<div class="walls"><div class="wall light">{sizes}</div><div class="wall dark">{sizes}</div></div></div></section>'''

variants = [v for v in gen.build() if not SHOW or v[0].startswith(SHOW)]
parts = []
for letter, blurb in GROUPS:
    cards = "".join(card(slug, name, desc) for slug, name, desc, _, _ in variants if slug.startswith(letter.lower()))
    if cards:
        parts.append(f'<h2>{letter} <span>{blurb}</span></h2><main>{cards}</main>')

html = f'''<!doctype html><html><head><meta charset="utf-8"><title>Frets 2 Keys icon variations</title>
<style>
body{{margin:0;padding:32px;font:15px/1.45 -apple-system,system-ui,sans-serif;background:#f4f4f5;color:#18181b}}
h1{{font-size:22px;margin:0 0 4px}} .lede{{margin:0 0 8px;color:#52525b}}
h2{{font-size:18px;margin:28px 0 12px}} h2 span{{font-weight:400;font-size:14px;color:#71717a;margin-left:6px}}
main{{display:grid;grid-template-columns:repeat(auto-fill,minmax(440px,1fr));gap:20px}}
section{{display:flex;gap:20px;background:#fff;border:1px solid #e4e4e7;border-radius:16px;padding:20px}}
.big{{width:180px;height:180px;border-radius:22.4%;flex:none;box-shadow:0 1px 3px rgba(0,0,0,.15)}}
h3{{font-size:16px;margin:0 0 6px}} p{{margin:0 0 12px;color:#52525b;font-size:14px}}
.new{{font-size:11px;font-weight:600;color:#1d4ed8;background:#dbeafe;border-radius:999px;padding:2px 8px;margin-left:8px;vertical-align:2px}}
.walls{{display:flex;gap:8px;flex-wrap:wrap}} .wall{{display:flex;align-items:center;gap:10px;padding:10px 12px;border-radius:10px}}
.light{{background:linear-gradient(135deg,#dbeafe,#fce7f3)}} .dark{{background:linear-gradient(135deg,#1e1b4b,#111827)}}
.s60{{width:60px;height:60px;border-radius:22.4%}} .s40{{width:40px;height:40px;border-radius:22.4%}} .s20{{width:20px;height:20px;border-radius:22.4%}}
@media (prefers-color-scheme:dark){{body{{background:#18181b;color:#f4f4f5}} section{{background:#27272a;border-color:#3f3f46}} p,.lede{{color:#a1a1aa}} h2 span{{color:#a1a1aa}} .new{{color:#bfdbfe;background:#1e3a8a}}}}
</style></head><body><h1>Frets 2 Keys — app icon variations</h1>
<p class="lede">Each shown large, then at home-screen (60), Spotlight (40) and Settings (20) sizes on light and dark wallpaper.</p>
{"".join(parts)}</body></html>'''
(here / "gallery.html").write_text(html)
print(len(variants), "variants,", len(html) // 1024, "KB")
