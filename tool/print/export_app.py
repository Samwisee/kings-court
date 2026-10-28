"""Writes lib/skin/court/emblems.g.dart: the Court Card emblems exactly as the
printed deck draws them (brand.py), as Flutter canvas code, so the app and
the cards in the box are the same.

    python3 tool/print/export_app.py

Each emblem is drawn by brand.py as SVG; this reads that SVG back and turns
every shape into Path calls. Line weights that depend on the outline width
are kept as expressions of `ow`, so the app can choose its own.
"""

from __future__ import annotations

import math
import pathlib
import re
import xml.etree.ElementTree as ET

import brand

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "lib" / "skin" / "court" / "emblems.g.dart"

CLOTH = "#C10C10"           # stands in for the card's cloth colour
GILT = "url(#GILT)"         # stands in for the emblem's gold


def num(v: float) -> str:
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


# --- SVG path data to Dart ---------------------------------------------------

TOKEN = re.compile(r"[MmLlHhVvQqCcAaZz]|-?\d*\.?\d+(?:e-?\d+)?")


def path_dart(d: str) -> str:
    toks = TOKEN.findall(d)
    i = 0
    out = []
    cx = cy = sx = sy = 0.0
    cmd = None

    def nums(n):
        nonlocal i
        vals = [float(t) for t in toks[i:i + n]]
        i += n
        return vals

    while i < len(toks):
        t = toks[i]
        if re.fullmatch(r"[A-Za-z]", t):
            cmd = t
            i += 1
            if cmd in "Zz":
                out.append("..close()")
                cx, cy = sx, sy
                continue
        rel = cmd.islower()
        c = cmd.upper()
        if c == "M":
            x, y = nums(2)
            if rel:
                x, y = cx + x, cy + y
            out.append(f"..moveTo({num(x)}, {num(y)})")
            cx, cy = sx, sy = x, y
            cmd = "l" if rel else "L"
        elif c == "L":
            x, y = nums(2)
            if rel:
                x, y = cx + x, cy + y
            out.append(f"..lineTo({num(x)}, {num(y)})")
            cx, cy = x, y
        elif c == "H":
            (x,) = nums(1)
            x = cx + x if rel else x
            out.append(f"..lineTo({num(x)}, {num(cy)})")
            cx = x
        elif c == "V":
            (y,) = nums(1)
            y = cy + y if rel else y
            out.append(f"..lineTo({num(cx)}, {num(y)})")
            cy = y
        elif c == "Q":
            x1, y1, x, y = nums(4)
            if rel:
                x1, y1, x, y = cx + x1, cy + y1, cx + x, cy + y
            out.append(f"..quadraticBezierTo({num(x1)}, {num(y1)}, {num(x)}, {num(y)})")
            cx, cy = x, y
        elif c == "C":
            x1, y1, x2, y2, x, y = nums(6)
            if rel:
                x1, y1, x2, y2, x, y = cx + x1, cy + y1, cx + x2, cy + y2, cx + x, cy + y
            out.append(f"..cubicTo({num(x1)}, {num(y1)}, {num(x2)}, {num(y2)}, {num(x)}, {num(y)})")
            cx, cy = x, y
        elif c == "A":
            rx, ry, rot, large, sweep, x, y = nums(7)
            if rel:
                x, y = cx + x, cy + y
            out.append(f"..arcToPoint(Offset({num(x)}, {num(y)}), radius: Radius.elliptical({num(rx)}, {num(ry)}), "
                       f"rotation: {num(rot)}, largeArc: {str(bool(large)).lower()}, "
                       f"clockwise: {str(bool(sweep)).lower()})")
            cx, cy = x, y
        else:
            raise ValueError(c)
    return "Path()" + "".join(out)


# --- the emblem SVG to Dart drawing calls ------------------------------------


def colour(value: str, opacity: float) -> str:
    if value == GILT:
        return "gilt"
    if value.upper() == CLOTH:
        return "cloth" if opacity >= 1 else f"cloth.withValues(alpha: {num(opacity)})"
    v = value.lstrip("#")
    a = round(max(0.0, min(1.0, opacity)) * 255)
    return f"const Color(0x{a:02X}{v.upper()})"


def walk(el1, el2, clips, paths, lines, depth=1):
    """Walks the SVG drawn with ow=1 (el1) and ow=2 (el2) together, so a
    line weight w1/w2 becomes the expression a + b*ow."""
    pad = "  " * depth
    for a, b in zip(list(el1), list(el2)):
        tag = a.tag.split("}")[-1]
        if tag == "defs":
            for cp in a:
                if cp.tag.split("}")[-1] == "clipPath":
                    shape = [p for p in cp if p.tag.split("}")[-1] == "path"][0]
                    clips[cp.get("id")] = shape.get("d")
            continue
        if tag == "g":
            clip = a.get("clip-path")
            if clip:
                cid = clip[5:-1]
                k = len(paths)
                paths.append(clips[cid])
                lines.append(f"{pad}canvas.save();")
                lines.append(f"{pad}canvas.clipPath(_p[{k}]);")
            walk(a, b, clips, paths, lines, depth + (1 if clip else 0))
            if clip:
                lines.append(f"{pad}canvas.restore();")
            continue
        if tag == "BACKDROP":
            continue
        if tag != "path":
            continue
        k = len(paths)
        paths.append(a.get("d"))
        tf = a.get("transform")
        if tf:
            assert tf == "translate(100 0) scale(-1 1)", tf
            lines.append(f"{pad}canvas.save();")
            lines.append(f"{pad}canvas.translate(100, 0);")
            lines.append(f"{pad}canvas.scale(-1, 1);")
        fill = a.get("fill")
        if fill and fill != "none":
            op = float(a.get("fill-opacity", "1"))
            lines.append(f"{pad}canvas.drawPath(_p[{k}], Paint()..{'shader = gilt' if fill == GILT else 'color = ' + colour(fill, op)});"
                         .replace("Paint()..shader = gilt", "giltPaint"))
        stroke = a.get("stroke")
        if stroke and stroke != "none":
            op = float(a.get("stroke-opacity", "1"))
            w1 = float(a.get("stroke-width", "1"))
            w2 = float(b.get("stroke-width", "1"))
            k_ow = w2 - w1
            base = w1 - k_ow
            if abs(k_ow) < 1e-6:
                w = num(w1)
            elif abs(base) < 1e-6:
                w = f"ow * {num(k_ow)}"
            else:
                w = f"{num(base)} + ow * {num(k_ow)}"
            cap = {"round": "StrokeCap.round"}.get(a.get("stroke-linecap"), "StrokeCap.butt")
            join = {"round": "StrokeJoin.round"}.get(a.get("stroke-linejoin"), "StrokeJoin.miter")
            src = "..shader = gilt" if stroke == GILT else f"..color = {colour(stroke, op)}"
            lines.append(f"{pad}canvas.drawPath(_p[{k}], Paint(){src}..style = PaintingStyle.stroke"
                         f"..strokeWidth = {w}..strokeCap = {cap}..strokeJoin = {join});")
        if tf:
            lines.append(f"{pad}canvas.restore();")


def svg_of(fn, ow):
    art, box = fn(ow, GILT, CLOTH)
    # The Jack's inset shows the card behind it: in the app, a hole cut
    # through the emblem.
    art = re.sub(r'<defs><clipPath id="JACKINSET"><path d="([^"]+)"/></clipPath></defs>'
                 r'<g class="foilknock"><g clip-path="url\(#JACKINSET\)">BACKDROP</g>',
                 r'<g class="foilknock"><hole d="\1"/>', art)
    return f'<svg xmlns="http://www.w3.org/2000/svg">{art}</svg>', box


def emit(name, fn):
    s1, box = svg_of(fn, 1.0)
    s2, _ = svg_of(fn, 2.0)
    r1, r2 = ET.fromstring(s1), ET.fromstring(s2)
    paths, lines, clips = [], [], {}
    hole_lines = []
    # holes first found, drawn last with BlendMode.clear
    for h in r1.iter():
        if h.tag.split("}")[-1] == "hole":
            k = len(paths)
            paths.append(h.get("d"))
            hole_lines.append(f"  canvas.drawPath(_p[{k}], Paint()..blendMode = BlendMode.clear);")
    # holes are drawn where they appear in the SVG: replace the tag in place
    def walk_with_holes(e1, e2, depth=1):
        pad = "  " * depth
        for a, b in zip(list(e1), list(e2)):
            tag = a.tag.split("}")[-1]
            if tag == "hole":
                lines.append(hole_lines.pop(0).replace("  ", pad, 1))
            elif tag == "g" and not a.get("clip-path") and any(x.tag.split("}")[-1] == "hole" for x in a.iter()):
                walk_with_holes(a, b, depth)
            else:
                holder1, holder2 = ET.Element("g"), ET.Element("g")
                holder1.append(a)
                holder2.append(b)
                walk(holder1, holder2, clips, paths, lines, depth)
    walk_with_holes(r1, r2)
    x0, y0, x1, y1 = box
    path_list = ",\n".join(f"  {path_dart(d)}" for d in paths)
    return f"""
final List<Path> _{name}Paths = [
{path_list},
];

/// {name}: drawn in its own units, bounds ({num(x0)}, {num(y0)}) to ({num(x1)}, {num(y1)}).
void paint{name[0].upper() + name[1:]}(Canvas canvas, double ow, Color cloth) {{
  final _p = _{name}Paths;
  final gilt = _gilt({num(y0)}, {num(y1)});
  final giltPaint = Paint()..shader = gilt;
{chr(10).join(lines)}
}}

const {name}Bounds = Rect.fromLTRB({num(x0)}, {num(y0)}, {num(x1)}, {num(y1)});
"""


def main():
    anchors = brand.ANCHOR
    body = "".join([
        emit("jester", brand._jester),
        emit("jack", brand._jack),
        emit("tiara", brand._tiara),
        emit("king", brand._king),
    ])
    a = lambda k, d: anchors.get(k, d)
    anchor_lines = "\n".join(
        f"const {n}Anchor = Offset({num(a(k, (0, 0))[0])}, {num(a(k, (0, 0))[1])});"
        for n, k in [("jester", "joker"), ("jack", "jack"), ("tiara", "queen"), ("king", "king")])
    boxes = (f"const emblemBox = Size({num(brand.EMBLEM_BOX[0])}, {num(brand.EMBLEM_BOX[1])});\n"
             f"const jackBox = Size({num(brand.JACK_BOX[0])}, {num(brand.JACK_BOX[1])});\n"
             f"const kingBox = Size({num(brand.KING_BOX[0])}, {num(brand.KING_BOX[1])});\n"
             f"const outlineMm = {num(brand.OUTLINE_MM)};")
    OUT.write_text(f"""// GENERATED by tool/print/export_app.py from tool/print/brand.py: the Court
// Card emblems exactly as the printed deck draws them. Don't edit by hand;
// change brand.py and run the script again.
// ignore_for_file: prefer_const_constructors, no_leading_underscores_for_local_identifiers

import 'dart:ui';

const _goldLight = Color(0xFF{brand.GOLD_LIGHT[1:]});
const _goldMid = Color(0xFF{brand.GOLD_MID[1:]});
const _goldDark = Color(0xFF{brand.GOLD_DARK[1:]});

Shader _gilt(double y0, double y1) => Gradient.linear(
    Offset(0, y0), Offset(0, y1), const [_goldLight, _goldMid, _goldDark], const [0, 0.5, 1]);

/// Sizes on the printed card, in millimetres (the card is 63 wide).
{boxes}

/// The point of each emblem that sits at the centre of the card.
{anchor_lines}
{body}""")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
