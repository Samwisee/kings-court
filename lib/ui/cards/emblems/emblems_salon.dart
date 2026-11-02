// Not under the Apache licence: the rooms' art, all rights reserved (LICENSE-ROOMS.md).
part of 'set_emblems.dart';

const _velvetRed = Color(0xFFA81E44);
const _plum = Color(0xFF4A1E40);

/// Velvet's: an opera mask for the Joker, a rose for the Jack, a fan for
/// the Queen, and a velvet crown for the King.
void _opera(_Pen pen, int rank) {
  switch (rank) {
    case 1:
      // A masquerade mask on its stick, ribbons from its sides.
      pen.gild(_rect(70, 50, 75, 94, 2));
      final mask = Path()
        ..moveTo(10, 38)
        ..quadraticBezierTo(30, 22, 50, 34)
        ..quadraticBezierTo(70, 22, 90, 38)
        ..quadraticBezierTo(88, 58, 70, 62)
        ..quadraticBezierTo(56, 62, 50, 52)
        ..quadraticBezierTo(44, 62, 30, 62)
        ..quadraticBezierTo(12, 58, 10, 38)
        ..close();
      pen.gild(mask);
      for (final x in const [32.0, 68.0]) {
        final eye = Path()
          ..moveTo(x - 10, 44)
          ..quadraticBezierTo(x, 34, x + 10, 44)
          ..quadraticBezierTo(x, 52, x - 10, 44)
          ..close();
        pen.fill(eye, pen.cloth);
      }
      pen.fill(
          Path()
            ..moveTo(10, 38)
            ..quadraticBezierTo(4, 52, 12, 70)
            ..quadraticBezierTo(10, 52, 16, 44)
            ..close(),
          _velvetRed);
      for (final (x, y) in const [(22.0, 30.0), (50.0, 32.0), (78.0, 30.0)]) {
        pen.gem(Offset(x, y), 3, _velvetRed);
      }
    case 2:
      // A rose in bloom on its stem.
      pen.bar(Path()
        ..moveTo(50, 50)
        ..quadraticBezierTo(46, 72, 52, 94), 4);
      for (final s in const [-1.0, 1.0]) {
        pen.gild(Path()
          ..moveTo(50, 70)
          ..quadraticBezierTo(50 + s * 14, 58, 50 + s * 26, 64)
          ..quadraticBezierTo(50 + s * 14, 76, 50, 70)
          ..close());
      }
      pen.fill(_circle(const Offset(50, 34), 22), _velvetRed);
      pen.shade(
          Path()
            ..moveTo(30, 34)
            ..quadraticBezierTo(50, 66, 70, 34)
            ..quadraticBezierTo(50, 50, 30, 34)
            ..close(),
          const Color(0xFF8A1236));
      for (final (r, a0) in const [(16.0, 3.6), (11.0, 0.6), (6.5, 3.9)]) {
        pen.ink(Path()..addArc(Rect.fromCircle(center: const Offset(50, 32), radius: r), a0, 4.2), const Color(0xFF4A0A1E), 1);
      }
    case 3:
      // An open fan, its ribs gilt, its leaf in velvet, a tassel at the
      // pivot.
      const pivot = Offset(50, 80);
      const n = 9;
      for (var k = 0; k < n; k++) {
        final a0 = math.pi * (1.1 + 0.8 * k / n), a1 = math.pi * (1.1 + 0.8 * (k + 1) / n);
        final leaf = Path()
          ..moveTo(pivot.dx, pivot.dy)
          ..lineTo(pivot.dx + math.cos(a0) * 52, pivot.dy + math.sin(a0) * 52)
          ..arcTo(Rect.fromCircle(center: pivot, radius: 52), a0, a1 - a0, false)
          ..close();
        if (k.isEven) {
          pen.gild(leaf);
        } else {
          pen.fill(leaf, _plum);
        }
      }
      pen.ink(Path()..addArc(Rect.fromCircle(center: pivot, radius: 36), math.pi * 1.1, math.pi * 0.8), null, 1);
      pen.gem(pivot, 6, _velvetRed);
      pen.bar(Path()
        ..moveTo(50, 86)
        ..lineTo(50, 96), 3);
    default:
      // A crown over a velvet cap, an ermine band, an orb and cross on
      // top.
      pen.fill(_oval(const Offset(50, 48), 56, 44), _velvetRed);
      for (final s in const [-1.0, 1.0]) {
        pen.bar(Path()
          ..moveTo(50 + s * 30, 64)
          ..quadraticBezierTo(50 + s * 26, 26, 50, 24), 5);
      }
      pen.gild(_circle(const Offset(50, 18), 7));
      pen.bar(Path()
        ..moveTo(50, 11)
        ..lineTo(50, 1)
        ..moveTo(45, 5)
        ..lineTo(55, 5), 3);
      pen.fill(_rect(16, 62, 84, 82, 4), const Color(0xFFF6F1E4));
      for (final x in const [24.0, 37.0, 50.0, 63.0, 76.0]) {
        pen.canvas.drawPath(
            _poly([Offset(x, 66), Offset(x + 2.5, 72), Offset(x, 78), Offset(x - 2.5, 72)]), Paint()..color = const Color(0xFF1A1A1A));
      }
      pen.gild(_rect(14, 82, 86, 90, 2));
  }
}

/// The Marble hall's: a lyre for the Joker, a column for the Jack, a
/// laurel wreath for the Queen, and a mural crown for the King.
void _classical(_Pen pen, int rank) {
  const marble = Color(0xFFF4F2EE);
  switch (rank) {
    case 1:
      // A lyre: its horns, the yoke across them, its strings and sound box.
      for (final s in const [-1.0, 1.0]) {
        pen.bar(Path()
          ..moveTo(50 + s * 12, 78)
          ..quadraticBezierTo(50 + s * 38, 60, 50 + s * 24, 34)
          ..quadraticBezierTo(50 + s * 14, 18, 50 + s * 26, 10), 6);
      }
      pen.gild(_rect(24, 24, 76, 30, 2));
      for (final x in const [42.0, 47.0, 53.0, 58.0]) {
        pen.ink(Path()
          ..moveTo(x, 28)
          ..lineTo(x, 76), null, 0.8);
      }
      pen.gild(_rect(30, 74, 70, 90, 6));
      pen.ink(_oval(const Offset(50, 82), 18, 6), null, 1);
    case 2:
      // An Ionic column: its scrolled capital, fluted shaft and base.
      pen.fill(_rect(38, 28, 62, 82), marble);
      for (final x in const [43.0, 48.0, 52.0, 57.0]) {
        pen.ink(Path()
          ..moveTo(x, 30)
          ..lineTo(x, 80), const Color(0xFFB4AA94), 0.8);
      }
      pen.gild(_rect(26, 18, 74, 28, 2));
      for (final x in const [28.0, 72.0]) {
        pen.gild(_circle(Offset(x, 26), 9));
        pen.ink(Path()..addArc(Rect.fromCircle(center: Offset(x, 26), radius: 5), 0, 5), null, 1);
        pen.canvas.drawCircle(Offset(x, 26), 1.6, Paint()..color = pen.dark);
      }
      pen.gild(_rect(22, 10, 78, 18, 2));
      pen.gild(_rect(32, 82, 68, 88, 2));
      pen.gild(_rect(26, 88, 74, 96, 2));
    case 3:
      // A laurel wreath, tied with a ribbon.
      for (final s in const [-1.0, 1.0]) {
        pen.bar(Path()..addArc(Rect.fromCircle(center: const Offset(50, 52), radius: 34), math.pi / 2 + s * 0.15, s * 2.5), 2.5);
        for (var k = 0; k < 7; k++) {
          final a = math.pi / 2 + s * (0.35 + k * 0.33);
          final at = const Offset(50, 52) + Offset(math.cos(a), math.sin(a)) * 34;
          pen.canvas.save();
          pen.canvas.translate(at.dx, at.dy);
          pen.canvas.rotate(a + (s > 0 ? 0.6 : -0.6));
          pen.gild(_oval(Offset(0, s * 7), 7, 15));
          pen.canvas.restore();
        }
      }
      pen.fill(
          Path()
            ..moveTo(50, 84)
            ..lineTo(38, 98)
            ..lineTo(44, 98)
            ..lineTo(50, 90)
            ..lineTo(56, 98)
            ..lineTo(62, 98)
            ..close(),
          const Color(0xFF7A4A3A));
      pen.gem(const Offset(50, 85), 4, const Color(0xFF7A4A3A));
    default:
      // A mural crown: a city's wall, its towers battlemented, gates cut
      // through it.
      final wall = Path()..moveTo(14, 86);
      wall.lineTo(14, 40);
      for (var k = 0; k < 6; k++) {
        final x = 14 + k * 12.0;
        wall
          ..lineTo(x, 30)
          ..lineTo(x + 6, 30)
          ..lineTo(x + 6, 40)
          ..lineTo(x + 12, 40);
      }
      wall
        ..lineTo(86, 30)
        ..lineTo(86, 86)
        ..close();
      pen.gild(wall);
      for (final x in const [30.0, 50.0, 70.0]) {
        pen.fill(
            Path()
              ..moveTo(x - 5, 80)
              ..lineTo(x - 5, 62)
              ..arcToPoint(Offset(x + 5, 62), radius: const Radius.circular(5))
              ..lineTo(x + 5, 80)
              ..close(),
            pen.cloth);
      }
      pen.ink(Path()
        ..moveTo(14, 52)
        ..lineTo(86, 52), null, 0.8);
      pen.gild(_rect(10, 84, 90, 92, 2));
  }
}

/// The Ballroom's: a champagne coupe for the Joker, a top hat for the
/// Jack, a deco fan for the Queen, and a stepped crown for the King.
void _jazz(_Pen pen, int rank) {
  switch (rank) {
    case 1:
      // A coupe of champagne, bubbles rising from it.
      final bowl = Path()
        ..moveTo(18, 30)
        ..lineTo(82, 30)
        ..quadraticBezierTo(80, 52, 50, 54)
        ..quadraticBezierTo(20, 52, 18, 30)
        ..close();
      pen.gild(bowl);
      pen.fill(_oval(const Offset(50, 31), 62, 8), const Color(0xFFF9E8B0));
      pen.gild(_rect(47, 52, 53, 84));
      pen.gild(_oval(const Offset(50, 86), 40, 10));
      for (final (c, r) in const [(Offset(40, 18), 3.0), (Offset(56, 12), 2.4), (Offset(48, 4), 2.0), (Offset(64, 22), 2.0)]) {
        pen.gild(_circle(c, r));
      }
    case 2:
      // A top hat, banded.
      final crown = Path()
        ..moveTo(32, 64)
        ..lineTo(34, 14)
        ..quadraticBezierTo(50, 10, 66, 14)
        ..lineTo(68, 64)
        ..close();
      pen.fill(crown, const Color(0xFF1C1C1E));
      pen.ink(Path()
        ..moveTo(38, 18)
        ..lineTo(37, 50), const Color(0x66FFFFFF), 1.2);
      pen.gild(_rect(32, 50, 68, 60));
      pen.gild(Path()
        ..moveTo(10, 66)
        ..quadraticBezierTo(50, 58, 90, 66)
        ..quadraticBezierTo(92, 74, 84, 74)
        ..quadraticBezierTo(50, 68, 16, 74)
        ..quadraticBezierTo(8, 74, 10, 66)
        ..close());
      pen.gem(const Offset(60, 55), 3, const Color(0xFFB8243A));
    case 3:
      // A deco fan: stepped rings and rays out from a jewel.
      const pivot = Offset(50, 82);
      pen.gild(Path()
        ..moveTo(pivot.dx, pivot.dy)
        ..arcTo(Rect.fromCircle(center: pivot, radius: 46), math.pi, math.pi, false)
        ..close());
      for (final r in const [36.0, 26.0]) {
        pen.ink(Path()..addArc(Rect.fromCircle(center: pivot, radius: r), math.pi, math.pi), null, 1);
      }
      for (var k = 1; k < 8; k++) {
        final a = math.pi + k * math.pi / 8;
        pen.ink(Path()
          ..moveTo(pivot.dx + math.cos(a) * 14, pivot.dy + math.sin(a) * 14)
          ..lineTo(pivot.dx + math.cos(a) * 46, pivot.dy + math.sin(a) * 46), null, 0.9);
      }
      pen.fill(Path()..addArc(Rect.fromCircle(center: pivot, radius: 14), math.pi, math.pi), const Color(0xFF1C1C1E));
      // A plume rising from it.
      pen.gild(Path()
        ..moveTo(60, 40)
        ..quadraticBezierTo(80, 18, 74, 2)
        ..quadraticBezierTo(70, 22, 54, 38)
        ..close());
      pen.gem(pivot + const Offset(0, -4), 5, const Color(0xFF1F8A70));
    default:
      // A stepped crown, ziggurat-like, rays on its face.
      final steps = Path()
        ..moveTo(14, 84)
        ..lineTo(14, 60)
        ..lineTo(24, 60)
        ..lineTo(24, 46)
        ..lineTo(34, 46)
        ..lineTo(34, 32)
        ..lineTo(44, 32)
        ..lineTo(44, 16)
        ..lineTo(56, 16)
        ..lineTo(56, 32)
        ..lineTo(66, 32)
        ..lineTo(66, 46)
        ..lineTo(76, 46)
        ..lineTo(76, 60)
        ..lineTo(86, 60)
        ..lineTo(86, 84)
        ..close();
      pen.gild(steps);
      for (var k = -3; k <= 3; k++) {
        pen.ink(Path()
          ..moveTo(50, 84)
          ..lineTo(50 + k * 11.0, 62 - (k.abs() == 3 ? 0 : 16 - k.abs() * 6.0)), null, 0.8);
      }
      pen.fill(_rect(12, 74, 88, 86, 2), const Color(0xFF1C1C1E));
      for (final (x, c) in const [(30.0, Color(0xFF1F8A70)), (50.0, Color(0xFFB8243A)), (70.0, Color(0xFF1F8A70))]) {
        pen.gem(Offset(x, 80), 3.6, c);
      }
      pen.pearl(const Offset(50, 10), 4);
  }
}

/// The Salon's: a palette for the Joker, a pen's nib for the Jack, a
/// perfume bottle for the Queen, and a drawn crown for the King. In
/// enamel white, lined in black.
void _atelier(_Pen pen, int rank) {
  switch (rank) {
    case 1:
      // A painter's palette, its paints, a brush across it.
      final palette = Path.combine(
          PathOperation.difference,
          Path()
            ..moveTo(14, 54)
            ..quadraticBezierTo(10, 18, 52, 18)
            ..quadraticBezierTo(92, 18, 88, 54)
            ..quadraticBezierTo(86, 84, 56, 82)
            ..quadraticBezierTo(48, 70, 40, 82)
            ..quadraticBezierTo(16, 84, 14, 54)
            ..close(),
          _oval(const Offset(36, 62), 12, 10));
      pen.gild(palette);
      for (final (c, colour) in const [
        (Offset(30, 38), Color(0xFFD0342C)),
        (Offset(48, 30), Color(0xFFF2C230)),
        (Offset(66, 32), Color(0xFF2456C8)),
        (Offset(76, 50), Color(0xFF1E8A55)),
      ]) {
        pen.fill(_circle(c, 6.5), colour);
      }
      pen.bar(Path()
        ..moveTo(52, 92)
        ..lineTo(84, 64), 3.5);
      pen.fill(_poly(const [Offset(82, 62), Offset(92, 52), Offset(88, 66)]), const Color(0xFF1A1A1A));
    case 2:
      // A pen's nib: its shoulders, the slit down to the point, the
      // breather hole.
      final nib = Path()
        ..moveTo(50, 94)
        ..quadraticBezierTo(26, 56, 30, 30)
        ..lineTo(36, 10)
        ..lineTo(64, 10)
        ..lineTo(70, 30)
        ..quadraticBezierTo(74, 56, 50, 94)
        ..close();
      pen.gild(nib);
      pen.fill(_rect(32, 8, 68, 22, 2), const Color(0xFF1A1A1A));
      pen.canvas.drawCircle(const Offset(50, 52), 4.5, Paint()..color = pen.dark);
      pen.ink(Path()
        ..moveTo(50, 56)
        ..lineTo(50, 92), null, 1.2);
      pen.ink(Path()
        ..moveTo(38, 36)
        ..quadraticBezierTo(50, 30, 62, 36), null, 0.8);
    case 3:
      // A perfume bottle, faceted, its stopper a gem.
      final body = _poly(const [
        Offset(26, 46), Offset(36, 36), Offset(64, 36), Offset(74, 46), Offset(74, 82), Offset(66, 90), Offset(34, 90), Offset(26, 82)
      ]);
      pen.fill(body, const Color(0xFFE8A8B8));
      pen.canvas.drawPath(_poly(const [Offset(32, 48), Offset(40, 42), Offset(44, 42), Offset(36, 50), Offset(36, 80), Offset(32, 80)]),
          Paint()..color = Colors.white.withValues(alpha: 0.55));
      pen.gild(_rect(42, 26, 58, 37, 2));
      pen.gild(_poly(const [Offset(50, 4), Offset(62, 16), Offset(50, 28), Offset(38, 16)]));
      pen.gild(_rect(38, 58, 62, 72, 2));
      pen.ink(Path()
        ..moveTo(42, 65)
        ..lineTo(58, 65), null, 0.8);
    default:
      // A crown drawn in a few strokes: three points, a dot on each.
      pen.gild(_crown(18, 82, 66, 84, 26, n: 3, lift: 10));
      pen.ink(Path()
        ..moveTo(18, 72)
        ..lineTo(82, 72), null, 1);
      for (final (x, y) in const [(18.0, 26.0), (50.0, 16.0), (82.0, 26.0)]) {
        pen.fill(_circle(Offset(x, y - 2), 5), const Color(0xFF1A1A1A));
      }
      pen.fill(_circle(const Offset(50, 78), 3.5), const Color(0xFFD0342C));
  }
}
