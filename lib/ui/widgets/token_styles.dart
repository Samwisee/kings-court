/// Seat tokens made of something (looks.dart: [TokenStyle]), always in
/// the courtier's house shape: struck as a coin with a milled edge, cut as
/// a gem, pressed in wax, striped as a casino chip, or blazoned with a
/// bend. In the seat's colour, with the ring (gold for the King and
/// whoever's turn it is) round it.
library;

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../game/courtiers.dart';
import '../../skin/looks.dart';
import '../../skin/skin.dart';
import 'token_shapes.dart';

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// A seat's token in [shape] (a disc when null), made as [style], in
/// [color], ringed in [ring].
class StyledToken extends StatelessWidget {
  const StyledToken({
    super.key,
    required this.style,
    required this.size,
    required this.color,
    required this.ring,
    required this.ringWidth,
    required this.skin,
    this.shape,
    this.glow = false,
    this.child,
  });

  final TokenStyle style;
  final TokenShape? shape;
  final double size;
  final Color color;
  final Color ring;
  final double ringWidth;
  final Skin skin;
  final bool glow;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _StyledPainter(style, shape, color, ring, ringWidth, glow, skin),
          child: Center(child: child),
        ),
      );
}

class _StyledPainter extends CustomPainter {
  _StyledPainter(this.style, this.shape, this.color, this.ring, this.ringWidth, this.glow, this.skin);
  final TokenStyle style;
  final TokenShape? shape;
  final Color color;
  final Color ring;
  final double ringWidth;
  final bool glow;
  final Skin skin;

  /// [path] drawn [k] of its size, about [c].
  static Path _scaled(Path path, Offset c, double k) => path.transform(
      (Matrix4.identity()
            ..translateByDouble(c.dx, c.dy, 0, 1)
            ..scaleByDouble(k, k, 1, 1)
            ..translateByDouble(-c.dx, -c.dy, 0, 1))
          .storage);

  /// Points round [path]'s edge, [n] of them, evenly.
  static List<Offset> _round(Path path, int n) {
    final pts = <Offset>[];
    for (final PathMetric m in path.computeMetrics()) {
      for (var k = 0; k < n; k++) {
        pts.add(m.getTangentForOffset(m.length * k / n)!.position);
      }
      break;
    }
    return pts;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final outline = shape == null ? (Path()..addOval(Rect.fromCircle(center: c, radius: r))) : tokenPath(shape!, size);
    final bounds = outline.getBounds();

    canvas.drawPath(
        outline.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black38
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    if (glow) {
      canvas.drawPath(
          outline,
          Paint()
            ..color = skin.gold
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    canvas.save();
    canvas.clipPath(outline);
    switch (style) {
      case TokenStyle.coins:
        // Struck: the rim a little paler and milled; the face inside it.
        canvas.drawPath(
            outline,
            Paint()
              ..shader = LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_mix(color, Colors.white, 0.5), _mix(color, Colors.black, 0.3)])
                  .createShader(bounds));
        final mill = Paint()
          ..color = _mix(color, Colors.black, 0.45)
          ..strokeWidth = math.max(0.7, r * 0.03);
        for (final p in _round(outline, 44)) {
          canvas.drawLine(p, Offset.lerp(p, c, 0.13)!, mill);
        }
        final face = _scaled(outline, c, 0.8);
        canvas.drawPath(
            face,
            Paint()
              ..shader = RadialGradient(
                      center: const Alignment(-0.3, -0.4),
                      colors: [_mix(color, Colors.white, 0.2), _mix(color, Colors.black, 0.15)])
                  .createShader(bounds));
        canvas.drawPath(
            _scaled(outline, c, 0.72),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.6, r * 0.03)
              ..color = _mix(color, Colors.white, 0.45).withValues(alpha: 0.7));
      case TokenStyle.gems:
        // Cut: a table in the middle, facets round it, lit from the top
        // left.
        canvas.drawPath(outline, Paint()..color = color);
        final edge = _round(outline, 16);
        final table = [for (final p in edge) Offset.lerp(c, p, 0.52)!];
        for (var k = 0; k < edge.length; k++) {
          final n = (k + 1) % edge.length;
          final facet = Path()
            ..moveTo(edge[k].dx, edge[k].dy)
            ..lineTo(edge[n].dx, edge[n].dy)
            ..lineTo(table[n].dx, table[n].dy)
            ..lineTo(table[k].dx, table[k].dy)
            ..close();
          final mid = (edge[k] + edge[n]) / 2 - c;
          final light = (-mid.dx - mid.dy) / (r * 1.5);
          canvas.drawPath(
              facet,
              Paint()
                ..color = light > 0
                    ? _mix(color, Colors.white, (light * 0.45).clamp(0.0, 0.45))
                    : _mix(color, Colors.black, (-light * 0.35).clamp(0.0, 0.35)));
        }
        final top = Path()..addPolygon(table, true);
        canvas.drawPath(top, Paint()..color = _mix(color, Colors.white, 0.12));
        final lines = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: 0.35);
        canvas.drawPath(top, lines);
        for (var k = 0; k < edge.length; k += 2) {
          canvas.drawLine(table[k], edge[k], lines);
        }
      case TokenStyle.seals:
        // Pressed wax: darker at its edge, the seal's ring pressed into
        // it, and a gleam where the light catches it.
        canvas.drawPath(
            outline,
            Paint()
              ..shader = RadialGradient(
                      center: const Alignment(-0.2, -0.3),
                      colors: [_mix(color, Colors.white, 0.1), _mix(color, Colors.black, 0.4)])
                  .createShader(bounds));
        final pressed = _scaled(outline, c, 0.72);
        canvas.drawPath(
            pressed,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.0, r * 0.08)
              ..color = _mix(color, Colors.black, 0.3));
        canvas.drawPath(
            pressed.shift(const Offset(-0.6, -0.6)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.6, r * 0.03)
              ..color = _mix(color, Colors.white, 0.3).withValues(alpha: 0.6));
        canvas.drawOval(
            Rect.fromCenter(center: c + Offset(-r * 0.4, -r * 0.48), width: r * 0.42, height: r * 0.2),
            Paint()..color = Colors.white.withValues(alpha: 0.28));
      case TokenStyle.chips:
        // A chip: stripes round its edge, and a dashed ring inside.
        canvas.drawPath(outline, Paint()..color = color);
        final band = _scaled(outline, c, 0.9);
        for (final PathMetric m in band.computeMetrics()) {
          for (var k = 0; k < 6; k++) {
            final at = m.length * (k + 0.5) / 6;
            canvas.drawPath(
                m.extractPath(at - m.length * 0.03, at + m.length * 0.03),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = r * 0.2
                  ..color = Colors.white.withValues(alpha: 0.92));
          }
        }
        final inner = _scaled(outline, c, 0.66);
        canvas.drawPath(inner, Paint()..color = _mix(color, Colors.white, 0.12));
        final dash = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, r * 0.04)
          ..color = Colors.white.withValues(alpha: 0.7);
        for (final PathMetric m in inner.computeMetrics()) {
          for (var k = 0; k < 16; k++) {
            canvas.drawPath(m.extractPath(m.length * k / 16, m.length * (k + 0.5) / 16), dash);
          }
        }
      case TokenStyle.shields:
        // Blazoned: the field in the seat's colour, a bend across it a
        // shade paler, and a border inside the edge.
        canvas.drawPath(outline, Paint()..color = color);
        final bend = Path()
          ..moveTo(0, size.height * 0.15)
          ..lineTo(size.width * 0.15, 0)
          ..lineTo(size.width, size.height * 0.85)
          ..lineTo(size.width * 0.85, size.height)
          ..close();
        canvas.drawPath(bend, Paint()..color = _mix(color, Colors.white, 0.3));
        canvas.drawPath(
            outline,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.0, r * 0.12)
              ..color = _mix(color, Colors.black, 0.3));
      case TokenStyle.houses:
        canvas.drawPath(outline, Paint()..color = color);
    }
    // The dark line just inside the ring.
    canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth + 2.6
          ..strokeJoin = StrokeJoin.round
          ..color = skin.outlineColour);
    canvas.restore();
    canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..strokeJoin = StrokeJoin.round
          ..color = ring);
  }

  @override
  bool shouldRepaint(_StyledPainter old) =>
      old.style != style ||
      old.shape != shape ||
      old.color != color ||
      old.ring != ring ||
      old.ringWidth != ringWidth ||
      old.glow != glow ||
      old.skin != skin;
}
