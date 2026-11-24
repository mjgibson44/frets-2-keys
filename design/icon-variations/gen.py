# Writes the icon variation SVGs (1024×1024, full bleed: Apple applies its own corner mask),
# plus sheet.svg, a contact sheet for checking them together.
import pathlib
out = pathlib.Path(__file__).parent

RAINBOW = ["#EF4444", "#F97316", "#EAB308", "#22C55E", "#06B6D4", "#3B82F6"]
RED, YEL, CYN = "#EF4444", "#EAB308", "#06B6D4"
GOLD, IVORY, PAPER, SILVER = "#EBCB6B", "#FAFAF9", "#F4F4F5", "#D4D4D8"

def lin(id, stops, x1, y1, x2, y2):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<linearGradient id="{id}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>'

def backdrop(id, top, bottom):
    return lin(id, [(0, top), (1, bottom)], 0, 0, 0, 1024), f'<rect width="1024" height="1024" fill="url(#{id})"/>'

def headstock(x, y, w, h, fill, hole):
    """A block headstock: six string holes, three tuning pegs on each side."""
    k = w / 200
    p = []
    for cy in (y + h*0.231, y + h*0.5, y + h*0.769):
        for edge, d in ((x, -1), (x + w, 1)):
            stem = (edge - 38*k, 40*k) if d < 0 else (edge - 2*k, 40*k)
            knob = edge - 54*k if d < 0 else edge + 26*k
            p.append(f'<rect x="{stem[0]:.1f}" y="{cy - 7*k:.1f}" width="{stem[1]:.1f}" height="{14*k:.1f}" fill="{fill}"/>')
            p.append(f'<rect x="{knob:.1f}" y="{cy - 19*k:.1f}" width="{28*k:.1f}" height="{38*k:.1f}" rx="{6*k:.1f}" fill="{fill}"/>')
    p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{20*k:.1f}" fill="{fill}"/>')
    for cx in (x + w*0.25, x + w*0.75):
        for cy in (y + h*0.231, y + h*0.5, y + h*0.769):
            p.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{20*k:.1f}" fill="{hole}"/>')
    return "\n".join(p)

def keys3(x, y, w, h, fill, cut):
    """Three white keys; the two black keys are cut out of them."""
    k = w / 252
    gap = 10*k
    kw = (w - 2*gap) / 3
    p = [f'<rect x="{x + i*(kw+gap):.1f}" y="{y}" width="{kw:.1f}" height="{h}" rx="{10*k:.1f}" fill="{fill}"/>' for i in range(3)]
    for i in (1, 2):
        cx = x + i*(kw+gap) - gap/2
        p.append(f'<rect x="{cx - 24*k:.1f}" y="{y - 1}" width="{48*k:.1f}" height="{h*0.575 + 1:.1f}" rx="{9*k:.1f}" fill="{cut}"/>')
    return "\n".join(p)

def loops(stroke_for, width=13):
    s = []
    for i in range(6):
        x, y, w, h = 200 + 24*i, 96 + 24*i, 624 - 48*i, 832 - 48*i
        s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{w/2}" fill="none" stroke="{stroke_for(i)}" stroke-width="{width}"/>')
    return "\n".join(s)

def full_loop(pid, top, bottom, stroke_for, width, head, keys):
    d, r = backdrop(pid + "bg", top, bottom)
    bg = f"url(#{pid}bg)"
    gaps = f'<rect x="170" y="356" width="236" height="312" fill="{bg}"/><rect x="596" y="356" width="292" height="312" fill="{bg}"/>'
    return d, r + loops(stroke_for, width) + gaps + headstock(188, 378, 200, 268, head, bg) + keys3(616, 378, 252, 268, keys, bg)

# Half-loop geometry: the instruments sit side by side and six strings join them in one curve.
CX, R0, STEP, HALF_W = 524, 350, 34, 20
def half_loop(pid, top, bottom, stroke_for, head, keys, arch=False):
    d, r = backdrop(pid + "bg", top, bottom)
    bg = f"url(#{pid}bg)"
    paths = []
    for i in range(6):
        rad = R0 - STEP*i
        paths.append(f'<path d="M{CX-rad} 442 L{CX-rad} 524 A{rad} {rad} 0 0 0 {CX+rad} 524 L{CX+rad} 442" fill="none" stroke="{stroke_for(i)}" stroke-width="{HALF_W}"/>')
    strings = "\n".join(paths)
    y = 132
    if arch:  # mirrored: a rainbow over the instruments
        strings = f'<g transform="translate(0 1024) scale(1 -1)">{strings}</g>'
        y = 1024 - 482
    # Hides the string ends behind the keys, which would otherwise show through the gaps between them.
    backing = f'<rect x="676" y="{y}" width="250" height="350" fill="{bg}"/>'
    return d, r + strings + backing + headstock(144, y, 230, 350, head, bg) + keys3(676, y, 250, 350, keys, bg)

def keyboard(x0, x1, y0, y1, gap, rx=14, fill="#FAFAFA"):
    w = (x1 - x0 - 6*gap) / 7
    rects = [f'<rect x="{x0 + k*(w+gap):.1f}" y="{y0}" width="{w:.1f}" height="{y1-y0}" rx="{rx}" fill="{fill}"/>' for k in range(7)]
    gaps = [x0 + w + gap/2 + k*(w+gap) for k in range(6)]
    centers = [x0 + w/2 + k*(w+gap) for k in range(7)]
    return rects, gaps, centers

def black_keys(gaps, y0, w, h, fill="#3F3F46", outline="#161618", r=12):
    return [f'<path d="M{g - w/2:.1f} {y0} h{w} v{h-r} a{r} {r} 0 0 1 -{r} {r} h-{w - 2*r} a{r} {r} 0 0 1 -{r} -{r} z" fill="{fill}" stroke="{outline}" stroke-width="8" paint-order="stroke"/>'
            for i, g in enumerate(gaps) if i != 2]

def fan(xs, gaps, widths, stroke_for, y_start, y_fan, y_keys, y_end):
    """Strings run straight, then spread into the gaps between the white keys."""
    span = y_keys - y_fan
    return [f'<path d="M{x} {y_start} L{x} {y_fan} C{x} {y_fan + span*0.55:.1f} {g:.1f} {y_keys - span*0.55:.1f} {g:.1f} {y_keys} L{g:.1f} {y_end}" fill="none" stroke="{stroke_for(i)}" stroke-width="{widths[i]}"/>'
            for i, (x, g) in enumerate(zip(xs, gaps))]

def sq(cx, cy, c, s=54):
    return f'<rect x="{cx - s/2:.1f}" y="{cy - s/2:.1f}" width="{s}" height="{s}" rx="{s*0.26:.1f}" fill="{c}"/>'

DARK = ("#202024", "#111113")

def c1(pid):
    d, r = backdrop(pid + "bg", *DARK)
    sx = [362, 422, 482, 542, 602, 662]
    rects, gaps, cen = keyboard(108, 916, 600, 920, 18)
    p = [r] + rects + ['<rect x="330" y="142" width="364" height="16" rx="4" fill="#EA580C"/>']
    p += [f'<rect x="340" y="{y-3}" width="344" height="6" rx="3" fill="#52525B"/>' for y in (250, 350, 450)]
    p += fan(sx, gaps, [9, 8, 7, 6, 5, 4.5], lambda i: SILVER, -10, 460, 600, 920)
    p += black_keys(gaps, 592, 62, 202)
    p += [sq(422, 400, RED), sq(482, 300, YEL), sq(542, 86, CYN), sq(602, 200, RED), sq(662, 86, YEL)]
    p += [sq(cen[0], 860, RED, 60), sq(cen[2], 860, YEL, 60), sq(cen[4], 860, CYN, 60)]
    return d, "\n".join(p)

def c2(pid):
    """Rainbow strings over a nut and two frets, spreading into full-bleed keys."""
    d, r = backdrop(pid + "bg", *DARK)
    sx = [397, 443, 489, 535, 581, 627]
    rects, gaps, cen = keyboard(0, 1024, 590, 1060, 26, rx=10)
    p = [r] + rects
    p += [f'<rect x="373" y="{y-4}" width="278" height="8" rx="4" fill="#52525B"/>' for y in (60, 172)]
    p.append('<rect x="365" y="280" width="294" height="22" rx="6" fill="#E7E5E4"/>')
    p += fan(sx, gaps, [20, 18, 16, 15, 14, 13], lambda i: RAINBOW[i], -10, 302, 590, 1060)
    p += black_keys(gaps, 580, 88, 250)
    return d, "\n".join(p)

def c3(pid):
    """C1 pared down: one square per chord tone on each instrument, everything bolder."""
    d, r = backdrop(pid + "bg", *DARK)
    sx = [347, 413, 479, 545, 611, 677]
    rects, gaps, cen = keyboard(80, 944, 580, 930, 20)
    p = [r] + rects + ['<rect x="315" y="141" width="394" height="18" rx="5" fill="#EA580C"/>']
    p += [f'<rect x="325" y="{y-3}" width="374" height="6" rx="3" fill="#52525B"/>' for y in (250, 350, 450)]
    p += fan(sx, gaps, [12, 11, 10, 9, 8, 7], lambda i: SILVER, -10, 460, 580, 930)
    p += black_keys(gaps, 572, 70, 210)
    p += [sq(413, 400, RED, 70), sq(479, 300, YEL, 70), sq(545, 80, CYN, 70)]
    p += [sq(cen[0], 866, RED, 72), sq(cen[2], 866, YEL, 72), sq(cen[4], 866, CYN, 72)]
    return d, "\n".join(p)

def c4(pid, head, stroke_for, extra_defs=""):
    """The headstock from A/B on top, its strings spreading into full-bleed keys."""
    d, r = backdrop(pid + "bg", *DARK)
    sx = [432, 464, 496, 528, 560, 592]
    rects, gaps, cen = keyboard(0, 1024, 610, 1060, 24, rx=10)
    p = [r] + rects
    p += fan(sx, gaps, [17, 16, 15, 14, 13, 12], stroke_for, 330, 400, 610, 1060)
    p += black_keys(gaps, 600, 86, 240)
    p.append(headstock(402, 70, 220, 290, head, f"url(#{pid}bg)"))
    return d + extra_defs, "\n".join(p)

def build():
    v = []
    gold = lambda pid, x1, x2: lin(pid + "str", [(0, GOLD), (1, "#FFFFFF")], x1, 0, x2, 0)
    d, b = full_loop("a", "#3A3A3F", "#202023", lambda i: "url(#astr)", 13, GOLD, IVORY)
    v.append(("a-refined", "A · Refined", "Unchanged from the last round.", d + gold("a", 200, 824), b))
    d, b = half_loop("a2", "#3A3A3F", "#202023", lambda i: "url(#a2str)", GOLD, IVORY)
    v.append(("a2-half-loop", "A2 · No top loop", "A with only the bottom loop. The headstock and keys are about 25% taller and the strings half as thick again.", d + gold("a2", 174, 874), b))
    d, b = full_loop("b1", "#232327", "#0C0C0E", lambda i: RAINBOW[i], 14, PAPER, PAPER)
    v.append(("b1-loop", "B1 · Full loop", "B from the last round, for comparison.", d, b))
    d, b = half_loop("b2", "#232327", "#0C0C0E", lambda i: RAINBOW[i], PAPER, PAPER)
    v.append(("b2-half-loop", "B2 · No top loop", "B with only the bottom loop, drawn larger like A2.", d, b))
    d, b = half_loop("b3", "#232327", "#0C0C0E", lambda i: RAINBOW[i], PAPER, PAPER, arch=True)
    v.append(("b3-arch", "B3 · Arch", "B2 turned over, so the strings make a rainbow above the instruments.", d, b))
    d, b = c1("c1")
    v.append(("c1-chord", "C1 · Chord", "C from the last round, for comparison.", d, b))
    d, b = c3("c3")
    v.append(("c2-pared-down", "C2 · Pared down", "C1 with one square per chord tone on each instrument, and thicker strings and larger squares.", d, b))
    d, b = c2("c2")
    v.append(("c3-rainbow", "C3 · Rainbow strings", "No note squares. B's coloured strings cross a nut and spread into keys that fill the width.", d, b))
    d, b = c4("c4", PAPER, lambda i: RAINBOW[i])
    v.append(("c4-headstock", "C4 · Headstock", "B's headstock on top, with its coloured strings spreading into the keys.", d, b))
    d, b = c4("c5", GOLD, lambda i: "url(#c5str)", lin("c5str", [(0, GOLD), (1, "#FFFFFF")], 0, 360, 0, 610))
    v.append(("c5-headstock-gold", "C5 · Headstock, gold", "C4 in A's colours: a gold headstock and strings that fade to white at the keys.", d, b))
    return v

if __name__ == "__main__":
    variants = build()
    for slug, name, desc, defs, body in variants:
        (out / f"{slug}.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024"><defs>{defs}</defs>{body}</svg>\n')
    # Contact sheet: every variant with a rounded mask, large and at 2× home-screen size.
    size, pad, cols = 300, 24, 4
    rows = -(-len(variants) // cols)
    small = 96
    W = cols*(size+pad) + pad
    H = max(W, rows*(size+pad) + pad + small + pad)
    cells = []
    for n, (slug, name, desc, defs, body) in enumerate(variants):
        inner = f'<defs>{defs}<clipPath id="k{n}"><rect width="1024" height="1024" rx="229"/></clipPath></defs><g clip-path="url(#k{n})">{body}</g>'
        x, y = pad + (n % cols)*(size+pad), pad + (n // cols)*(size+pad)
        cells.append(f'<svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="0 0 1024 1024">{inner}</svg>')
        cells.append(f'<svg x="{pad + n*(small+pad)}" y="{rows*(size+pad) + pad}" width="{small}" height="{small}" viewBox="0 0 1024 1024"><g clip-path="url(#k{n})">{body}</g></svg>')
    (out / "sheet.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}"><rect width="{W}" height="{H}" fill="#9CA3AF"/>{"".join(cells)}</svg>\n')
    print(len(variants), W, H)
