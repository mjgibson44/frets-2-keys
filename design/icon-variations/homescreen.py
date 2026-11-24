# Builds homescreen.html: every icon variation on a mocked-up iPhone home screen, among generic
# placeholder apps, with a light and a dark wallpaper.
import base64, pathlib, subprocess, sys
here = pathlib.Path(__file__).parent
subprocess.run([sys.executable, str(here / "gen.py")], check=True, stdout=subprocess.DEVNULL)
sys.path.insert(0, str(here))
import gen

def grad(id, a, b):
    return f'<linearGradient id="{id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>'

GRADS = "".join(grad(*g) for g in [
    ("g-blue", "#38BDF8", "#2563EB"), ("g-green", "#4ADE80", "#16A34A"), ("g-red", "#FB7185", "#E11D48"),
    ("g-gray", "#9CA3AF", "#4B5563"), ("g-silver", "#E5E7EB", "#9CA3AF"), ("g-orange", "#FDBA74", "#EA580C"),
    ("g-purple", "#C084FC", "#7E22CE"), ("g-amber", "#FCD34D", "#F59E0B"), ("g-sunset", "#FDBA74", "#EC4899"),
    ("g-yellow", "#FDE047", "#EAB308"),
])
T = '<rect width="60" height="60" fill="{}"/>'
bars = "".join(f'<rect x="{11 + i*4.6:.1f}" y="{30 - h/2}" width="2.6" height="{h}" rx="1.3" fill="{"#EF4444" if i < 6 else "#6B7280"}"/>' for i, h in enumerate([8, 16, 26, 14, 32, 20, 10, 18, 6]))
calc = "".join(f'<circle cx="{17 + c*13}" cy="{17 + r*13}" r="5" fill="{"#F59E0B" if c == 2 else "#D1D5DB" if r == 0 else "#6B7280"}"/>' for r in range(3) for c in range(3))
rem = "".join(f'<circle cx="15" cy="{y}" r="4" fill="{c}"/><rect x="24" y="{y - 1.2}" width="{w}" height="2.4" rx="1.2" fill="#D4D4D8"/>' for y, c, w in [(18, "#3B82F6", 24), (30, "#EF4444", 18), (42, "#F59E0B", 22)])
wallet = "".join(f'<rect x="11" y="{y}" width="38" height="22" rx="4" fill="{c}"/>' for y, c in [(13, "#3B82F6"), (19, "#F59E0B"), (25, "#22C55E"), (31, "#EF4444")])

# Simple stand-ins for neighbouring apps, each drawn on a 60×60 tile.
APPS = {
    "Calendar": T.format("#fff") + '<text x="30" y="17" font-size="9.5" font-weight="600" fill="#EF4444" text-anchor="middle">TUE</text><text x="30" y="47" font-size="31" font-weight="300" fill="#111" text-anchor="middle">24</text>',
    "Photos": T.format("url(#g-sunset)") + '<circle cx="42" cy="19" r="6" fill="#fff" opacity=".95"/><path d="M0 60 V44 L18 26 L32 42 L41 34 L60 50 V60 Z" fill="#fff" opacity=".9"/>',
    "Camera": T.format("url(#g-silver)") + '<rect x="12" y="20" width="36" height="25" rx="5" fill="#1F2937"/><rect x="23" y="15" width="14" height="8" rx="2.5" fill="#1F2937"/><circle cx="30" cy="32.5" r="8" fill="#9CA3AF"/><circle cx="30" cy="32.5" r="5" fill="#1F2937"/>',
    "Clock": T.format("#111") + '<circle cx="30" cy="30" r="23" fill="#fff"/><path d="M30 30 V14 M30 30 L41 36" stroke="#111" stroke-width="2.4" stroke-linecap="round"/><path d="M30 30 L20 42" stroke="#F97316" stroke-width="1.2"/><circle cx="30" cy="30" r="2" fill="#111"/>',
    "Weather": T.format("url(#g-blue)") + '<circle cx="22" cy="23" r="9" fill="#FDE047"/><g fill="#fff"><circle cx="24" cy="38" r="8"/><circle cx="34" cy="33" r="10"/><circle cx="43" cy="39.5" r="6.5"/><rect x="24" y="36" width="19" height="10"/></g>',
    "Notes": T.format("#fff") + '<rect width="60" height="15" fill="#FACC15"/><rect x="11" y="24" width="38" height="2.2" rx="1.1" fill="#D4D4D8"/><rect x="11" y="33" width="38" height="2.2" rx="1.1" fill="#D4D4D8"/><rect x="11" y="42" width="24" height="2.2" rx="1.1" fill="#D4D4D8"/>',
    "Reminders": T.format("#fff") + rem,
    "Maps": T.format("#E5E7EB") + '<path d="M0 0 H24 L0 16z" fill="#86EFAC"/><path d="M60 60 V36 L38 60z" fill="#93C5FD"/><path d="M-5 45 L65 20" stroke="#fff" stroke-width="7"/><path d="M20 -5 L38 65" stroke="#FDE68A" stroke-width="5"/><circle cx="31" cy="27" r="7" fill="#EF4444"/><circle cx="31" cy="27" r="2.6" fill="#fff"/>',
    "Files": T.format("#fff") + '<path d="M12 22 a4 4 0 0 1 4 -4 h9 l4 4 h15 a4 4 0 0 1 4 4 v16 a4 4 0 0 1 -4 4 h-28 a4 4 0 0 1 -4 -4 z" fill="#7DD3FC"/><rect x="12" y="26" width="36" height="20" rx="4" fill="#0EA5E9"/>',
    "Calculator": T.format("#1C1C1E") + calc,
    "Settings": T.format("url(#g-gray)") + '<circle cx="30" cy="30" r="15" fill="none" stroke="#E5E7EB" stroke-width="7" stroke-dasharray="5.2 4.22"/><circle cx="30" cy="30" r="12" fill="none" stroke="#E5E7EB" stroke-width="5"/><circle cx="30" cy="30" r="4" fill="#E5E7EB"/>',
    "Books": T.format("url(#g-orange)") + '<path d="M30 20 C25 16 17 16 12 18 V42 C17 40 25 40 30 44 Z" fill="#fff"/><path d="M30 20 C35 16 43 16 48 18 V42 C43 40 35 40 30 44 Z" fill="#fff" opacity=".85"/>',
    "Podcasts": T.format("url(#g-purple)") + '<circle cx="30" cy="27" r="4.5" fill="#fff"/><rect x="27" y="34" width="6" height="13" rx="3" fill="#fff"/><path d="M19.5 37 a13 13 0 1 1 21 0" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round"/>',
    "Stocks": T.format("#111") + '<path d="M8 46 H52" stroke="#525252" stroke-width="1.5"/><path d="M8 40 L18 34 L25 38 L34 24 L42 29 L52 16" stroke="#4ADE80" stroke-width="3" fill="none" stroke-linejoin="round" stroke-linecap="round"/>',
    "Home": T.format("url(#g-amber)") + '<path d="M30 14 L48 29 H43 V45 H34 V35 H26 V45 H17 V29 H12 Z" fill="#fff"/>',
    "Voice Memos": T.format("#1C1C1E") + bars,
    "Health": T.format("#fff") + '<path d="M30 45 C12 33 15 18 24 18 c3.5 0 5.5 2.5 6 4 c.5 -1.5 2.5 -4 6 -4 C45 18 48 33 30 45 Z" fill="#F43F5E"/>',
    "Wallet": T.format("#111") + wallet + '<rect x="11" y="37" width="38" height="12" rx="3" fill="#27272A"/>',
    "Tips": T.format("url(#g-yellow)") + '<circle cx="30" cy="26" r="11" fill="#fff"/><rect x="25" y="35" width="10" height="9" rx="2" fill="#fff"/><rect x="26.5" y="46" width="7" height="2.4" rx="1.2" fill="#fff"/>',
    "Messages": T.format("url(#g-green)") + '<ellipse cx="30" cy="28.5" rx="17" ry="14" fill="#fff"/><path d="M19 38 L15 46 L27 41 Z" fill="#fff"/>',
    "Mail": T.format("url(#g-blue)") + '<rect x="11" y="18" width="38" height="25" rx="4" fill="#fff"/><path d="M12.5 20.5 L30 33 L47.5 20.5" stroke="#3B82F6" stroke-width="2.2" fill="none" stroke-linejoin="round"/>',
    "Browser": T.format("#fff") + '<circle cx="30" cy="30" r="22" fill="url(#g-blue)"/><path d="M39 21 L33 33 L27 27 Z" fill="#EF4444"/><path d="M21 39 L27 27 L33 33 Z" fill="#fff"/>',
    "Music": T.format("url(#g-red)") + '<ellipse cx="22" cy="41" rx="5.5" ry="4.5" fill="#fff"/><ellipse cx="39" cy="37" rx="5.5" ry="4.5" fill="#fff"/><path d="M25.8 41 V18 L42.8 14 V37" stroke="#fff" stroke-width="3.4" fill="none" stroke-linejoin="round"/><path d="M25.8 18 L42.8 14 V20 L25.8 24 Z" fill="#fff"/>',
}
slug = lambda name: "i-" + name.lower().replace(" ", "-")
symbols = "".join(f'<symbol id="{slug(n)}" viewBox="0 0 60 60">{body}</symbol>' for n, body in APPS.items())

OURS = "Frets 2 Keys"
GRID = ["Calendar", "Photos", "Camera", "Clock",
        "Weather", "Notes", "Reminders", "Maps",
        "Files", OURS, "Calculator", "Settings",
        "Books", "Podcasts", "Stocks", "Home",
        "Voice Memos", "Health", "Wallet", "Tips"]
DOCK = ["Messages", "Mail", "Browser", "Music"]

STATUS = ('<svg class="sys" viewBox="0 0 78 14" width="78" height="14" fill="#fff"><rect x="0" y="9" width="3.4" height="4" rx="1"/><rect x="5" y="6.5" width="3.4" height="6.5" rx="1"/>'
          '<rect x="10" y="3.5" width="3.4" height="9.5" rx="1"/><rect x="15" y="0.5" width="3.4" height="12.5" rx="1"/>'
          '<path d="M25 5 a11 11 0 0 1 17 0 l-2.2 2.2 a8 8 0 0 0 -12.6 0 z M29.3 9.3 a5 5 0 0 1 8.4 0 L33.5 13.5 z"/>'
          '<rect x="49.5" y="1" width="24" height="12" rx="3.6" fill="none" stroke="#fff" stroke-opacity=".5"/><rect x="51.2" y="2.7" width="20.6" height="8.6" rx="2.2"/><rect x="74.8" y="4.8" width="1.6" height="4.4" rx=".8" fill-opacity=".5"/></svg>')

def tile(name, uri):
    if name == OURS:
        return f'<img class="ic" src="{uri}" alt="">'
    return f'<svg class="ic" viewBox="0 0 60 60"><use href="#{slug(name)}"/></svg>'

def phone(name, uri):
    grid = "".join(f'<div class="app">{tile(n, uri)}<span>{n}</span></div>' for n in GRID)
    dock = "".join(tile(n, uri) for n in DOCK)
    return f'''<figure><div class="phone"><div class="screen">
<div class="time">9:41</div><div class="island"></div>{STATUS}
<div class="grid">{grid}</div>
<div class="search"><svg viewBox="0 0 12 12" width="11" height="11"><circle cx="5" cy="5" r="3.6" fill="none" stroke="#fff" stroke-width="1.5"/><path d="M7.8 7.8 L11 11" stroke="#fff" stroke-width="1.5" stroke-linecap="round"/></svg>Search</div>
<div class="dock">{dock}</div></div></div><figcaption>{name}</figcaption></figure>'''

# Slug prefixes to show, e.g. `python3 homescreen.py a-refined a3 a4`; everything when none are given.
SHOW = tuple(sys.argv[1:])
phones = []
for s, name, desc, _, _ in gen.build():
    if SHOW and not s.startswith(SHOW):
        continue
    uri = "data:image/svg+xml;base64," + base64.b64encode((here / f"{s}.svg").read_bytes()).decode()
    phones.append(phone(name, uri))

html = f'''<!doctype html><html><head><meta charset="utf-8"><title>Frets 2 Keys icons on a home screen</title>
<style>
body{{margin:0;padding:28px 32px 48px;font:15px/1.45 -apple-system,system-ui,sans-serif;background:#f4f4f5;color:#18181b}}
h1{{font-size:22px;margin:0 0 4px}} .lede{{margin:0 0 16px;color:#52525b;max-width:70ch}}
input[name=w]{{position:absolute;opacity:0;pointer-events:none}}
.toggle{{display:inline-flex;background:#e4e4e7;border-radius:10px;padding:3px;margin-bottom:24px}}
.toggle label{{padding:6px 16px;border-radius:8px;font-size:14px;font-weight:500;cursor:pointer;color:#52525b}}
#w-light:checked~.toggle label[for=w-light],#w-dark:checked~.toggle label[for=w-dark]{{background:#fff;color:#18181b;box-shadow:0 1px 2px rgba(0,0,0,.12)}}
#w-light:focus-visible~.toggle label[for=w-light],#w-dark:focus-visible~.toggle label[for=w-dark]{{outline:2px solid #3b82f6;outline-offset:1px}}
main{{display:flex;flex-wrap:wrap;gap:32px 28px}}
figure{{margin:0}} figcaption{{margin-top:12px;font-weight:600;text-align:center}}
.phone{{zoom:.8;width:393px;height:852px;border:11px solid #0b0b0c;border-radius:66px;box-shadow:0 0 0 2px #52525b,0 18px 40px rgba(0,0,0,.22);position:relative;overflow:hidden;font-family:-apple-system,system-ui,sans-serif}}
.screen{{position:absolute;inset:0;background:linear-gradient(165deg,#7dd3fc 0%,#a5b4fc 48%,#f9a8d4 100%)}}
#w-dark:checked~main .screen{{background:linear-gradient(165deg,#0b1020 0%,#1e1b4b 55%,#3b0764 100%)}}
.time{{position:absolute;top:17px;left:0;width:133px;text-align:center;color:#fff;font-size:17px;font-weight:600;line-height:22px}}
.island{{position:absolute;top:11px;left:50%;margin-left:-63px;width:126px;height:37px;border-radius:19px;background:#000}}
.sys{{position:absolute;top:22px;right:30px}}
.grid{{position:absolute;top:80px;left:27px;right:27px;display:grid;grid-template-columns:repeat(4,60px);justify-content:space-between;row-gap:24px}}
.app{{position:relative;width:60px;height:78px}}
.app span{{position:absolute;top:65px;left:50%;transform:translateX(-50%);white-space:nowrap;font-size:11.5px;line-height:14px;color:#fff;text-shadow:0 0 5px rgba(0,0,0,.35)}}
.ic{{display:block;width:60px;height:60px;border-radius:13.5px;overflow:hidden}}
.search{{position:absolute;top:703px;left:50%;margin-left:-39px;width:78px;height:30px;border-radius:15px;background:rgba(255,255,255,.25);color:#fff;font-size:13px;display:flex;align-items:center;justify-content:center;gap:4px}}
.dock{{position:absolute;left:12px;right:12px;bottom:12px;height:94px;border-radius:38px;background:rgba(255,255,255,.3);display:flex;justify-content:space-between;align-items:center;padding:0 15px;box-sizing:border-box}}
#w-dark:checked~main .dock{{background:rgba(255,255,255,.14)}} #w-dark:checked~main .search{{background:rgba(255,255,255,.16)}}
@media (prefers-color-scheme:dark){{body{{background:#18181b;color:#f4f4f5}} .lede{{color:#a1a1aa}} .toggle{{background:#27272a}} .toggle label{{color:#a1a1aa}}
#w-light:checked~.toggle label[for=w-light],#w-dark:checked~.toggle label[for=w-dark]{{background:#52525b;color:#fff}}}}
</style></head><body>
<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>{GRADS}{symbols}</defs></svg>
<h1>Frets 2 Keys — icons on a home screen</h1>
<p class="lede">Each variation in the third row of an iPhone home screen, at about life size on a laptop display. The other apps are generic stand-ins.</p>
<input type="radio" name="w" id="w-light" checked><input type="radio" name="w" id="w-dark">
<div class="toggle" role="group" aria-label="Wallpaper"><label for="w-light">Light wallpaper</label><label for="w-dark">Dark wallpaper</label></div>
<main>{"".join(phones)}</main></body></html>'''
(here / "homescreen.html").write_text(html)
print(len(phones), "phones,", len(html) // 1024, "KB")
