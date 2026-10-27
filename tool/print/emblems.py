"""The four Court Card emblems, drawn once and used everywhere: the printed
deck (as SVG) and the app (generated Dart, lib/play/emblems.g.dart).

They share one design so they read as a set:
  * each stands on the same jewelled band (or, for the Jack, a crossguard
    of the same weight),
  * each has three gold pearls at its tips in the same places,
  * each carries gems in the cloth's colour: a lozenge in the middle, a
    stud either side,
  * the same dark cartoon outline and gilt.

Everything is in a 100 x 100 box. Shapes are lists of primitives:
  ("path", commands, role)       commands: ("M", x, y) ("L", x, y)
                                 ("Q", cx, cy, x, y) ("C", c1x, c1y, c2x, c2y, x, y) ("Z",)
  ("circle", cx, cy, r, role)
  ("rrect", x, y, w, h, r, role)
  ("stroke", commands, width, role)
role: "gold" (gilt, foil), "gem" (the cloth's colour) or "dark" (dark gold).

Run:  python3 tool/print/emblems.py   (writes the Dart file)
"""
from __future__ import annotations

import math
import pathlib

OUTLINE_W = 5.0   # the cartoon outline, in the 100-unit box

# The shared pieces ------------------------------------------------------------

BAND_Y, BAND_H = 76.0, 13.0
PEARLS = [(8.0, 30.0, 6.0), (50.0, 12.0, 6.6), (92.0, 30.0, 6.0)]


def band(y=BAND_Y, x0=14.0, x1=86.0, h=BAND_H):
    cy = y + h / 2
    return [
        ("rrect", x0, y, x1 - x0, h, 4.0, "gold"),
        *gems(cy, x0, x1),
    ]


def gems(cy, x0, x1, size=1.0):
    """A lozenge in the middle and a stud either side."""
    w, h = 11.0 * size, 9.5 * size
    return [
        ("path", [("M", 50, cy - h / 2), ("L", 50 + w / 2, cy), ("L", 50, cy + h / 2),
                  ("L", 50 - w / 2, cy), ("Z",)], "gem"),
        ("circle", x0 + (50 - x0) * 0.42, cy, 2.5 * size, "gem"),
        ("circle", x1 - (x1 - 50) * 0.42, cy, 2.5 * size, "gem"),
    ]


def pearls(points=PEARLS):
    return [("circle", x, y, r, "gold") for x, y, r in points]


# The four ---------------------------------------------------------------------


def joker():
    """The jester's cap: three curling horns with bells, on the band."""
    cap = [("M", 17, 77), ("Q", 13, 50, 8, 30), ("Q", 28, 37, 37, 56),
           ("Q", 41, 28, 50, 12), ("Q", 59, 28, 63, 56), ("Q", 72, 37, 92, 30),
           ("Q", 87, 50, 83, 77), ("Z",)]
    seams = [("stroke", [("M", 37, 56), ("Q", 36, 66, 36, 76)], 2.0, "dark"),
             ("stroke", [("M", 63, 56), ("Q", 64, 66, 64, 76)], 2.0, "dark")]
    return [("path", cap, "gold"), *seams, *pearls(), *band()]


def jack():
    """A sword behind a shield: pommel and crossguard ends are the pearls,
    the crossguard is the band, and the shield carries the gems."""
    sword = [("rrect", 46, 12, 8, 14, 2, "gold"),
             ("path", [("M", 44.5, 30), ("L", 55.5, 30), ("L", 55.5, 86), ("L", 50, 96),
                       ("L", 44.5, 86), ("Z",)], "gold")]
    guard = [("rrect", 14, 22, 72, 11, 4, "gold"), *gems(27.5, 14, 86, size=0.82)]
    shield = [("path", [("M", 26, 38), ("L", 74, 38), ("L", 74, 56), ("Q", 72, 76, 50, 88),
                        ("Q", 28, 76, 26, 56), ("Z",)], "gold"),
              ("path", [("M", 50, 47), ("L", 58, 60), ("L", 50, 73), ("L", 42, 60), ("Z",)], "gem")]
    tips = pearls([(8.0, 27.5, 6.0), (50.0, 9.0, 6.6), (92.0, 27.5, 6.0)])
    return [*sword, *shield, *guard, *tips]


def _scroll(start, curve, centre, turn, end_r):
    """A sweep up from the band curling into a spiral (as in the app's tiara),
    in the 100 box."""
    cmds = [("M", *start), ("C", *curve)]
    fx, fy = curve[4], curve[5]
    cx, cy = centre
    a0 = math.atan2(fy - cy, fx - cx)
    r0 = math.hypot(fx - cx, fy - cy)
    for k in range(1, 33):
        f = k / 32
        a = a0 - turn * f
        r = r0 + (end_r - r0) * f
        cmds.append(("L", round(cx + r * math.cos(a), 2), round(cy + r * math.sin(a), 2)))
    return cmds


def _mirror(cmds):
    out = []
    for c in cmds:
        if c[0] == "Z":
            out.append(c)
            continue
        vals = list(c[1:])
        for i in range(0, len(vals), 2):
            vals[i] = round(100 - vals[i], 2)
        out.append((c[0], *vals))
    return out


def queen():
    """The tiara: a pointed spire with a gem, scrolls either side, pearls
    at the tips, on the band."""
    spire = [("M", 36, 77), ("C", 38, 62, 44, 40, 50, 18), ("C", 56, 40, 62, 62, 64, 77), ("Z",)]
    gem = [("path", [("M", 50, 42), ("L", 55.5, 54), ("L", 50, 66), ("L", 44.5, 54), ("Z",)], "gem")]
    left = _scroll((40, 76), (36, 56, 26, 46, 16, 50), (18.5, 58.5), math.pi * 1.6, 2.5)
    side = [("stroke", left, 6.5, "gold"), ("stroke", _mirror(left), 6.5, "gold")]
    tips = pearls([(8.0, 47.0, 5.2), (50.0, 12.0, 6.6), (92.0, 47.0, 5.2)])
    return [*side, ("path", spire, "gold"), *gem, *tips, *band()]


def king():
    """The crown: five points, pearls on the three tallest, on the band."""
    body = [("M", 16, 77), ("L", 8, 30), ("L", 31, 52), ("L", 50, 12), ("L", 69, 52),
            ("L", 92, 30), ("L", 84, 77), ("Z",)]
    return [("path", body, "gold"), *pearls(), *band()]


EMBLEMS = {"joker": joker, "jack": jack, "queen": queen, "king": king}


# SVG -------------------------------------------------------------------------


def _d(cmds):
    out = []
    for c in cmds:
        out.append(c[0] + (" " + " ".join(f"{v:g}" for v in c[1:]) if len(c) > 1 else ""))
    return " ".join(out)


def svg(name: str, gem: str, outline: str, gilt: str = "url(#gilt)",
        dark: str = "#9C7420") -> str:
    """The emblem as SVG in its 100 box: an outline layer (ink, with a drop
    shadow), the gold (foil), then gems and dark details (knocked out of
    the foil)."""
    ops = EMBLEMS[name]()
    back, gold, top = [], [], []
    for op in ops:
        kind, role = op[0], op[-1]
        if kind == "path":
            el = f'd="{_d(op[1])}"'
            shape = f"<path {el} fill=\"{{f}}\"{{s}}/>"
        elif kind == "circle":
            shape = f'<circle cx="{op[1]}" cy="{op[2]}" r="{op[3]}" fill="{{f}}"{{s}}/>'
        elif kind == "rrect":
            shape = (f'<rect x="{op[1]}" y="{op[2]}" width="{op[3]}" height="{op[4]}" rx="{op[5]}" '
                     f'fill="{{f}}"{{s}}/>')
        else:  # stroke
            w = op[2]
            if role == "gold":
                back.append(f'<path d="{_d(op[1])}" fill="none" stroke="{outline}" '
                            f'stroke-width="{w + OUTLINE_W}" stroke-linecap="round" stroke-linejoin="round"/>')
                gold.append(f'<path d="{_d(op[1])}" fill="none" stroke="{gilt}" stroke-width="{w}" '
                            f'stroke-linecap="round" stroke-linejoin="round"/>')
            else:
                top.append(f'<path d="{_d(op[1])}" fill="none" stroke="{dark}" stroke-width="{w}" '
                           f'stroke-linecap="round"/>')
            continue
        o = f' stroke="{outline}" stroke-width="{OUTLINE_W}" stroke-linejoin="round"'
        if role == "gold":
            back.append(shape.format(f=outline, s=o))
            gold.append(shape.format(f=gilt, s=""))
        elif role == "gem":
            top.append(shape.format(f=gem, s=f' stroke="{outline}" stroke-width="1.6" stroke-linejoin="round"'))
        else:
            top.append(shape.format(f=dark, s=""))
    return (f'<g filter="url(#drop)">{"".join(back)}</g>'
            f'<g class="foil">{"".join(gold)}</g>'
            f'<g class="foilknock">{"".join(top)}</g>')


# Dart ------------------------------------------------------------------------

DART_HEADER = '''// Generated by tool/print/emblems.py: the Court Card emblems, the same as
// on the printed deck. Edit the Python and re-run it, not this file.
// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';

/// Which Court Card emblem.
enum Emblem { joker, jack, queen, king }

/// Draws a Court Card emblem in gilt with a dark outline, its gems in
/// [gem] (the card's cloth colour), fitted into the space it's given.
class EmblemPainter extends CustomPainter {
  EmblemPainter(this.emblem, {required this.gem});
  final Emblem emblem;
  final Color gem;

  static const _goldLight = Color(0xFFF9E08C);
  static const _goldMid = Color(0xFFD4A63A);
  static const _goldDark = Color(0xFF9C7420);
  static const _outline = Color(0xFF5E420C);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);
    final gilt = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_goldLight, _goldMid, _goldDark],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    final outline = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = %(outline)s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final outlineFill = Paint()..color = _outline;
    final gemPaint = Paint()..color = gem;
    final gemEdge = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final dark = Paint()..color = _goldDark;
    final ops = switch (emblem) {
      Emblem.joker => _joker(),
      Emblem.jack => _jack(),
      Emblem.queen => _queen(),
      Emblem.king => _king(),
    };
    // Outline first, then gold, then gems and details on top.
    for (final op in ops) {
      if (op.role != 'gold') continue;
      if (op.stroke != null) {
        canvas.drawPath(op.path, Paint()
          ..color = _outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = op.stroke! + %(outline)s
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
      } else {
        canvas.drawPath(op.path, outlineFill);
        canvas.drawPath(op.path, outline);
      }
    }
    for (final op in ops) {
      if (op.role != 'gold') continue;
      if (op.stroke != null) {
        canvas.drawPath(op.path, Paint()
          ..shader = gilt.shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = op.stroke!
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
      } else {
        canvas.drawPath(op.path, gilt);
      }
    }
    for (final op in ops) {
      if (op.role == 'gem') {
        canvas.drawPath(op.path, gemPaint);
        canvas.drawPath(op.path, gemEdge);
      } else if (op.role == 'dark') {
        if (op.stroke != null) {
          canvas.drawPath(op.path, Paint()
            ..color = _goldDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = op.stroke!
            ..strokeCap = StrokeCap.round);
        } else {
          canvas.drawPath(op.path, dark);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(EmblemPainter old) => old.emblem != emblem || old.gem != gem;
}

class _Op {
  const _Op(this.path, this.role, [this.stroke]);
  final Path path;
  final String role;
  final double? stroke;
}

Path _circle(double x, double y, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

Path _rrect(double x, double y, double w, double h, double r) =>
    Path()..addRRect(RRect.fromLTRBR(x, y, x + w, y + h, Radius.circular(r)));
'''


def _dart_path(cmds) -> str:
    parts = ["Path()"]
    for c in cmds:
        k, v = c[0], [f"{x:g}".replace("-0", "-0") for x in c[1:]]
        v = [s if "." in s else s + ".0" for s in v]
        if k == "M":
            parts.append(f"..moveTo({v[0]}, {v[1]})")
        elif k == "L":
            parts.append(f"..lineTo({v[0]}, {v[1]})")
        elif k == "Q":
            parts.append(f"..quadraticBezierTo({', '.join(v)})")
        elif k == "C":
            parts.append(f"..cubicTo({', '.join(v)})")
        elif k == "Z":
            parts.append("..close()")
    return "".join(parts)


def _f(x) -> str:
    s = f"{x:g}"
    return s if "." in s or "e" in s else s + ".0"


def dart() -> str:
    out = [DART_HEADER % {"outline": _f(OUTLINE_W)}]
    for name, fn in EMBLEMS.items():
        ops = []
        for op in fn():
            kind, role = op[0], op[-1]
            if kind == "path":
                ops.append(f"_Op({_dart_path(op[1])}, '{role}')")
            elif kind == "circle":
                ops.append(f"_Op(_circle({_f(op[1])}, {_f(op[2])}, {_f(op[3])}), '{role}')")
            elif kind == "rrect":
                ops.append(f"_Op(_rrect({', '.join(_f(v) for v in op[1:6])}), '{role}')")
            else:
                ops.append(f"_Op({_dart_path(op[1])}, '{role}', {_f(op[2])})")
        body = ",\n      ".join(ops)
        out.append(f"\nList<_Op> _{name}() => [\n      {body},\n    ];\n")
    return "".join(out)


if __name__ == "__main__":
    target = pathlib.Path(__file__).resolve().parents[2] / "lib" / "play" / "emblems.g.dart"
    target.write_text(dart())
    print("wrote", target)
