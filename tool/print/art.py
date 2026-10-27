"""Shared drawing pieces for the printed deck and box: suit shapes, emblems,
gold foil, fonts, and rendering SVG to PNG/PDF with Chromium (Playwright).

Everything is drawn as vectors in millimetres. Elements meant to be gold
foil carry class="foil": in a foil render they turn solid black on white
and everything else disappears, which is the foil plate a printer needs.
"""
from __future__ import annotations

import math
import pathlib
import re

HERE = pathlib.Path(__file__).resolve().parent
FONTS = HERE / "fonts"

# --- palette -----------------------------------------------------------

IVORY = "#F6F0E1"
IVORY_EDGE = "#EDE3CC"
INK = "#1B1A1F"
RED = "#8E1B23"
MAROON = "#6E1A26"
MAROON_DEEP = "#330A12"
GOLD = "#C29B45"
CLOTH = {  # the Court Cards, as in the app
    "joker": "#4A2670",
    "jack": "#0F5B3A",
    "queen": "#203C8C",
    "king": "#7E1828",
}

SUITS = {
    "hearts": ("♥", RED),
    "diamonds": ("♦", RED),
    "spades": ("♠", INK),
    "clubs": ("♣", INK),
}

# --- fonts -------------------------------------------------------------


def font_css() -> str:
    faces = [
        ("Cinzel", 500, "normal", "cinzel-latin-500-normal.woff2"),
        ("Cinzel", 600, "normal", "cinzel-latin-600-normal.woff2"),
        ("Cinzel", 700, "normal", "cinzel-latin-700-normal.woff2"),
        ("Cormorant", 500, "normal", "cormorant-garamond-latin-500-normal.woff2"),
        ("Cormorant", 600, "normal", "cormorant-garamond-latin-600-normal.woff2"),
        ("Cormorant", 700, "normal", "cormorant-garamond-latin-700-normal.woff2"),
        ("Cormorant", 500, "italic", "cormorant-garamond-latin-500-italic.woff2"),
    ]
    # Embedded, since a page set from a string can't load local files.
    return "\n".join(
        f"@font-face{{font-family:'{f}';font-weight:{w};font-style:{s};"
        f"src:url(data:font/woff2;base64,{_b64(file)}) format('woff2');}}"
        for f, w, s, file in faces
    )


_cache: dict[str, str] = {}


def _b64(file: str) -> str:
    if file not in _cache:
        import base64
        _cache[file] = base64.b64encode((FONTS / file).read_bytes()).decode()
    return _cache[file]


# --- gold --------------------------------------------------------------


def defs() -> str:
    """Gradients that stand in for foil on screen and in proofs."""
    return """
<defs>
  <linearGradient id="gold" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#8A6620"/>
    <stop offset="0.28" stop-color="#E6CB78"/>
    <stop offset="0.5" stop-color="#B38327"/>
    <stop offset="0.72" stop-color="#F2DC93"/>
    <stop offset="1" stop-color="#94701F"/>
  </linearGradient>
  <radialGradient id="ivory" cx="0.5" cy="0.45" r="0.75">
    <stop offset="0" stop-color="#FBF6EA"/>
    <stop offset="1" stop-color="#EFE5CF"/>
  </radialGradient>
  <radialGradient id="maroon" cx="0.5" cy="0.5" r="0.75">
    <stop offset="0" stop-color="#832433"/>
    <stop offset="1" stop-color="#2E0910"/>
  </radialGradient>
</defs>"""


G = "url(#gold)"

# --- shapes (drawn in a 100 x 100 box, centred on 50,50) -----------------

SUIT_PATHS = {
    "hearts": "M50 92 C 34 76, 2 56, 2 30 C 2 13, 14 4, 28 4 C 39 4, 46 11, 50 20 "
    "C 54 11, 61 4, 72 4 C 86 4, 98 13, 98 30 C 98 56, 66 76, 50 92 Z",
    "diamonds": "M50 2 C 61 21, 75 37, 92 50 C 75 63, 61 79, 50 98 C 39 79, 25 63, 8 50 "
    "C 25 37, 39 21, 50 2 Z",
    "spades": "M50 2 C 60 19, 98 38, 98 62 C 98 77, 87 86, 74 86 C 64 86, 57 81, 53 74 "
    "C 54 84, 59 92, 68 98 L 32 98 C 41 92, 46 84, 47 74 C 43 81, 36 86, 26 86 "
    "C 13 86, 2 77, 2 62 C 2 38, 40 19, 50 2 Z",
    "clubs": "M29.5 26 a20.5 20.5 0 1 0 41 0 a20.5 20.5 0 1 0 -41 0 "
    "M6 58 a20.5 20.5 0 1 0 41 0 a20.5 20.5 0 1 0 -41 0 "
    "M53 58 a20.5 20.5 0 1 0 41 0 a20.5 20.5 0 1 0 -41 0 "
    "M38 36 L 62 36 L 68 64 L 32 64 Z "
    "M50 52 C 52 74, 58 90, 70 98 L 30 98 C 42 90, 48 74, 50 52 Z",
}

CROWN = (
    "M10 80 L 5 30 L 28 50 L 50 12 L 72 50 L 95 30 L 90 80 Z "
    "M10 84 H 90 V 95 H 10 Z "
    "M5 31 m -7 0 a 7 7 0 1 0 14 0 a 7 7 0 1 0 -14 0 "
    "M50 12 m -7 0 a 7 7 0 1 0 14 0 a 7 7 0 1 0 -14 0 "
    "M95 31 m -7 0 a 7 7 0 1 0 14 0 a 7 7 0 1 0 -14 0"
)

_TIARA_OLD = (
    "M4 86 C 18 70, 30 62, 38 60 C 40 44, 44 30, 50 14 C 56 30, 60 44, 62 60 "
    "C 70 62, 82 70, 96 86 C 80 80, 64 77, 50 77 C 36 77, 20 80, 4 86 Z "
    "M50 14 m -6 0 a 6 6 0 1 0 12 0 a 6 6 0 1 0 -12 0 "
    "M30 63 m -4 0 a 4 4 0 1 0 8 0 a 4 4 0 1 0 -8 0 "
    "M70 63 m -4 0 a 4 4 0 1 0 8 0 a 4 4 0 1 0 -8 0"
)

PLUME = (
    "M52 96 C 46 74, 36 52, 40 32 C 43 18, 54 8, 70 2 C 60 14, 58 26, 62 38 "
    "C 66 52, 64 70, 58 96 Z M48 98 H 64 V 92 H 48 Z"
)

JESTER = (
    "M12 86 L 88 86 L 84 72 C 80 46, 90 30, 97 22 C 80 28, 67 42, 61 62 "
    "C 59 38, 54 20, 50 8 C 46 20, 41 38, 39 62 C 33 42, 20 28, 3 22 "
    "C 10 30, 20 46, 16 72 Z M10 89 H 90 V 96 H 10 Z "
    "M97 22 m -6 0 a 6 6 0 1 0 12 0 a 6 6 0 1 0 -12 0 "
    "M50 8 m -6 0 a 6 6 0 1 0 12 0 a 6 6 0 1 0 -12 0 "
    "M3 22 m -6 0 a 6 6 0 1 0 12 0 a 6 6 0 1 0 -12 0"
)

SHIELD = (
    "M14 8 H 86 V 48 C 86 74, 66 88, 50 96 C 34 88, 14 74, 14 48 Z"
)

SWORD = "M47 2 H 53 V 64 H 47 Z M34 62 H 66 V 69 H 34 Z M46 69 H 54 V 86 H 46 Z M50 92 m -6 0 a 6 6 0 1 0 12 0 a 6 6 0 1 0 -12 0"


def tiara_path() -> str:
    """A diadem: a curved band with five jewelled spires, tallest in the
    middle, and little arches between them."""
    parts = ["M6 84 Q 50 62 94 84 L 94 93 Q 50 71 6 93 Z"]
    for i in range(-2, 3):
        x = 50 + i * 17
        base = 79 - (1 - abs(i) / 2) * 9  # the band rises toward the middle
        top = 16 + abs(i) * 15
        w = 6.5 - abs(i)
        parts.append(f"M{x - w} {base} L {x} {top + 6} L {x + w} {base} Z")
        r = 5.5 - abs(i) * 0.8
        parts.append(f"M{x - r} {top} a {r} {r} 0 1 0 {2 * r} 0 a {r} {r} 0 1 0 {-2 * r} 0")
    for i in (-1.5, -0.5, 0.5, 1.5):
        x = 50 + i * 17
        base = 79 - (1 - abs(i) / 2) * 9
        parts.append(f"M{x - 6} {base} Q {x} {base - 14} {x + 6} {base} L {x + 3.5} {base} "
                     f"Q {x} {base - 9} {x - 3.5} {base} Z")
    return " ".join(parts)


def star_path(points=5, outer=48, inner=20) -> str:
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = -math.pi / 2 + i * math.pi / points
        pts.append(f"{50 + r * math.cos(a):.2f} {50 + r * math.sin(a):.2f}")
    return "M" + " L ".join(pts) + " Z"


STAR = star_path()
TIARA = tiara_path()


def shape(path: str, cx: float, cy: float, size: float, fill: str,
          rotate: float = 0, cls: str = "", extra: str = "") -> str:
    """[path] (100-unit box) centred at cx,cy and [size] mm across."""
    s = size / 100
    c = f' class="{cls}"' if cls else ""
    # Each subpath drawn on its own, so overlapping parts (a club's three
    # leaves, a crown's jewels) simply join up.
    parts = [p.strip() for p in re.split(r"(?=M)", path) if p.strip()]
    paths = "".join(f'<path d="{p}" fill="{fill}" {extra}/>' for p in parts)
    return (
        f'<g transform="translate({cx:.3f} {cy:.3f}) rotate({rotate}) '
        f'scale({s:.5f}) translate(-50 -50)"{c}>{paths}</g>'
    )


def text(x, y, s, size, family="Cinzel", weight=600, fill=INK, anchor="middle",
         rotate=0, cls="", spacing=0, style="normal") -> str:
    c = f' class="{cls}"' if cls else ""
    rot = f' transform="rotate({rotate} {x:.3f} {y:.3f})"' if rotate else ""
    return (
        f'<text x="{x:.3f}" y="{y:.3f}" font-family="{family}" font-weight="{weight}" '
        f'font-style="{style}" font-size="{size}" fill="{fill}" text-anchor="{anchor}" '
        f'letter-spacing="{spacing}"{rot}{c}>{s}</text>'
    )


def laurel(cx, cy, r, fill, cls="foil", leaves=11, size=2.6) -> str:
    """Two branches of leaves curving round a circle, open at the top."""
    out = [f'<g class="{cls}">']
    for side in (-1, 1):
        for i in range(leaves):
            # From the bottom up one side.
            a = math.pi / 2 + side * (0.25 + i * (2.35 / leaves))
            x = cx + r * math.cos(a)
            y = cy + r * math.sin(a)
            tangent = math.degrees(a) + (90 if side > 0 else -90)
            out.append(
                f'<ellipse cx="{x:.3f}" cy="{y:.3f}" rx="{size * 0.42:.3f}" ry="{size:.3f}" '
                f'fill="{fill}" transform="rotate({tangent + side * 28:.2f} {x:.3f} {y:.3f})"/>'
            )
    out.append("</g>")
    return "".join(out)


def filigree_corner(x, y, sx, sy, stroke, w=0.22) -> str:
    """A small scroll in a frame corner; sx, sy flip it into place."""
    return (
        f'<g transform="translate({x} {y}) scale({sx} {sy})" class="foil">'
        f'<path d="M0 6 C 0 2, 2 0, 6 0 M1.6 5.5 C 1.6 3, 3 1.6, 5.5 1.6 '
        f'M6 0 C 8.5 0, 9 2, 7.4 2.8 C 6.4 3.3, 5.6 2.4, 6.3 1.8 '
        f'M0 6 C 0 8.5, 2 9, 2.8 7.4 C 3.3 6.4, 2.4 5.6, 1.8 6.3" '
        f'fill="none" stroke="{stroke}" stroke-width="{w}" stroke-linecap="round"/>'
        f'<path d="M3.2 3.2 m -0.9 0 l 0.9 -0.9 l 0.9 0.9 l -0.9 0.9 Z" fill="{stroke}"/></g>'
    )


# --- rendering ---------------------------------------------------------

FOIL_CSS = """
svg * { visibility: hidden; }
.foil, .foil * { visibility: visible; }
.foil [fill]:not([fill="none"]), .foil[fill]:not([fill="none"]) { fill: #000 !important; }
.foil [stroke]:not([stroke="none"]), .foil[stroke]:not([stroke="none"]) { stroke: #000 !important; }
.foilbg { visibility: visible !important; fill: #fff !important; stroke: #fff !important; }
clipPath, clipPath * { visibility: visible !important; }
"""


def page(svg: str, w_mm: float, h_mm: float, foil: bool = False) -> str:
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
{font_css()}
html,body{{margin:0;padding:0;background:#fff}}
svg{{display:block;width:{w_mm}mm;height:{h_mm}mm}}
{FOIL_CSS if foil else ''}
@page{{size:{w_mm}mm {h_mm}mm;margin:0}}
</style></head><body>{svg}</body></html>"""


class Renderer:
    """Renders SVG documents (sized in mm) to PNG at a given DPI, and
    collects pages into PDFs."""

    def __init__(self):
        from playwright.sync_api import sync_playwright

        self._pw = sync_playwright().start()
        self._browser = self._pw.chromium.launch()

    def png(self, svg: str, w_mm: float, h_mm: float, out: pathlib.Path,
            dpi: int = 300, foil: bool = False):
        scale = dpi / 25.4 / (96 / 25.4)  # CSS px are 96 per inch
        w_px = round(w_mm / 25.4 * 96)
        h_px = round(h_mm / 25.4 * 96)
        pg = self._browser.new_page(
            viewport={"width": w_px, "height": h_px}, device_scale_factor=scale)
        pg.set_content(page(svg, w_mm, h_mm, foil))
        pg.evaluate("document.fonts.ready")
        pg.wait_for_timeout(50)
        out.parent.mkdir(parents=True, exist_ok=True)
        pg.screenshot(path=str(out), clip={"x": 0, "y": 0, "width": w_px, "height": h_px})
        pg.close()

    def pdf(self, svgs: list[str], w_mm: float, h_mm: float, out: pathlib.Path,
            foil: bool = False):
        body = "".join(
            f'<div style="page-break-after:always;width:{w_mm}mm;height:{h_mm}mm">{s}</div>'
            for s in svgs)
        pg = self._browser.new_page()
        pg.set_content(page(body, w_mm, h_mm, foil))
        pg.evaluate("document.fonts.ready")
        pg.wait_for_timeout(100)
        out.parent.mkdir(parents=True, exist_ok=True)
        pg.pdf(path=str(out), width=f"{w_mm}mm", height=f"{h_mm}mm",
               print_background=True, prefer_css_page_size=True)
        pg.close()

    def html_png(self, html: str, w_px: int, h_px: int, out: pathlib.Path, scale=2):
        pg = self._browser.new_page(
            viewport={"width": w_px, "height": h_px}, device_scale_factor=scale)
        pg.set_content(html)
        pg.evaluate("document.fonts.ready")
        pg.wait_for_timeout(200)
        out.parent.mkdir(parents=True, exist_ok=True)
        pg.screenshot(path=str(out), full_page=True)
        pg.close()

    def close(self):
        self._browser.close()
        self._pw.stop()
