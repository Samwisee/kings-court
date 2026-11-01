part of 'set_emblems.dart';

const _lapis = Color(0xFF1C3A8C);
const _turquoise = Color(0xFF2EA8A0);
const _carnelian = Color(0xFFB5352A);

/// The Egyptian room's: the eye for the Joker, the ankh for the Jack, a
/// lotus for the Queen, and the nemes headdress for the King.
void _pharaoh(_Pen pen, int rank) {
  switch (rank) {
    case 1:
      // The eye of Horus: the brow, the eye lined in kohl, the markings
      // under it.
      pen.bar(Path()
        ..moveTo(12, 30)
        ..quadraticBezierTo(50, 14, 86, 28), 6);
      final eye = Path()
        ..moveTo(10, 48)
        ..quadraticBezierTo(50, 20, 90, 46)
        ..quadraticBezierTo(50, 70, 10, 48)
        ..close();
      pen.fill(eye, const Color(0xFFF6EEDB));
      pen.fill(_circle(const Offset(50, 46), 13), _lapis);
      pen.canvas.drawCircle(const Offset(50, 46), 5, Paint()..color = const Color(0xFF0A0A0A));
      pen.bar(eye, 3);
      pen.bar(Path()
        ..moveTo(90, 46)
        ..lineTo(98, 48), 3);
      pen.bar(Path()
        ..moveTo(46, 60)
        ..lineTo(42, 84)
        ..quadraticBezierTo(36, 94, 28, 88), 4);
      pen.bar(Path()
        ..moveTo(58, 60)
        ..quadraticBezierTo(74, 68, 72, 82)
        ..quadraticBezierTo(70, 92, 62, 86)
        ..quadraticBezierTo(60, 80, 66, 80), 4);
    case 2:
      // The ankh.
      final loop = Path.combine(PathOperation.difference, _oval(const Offset(50, 26), 40, 46), _oval(const Offset(50, 26), 20, 28));
      pen.gild(loop);
      pen.gild(_rect(18, 46, 82, 58, 2));
      pen.gild(Path()
        ..moveTo(42, 58)
        ..lineTo(58, 58)
        ..lineTo(62, 96)
        ..lineTo(38, 96)
        ..close());
      pen.gem(const Offset(50, 52), 4, _carnelian);
      for (final x in const [26.0, 74.0]) {
        pen.gem(Offset(x, 52), 3, _turquoise);
      }
    case 3:
      // A lotus: its petals fanning from the water, gold and turquoise.
      for (final (a, h, c) in const [
        (-0.95, 40.0, _turquoise),
        (0.95, 40.0, _turquoise),
        (-0.5, 52.0, Color(0x00000000)),
        (0.5, 52.0, Color(0x00000000)),
        (0.0, 64.0, _lapis),
      ]) {
        pen.canvas.save();
        pen.canvas.translate(50, 82);
        pen.canvas.rotate(a);
        final petal = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-14, -h * 0.55, 0, -h)
          ..quadraticBezierTo(14, -h * 0.55, 0, 0)
          ..close();
        if (c.a == 0) {
          pen.gild(petal);
        } else {
          pen.fill(petal, c);
          pen.ink(Path()
            ..moveTo(0, -4)
            ..lineTo(0, -h + 8), const Color(0xFFE2B53E), 1);
        }
        pen.canvas.restore();
      }
      pen.gild(Path()
        ..moveTo(26, 80)
        ..quadraticBezierTo(50, 96, 74, 80)
        ..close());
      for (var k = 0; k < 3; k++) {
        pen.ink(Path()
          ..moveTo(22.0 + k * 4, 92.0 + k * 3)
          ..quadraticBezierTo(50, 86.0 + k * 3, 78.0 - k * 4, 92.0 + k * 3), _lapis, 1.2);
      }
    default:
      // The nemes: the headcloth striped gold and lapis, the brow band, the
      // cobra rising from it.
      final cloth = Path()
        ..moveTo(32, 30)
        ..quadraticBezierTo(50, 4, 68, 30)
        ..lineTo(70, 44)
        ..lineTo(88, 88)
        ..lineTo(68, 88)
        ..lineTo(64, 56)
        ..lineTo(36, 56)
        ..lineTo(32, 88)
        ..lineTo(12, 88)
        ..lineTo(30, 44)
        ..close();
      pen.gild(cloth);
      pen.canvas.save();
      pen.canvas.clipPath(cloth);
      for (var y = 22.0; y < 92; y += 8) {
        pen.canvas.drawRect(Rect.fromLTWH(0, y, 100, 3.6), Paint()..color = _lapis);
      }
      pen.canvas.restore();
      pen.edge(cloth, 2);
      pen.fill(
          Path()
            ..moveTo(36, 56)
            ..lineTo(36, 40)
            ..quadraticBezierTo(50, 34, 64, 40)
            ..lineTo(64, 56)
            ..quadraticBezierTo(50, 80, 36, 56)
            ..close(),
          pen.cloth);
      pen.gild(_rect(30, 32, 70, 40, 2));
      // The cobra.
      pen.gild(Path()
        ..moveTo(46, 34)
        ..quadraticBezierTo(42, 18, 50, 14)
        ..quadraticBezierTo(58, 18, 54, 34)
        ..close());
      pen.gem(const Offset(50, 22), 2.6, _carnelian);
  }
}

/// The Galleon's: a parrot for the Joker, an anchor for the Jack, a
/// compass rose for the Queen, and a ship's wheel crowned for the King.
void _pirate(_Pen pen, int rank) {
  switch (rank) {
    case 1:
      // A parrot on its perch.
      pen.bar(Path()
        ..moveTo(18, 82)
        ..lineTo(82, 82), 5);
      pen.fill(
          Path()
            ..moveTo(52, 70)
            ..lineTo(40, 98)
            ..lineTo(50, 98)
            ..lineTo(60, 72)
            ..close(),
          const Color(0xFF2456C8));
      final body = Path()
        ..moveTo(50, 20)
        ..quadraticBezierTo(76, 26, 66, 60)
        ..quadraticBezierTo(60, 80, 48, 78)
        ..quadraticBezierTo(34, 66, 36, 40)
        ..quadraticBezierTo(38, 22, 50, 20)
        ..close();
      pen.fill(body, const Color(0xFFD0342C));
      pen.fill(
          Path()
            ..moveTo(58, 40)
            ..quadraticBezierTo(76, 50, 62, 76)
            ..quadraticBezierTo(52, 62, 58, 40)
            ..close(),
          const Color(0xFF1E8A55));
      pen.fill(
          Path()
            ..moveTo(38, 28)
            ..quadraticBezierTo(24, 28, 26, 42)
            ..quadraticBezierTo(30, 36, 38, 38)
            ..close(),
          const Color(0xFFF2E6C8));
      pen.fill(_circle(const Offset(46, 30), 4.5), const Color(0xFFFFFFFF));
      pen.canvas.drawCircle(const Offset(46, 30), 2, Paint()..color = _ink);
      pen.gild(_rect(42, 78, 50, 84, 2));
    case 2:
      // An anchor, a rope round its shank.
      pen.bar(_circle(const Offset(50, 14), 7), 4);
      pen.bar(Path()
        ..moveTo(50, 21)
        ..lineTo(50, 86), 7);
      pen.bar(Path()
        ..moveTo(30, 30)
        ..lineTo(70, 30), 5);
      pen.bar(Path()
        ..moveTo(16, 60)
        ..quadraticBezierTo(18, 88, 50, 88)
        ..quadraticBezierTo(82, 88, 84, 60), 6);
      for (final s in const [-1.0, 1.0]) {
        pen.gild(_poly([Offset(50 + s * 34, 54), Offset(50 + s * 42, 66), Offset(50 + s * 26, 66)]));
      }
      pen.ink(Path()
        ..moveTo(50, 36)
        ..cubicTo(64, 42, 36, 50, 50, 56)
        ..cubicTo(64, 62, 36, 70, 52, 76), const Color(0xFFEADBB8), 2.4);
    case 3:
      // A compass rose: the cardinal points long and gilt, the others
      // short and dark, a fleur at north.
      pen.ink(_circle(const Offset(50, 54), 30), null, 1.4);
      for (var k = 0; k < 8; k++) {
        final a = -math.pi / 2 + k * math.pi / 4;
        final long = k.isEven;
        final d = Offset(math.cos(a), math.sin(a));
        final side = Offset(-d.dy, d.dx);
        final c = const Offset(50, 54);
        final point = _poly([c + d * (long ? 42 : 26), c + side * 7, c - side * 7]);
        if (long) {
          pen.gild(point);
        } else {
          pen.fill(point, const Color(0xFF6E4A22));
        }
      }
      pen.gem(const Offset(50, 54), 5, const Color(0xFFA8302A));
      pen.gild(_star(const Offset(50, 8), 6, n: 4, inner: 0.4));
    default:
      // A ship's wheel, crowned.
      const c = Offset(50, 62);
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        pen.bar(Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(a) * 34, c.dy + math.sin(a) * 34), 3.5);
      }
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        pen.gild(_circle(c + Offset(math.cos(a), math.sin(a)) * 34, 3.4));
      }
      pen.bar(_circle(c, 24), 5);
      pen.gild(_circle(c, 8));
      pen.gild(_crown(28, 72, 26, 36, 4, lift: 4));
      for (final x in const [36.0, 50.0, 64.0]) {
        pen.gem(Offset(x, 31), 2.4, const Color(0xFFA8302A));
      }
  }
}
