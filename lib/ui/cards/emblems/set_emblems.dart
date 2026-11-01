/// The rooms' own Court Card emblems (card_look.dart: [EmblemSet]), in
/// place of the court's jester, sword, tiara and crown. Each is drawn in a
/// box 100 units square, centred on (50, 50), in its set's metal with a
/// dark line round it, as the court's are; card_view.dart places it on the
/// card.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../skin/looks.dart';

part 'emblems_sky.dart';
part 'emblems_salon.dart';
part 'emblems_play.dart';
part 'emblems_voyage.dart';

/// Where a set's emblems are drawn, in their own units.
const setEmblemBounds = Rect.fromLTWH(0, 0, 100, 100);
const setEmblemAnchor = Offset(50, 50);

/// Draws [set]'s emblem for [rank] (1 the Joker, 2 the Jack, 3 the Queen,
/// 4 the King), its outline [ow] wide, on [cloth].
void paintSetEmblem(Canvas canvas, EmblemSet set, int rank, double ow, Color cloth) {
  final pen = _Pen(canvas, ow, set, cloth);
  switch (set) {
    case EmblemSet.starlight:
      _starlight(pen, rank);
    case EmblemSet.snow:
      _snow(pen, rank);
    case EmblemSet.opera:
      _opera(pen, rank);
    case EmblemSet.classical:
      _classical(pen, rank);
    case EmblemSet.jazz:
      _jazz(pen, rank);
    case EmblemSet.atelier:
      _atelier(pen, rank);
    case EmblemSet.royale:
      _royale(pen, rank);
    case EmblemSet.napoli:
      _napoli(pen, rank);
    case EmblemSet.pharaoh:
      _pharaoh(pen, rank);
    case EmblemSet.pirate:
      _pirate(pen, rank);
  }
}

/// The metal each set is worked in: light, middle, dark.
const _gold = [Color(0xFFF9E08C), Color(0xFFD4A63A), Color(0xFF9C7420)];
const _silver = [Color(0xFFFFFFFF), Color(0xFFC9D2E3), Color(0xFF7E8AA6)];
const _ivory = [Color(0xFFFFFFFF), Color(0xFFEDE6D6), Color(0xFFB4AA94)];

/// What draws a set's emblems: its metal, the dark line round everything,
/// and the cloth behind (for what's cut through to it).
class _Pen {
  _Pen(this.canvas, this.ow, EmblemSet set, this.cloth)
      : metal = switch (set) {
          EmblemSet.starlight || EmblemSet.snow => _silver,
          EmblemSet.atelier => _ivory,
          _ => _gold,
        },
        dark = switch (set) {
          EmblemSet.starlight => const Color(0xFF141C38),
          EmblemSet.snow => const Color(0xFF1A2E48),
          EmblemSet.atelier => const Color(0xFF1A1A1A),
          _ => const Color(0xFF5E420C),
        };

  final Canvas canvas;
  final double ow;
  final List<Color> metal;
  final Color dark;
  final Color cloth;

  Shader get _shine =>
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: metal).createShader(setEmblemBounds);

  /// [p] in the set's metal, outlined.
  void gild(Path p) {
    edge(p, 2);
    canvas.drawPath(p, Paint()..shader = _shine);
  }

  /// [p] in [colour], outlined.
  void fill(Path p, Color colour) {
    edge(p, 2);
    canvas.drawPath(p, Paint()..color = colour);
  }

  /// [p] filled with a shade of [colour], lit from the top left.
  void shade(Path p, Color colour) {
    edge(p, 2);
    canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(colour, Colors.white, 0.3)!, colour, Color.lerp(colour, Colors.black, 0.35)!])
              .createShader(p.getBounds()));
  }

  /// The dark line along [p], [k] outlines wide.
  void edge(Path p, [double k = 1]) => canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ow * k
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = dark);

  /// A line along [p], [width] units wide, in metal, outlined.
  void bar(Path p, double width) {
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + ow * 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = dark);
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = _shine);
  }

  /// A fine line along [p] in [colour] (the dark, when null).
  void ink(Path p, [Color? colour, double k = 0.6]) => canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ow * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colour ?? dark);

  /// A gem at [c], [r] across, in [colour], with its glint.
  void gem(Offset c, double r, Color colour) {
    fill(Path()..addOval(Rect.fromCircle(center: c, radius: r)), colour);
    canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.35), r * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.6));
  }

  /// A pearl at [c].
  void pearl(Offset c, double r) => gem(c, r, const Color(0xFFF6F1E4));
}

// Shapes more than one set draws.

Path _circle(Offset c, double r) => Path()..addOval(Rect.fromCircle(center: c, radius: r));

Path _oval(Offset c, double w, double h) => Path()..addOval(Rect.fromCenter(center: c, width: w, height: h));

Path _rect(double l, double t, double r, double b, [double radius = 0]) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

/// A star of [n] points about [c], [r] to its points and [inner] of that
/// to its notches, a point straight up.
Path _star(Offset c, double r, {int n = 5, double inner = 0.45}) => _poly([
      for (var k = 0; k < n * 2; k++)
        c +
            Offset(math.cos(-math.pi / 2 + k * math.pi / n), math.sin(-math.pi / 2 + k * math.pi / n)) *
                (k.isEven ? r : r * inner)
    ]);

/// A crown's outline: a band from [l] to [r] between [top] and [bottom],
/// with [n] points rising to [peak] (the middle one highest by [lift]).
Path _crown(double l, double r, double top, double bottom, double peak, {int n = 5, double lift = 0}) {
  final p = Path()..moveTo(l, bottom);
  p.lineTo(l, top);
  final w = (r - l) / (n - 1);
  for (var k = 0; k < n; k++) {
    final x = l + k * w;
    final mid = (k - (n - 1) / 2).abs() / ((n - 1) / 2);
    p.lineTo(x, peak - lift * (1 - mid));
    if (k < n - 1) p.lineTo(x + w / 2, top - (top - peak) * 0.25);
  }
  p.lineTo(r, top);
  p.lineTo(r, bottom);
  return p..close();
}

/// A heart about [c], [s] across.
Path _heart(Offset c, double s) => Path()
  ..moveTo(c.dx, c.dy + s * 0.5)
  ..cubicTo(c.dx - s * 0.75, c.dy, c.dx - s * 0.45, c.dy - s * 0.6, c.dx, c.dy - s * 0.2)
  ..cubicTo(c.dx + s * 0.45, c.dy - s * 0.6, c.dx + s * 0.75, c.dy, c.dx, c.dy + s * 0.5)
  ..close();

/// A diamond about [c], [s] across.
Path _diamond(Offset c, double s) =>
    _poly([c + Offset(0, -s * 0.55), c + Offset(s * 0.4, 0), c + Offset(0, s * 0.55), c + Offset(-s * 0.4, 0)]);

/// A spade about [c], [s] across.
Path _spade(Offset c, double s) => Path()
  ..moveTo(c.dx, c.dy - s * 0.55)
  ..cubicTo(c.dx + s * 0.75, c.dy, c.dx + s * 0.45, c.dy + s * 0.55, c.dx + s * 0.05, c.dy + s * 0.2)
  ..lineTo(c.dx + s * 0.2, c.dy + s * 0.55)
  ..lineTo(c.dx - s * 0.2, c.dy + s * 0.55)
  ..lineTo(c.dx - s * 0.05, c.dy + s * 0.2)
  ..cubicTo(c.dx - s * 0.45, c.dy + s * 0.55, c.dx - s * 0.75, c.dy, c.dx, c.dy - s * 0.55)
  ..close();

/// A club about [c], [s] across.
Path _club(Offset c, double s) => Path.combine(
    PathOperation.union,
    Path.combine(PathOperation.union, _circle(c + Offset(0, -s * 0.26), s * 0.24),
        Path.combine(PathOperation.union, _circle(c + Offset(-s * 0.26, s * 0.08), s * 0.24), _circle(c + Offset(s * 0.26, s * 0.08), s * 0.24))),
    _poly([c + Offset(-s * 0.06, 0), c + Offset(s * 0.06, 0), c + Offset(s * 0.2, s * 0.55), c + Offset(-s * 0.2, s * 0.55)]));
