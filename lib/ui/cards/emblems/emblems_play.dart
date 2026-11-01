part of 'set_emblems.dart';

const _feltRed = Color(0xFFC8102E);
const _ink = Color(0xFF141414);

/// The Casino's: a pair of dice for the Joker, a chip for the Jack, a
/// roulette wheel for the Queen, and a crown set with the four suits for
/// the King.
void _royale(_Pen pen, int rank) {
  switch (rank) {
    case 1:
      // A pair of dice, tumbling: a five and a three.
      void die(Offset c, double angle, List<Offset> pips) {
        pen.canvas.save();
        pen.canvas.translate(c.dx, c.dy);
        pen.canvas.rotate(angle);
        pen.fill(_rect(-20, -20, 20, 20, 6), const Color(0xFFFAF7F0));
        for (final p in pips) {
          pen.canvas.drawCircle(p * 10, 4, Paint()..color = _feltRed);
        }
        pen.canvas.restore();
      }

      die(const Offset(36, 62), -0.28,
          const [Offset(-1, -1), Offset(1, -1), Offset.zero, Offset(-1, 1), Offset(1, 1)]);
      die(const Offset(66, 36), 0.22, const [Offset(-1, -1), Offset.zero, Offset(1, 1)]);
    case 2:
      // A chip: red, striped round its edge, a spade at its heart.
      pen.fill(_circle(const Offset(50, 50), 40), _feltRed);
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        pen.canvas.drawPath(
            Path()..addArc(Rect.fromCircle(center: const Offset(50, 50), radius: 34), a - 0.16, 0.32),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 11
              ..color = const Color(0xFFFAF7F0));
      }
      pen.gild(_circle(const Offset(50, 50), 24));
      pen.ink(_circle(const Offset(50, 50), 20), null, 0.8);
      pen.fill(_spade(const Offset(50, 50), 26), _ink);
    case 3:
      // A roulette wheel: its pockets red and black, the zero green, the
      // turret in the middle.
      pen.gild(_circle(const Offset(50, 50), 44));
      const n = 18;
      for (var k = 0; k < n; k++) {
        final a0 = k * 2 * math.pi / n;
        final pocket = Path()
          ..arcTo(Rect.fromCircle(center: const Offset(50, 50), radius: 36), a0, 2 * math.pi / n, true)
          ..arcTo(Rect.fromCircle(center: const Offset(50, 50), radius: 24), a0 + 2 * math.pi / n, -2 * math.pi / n, false)
          ..close();
        pen.canvas.drawPath(
            pocket,
            Paint()
              ..color = k == 0
                  ? const Color(0xFF13734A)
                  : k.isOdd
                      ? _feltRed
                      : _ink);
      }
      pen.ink(_circle(const Offset(50, 50), 36), null, 1);
      pen.gild(_circle(const Offset(50, 50), 24));
      for (var k = 0; k < 4; k++) {
        final a = k * math.pi / 2 + math.pi / 4;
        pen.bar(Path()
          ..moveTo(50, 50)
          ..lineTo(50 + math.cos(a) * 18, 50 + math.sin(a) * 18), 3);
      }
      pen.gild(_circle(const Offset(50, 50), 7));
      pen.pearl(const Offset(50, 17), 3.5);
    default:
      // A crown, the four suits set in its band.
      pen.gild(_crown(16, 84, 50, 84, 16, lift: 8));
      pen.fill(_rect(14, 58, 86, 84, 4), const Color(0xFFFAF7F0));
      pen.fill(_heart(const Offset(25, 72), 13), _feltRed);
      pen.fill(_spade(const Offset(42, 71), 13), _ink);
      pen.fill(_diamond(const Offset(58, 71), 13), _feltRed);
      pen.fill(_club(const Offset(75, 71), 13), _ink);
      for (final x in const [16.0, 33.0, 67.0, 84.0]) {
        pen.pearl(Offset(x, x == 16 || x == 84 ? 16 : 18), 3);
      }
      pen.gem(const Offset(50, 10), 5, _feltRed);
  }
}

const _italianRed = Color(0xFFC0242E);
const _italianBlue = Color(0xFF1F5AA8);
const _italianGreen = Color(0xFF2A7A3A);

/// Scopa's, from the Neapolitan deck: a cup for the Joker, a club for the
/// Jack, a coin for the Queen, and its crown for the King.
void _napoli(_Pen pen, int rank) {
  switch (rank) {
    case 1:
      // Coppe: a goblet, banded in red and blue.
      final cup = Path()
        ..moveTo(18, 12)
        ..lineTo(82, 12)
        ..quadraticBezierTo(82, 50, 56, 56)
        ..lineTo(44, 56)
        ..quadraticBezierTo(18, 50, 18, 12)
        ..close();
      pen.gild(cup);
      pen.fill(_rect(20, 20, 80, 28), _italianRed);
      pen.fill(_rect(24, 34, 76, 40), _italianBlue);
      pen.gild(_rect(46, 56, 54, 80));
      pen.gild(_circle(const Offset(50, 66), 6));
      pen.gild(Path()
        ..moveTo(26, 92)
        ..quadraticBezierTo(50, 74, 74, 92)
        ..close());
    case 2:
      // Bastoni: a knotted club, leaves sprouting from it.
      final club = Path()
        ..moveTo(44, 94)
        ..lineTo(40, 30)
        ..quadraticBezierTo(38, 8, 52, 6)
        ..quadraticBezierTo(66, 8, 62, 30)
        ..lineTo(56, 94)
        ..close();
      pen.shade(club, const Color(0xFF9C6A34));
      for (final (x, y, s) in const [(42.0, 24.0, -1.0), (60.0, 42.0, 1.0), (44.0, 62.0, -1.0), (57.0, 78.0, 1.0)]) {
        pen.fill(_oval(Offset(x, y), 7, 6), const Color(0xFF7A4E22));
        pen.fill(
            Path()
              ..moveTo(x, y)
              ..quadraticBezierTo(x + s * 14, y - 12, x + s * 24, y - 6)
              ..quadraticBezierTo(x + s * 12, y + 2, x, y)
              ..close(),
            _italianGreen);
      }
      pen.gild(_rect(41, 86, 59, 94, 2));
    case 3:
      // Denari: a coin like a sun, a rose of red at its heart.
      for (var k = 0; k < 16; k++) {
        final a = k * math.pi / 8;
        final d = Offset(math.cos(a), math.sin(a));
        final side = Offset(-d.dy, d.dx);
        pen.gild(_poly([
          const Offset(50, 50) + d * 46,
          const Offset(50, 50) + d * 30 + side * 6,
          const Offset(50, 50) + d * 30 - side * 6,
        ]));
      }
      pen.gild(_circle(const Offset(50, 50), 32));
      pen.ink(_circle(const Offset(50, 50), 26), null, 1);
      pen.fill(_circle(const Offset(50, 50), 16), _italianBlue);
      for (var k = 0; k < 6; k++) {
        final a = k * math.pi / 3;
        pen.fill(_circle(Offset(50 + math.cos(a) * 8, 50 + math.sin(a) * 8), 5), _italianRed);
      }
      pen.gild(_circle(const Offset(50, 50), 4.5));
    default:
      // The crown: five points with fleurs, red and green stones.
      pen.gild(_crown(16, 84, 56, 82, 24, lift: 6));
      for (final (x, y) in const [(16.0, 24.0), (33.0, 24.0), (50.0, 18.0), (67.0, 24.0), (84.0, 24.0)]) {
        pen.gild(_circle(Offset(x, y - 4), 5));
      }
      pen.gild(_rect(12, 62, 88, 84, 3));
      for (final (x, c) in const [
        (22.0, _italianGreen),
        (36.0, _italianRed),
        (50.0, _italianBlue),
        (64.0, _italianRed),
        (78.0, _italianGreen),
      ]) {
        pen.gem(Offset(x, 73), 4.5, c);
      }
  }
}
