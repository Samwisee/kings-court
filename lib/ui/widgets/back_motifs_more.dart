// Not under the Apache licence: the rooms' art, all rights reserved (LICENSE-ROOMS.md).
/// The rooms' own motifs for a card's back, a number card's face or a task
/// card (looks.dart: [BackMotif]): stars, damask, marble's veins, deco
/// fans, a casino's diamonds, herringbone, snow, zigzags, a sea chart, a
/// plaid and papyrus. Each in one colour, scaled to what it covers.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/looks.dart';

/// [motif] in [colour]: one of the rooms' own.
class SetMotif extends CustomPainter {
  const SetMotif(this.motif, this.colour);
  final BackMotif motif;
  final Color colour;

  /// The same scatter every time: [n] points over [size], from [seed].
  static List<Offset> _scatter(Size size, int n, int seed) {
    final r = math.Random(seed);
    return [for (var k = 0; k < n; k++) Offset(r.nextDouble() * size.width, r.nextDouble() * size.height)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()..color = colour;
    final line = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.8, w / 70);
    switch (motif) {
      case BackMotif.stars:
        final n = (w * h / math.pow(math.max(6.0, w / 6), 2)).round().clamp(6, 90);
        for (final (k, p) in _scatter(size, n, 7).indexed) {
          final s = math.max(1.0, w / (k % 5 == 0 ? 22 : 60));
          if (k % 5 == 0) {
            // A bright one: four points.
            final star = Path()
              ..moveTo(p.dx, p.dy - s * 2)
              ..quadraticBezierTo(p.dx, p.dy, p.dx + s * 2, p.dy)
              ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s * 2)
              ..quadraticBezierTo(p.dx, p.dy, p.dx - s * 2, p.dy)
              ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s * 2)
              ..close();
            canvas.drawPath(star, fill);
          } else {
            canvas.drawCircle(p, s * 0.8, fill);
          }
        }
      case BackMotif.damask:
        final step = math.max(8.0, w / 3.5);
        var row = 0;
        for (var y = step / 2; y < h + step; y += step * 0.9, row++) {
          for (var x = row.isOdd ? 0.0 : step / 2; x < w + step; x += step) {
            _flower(canvas, Offset(x, y), step * 0.32, fill, line, row.isOdd);
          }
        }
      case BackMotif.veins:
        final r = math.Random(3);
        for (var k = 0; k < 4; k++) {
          final y0 = h * (0.1 + 0.27 * k) + r.nextDouble() * h * 0.08;
          final p = Path()..moveTo(-2, y0);
          var x = 0.0, y = y0;
          while (x < w) {
            final nx = x + w * (0.18 + r.nextDouble() * 0.15);
            final ny = y + h * (r.nextDouble() * 0.16 - 0.04);
            p.quadraticBezierTo((x + nx) / 2, y + h * (r.nextDouble() * 0.1 - 0.05), nx, ny);
            if (r.nextDouble() < 0.45) {
              // A branch off it.
              canvas.drawLine(Offset(nx, ny), Offset(nx + w * 0.12, ny - h * 0.07),
                  line..strokeWidth = math.max(0.6, w / 140));
            }
            x = nx;
            y = ny;
          }
          canvas.drawPath(p, line..strokeWidth = math.max(0.7, w / (k.isEven ? 60 : 110)));
        }
      case BackMotif.fans:
        final step = math.max(8.0, w / 4);
        var row = 0;
        for (var y = 0.0; y < h + step; y += step / 2, row++) {
          for (var x = row.isOdd ? step / 2 : 0.0; x < w + step; x += step) {
            for (final k in [0.5, 0.33, 0.16]) {
              canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: step * k), math.pi, math.pi, false,
                  line..strokeWidth = math.max(0.6, w / 100));
            }
          }
        }
      case BackMotif.diamonds:
        final step = math.max(4.0, w / 10);
        final thin = Paint()
          ..color = colour
          ..strokeWidth = math.max(0.5, w / 160);
        for (var x = -h; x < w + h; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x + h, h), thin);
          canvas.drawLine(Offset(x + h, 0), Offset(x, h), thin);
        }
        // A small diamond in every other cell.
        for (var y = 0.0; y < h + step; y += step) {
          for (var x = 0.0; x < w + step; x += step) {
            final c = Offset(x, y + step / 2);
            final d = step * 0.22;
            canvas.drawPath(
                Path()
                  ..moveTo(c.dx, c.dy - d)
                  ..lineTo(c.dx + d, c.dy)
                  ..lineTo(c.dx, c.dy + d)
                  ..lineTo(c.dx - d, c.dy)
                  ..close(),
                fill);
          }
        }
      case BackMotif.herringbone:
        final step = math.max(4.0, w / 8);
        final thin = Paint()
          ..color = colour
          ..strokeWidth = math.max(0.6, w / 90);
        var col = 0;
        for (var x = 0.0; x < w + step; x += step, col++) {
          for (var y = -step; y < h + step; y += step / 2.2) {
            final dir = col.isEven ? 1 : -1;
            canvas.drawLine(Offset(x, y), Offset(x + step, y + dir * step * 0.6), thin);
          }
        }
      case BackMotif.snow:
        final n = (w * h / math.pow(math.max(9.0, w / 4), 2)).round().clamp(4, 50);
        for (final (k, p) in _scatter(size, n, 11).indexed) {
          final s = math.max(2.0, w / (k.isEven ? 12 : 20));
          _flake(canvas, p, s, line..strokeWidth = math.max(0.6, s / 6));
        }
      case BackMotif.zigzag:
        final step = math.max(8.0, w / 3.2);
        final tooth = step / 4;
        for (var y = step / 2; y < h + step; y += step) {
          for (final dy in [-tooth * 0.7, tooth * 0.7]) {
            final p = Path()..moveTo(0, y + dy);
            var up = true;
            for (var x = 0.0; x <= w + tooth; x += tooth) {
              p.lineTo(x, y + dy + (up ? -tooth / 2 : tooth / 2));
              up = !up;
            }
            canvas.drawPath(p, line..strokeWidth = math.max(0.7, w / 80));
          }
          canvas.drawCircle(Offset(w / 2, y + step / 2), math.max(1.0, w / 50), fill);
        }
      case BackMotif.chart:
        final c = Offset(w / 2, h / 2);
        final reach = math.sqrt(w * w + h * h);
        final thin = Paint()
          ..color = colour
          ..strokeWidth = math.max(0.5, w / 160);
        for (var k = 0; k < 16; k++) {
          final a = k * math.pi / 8;
          canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * reach, thin);
        }
        // Other roses out at the edges, as charts have.
        for (final o in [Offset(w * 0.1, h * 0.12), Offset(w * 0.9, h * 0.88)]) {
          for (var k = 0; k < 8; k++) {
            final a = k * math.pi / 4;
            canvas.drawLine(o, o + Offset(math.cos(a), math.sin(a)) * reach * 0.4, thin);
          }
        }
        canvas.drawCircle(c, w * 0.36, line..strokeWidth = math.max(0.7, w / 90));
        canvas.drawCircle(c, w * 0.3, thin..style = PaintingStyle.stroke);
      case BackMotif.plaid:
        final step = math.max(8.0, w / 3);
        for (var x = 0.0; x < w + step; x += step) {
          canvas.drawRect(Rect.fromLTWH(x, 0, step * 0.34, h), fill);
          canvas.drawRect(Rect.fromLTWH(x + step * 0.62, 0, step * 0.08, h), fill);
        }
        for (var y = 0.0; y < h + step; y += step) {
          canvas.drawRect(Rect.fromLTWH(0, y, w, step * 0.34), fill);
          canvas.drawRect(Rect.fromLTWH(0, y + step * 0.62, w, step * 0.08), fill);
        }
      case BackMotif.papyrus:
        final step = math.max(2.5, w / 26);
        final thin = Paint()
          ..color = colour
          ..strokeWidth = math.max(0.5, w / 200);
        final r = math.Random(5);
        for (var y = 0.0; y < h; y += step * (0.6 + r.nextDouble())) {
          canvas.drawLine(Offset(0, y), Offset(w, y + r.nextDouble() * 2 - 1), thin);
        }
        for (var x = 0.0; x < w; x += step * (1.4 + r.nextDouble() * 2)) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), thin);
        }
      case BackMotif.none:
      case BackMotif.lattice:
      case BackMotif.stripes:
      case BackMotif.dots:
      case BackMotif.rays:
      case BackMotif.waves:
        break;
    }
  }

  /// A small woven flower: four petals round a heart, turned a quarter on
  /// [turned] rows.
  static void _flower(Canvas canvas, Offset c, double r, Paint fill, Paint line, bool turned) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (turned) canvas.rotate(math.pi / 4);
    for (var k = 0; k < 4; k++) {
      canvas.drawOval(Rect.fromCenter(center: Offset(0, -r * 0.62), width: r * 0.55, height: r * 0.95), fill);
      canvas.rotate(math.pi / 2);
    }
    canvas.drawCircle(Offset.zero, r * 0.18, Paint()..color = fill.color.withValues(alpha: fill.color.a * 0.5));
    canvas.restore();
  }

  /// A snowflake of six arms, each with a pair of barbs.
  static void _flake(Canvas canvas, Offset c, double s, Paint line) {
    for (var k = 0; k < 6; k++) {
      final a = k * math.pi / 3;
      final d = Offset(math.cos(a), math.sin(a));
      final tip = c + d * s;
      canvas.drawLine(c, tip, line);
      final mid = c + d * s * 0.55;
      for (final t in [-0.6, 0.6]) {
        final b = Offset(math.cos(a + t), math.sin(a + t));
        canvas.drawLine(mid, mid + b * s * 0.32, line);
      }
    }
  }

  @override
  bool shouldRepaint(SetMotif old) => old.motif != motif || old.colour != colour;
}
