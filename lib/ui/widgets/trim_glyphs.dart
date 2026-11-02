/// Each room's menu glyph (skin/trim.dart), drawn in a square: three bars
/// at court, a ship's wheel aboard the galleon, a scarab in Egypt, an
/// abacus in the counting house. Plain strokes and fills, no blurs.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../skin/trim.dart';

/// Draws [trim]'s menu glyph in [s] in [c], cutting into it with [back]
/// where it needs a gap. Court's own (three bars tipped with diamonds) is
/// drawn by the menu itself.
void paintMenuGlyph(Canvas canvas, Size size, Trim trim, Color c, Color back) {
  final s = size.width;
  final w = s * 0.09;
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;
  final thin = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.6
    ..strokeCap = StrokeCap.round
    ..color = c;
  final fill = Paint()..color = c;
  final gap = Paint()..color = back;
  Offset p(double x, double y) => Offset(s * x, s * y);
  void bars({double left = 0.18, double right = 0.82, List<double> ys = const [0.28, 0.5, 0.72]}) {
    for (final y in ys) {
      canvas.drawLine(p(left, y), p(right, y), line);
    }
  }

  switch (trim) {
    case Trim.court:
    case Trim.plain:
      bars();
    case Trim.lacquer:
      // A crest: three bars in a ring.
      canvas.drawCircle(p(0.5, 0.5), s * 0.4, thin);
      bars(left: 0.3, right: 0.7, ys: const [0.36, 0.5, 0.64]);
    case Trim.garden:
      // Three stems, each with a leaf.
      bars(right: 0.66);
      for (final y in [0.28, 0.5, 0.72]) {
        canvas.save();
        canvas.translate(s * 0.76, s * y);
        canvas.rotate(-0.5);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.2, height: s * 0.1), fill);
        canvas.restore();
      }
    case Trim.midnight:
      // A crescent moon beside three bars.
      canvas.drawCircle(p(0.24, 0.5), s * 0.17, fill);
      canvas.drawCircle(p(0.31, 0.44), s * 0.15, gap);
      bars(left: 0.48, right: 0.86);
    case Trim.harbour:
      // Three waves.
      for (final y in [0.28, 0.5, 0.72]) {
        final path = Path()..moveTo(s * 0.14, s * y);
        for (var i = 0; i < 3; i++) {
          final x = 0.14 + i * 0.24;
          path.quadraticBezierTo(s * (x + 0.06), s * (y - 0.08), s * (x + 0.12), s * y);
          path.quadraticBezierTo(s * (x + 0.18), s * (y + 0.08), s * (x + 0.24), s * y);
        }
        canvas.drawPath(path, thin..strokeWidth = w * 0.85);
      }
    case Trim.velvet:
      // A theatre's curtains, drawn back.
      canvas.drawLine(p(0.12, 0.16), p(0.88, 0.16), line);
      for (final side in [-1.0, 1.0]) {
        final x0 = 0.5 + side * 0.36, x1 = 0.5 + side * 0.08;
        final drape = Path()
          ..moveTo(s * x0, s * 0.2)
          ..lineTo(s * x1, s * 0.2)
          ..quadraticBezierTo(s * (x1 + side * 0.04), s * 0.5, s * (x0 - side * 0.06), s * 0.58)
          ..quadraticBezierTo(s * (x0 - side * 0.02), s * 0.72, s * (x0 + side * 0.02), s * 0.86)
          ..lineTo(s * x0, s * 0.86)
          ..close();
        canvas.drawPath(drape, fill);
      }
    case Trim.counting:
      // An abacus.
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(s * 0.12, s * 0.16, s * 0.88, s * 0.84), Radius.circular(s * 0.05)), thin);
      for (final (y, beads) in [(0.32, [0.3, 0.42]), (0.5, [0.58, 0.7]), (0.68, [0.3, 0.7])]) {
        canvas.drawLine(p(0.16, y), p(0.84, y), thin..strokeWidth = w * 0.4);
        for (final x in beads) {
          canvas.drawOval(Rect.fromCenter(center: p(x, y), width: s * 0.12, height: s * 0.13), fill);
        }
      }
    case Trim.library:
      // Three books, stacked.
      for (final (y, l, r) in [(0.22, 0.24, 0.8), (0.46, 0.16, 0.76), (0.7, 0.2, 0.86)]) {
        final book = Rect.fromLTRB(s * l, s * (y - 0.08), s * r, s * (y + 0.1));
        canvas.drawRRect(RRect.fromRectAndRadius(book, Radius.circular(s * 0.03)), fill);
        canvas.drawLine(Offset(book.left + s * 0.1, book.top + s * 0.03), Offset(book.left + s * 0.1, book.bottom - s * 0.03),
            Paint()
              ..color = back
              ..strokeWidth = w * 0.35);
        canvas.drawLine(Offset(book.right - s * 0.05, book.top + s * 0.04), Offset(book.right - s * 0.05, book.bottom - s * 0.04),
            Paint()
              ..color = back
              ..strokeWidth = w * 0.35);
      }
    case Trim.tavern:
      // Three planks, nailed.
      for (final y in [0.28, 0.5, 0.72]) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: p(0.5, y), width: s * 0.72, height: s * 0.15), Radius.circular(s * 0.02)), fill);
        canvas.drawCircle(p(0.22, y), s * 0.025, gap);
        canvas.drawCircle(p(0.78, y), s * 0.025, gap);
      }
    case Trim.marble:
      // Three cut stones.
      for (final y in [0.28, 0.5, 0.72]) {
        final r = Rect.fromCenter(center: p(0.5, y), width: s * 0.72, height: s * 0.15);
        final k = r.height / 2;
        canvas.drawPath(
            Path()
              ..moveTo(r.left + k, r.top)
              ..lineTo(r.right - k, r.top)
              ..lineTo(r.right, r.center.dy)
              ..lineTo(r.right - k, r.bottom)
              ..lineTo(r.left + k, r.bottom)
              ..lineTo(r.left, r.center.dy)
              ..close(),
            fill);
      }
    case Trim.ballroom:
      // A ziggurat of bars, a fan rising from it.
      for (final (y, half) in [(0.44, 0.16), (0.6, 0.26), (0.76, 0.36)]) {
        canvas.drawRect(Rect.fromCenter(center: p(0.5, y), width: s * half * 2, height: s * 0.1), fill);
      }
      for (final a in [-0.9, -0.45, 0.0, 0.45, 0.9]) {
        final d = Offset(math.sin(a), -math.cos(a));
        canvas.drawLine(p(0.5, 0.36) + d * s * 0.06, p(0.5, 0.36) + d * s * 0.2, thin..strokeWidth = w * 0.5);
      }
    case Trim.courtyard:
      // A list set with tiles: a tile, then a bar, three times.
      for (final y in [0.28, 0.5, 0.72]) {
        canvas.save();
        canvas.translate(s * 0.22, s * y);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s * 0.13, height: s * 0.13), fill);
        canvas.restore();
        canvas.drawLine(p(0.4, y), p(0.84, y), line);
      }
    case Trim.campaign:
      // A folded map, with its route.
      final map = Path()
        ..moveTo(s * 0.12, s * 0.22)
        ..lineTo(s * 0.37, s * 0.14)
        ..lineTo(s * 0.63, s * 0.22)
        ..lineTo(s * 0.88, s * 0.14)
        ..lineTo(s * 0.88, s * 0.78)
        ..lineTo(s * 0.63, s * 0.86)
        ..lineTo(s * 0.37, s * 0.78)
        ..lineTo(s * 0.12, s * 0.86)
        ..close();
      canvas.drawPath(map, thin);
      canvas.drawLine(p(0.37, 0.14), p(0.37, 0.78), thin..strokeWidth = w * 0.45);
      canvas.drawLine(p(0.63, 0.22), p(0.63, 0.86), thin);
      for (final (x, y) in [(0.22, 0.66), (0.32, 0.56), (0.44, 0.5), (0.56, 0.44), (0.68, 0.4)]) {
        canvas.drawCircle(p(x, y), s * 0.025, fill);
      }
      final x = p(0.76, 0.34);
      canvas.drawLine(x - Offset(s * 0.05, s * 0.05), x + Offset(s * 0.05, s * 0.05), thin..strokeWidth = w * 0.6);
      canvas.drawLine(x - Offset(s * 0.05, -s * 0.05), x + Offset(s * 0.05, -s * 0.05), thin);
    case Trim.casino:
      // A stack of three chips.
      for (final y in [0.72, 0.5, 0.28]) {
        final chip = RRect.fromRectAndRadius(Rect.fromCenter(center: p(0.5, y), width: s * 0.74, height: s * 0.16), Radius.circular(s * 0.08));
        // A rim of the felt between chips, so the stack reads as three.
        canvas.drawRRect(chip.inflate(s * 0.03), gap);
        canvas.drawRRect(chip, fill);
        for (final x in [0.26, 0.5, 0.74]) {
          canvas.drawRect(Rect.fromCenter(center: p(x, y), width: s * 0.045, height: s * 0.17), gap);
        }
      }
    case Trim.salon:
      // Three hairlines and a dot.
      for (final y in [0.3, 0.5, 0.7]) {
        canvas.drawLine(p(0.16, y), p(y == 0.5 ? 0.66 : 0.84, y), thin..strokeWidth = w * 0.45);
      }
      canvas.drawCircle(p(0.8, 0.5), s * 0.045, fill);
    case Trim.riviera:
      // A striped awning.
      const n = 4;
      final top = s * 0.24, hem = s * 0.62;
      for (var i = 0; i < n; i++) {
        final l = s * (0.12 + i * 0.19), r = l + s * 0.19;
        final stripe = Path()
          ..moveTo(l, top)
          ..lineTo(r, top)
          ..lineTo(r, hem)
          ..quadraticBezierTo((l + r) / 2, hem + s * 0.16, l, hem)
          ..close();
        canvas.drawPath(stripe, i.isEven ? fill : thin..strokeWidth = w * 0.45);
      }
      canvas.drawLine(p(0.1, 0.2), p(0.9, 0.2), line);
    case Trim.winter:
      // Three bars hung with icicles.
      bars();
      for (final y in [0.28, 0.5, 0.72]) {
        for (final (x, len) in [(0.3, 0.1), (0.5, 0.06), (0.68, 0.09)]) {
          canvas.drawPath(
              Path()
                ..moveTo(s * (x - 0.035), s * y)
                ..lineTo(s * (x + 0.035), s * y)
                ..lineTo(s * x, s * (y + len + 0.04))
                ..close(),
              fill);
        }
      }
    case Trim.egyptian:
      // A scarab.
      canvas.drawOval(Rect.fromCenter(center: p(0.5, 0.58), width: s * 0.4, height: s * 0.48), fill);
      canvas.drawLine(p(0.5, 0.42), p(0.5, 0.8), Paint()
        ..color = back
        ..strokeWidth = w * 0.45);
      canvas.drawLine(p(0.32, 0.44), p(0.68, 0.44), Paint()
        ..color = back
        ..strokeWidth = w * 0.4);
      canvas.drawOval(Rect.fromCenter(center: p(0.5, 0.27), width: s * 0.22, height: s * 0.14), fill);
      for (final side in [-1.0, 1.0]) {
        for (final (y, dy) in [(0.48, -0.08), (0.6, 0.0), (0.72, 0.08)]) {
          canvas.drawLine(p(0.5 + side * 0.2, y), p(0.5 + side * 0.36, y + dy), thin..strokeWidth = w * 0.5);
        }
        canvas.drawLine(p(0.5 + side * 0.06, 0.2), p(0.5 + side * 0.14, 0.1), thin);
      }
    case Trim.galleon:
      // A ship's wheel.
      final c = p(0.5, 0.5);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c, c + d * s * 0.38, thin..strokeWidth = w * 0.55);
        canvas.drawCircle(c + d * s * 0.41, s * 0.045, fill);
      }
      canvas.drawCircle(c, s * 0.27, thin..strokeWidth = w * 0.8);
      canvas.drawCircle(c, s * 0.08, fill);
    case Trim.scopa:
      // The trattoria's chalk menu, on its board.
      final board = RRect.fromRectAndRadius(Rect.fromLTRB(s * 0.14, s * 0.14, s * 0.86, s * 0.86), Radius.circular(s * 0.04));
      canvas.drawRRect(board, thin..strokeWidth = w * 0.8);
      for (final (y, r) in [(0.34, 0.72), (0.5, 0.62), (0.66, 0.7)]) {
        canvas.drawLine(p(0.28, y), p(r, y), thin..strokeWidth = w * 0.5);
      }
  }
}

/// What tips a stroke in [trim]'s icons (the arms of its cross, an eye's
/// pupil): a diamond at court, a dot, a square, a star.
enum TrimMark { round, diamond, dot, square, star, leaf }

TrimMark markOf(Trim trim) => switch (trim) {
      Trim.court || Trim.ballroom || Trim.egyptian || Trim.lacquer => TrimMark.diamond,
      Trim.velvet || Trim.casino || Trim.harbour || Trim.riviera || Trim.tavern || Trim.galleon => TrimMark.dot,
      Trim.counting || Trim.courtyard || Trim.marble || Trim.library || Trim.campaign => TrimMark.square,
      Trim.midnight || Trim.winter => TrimMark.star,
      Trim.garden => TrimMark.leaf,
      Trim.plain || Trim.salon || Trim.scopa => TrimMark.round,
    };

/// Draws [mark] at [c], [r] across.
void paintMark(Canvas canvas, TrimMark mark, Offset c, double r, Paint fill) {
  switch (mark) {
    case TrimMark.round:
      break;
    case TrimMark.dot:
      canvas.drawCircle(c, r, fill);
    case TrimMark.diamond:
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r * 1.3)
            ..lineTo(c.dx + r, c.dy)
            ..lineTo(c.dx, c.dy + r * 1.3)
            ..lineTo(c.dx - r, c.dy)
            ..close(),
          fill);
    case TrimMark.square:
      canvas.drawRect(Rect.fromCenter(center: c, width: r * 1.7, height: r * 1.7), fill);
    case TrimMark.star:
      final path = Path();
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 - math.pi / 2;
        final d = i.isEven ? r * 1.5 : r * 0.5;
        final o = c + Offset(math.cos(a), math.sin(a)) * d;
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path..close(), fill);
    case TrimMark.leaf:
      canvas.drawOval(Rect.fromCenter(center: c, width: r * 2.4, height: r * 1.3), fill);
  }
}
