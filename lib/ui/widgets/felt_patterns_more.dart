part of 'felt_patterns.dart';

/// The patterns of the later rooms (Riviera, Winter palace, Egyptian,
/// Galleon, Scopa, Casino), drawn by [FeltPatternPainter] as the others are
/// (with what's hidden in some of them: felt_patterns_eggs.dart).
extension _MorePatterns on FeltPatternPainter {
  /// A Riviera terrace: glazed tiles, a circle traced across the corners
  /// of every four, and in each tile turn about a lemon on its sprig or the
  /// sun; a few tiles sun-bleached paler than the rest.
  void _awning(Canvas canvas, Size s) {
    const tile = 76.0;
    final rand = math.Random(9);
    final joint = _line(1, 0.45);
    final line = _line(1.1, 0.85)..strokeCap = StrokeCap.round;
    for (var y = 0.0, j = 0; y < s.height + tile; y += tile, j++) {
      for (var x = 0.0, i = 0; x < s.width + tile; x += tile, i++) {
        final r = Rect.fromLTWH(x, y, tile, tile);
        // Bleached by the sun: a few tiles a wash paler.
        if (rand.nextDouble() < 0.18) canvas.drawRect(r.deflate(1.5), _fill(0.18));
        canvas.drawRect(r, joint);
        // A quarter circle in each corner: across four tiles, a ring.
        for (final (corner, start) in [
          (r.topLeft, 0.0),
          (r.topRight, math.pi / 2),
          (r.bottomRight, math.pi),
          (r.bottomLeft, math.pi * 1.5),
        ]) {
          canvas.drawArc(Rect.fromCircle(center: corner, radius: tile * 0.3), start, math.pi / 2, false, line);
        }
        final c = r.center;
        if ((i + j).isEven) {
          // A lemon on its sprig: the fruit, a point at its end, two leaves.
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(-0.5);
          canvas.drawOval(const Rect.fromLTWH(-11, -7.5, 22, 15), _fill(0.75));
          canvas.drawCircle(const Offset(11.5, 0), 1.8, _fill(0.75));
          for (final side in const [-1.0, 1.0]) {
            canvas.drawPath(
                Path()
                  ..moveTo(-11, 0)
                  ..quadraticBezierTo(-17, side * 9, -24, side * 4)
                  ..quadraticBezierTo(-17, side * 1, -11, 0),
                line);
          }
          canvas.restore();
        } else {
          // The sun: a ring and its rays.
          canvas.drawCircle(c, 7, _fill(0.6));
          for (var k = 0; k < 12; k++) {
            final a = k * math.pi / 6;
            final d = Offset(math.cos(a), math.sin(a));
            canvas.drawLine(c + d * 10, c + d * (k.isEven ? 16 : 13), line);
          }
        }
      }
    }
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
    _lotusEggs(canvas, s, band: band, row: row);
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
    // The land in parchment, the sea round it the table's own blue.
    canvas.drawPath(island, Paint()..color = const Color(0xFFE3CC97).withValues(alpha: math.min(0.5, ink.a * 1.7)));
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
    _galleonEggs(canvas, s, c, rx, ry);
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
}
