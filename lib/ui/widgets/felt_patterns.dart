/// What's worked into a table's felt (looks.dart: [FeltPattern]): drawn
/// once, under the lamp light and everything on the table, faintly, in
/// the table's own ink.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/looks.dart';

/// Draws [pattern] in [ink] over a felt of [ground], at [scale] (smaller
/// for a little table in the Look dialog).
class FeltPatternPainter extends CustomPainter {
  const FeltPatternPainter(this.pattern, this.ink, {required this.ground, this.scale = 1});
  final FeltPattern pattern;
  final Color ink;
  final Color ground;
  final double scale;

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
    }
    canvas.restore();
  }

  Paint _line([double width = 1, double alpha = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..isAntiAlias = true
    ..color = ink.withValues(alpha: ink.a * alpha);

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

  /// Veins wandering across, thick and thin.
  void _marble(Canvas canvas, Size s) {
    final rand = math.Random(11);
    final veins = (s.width * s.height / 70000).round().clamp(4, 40);
    for (var v = 0; v < veins; v++) {
      var p = Offset(rand.nextDouble() * s.width, rand.nextDouble() * s.height);
      var a = rand.nextDouble() * math.pi * 2;
      final path = Path()..moveTo(p.dx, p.dy);
      for (var k = 0; k < 14; k++) {
        a += (rand.nextDouble() - 0.5) * 1.1;
        final mid = p + Offset(math.cos(a), math.sin(a)) * 22;
        a += (rand.nextDouble() - 0.5) * 0.6;
        final next = mid + Offset(math.cos(a), math.sin(a)) * 22;
        path.quadraticBezierTo(mid.dx, mid.dy, next.dx, next.dy);
        p = next;
        // A thread branching off, now and then.
        if (rand.nextDouble() < 0.2) {
          final b = a + (rand.nextBool() ? 0.9 : -0.9);
          canvas.drawLine(p, p + Offset(math.cos(b), math.sin(b)) * (20 + rand.nextDouble() * 40), _line(0.6, 0.6));
        }
      }
      canvas.drawPath(path, _line(0.6 + rand.nextDouble() * 1.8, 0.5 + rand.nextDouble() * 0.5));
    }
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

  @override
  bool shouldRepaint(FeltPatternPainter old) =>
      old.pattern != pattern || old.ink != ink || old.ground != ground || old.scale != scale;
}

/// [child] (a pattern) faded away in the middle, where the words are, and
/// left at the edges: how a page or a menu keeps its room's pattern
/// without it getting in the way of reading.
class EdgesOnly extends StatelessWidget {
  const EdgesOnly({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const RadialGradient(
          radius: 0.95,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x99000000), Color(0xFF000000)],
          stops: [0, 0.45, 0.8, 1],
        ).createShader(bounds),
        child: child,
      );
}
