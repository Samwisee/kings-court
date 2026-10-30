/// Seat tokens made as something else than the courtiers' houses
/// (looks.dart: [TokenStyle]): coins, cut gems, wax seals, casino chips
/// and heraldic shields, each in the seat's colour, with the ring (gold
/// for the King and whoever's turn it is) round it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/courtiers.dart';
import '../../skin/looks.dart';
import '../../skin/skin.dart';
import 'token_shapes.dart';

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// A seat's token as [style] makes it, in [color], ringed in [ring].
class StyledToken extends StatelessWidget {
  const StyledToken({
    super.key,
    required this.style,
    required this.size,
    required this.color,
    required this.ring,
    required this.ringWidth,
    required this.skin,
    this.glow = false,
    this.child,
  });

  final TokenStyle style;
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
          painter: _StyledPainter(style, color, ring, ringWidth, glow, skin),
          child: Center(child: child),
        ),
      );
}

class _StyledPainter extends CustomPainter {
  _StyledPainter(this.style, this.color, this.ring, this.ringWidth, this.glow, this.skin);
  final TokenStyle style;
  final Color color;
  final Color ring;
  final double ringWidth;
  final bool glow;
  final Skin skin;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final outline = Path();
    switch (style) {
      case TokenStyle.gems:
        // An octagon, cut.
        for (var k = 0; k < 8; k++) {
          final a = -math.pi / 2 + math.pi / 8 + k * math.pi / 4;
          final p = c + Offset(math.cos(a), math.sin(a)) * r;
          k == 0 ? outline.moveTo(p.dx, p.dy) : outline.lineTo(p.dx, p.dy);
        }
        outline.close();
      case TokenStyle.shields:
        outline.addPath(tokenPath(TokenShape.shield, size), Offset.zero);
      case TokenStyle.seals:
        // A pressed edge, never quite round.
        for (var k = 0; k <= 48; k++) {
          final a = k * 2 * math.pi / 48;
          final rr = r * (0.94 + 0.05 * math.sin(a * 7) + 0.02 * math.sin(a * 13 + 1));
          final p = c + Offset(math.cos(a), math.sin(a)) * rr;
          k == 0 ? outline.moveTo(p.dx, p.dy) : outline.lineTo(p.dx, p.dy);
        }
        outline.close();
      case TokenStyle.houses:
      case TokenStyle.coins:
      case TokenStyle.chips:
        outline.addOval(Rect.fromCircle(center: c, radius: r));
    }

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
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.clipPath(outline);
    switch (style) {
      case TokenStyle.coins:
        // The rim, milled, a little paler; the face inside it, struck.
        canvas.drawCircle(
            c,
            r,
            Paint()
              ..shader = LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_mix(color, Colors.white, 0.5), _mix(color, Colors.black, 0.3)])
                  .createShader(rect));
        final mill = Paint()
          ..color = _mix(color, Colors.black, 0.45)
          ..strokeWidth = math.max(0.7, r * 0.03);
        for (var k = 0; k < 40; k++) {
          final a = k * 2 * math.pi / 40;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + d * r * 0.86, c + d * r, mill);
        }
        canvas.drawCircle(
            c,
            r * 0.78,
            Paint()
              ..shader = RadialGradient(
                      center: const Alignment(-0.3, -0.4),
                      colors: [_mix(color, Colors.white, 0.2), _mix(color, Colors.black, 0.15)])
                  .createShader(rect));
        canvas.drawCircle(
            c,
            r * 0.7,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.6, r * 0.03)
              ..color = _mix(color, Colors.white, 0.45).withValues(alpha: 0.7));
      case TokenStyle.gems:
        // Facets: a table in the middle, and the crown's eight sides round
        // it, lit from the top left.
        canvas.drawPath(outline, Paint()..color = color);
        final table = <Offset>[];
        final girdle = <Offset>[];
        for (var k = 0; k < 8; k++) {
          final a = -math.pi / 2 + math.pi / 8 + k * math.pi / 4;
          final d = Offset(math.cos(a), math.sin(a));
          table.add(c + d * r * 0.52);
          girdle.add(c + d * r);
        }
        for (var k = 0; k < 8; k++) {
          final n = (k + 1) % 8;
          final face = Path()
            ..moveTo(girdle[k].dx, girdle[k].dy)
            ..lineTo(girdle[n].dx, girdle[n].dy)
            ..lineTo(table[n].dx, table[n].dy)
            ..lineTo(table[k].dx, table[k].dy)
            ..close();
          final mid = (girdle[k] + girdle[n]) / 2 - c;
          final light = (-mid.dx - mid.dy) / (r * 1.5);
          canvas.drawPath(
              face,
              Paint()
                ..color = light > 0
                    ? _mix(color, Colors.white, (light * 0.45).clamp(0.0, 0.45))
                    : _mix(color, Colors.black, (-light * 0.35).clamp(0.0, 0.35)));
        }
        final top = Path()..addPolygon(table, true);
        canvas.drawPath(top, Paint()..color = _mix(color, Colors.white, 0.12));
        final edges = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: 0.35);
        canvas.drawPath(top, edges);
        for (var k = 0; k < 8; k++) {
          canvas.drawLine(table[k], girdle[k], edges);
        }
      case TokenStyle.seals:
        // Wax, darker at its edge, with the ring a seal leaves and a
        // gleam where the light catches it.
        canvas.drawPath(
            outline,
            Paint()
              ..shader = RadialGradient(
                      center: const Alignment(-0.2, -0.3),
                      colors: [_mix(color, Colors.white, 0.1), _mix(color, Colors.black, 0.35)])
                  .createShader(rect));
        canvas.drawCircle(
            c,
            r * 0.7,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.0, r * 0.07)
              ..color = _mix(color, Colors.black, 0.3));
        canvas.drawCircle(
            c,
            r * 0.7,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.6, r * 0.03)
              ..color = _mix(color, Colors.white, 0.3).withValues(alpha: 0.6));
        canvas.drawOval(
            Rect.fromCenter(center: c + Offset(-r * 0.42, -r * 0.5), width: r * 0.42, height: r * 0.2),
            Paint()..color = Colors.white.withValues(alpha: 0.28));
      case TokenStyle.chips:
        // The chip, stripes round its edge, and an inner ring of dashes.
        canvas.drawCircle(c, r, Paint()..color = color);
        final stripe = Paint()..color = Colors.white.withValues(alpha: 0.92);
        for (var k = 0; k < 6; k++) {
          final a = k * math.pi / 3;
          canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.9), a - 0.16, 0.32, false,
              stripe
                ..style = PaintingStyle.stroke
                ..strokeWidth = r * 0.2);
        }
        canvas.drawCircle(c, r * 0.66, Paint()..color = _mix(color, Colors.white, 0.12));
        final dash = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, r * 0.04)
          ..color = Colors.white.withValues(alpha: 0.7);
        for (var k = 0; k < 16; k++) {
          final a = k * math.pi / 8;
          canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.66), a, math.pi / 16, false, dash);
        }
      case TokenStyle.shields:
        // The field in the seat's colour, a bend across it a shade paler,
        // and a fine line inside the edge.
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
      old.color != color ||
      old.ring != ring ||
      old.ringWidth != ringWidth ||
      old.glow != glow ||
      old.skin != skin;
}
