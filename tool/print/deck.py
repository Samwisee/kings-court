"""The King's Court printed deck: a full standard deck (52 cards and two
Jokers) that is also the King's Court deck (Aces to 9s, marked with a small
gold crown, plus the four Court Cards), and two cards about the game.

Poker size, 63 x 88 mm, drawn with 3 mm bleed (69 x 94 mm). Each card is
rendered as artwork and as a foil plate (black = gold foil).

Run:  python3 tool/print/deck.py OUT_DIR
"""
from __future__ import annotations

import math
import pathlib
import sys

import segno

from art import (CLOTH, CROWN, G, INK, IVORY, JESTER, PLUME, RED, SHIELD,
                 STAR, SUIT_PATHS, SUITS, SWORD, TIARA, Renderer, defs,
                 filigree_corner, laurel, shape, text)

W, H = 69.0, 94.0          # with bleed
BLEED = 3.0
CX, CY = W / 2, H / 2
TRIM = (BLEED, BLEED, W - BLEED, H - BLEED)
APP_URL = "https://samwisee.github.io/kings-court/"
SAMPLE_CODE = "KC-7Q4M-X2PA"

RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

# Pip positions in a 0..1 field (columns left/centre/right, rows down).
PIPS = {
    2: [(.5, 0), (.5, 1)],
    3: [(.5, 0), (.5, .5), (.5, 1)],
    4: [(0, 0), (1, 0), (0, 1), (1, 1)],
    5: [(0, 0), (1, 0), (.5, .5), (0, 1), (1, 1)],
    6: [(0, 0), (1, 0), (0, .5), (1, .5), (0, 1), (1, 1)],
    7: [(0, 0), (1, 0), (.5, .25), (0, .5), (1, .5), (0, 1), (1, 1)],
    8: [(0, 0), (1, 0), (.5, .25), (0, .5), (1, .5), (.5, .75), (0, 1), (1, 1)],
    9: [(0, 0), (1, 0), (0, 1 / 3), (1, 1 / 3), (.5, .5), (0, 2 / 3), (1, 2 / 3),
        (0, 1), (1, 1)],
    10: [(0, 0), (1, 0), (.5, 1 / 6), (0, 1 / 3), (1, 1 / 3), (0, 2 / 3), (1, 2 / 3),
         (.5, 5 / 6), (0, 1), (1, 1)],
}


def svg(body: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}">'
            f'{defs()}{body}</svg>')


def frame(colour: str = G, inset: float = 3.4) -> str:
    x0, y0 = BLEED + inset, BLEED + inset
    w, h = W - 2 * x0, H - 2 * y0
    i = 0.9
    out = [
        f'<rect x="{x0}" y="{y0}" width="{w}" height="{h}" rx="2.2" fill="none" '
        f'stroke="{colour}" stroke-width="0.34" class="foil"/>',
        f'<rect x="{x0 + i}" y="{y0 + i}" width="{w - 2 * i}" height="{h - 2 * i}" rx="1.5" '
        f'fill="none" stroke="{colour}" stroke-width="0.18" class="foil"/>',
    ]
    k = 1.6
    for (x, y, sx, sy) in [(x0 + k, y0 + k, 1, 1), (x0 + w - k, y0 + k, -1, 1),
                           (x0 + k, y0 + h - k, 1, -1), (x0 + w - k, y0 + h - k, -1, -1)]:
        out.append(filigree_corner(x, y, sx * 0.55, sy * 0.55, colour))
    return "".join(out)


def ivory_bg() -> str:
    return f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#ivory)" class="foilbg"/>'


def both_ends(content: str) -> str:
    """[content] drawn for the top-left, and again turned for bottom-right."""
    return content + f'<g transform="rotate(180 {CX} {CY})">{content}</g>'


def index(rank: str, suit: str | None, colour: str, crown: bool,
          letter_fill: str | None = None, dots: int = 0) -> str:
    x = 11.4
    size = 6.0 if rank != "10" else 5.4
    spacing = -0.35 if rank == "10" else 0
    out = text(x, 15.6, rank, size, fill=letter_fill or colour, weight=600,
               spacing=spacing, cls="foil" if letter_fill == G else "")
    y = 19.8
    if suit:
        out += shape(SUIT_PATHS[suit], x, y, 4.1, colour)
        y += 4.4
    if dots:
        # Court Cards: their order, lowest (one) to highest (four).
        for i in range(dots):
            out += shape(SUIT_PATHS["diamonds"], x, y - 1.6 + i * 1.75, 1.2, G, cls="foil")
        y += dots * 1.75
    if crown:
        # The King's Court mark: this card is in the 40-card game deck.
        out += shape(CROWN, x, y + 0.6, 2.7, G, cls="foil")
    return out


# --- faces --------------------------------------------------------------


def pip_card(rank: int, suit: str) -> str:
    _, colour = SUITS[suit]
    n = rank
    size = 9.6 if n <= 6 else 8.6
    x0, x1 = CX - 10.6, CX + 10.6
    y0, y1 = 21.5, H - 21.5
    pips = []
    for (u, v) in PIPS[n]:
        x = x0 + (x1 - x0) * u
        y = y0 + (y1 - y0) * v
        rot = 180 if v > 0.5 else 0
        pips.append(shape(SUIT_PATHS[suit], x, y, size, colour, rotate=rot))
    crown = n <= 9
    return svg(ivory_bg() + frame() + both_ends(index(str(n), suit, colour, crown))
               + "".join(pips))


def ace(suit: str) -> str:
    _, colour = SUITS[suit]
    if suit == "spades":
        art = (laurel(CX, CY + 1, 19.5, G, size=2.9)
               + shape(SUIT_PATHS[suit], CX, CY + 1, 27, colour)
               + shape(CROWN, CX, 21.4, 10, G, cls="foil")
               + text(CX, 80.6, "THE KING’S COURT", 3.1, fill=G, weight=600,
                      spacing=0.45, cls="foil")
               + text(CX, 84.2, "MMXXVI", 2.1, fill=G, weight=500, spacing=0.8, cls="foil"))
    else:
        ring = [f'<circle cx="{CX}" cy="{CY}" r="16.5" fill="none" stroke="{G}" '
                f'stroke-width="0.28" class="foil"/>',
                f'<circle cx="{CX}" cy="{CY}" r="15.4" fill="none" stroke="{G}" '
                f'stroke-width="0.18" class="foil"/>']
        for i in range(16):
            a = i * math.pi / 8
            ring.append(shape(SUIT_PATHS["diamonds"], CX + 18.2 * math.cos(a),
                              CY + 18.2 * math.sin(a), 2.0 if i % 2 == 0 else 1.2, G,
                              cls="foil"))
        art = "".join(ring) + shape(SUIT_PATHS[suit], CX, CY, 21, colour)
    return svg(ivory_bg() + frame() + both_ends(index("A", suit, colour, True)) + art)


HEADWEAR = {"J": PLUME, "Q": TIARA, "K": CROWN}
TITLE = {"J": "JACK", "Q": "QUEEN", "K": "KING"}


def face_card(rank: str, suit: str) -> str:
    """Standard Jack, Queen and King: a crest for the top half, mirrored."""
    _, colour = SUITS[suit]
    px0, py0, px1, py1 = 15.8, 12.6, W - 15.8, H - 12.6
    panel = (f'<rect x="{px0}" y="{py0}" width="{px1 - px0}" height="{py1 - py0}" rx="1.4" '
             f'fill="none" stroke="{colour}" stroke-width="0.3"/>'
             f'<rect x="{px0 + 0.8}" y="{py0 + 0.8}" width="{px1 - px0 - 1.6}" '
             f'height="{py1 - py0 - 1.6}" rx="1" fill="none" stroke="{G}" '
             f'stroke-width="0.18" class="foil"/>'
             f'<line x1="{px0 + 2}" y1="{CY}" x2="{px1 - 2}" y2="{CY}" stroke="{G}" '
             f'stroke-width="0.18" class="foil"/>'
             + shape(SUIT_PATHS["diamonds"], CX, CY, 2.4, G, cls="foil"))
    half = (laurel(CX, 31.5, 11.6, G, leaves=9, size=2.3)
            + shape(HEADWEAR[rank], CX, 20.6, 10 if rank == "J" else 8.6, G, cls="foil")
            # Cinzel's J drops below the line and its Q has a long tail, so
            # each sits where it looks centred.
            + text(CX, {"J": 36.2, "Q": 38.0, "K": 38.6}[rank], rank,
                   {"J": 14, "Q": 14, "K": 15}[rank], fill=colour, weight=700)
            + shape(SUIT_PATHS[suit], CX - 13.2, 33.2, 3.6, colour)
            + shape(SUIT_PATHS[suit], CX + 13.2, 33.2, 3.6, colour)
            + text(CX, 44.2, TITLE[rank], 2.2, fill=colour, weight=600, spacing=0.6))
    return svg(ivory_bg() + frame() + both_ends(index(rank, suit, colour, False))
               + panel + both_ends(half))


COURT = [  # the King's Court suit, lowest to highest
    ("joker", "★", STAR, "THE JOKER"),
    ("jack", "J", SHIELD, "THE JACK"),
    ("queen", "Q", TIARA, "THE QUEEN"),
    ("king", "K", CROWN, "THE KING"),
]


def court_card(i: int) -> str:
    key, letter, emblem, name = COURT[i]
    cloth = CLOTH[key]
    bg = (f'<radialGradient id="cloth-{key}" cx="0.5" cy="0.45" r="0.8">'
          f'<stop offset="0" stop-color="{cloth}"/>'
          f'<stop offset="1" stop-color="#0E0710"/></radialGradient>'
          f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#cloth-{key})" class="foilbg"/>')
    # A fine damask: small diamonds in a lattice, very faint.
    damask = []
    for row in range(-1, 24):
        for col in range(-1, 18):
            x = col * 4.2 + (2.1 if row % 2 else 0)
            y = row * 4.2
            damask.append(shape(SUIT_PATHS["diamonds"], x, y, 1.1, "#FFFFFF",
                                extra='fill-opacity="0.06"'))
    if letter == "★":
        idx = shape(STAR, 11.4, 13.6, 5.2, G, cls="foil")
        idx += "".join(shape(SUIT_PATHS["diamonds"], 11.4, 18.6 + k * 1.75, 1.2, G, cls="foil")
                       for k in range(i + 1))
        idx += shape(CROWN, 11.4, 18.6 + (i + 1) * 1.75 + 0.6, 2.7, G, cls="foil")
    else:
        idx = index(letter, None, G, True, letter_fill=G, dots=i + 1)
    medal = (f'<circle cx="{CX}" cy="{CY}" r="17.5" fill="{cloth}" fill-opacity="0.55"/>'
             f'<circle cx="{CX}" cy="{CY}" r="17.5" fill="none" stroke="{G}" '
             f'stroke-width="0.35" class="foil"/>'
             f'<circle cx="{CX}" cy="{CY}" r="16.4" fill="none" stroke="{G}" '
             f'stroke-width="0.18" class="foil"/>'
             + laurel(CX, CY, 20.5, G, leaves=12, size=2.6))
    if key == "jack":
        art = (shape(SHIELD, CX, CY, 21, G, cls="foil")
               + shape(SHIELD, CX, CY - 0.4, 17.4, cloth)
               + shape(SWORD, CX, CY, 16, G, cls="foil"))
    else:
        art = shape(emblem, CX, CY - (1 if key == "king" else 0), 22, G, cls="foil")
    names = both_ends(text(CX, 82.2, name, 3.6, fill=G, weight=700, spacing=0.5, cls="foil")
                      + text(CX, 85.4, "OF THE COURT", 1.9, fill=G, weight=500,
                             spacing=0.7, cls="foil"))
    return svg(bg + "".join(damask) + frame() + both_ends(idx) + medal + art + names)


def joker(colour: str) -> str:
    letters = "".join(text(11.2, 13.4 + k * 4.1, ch, 3.6, fill=colour, weight=700)
                      for k, ch in enumerate("JOKER"))
    art = (laurel(CX, CY + 2, 18.5, G, leaves=12, size=2.6)
           + shape(JESTER, CX, CY - 1, 24, colour)
           + text(CX, 76.6, "JOKER", 3.4, fill=colour, weight=700, spacing=0.8)
           + text(CX, 80.4, "for standard games", 2.4, family="Cormorant", weight=500,
                  fill=colour, style="italic"))
    return svg(ivory_bg() + frame() + both_ends(letters) + art)


def qr_path(data: str, x: float, y: float, size: float, colour=INK) -> str:
    q = segno.make(data, error="m")
    m = [list(r) for r in q.matrix]
    n = len(m)
    cell = size / n
    d = []
    for r, row in enumerate(m):
        for c, v in enumerate(row):
            if v:
                d.append(f"M{x + c * cell:.3f} {y + r * cell:.3f}h{cell:.3f}v{cell:.3f}h-{cell:.3f}z")
    return (f'<rect x="{x - 1.2}" y="{y - 1.2}" width="{size + 2.4}" height="{size + 2.4}" '
            f'rx="0.8" fill="#FFFFFF"/><path d="{"".join(d)}" fill="{colour}"/>')


def para(lines: list[str], x: float, y: float, size=3.0, lead=4.0, colour=INK,
         anchor="start", style="normal", weight=500) -> str:
    return "".join(text(x, y + i * lead, s, size, family="Cormorant", weight=weight,
                        fill=colour, anchor=anchor, style=style)
                   for i, s in enumerate(lines))


def rules_card() -> str:
    body = (text(CX, 16.2, "THE KING’S COURT", 3.6, fill=G, weight=700, spacing=0.4, cls="foil")
            + shape(CROWN, CX, 11.2, 4.4, G, cls="foil")
            + text(CX, 20.4, "A cooperative trick-taking game for 2 to 6", 2.6,
                   family="Cormorant", style="italic", fill=INK)
            + para([
                "Keep the Aces to 9s, marked with a small",
                "gold crown, and the four Court Cards.",
                "Set the 10s, picture cards and Jokers aside.",
                "",
                "Deal all forty. Whoever holds the King card",
                "is King for the round.",
                "",
                "Open the app to deal the court its tasks.",
                "Follow suit; the highest card wins the trick.",
                "Court Cards beat every other card.",
                "Complete every task, together, to win.",
            ], 10.6, 26.2, size=2.75, lead=3.25)
            + qr_path(APP_URL, CX - 7.5, 63.6, 15)
            + text(CX, 84.0, "Scan to play, learn or keep the tasks", 2.3,
                   family="Cormorant", style="italic", fill=INK))
    return svg(ivory_bg() + frame() + body)


def NFC(cx, cy, s, colour) -> str:
    arcs = "".join(
        f'<path d="M{cx + r * 0.55:.2f} {cy - r:.2f} A {r} {r} 0 0 1 {cx + r * 0.55:.2f} {cy + r:.2f}" '
        f'fill="none" stroke="{colour}" stroke-width="{s * 0.09:.2f}" stroke-linecap="round"/>'
        for r in (s * 0.25, s * 0.45, s * 0.65))
    return f'<circle cx="{cx - s * 0.1:.2f}" cy="{cy}" r="{s * 0.1:.2f}" fill="{colour}"/>' + arcs


def court_awaits_card() -> str:
    url = f"{APP_URL}redeem?code={SAMPLE_CODE}"
    body = (shape(CROWN, CX, 11.4, 4.4, G, cls="foil")
            + text(CX, 16.6, "YOUR COURT AWAITS", 3.4, fill=G, weight=700, spacing=0.35, cls="foil")
            + para(["This deck unlocks the full King’s Court:",
                    "the Chronicle, new task packs and more,",
                    "on any phone, tablet or computer."], CX, 22.6, size=2.75,
                   lead=3.3, anchor="middle")
            + qr_path(url, CX - 9, 34.6, 18)
            + text(CX, 59.0, SAMPLE_CODE, 3.2, family="Cinzel", weight=600, fill=INK,
                   spacing=0.6)
            + f'<line x1="14" y1="63.4" x2="{W - 14}" y2="63.4" stroke="{G}" '
              f'stroke-width="0.15" class="foil"/>'
            + NFC(CX, 70.4, 7, INK)
            + para(["Tap the box with your phone to open a",
                    "table everyone can join from their own."], CX, 78.4, size=2.6,
                   lead=3.1, anchor="middle", style="italic"))
    return svg(ivory_bg() + frame() + body)


def back() -> str:
    bg = f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#maroon)" class="foilbg"/>'
    x0, y0 = BLEED + 5.2, BLEED + 5.2
    x1, y1 = W - x0, H - y0
    clip = (f'<clipPath id="inner"><rect x="{x0}" y="{y0}" width="{x1 - x0}" '
            f'height="{y1 - y0}" rx="1.2"/></clipPath>')
    lattice = []
    step = 4.6
    for k in range(-30, 40):
        o = k * step
        lattice.append(f'<line x1="{o}" y1="0" x2="{o + H}" y2="{H}"/>')
        lattice.append(f'<line x1="{o}" y1="{H}" x2="{o + H}" y2="0"/>')
    dots = []
    # Lattice crossings, mirrored about the centre so the back is two-way.
    for i in range(-14, 15):
        for j in range(-14, 15):
            x = CX + (i + j) * step / 2
            y = CY + (i - j) * step / 2
            if x0 < x < x1 and y0 < y < y1:
                dots.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="0.32"/>')
    pattern = (f'<g clip-path="url(#inner)" class="foil">'
               f'<g stroke="{G}" stroke-width="0.18" fill="none" '
               f'transform="translate({CX - H / 2 - (CX - H / 2) % step} 0)">{"".join(lattice)}</g>'
               f'<g fill="{G}">{"".join(dots)}</g></g>')
    medal = (f'<ellipse cx="{CX}" cy="{CY}" rx="15.2" ry="19.6" fill="url(#maroon)" class="foilbg"/>'
             f'<ellipse cx="{CX}" cy="{CY}" rx="15.2" ry="19.6" fill="none" stroke="{G}" '
             f'stroke-width="0.4" class="foil"/>'
             f'<ellipse cx="{CX}" cy="{CY}" rx="14" ry="18.4" fill="none" stroke="{G}" '
             f'stroke-width="0.18" class="foil"/>'
             + shape(CROWN, CX, CY - 8.2, 11, G, cls="foil")
             + shape(CROWN, CX, CY + 8.2, 11, G, rotate=180, cls="foil")
             + f'<line x1="{CX - 8}" y1="{CY}" x2="{CX + 8}" y2="{CY}" stroke="{G}" '
               f'stroke-width="0.2" class="foil"/>'
             + shape(SUIT_PATHS["diamonds"], CX, CY, 3.4, G, cls="foil")
             + shape(SUIT_PATHS["diamonds"], CX - 9.6, CY, 1.4, G, cls="foil")
             + shape(SUIT_PATHS["diamonds"], CX + 9.6, CY, 1.4, G, cls="foil"))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}">{defs()}'
            f'<defs>{clip}</defs>{bg}{pattern}{frame(inset=3.2)}{medal}</svg>')


# --- the deck -------------------------------------------------------------


def cards() -> list[tuple[str, str]]:
    out = []
    n = 1
    for suit in ["spades", "hearts", "diamonds", "clubs"]:
        for rank in RANKS:
            name = f"{n:02d}-{suit}-{rank}"
            if rank == "A":
                s = ace(suit)
            elif rank in HEADWEAR:
                s = face_card(rank, suit)
            else:
                s = pip_card(int(rank), suit)
            out.append((name, s))
            n += 1
    for i, (key, *_rest) in enumerate(COURT):
        out.append((f"{n:02d}-court-{i + 1}-{key}", court_card(i)))
        n += 1
    out.append((f"{n:02d}-joker-red", joker(RED)))
    n += 1
    out.append((f"{n:02d}-joker-black", joker(INK)))
    n += 1
    out.append((f"{n:02d}-how-to-play", rules_card()))
    n += 1
    out.append((f"{n:02d}-your-court-awaits", court_awaits_card()))
    return out


def main(out: pathlib.Path):
    r = Renderer()
    try:
        deck = cards()
        for name, s in deck:
            r.png(s, W, H, out / "cards" / "png" / f"{name}.png")
            r.png(s, W, H, out / "cards" / "foil" / f"{name}-foil.png", foil=True)
        b = back()
        r.png(b, W, H, out / "cards" / "png" / "00-back.png")
        r.png(b, W, H, out / "cards" / "foil" / "00-back-foil.png", foil=True)
        r.pdf([s for _, s in deck], W, H, out / "cards" / "pdf" / "fronts.pdf")
        r.pdf([s for _, s in deck], W, H, out / "cards" / "pdf" / "fronts-foil.pdf", foil=True)
        r.pdf([b], W, H, out / "cards" / "pdf" / "back.pdf")
        r.pdf([b], W, H, out / "cards" / "pdf" / "back-foil.pdf", foil=True)
        sheet(r, deck, b, out / "preview" / "deck.png")
    finally:
        r.close()


def sheet(r: Renderer, deck, b, out: pathlib.Path, cols=10):
    """All the cards, trimmed, on felt: a preview, not for print."""
    from art import font_css
    tiles = []
    for _, s in [("back", b)] + deck:
        tiles.append(
            f'<div class="c"><div class="i">{s}</div></div>')
    html = f"""<!doctype html><html><head><meta charset="utf-8"><style>
{font_css()}
body{{margin:0;background:#0d3a24;padding:24px;font-family:Cinzel}}
.g{{display:grid;grid-template-columns:repeat({cols},126px);gap:14px}}
.c{{width:126px;height:176px;border-radius:7px;overflow:hidden;position:relative;
   box-shadow:0 3px 10px rgba(0,0,0,.45)}}
.i{{position:absolute;left:-6px;top:-6px;width:138px;height:188px}}
.i svg{{width:138px;height:188px;display:block}}
</style></head><body><div class="g">{"".join(tiles)}</div></body></html>"""
    rows = math.ceil(len(tiles) / cols)
    r.html_png(html, 24 * 2 + cols * 126 + (cols - 1) * 14, 48 + rows * 190, out)


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "print-out"))
