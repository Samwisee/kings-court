/// What's worked into a table's felt (looks.dart: [FeltPattern]): drawn
/// once, under the lamp light and everything on the table, faintly, in
/// the table's own ink.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/looks.dart';

/// Draws [pattern] in [ink] over a felt of [ground], at [scale] (smaller
/// for a little table in the Livery page).
class FeltPatternPainter extends CustomPainter {
  const FeltPatternPainter(this.pattern, this.ink, {required this.ground, this.scale = 1, this.soft = false});
  final FeltPattern pattern;
  final Color ink;
  final Color ground;
  final double scale;

  /// Softened, as if seen through a little haze (off the table, behind
  /// words): the lines wider and fainter, so their edges blur together.
  /// (Wider rather than truly blurred: a blur on every line would cost
  /// every frame.)
  final bool soft;

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern == FeltPattern.none || ink.a == 0) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    final s = Size(size.width / scale, size.height / scale);
    switch (pattern) {
      case FeltPattern.none:
        break;
      case FeltPattern.trellis:
        _trellis(canvas, s);
      case FeltPattern.chart:
        _chart(canvas, s);
      case FeltPattern.stars:
        _stars(canvas, s);
      case FeltPattern.damask:
        _damask(canvas, s);
      case FeltPattern.pinstripe:
        _pinstripe(canvas, s);
      case FeltPattern.tooled:
        _tooled(canvas, s);
      case FeltPattern.chequer:
        _chequer(canvas, s);
      case FeltPattern.planks:
        _planks(canvas, s);
      case FeltPattern.marble:
        _marble(canvas, s);
      case FeltPattern.deco:
        _deco(canvas, s);
      case FeltPattern.tiles:
        _tiles(canvas, s);
      case FeltPattern.contours:
        _contours(canvas, s);
      case FeltPattern.herringbone:
        _herringbone(canvas, s);
      case FeltPattern.awning:
        _awning(canvas, s);
      case FeltPattern.frost:
        _frost(canvas, s);
      case FeltPattern.lotus:
        _lotus(canvas, s);
      case FeltPattern.map:
        _map(canvas, s);
      case FeltPattern.gingham:
        _gingham(canvas, s);
      case FeltPattern.baize:
        _baize(canvas, s);
    }
    canvas.restore();
  }

  Paint _line([double width = 1, double alpha = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = soft ? width * 2.2 : width
    ..strokeCap = soft ? StrokeCap.round : StrokeCap.butt
    ..isAntiAlias = true
    ..color = ink.withValues(alpha: ink.a * alpha * (soft ? 0.55 : 1));

  Paint _fill([double alpha = 1]) => Paint()..color = ink.withValues(alpha: ink.a * alpha);

  /// A diamond lattice with a pair of leaves at each crossing.
  void _trellis(Canvas canvas, Size s) {
    const step = 56.0;
    final line = _line(1.2);
    final reach = s.width + s.height;
    final lattice = Path();
    for (var x = -s.height; x < s.width + step; x += step) {
      lattice
        ..moveTo(x, 0)
        ..lineTo(x + reach, reach)
        ..moveTo(x, 0)
        ..lineTo(x - reach, reach);
    }
    canvas.drawPath(lattice, line);
    final leaf = _fill(0.9);
    for (var y = 0.0; y < s.height + step; y += step / 2) {
      final odd = (y / (step / 2)).round().isOdd;
      for (var x = odd ? step / 2 : 0.0; x < s.width + step; x += step) {
        for (final a in const [-0.6, 0.6]) {
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(a);
          canvas.drawOval(const Rect.fromLTWH(-2.6, -9, 5.2, 9), leaf);
          canvas.restore();
        }
      }
    }
  }

  /// A compass rose in the middle and rhumb lines out from it.
  void _chart(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height * 0.45);
    final r = math.min(s.width, s.height) * 0.2;
    final reach = math.sqrt(s.width * s.width + s.height * s.height);
    final rhumb = _line(0.8, 0.7);
    final lines = Path();
    for (var k = 0; k < 32; k++) {
      final a = k * math.pi / 16;
      lines
        ..moveTo(c.dx + math.cos(a) * r * 1.2, c.dy + math.sin(a) * r * 1.2)
        ..lineTo(c.dx + math.cos(a) * reach, c.dy + math.sin(a) * reach);
    }
    canvas.drawPath(lines, rhumb);
    // A second, smaller rose's lines, off to one side, as on a real chart.
    final c2 = Offset(s.width * 0.12, s.height * 0.86);
    final lines2 = Path();
    for (var k = 0; k < 16; k++) {
      final a = k * math.pi / 8;
      lines2
        ..moveTo(c2.dx, c2.dy)
        ..lineTo(c2.dx + math.cos(a) * reach, c2.dy + math.sin(a) * reach);
    }
    canvas.drawPath(lines2, _line(0.6, 0.45));
    // The rings, ticked.
    final ring = _line(1.2);
    canvas.drawCircle(c, r * 1.08, ring);
    canvas.drawCircle(c, r * 1.2, ring);
    final ticks = Path();
    for (var k = 0; k < 64; k++) {
      final a = k * math.pi / 32;
      final inner = k.isEven ? r * 1.08 : r * 1.13;
      ticks
        ..moveTo(c.dx + math.cos(a) * inner, c.dy + math.sin(a) * inner)
        ..lineTo(c.dx + math.cos(a) * r * 1.2, c.dy + math.sin(a) * r * 1.2);
    }
    canvas.drawPath(ticks, _line(0.8));
    // The points: four long, four between, eight short; each half filled.
    void point(double a, double length, double width) {
      final tip = c + Offset(math.cos(a), math.sin(a)) * length;
      final left = c + Offset(math.cos(a - math.pi / 2), math.sin(a - math.pi / 2)) * width;
      final right = c + Offset(math.cos(a + math.pi / 2), math.sin(a + math.pi / 2)) * width;
      canvas.drawPath(Path()..moveTo(c.dx, c.dy)..lineTo(tip.dx, tip.dy)..lineTo(left.dx, left.dy)..close(), _fill(0.9));
      canvas.drawPath(
          Path()
            ..moveTo(left.dx, left.dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(right.dx, right.dy)
            ..lineTo(c.dx, c.dy)
            ..close(),
          _line());
    }

    for (var k = 0; k < 8; k++) {
      point(k * math.pi / 4 + math.pi / 8, r * 0.5, r * 0.06);
    }
    for (var k = 0; k < 4; k++) {
      point(k * math.pi / 2 + math.pi / 4, r * 0.72, r * 0.09);
    }
    for (var k = 0; k < 4; k++) {
      point(k * math.pi / 2 - math.pi / 2, r, r * 0.13);
    }
    canvas.drawCircle(c, r * 0.06, _fill());
  }

  /// Scattered stars, a few bright with rays, and one constellation.
  void _stars(Canvas canvas, Size s) {
    final rand = math.Random(7);
    final count = (s.width * s.height / 1800).round().clamp(40, 900);
    for (var k = 0; k < count; k++) {
      final p = Offset(rand.nextDouble() * s.width, rand.nextDouble() * s.height);
      final big = rand.nextDouble();
      canvas.drawCircle(p, 0.5 + big * big * 1.3, _fill(0.25 + 0.75 * rand.nextDouble()));
    }
    // Bright ones, with four rays.
    for (var k = 0; k < count ~/ 40 + 2; k++) {
      final p = Offset(rand.nextDouble() * s.width, rand.nextDouble() * s.height);
      _sparkle(canvas, p, 5 + rand.nextDouble() * 4);
    }
    // A crown of stars, up and to the right: the King's constellation.
    final o = Offset(s.width * 0.72, s.height * 0.16);
    final u = math.min(s.width, s.height) * 0.05;
    final crown = [
      o + Offset(-2 * u, 0),
      o + Offset(-1.2 * u, -1.4 * u),
      o + Offset(-0.4 * u, -0.2 * u),
      o + Offset(0.4 * u, -1.9 * u),
      o + Offset(1.2 * u, -0.2 * u),
      o + Offset(2 * u, -1.4 * u),
      o + Offset(2.6 * u, 0.1 * u),
    ];
    final path = Path()..moveTo(crown.first.dx, crown.first.dy);
    for (final p in crown.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, _line(0.7, 0.5));
    for (final p in crown) {
      canvas.drawCircle(p, 1.8, _fill());
    }
    _sparkle(canvas, crown[3], 7);
  }

  void _sparkle(Canvas canvas, Offset p, double r) {
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r)
      ..close();
    canvas.drawPath(path, _fill());
  }

  /// Rows of a woven flower, each row set half over.
  void _damask(Canvas canvas, Size s) {
    const step = 92.0;
    final fill = _fill();
    final line = _line(1.1);
    var row = 0;
    for (var y = 0.0; y < s.height + step; y += step * 0.6, row++) {
      for (var x = row.isOdd ? step / 2 : 0.0; x < s.width + step; x += step) {
        canvas.save();
        canvas.translate(x, y);
        // Four petals, and four leaves between them.
        for (var k = 0; k < 4; k++) {
          canvas.save();
          canvas.rotate(k * math.pi / 2);
          canvas.drawPath(
              Path()
                ..moveTo(0, -4)
                ..cubicTo(-9, -12, -6, -24, 0, -26)
                ..cubicTo(6, -24, 9, -12, 0, -4)
                ..close(),
              fill);
          canvas.rotate(math.pi / 4);
          canvas.drawPath(
              Path()
                ..moveTo(0, -8)
                ..quadraticBezierTo(-6, -16, 0, -21)
                ..quadraticBezierTo(6, -16, 0, -8),
              line);
          canvas.restore();
        }
        canvas.drawCircle(Offset.zero, 4.5, line);
        canvas.restore();
      }
    }
  }

  /// Fine stripes, in pairs.
  void _pinstripe(Canvas canvas, Size s) {
    final line = _line();
    final path = Path();
    for (var x = 12.0; x < s.width; x += 30) {
      path
        ..moveTo(x, 0)
        ..lineTo(x, s.height)
        ..moveTo(x + 4, 0)
        ..lineTo(x + 4, s.height);
    }
    canvas.drawPath(path, line);
  }

  /// A gilt rule tooled inside the edge, a flourish in each corner, and a
  /// lozenge in the middle.
  void _tooled(Canvas canvas, Size s) {
    final outer = RRect.fromRectAndRadius(Rect.fromLTRB(20, 20, s.width - 20, s.height - 20), const Radius.circular(6));
    canvas.drawRRect(outer, _line(1.6));
    canvas.drawRRect(outer.deflate(6), _line(0.8));
    // A row of tooled dots between the rules.
    final dot = _fill(0.8);
    final r = outer.deflate(3).outerRect;
    for (var x = r.left + 12; x < r.right - 8; x += 12) {
      canvas.drawCircle(Offset(x, r.top), 1, dot);
      canvas.drawCircle(Offset(x, r.bottom), 1, dot);
    }
    for (var y = r.top + 12; y < r.bottom - 8; y += 12) {
      canvas.drawCircle(Offset(r.left, y), 1, dot);
      canvas.drawCircle(Offset(r.right, y), 1, dot);
    }
    // The corners: a scroll curling in, with a leaf.
    final inner = outer.deflate(6).outerRect;
    for (final (corner, sx, sy) in [
      (inner.topLeft, 1.0, 1.0),
      (inner.topRight, -1.0, 1.0),
      (inner.bottomLeft, 1.0, -1.0),
      (inner.bottomRight, -1.0, -1.0),
    ]) {
      canvas.save();
      canvas.translate(corner.dx, corner.dy);
      canvas.scale(sx, sy);
      canvas.drawPath(
          Path()
            ..moveTo(0, 40)
            ..cubicTo(0, 14, 14, 0, 40, 0)
            ..moveTo(10, 30)
            ..cubicTo(10, 16, 16, 10, 30, 10)
            ..moveTo(14, 14)
            ..cubicTo(24, 18, 26, 26, 20, 30)
            ..cubicTo(14, 26, 12, 20, 14, 14),
          _line(1.2));
      canvas.drawCircle(const Offset(8, 8), 2.2, _fill());
      canvas.restore();
    }
    final c = Offset(s.width / 2, s.height * 0.45);
    final m = math.min(s.width, s.height) * 0.08;
    final lozenge = Path()
      ..moveTo(c.dx, c.dy - m)
      ..lineTo(c.dx + m * 0.7, c.dy)
      ..lineTo(c.dx, c.dy + m)
      ..lineTo(c.dx - m * 0.7, c.dy)
      ..close();
    canvas.drawPath(lozenge, _line(1.2));
    canvas.drawCircle(c, m * 0.22, _line());
  }

  /// Squares a shade apart.
  void _chequer(Canvas canvas, Size s) {
    const step = 64.0;
    final fill = _fill();
    final path = Path();
    for (var y = 0; y * step < s.height; y++) {
      for (var x = y.isOdd ? 1 : 0; x * step < s.width; x += 2) {
        path.addRect(Rect.fromLTWH(x * step, y * step, step, step));
      }
    }
    canvas.drawPath(path, fill);
  }

  /// Boards with their seams, butt joints and grain.
  void _planks(Canvas canvas, Size s) {
    const board = 70.0;
    final rand = math.Random(3);
    final seam = _line(2);
    final grain = _line(0.9, 0.45);
    for (var y = 0.0; y < s.height; y += board) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), seam);
      // Joints, staggered board to board.
      var x = rand.nextDouble() * 300;
      while (x < s.width) {
        canvas.drawLine(Offset(x, y), Offset(x, y + board), seam);
        x += 260 + rand.nextDouble() * 220;
      }
      // Grain: long gentle waves, with a knot now and then.
      for (var g = 0; g < 5; g++) {
        final gy = y + 8 + g * (board - 16) / 4;
        final phase = rand.nextDouble() * math.pi * 2;
        final path = Path()..moveTo(0, gy);
        for (var gx = 0.0; gx <= s.width; gx += 24) {
          path.lineTo(gx, gy + math.sin(gx / 90 + phase) * 2.4);
        }
        canvas.drawPath(path, grain);
      }
      if (rand.nextBool()) {
        final k = Offset(rand.nextDouble() * s.width, y + board / 2);
        canvas.drawOval(Rect.fromCenter(center: k, width: 18, height: 8), grain);
        canvas.drawOval(Rect.fromCenter(center: k, width: 8, height: 3.5), grain);
      }
    }
  }

  /// Polished marble, laid in slabs: each slab clouded a little lighter or
  /// darker, its veins tapering and branching, fainter threads between,
  /// the joints fine pale lines, and a round inlay in the middle of the
  /// floor. (Drawn once, so the clouds' soft gradients cost nothing after.)
  void _marble(Canvas canvas, Size s) {
    final rand = math.Random(11);
    const slab = 240.0;
    // The clouds: soft patches of the vein colour, and of shadow.
    for (var k = 0; k < (s.width * s.height / 26000).round().clamp(6, 80); k++) {
      final c = Offset(rand.nextDouble() * s.width, rand.nextDouble() * s.height);
      final r = 60 + rand.nextDouble() * 140;
      final light = rand.nextBool();
      final tint = light ? ink.withValues(alpha: ink.a * 0.22) : const Color(0x2A000000);
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(colors: [tint, tint.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: c, radius: r)));
    }
    // The veins: long, wandering, thick in the middle and thin at each end.
    void vein(Offset start, double angle, int steps, double width, double alpha) {
      var p = start;
      var a = angle;
      for (var k = 0; k < steps; k++) {
        a += (rand.nextDouble() - 0.5) * 0.7;
        final next = p + Offset(math.cos(a), math.sin(a)) * (14 + rand.nextDouble() * 10);
        final taper = math.sin((k + 0.5) / steps * math.pi);
        canvas.drawLine(p, next, _line(0.35 + width * taper, alpha * (0.4 + 0.6 * taper))..strokeCap = StrokeCap.round);
        // Threads off it, now and then.
        if (rand.nextDouble() < 0.12) {
          final b = a + (rand.nextBool() ? 0.8 : -0.8);
          var q = next;
          var ba = b;
          for (var t = 0; t < 4 + rand.nextInt(5); t++) {
            ba += (rand.nextDouble() - 0.5) * 0.9;
            final qn = q + Offset(math.cos(ba), math.sin(ba)) * 12;
            canvas.drawLine(q, qn, _line(0.5, alpha * 0.5));
            q = qn;
          }
        }
        p = next;
      }
    }
    final veins = (s.width * s.height / 60000).round().clamp(4, 40);
    for (var v = 0; v < veins; v++) {
      vein(Offset(rand.nextDouble() * s.width, rand.nextDouble() * s.height), rand.nextDouble() * math.pi * 2,
          14 + rand.nextInt(14), 1.2 + rand.nextDouble() * 1.6, 0.55 + rand.nextDouble() * 0.45);
    }
    // Fainter threads everywhere between.
    for (var v = 0; v < veins * 2; v++) {
      vein(Offset(rand.nextDouble() * s.width, rand.nextDouble() * s.height), rand.nextDouble() * math.pi * 2,
          6 + rand.nextInt(6), 0.3, 0.35);
    }
    // The slabs' joints.
    final joint = _line(1, 0.55);
    for (var x = slab; x < s.width; x += slab) {
      canvas.drawLine(Offset(x, 0), Offset(x, s.height), joint);
    }
    for (var y = slab; y < s.height; y += slab) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), joint);
    }
    // The inlay in the middle: a ring of a darker stone, and a lozenge.
    final c = Offset(s.width / 2, s.height * 0.45);
    final r = math.min(s.width, s.height) * 0.16;
    canvas.drawCircle(c, r, _line(2.2, 0.7));
    canvas.drawCircle(c, r * 0.86, _line(0.8, 0.6));
    canvas.drawCircle(c, r * 0.86, Paint()..color = const Color(0x1A000000));
    final lozenge = Path()
      ..moveTo(c.dx, c.dy - r * 0.8)
      ..lineTo(c.dx + r * 0.8, c.dy)
      ..lineTo(c.dx, c.dy + r * 0.8)
      ..lineTo(c.dx - r * 0.8, c.dy)
      ..close();
    canvas.drawPath(lozenge, _line(1.2, 0.65));
    canvas.drawCircle(c, r * 0.22, _fill(0.35));
  }

  /// Rows of fans, each row over the one before.
  void _deco(Canvas canvas, Size s) {
    const r = 38.0;
    final ground = Paint()..color = this.ground;
    final line = _line(1.2);
    final fine = _line(0.8, 0.8);
    var row = 0;
    for (var y = -r; y < s.height + r; y += r * 0.62, row++) {
      for (var x = row.isOdd ? r : 0.0; x < s.width + 2 * r; x += 2 * r) {
        final c = Offset(x, y + r);
        final fan = Rect.fromCircle(center: c, radius: r);
        // The ground first, so each fan covers the ones behind it.
        canvas.drawArc(fan, math.pi, math.pi, true, ground);
        canvas.drawArc(fan, math.pi, math.pi, true, line);
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.7), math.pi, math.pi, false, fine);
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.4), math.pi, math.pi, false, fine);
        for (var k = 1; k < 6; k++) {
          final a = math.pi + k * math.pi / 6;
          canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r * 0.4,
              c + Offset(math.cos(a), math.sin(a)) * r * 0.7, fine);
        }
      }
    }
  }

  /// Square tiles, each with a four-pointed star, diamonds where they meet.
  void _tiles(Canvas canvas, Size s) {
    const step = 72.0;
    final grid = Path();
    for (var x = 0.0; x <= s.width; x += step) {
      grid
        ..moveTo(x, 0)
        ..lineTo(x, s.height);
    }
    for (var y = 0.0; y <= s.height; y += step) {
      grid
        ..moveTo(0, y)
        ..lineTo(s.width, y);
    }
    canvas.drawPath(grid, _line(1.4));
    final star = Path();
    final dots = Path();
    for (var y = 0.0; y < s.height + step; y += step) {
      for (var x = 0.0; x < s.width + step; x += step) {
        final c = Offset(x + step / 2, y + step / 2);
        const a = step * 0.36, b = step * 0.1;
        star
          ..moveTo(c.dx, c.dy - a)
          ..lineTo(c.dx + b, c.dy - b)
          ..lineTo(c.dx + a, c.dy)
          ..lineTo(c.dx + b, c.dy + b)
          ..lineTo(c.dx, c.dy + a)
          ..lineTo(c.dx - b, c.dy + b)
          ..lineTo(c.dx - a, c.dy)
          ..lineTo(c.dx - b, c.dy - b)
          ..close();
        star.addOval(Rect.fromCircle(center: c, radius: step * 0.42));
        dots
          ..moveTo(x, y - 7)
          ..lineTo(x + 7, y)
          ..lineTo(x, y + 7)
          ..lineTo(x - 7, y)
          ..close();
      }
    }
    canvas.drawPath(star, _line());
    canvas.drawPath(dots, _fill());
  }

  /// Contour lines round a few hills.
  void _contours(Canvas canvas, Size s) {
    final rand = math.Random(5);
    final hills = 3 + (s.width * s.height / 400000).round().clamp(0, 5);
    final line = _line();
    final bold = _line(1.6);
    for (var h = 0; h < hills; h++) {
      final c = Offset(rand.nextDouble() * s.width, rand.nextDouble() * s.height);
      final harmonics = [for (var k = 0; k < 3; k++) (rand.nextDouble() * 0.25, rand.nextDouble() * math.pi * 2)];
      final rings = 5 + rand.nextInt(5);
      for (var ring = 1; ring <= rings; ring++) {
        final r = ring * 26.0;
        final path = Path();
        for (var k = 0; k <= 72; k++) {
          final a = k * math.pi / 36;
          var f = 1.0;
          for (var i = 0; i < harmonics.length; i++) {
            f += harmonics[i].$1 * math.sin(a * (i + 2) + harmonics[i].$2);
          }
          final p = c + Offset(math.cos(a), math.sin(a) * 0.75) * r * f;
          if (k == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(path, ring % 4 == 0 ? bold : line);
      }
      // The top: a small cross.
      canvas.drawLine(c - const Offset(4, 0), c + const Offset(4, 0), bold);
      canvas.drawLine(c - const Offset(0, 4), c + const Offset(0, 4), bold);
    }
  }

  /// Herringbone parquet: columns of short boards, sloping one way then
  /// the other.
  void _herringbone(Canvas canvas, Size s) {
    const column = 34.0, board = 13.0;
    final path = Path();
    var i = 0;
    for (var x = 0.0; x < s.width; x += column, i++) {
      path
        ..moveTo(x, 0)
        ..lineTo(x, s.height);
      final rise = i.isEven ? -column : column;
      for (var y = -column; y < s.height + column; y += board) {
        path
          ..moveTo(x, y)
          ..lineTo(x + column, y + rise);
      }
    }
    canvas.drawPath(path, _line(1.1));
  }

  /// A cabana's awning: broad stripes down the cloth, every other one
  /// filled, under a valance of scallops along the top.
  void _awning(Canvas canvas, Size s) {
    const stripe = 46.0;
    const drop = 30.0;
    final fill = _fill(0.55);
    final edge = _line(1, 0.8);
    for (var x = 0.0; x < s.width; x += stripe * 2) {
      canvas.drawRect(Rect.fromLTWH(x, drop, stripe, s.height), fill);
      canvas.drawLine(Offset(x + 4, drop), Offset(x + 4, s.height), _line(0.7, 0.5));
      canvas.drawLine(Offset(x + stripe - 4, drop), Offset(x + stripe - 4, s.height), _line(0.7, 0.5));
    }
    // The valance: a scallop under each stripe, filled like the stripe.
    for (var x = 0.0, k = 0; x < s.width; x += stripe, k++) {
      final scallop = Path()
        ..moveTo(x, 0)
        ..lineTo(x, drop - stripe / 2)
        ..arcToPoint(Offset(x + stripe, drop - stripe / 2), radius: const Radius.circular(stripe / 2), clockwise: false)
        ..lineTo(x + stripe, 0)
        ..close();
      if (k.isEven) canvas.drawPath(scallop, _fill(0.75));
      canvas.drawPath(scallop, edge);
    }
    canvas.drawLine(const Offset(0, 6), Offset(s.width, 6), _line(1.4, 0.8));
  }

  /// Frost: snowflakes of six arms, each arm feathered, scattered large and
  /// small; and ferns of ice grown in from the corners.
  void _frost(Canvas canvas, Size s) {
    final rand = math.Random(5);
    void flake(Offset c, double r, double alpha) {
      final line = _line(r > 18 ? 1.2 : 0.9, alpha)..strokeCap = StrokeCap.round;
      for (var k = 0; k < 6; k++) {
        final a = k * math.pi / 3 + 0.26;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c, c + d * r, line);
        for (final f in const [0.45, 0.72]) {
          final at = c + d * r * f;
          for (final side in const [-1.0, 1.0]) {
            final b = a + side * 0.75;
            canvas.drawLine(at, at + Offset(math.cos(b), math.sin(b)) * r * 0.28, line);
          }
        }
      }
      canvas.drawCircle(c, r * 0.12, line);
    }
    final n = (s.width * s.height / 22000).round().clamp(6, 60);
    for (var k = 0; k < n; k++) {
      final big = rand.nextDouble() < 0.25;
      flake(Offset(rand.nextDouble() * s.width, rand.nextDouble() * s.height),
          big ? 22 + rand.nextDouble() * 14 : 6 + rand.nextDouble() * 8, big ? 0.75 : 0.5);
    }
    // Ice ferns from each corner: a stem that wanders in, fronds off it.
    void fern(Offset start, double angle, double length, int depth) {
      var p = start;
      var a = angle;
      final steps = (length / 10).round();
      for (var k = 0; k < steps; k++) {
        a += (rand.nextDouble() - 0.5) * 0.25;
        final next = p + Offset(math.cos(a), math.sin(a)) * 10;
        canvas.drawLine(p, next, _line(depth == 0 ? 1.1 : 0.6, depth == 0 ? 0.7 : 0.5));
        if (depth < 2 && k.isOdd) {
          fern(next, a + (k % 4 == 1 ? 0.9 : -0.9), length * (0.35 - k / steps * 0.25), depth + 1);
        }
        p = next;
      }
    }
    for (final (corner, angle) in [
      (Offset.zero, math.pi / 4),
      (Offset(s.width, 0), math.pi * 3 / 4),
      (Offset(0, s.height), -math.pi / 4),
      (Offset(s.width, s.height), -math.pi * 3 / 4),
    ]) {
      for (var k = -1; k <= 1; k++) {
        fern(corner, angle + k * 0.32, 150 + rand.nextDouble() * 90, 0);
      }
    }
  }

  /// Egyptian bands: between pairs of rules with a zigzag in them, rows of
  /// lotus flowers and papyrus buds on their stems, turn and turn about.
  void _lotus(Canvas canvas, Size s) {
    const band = 26.0;
    const row = 132.0;
    final rule = _line(1.2);
    final fine = _line(0.9, 0.85);
    for (var y = 0.0; y < s.height + row; y += row) {
      // The border band: two rules and a zigzag.
      canvas.drawLine(Offset(0, y), Offset(s.width, y), rule);
      canvas.drawLine(Offset(0, y + band), Offset(s.width, y + band), rule);
      final zig = Path()..moveTo(0, y + band - 4);
      for (var x = 0.0, k = 0; x <= s.width + 14; x += 14, k++) {
        zig.lineTo(x, k.isEven ? y + band - 4 : y + 4);
      }
      canvas.drawPath(zig, fine);
      // The row of flowers under it.
      final base = y + row - 8;
      for (var x = 30.0, k = 0; x < s.width + 40; x += 60, k++) {
        final stem = Offset(x, base);
        final head = Offset(x, y + band + 40);
        canvas.drawLine(stem, head + const Offset(0, 14), fine);
        if (k.isEven) {
          // A lotus: a tall middle petal and a petal curling out each side.
          final petal = Path()
            ..moveTo(head.dx, head.dy + 14)
            ..quadraticBezierTo(head.dx - 9, head.dy, head.dx, head.dy - 16)
            ..quadraticBezierTo(head.dx + 9, head.dy, head.dx, head.dy + 14);
          canvas.drawPath(petal, _fill(0.55));
          canvas.drawPath(petal, fine);
          for (final side in const [-1.0, 1.0]) {
            final p = Path()
              ..moveTo(head.dx, head.dy + 14)
              ..quadraticBezierTo(head.dx + side * 20, head.dy + 8, head.dx + side * 18, head.dy - 8)
              ..quadraticBezierTo(head.dx + side * 10, head.dy + 2, head.dx, head.dy + 14);
            canvas.drawPath(p, fine);
          }
        } else {
          // A papyrus bud: a fan closed to a point.
          final bud = Path()
            ..moveTo(head.dx, head.dy + 14)
            ..lineTo(head.dx - 11, head.dy - 6)
            ..quadraticBezierTo(head.dx, head.dy - 14, head.dx + 11, head.dy - 6)
            ..close();
          canvas.drawPath(bud, fine);
          for (final dx in const [-5.0, 0.0, 5.0]) {
            canvas.drawLine(Offset(head.dx, head.dy + 12), Offset(head.dx + dx, head.dy - 6), _line(0.6, 0.6));
          }
        }
      }
    }
  }

  /// A treasure map: a stretch of coast with hatching along its shore,
  /// waves out at sea, a dashed course to an X, a compass rose, and a rope
  /// laid round the edge.
  void _map(Canvas canvas, Size s) {
    final rand = math.Random(17);
    final line = _line(1.2);
    final fine = _line(0.8, 0.7);
    // The coast: an island's outline off one side, its shore hatched.
    final island = Path();
    final c = Offset(s.width * 0.22, s.height * 0.58);
    final rx = s.width * 0.2, ry = s.height * 0.16;
    for (var k = 0; k <= 36; k++) {
      final a = k / 36 * math.pi * 2;
      final wobble = 1 + (math.sin(a * 3 + 1) * 0.12 + math.sin(a * 7) * 0.06);
      final p = c + Offset(math.cos(a) * rx * wobble, math.sin(a) * ry * wobble);
      k == 0 ? island.moveTo(p.dx, p.dy) : island.lineTo(p.dx, p.dy);
    }
    island.close();
    canvas.drawPath(island, _fill(0.18));
    canvas.drawPath(island, line);
    for (var k = 0; k < 60; k++) {
      final a = k / 60 * math.pi * 2;
      final wobble = 1 + (math.sin(a * 3 + 1) * 0.12 + math.sin(a * 7) * 0.06);
      final p = c + Offset(math.cos(a) * rx * wobble, math.sin(a) * ry * wobble);
      final out = Offset(math.cos(a), math.sin(a)) * 9;
      canvas.drawLine(p + out * 0.4, p + out, fine);
    }
    // Waves out at sea.
    for (var k = 0; k < (s.width * s.height / 30000).round().clamp(4, 40); k++) {
      final p = Offset(rand.nextDouble() * s.width, rand.nextDouble() * s.height);
      if ((p - c).dx.abs() < rx * 1.3 && (p - c).dy.abs() < ry * 1.4) continue;
      final w = Path()
        ..moveTo(p.dx, p.dy)
        ..quadraticBezierTo(p.dx + 6, p.dy - 5, p.dx + 12, p.dy)
        ..quadraticBezierTo(p.dx + 18, p.dy - 5, p.dx + 24, p.dy);
      canvas.drawPath(w, fine);
    }
    // The course: dashed, from the far side to the X on the island.
    final x = c + Offset(rx * 0.25, -ry * 0.15);
    final course = Path()
      ..moveTo(s.width * 0.9, s.height * 0.12)
      ..cubicTo(s.width * 0.75, s.height * 0.42, s.width * 0.55, s.height * 0.2, x.dx, x.dy);
    for (final m in course.computeMetrics()) {
      for (var d = 0.0; d < m.length - 14; d += 16) {
        canvas.drawPath(m.extractPath(d, d + 9), _line(1.6, 0.85));
      }
    }
    final xs = _line(2.6)..strokeCap = StrokeCap.round;
    canvas.drawLine(x + const Offset(-9, -9), x + const Offset(9, 9), xs);
    canvas.drawLine(x + const Offset(9, -9), x + const Offset(-9, 9), xs);
    // A compass rose in the top corner.
    final rose = Offset(s.width * 0.2, s.height * 0.16);
    final rr = math.min(s.width, s.height) * 0.08;
    canvas.drawCircle(rose, rr, fine);
    canvas.drawCircle(rose, rr * 0.75, fine);
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      final len = k.isEven ? rr * 1.25 : rr * 0.75;
      final tip = rose + Offset(math.cos(a), math.sin(a)) * len;
      final l = rose + Offset(math.cos(a + math.pi / 2), math.sin(a + math.pi / 2)) * rr * 0.14;
      final r = rose + Offset(math.cos(a - math.pi / 2), math.sin(a - math.pi / 2)) * rr * 0.14;
      final point = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(l.dx, l.dy)
        ..lineTo(r.dx, r.dy)
        ..close();
      canvas.drawPath(point, k.isEven ? _fill(0.6) : fine);
    }
    // A rope round the edge: a twist of short slanted strokes.
    const inset = 14.0;
    final rope = Rect.fromLTRB(inset, inset, s.width - inset, s.height - inset);
    final twist = _line(1.6, 0.8)..strokeCap = StrokeCap.round;
    void along(Offset a, Offset b) {
      final len = (b - a).distance;
      final d = (b - a) / len;
      final n = Offset(-d.dy, d.dx);
      for (var t = 0.0; t < len; t += 7) {
        final p = a + d * t;
        canvas.drawLine(p - n * 3.5, p + d * 5 + n * 3.5, twist);
      }
    }
    along(rope.topLeft, rope.topRight);
    along(rope.topRight, rope.bottomRight);
    along(rope.bottomRight, rope.bottomLeft);
    along(rope.bottomLeft, rope.topLeft);
  }

  /// Gingham: bands of the ink across and down, half as strong, so where
  /// they cross they're as strong again.
  void _gingham(Canvas canvas, Size s) {
    const step = 34.0;
    final band = _fill(0.5);
    for (var x = 0.0; x < s.width; x += step * 2) {
      canvas.drawRect(Rect.fromLTWH(x, 0, step, s.height), band);
    }
    for (var y = 0.0; y < s.height; y += step * 2) {
      canvas.drawRect(Rect.fromLTWH(0, y, s.width, step), band);
    }
  }

  /// A casino's baize: a gilt rail, two fine lines round an oval inset
  /// from the edge, and the four suits in rows across the cloth.
  void _baize(Canvas canvas, Size s) {
    const step = 84.0;
    var row = 0;
    for (var y = step / 2; y < s.height + step; y += step * 0.86, row++) {
      for (var x = (row.isOdd ? step / 2 : 0.0) + step / 2, k = row; x < s.width + step; x += step, k++) {
        _suit(canvas, Offset(x, y), 9, k % 4, _fill(0.5));
      }
    }
    final rail = Rect.fromLTRB(s.width * 0.05, s.height * 0.06, s.width * 0.95, s.height * 0.94);
    final r = Radius.circular(math.min(rail.width, rail.height) / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(rail, r), _line(2.4));
    canvas.drawRRect(RRect.fromRectAndRadius(rail.deflate(7), r), _line(0.9, 0.8));
  }

  /// A suit's mark, [size] across: spades, hearts, diamonds, clubs for
  /// [which] 0 to 3.
  void _suit(Canvas canvas, Offset c, double size, int which, Paint paint) {
    final h = size;
    switch (which) {
      case 1: // hearts
        final p = Path()
          ..moveTo(c.dx, c.dy + h)
          ..cubicTo(c.dx - h * 1.6, c.dy - h * 0.2, c.dx - h * 0.6, c.dy - h * 1.3, c.dx, c.dy - h * 0.4)
          ..cubicTo(c.dx + h * 0.6, c.dy - h * 1.3, c.dx + h * 1.6, c.dy - h * 0.2, c.dx, c.dy + h)
          ..close();
        canvas.drawPath(p, paint);
      case 2: // diamonds
        final p = Path()
          ..moveTo(c.dx, c.dy - h)
          ..lineTo(c.dx + h * 0.72, c.dy)
          ..lineTo(c.dx, c.dy + h)
          ..lineTo(c.dx - h * 0.72, c.dy)
          ..close();
        canvas.drawPath(p, paint);
      case 3: // clubs
        canvas.drawCircle(c + Offset(0, -h * 0.45), h * 0.42, paint);
        canvas.drawCircle(c + Offset(-h * 0.45, h * 0.15), h * 0.42, paint);
        canvas.drawCircle(c + Offset(h * 0.45, h * 0.15), h * 0.42, paint);
        canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy)
              ..lineTo(c.dx + h * 0.25, c.dy + h)
              ..lineTo(c.dx - h * 0.25, c.dy + h)
              ..close(),
            paint);
      default: // spades
        final p = Path()
          ..moveTo(c.dx, c.dy - h)
          ..cubicTo(c.dx + h * 1.6, c.dy + h * 0.1, c.dx + h * 0.6, c.dy + h * 1.0, c.dx, c.dy + h * 0.3)
          ..cubicTo(c.dx - h * 0.6, c.dy + h * 1.0, c.dx - h * 1.6, c.dy + h * 0.1, c.dx, c.dy - h)
          ..close();
        canvas.drawPath(p, paint);
        canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy + h * 0.2)
              ..lineTo(c.dx + h * 0.25, c.dy + h)
              ..lineTo(c.dx - h * 0.25, c.dy + h)
              ..close(),
            paint);
    }
  }

  @override
  bool shouldRepaint(FeltPatternPainter old) =>
      old.pattern != pattern || old.ink != ink || old.ground != ground || old.scale != scale || old.soft != soft;
}
