"""The game's own look, for print: the same palette, fonts, Court Card
cloths, patterns and gold emblems as the app (lib/play/card_view.dart and
lib/theme.dart), drawn as SVG.

Gold is drawn with the app's gilt gradient (light at the top, dark at the
bottom). Gold that should be foil carries class="foil"; dark gold details
drawn over foil carry class="foilknock" so the foil plate leaves them out.
"""
from __future__ import annotations

import math

# --- palette (lib/theme.dart) ----------------------------------------------

FELT = "#0F4A2E"
FELT_DEEP = "#0A3622"
CARD = "#FFFDF8"
INK = "#1D1B18"
GOLD_LIGHT, GOLD_MID, GOLD_DARK = "#F9E08C", "#D4A63A", "#9C7420"
OUTLINE = "#5E420C"           # the cartoon outline round gold shapes

# Four-colour suits, as in the app's accessibility setting.
SUIT_INK = {
    "hearts": "#B3122B",
    "diamonds": "#1A5BC8",
    "clubs": "#13793A",
    "spades": INK,
}

# Each suit's face cards wear a cloth in the suit's colour: the hearts,
# clubs and diamonds cloths are the app's King, Jack and Queen.
SUIT_CLOTH = {
    "hearts": ("#9A1E31", "#3A0610"),
    "clubs": ("#13734A", "#062A1B"),
    "diamonds": ("#2849A8", "#0B1A45"),
    "spades": ("#45434E", "#0C0B10"),
}
JOKER_CLOTH = {
    "purple": ("#5A2F87", "#241238"),
    "yellow": ("#F5CF55", "#B8800F"),
}

GILT = "url(#gilt)"


def defs(extra: str = "") -> str:
    return f"""<defs>
  <linearGradient id="gilt" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{GOLD_LIGHT}"/>
    <stop offset="0.5" stop-color="{GOLD_MID}"/>
    <stop offset="1" stop-color="{GOLD_DARK}"/>
  </linearGradient>
  <linearGradient id="giltRim" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{GOLD_LIGHT}"/>
    <stop offset="0.35" stop-color="{GOLD_MID}"/>
    <stop offset="0.6" stop-color="#F3D27A"/>
    <stop offset="1" stop-color="{GOLD_DARK}"/>
  </linearGradient>
  <radialGradient id="cardFace" cx="0.5" cy="0.42" r="0.8">
    <stop offset="0" stop-color="#FFFEFA"/>
    <stop offset="1" stop-color="#F4EEDF"/>
  </radialGradient>
  <radialGradient id="felt" cx="0.5" cy="0.4" r="0.85">
    <stop offset="0" stop-color="#16603C"/>
    <stop offset="1" stop-color="{FELT_DEEP}"/>
  </radialGradient>
  <radialGradient id="backCloth" cx="0.5" cy="0.5" r="0.8">
    <stop offset="0" stop-color="#7A1F2C"/>
    <stop offset="1" stop-color="#2A070D"/>
  </radialGradient>
  <filter id="drop" x="-30%" y="-30%" width="160%" height="160%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="0.9"/>
    <feOffset dx="0.5" dy="1.1" result="b"/>
    <feComponentTransfer><feFuncA type="linear" slope="0.55"/></feComponentTransfer>
    <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  {extra}
</defs>"""


def cloth_gradient(gid: str, top: str, bottom: str) -> str:
    """The app's cloth: a diagonal gradient, top left to bottom right."""
    return (f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/>'
            f'</linearGradient>')


# --- shapes -------------------------------------------------------------------

# Chunky suits in a 100 x 100 box.
SUITS = {
    "hearts": "M50 94 C 30 76, 2 58, 2 32 C 2 14, 15 4, 29 4 C 40 4, 47 11, 50 20 "
    "C 53 11, 60 4, 71 4 C 85 4, 98 14, 98 32 C 98 58, 70 76, 50 94 Z",
    "diamonds": "M50 1 C 62 20, 76 37, 94 50 C 76 63, 62 80, 50 99 C 38 80, 24 63, 6 50 "
    "C 24 37, 38 20, 50 1 Z",
    "spades": "M50 2 C 62 20, 98 38, 98 62 C 98 78, 86 87, 73 87 C 64 87, 57 83, 54 77 "
    "C 55 86, 60 93, 69 98 L 31 98 C 40 93, 45 86, 46 77 C 43 83, 36 87, 27 87 "
    "C 14 87, 2 78, 2 62 C 2 38, 38 20, 50 2 Z",
    "clubs": "M28.5 27 a21.5 21.5 0 1 0 43 0 a21.5 21.5 0 1 0 -43 0 "
    "M4 59 a21.5 21.5 0 1 0 43 0 a21.5 21.5 0 1 0 -43 0 "
    "M53 59 a21.5 21.5 0 1 0 43 0 a21.5 21.5 0 1 0 -43 0 "
    "M37 36 L 63 36 L 69 66 L 31 66 Z "
    "M50 52 C 52 74, 58 90, 71 98 L 29 98 C 42 90, 48 74, 50 52 Z",
}

# The app's crown (CrownIcon), 100 wide and 75 tall.
CROWN = ("M0 18.75 L27 41.25 L50 0 L73 41.25 L100 18.75 L88 61.5 L12 61.5 Z "
         "M12 66 H88 V75 H12 Z")


def star(cx=50, cy=50, outer=48, inner=21, points=5) -> str:
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = -math.pi / 2 + i * math.pi / points
        pts.append(f"{cx + r * math.cos(a):.2f} {cy + r * math.sin(a):.2f}")
    return "M" + " L ".join(pts) + " Z"


def place(content: str, cx: float, cy: float, w: float, box_w: float, box_h: float,
          rotate: float = 0) -> str:
    """[content] drawn in a box_w x box_h box, centred at cx, cy, [w] mm wide."""
    s = w / box_w
    return (f'<g transform="translate({cx:.3f} {cy:.3f}) rotate({rotate}) scale({s:.5f}) '
            f'translate({-box_w / 2} {-box_h / 2})">{content}</g>')


def outlined(d: str, fill: str = GILT, outline: float = 5, cls: str = "foil",
             shadow: bool = True) -> str:
    """A shape with a dark cartoon outline behind it (ink) and its fill on
    top (foil)."""
    parts = [p for p in d.replace(" M", "\nM").split("\n") if p.strip()]
    back = "".join(f'<path d="{p}" fill="{OUTLINE}" stroke="{OUTLINE}" '
                   f'stroke-width="{outline}" stroke-linejoin="round"/>' for p in parts)
    front = "".join(f'<path d="{p}" fill="{fill}"/>' for p in parts)
    f = ' filter="url(#drop)"' if shadow else ""
    return f'<g{f}>{back}</g><g class="{cls}">{front}</g>'


def suit(name: str, cx: float, cy: float, size: float, fill: str,
         rotate: float = 0, cls: str = "", outline: float = 0) -> str:
    d = SUITS[name]
    parts = [p for p in d.replace(" M", "\nM").split("\n") if p.strip()]
    c = f' class="{cls}"' if cls else ""
    o = ""
    if outline:
        o = "".join(f'<path d="{p}" fill="{OUTLINE}" stroke="{OUTLINE}" '
                    f'stroke-width="{outline}" stroke-linejoin="round"/>' for p in parts)
    body = "".join(f'<path d="{p}" fill="{fill}"/>' for p in parts)
    return place(f"{o}<g{c}>{body}</g>", cx, cy, size, 100, 100, rotate)


def text(x, y, s, size, family="Alegreya Sans", weight=700, fill=INK, anchor="middle",
         rotate=0, cls="", spacing=0, stroke=None, stroke_w=0.0) -> str:
    c = f' class="{cls}"' if cls else ""
    rot = f' transform="rotate({rotate} {x:.3f} {y:.3f})"' if rotate else ""
    common = (f'x="{x:.3f}" y="{y:.3f}" font-family="{family}" font-weight="{weight}" '
              f'font-size="{size}" text-anchor="{anchor}" letter-spacing="{spacing}"{rot}')
    out = ""
    if stroke:
        out += (f'<text {common} fill="{stroke}" stroke="{stroke}" stroke-width="{stroke_w}" '
                f'stroke-linejoin="round">{s}</text>')
    return out + f'<text {common} fill="{fill}"{c}>{s}</text>'


# --- the Court Card emblems (the app's, from lib/play/card_view.dart) -------
#
# Drawn as in the app, then evened out so they read as one set: every
# emblem fits the same box, its gold is one gradient from top to bottom of
# the emblem (not per piece), and its outline is the same weight in
# millimetres whatever its scale. The King is drawn a little larger and
# wears jewels on his band, so he outranks the Joker at a glance.

OUTLINE_MM = 0.75     # the cartoon outline, as printed


def _gilt_for(gid: str, y0: float, y1: float) -> str:
    return (f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" x1="0" y1="{y0}" '
            f'x2="0" y2="{y1}"><stop offset="0" stop-color="{GOLD_LIGHT}"/>'
            f'<stop offset="0.5" stop-color="{GOLD_MID}"/><stop offset="1" stop-color="{GOLD_DARK}"/>'
            f'</linearGradient>')


def _solid(paths: list[str], fill: str, ow: float) -> str:
    """Pieces of gold: an outline behind (ink), the gilt on top (foil)."""
    back = "".join(f'<path d="{d}" fill="{OUTLINE}" stroke="{OUTLINE}" stroke-width="{ow:.3f}" '
                   f'stroke-linejoin="round"/>' for d in paths)
    front = "".join(f'<path d="{d}" fill="{fill}"/>' for d in paths)
    return f'<g>{back}</g><g class="foil">{front}</g>'


def _circle(x, y, r) -> str:
    return f"M{x - r} {y} a{r} {r} 0 1 0 {2 * r} 0 a{r} {r} 0 1 0 {-2 * r} 0 Z"


def _jester(ow: float, gilt: str):
    """The Joker's three-pointed cap with bells."""
    cap = ("M18 73.8 Q10 40.5 2 27 Q30 34.2 38 49.5 Q42 18 50 3.6 Q58 18 62 49.5 "
           "Q70 34.2 98 27 Q90 40.5 82 73.8 Z")
    band = "M19 70 H81 A4 4 0 0 1 85 74 V79 A4 4 0 0 1 81 83 H19 A4 4 0 0 1 15 79 V74 A4 4 0 0 1 19 70 Z"
    bells = [_circle(x, y, 6) for x, y in [(4, 27), (50, 4.5), (96, 27)]]
    art = (_solid([cap, band, *bells], gilt, ow)
           + f'<g class="foilknock"><path d="M38 49.5 L36.4 70 M62 49.5 L63.6 70" stroke="{OUTLINE}" '
             f'stroke-width="{ow * 0.45:.3f}" stroke-linecap="round" fill="none"/></g>')
    return art, (-2, -1.5, 102, 83)


def _jack(ow: float, gilt: str, cloth: str):
    """The Jack's sword behind a shield, a chevron in the cloth's colour."""
    pieces = [_circle(50, 0, 4.5), "M46.5 1.8 H53.5 V22.5 H46.5 Z",
              "M29 20.7 H71 A3 3 0 0 1 74 23.7 A3 3 0 0 1 71 26.7 H29 A3 3 0 0 1 26 23.7 "
              "A3 3 0 0 1 29 20.7 Z",
              "M45 26.1 L55 26.1 L55 82.8 L50 91.8 L45 82.8 Z",
              "M24 30.6 L76 30.6 L76 48.6 Q74 66.6 50 75.6 Q26 66.6 24 48.6 Z"]
    chevron = "M32 43.2 L50 54.9 L68 43.2 L68 52.2 L50 63.9 L32 52.2 Z"
    art = (_solid(pieces, gilt, ow)
           + f'<g class="foilknock"><path d="{chevron}" fill="{cloth}" stroke="{OUTLINE}" '
             f'stroke-width="{ow * 0.45:.3f}" stroke-linejoin="round"/></g>')
    return art, (24, -4.5, 76, 91.8)


def _tiara(ow: float, gilt: str):
    """The Queen's filigree tiara: band, pointed oval with a gem, scrolls.
    Its lines are drawn a little bolder than the app's, to match the
    weight of the others."""
    band = "M4 64 C30 70 70 70 96 64 C72 79 28 79 4 64 Z"
    gem = "M50 58 C42 50 43 30 50 20 C57 30 58 50 50 58 Z"
    oval = "M50 66 C36 56 38 24 50 8 C62 24 64 56 50 66"

    def scroll(start, curve, centre, turn, end_r):
        pts = [f"M{start[0] * 100:.2f} {start[1] * 100:.2f}",
               "C" + " ".join(f"{v * 100:.2f}" for v in curve)]
        fx, fy = curve[4] * 100, curve[5] * 100
        cx, cy = centre[0] * 100, centre[1] * 100
        a0 = math.atan2(fy - cy, fx - cx)
        r0 = math.hypot(fx - cx, fy - cy)
        for k in range(1, 49):
            f = k / 48
            a = a0 - turn * f
            rr = r0 + (end_r * 100 - r0) * f
            pts.append(f"L{cx + rr * math.cos(a):.2f} {cy + rr * math.sin(a):.2f}")
        return " ".join(pts)

    big = scroll((0.44, 0.66), (0.4, 0.36, 0.28, 0.22, 0.17, 0.43), (0.245, 0.52),
                 math.pi * 1.83, 0.035)
    small = scroll((0.2, 0.66), (0.16, 0.5, 0.09, 0.45, 0.05, 0.53), (0.09, 0.58),
                   math.pi * 1.67, 0.02)
    lines = [(oval, 5.2), (big, 5.4), (small, 4.4)]

    def strokes(colour, extra):
        out = ""
        for d, w in lines:
            for t in ("",) if d == oval else ("", ' transform="translate(100 0) scale(-1 1)"'):
                out += (f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{w + extra:.3f}" '
                        f'stroke-linecap="round" stroke-linejoin="round"{t}/>')
        return out

    outline = (f'<g><path d="{band}" fill="{OUTLINE}" stroke="{OUTLINE}" stroke-width="{ow:.3f}" '
               f'stroke-linejoin="round"/><path d="{gem}" fill="{OUTLINE}" stroke="{OUTLINE}" '
               f'stroke-width="{ow:.3f}" stroke-linejoin="round"/>{strokes(OUTLINE, ow)}</g>')
    gold = (f'<g class="foil"><path d="{band}" fill="{gilt}"/><path d="{gem}" fill="{gilt}"/>'
            f'{strokes(gilt, 0)}</g>')
    return outline + gold, (1, 5, 99, 78)


def _king(ow: float, gilt: str, cloth: str):
    """The King's crown (the app's), with three jewels in the cloth's
    colour on its band."""
    body = "M0 18.75 L27 41.25 L50 0 L73 41.25 L100 18.75 L88 61.5 L12 61.5 Z"
    band = "M12 66 H88 V75 H12 Z"
    jewels = "".join(
        f'<path d="{_circle(x, 70.5, 2.6)}" fill="{cloth}" stroke="{OUTLINE}" '
        f'stroke-width="{ow * 0.4:.3f}"/>' for x in (31, 50, 69))
    return _solid([body, band], gilt, ow) + f'<g class="foilknock">{jewels}</g>', (0, 0, 100, 75)


# Every emblem fits this box (mm) on the card; the King's is larger.
EMBLEM_BOX = (34.0, 29.0)
KING_BOX = (40.0, 32.0)


def emblem(kind: str, cloth: str, cx: float, cy: float) -> str:
    """A Court Card emblem centred at cx, cy (mm), evened out with the rest."""
    box_w, box_h = KING_BOX if kind == "king" else EMBLEM_BOX
    # Work out the scale from the emblem's own bounds.
    probe = {"joker": lambda: _jester(1, GILT), "jack": lambda: _jack(1, GILT, cloth),
             "queen": lambda: _tiara(1, GILT), "king": lambda: _king(1, GILT, cloth)}[kind]
    x0, y0, x1, y1 = probe()[1]
    w, h = x1 - x0, y1 - y0
    s = min(box_w / w, box_h / h)
    ow = 2 * OUTLINE_MM / s          # half of the stroke shows outside the gold
    gid = f"gilt-{kind}-{cloth[1:]}"
    gilt = f"url(#{gid})"
    art = {"joker": lambda: _jester(ow, gilt), "jack": lambda: _jack(ow, gilt, cloth),
           "queen": lambda: _tiara(ow, gilt), "king": lambda: _king(ow, gilt, cloth)}[kind]()[0]
    return (f'<defs>{_gilt_for(gid, y0, y1)}</defs>'
            f'<g filter="url(#drop)"><g transform="translate({cx:.3f} {cy:.3f}) scale({s:.5f}) '
            f'translate({-(x0 + x1) / 2:.3f} {-(y0 + y1) / 2:.3f})">{art}</g></g>')


def crown() -> tuple[str, float, float]:
    """The app's crown (CrownIcon) for decoration: logos, marks, medallions."""
    return outlined(CROWN, outline=5), 100, 75


# --- the cloths' patterns (each in a w x h box, faint) ----------------------------


def stripes(w, h) -> str:
    """The Jack's fine diagonal stripes."""
    step, sw = w * 0.16, w * 0.05
    lines = "".join(f'<line x1="{x:.2f}" y1="{h}" x2="{x + h:.2f}" y2="0"/>'
                    for x in [-h + i * step for i in range(int((w + h) / step) + 2)])
    return f'<g stroke="#FFFFFF" stroke-opacity="0.07" stroke-width="{sw:.2f}">{lines}</g>'


def lattice(w, h) -> str:
    """The Queen's gold lattice with pearls where the lines cross."""
    step = w / 4
    lines = []
    x = -h
    while x < w + h:
        lines.append(f'<line x1="{x:.2f}" y1="0" x2="{x + h:.2f}" y2="{h}"/>')
        lines.append(f'<line x1="{x:.2f}" y1="{h}" x2="{x + h:.2f}" y2="0"/>')
        x += step
    pearls = []
    y, row = 0.0, 0
    while y <= h + 0.1:
        x = step / 2 if row % 2 else 0.0
        while x <= w + 0.1:
            pearls.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="0.55"/>')
            x += step
        y += step / 2
        row += 1
    return (f'<g stroke="{GOLD_LIGHT}" stroke-opacity="0.16" stroke-width="0.3">{"".join(lines)}</g>'
            f'<g fill="#FFF8E8" fill-opacity="0.22">{"".join(pearls)}</g>')


def sunburst(w, h, cy_frac=0.56, alpha=1.0) -> str:
    """The King's gold rays from the crown out to the edges."""
    cx, cy = w / 2, h * cy_frac
    r = max(w, h) * 1.2
    k = f"{int(cy_frac * 100)}-{int(alpha * 100)}"
    rays = []
    for i in range(24):
        a = i * math.pi / 12
        p1 = (cx + r * math.cos(a - 0.06), cy + r * math.sin(a - 0.06))
        p2 = (cx + r * math.cos(a + 0.06), cy + r * math.sin(a + 0.06))
        op = (0.25 if i % 2 == 0 else 0.15) * alpha
        rays.append(f'<path d="M{cx:.2f} {cy:.2f} L{p1[0]:.2f} {p1[1]:.2f} L{p2[0]:.2f} {p2[1]:.2f} Z" '
                    f'fill="url(#rayFade{k})" fill-opacity="{op:.2f}"/>')
    glow = (f'<circle cx="{cx}" cy="{cy}" r="{w * 0.42:.2f}" fill="url(#glow{k})"/>')
    grad = (f'<defs><radialGradient id="rayFade{k}" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" r="{r * 0.7:.2f}">'
            f'<stop offset="0" stop-color="{GOLD_LIGHT}"/><stop offset="1" stop-color="{GOLD_LIGHT}" stop-opacity="0.05"/>'
            f'</radialGradient><radialGradient id="glow{k}"><stop offset="0" stop-color="{GOLD_LIGHT}" stop-opacity="{0.3 * alpha:.2f}"/>'
            f'<stop offset="1" stop-color="{GOLD_LIGHT}" stop-opacity="0"/></radialGradient></defs>')
    return grad + "".join(rays) + glow


def harlequin(w, h, dark="#1A0C2A", light=GOLD_LIGHT) -> str:
    """The Joker's field of diamonds."""
    dw, dh = w / 4, h / 5
    out = []
    for row in range(-1, 6):
        for col in range(-1, 5):
            cx = col * dw + (dw / 2 if row % 2 else 0)
            cy = row * dh
            fill, op = (dark, 0.22) if (row + col) % 2 == 0 else (light, 0.08)
            out.append(f'<path d="M{cx:.2f} {cy - dh / 2:.2f} L{cx + dw / 2:.2f} {cy:.2f} '
                       f'L{cx:.2f} {cy + dh / 2:.2f} L{cx - dw / 2:.2f} {cy:.2f} Z" '
                       f'fill="{fill}" fill-opacity="{op}"/>')
    return "".join(out)


def brass_inlay(x, y, w, h, r=3.0) -> str:
    """The table's thin double brass rule (TableTrim)."""
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="none" '
            f'stroke="{GOLD_MID}" stroke-opacity="0.75" stroke-width="0.4" class="foil"/>'
            f'<rect x="{x + 0.9}" y="{y + 0.9}" width="{w - 1.8}" height="{h - 1.8}" rx="{max(0.5, r - 0.8)}" '
            f'fill="none" stroke="{GOLD_MID}" stroke-opacity="0.45" stroke-width="0.25" class="foil"/>')
