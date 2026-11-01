/// The rooms' own seat tokens (looks.dart: [TokenStyle]): a ringed
/// planet, tufted velvet, a cameo, a deco sunburst, a die, an enamel pin,
/// ice, a faience scarab, a hammered doubloon and a bottle's crown cap. In
/// the seat's colour, so the seats stay apart; drawn inside the token's
/// outline (token_styles.dart clips to it and rings it).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/looks.dart';
import '../../skin/skin.dart';

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// The outline [style] has whatever the house (a die is square, a
/// doubloon hammered, a cap crimped, a planet round); null to take the
/// house's shape.
Path? setTokenOutline(TokenStyle style, Size size) {
  final c = size.center(Offset.zero);
  final r = size.shortestSide / 2;
  switch (style) {
    case TokenStyle.dice:
      return Path()
        ..addRRect(RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: r * 0.9), Radius.circular(r * 0.32)));
    case TokenStyle.planets:
      return Path()..addOval(Rect.fromCircle(center: c, radius: r));
    case TokenStyle.doubloons:
      // Struck by hand: not quite round.
      const wobble = [1.0, 0.95, 0.99, 0.93, 0.98, 1.0, 0.94, 0.97, 0.99, 0.92, 0.97, 1.0, 0.95, 0.98];
      return _smooth([
        for (var k = 0; k < wobble.length; k++)
          c + Offset(math.cos(k * 2 * math.pi / wobble.length), math.sin(k * 2 * math.pi / wobble.length)) * r * wobble[k]
      ]);
    case TokenStyle.caps:
      // A crown cap's 21 crimps.
      const n = 42;
      return _smooth([
        for (var k = 0; k < n; k++)
          c + Offset(math.cos(k * 2 * math.pi / n), math.sin(k * 2 * math.pi / n)) * r * (k.isEven ? 1 : 0.88)
      ]);
    default:
      return null;
  }
}

/// A closed curve through the middles of [pts]' sides, bent at each
/// point.
Path _smooth(List<Offset> pts) {
  Offset mid(int k) => (pts[k % pts.length] + pts[(k + 1) % pts.length]) / 2;
  final p = Path()..moveTo(mid(0).dx, mid(0).dy);
  for (var k = 1; k <= pts.length; k++) {
    final a = pts[k % pts.length];
    p.quadraticBezierTo(a.dx, a.dy, mid(k).dx, mid(k).dy);
  }
  return p..close();
}

/// [path] at [k] of its size, about [c].
Path _scaled(Path path, Offset c, double k) => path.transform((Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1))
    .storage);

/// Draws a seat's token as [style], in [color], filling [outline] (the
/// canvas is clipped to it already).
void paintSetToken(Canvas canvas, TokenStyle style, Path outline, Size size, Color color, Skin skin) {
  final c = size.center(Offset.zero);
  final r = size.shortestSide / 2;
  final bounds = outline.getBounds();
  Paint stroke(Color colour, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..color = colour;
  final light = _mix(color, Colors.white, 0.45);
  final dark = _mix(color, Colors.black, 0.4);
  switch (style) {
    case TokenStyle.planets:
      // A lit sphere, its night side, and its rings across it.
      canvas.drawPath(
          outline,
          Paint()
            ..shader = RadialGradient(center: const Alignment(-0.4, -0.45), radius: 1.05, colors: [light, color, dark])
                .createShader(bounds));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.38);
      final ring = Rect.fromCenter(center: Offset.zero, width: r * 2.3, height: r * 0.62);
      canvas.drawOval(ring, stroke(_mix(color, Colors.white, 0.7).withValues(alpha: 0.85), r * 0.13));
      canvas.drawOval(ring.deflate(r * 0.13), stroke(dark.withValues(alpha: 0.5), r * 0.04));
      canvas.restore();
    case TokenStyle.tufted:
      // Buttoned velvet: diamonds of it, puffed, a button at each corner.
      canvas.drawPath(
          outline,
          Paint()
            ..shader = RadialGradient(center: const Alignment(-0.2, -0.3), colors: [_mix(color, Colors.white, 0.18), dark])
                .createShader(bounds));
      final step = r * 0.78;
      final seam = stroke(_mix(color, Colors.black, 0.55).withValues(alpha: 0.7), math.max(0.7, r * 0.05));
      for (var x = -size.height; x < size.width + size.height; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), seam);
        canvas.drawLine(Offset(x + size.height, 0), Offset(x, size.height), seam);
      }
      final button = Paint()..color = _mix(color, Colors.white, 0.35);
      for (var y = c.dy - step * 2; y <= c.dy + step * 2; y += step / 2) {
        final odd = ((y - c.dy) / (step / 2)).round().isOdd;
        for (var x = c.dx - step * 2 + (odd ? step / 2 : 0); x <= c.dx + step * 2; x += step) {
          canvas.drawCircle(Offset(x, y), math.max(0.8, r * 0.06), button);
        }
      }
    case TokenStyle.cameos:
      // Carved: the field, a pale shell oval raised in it, and a beaded
      // gilt rim.
      canvas.drawPath(outline, Paint()..color = color);
      canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 1.2, height: r * 1.45),
          Paint()
            ..shader = RadialGradient(colors: [_mix(color, Colors.white, 0.55), _mix(color, Colors.white, 0.25)])
                .createShader(bounds));
      canvas.drawOval(Rect.fromCenter(center: c, width: r * 1.2, height: r * 1.45),
          stroke(_mix(color, Colors.black, 0.25), math.max(0.6, r * 0.04)));
      final rim = _scaled(outline, c, 0.86);
      for (final m in rim.computeMetrics()) {
        final n = (m.length / (r * 0.22)).floor();
        for (var k = 0; k < n; k++) {
          canvas.drawCircle(m.getTangentForOffset(m.length * k / n)!.position, math.max(0.7, r * 0.06),
              Paint()..color = skin.gold);
        }
      }
    case TokenStyle.sunbursts:
      // Deco: rays fanning from the foot, alternately lit, under a gilt
      // rule.
      canvas.drawPath(outline, Paint()..color = color);
      final foot = Offset(c.dx, size.height * 1.05);
      const n = 9;
      for (var k = 0; k < n; k += 2) {
        final a0 = math.pi + k * math.pi / n, a1 = math.pi + (k + 1) * math.pi / n;
        canvas.drawPath(
            Path()
              ..moveTo(foot.dx, foot.dy)
              ..lineTo(foot.dx + math.cos(a0) * size.height * 2, foot.dy + math.sin(a0) * size.height * 2)
              ..lineTo(foot.dx + math.cos(a1) * size.height * 2, foot.dy + math.sin(a1) * size.height * 2)
              ..close(),
            Paint()..color = _mix(color, Colors.white, 0.22));
      }
      canvas.drawPath(_scaled(outline, c, 0.8), stroke(skin.gold, math.max(0.8, r * 0.07)));
    case TokenStyle.dice:
      // A die: a bevel lit from the top, and four pips in its corners
      // (the middle left for the seat's letter).
      canvas.drawPath(
          outline,
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, color, dark], stops: const [0, 0.45, 1])
                .createShader(bounds));
      canvas.drawPath(_scaled(outline, c, 0.86), Paint()..color = color);
      final pip = Paint()..color = Colors.white.withValues(alpha: 0.95);
      for (final d in const [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)]) {
        canvas.drawCircle(c + d * r * 0.52, r * 0.11, pip);
      }
    case TokenStyle.enamel:
      // A pin: a white metal rim, the enamel inside it, glossy.
      canvas.drawPath(outline, Paint()..color = const Color(0xFFF4F1EA));
      final inner = _scaled(outline, c, 0.76);
      canvas.drawPath(inner, Paint()..color = color);
      canvas.drawPath(inner, stroke(const Color(0xFFB9B4A8), math.max(0.6, r * 0.05)));
      canvas.save();
      canvas.clipPath(inner);
      canvas.drawOval(Rect.fromCenter(center: c + Offset(-r * 0.3, -r * 0.42), width: r * 0.9, height: r * 0.34),
          Paint()..color = Colors.white.withValues(alpha: 0.32));
      canvas.restore();
    case TokenStyle.ice:
      // Ice: paler at the top, cut facets, and frost along its edge.
      canvas.drawPath(
          outline,
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_mix(color, Colors.white, 0.6), _mix(color, Colors.white, 0.15)])
                .createShader(bounds));
      final cut = stroke(Colors.white.withValues(alpha: 0.6), math.max(0.6, r * 0.04));
      for (final (a, b) in [
        (const Offset(-0.9, -0.2), const Offset(-0.1, -0.9)),
        (const Offset(-0.1, -0.9), const Offset(0.8, -0.3)),
        (const Offset(-0.9, -0.2), const Offset(0.1, 0.9)),
        (const Offset(0.8, -0.3), const Offset(0.1, 0.9)),
      ]) {
        canvas.drawLine(c + a * r, c + b * r, cut);
      }
      canvas.drawPath(_scaled(outline, c, 0.92), stroke(Colors.white.withValues(alpha: 0.7), math.max(0.8, r * 0.08)));
    case TokenStyle.scarabs:
      // Faience: glazed, its wing cases parted, banded in gold at the
      // shoulders, its head at the top.
      canvas.drawPath(
          outline,
          Paint()
            ..shader = RadialGradient(center: const Alignment(-0.3, -0.3), colors: [light, color, dark], stops: const [0, 0.55, 1])
                .createShader(bounds));
      final shoulder = bounds.top + bounds.height * 0.34;
      canvas.drawLine(Offset(c.dx, shoulder), Offset(c.dx, bounds.bottom), stroke(dark, math.max(0.8, r * 0.07)));
      canvas.drawLine(Offset(bounds.left, shoulder), Offset(bounds.right, shoulder), stroke(skin.gold, math.max(1.0, r * 0.12)));
      canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, bounds.top + r * 0.05), width: r * 0.8, height: r * 0.7), 0, math.pi,
          true, Paint()..color = dark);
    case TokenStyle.doubloons:
      // Hammered: the metal lit across, a cross struck in it, and the
      // ring of the die.
      canvas.drawPath(
          outline,
          Paint()
            ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, color, dark])
                .createShader(bounds));
      canvas.drawCircle(c, r * 0.74, stroke(dark.withValues(alpha: 0.6), math.max(0.7, r * 0.05)));
      final arm = r * 0.5, bar = r * 0.16;
      final cross = Paint()..color = light.withValues(alpha: 0.6);
      canvas.drawRect(Rect.fromCenter(center: c, width: bar, height: arm * 2), cross);
      canvas.drawRect(Rect.fromCenter(center: c, width: arm * 2, height: bar), cross);
      for (final d in const [Offset(0, -1), Offset(0, 1), Offset(-1, 0), Offset(1, 0)]) {
        canvas.drawRect(Rect.fromCenter(center: c + d * arm, width: d.dx == 0 ? arm * 0.6 : bar, height: d.dx == 0 ? bar : arm * 0.6),
            cross);
      }
    case TokenStyle.caps:
      // A crown cap: the crimped skirt in shadow, the flat top, a ring
      // pressed round it.
      canvas.drawPath(outline, Paint()..color = dark);
      for (var k = 0; k < 21; k++) {
        final a = (k + 0.5) * 2 * math.pi / 21;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + d * r * 0.72, c + d * r, stroke(_mix(color, Colors.white, 0.15), math.max(0.6, r * 0.05)));
      }
      canvas.drawCircle(
          c,
          r * 0.72,
          Paint()
            ..shader = RadialGradient(center: const Alignment(-0.3, -0.35), colors: [light, color]).createShader(bounds));
      canvas.drawCircle(c, r * 0.6, stroke(_mix(color, Colors.white, 0.55).withValues(alpha: 0.7), math.max(0.6, r * 0.04)));
    default:
      canvas.drawPath(outline, Paint()..color = color);
  }
}
