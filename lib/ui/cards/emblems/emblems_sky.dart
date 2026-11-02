// Not under the Apache licence: the rooms' art, all rights reserved (LICENSE-ROOMS.md).
part of 'set_emblems.dart';

/// Midnight's: a comet for the Joker, a crescent moon for the Jack, a
/// tiara of stars for the Queen, and a crown whose points are stars for the
/// King. In silver.
void _starlight(_Pen pen, int rank) {
  switch (rank) {
    case 1:
      // A comet: its tail streaming down to the left, its head a star.
      final tail = Path()
        ..moveTo(60, 26)
        ..quadraticBezierTo(34, 40, 10, 88)
        ..quadraticBezierTo(30, 62, 46, 54)
        ..quadraticBezierTo(26, 76, 22, 92)
        ..quadraticBezierTo(44, 64, 74, 46)
        ..close();
      pen.gild(tail);
      pen.ink(Path()
        ..moveTo(58, 34)
        ..quadraticBezierTo(38, 50, 24, 80));
      pen.gild(_star(const Offset(68, 32), 20, inner: 0.42));
      pen.gem(const Offset(68, 33), 5, const Color(0xFF8FC0FF));
      for (final (c, r) in const [(Offset(86, 66), 4.0), (Offset(30, 18), 3.0), (Offset(84, 12), 3.5)]) {
        pen.gild(_star(c, r * 1.6, n: 4, inner: 0.35));
      }
    case 2:
      // A crescent moon, a star in its arms.
      final moon = Path.combine(PathOperation.difference, _circle(const Offset(46, 52), 36), _circle(const Offset(62, 42), 31));
      pen.gild(moon);
      pen.ink(Path()
        ..addArc(Rect.fromCircle(center: const Offset(46, 52), radius: 30), math.pi * 0.55, math.pi * 0.7));
      pen.gild(_star(const Offset(70, 56), 13, inner: 0.42));
      pen.gild(_star(const Offset(82, 26), 6, n: 4, inner: 0.35));
    case 3:
      // A tiara of stars on a band, pearls along it.
      final band = Path()
        ..moveTo(12, 70)
        ..quadraticBezierTo(50, 50, 88, 70)
        ..lineTo(84, 80)
        ..quadraticBezierTo(50, 62, 16, 80)
        ..close();
      pen.gild(Path()
        ..moveTo(22, 70)
        ..lineTo(30, 46)
        ..lineTo(40, 62)
        ..lineTo(50, 28)
        ..lineTo(60, 62)
        ..lineTo(70, 46)
        ..lineTo(78, 70)
        ..close());
      pen.gild(band);
      pen.gild(_star(const Offset(50, 24), 17, inner: 0.42));
      pen.gild(_star(const Offset(28, 44), 10, inner: 0.42));
      pen.gild(_star(const Offset(72, 44), 10, inner: 0.42));
      for (var k = 0; k < 7; k++) {
        final t = (k + 0.5) / 7;
        final x = 16 + t * 68;
        final y = 74 - 16 * (1 - (2 * t - 1) * (2 * t - 1)) * 0.75;
        pen.pearl(Offset(x, y), 2.6);
      }
      pen.gem(const Offset(50, 25), 4.5, const Color(0xFF8FC0FF));
    default:
      // A crown: its points stars, a crescent set in its band.
      pen.gild(_crown(18, 82, 58, 82, 30, lift: 8));
      pen.gild(_rect(14, 66, 86, 84, 3));
      for (final (x, y, r) in const [(18.0, 28.0, 8.0), (34.0, 26.0, 8.0), (50.0, 16.0, 11.0), (66.0, 26.0, 8.0), (82.0, 28.0, 8.0)]) {
        pen.gild(_star(Offset(x, y), r, inner: 0.42));
      }
      final crescent =
          Path.combine(PathOperation.difference, _circle(const Offset(50, 75), 7.5), _circle(const Offset(54, 72), 6.5));
      pen.fill(_circle(const Offset(50, 75), 8.5), const Color(0xFF141C38));
      pen.canvas.drawPath(crescent, Paint()..color = const Color(0xFFE6EBF5));
      for (final x in const [28.0, 72.0]) {
        pen.gem(Offset(x, 75), 4, const Color(0xFF8FC0FF));
      }
  }
}

/// The Winter palace's: a snowman for the Joker, a skate for the Jack, a
/// snowflake for the Queen, and a crown of icicles for the King. In
/// silver.
void _snow(_Pen pen, int rank) {
  const snow = Color(0xFFF4F8FF);
  switch (rank) {
    case 1:
      // A snowman in a top hat and a red scarf.
      pen.fill(_circle(const Offset(50, 74), 20), snow);
      pen.fill(_circle(const Offset(50, 46), 14), snow);
      pen.fill(_circle(const Offset(50, 28), 11), snow);
      pen.fill(_rect(43, 2, 57, 15, 1), const Color(0xFF1A2E48));
      pen.fill(_rect(37, 14, 63, 18, 1), const Color(0xFF1A2E48));
      pen.fill(_rect(32, 33, 68, 38, 2), const Color(0xFFC0283C));
      pen.fill(_rect(56, 35, 62, 52, 2), const Color(0xFFC0283C));
      pen.fill(_poly(const [Offset(50, 28), Offset(64, 31), Offset(50, 32)]), const Color(0xFFE8822A));
      for (final c in const [Offset(45, 25), Offset(55, 25), Offset(50, 44), Offset(50, 52), Offset(50, 68)]) {
        pen.canvas.drawCircle(c, 1.8, Paint()..color = const Color(0xFF1A2E48));
      }
      pen.ink(Path()
        ..moveTo(36, 46)
        ..lineTo(18, 34)
        ..moveTo(24, 38)
        ..lineTo(20, 30), null, 1.2);
      pen.ink(Path()
        ..moveTo(64, 46)
        ..lineTo(84, 36)
        ..moveTo(78, 39)
        ..lineTo(84, 30), null, 1.2);
    case 2:
      // A skate: the boot laced up, the blade curling at its toe.
      final boot = Path()
        ..moveTo(30, 14)
        ..lineTo(54, 14)
        ..lineTo(56, 46)
        ..quadraticBezierTo(80, 50, 84, 62)
        ..lineTo(84, 70)
        ..lineTo(26, 70)
        ..quadraticBezierTo(24, 40, 30, 14)
        ..close();
      pen.fill(boot, snow);
      pen.fill(_rect(26, 64, 84, 71, 2), const Color(0xFF5C82AA));
      for (var y = 22.0; y <= 50; y += 7) {
        pen.ink(Path()
          ..moveTo(44, y)
          ..lineTo(56, y + 5), null, 0.9);
      }
      pen.gild(Path()
        ..moveTo(22, 82)
        ..lineTo(84, 82)
        ..quadraticBezierTo(96, 82, 92, 72)
        ..quadraticBezierTo(90, 88, 84, 88)
        ..lineTo(22, 88)
        ..close());
      pen.gild(_rect(34, 70, 38, 83));
      pen.gild(_rect(70, 70, 74, 83));
    case 3:
      // A snowflake: six arms, each barbed twice, a hexagon at its heart.
      for (var k = 0; k < 6; k++) {
        final a = -math.pi / 2 + k * math.pi / 3;
        final d = Offset(math.cos(a), math.sin(a));
        const c = Offset(50, 50);
        final arm = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo((c + d * 42).dx, (c + d * 42).dy);
        for (final (at, len) in const [(0.45, 13.0), (0.72, 9.0)]) {
          final m = c + d * 42 * at;
          for (final t in [-0.75, 0.75]) {
            final b = Offset(math.cos(a + t), math.sin(a + t));
            arm
              ..moveTo(m.dx, m.dy)
              ..lineTo((m + b * len).dx, (m + b * len).dy);
          }
        }
        pen.bar(arm, 5);
      }
      pen.gild(_poly([
        for (var k = 0; k < 6; k++) const Offset(50, 50) + Offset(math.cos(k * math.pi / 3), math.sin(k * math.pi / 3)) * 11
      ]));
      pen.gem(const Offset(50, 50), 5, const Color(0xFF8FC0FF));
    default:
      // A crown of icicles over a band set with ice.
      final crown = Path()..moveTo(16, 66);
      const tips = [(22.0, 30.0), (36.0, 22.0), (50.0, 8.0), (64.0, 22.0), (78.0, 30.0)];
      var x = 16.0;
      for (final (tx, ty) in tips) {
        crown
          ..lineTo(tx - 6, 58)
          ..lineTo(tx, ty)
          ..lineTo(tx + 6, 58);
        x = tx + 7;
      }
      crown
        ..lineTo(x, 58)
        ..lineTo(84, 66)
        ..close();
      pen.gild(crown);
      pen.gild(_rect(14, 62, 86, 80, 3));
      // Icicles hanging from the band.
      for (final (ix, len) in const [(24.0, 10.0), (38.0, 14.0), (50.0, 9.0), (62.0, 14.0), (76.0, 10.0)]) {
        pen.fill(_poly([Offset(ix - 3, 80), Offset(ix + 3, 80), Offset(ix, 80 + len)]), snow);
      }
      for (final gx in const [26.0, 50.0, 74.0]) {
        pen.gem(Offset(gx, 71), 4.5, const Color(0xFF8FC0FF));
      }
      pen.pearl(const Offset(50, 8), 3.5);
  }
}
