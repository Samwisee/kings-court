"""The King's Court printed deck, in the game's own look.

A full standard deck (52 cards and two Jokers) that is also the King's
Court deck: the Aces to 9s carry a small gold crown, and the face cards
are the app's Court Cards, in every suit's colour, so players choose which
Jack, Queen and King make their court. Plus two cards about the game.

Four-colour suits (♥ red, ♦ blue, ♣ green, ♠ black), the app's fonts
(Cinzel Decorative and Alegreya Sans), its Court Card cloths, patterns and
gold emblems, with gold foil and a cartoon outline.

Poker size, 63 x 88 mm, drawn with 3 mm bleed (69 x 94 mm). Each card is
rendered as artwork and as a foil plate (black = gold foil).

Run:  python3 tool/print/deck.py OUT_DIR
"""
from __future__ import annotations

import math
import pathlib
import sys

import segno

from art import Renderer
from brand import (CARD, CROWN, FELT, GILT, GOLD_DARK, GOLD_LIGHT, GOLD_MID,
                   INK, JOKER_CLOTH, OUTLINE, SUIT_CLOTH, SUIT_INK, brass_inlay,
                   cloth_gradient, crown, defs, emblem, harlequin, lattice,
                   outlined, place, star, stripes, suit, sunburst, text)

W, H = 69.0, 94.0          # with bleed
BLEED = 3.0
CX, CY = W / 2, H / 2
APP_URL = "https://samwisee.github.io/kings-court/"
SAMPLE_CODE = "KC-7Q4M-X2PA"
DISPLAY = "Cinzel Decorative"
BODY = "Alegreya Sans"

RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
NAMES = {"J": "Jack", "Q": "Queen", "K": "King"}

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


def svg(body: str, extra_defs: str = "") -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}">'
            f'{defs(extra_defs)}{body}</svg>')


def both_ends(content: str) -> str:
    return content + f'<g transform="rotate(180 {CX} {CY})">{content}</g>'


def rim(dark_line: bool = True) -> str:
    """The thick gold rim round every card, with a cartoon outline either
    side, and a fine inner frame."""
    x = BLEED + 2.1
    w, h = W - 2 * x, H - 2 * x
    out = ""
    if dark_line:
        out += (f'<rect x="{x}" y="{y_(x)}" width="{w}" height="{h}" rx="3.4" fill="none" '
                f'stroke="{OUTLINE}" stroke-width="2.0"/>')
    out += (f'<rect x="{x}" y="{x}" width="{w}" height="{h}" rx="3.4" fill="none" '
            f'stroke="url(#giltRim)" stroke-width="1.35" class="foil"/>'
            f'<rect x="{x + 3}" y="{x + 3}" width="{w - 6}" height="{h - 6}" rx="2" fill="none" '
            f'stroke="{GOLD_MID}" stroke-opacity="0.75" stroke-width="0.25" class="foil"/>')
    return out


def y_(v):
    return v


# --- number cards ---------------------------------------------------------------


def number_index(rank: str, name: str, crowned: bool) -> str:
    colour = SUIT_INK[name]
    x = 12.9
    size = 9.6 if rank != "10" else 8.2
    out = text(x, 17.6, rank, size, family=BODY, weight=700, fill=colour,
               spacing=-0.5 if rank == "10" else 0)
    out += suit(name, x, 22.6, 5.8, colour)
    if crowned:
        # The King's Court mark: this card is in the game's deck.
        out += place(outlined(CROWN, outline=6, shadow=False), x, 29.0, 4.2, 100, 75)
    return out


def face_bg() -> str:
    return f'<rect width="{W}" height="{H}" fill="url(#cardFace)" class="foilbg"/>'


def number_card(n: int, name: str) -> str:
    colour = SUIT_INK[name]
    size = 10.8 if n <= 6 else 9.6
    x0, x1 = CX - 11.2, CX + 11.2
    y0, y1 = 24.0, H - 24.0
    pips = "".join(
        suit(name, x0 + (x1 - x0) * u, y0 + (y1 - y0) * v, size, colour,
             rotate=180 if v > 0.5 else 0)
        for u, v in PIPS[n])
    return svg(face_bg() + rim() + both_ends(number_index(str(n), name, n <= 9)) + pips)


def ace(name: str) -> str:
    """A plain, large pip: the Court Cards are the stars of this deck."""
    colour = SUIT_INK[name]
    return svg(face_bg() + rim() + both_ends(number_index("A", name, True))
               + suit(name, CX, CY, 26, colour))


# --- face cards: the Court Cards in every suit's colour ---------------------------------


EMBLEM_Y = CY + 1.5


def cloth_card(gid: str, top: str, bottom: str, pattern: str, art: str,
               index: str, footer: str = "") -> str:
    bg = f'<rect width="{W}" height="{H}" fill="url(#{gid})" class="foilbg"/>'
    return svg(bg + pattern + rim() + both_ends(index) + art + footer,
               cloth_gradient(gid, top, bottom))


def court_index(letter: str, name: str | None) -> str:
    x = 12.9
    out = text(x, 18.6, letter, 9.4, family=DISPLAY, weight=900, fill=GILT, cls="foil",
               stroke=OUTLINE, stroke_w=0.9)
    if name:
        out += suit(name, x, 24.4, 5.4, GILT, cls="foil", outline=9)
    return out


def face_card(rank: str, name: str) -> str:
    top, bottom = SUIT_CLOTH[name]
    pattern = {"J": stripes, "Q": lattice, "K": sunburst}[rank](W, H)
    art = emblem({"J": "jack", "Q": "queen", "K": "king"}[rank], top, CX, EMBLEM_Y)
    footer = text(CX, 82.4, NAMES[rank].upper(), 3.3, family=DISPLAY, weight=900,
                  fill=GILT, cls="foil", spacing=0.6, stroke=OUTLINE, stroke_w=0.5)
    return cloth_card(f"cloth-{name}-{rank}", top, bottom, pattern, art,
                      court_index(rank, name), footer=footer)


def joker(colour: str) -> str:
    top, bottom = JOKER_CLOTH[colour]
    dark = "#1A0C2A" if colour == "purple" else "#5A1E00"
    star_idx = place(outlined(star(), outline=7, shadow=False), 12.9, 15.6, 6.6, 100, 100)
    letters = "".join(text(12.9, 24.6 + k * 3.6, ch, 3.2, family=DISPLAY, weight=900,
                           fill=GILT, cls="foil", stroke=OUTLINE, stroke_w=0.45)
                      for k, ch in enumerate("JOKER"))
    return cloth_card(f"joker-{colour}", top, bottom, harlequin(W, H, dark=dark),
                      emblem("joker", top if colour == "purple" else bottom, CX, EMBLEM_Y), star_idx + letters)


# --- cards about the game ------------------------------------------------------


def felt_bg() -> str:
    return f'<rect width="{W}" height="{H}" fill="url(#felt)" class="foilbg"/>'


def qr(data: str, x: float, y: float, size: float) -> str:
    q = segno.make(data, error="m")
    m = [list(r) for r in q.matrix]
    cell = size / len(m)
    d = "".join(f"M{x + c * cell:.3f} {y + r * cell:.3f}h{cell:.3f}v{cell:.3f}h-{cell:.3f}z"
                for r, row in enumerate(m) for c, v in enumerate(row) if v)
    return (f'<rect x="{x - 1.4}" y="{y - 1.4}" width="{size + 2.8}" height="{size + 2.8}" '
            f'rx="1.2" fill="{CARD}" stroke="{GOLD_MID}" stroke-width="0.4"/>'
            f'<path d="{d}" fill="{INK}"/>')


def lines(rows, x, y, size=2.9, lead=3.6, fill="#E9F2EC", anchor="start", weight=500):
    return "".join(text(x, y + i * lead, s, size, family=BODY, weight=weight, fill=fill,
                        anchor=anchor) for i, s in enumerate(rows))


def heading(s, y, size=3.9):
    return text(CX, y, s, size, family=DISPLAY, weight=900, fill=GILT, cls="foil",
                stroke=OUTLINE, stroke_w=0.5)


def rules_card() -> str:
    body = (place(crown()[0], CX, 11.6, 9, 100, 75)
            + heading("THE KING’S COURT", 19.6)
            + text(CX, 23.8, "Cooperative trick-taking for 2 to 6", 2.7, family=BODY,
                   weight=500, fill=GOLD_LIGHT)
            + lines(["Choose your court: one Jack, one Queen",
                     "and one King, in any colours you like,",
                     "and a Joker. (The app’s are green, blue",
                     "and red.) Add the crowned Aces to 9s",
                     "and set the other cards aside.",
                     "",
                     "Deal them all. Whoever holds the King",
                     "is King. Open the app to deal the tasks,",
                     "follow suit, and win every task together.",
                     "Court Cards beat all, Joker lowest."], 11.4, 30.2, size=2.7, lead=3.3)
            + qr(APP_URL, CX - 7.5, 66.2, 15))
    return svg(felt_bg() + rim() + body)


def nfc(cx, cy, s, colour):
    arcs = "".join(
        f'<path d="M{cx + r * 0.55:.2f} {cy - r:.2f} A {r} {r} 0 0 1 {cx + r * 0.55:.2f} {cy + r:.2f}" '
        f'fill="none" stroke="{colour}" stroke-width="{s * 0.1:.2f}" stroke-linecap="round"/>'
        for r in (s * 0.25, s * 0.45, s * 0.65))
    return f'<circle cx="{cx - s * 0.1:.2f}" cy="{cy}" r="{s * 0.11:.2f}" fill="{colour}"/>' + arcs


def awaits_card() -> str:
    url = f"{APP_URL}redeem?code={SAMPLE_CODE}"
    body = (place(crown()[0], CX, 11.6, 9, 100, 75)
            + heading("YOUR COURT AWAITS", 19.6, 3.6)
            + lines(["This deck unlocks the full King’s Court:",
                     "the Chronicle, task packs and more,",
                     "on any phone, tablet or computer."], CX, 25.4, size=2.7, lead=3.3,
                    anchor="middle")
            + qr(url, CX - 9, 37.0, 18)
            + text(CX, 62.0, SAMPLE_CODE, 3.4, family=BODY, weight=700, fill=GOLD_LIGHT,
                   spacing=0.5)
            + nfc(CX, 70.4, 7, GOLD_LIGHT)
            + lines(["Tap the box with your phone to open",
                     "a table everyone joins from their own."], CX, 79.4, size=2.6,
                    lead=3.1, anchor="middle"))
    return svg(felt_bg() + rim() + body)


# --- the back ------------------------------------------------------------------


def back() -> str:
    """The table's green felt inside an ivory border, so a back can never be
    mistaken for a face: a field of little crowns, the brass rim, and a
    medallion that reads the same either way up."""
    bg = f'<rect width="{W}" height="{H}" fill="url(#cardFace)" class="foilbg"/>'
    x = BLEED + 3.2
    w, h = W - 2 * x, H - 2 * x
    panel = (f'<rect x="{x}" y="{x}" width="{w}" height="{h}" rx="3" fill="{OUTLINE}" '
             f'stroke="{OUTLINE}" stroke-width="1.6"/>'
             f'<rect x="{x}" y="{x}" width="{w}" height="{h}" rx="3" fill="url(#felt)"/>')
    # Little crowns in rows, every other row turned, in a lighter green.
    tiles = []
    step_x, step_y = 7.0, 7.2
    row = 0
    y = x + 2.4
    while y < x + h + 3:
        off = 0 if row % 2 == 0 else step_x / 2
        cx = x + 1.2 + off
        while cx < x + w + 3:
            tiles.append(place(f'<path d="{CROWN}" fill="#1F7A4F"/>', cx, y, 3.4, 100, 75,
                               rotate=180 if row % 2 else 0))
            cx += step_x
        y += step_y
        row += 1
    clip = (f'<clipPath id="backPanel"><rect x="{x}" y="{x}" width="{w}" height="{h}" rx="3"/>'
            f'</clipPath>')
    field = f'<g clip-path="url(#backPanel)">{"".join(tiles)}</g>'
    rim_ = (f'<rect x="{x}" y="{x}" width="{w}" height="{h}" rx="3" fill="none" '
            f'stroke="url(#giltRim)" stroke-width="1.1" class="foil"/>'
            f'<rect x="{x + 2.2}" y="{x + 2.2}" width="{w - 4.4}" height="{h - 4.4}" rx="2" '
            f'fill="none" stroke="{GOLD_MID}" stroke-opacity="0.8" stroke-width="0.25" class="foil"/>')
    rx, ry = 15.5, 22.5
    medal = (f'<ellipse cx="{CX}" cy="{CY}" rx="{rx + 0.9}" ry="{ry + 0.9}" fill="{OUTLINE}"/>'
             f'<ellipse cx="{CX}" cy="{CY}" rx="{rx}" ry="{ry}" fill="{FELT}" class="foilbg"/>'
             f'<ellipse cx="{CX}" cy="{CY}" rx="{rx}" ry="{ry}" fill="none" '
             f'stroke="url(#giltRim)" stroke-width="1.1" class="foil"/>'
             f'<ellipse cx="{CX}" cy="{CY}" rx="{rx - 2}" ry="{ry - 2}" fill="none" '
             f'stroke="{GOLD_MID}" stroke-width="0.25" class="foil"/>'
             + place(crown()[0], CX, CY - 9.4, 15, 100, 75)
             + place(crown()[0], CX, CY + 9.4, 15, 100, 75, rotate=180)
             + "".join(suit(s_, CX + (i - 1.5) * 5.2, CY, 3.4, c, outline=9)
                       for i, (s_, c) in enumerate([("spades", "#1D1B18"), ("hearts", "#B3122B"),
                                                    ("clubs", "#13793A"), ("diamonds", "#1A5BC8")])))
    return svg(bg + panel + f"<defs>{clip}</defs>" + field + rim_ + medal)


# --- the deck ------------------------------------------------------------------


def cards() -> list[tuple[str, str]]:
    out = []
    n = 1
    for name in ["spades", "hearts", "diamonds", "clubs"]:
        for rank in RANKS:
            if rank == "A":
                s = ace(name)
            elif rank in NAMES:
                s = face_card(rank, name)
            else:
                s = number_card(int(rank), name)
            out.append((f"{n:02d}-{name}-{rank}", s))
            n += 1
    for colour in ("purple", "orange"):
        out.append((f"{n:02d}-joker-{colour}", joker(colour)))
        n += 1
    out.append((f"{n:02d}-how-to-play", rules_card()))
    n += 1
    out.append((f"{n:02d}-your-court-awaits", awaits_card()))
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
    """All the cards, trimmed, on the felt: a preview, not for print."""
    from art import font_css
    tiles = "".join(f'<div class="c"><div class="i">{s}</div></div>'
                    for _, s in [("back", b)] + deck)
    html = f"""<!doctype html><html><head><meta charset="utf-8"><style>
{font_css()}
body{{margin:0;background:radial-gradient(ellipse at 50% 30%,#16603C,#0A3622);padding:24px}}
.g{{display:grid;grid-template-columns:repeat({cols},126px);gap:14px}}
.c{{width:126px;height:176px;border-radius:9px;overflow:hidden;position:relative;
   box-shadow:0 4px 12px rgba(0,0,0,.5)}}
.i{{position:absolute;left:-6px;top:-6px;width:138px;height:188px}}
.i svg{{width:138px;height:188px;display:block}}
</style></head><body><div class="g">{tiles}</div></body></html>"""
    rows = math.ceil((len(deck) + 1) / cols)
    r.html_png(html, 48 + cols * 126 + (cols - 1) * 14, 48 + rows * 190, out)


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "print-out"))
