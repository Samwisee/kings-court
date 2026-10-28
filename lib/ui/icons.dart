// The game’s small drawn icons: crowns, suits, Court Cards, and the buttons by your hand.
part of '../widgets.dart';

/// A small five-point crown, drawn so it looks the same on every platform.
class CrownIcon extends StatelessWidget {
  const CrownIcon({super.key, this.size = 16, this.color = Palette.gold});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size * 0.75),
        painter: _CrownPainter(color),
      );
}

class _CrownPainter extends CustomPainter {
  _CrownPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final path = Path()
      ..moveTo(0, h * 0.25)
      ..lineTo(w * 0.27, h * 0.55)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w * 0.73, h * 0.55)
      ..lineTo(w, h * 0.25)
      ..lineTo(w * 0.88, h * 0.82)
      ..lineTo(w * 0.12, h * 0.82)
      ..close()
      ..addRect(Rect.fromLTWH(w * 0.12, h * 0.88, w * 0.76, h * 0.12));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.color != color;
}

/// The card tracker's icon: a small grid of cards, like the tracker's own
/// rows of the deck, some of them played (filled) and some still to come.
class TrackerIcon extends StatelessWidget {
  const TrackerIcon({super.key, this.size = 26, this.color = Palette.gold});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _TrackerPainter(color));
}

class _TrackerPainter extends CustomPainter {
  _TrackerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final w = s * 0.24, h = s * 0.32, gap = s * 0.08;
    final left = (s - 3 * w - 2 * gap) / 2, top = (s - 2 * h - gap) / 2;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.065
      ..color = color;
    final fill = Paint()..color = color;
    const filled = [true, true, false, true, false, false];
    for (int i = 0; i < 6; i++) {
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(left + (i % 3) * (w + gap), top + (i ~/ 3) * (h + gap), w, h),
          Radius.circular(s * 0.05));
      canvas.drawRRect(r, filled[i] ? fill : line);
    }
  }

  @override
  bool shouldRepaint(_TrackerPainter old) => old.color != color;
}

/// Court Cards fanned out, the front one gold with a crown; struck out by
/// [NoCourtIcon] for "no Court Cards".
class CardFanIcon extends StatelessWidget {
  const CardFanIcon({super.key, this.size = 26, this.color = Palette.gold});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CardFanPainter(color));
}

class _CardFanPainter extends CustomPainter {
  _CardFanPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final card = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -s * 0.12), width: s * 0.42, height: s * 0.58),
        Radius.circular(s * 0.07));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..color = color;
    final back = Paint()..color = Palette.feltDeep;
    for (final (i, a) in [(-1, -0.42), (0, 0.0), (1, 0.42)].map((e) => (e.$1, e.$2))) {
      canvas.save();
      canvas.translate(s / 2, s * 0.88);
      canvas.rotate(a);
      canvas.translate(0, -s * 0.36);
      canvas.drawRRect(card, i == 1 ? (Paint()..color = color) : back);
      canvas.drawRRect(card, edge);
      if (i == 1) {
        // A small crown on the front card.
        final c = card.center;
        final w = s * 0.2;
        final crown = Path()
          ..moveTo(c.dx - w / 2, c.dy + w * 0.25)
          ..lineTo(c.dx - w / 2, c.dy - w * 0.25)
          ..lineTo(c.dx - w / 4, c.dy)
          ..lineTo(c.dx, c.dy - w * 0.4)
          ..lineTo(c.dx + w / 4, c.dy)
          ..lineTo(c.dx + w / 2, c.dy - w * 0.25)
          ..lineTo(c.dx + w / 2, c.dy + w * 0.25)
          ..close();
        canvas.drawPath(crown, back);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CardFanPainter old) => old.color != color;
}

/// The icon for showing a card: a card held up, with rays around it. Once
/// used, the rays are gone and a line crosses it out.
class ShowCardIcon extends StatelessWidget {
  const ShowCardIcon(
      {super.key, this.size = 26, this.color = Palette.gold, this.used = false});
  final double size;
  final Color color;
  final bool used;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ShowCardPainter(color, used));
}

class _ShowCardPainter extends CustomPainter {
  _ShowCardPainter(this.color, this.used);
  final Color color;
  final bool used;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final card = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: s * 0.44, height: s * 0.6),
        Radius.circular(s * 0.07));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawRRect(card, line);
    // A heart on the card.
    final h = s * 0.16;
    final heart = Path()
      ..moveTo(c.dx, c.dy + h * 0.6)
      ..cubicTo(c.dx - h * 1.2, c.dy - h * 0.1, c.dx - h * 0.5, c.dy - h * 0.9, c.dx, c.dy - h * 0.3)
      ..cubicTo(c.dx + h * 0.5, c.dy - h * 0.9, c.dx + h * 1.2, c.dy - h * 0.1, c.dx, c.dy + h * 0.6)
      ..close();
    canvas.drawPath(heart, Paint()..color = color);
    if (used) {
      canvas.drawLine(Offset(s * 0.18, s * 0.82), Offset(s * 0.82, s * 0.18), line);
      return;
    }
    // Rays: it's being shown.
    final ray = Paint()
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final a in [-2.4, -1.57, -0.74]) {
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * s * 0.4, c + d * s * 0.5, ray);
    }
    for (final a in [0.0, math.pi]) {
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * s * 0.33, c + d * s * 0.45, ray);
    }
  }

  @override
  bool shouldRepaint(_ShowCardPainter old) => old.color != color || old.used != used;
}

/// A suit drawn as a shape, not a font glyph: the same chunky suits as the
/// printed deck, in exactly the colour asked for (a browser's emoji font
/// can never take over).
class SuitIcon extends StatelessWidget {
  const SuitIcon(this.suit, {super.key, required this.size, required this.color});
  final Suit suit;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => suit == Suit.court
      ? CrownIcon(size: size, color: color)
      : CustomPaint(size: Size.square(size), painter: _SuitPainter(suit, color));
}

class _SuitPainter extends CustomPainter {
  _SuitPainter(this.suit, this.color);
  final Suit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final parts = suitPaths[suit.name];
    if (parts == null) return;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()..color = color;
    for (final p in parts) {
      canvas.drawPath(p, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SuitPainter old) => old.suit != suit || old.color != color;
}

/// A Court Card: a card with a crown on it.
class CourtCardIcon extends StatelessWidget {
  const CourtCardIcon({super.key, required this.size, this.color = Palette.goldDeep});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size(size * 0.78, size), painter: _CourtCardPainter(color));
}

class _CourtCardPainter extends CustomPainter {
  _CourtCardPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = w * 0.11;
    final card = RRect.fromRectAndRadius(
        Rect.fromLTWH(line / 2, line / 2, w - line, h - line), Radius.circular(w * 0.16));
    canvas.drawRRect(
        card,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = line
          ..color = color);
    // The crown, as [CrownIcon] draws it, in the middle of the card.
    final cw = w * 0.62, ch = cw * 0.75;
    final x = (w - cw) / 2, y = (h - ch) / 2;
    final crown = Path()
      ..moveTo(x, y + ch * 0.25)
      ..lineTo(x + cw * 0.27, y + ch * 0.55)
      ..lineTo(x + cw * 0.5, y)
      ..lineTo(x + cw * 0.73, y + ch * 0.55)
      ..lineTo(x + cw, y + ch * 0.25)
      ..lineTo(x + cw * 0.88, y + ch * 0.82)
      ..lineTo(x + cw * 0.12, y + ch * 0.82)
      ..close()
      ..addRect(Rect.fromLTRB(x + cw * 0.12, y + ch * 0.88, x + cw * 0.88, y + ch));
    canvas.drawPath(crown, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CourtCardPainter old) => old.color != color;
}

/// No Court Cards: the Court Card icon, struck through.
class NoCourtIcon extends StatelessWidget {
  const NoCourtIcon({super.key, required this.size, this.color = Palette.goldDeep});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CourtCardIcon(size: size, color: color),
          CustomPaint(size: Size.square(size), painter: _SlashPainter(color)),
        ]),
      );
}

class _SlashPainter extends CustomPainter {
  _SlashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
        Offset(size.width * 0.1, size.height * 0.92),
        Offset(size.width * 0.9, size.height * 0.08),
        Paint()
          ..color = Palette.lost
          ..strokeWidth = size.height * 0.1
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_SlashPainter old) => old.color != color;
}
