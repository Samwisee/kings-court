"""The two-piece box: an inner tray that holds the cards upright, and an
outer sleeve it slides into from the top (open at the top, thumb notches
front and back to draw the tray out).

Folded carton, about 400 gsm board (0.55 mm). Dimensions are a starting
point: a printer will supply its own dieline for the board it uses, and
the art here drops onto it.

Each piece is drawn flat with:
  * art, with 3 mm bleed past every cut edge,
  * a foil plate (black = gold foil),
  * the dieline: cut (red, solid) and fold (blue, dashed).

Run:  python3 tool/print/box.py OUT_DIR
"""
from __future__ import annotations

import math
import pathlib
import sys

from art import Renderer
import deck
from brand import (CROWN, FELT, GILT, GOLD_LIGHT, GOLD_MID, INK, OUTLINE,
                   brass_inlay, crown, defs, lattice, outlined, place, suit,
                   sunburst, text)

DISPLAY, BODY = "Cinzel Decorative", "Alegreya Sans"

# --- sizes (mm) ---------------------------------------------------------

BOARD = 0.55
CARD_W, CARD_H = 63.0, 88.0
STACK = 18.0                     # 56 cards at about 0.31 mm
TRAY_W = CARD_W + 1.6 + 2 * BOARD    # outside
TRAY_D = STACK + 1.2 + 2 * BOARD
TRAY_H = 80.0                    # cards stand 8 mm proud of the tray
SLEEVE_W = TRAY_W + 0.8          # outside of the tray, plus a sliding fit
SLEEVE_D = TRAY_D + 0.8
SLEEVE_H = CARD_H + BOARD + 1.6  # covers the cards completely
NOTCH_SLEEVE = 10.0              # thumb notch radius
NOTCH_TRAY = 8.0
BLEED = 3.0
GLUE = 12.0

FELT_BG = "url(#felt)"
CLOTH_BG = "url(#backCloth)"
CUT, FOLD = "#E4002B", "#0072CE"

# --- panel art (each drawn upright in its own w x h box) -------------------


def card_art(svg_doc: str, cx, cy, w, angle=0.0) -> str:
    """A whole card from the deck, trimmed and rounded, at cx, cy, w wide."""
    h = w * 88 / 63
    inner = svg_doc.replace('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 69.0 94.0">',
                            '', 1)
    inner = inner[: inner.rfind("</svg>")]
    k = abs(hash((cx, cy, w, angle))) % 100000
    return (f'<g transform="translate({cx:.2f} {cy:.2f}) rotate({angle:.2f})">'
            f'<clipPath id="cc{k}"><rect x="{-w / 2}" y="{-h / 2}" width="{w}" height="{h}" '
            f'rx="{w * 0.06:.2f}"/></clipPath>'
            f'<rect x="{-w / 2 + 0.5}" y="{-h / 2 + 0.9}" width="{w}" height="{h}" rx="{w * 0.06:.2f}" '
            f'fill="#000" fill-opacity="0.45" filter="url(#drop)"/>'
            f'<g clip-path="url(#cc{k})"><svg x="{-w / 2}" y="{-h / 2}" width="{w}" height="{h}" '
            f'viewBox="3 3 63 88">{inner}</svg></g></g>')


def fan(cx, cy, w) -> str:
    """The welcome screen's fan: Joker, Jack, Queen and King."""
    cards = [deck.joker("purple"), deck.face_card("J", "clubs"),
             deck.face_card("Q", "diamonds"), deck.face_card("K", "hearts")]
    out = ""
    for i, c in enumerate(cards):
        t = i - 1.5
        a = t * 14
        # Fanned from a point below the cards, like a hand.
        px = cx + math.sin(math.radians(a)) * w * 1.6
        py = cy - math.cos(math.radians(a)) * w * 1.6 + w * 1.6
        out += card_art(c, px, py, w, a)
    return out


def sleeve_front(w, h) -> str:
    cx = w / 2
    return (sunburst(w, h, cy_frac=0.42, alpha=0.75)
            + brass_inlay(3, 3, w - 6, h - 6)
            + place(crown()[0], cx, 24.5, 32, 100, 75)
            + fan(cx, 47.5, 16)
            + text(cx, 66.6, "THE", 4.2, family=DISPLAY, weight=900, fill=GILT, cls="foil",
                   stroke=OUTLINE, stroke_w=0.6, spacing=0.4)
            + text(cx, 74.2, "KING’S COURT", 6.6, family=DISPLAY, weight=900, fill=GILT,
                   cls="foil", stroke=OUTLINE, stroke_w=0.8)
            + text(cx, 79.8, "LUXURY PLAYING CARDS", 2.5, family=BODY, weight=700,
                   fill=GOLD_LIGHT, spacing=0.8)
            + "".join(suit(s, cx + (i - 1.5) * 5.4, 84.2, 3.0, c, outline=10)
                      for i, (s, c) in enumerate([("spades", "#1D1B18"), ("hearts", "#B3122B"),
                                                  ("clubs", "#13793A"), ("diamonds", "#1A5BC8")])))


def sleeve_back(w, h) -> str:
    cx = w / 2
    light = "#E9F2EC"
    blurb = [
        "A deck for the whole court. Play any classic",
        "game with all fifty-four cards, or choose a",
        "Jack, Queen, King and Joker in the colours",
        "you like for The King’s Court: cooperative",
        "trick-taking for 2 to 6. Win or lose together.",
    ]
    contents = [
        "52 cards in four colours and two Jokers",
        "Court Cards in red, green, blue and black",
        "How-to-play card and your unlock code",
    ]
    return (brass_inlay(3, 3, w - 6, h - 6)
            + place(crown()[0], cx, 13.6, 9, 100, 75)
            + text(cx, 21.6, "THE KING’S COURT", 3.9, family=DISPLAY, weight=900, fill=GILT,
                   cls="foil", stroke=OUTLINE, stroke_w=0.5)
            + "".join(text(cx, 27.6 + i * 3.5, s, 2.7, family=BODY, weight=500, fill=light)
                      for i, s in enumerate(blurb))
            + "".join(suit(s, cx + (i - 1.5) * 4, 46.4, 2.2, GILT, cls="foil")
                      for i, s in enumerate(["spades", "hearts", "clubs", "diamonds"]))
            + "".join(text(cx, 51.6 + i * 3.4, s, 2.5, family=BODY, weight=500,
                           fill=GOLD_LIGHT) for i, s in enumerate(contents))
            + deck.qr(deck.APP_URL, 10, h - 29.5, 13)
            + text(26.8, h - 25.0, "Scan to play,", 2.4, family=BODY, weight=500, fill=light,
                   anchor="start")
            + text(26.8, h - 22.0, "or tap the box", 2.4, family=BODY, weight=500, fill=light,
                   anchor="start")
            + text(26.8, h - 19.0, "for a table.", 2.4, family=BODY, weight=500, fill=light,
                   anchor="start")
            + deck.nfc(30.6, h - 13.8, 4.4, GOLD_LIGHT)
            + f'<rect x="{w - 21}" y="{h - 29.5}" width="12.5" height="13" fill="#FFFFFF"/>'
            + text(w - 14.75, h - 22.4, "BARCODE", 1.6, family=BODY, weight=700, fill=INK)
            + text(cx, h - 6.6, "Inspired by The Crew  ·  © 2026 The King’s Court", 1.9,
                   family=BODY, weight=500, fill=light))


def sleeve_side(w, h) -> str:
    """The spine, read bottom to top."""
    cx, cy = w / 2, h / 2
    return (brass_inlay(2.2, 3, w - 4.4, h - 6, r=2)
            + place(crown()[0], cx, h - 14.5, 8.6, 100, 75)
            + text(cx, cy, "THE KING’S COURT", 4.0, family=DISPLAY, weight=900, fill=GILT,
                   cls="foil", stroke=OUTLINE, stroke_w=0.5, rotate=-90)
            + suit("diamonds", cx, 14, 3.0, GILT, cls="foil", outline=10))


def medallion(cx, cy, r) -> str:
    return (f'<circle cx="{cx}" cy="{cy}" r="{r + 0.9}" fill="{OUTLINE}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#5A1620" class="foilbg"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="url(#giltRim)" '
            f'stroke-width="1.1" class="foil"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r - 2}" fill="none" stroke="{GOLD_MID}" '
            f'stroke-width="0.25" class="foil"/>'
            + place(crown()[0], cx, cy - 0.6, r * 1.2, 100, 75))


def tray_front(w, h) -> str:
    """Shows above the sleeve when the box opens: the card back's look."""
    cx = w / 2
    return (sunburst(w, h, cy_frac=0.36, alpha=0.9)
            + brass_inlay(2.6, 2.6, w - 5.2, h - 5.2)
            + medallion(cx, 28.6, 12.5)
            + text(cx, 52.4, "LONG LIVE", 3.2, family=DISPLAY, weight=900, fill=GILT,
                   cls="foil", stroke=OUTLINE, stroke_w=0.45, spacing=0.5)
            + text(cx, 59.4, "THE COURT", 5.0, family=DISPLAY, weight=900, fill=GILT,
                   cls="foil", stroke=OUTLINE, stroke_w=0.6))


def tray_back(w, h) -> str:
    cx = w / 2
    return (sunburst(w, h, cy_frac=0.5, alpha=0.7)
            + brass_inlay(2.6, 2.6, w - 5.2, h - 5.2)
            + text(cx, h / 2 - 3, "A TABLE", 3.2, family=DISPLAY, weight=900, fill=GILT,
                   cls="foil", stroke=OUTLINE, stroke_w=0.45)
            + text(cx, h / 2 + 3.6, "OF EQUALS", 4.4, family=DISPLAY, weight=900, fill=GILT,
                   cls="foil", stroke=OUTLINE, stroke_w=0.55))


def tray_side(w, h) -> str:
    return place(outlined(CROWN, outline=6, shadow=False), w / 2, h / 2, 9, 100, 75)


def liner(w, h) -> str:
    """The inside of the tray: the table's felt, with a faint lattice."""
    return f'<rect width="{w}" height="{h}" fill="url(#felt)"/>' + lattice(w, h)


# --- nets -----------------------------------------------------------------


class Net:
    """Panels laid out flat, each with its own background and art."""

    def __init__(self):
        self.panels = []   # (x, y, w, h, bg, art_fn, rotation)
        self.flaps = []    # (path d, bg) for glue flaps and dust flaps
        self.cuts = []     # path d strings
        self.folds = []    # (x1, y1, x2, y2)

    def panel(self, x, y, w, h, bg, art=None, rot=0):
        self.panels.append((x, y, w, h, bg, art, rot))

    def bounds(self):
        xs, ys = [], []
        for (x, y, w, h, *_rest) in self.panels:
            xs += [x, x + w]
            ys += [y, y + h]
        for d, _bg in self.flaps:
            nums = [float(v) for v in d.replace("M", " ").replace("L", " ").replace("Z", " ").split()]
            xs += nums[0::2]
            ys += nums[1::2]
        return min(xs), min(ys), max(xs), max(ys)

    def render(self, mode: str) -> tuple[str, float, float]:
        """mode: 'art' (art with bleed), 'foil' (same, for the foil plate),
        'lines' (dieline only), 'proof' (art with the dieline over it)."""
        x0, y0, x1, y1 = self.bounds()
        pad = 8
        ox, oy = -x0 + pad, -y0 + pad
        w, h = x1 - x0 + 2 * pad, y1 - y0 + 2 * pad
        body = []
        if mode != "lines":
            # Bleed first, then each panel exactly, so neighbours meet cleanly.
            for (x, y, pw, ph, bg, _a, _r) in self.panels:
                body.append(f'<rect x="{x - BLEED}" y="{y - BLEED}" width="{pw + 2 * BLEED}" '
                            f'height="{ph + 2 * BLEED}" fill="{bg}" class="foilbg"/>')
            for d, bg in self.flaps:
                body.append(f'<path d="{d}" fill="{bg}" stroke="{bg}" stroke-width="{2 * BLEED}" '
                            f'stroke-linejoin="round" class="foilbg"/>')
            for (x, y, pw, ph, bg, _a, _r) in self.panels:
                body.append(f'<rect x="{x}" y="{y}" width="{pw}" height="{ph}" fill="{bg}" class="foilbg"/>')
            for (x, y, pw, ph, _bg, art, rot) in self.panels:
                if not art:
                    continue
                aw, ah = (ph, pw) if rot in (90, -90) else (pw, ph)
                if rot == 0:
                    t = f"translate({x} {y})"
                elif rot == 180:
                    t = f"translate({x + pw} {y + ph}) rotate(180)"
                elif rot == 90:
                    t = f"translate({x + pw} {y}) rotate(90)"
                else:
                    t = f"translate({x} {y + ph}) rotate(-90)"
                body.append(f'<g transform="{t}"><svg x="0" y="0" width="{aw}" height="{ah}" '
                            f'viewBox="0 0 {aw} {ah}" overflow="hidden">{art(aw, ah)}</svg></g>')
        if mode in ("lines", "proof"):
            for d in self.cuts:
                body.append(f'<path d="{d}" fill="none" stroke="{CUT}" stroke-width="0.25"/>')
            for (a, b, c, e) in self.folds:
                body.append(f'<line x1="{a}" y1="{b}" x2="{c}" y2="{e}" stroke="{FOLD}" '
                            f'stroke-width="0.25" stroke-dasharray="1.5 1"/>')
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}">{defs()}'
               f'<g transform="translate({ox} {oy})">{"".join(body)}</g></svg>')
        return svg, w, h


def notch_cut(cx, y, r, down=True) -> str:
    """A thumb notch: a half circle cut into an edge at height y."""
    s = 1 if down else 0
    return f"M{cx - r} {y} A {r} {r} 0 0 {s} {cx + r} {y}"


def sleeve() -> Net:
    n = Net()
    W, D, H = SLEEVE_W, SLEEVE_D, SLEEVE_H
    xs = [0, GLUE, GLUE + D, GLUE + D + W, GLUE + 2 * D + W, GLUE + 2 * D + 2 * W]
    m = FELT_BG
    n.panel(xs[1], 0, D, H, m, sleeve_side)
    n.panel(xs[2], 0, W, H, m, sleeve_front)
    n.panel(xs[3], 0, D, H, m, sleeve_side)
    n.panel(xs[4], 0, W, H, m, sleeve_back)
    # Glue flap on the left, tapered.
    glue = f"M{xs[1]} 0 L {xs[0]} 4 L {xs[0]} {H - 4} L {xs[1]} {H} Z"
    n.flaps.append((glue, m))
    # Bottom: the front's flap closes it, the sides tuck in, the back's
    # flap is glued under.
    close = f"M{xs[2]} {H} L {xs[2]} {H + D} L {xs[3]} {H + D} L {xs[3]} {H} Z"
    dust1 = f"M{xs[1]} {H} L {xs[1] + 1} {H + D * 0.8} L {xs[2] - 2} {H + D * 0.8} L {xs[2]} {H} Z"
    dust2 = f"M{xs[3]} {H} L {xs[3] + 2} {H + D * 0.8} L {xs[4] - 1} {H + D * 0.8} L {xs[4]} {H} Z"
    tab = f"M{xs[4]} {H} L {xs[4] + 4} {H + GLUE} L {xs[5] - 4} {H + GLUE} L {xs[5]} {H} Z"
    for d in (close, dust1, dust2, tab):
        n.flaps.append((d, m))
    # Cut line: round the outside, with notches in the top of front and back.
    fx, bx = xs[2] + W / 2, xs[4] + W / 2
    r = NOTCH_SLEEVE
    top = (f"M{xs[1]} 0 L {fx - r} 0 A {r} {r} 0 0 0 {fx + r} 0 L {bx - r} 0 "
           f"A {r} {r} 0 0 0 {bx + r} 0 L {xs[5]} 0 L {xs[5]} {H} "
           f"L {xs[5] - 4} {H + GLUE} L {xs[4] + 4} {H + GLUE} L {xs[4]} {H} "
           f"L {xs[4] - 1} {H + D * 0.8} L {xs[3] + 2} {H + D * 0.8} L {xs[3]} {H} "
           f"L {xs[3]} {H + D} L {xs[2]} {H + D} L {xs[2]} {H} "
           f"L {xs[2] - 2} {H + D * 0.8} L {xs[1] + 1} {H + D * 0.8} L {xs[1]} {H} "
           f"L {xs[0]} {H - 4} L {xs[0]} 4 Z")
    n.cuts.append(top)
    for x in xs[1:5]:
        n.folds.append((x, 0, x, H))
    for (a, b) in [(xs[1], xs[2]), (xs[2], xs[3]), (xs[3], xs[4]), (xs[4], xs[5])]:
        n.folds.append((a, H, b, H))
    return n


def tray() -> Net:
    n = Net()
    W, D, H = TRAY_W, TRAY_D, TRAY_H
    iv = CLOTH_BG
    red = FELT_BG
    L, T = H, 2 * H - 1          # top-left of the bottom panel
    lin = H - 1.2                # liners fold down inside the walls
    n.panel(L, T, W, D, iv)                                   # bottom
    n.panel(L, T - H, W, H, iv, tray_back)                    # back wall
    n.panel(L + 0.6, T - H - lin, W - 1.2, lin, red, liner, 180)  # back liner
    n.panel(L, T + D, W, H, iv, tray_front, 180)              # front wall
    n.panel(L + 0.6, T + D + H, W - 1.2, lin, red, liner)      # front liner
    n.panel(L - H, T, H, D, iv, tray_side, -90)               # left side
    n.panel(L + W, T, H, D, iv, tray_side, 90)                # right side
    # Glue tabs on the walls' ends fold round onto the sides.
    g = 10
    tabs = [
        f"M{L} {T - H + 1} L {L - g} {T - H + 4} L {L - g} {T - 3} L {L} {T} Z",
        f"M{L + W} {T - H + 1} L {L + W + g} {T - H + 4} L {L + W + g} {T - 3} L {L + W} {T} Z",
        f"M{L} {T + D} L {L - g} {T + D + 3} L {L - g} {T + D + H - 4} L {L} {T + D + H - 1} Z",
        f"M{L + W} {T + D} L {L + W + g} {T + D + 3} L {L + W + g} {T + D + H - 4} "
        f"L {L + W} {T + D + H - 1} Z",
    ]
    for d in tabs:
        n.flaps.append((d, iv))
    # Cut outline, going round clockwise from the back liner's top left.
    r = NOTCH_TRAY
    fx = L + W / 2
    fy = T + D + H              # front wall's top edge (fold to its liner)
    n.cuts.append(
        f"M{L + 0.6} {T - H - lin} L {L + W - 0.6} {T - H - lin} L {L + W - 0.6} {T - H} "
        f"L {L + W} {T - H} L {L + W} {T - H + 1} L {L + W + g} {T - H + 4} L {L + W + g} {T - 3} "
        f"L {L + W} {T} L {L + W + H} {T} L {L + W + H} {T + D} L {L + W} {T + D} "
        f"L {L + W + g} {T + D + 3} L {L + W + g} {T + D + H - 4} L {L + W} {T + D + H - 1} "
        f"L {L + W} {fy} L {L + W - 0.6} {fy} L {L + W - 0.6} {fy + lin} L {L + 0.6} {fy + lin} "
        f"L {L + 0.6} {fy} L {L} {fy} L {L} {T + D + H - 1} L {L - g} {T + D + H - 4} "
        f"L {L - g} {T + D + 3} L {L} {T + D} L {L - H} {T + D} L {L - H} {T} L {L} {T} "
        f"L {L - g} {T - 3} L {L - g} {T - H + 4} L {L} {T - H + 1} L {L} {T - H} "
        f"L {L + 0.6} {T - H} Z")
    # The thumb notch goes through the front wall and its liner together.
    n.cuts.append(f"M{fx - r} {fy} A {r} {r} 0 1 0 {fx + r} {fy} A {r} {r} 0 1 0 {fx - r} {fy} Z")
    folds = [
        (L, T, L + W, T), (L, T + D, L + W, T + D),          # walls up
        (L, T, L, T + D), (L + W, T, L + W, T + D),          # sides up
        (L + 0.6, T - H, L + W - 0.6, T - H),                # back liner down
        (L + 0.6, fy, fx - r, fy), (fx + r, fy, L + W - 0.6, fy),  # front liner
        (L, T - H + 1, L, T), (L + W, T - H + 1, L + W, T),  # tabs
        (L, T + D, L, T + D + H - 1), (L + W, T + D, L + W, T + D + H - 1),
    ]
    n.folds += folds
    return n


# --- a mock-up ---------------------------------------------------------------


def mockup(r: Renderer, faces: dict[str, pathlib.Path], out: pathlib.Path):
    """The box in 3D: the tray drawn halfway out of the sleeve."""
    import base64

    def uri(p):
        return "data:image/png;base64," + base64.b64encode(p.read_bytes()).decode()

    k = 4.2  # px per mm
    W, D, H = SLEEVE_W * k, SLEEVE_D * k, SLEEVE_H * k
    tw, td, th = TRAY_W * k, TRAY_D * k, TRAY_H * k
    lift = 46 * k
    html = f"""<!doctype html><html><head><style>
body{{margin:0;background:radial-gradient(ellipse at 50% 40%,#2b2f36,#0d0f12);
  width:1100px;height:900px;overflow:hidden}}
.scene{{position:absolute;left:50%;top:58%;perspective:2200px}}
.obj{{position:absolute;transform-style:preserve-3d;
  transform:rotateX(-16deg) rotateY(-32deg)}}
.f{{position:absolute;backface-visibility:hidden;background-size:100% 100%}}
.shadow{{position:absolute;left:-260px;top:{H / 2 - 30}px;width:560px;height:120px;
  background:radial-gradient(ellipse,rgba(0,0,0,.6),transparent 70%);
  transform:rotateX(90deg) translateZ(-{H / 2}px)}}
</style></head><body><div class="scene"><div class="obj">
<div class="shadow"></div>
<!-- tray, lifted -->
<div class="f" style="width:{tw}px;height:{th}px;left:{-tw / 2}px;top:{H / 2 - th - lift}px;
  transform:translateZ({td / 2}px);background-image:url({uri(faces['tray_front'])})"></div>
<div class="f" style="width:{td}px;height:{th}px;left:{-td / 2}px;top:{H / 2 - th - lift}px;
  transform:rotateY(90deg) translateZ({tw / 2}px);background-image:url({uri(faces['tray_side'])})"></div>
<div class="f" style="width:{tw - 6}px;height:{td - 6}px;left:{-tw / 2 + 3}px;top:{H / 2 - th - lift - (td - 6) / 2 - 8 * k}px;
  transform:rotateX(90deg) translateZ({td * 0}px);background:#f3ead6;
  box-shadow:inset 0 0 0 2px #e8dcc0"></div>
<!-- cards' top edges -->
<div class="f" style="width:{tw - 4}px;height:{8 * k}px;left:{-tw / 2 + 2}px;top:{H / 2 - th - lift - 8 * k}px;
  transform:translateZ({td / 2 - 3}px);background:repeating-linear-gradient(90deg,#f6efe0 0 3px,#e9dfc8 3px 4px)"></div>
<!-- sleeve -->
<div class="f" style="width:{W}px;height:{H}px;left:{-W / 2}px;top:{-H / 2}px;
  transform:translateZ({D / 2}px);background-image:url({uri(faces['sleeve_front'])});
  -webkit-mask:radial-gradient(circle {NOTCH_SLEEVE * k}px at 50% 0,transparent 98%,#000 100%)"></div>
<div class="f" style="width:{D}px;height:{H}px;left:{-D / 2}px;top:{-H / 2}px;
  transform:rotateY(90deg) translateZ({W / 2}px);background-image:url({uri(faces['sleeve_side'])})"></div>
</div></div></body></html>"""
    r.html_png(html, 1100, 900, out, scale=1.5)


def main(out: pathlib.Path):
    r = Renderer()
    try:
        for name, net in (("sleeve", sleeve()), ("tray", tray())):
            for mode in ("art", "lines", "proof"):
                s, w, h = net.render(mode)
                if mode != "proof":
                    r.pdf([s], w, h, out / "box" / f"{name}-{mode}.pdf")
                r.png(s, w, h, out / "box" / f"{name}-{mode}.png", dpi=300 if mode != "proof" else 150)
            s, w, h = net.render("art")
            r.pdf([s], w, h, out / "box" / f"{name}-foil.pdf", foil=True)
            r.png(s, w, h, out / "box" / f"{name}-foil.png", foil=True)
        # Faces for the mock-up.
        _defs = defs
        faces = {}
        for key, fn, w, h, bg in [
            ("sleeve_front", sleeve_front, SLEEVE_W, SLEEVE_H, FELT_BG),
            ("sleeve_side", sleeve_side, SLEEVE_D, SLEEVE_H, FELT_BG),
            ("tray_front", tray_front, TRAY_W, TRAY_H, CLOTH_BG),
            ("tray_side", tray_side, TRAY_D, TRAY_H, CLOTH_BG),
        ]:
            s = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}">{_defs()}'
                 f'<rect width="{w}" height="{h}" fill="{bg}"/>{fn(w, h)}</svg>')
            p = out / "preview" / "faces" / f"{key}.png"
            r.png(s, w, h, p, dpi=200)
            faces[key] = p
        mockup(r, faces, out / "preview" / "box-mockup.png")
    finally:
        r.close()


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "print-out"))
