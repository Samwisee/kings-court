import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/cards.dart';
import '../theme.dart';
import '../widgets.dart';

/// A playing card drawn on screen. Plain suits show their pip. Each Court
/// Card has a face of its own, all framed in gold: the Joker's jester cap
/// on harlequin purple, the Jack's sword and shield on emerald, the Queen's
/// tiara on sapphire, and the King card's radiant crown on crimson velvet.
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    required this.card,
    required this.width,
    this.dimmed = false,
    this.glow = false,
    this.edge,
    this.marks = const [],
  });

  final PlayingCard card;
  final double width;

  /// Not playable right now: shaded (but never see-through).
  final bool dimmed;

  /// Won the trick.
  final bool glow;

  /// A coloured border, such as the colour of the player who played it.
  final Color? edge;

  /// Colours of the players whose tasks need this card.
  final List<Color> marks;

  static double heightFor(double width) => width * 1.42;

  /// Each Court Card's cloth: Joker, Jack, Queen, King.
  static const _cloth = [
    [Color(0xFF5A2F87), Color(0xFF241238)],
    [Color(0xFF13734A), Color(0xFF062A1B)],
    [Color(0xFF2849A8), Color(0xFF0B1A45)],
    [Color(0xFF9A1E31), Color(0xFF3A0610)],
  ];

  bool get _isKing => card == PlayingCard.king;

  Color get _inkColour => Palette.suitColour(card.suit);

  @override
  Widget build(BuildContext context) {
    final h = heightFor(width);
    final r = BorderRadius.circular(width * 0.1);
    final corner = TextStyle(
        fontFamily: card.isCourt ? displayFont : bodyFont,
        fontWeight: FontWeight.w900,
        fontSize: width * (card.isCourt ? 0.3 : 0.26),
        height: 1,
        color: _inkColour);
    final borderColour = edge ??
        (marks.isNotEmpty
            ? marks.first
            : glow
                ? Palette.gold
                : card.isCourt
                    ? Palette.gold
                    : const Color(0xFFD9D2C3));
    final thick = glow || edge != null || marks.isNotEmpty || card.isCourt;

    return Semantics(
      label: card.spoken,
      value: dimmed ? 'can’t be played now' : glow ? 'suggested' : null,
      excludeSemantics: true,
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          color: card.isCourt ? null : Palette.card,
          gradient: card.isCourt
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _cloth[card.rank - 1])
              : null,
          borderRadius: r,
          border: Border.all(
              color: borderColour, width: thick ? 3 : card.isCourt ? 2 : 1),
          boxShadow: [
            if (glow)
              const BoxShadow(color: Palette.gold, blurRadius: 14)
            else if (marks.isNotEmpty)
              BoxShadow(color: marks.first.withValues(alpha: 0.85), blurRadius: 10)
            else if (_isKing)
              const BoxShadow(color: Color(0x88D4A63A), blurRadius: 8)
            else
              const BoxShadow(
                  color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        foregroundDecoration: dimmed
            ? BoxDecoration(color: const Color(0x66000000), borderRadius: r)
            : null,
        child: Stack(
          children: [
            // Each Court Card's cloth has its own pattern.
            if (card.isCourt)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: r,
                  child: CustomPaint(
                      painter: switch (card.rank) {
                    1 => _Harlequin(),
                    2 => _Stripes(),
                    3 => _Lattice(),
                    _ => _Sunburst(),
                  }),
                ),
              ),
            // Every Court Card has an inner gold frame.
            if (card.isCourt)
              Positioned.fill(
                child: Container(
                  margin: EdgeInsets.all(width * 0.06),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(width * 0.06),
                    border: Border.all(color: const Color(0x99D4A63A), width: 1),
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: width * 0.18),
                child: _face(),
              ),
            ),
            Positioned(
              left: width * 0.09,
              top: width * 0.08,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(card.rankLabel, style: corner),
                  // Court Cards are their own suit: no pip in the corner.
                  if (!card.isCourt)
                    Text(card.suit.symbol,
                        style: corner.copyWith(fontSize: width * 0.22)),
                ],
              ),
            ),
            // Flags for whoever needs this card, under the corner, where
            // they show even when the next card in a hand covers the rest.
            if (marks.isNotEmpty)
              Positioned(
                left: width * 0.06,
                top: width * 0.6,
                child: Column(
                  children: [
                    for (final m in marks)
                      Container(
                        width: width * 0.2,
                        height: width * 0.2,
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: m,
                          shape: BoxShape.circle,
                          border: Border.all(color: Palette.ink, width: 1.2),
                        ),
                        child: Icon(Icons.flag_rounded,
                            size: width * 0.13, color: Colors.white),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _face() {
    if (!card.isCourt) {
      return Text(card.suit.symbol,
          style: TextStyle(
              fontFamily: bodyFont,
              fontWeight: FontWeight.w900,
              fontSize: width * 0.52,
              height: 1,
              color: _inkColour));
    }
    final art = SizedBox(width: width * 0.66, height: width * 0.6);
    return switch (card.rank) {
      1 => CustomPaint(painter: _JesterCap(), child: art),
      2 => CustomPaint(painter: _SwordAndShield(), child: art),
      3 => CustomPaint(painter: _Tiara(), child: art),
      _ => CustomPaint(
          painter: _RoyalCrown(),
          child: SizedBox(width: width * 0.72, height: width * 0.66)),
    };
  }
}

const _goldLight = Color(0xFFF9E08C);
const _goldMid = Color(0xFFD4A63A);
const _goldDark = Color(0xFF9C7420);

Paint _gilt(Rect r) => Paint()
  ..shader = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_goldLight, _goldMid, _goldDark],
  ).createShader(r);

/// The Joker's cloth: a field of purple diamonds.
class _Harlequin extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dw = size.width / 4, dh = size.height / 5;
    final paint = Paint()..color = const Color(0x1C4A1E6E);
    final light = Paint()..color = const Color(0x12F9E08C);
    for (int row = -1; row <= 5; row++) {
      for (int col = -1; col <= 4; col++) {
        final cx = col * dw + (row.isOdd ? dw / 2 : 0);
        final cy = row * dh;
        final p = Path()
          ..moveTo(cx, cy - dh / 2)
          ..lineTo(cx + dw / 2, cy)
          ..lineTo(cx, cy + dh / 2)
          ..lineTo(cx - dw / 2, cy)
          ..close();
        canvas.drawPath(p, (row + col).isEven ? paint : light);
      }
    }
  }

  @override
  bool shouldRepaint(_Harlequin old) => false;
}

/// The Joker's three-pointed cap, with bells.
class _JesterCap extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cap = Path()
      ..moveTo(w * 0.18, h * 0.82)
      ..quadraticBezierTo(w * 0.1, h * 0.45, w * 0.02, h * 0.3)
      ..quadraticBezierTo(w * 0.3, h * 0.38, w * 0.38, h * 0.55)
      ..quadraticBezierTo(w * 0.42, h * 0.2, w * 0.5, h * 0.04)
      ..quadraticBezierTo(w * 0.58, h * 0.2, w * 0.62, h * 0.55)
      ..quadraticBezierTo(w * 0.7, h * 0.38, w * 0.98, h * 0.3)
      ..quadraticBezierTo(w * 0.9, h * 0.45, w * 0.82, h * 0.82)
      ..close();
    canvas.drawPath(cap, _gilt(Offset.zero & size));
    // Seams.
    final seam = Paint()
      ..color = _goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02;
    canvas.drawLine(Offset(w * 0.38, h * 0.55), Offset(w * 0.36, h * 0.8), seam);
    canvas.drawLine(Offset(w * 0.62, h * 0.55), Offset(w * 0.64, h * 0.8), seam);
    // Band.
    canvas.drawRRect(
        RRect.fromLTRBR(w * 0.15, h * 0.78, w * 0.85, h * 0.92,
            Radius.circular(w * 0.04)),
        Paint()..color = _goldDark);
    // Bells.
    final bell = Paint()..color = _goldLight;
    final edge = Paint()
      ..color = _goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.015;
    for (final p in [
      Offset(w * 0.04, h * 0.3),
      Offset(w * 0.5, h * 0.05),
      Offset(w * 0.96, h * 0.3),
    ]) {
      canvas.drawCircle(p, w * 0.06, bell);
      canvas.drawCircle(p, w * 0.06, edge);
    }
  }

  @override
  bool shouldRepaint(_JesterCap old) => false;
}

/// The Jack's sword behind a shield.
class _SwordAndShield extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final gilt = _gilt(Offset.zero & size);
    // A gold sword, point down: pommel, a long grip and the crossguard
    // above the shield.
    canvas.drawCircle(Offset(w * 0.5, h * 0.0), w * 0.045, gilt);
    canvas.drawRect(Rect.fromLTRB(w * 0.465, h * 0.02, w * 0.535, h * 0.25), gilt);
    canvas.drawRRect(
        RRect.fromLTRBR(w * 0.26, h * 0.23, w * 0.74, h * 0.29, Radius.circular(w * 0.03)),
        gilt);
    final blade = Path()
      ..moveTo(w * 0.45, h * 0.29)
      ..lineTo(w * 0.55, h * 0.29)
      ..lineTo(w * 0.55, h * 0.92)
      ..lineTo(w * 0.5, h * 1.02)
      ..lineTo(w * 0.45, h * 0.92)
      ..close();
    canvas.drawPath(blade, gilt);
    canvas.drawLine(Offset(w * 0.5, h * 0.3), Offset(w * 0.5, h * 0.95),
        Paint()
          ..color = _goldDark
          ..strokeWidth = w * 0.012);
    // Shield in front of the blade.
    final shield = Path()
      ..moveTo(w * 0.24, h * 0.34)
      ..lineTo(w * 0.76, h * 0.34)
      ..lineTo(w * 0.76, h * 0.54)
      ..quadraticBezierTo(w * 0.74, h * 0.74, w * 0.5, h * 0.84)
      ..quadraticBezierTo(w * 0.26, h * 0.74, w * 0.24, h * 0.54)
      ..close();
    canvas.drawPath(shield, gilt);
    // An emerald chevron on the shield.
    final chevron = Path()
      ..moveTo(w * 0.32, h * 0.48)
      ..lineTo(w * 0.5, h * 0.61)
      ..lineTo(w * 0.68, h * 0.48)
      ..lineTo(w * 0.68, h * 0.58)
      ..lineTo(w * 0.5, h * 0.71)
      ..lineTo(w * 0.32, h * 0.58)
      ..close();
    canvas.drawPath(chevron, Paint()..color = const Color(0xFF0F5B3A));
  }

  @override
  bool shouldRepaint(_SwordAndShield old) => false;
}

/// The Queen's tiara, all in gold filigree: a curved band, a tall pointed
/// oval with a gem-shaped centre, and a scroll curling down on each side,
/// with a smaller curl beyond it. Soft and curling where the King's crown
/// is all points.
class _Tiara extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Drawn in a box [s] wide and 0.8 s tall, centred in the space.
    final s = math.min(size.width, size.height / 0.8);
    final ox = (size.width - s) / 2, oy = (size.height - s * 0.8) / 2;
    Offset p(double x, double y) => Offset(ox + x * s, oy + y * s);
    final box = Offset.zero & size;
    final fill = _gilt(box);
    Paint stroke(double width) => _gilt(box)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void cubic(Path path, List<double> c) {
      final c1 = p(c[0], c[1]), c2 = p(c[2], c[3]), e = p(c[4], c[5]);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
    }

    // The band: a crescent, curving up at the ends.
    final band = Path()..moveTo(p(0.04, 0.64).dx, p(0.04, 0.64).dy);
    cubic(band, [0.3, 0.7, 0.7, 0.7, 0.96, 0.64]);
    cubic(band, [0.72, 0.79, 0.28, 0.79, 0.04, 0.64]);
    canvas.drawPath(band..close(), fill);

    // The tall pointed oval, and the gem inside it.
    final oval = Path()..moveTo(p(0.5, 0.66).dx, p(0.5, 0.66).dy);
    cubic(oval, [0.36, 0.56, 0.38, 0.24, 0.5, 0.08]);
    cubic(oval, [0.62, 0.24, 0.64, 0.56, 0.5, 0.66]);
    canvas.drawPath(oval, stroke(0.04));
    final gem = Path()..moveTo(p(0.5, 0.58).dx, p(0.5, 0.58).dy);
    cubic(gem, [0.42, 0.5, 0.43, 0.3, 0.5, 0.2]);
    cubic(gem, [0.57, 0.3, 0.58, 0.5, 0.5, 0.58]);
    canvas.drawPath(gem..close(), fill);

    // A scroll: a sweep up from the band that curls down into a spiral.
    Path scroll(List<double> start, List<double> curve, Offset centre,
        double turn, double endRadius) {
      final path = Path()..moveTo(p(start[0], start[1]).dx, p(start[0], start[1]).dy);
      cubic(path, curve);
      final from = p(curve[4], curve[5]);
      final c = p(centre.dx, centre.dy);
      final a0 = math.atan2(from.dy - c.dy, from.dx - c.dx);
      final r0 = (from - c).distance;
      const steps = 48;
      for (int k = 1; k <= steps; k++) {
        final f = k / steps;
        final a = a0 - turn * f;
        final r = r0 + (endRadius * s - r0) * f;
        path.lineTo(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      }
      return path;
    }

    final big = scroll([0.44, 0.66], [0.4, 0.36, 0.28, 0.22, 0.17, 0.43],
        const Offset(0.245, 0.52), math.pi * 1.83, 0.035);
    final small = scroll([0.2, 0.66], [0.16, 0.5, 0.09, 0.45, 0.05, 0.53],
        const Offset(0.09, 0.58), math.pi * 1.67, 0.02);
    // The right side mirrors the left across the middle of the space.
    final flip = Matrix4.diagonal3Values(-1, 1, 1)
      ..setTranslationRaw(size.width, 0, 0);
    for (final path in [big, small]) {
      final width = path == big ? 0.042 : 0.034;
      canvas.drawPath(path, stroke(width));
      canvas.drawPath(path.transform(flip.storage), stroke(width));
    }
  }

  @override
  bool shouldRepaint(_Tiara old) => false;
}

/// Gold rays from the King's crown out to the edges of the card.
class _Sunburst extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.56);
    final r = size.longestSide;
    for (int i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.06), c.dy + r * math.sin(a - 0.06))
        ..lineTo(c.dx + r * math.cos(a + 0.06), c.dy + r * math.sin(a + 0.06))
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(
              colors: [
                i.isEven ? const Color(0x40F9E08C) : const Color(0x26F9E08C),
                const Color(0x06F9E08C),
              ],
            ).createShader(Rect.fromCircle(center: c, radius: r)));
    }
    // A warm glow where the crown sits.
    canvas.drawCircle(
        c,
        size.width * 0.42,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0x33F9E08C), Color(0x00F9E08C)])
              .createShader(Rect.fromCircle(center: c, radius: size.width * 0.42)));
  }

  @override
  bool shouldRepaint(_Sunburst old) => false;
}

/// The Jack's cloth: fine diagonal stripes.
class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1438D98B)
      ..strokeWidth = size.width * 0.05;
    for (double x = -size.height; x < size.width; x += size.width * 0.16) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Stripes old) => false;
}

/// The Queen's cloth: a lattice of fine gold lines with pearls where they
/// cross.
class _Lattice extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x1CF9E08C)
      ..strokeWidth = 1;
    final step = size.width / 4;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
    final pearl = Paint()..color = const Color(0x26FFF8E8);
    for (double y = 0; y <= size.height; y += step / 2) {
      for (double x = (y / (step / 2)).round().isOdd ? step / 2 : 0;
          x <= size.width;
          x += step) {
        canvas.drawCircle(Offset(x, y), 1.4, pearl);
      }
    }
  }

  @override
  bool shouldRepaint(_Lattice old) => false;
}

/// The King's crown: the same crown used across the app (see CrownIcon),
/// in gilt.
class _RoyalCrown extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height * 0.75;
    final top = (size.height - h) / 2;
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
    canvas.translate(0, top);
    canvas.drawPath(path, _gilt(Offset.zero & Size(w, h)));
  }

  @override
  bool shouldRepaint(_RoyalCrown old) => false;
}

/// The back of a card, for hands you can't see and cards being dealt.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: PlayingCardView.heightFor(width),
      decoration: BoxDecoration(
        color: const Color(0xFF5A1620),
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(color: Palette.gold, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: CrownIcon(size: width * 0.5, color: Palette.gold),
    );
  }
}

/// Turns a card over: the back while [face] runs from 0 to 0.5, the front
/// after, like a card flipped on the table.
class FlipIn extends StatelessWidget {
  const FlipIn(
      {super.key, required this.t, required this.front, required this.back});
  final double t;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    final angle = (1 - t) * math.pi;
    final showBack = angle > math.pi / 2;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateY(angle),
      child: showBack
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: back)
          : front,
    );
  }
}

/// A deck being shuffled: the two halves part and riffle together a few
/// times. Plays once.
class ShufflingDeck extends StatelessWidget {
  const ShufflingDeck({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = PlayingCardView.heightFor(width);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, t, _) {
        // Three riffles: the halves swing apart and back.
        final phase = (t * 3) % 1;
        final apart = t >= 1 ? 0.0 : math.sin(phase * math.pi);
        return SizedBox(
          width: width * 2.6,
          height: h + 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 4; i++)
                Transform.translate(
                  offset: Offset(-apart * width * 0.7 + i * 1.5, -i * 1.5),
                  child: Transform.rotate(
                      angle: -apart * 0.18, child: CardBack(width: width)),
                ),
              for (int i = 0; i < 4; i++)
                Transform.translate(
                  offset: Offset(apart * width * 0.7 + i * 1.5,
                      -i * 1.5 - (phase < 0.5 ? 0 : 4)),
                  child: Transform.rotate(
                      angle: apart * 0.18, child: CardBack(width: width)),
                ),
            ],
          ),
        );
      },
    );
  }
}
