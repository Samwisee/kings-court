part of 'felt_patterns.dart';

/// Little things hidden in the maps and walls, faint as the rest of the
/// pattern, for a player to come across over many games: on the treasure
/// map a palm on the island, a crown in its coast, a ship setting out, a
/// sea serpent, a whale's tail, a kraken's arm, a bottle with a message
/// and "here be dragons"; on the campaign map a fort on a hill, a camp and
/// crossed swords where the battle was; on the Egyptian walls an eye, a
/// cat and a pyramid.
extension _Eggs on FeltPatternPainter {
  /// The treasure map's: round the island ([c], [rx] by [ry]) and out at
  /// sea.
  void _galleonEggs(Canvas canvas, Size s, Offset c, double rx, double ry) {
    final line = _line(1.1, 0.8)..strokeCap = StrokeCap.round;
    final fill = _fill(0.55);

    // A palm on the island, leaning, by the X.
    final foot = c + Offset(-rx * 0.35, ry * 0.25);
    final top = foot + const Offset(6, -26);
    canvas.drawPath(
        Path()
          ..moveTo(foot.dx, foot.dy)
          ..quadraticBezierTo(foot.dx + 1, foot.dy - 14, top.dx, top.dy),
        _line(1.6, 0.8));
    for (final a in const [-2.7, -2.1, -1.2, -0.5, 0.2]) {
      final tip = top + Offset(math.cos(a), math.sin(a)) * 13;
      canvas.drawPath(
          Path()
            ..moveTo(top.dx, top.dy)
            ..quadraticBezierTo(
                (top.dx + tip.dx) / 2, math.min(top.dy, tip.dy) - 4, tip.dx, tip.dy + 2),
          line);
    }

    // A crown in the coastline: three points on the island's far shore.
    final shore = c + Offset(rx * 0.88, ry * 0.55);
    canvas.drawPath(
        Path()
          ..moveTo(shore.dx - 6, shore.dy + 3)
          ..lineTo(shore.dx - 6, shore.dy - 3)
          ..lineTo(shore.dx - 3, shore.dy)
          ..lineTo(shore.dx, shore.dy - 5)
          ..lineTo(shore.dx + 3, shore.dy)
          ..lineTo(shore.dx + 6, shore.dy - 3)
          ..lineTo(shore.dx + 6, shore.dy + 3)
          ..close(),
        fill);

    // A little ship setting out, where the course begins.
    final ship = Offset(s.width * 0.9, s.height * 0.12) + const Offset(10, -6);
    canvas.drawPath(
        Path()
          ..moveTo(ship.dx - 9, ship.dy)
          ..lineTo(ship.dx + 9, ship.dy)
          ..lineTo(ship.dx + 6, ship.dy + 4)
          ..lineTo(ship.dx - 6, ship.dy + 4)
          ..close(),
        fill);
    canvas.drawLine(ship, ship - const Offset(0, 14), line);
    canvas.drawPath(
        Path()
          ..moveTo(ship.dx + 1, ship.dy - 13)
          ..quadraticBezierTo(ship.dx + 9, ship.dy - 8, ship.dx + 1, ship.dy - 3)
          ..close(),
        fill);

    // A sea serpent: three humps and a head, out past the island.
    final sea = Offset(s.width * 0.62, s.height * 0.6);
    final serpent = Path()..moveTo(sea.dx, sea.dy);
    for (var k = 0; k < 3; k++) {
      final x = sea.dx + k * 14;
      serpent.quadraticBezierTo(x + 7, sea.dy - 12, x + 14, sea.dy);
    }
    serpent.quadraticBezierTo(sea.dx + 47, sea.dy - 14, sea.dx + 52, sea.dy - 10);
    canvas.drawPath(serpent, _line(1.5, 0.75));
    canvas.drawCircle(sea + const Offset(51, -11), 1.2, fill);
    for (var k = 0; k < 4; k++) {
      canvas.drawLine(sea + Offset(k * 14 - 3, 2), sea + Offset(k * 14 + 3, 2), _line(0.7, 0.5));
    }

    // A whale's tail, diving.
    final whale = Offset(s.width * 0.84, s.height * 0.5);
    canvas.drawPath(
        Path()
          ..moveTo(whale.dx, whale.dy)
          ..quadraticBezierTo(whale.dx + 1, whale.dy - 7, whale.dx - 8, whale.dy - 12)
          ..quadraticBezierTo(whale.dx - 2, whale.dy - 9, whale.dx + 1, whale.dy - 9)
          ..quadraticBezierTo(whale.dx + 4, whale.dy - 9, whale.dx + 10, whale.dy - 12)
          ..quadraticBezierTo(whale.dx + 2, whale.dy - 7, whale.dx + 3, whale.dy)
          ..close(),
        fill);
    canvas.drawLine(whale + const Offset(-7, 1), whale + const Offset(10, 1), _line(0.7, 0.5));

    // A kraken's arm, curling up out of the sea.
    final arm = Offset(s.width * 0.95, s.height * 0.68);
    canvas.drawPath(
        Path()
          ..moveTo(arm.dx - 6, arm.dy)
          ..cubicTo(arm.dx - 4, arm.dy - 34, arm.dx - 30, arm.dy - 30, arm.dx - 24, arm.dy - 48)
          ..cubicTo(arm.dx - 20, arm.dy - 56, arm.dx - 12, arm.dy - 50, arm.dx - 16, arm.dy - 46),
        _line(2.2, 0.6)..strokeCap = StrokeCap.round);
    for (var k = 1; k < 4; k++) {
      canvas.drawCircle(Offset(arm.dx - 7 - k * 3.5, arm.dy - k * 9), 1.1, _fill(0.5));
    }

    // A bottle with a message in it, bobbing.
    final bottle = Offset(s.width * 0.55, s.height * 0.66);
    canvas.save();
    canvas.translate(bottle.dx, bottle.dy);
    canvas.rotate(-0.5);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -3, 11, 6), const Radius.circular(3)), line);
    canvas.drawRect(const Rect.fromLTWH(4, -1.5, 4, 3), fill);
    canvas.drawLine(const Offset(-4, 0), const Offset(1, 0), _line(0.8, 0.6));
    canvas.restore();
    canvas.drawLine(bottle + const Offset(-10, 6), bottle + const Offset(8, 6), _line(0.7, 0.5));

    // Here be dragons, in a corner the course doesn't reach.
    final words = TextPainter(
      text: TextSpan(
        text: 'here be dragons',
        style: TextStyle(
            fontFamily: 'AlegreyaSans',
            fontSize: 10,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.6,
            color: ink.withValues(alpha: ink.a * 0.75)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    words.paint(canvas, Offset(s.width * 0.56, s.height * 0.73));
  }

  /// The campaign map's: a fort on the hill [top], a camp of tents and
  /// crossed swords where the battle was.
  void _campaignEggs(Canvas canvas, Size s, Offset top) {
    final line = _line(1.1, 0.85);
    final fill = _fill(0.6);
    // The fort: a wall with battlements, a tower, a pennant.
    final wall = Path()..moveTo(top.dx - 9, top.dy + 4);
    for (var k = 0; k < 4; k++) {
      final x = top.dx - 9 + k * 4.5;
      wall
        ..lineTo(x, top.dy - 2)
        ..lineTo(x + 2.25, top.dy - 2)
        ..lineTo(x + 2.25, top.dy)
        ..lineTo(x + 4.5, top.dy);
    }
    wall
      ..lineTo(top.dx + 9, top.dy + 4)
      ..close();
    canvas.drawPath(wall, fill);
    canvas.drawLine(top + const Offset(0, -2), top + const Offset(0, -12), line);
    canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy - 12)
          ..lineTo(top.dx + 7, top.dy - 10)
          ..lineTo(top.dx, top.dy - 8)
          ..close(),
        fill);

    // A camp: three tents in a row.
    final camp = Offset(s.width * 0.5, s.height * 0.42);
    for (var k = 0; k < 3; k++) {
      final t = camp + Offset(k * 13.0, k.isOdd ? 3 : 0);
      canvas.drawPath(
          Path()
            ..moveTo(t.dx - 5, t.dy + 5)
            ..lineTo(t.dx, t.dy - 4)
            ..lineTo(t.dx + 5, t.dy + 5)
            ..close(),
          k == 1 ? fill : line);
    }

    // Crossed swords where the battle was.
    final battle = Offset(s.width * 0.6, s.height * 0.68);
    final blade = _line(1.4, 0.85)..strokeCap = StrokeCap.round;
    for (final d in const [1.0, -1.0]) {
      canvas.drawLine(battle + Offset(-8 * d, 8), battle + Offset(8 * d, -8), blade);
      canvas.drawLine(battle + Offset(-5 * d - 3, 3), battle + Offset(-5 * d + 3, 9), line);
    }
  }

  /// The Egyptian walls': an eye in one band, a cat sitting in one row
  /// among the flowers, and a pyramid low in a corner.
  void _lotusEggs(Canvas canvas, Size s, {required double band, required double row}) {
    final line = _line(1.1, 0.85);
    final fill = _fill(0.6);
    // The eye, in the second border band, a third of the way along.
    final eye = Offset(s.width * 0.34, row + band / 2);
    canvas.drawPath(
        Path()
          ..moveTo(eye.dx - 9, eye.dy)
          ..quadraticBezierTo(eye.dx, eye.dy - 8, eye.dx + 9, eye.dy)
          ..quadraticBezierTo(eye.dx, eye.dy + 6, eye.dx - 9, eye.dy),
        line);
    canvas.drawCircle(eye, 2.4, fill);
    canvas.drawLine(eye + const Offset(-2, 4), eye + const Offset(-4, 9), line);
    canvas.drawPath(
        Path()
          ..moveTo(eye.dx + 2, eye.dy + 4)
          ..quadraticBezierTo(eye.dx + 3, eye.dy + 9, eye.dx + 8, eye.dy + 8),
        line);

    // A cat, sitting at the foot of the third row.
    final cat = Offset(s.width * 0.72, row * 3 - 9);
    canvas.drawPath(
        Path()
          ..moveTo(cat.dx - 5, cat.dy)
          ..quadraticBezierTo(cat.dx - 7, cat.dy - 10, cat.dx - 2, cat.dy - 13)
          ..lineTo(cat.dx - 3, cat.dy - 18)
          ..lineTo(cat.dx, cat.dy - 15)
          ..lineTo(cat.dx + 3, cat.dy - 18)
          ..lineTo(cat.dx + 2, cat.dy - 13)
          ..quadraticBezierTo(cat.dx + 7, cat.dy - 10, cat.dx + 5, cat.dy)
          ..close(),
        fill);
    canvas.drawPath(
        Path()
          ..moveTo(cat.dx + 5, cat.dy - 1)
          ..quadraticBezierTo(cat.dx + 11, cat.dy - 2, cat.dx + 10, cat.dy - 8),
        line);

    // A pyramid, low in the left corner.
    final py = Offset(s.width * 0.06, s.height - 10);
    canvas.drawPath(
        Path()
          ..moveTo(py.dx - 11, py.dy)
          ..lineTo(py.dx, py.dy - 13)
          ..lineTo(py.dx + 11, py.dy)
          ..close(),
        line);
    canvas.drawLine(py + const Offset(0, -13), py + const Offset(3, 0), _line(0.7, 0.6));
  }
}
