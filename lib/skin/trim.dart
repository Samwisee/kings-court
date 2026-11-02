/// A skin's trim: the cut of its buttons and the family its icons belong
/// to (ui/widgets/trim_icons.dart), one for each room. [TrimBorder] is the
/// button's shape: its outline, and the few marks at its edges that say
/// which room it's from (a chip's edge spots, a rope, a cartouche's tie).
/// Drawn with plain strokes and fills, no blurs: cheap on every frame.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

enum Trim {
  /// The court's plaque: cut corners.
  court,
  plain,
  lacquer,
  garden,
  midnight,
  harbour,
  velvet,
  counting,
  library,
  tavern,
  marble,
  ballroom,
  courtyard,
  campaign,
  casino,
  salon,
  riviera,
  winter,
  egyptian,
  galleon,
  scopa;

  /// A chalkboard rather than the accent's fill: its board and its chalk.
  bool get chalk => this == scopa;
}

/// Scopa's chalkboard and its wooden frame.
const chalkBoard = Color(0xFF26332D);
const chalkInk = Color(0xFFF3EFE4);
const chalkFrame = Color(0xFF7A4E2A);

/// A button cut to its room's [trim], [radius] its corners' where it has
/// any. Its marks are drawn in [side]'s colour unless the trim has its own.
class TrimBorder extends OutlinedBorder {
  const TrimBorder(this.trim, {super.side, this.radius = 12});

  final Trim trim;
  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  ShapeBorder scale(double t) => TrimBorder(trim, side: side.scale(t), radius: radius * t);

  @override
  TrimBorder copyWith({BorderSide? side}) => TrimBorder(trim, side: side ?? this.side, radius: radius);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => outline(rect.deflate(side.strokeInset));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => outline(rect);

  /// The button's outline in [r].
  Path outline(Rect r) {
    final h = r.height, w = r.width;
    final stadium = RRect.fromRectAndRadius(r, Radius.circular(h / 2));
    RRect round(double k) => RRect.fromRectAndRadius(r, Radius.circular(math.min(k, h / 2)));
    Path cut(double c) => Path()
      ..moveTo(r.left + c, r.top)
      ..lineTo(r.right - c, r.top)
      ..lineTo(r.right, r.top + c)
      ..lineTo(r.right, r.bottom - c)
      ..lineTo(r.right - c, r.bottom)
      ..lineTo(r.left + c, r.bottom)
      ..lineTo(r.left, r.bottom - c)
      ..lineTo(r.left, r.top + c)
      ..close();
    switch (trim) {
      case Trim.court:
        return cut(math.min(radius, h / 3));
      case Trim.plain:
        return Path()..addRRect(round(10));
      case Trim.lacquer:
      case Trim.library:
      case Trim.galleon:
        return Path()..addRRect(round(5));
      case Trim.counting:
      case Trim.scopa:
      case Trim.courtyard:
        return Path()..addRRect(round(3));
      case Trim.midnight:
        return Path()..addRRect(round(h * 0.3));
      case Trim.winter:
        return Path()..addRRect(round(10));
      case Trim.velvet:
      case Trim.casino:
      case Trim.salon:
      case Trim.harbour:
      case Trim.egyptian:
        return Path()..addRRect(stadium);
      case Trim.garden:
        // A leaf: two opposite corners round, two to a point.
        final big = Radius.circular(h / 2), small = const Radius.circular(3);
        return Path()..addRRect(RRect.fromRectAndCorners(r, topLeft: big, bottomRight: big, topRight: small, bottomLeft: small));
      case Trim.marble:
        return cut(math.min(6, h / 4));
      case Trim.tavern:
        // A board cut by hand: not quite square.
        return Path()
          ..moveTo(r.left + 3, r.top)
          ..lineTo(r.right - 1, r.top + 1.5)
          ..lineTo(r.right, r.bottom - 2.5)
          ..lineTo(r.right - 3, r.bottom)
          ..lineTo(r.left + 1, r.bottom - 1)
          ..lineTo(r.left, r.top + 2)
          ..close();
      case Trim.ballroom:
        // Stepped corners, two steps each.
        final s = math.min(h * 0.13, 6.0);
        return Path()
          ..moveTo(r.left + 2 * s, r.top)
          ..lineTo(r.right - 2 * s, r.top)
          ..lineTo(r.right - 2 * s, r.top + s)
          ..lineTo(r.right - s, r.top + s)
          ..lineTo(r.right - s, r.top + 2 * s)
          ..lineTo(r.right, r.top + 2 * s)
          ..lineTo(r.right, r.bottom - 2 * s)
          ..lineTo(r.right - s, r.bottom - 2 * s)
          ..lineTo(r.right - s, r.bottom - s)
          ..lineTo(r.right - 2 * s, r.bottom - s)
          ..lineTo(r.right - 2 * s, r.bottom)
          ..lineTo(r.left + 2 * s, r.bottom)
          ..lineTo(r.left + 2 * s, r.bottom - s)
          ..lineTo(r.left + s, r.bottom - s)
          ..lineTo(r.left + s, r.bottom - 2 * s)
          ..lineTo(r.left, r.bottom - 2 * s)
          ..lineTo(r.left, r.top + 2 * s)
          ..lineTo(r.left + s, r.top + 2 * s)
          ..lineTo(r.left + s, r.top + s)
          ..lineTo(r.left + 2 * s, r.top + s)
          ..close();
      case Trim.campaign:
        // A ribbon: a notch in each end.
        final d = h * 0.22;
        return Path()
          ..moveTo(r.left, r.top)
          ..lineTo(r.right, r.top)
          ..lineTo(r.right - d, r.center.dy)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.left, r.bottom)
          ..lineTo(r.left + d, r.center.dy)
          ..close();
      case Trim.riviera:
        // An awning: square on top, scalloped underneath.
        final a = h * 0.12;
        final n = math.max(4, (w / (h * 0.55)).round());
        final step = w / n;
        final p = Path()
          ..moveTo(r.left, r.top + 6)
          ..quadraticBezierTo(r.left, r.top, r.left + 6, r.top)
          ..lineTo(r.right - 6, r.top)
          ..quadraticBezierTo(r.right, r.top, r.right, r.top + 6)
          ..lineTo(r.right, r.bottom - a);
        for (var i = n; i > 0; i--) {
          final x = r.left + i * step;
          p.quadraticBezierTo(x - step / 2, r.bottom + a, x - step, r.bottom - a);
        }
        return p..close();
    }
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final r = rect;
    final h = r.height;
    final ink = side.color;
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = c;
    final fill = Paint()..color = ink;
    if (side.style != BorderStyle.none && side.width > 0) {
      canvas.drawPath(outline(r.deflate(side.width / 2)), stroke(ink, side.width));
    }
    // An inner rule following the outline.
    void rule(double inset, Color c, double w) => canvas.drawPath(outline(r.deflate(inset)), stroke(c, w));
    final soft = ink.withValues(alpha: ink.a * 0.7);
    switch (trim) {
      case Trim.court:
      case Trim.plain:
        break;
      case Trim.lacquer:
        // A gilt inlay inside the edge.
        rule(3.5, soft, 1);
      case Trim.garden:
        rule(3.5, soft, 1);
        // A leaf's vein at each pointed corner.
        canvas.drawLine(Offset(r.right - 4, r.top + 4), Offset(r.right - 11, r.top + 9), stroke(soft, 1.2));
        canvas.drawLine(Offset(r.left + 4, r.bottom - 4), Offset(r.left + 11, r.bottom - 9), stroke(soft, 1.2));
      case Trim.midnight:
        // A silver rule, a star at each end.
        rule(3.5, const Color(0xCCE8EEFF), 1);
        for (final x in [r.left + h * 0.32, r.right - h * 0.32]) {
          _star(canvas, Offset(x, r.center.dy), h * 0.11, const Color(0xEEF4F7FF));
        }
      case Trim.harbour:
        // A porthole's bolts at each end.
        for (final x in [r.left + h * 0.27, r.right - h * 0.27]) {
          for (final dy in [-h * 0.2, h * 0.2]) {
            canvas.drawCircle(Offset(x, r.center.dy + dy), 1.6, fill);
          }
        }
      case Trim.velvet:
        // Piping round a cushion, buttoned at each end.
        rule(3, soft, 1.4);
        for (final x in [r.left + h * 0.36, r.right - h * 0.36]) {
          canvas.drawCircle(Offset(x, r.center.dy), 2.6, fill);
          canvas.drawCircle(Offset(x - 0.6, r.center.dy - 0.6), 1, Paint()..color = const Color(0x55FFFFFF));
        }
      case Trim.counting:
        // A brass plate's screws.
        for (final c in [
          Offset(r.left + 6, r.top + 6),
          Offset(r.right - 6, r.top + 6),
          Offset(r.left + 6, r.bottom - 6),
          Offset(r.right - 6, r.bottom - 6),
        ]) {
          canvas.drawCircle(c, 2.2, stroke(ink, 1));
          canvas.drawLine(c - const Offset(1.5, 1.5), c + const Offset(1.5, 1.5), stroke(ink, 1));
        }
      case Trim.library:
        // Tooled leather: a stitched rule.
        _dashed(canvas, outline(r.deflate(3.5)), stroke(soft, 1), 3, 2.5);
      case Trim.tavern:
        // Nailed to the wall.
        for (final x in [r.left + 7, r.right - 7]) {
          canvas.drawCircle(Offset(x, r.center.dy), 2.2, fill);
        }
      case Trim.marble:
        // Carved: a groove, dark above and light below.
        final groove = r.deflate(4);
        canvas.drawLine(groove.topLeft, groove.topRight, stroke(const Color(0x55000000), 1.2));
        canvas.drawLine(groove.bottomLeft, groove.bottomRight, stroke(const Color(0x66FFFFFF), 1.2));
        canvas.drawLine(groove.topLeft + const Offset(0, 1), groove.bottomLeft, stroke(const Color(0x40000000), 1));
        canvas.drawLine(groove.topRight + const Offset(0, 1), groove.bottomRight, stroke(const Color(0x55FFFFFF), 1));
      case Trim.ballroom:
        rule(3.5, soft, 1);
      case Trim.courtyard:
        // A tile at each corner.
        for (final c in [
          Offset(r.left + 3, r.top + 3),
          Offset(r.right - 8, r.top + 3),
          Offset(r.left + 3, r.bottom - 8),
          Offset(r.right - 8, r.bottom - 8),
        ]) {
          canvas.drawRect(c & const Size(5, 5), fill);
        }
      case Trim.campaign:
        rule(3.5, soft, 1);
      case Trim.casino:
        // A chip's edge spots, round the rim.
        final spot = Paint()
          ..color = const Color(0xF2FFFFFF)
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.butt;
        final n = math.max(2, (r.width / (h * 0.9)).floor());
        for (var i = 0; i < n; i++) {
          final x = r.left + h / 2 + (r.width - h) * (n == 1 ? 0.5 : i / (n - 1));
          canvas.drawLine(Offset(x - h * 0.1, r.top + 1.8), Offset(x + h * 0.1, r.top + 1.8), spot);
          canvas.drawLine(Offset(x - h * 0.1, r.bottom - 1.8), Offset(x + h * 0.1, r.bottom - 1.8), spot);
        }
        for (final x in [r.left + 1.8, r.right - 1.8]) {
          canvas.drawLine(Offset(x, r.center.dy - h * 0.1), Offset(x, r.center.dy + h * 0.1), spot);
        }
      case Trim.salon:
        rule(2.5, soft, 0.75);
      case Trim.riviera:
        // The awning's hem, above its scallops.
        final y = r.bottom - h * 0.18;
        canvas.drawLine(Offset(r.left + 3, y), Offset(r.right - 3, y), stroke(const Color(0x99FFFFFF), 1.2));
      case Trim.winter:
        // Frost on the glass: a bright rim along the top, streaks in the
        // corner, a few flakes.
        final frost = stroke(const Color(0xCCFFFFFF), 1.2);
        canvas.drawLine(Offset(r.left + 8, r.top + 2.5), Offset(r.right - 8, r.top + 2.5), frost);
        for (var i = 0; i < 3; i++) {
          final o = 6.0 + i * 4.5;
          canvas.drawLine(Offset(r.left + 3, r.top + o + 4), Offset(r.left + o + 4, r.top + 3), stroke(const Color(0x88FFFFFF), 1));
        }
        for (final c in [Offset(r.right - 9, r.bottom - 8), Offset(r.right - 15, r.bottom - 13)]) {
          canvas.drawCircle(c, 1.4, Paint()..color = const Color(0xCCFFFFFF));
        }
      case Trim.egyptian:
        // A cartouche: a second rule, tied off at one end.
        rule(3.5, soft, 1);
        final x = r.right - h * 0.28;
        canvas.drawLine(Offset(x, r.top + 6), Offset(x, r.bottom - 6), stroke(ink, 2));
      case Trim.galleon:
        // Bound in rope: a twist all the way round.
        final rope = stroke(const Color(0xFFC9A46A), 1.6)..strokeCap = StrokeCap.round;
        for (final m in outline(r.deflate(2.5)).computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 4.5) {
            final t = m.getTangentForOffset(d);
            if (t == null) continue;
            final n = Offset(-t.vector.dy, t.vector.dx);
            final a = t.position - t.vector * 1.6 - n * 1.6;
            final b = t.position + t.vector * 1.6 + n * 1.6;
            canvas.drawLine(a, b, rope);
          }
        }
      case Trim.scopa:
        // The board's wooden frame.
        canvas.drawPath(outline(r.deflate(2.5)), stroke(chalkFrame, 4));
        rule(5, const Color(0x33FFFFFF), 0.8);
    }
  }

  static void _star(Canvas canvas, Offset c, double r, Color colour) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final d = i.isEven ? r : r * 0.35;
      final o = c + Offset(math.cos(a), math.sin(a)) * d;
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = colour);
  }

  static void _dashed(Canvas canvas, Path path, Paint paint, double on, double off) {
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += on + off) {
        canvas.drawPath(m.extractPath(d, math.min(d + on, m.length)), paint);
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TrimBorder && other.trim == trim && other.side == side && other.radius == radius;

  @override
  int get hashCode => Object.hash(trim, side, radius);
}
