import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/cards.dart';
import '../theme.dart';
import '../widgets.dart';
import 'emblems.g.dart';

/// A playing card drawn on screen. Plain suits show their pip. Each Court
/// Card has a face of its own, all framed in gold: the Joker's jester cap
/// on harlequin purple, the Jack's sword and inset shield on striped
/// emerald, the Queen's tiara on a sapphire lattice, and the King's crown
/// in rays on crimson. The emblems and cloths are the printed deck's
/// (tool/print), so the cards on screen and in the box match.
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
    final outer = width * 0.1;
    final r = BorderRadius.circular(outer - outlineWidth);
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
    // A player's colour (or the gold of a suggested card) round the edge:
    // dark lines touch it on both sides, so it reads against anything.
    final coloured = glow || edge != null || marks.isNotEmpty;
    final borderWidth = thick ? 3.0 : card.isCourt ? 2.0 : 1.0;

    return Semantics(
      label: card.spoken,
      value: dimmed ? 'can’t be played now' : glow ? 'suggested' : null,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: h,
        child: InkOutline(
        radius: outer,
        shadows: [
          if (glow)
            const BoxShadow(color: Palette.gold, blurRadius: 14)
          else if (marks.isNotEmpty)
            BoxShadow(color: marks.first.withValues(alpha: 0.85), blurRadius: 10)
          else if (_isKing)
            const BoxShadow(color: Color(0x88D4A63A), blurRadius: 8)
          else
            const BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
        child: Container(
        decoration: BoxDecoration(
          color: card.isCourt ? null : Palette.card,
          gradient: card.isCourt
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _cloth[card.rank - 1])
              : null,
          borderRadius: r,
          border: Border.all(color: borderColour, width: borderWidth),
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
            if (coloured)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(borderWidth),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                          math.max(0.0, outer - outlineWidth - borderWidth)),
                      border: Border.all(color: outlineColour, width: outlineWidth),
                    ),
                  ),
                ),
              ),
            // Every card has an inner frame, as on the printed deck: gold
            // on the Court Cards, a fine dark rule on the rest (unless a
            // player's colour is already framed in dark).
            if (card.isCourt || !coloured)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.all(width * 0.06),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.06),
                  border: Border.all(
                      color: card.isCourt
                          ? const Color(0x99D4A63A)
                          : outlineColour.withValues(alpha: 0.45),
                      width: 1),
                ),
              ),
            ),
            if (card.isCourt)
              Positioned.fill(
                child: CustomPaint(painter: _Emblem(card.rank, _cloth[card.rank - 1][0])),
              )
            else
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
      ),
      ),
    );
  }

  Widget _face() => Text(card.suit.symbol,
      style: TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w900,
          fontSize: width * 0.52,
          height: 1,
          color: _inkColour));
}

const _goldLight = Color(0xFFF9E08C);
const _goldMid = Color(0xFFD4A63A);

/// The printed card is 63 mm wide; the app's card is [width] wide. Sizes
/// below are the printed deck's, in millimetres, scaled to the card.
double _mm(Size size) => size.width / 63;

/// A Court Card's emblem, placed as on the printed card (a touch larger,
/// to read at a glance in a hand).
class _Emblem extends CustomPainter {
  _Emblem(this.rank, this.cloth);

  final int rank;
  final Color cloth;

  static const _grow = 1.15;

  @override
  void paint(Canvas canvas, Size size) {
    final mm = _mm(size) * _grow;
    final (bounds, anchor, box, draw) = switch (rank) {
      1 => (jesterBounds, jesterAnchor, emblemBox, paintJester),
      2 => (jackBounds, jackAnchor, jackBox, paintJack),
      3 => (tiaraBounds, tiaraAnchor, emblemBox, paintTiara),
      _ => (kingBounds, kingAnchor, kingBox, paintKing),
    };
    final s = math.min(box.width * mm / bounds.width, box.height * mm / bounds.height);
    // The outline is the same weight whatever the emblem's scale, and never
    // thinner than a hairline.
    final ow = 2 * math.max(0.8, outlineMm * _mm(size)) / s;
    final centre = Offset(size.width / 2, size.height / 2 + size.width * 0.06);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(s);
    canvas.translate(-anchor.dx, -anchor.dy);
    // On its own layer: the Jack's inset shield is a window to the cloth.
    canvas.saveLayer(bounds.inflate(ow * 2), Paint());
    draw(canvas, ow, cloth);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Emblem old) => old.rank != rank || old.cloth != cloth;
}

/// The Joker's cloth: a field of diamonds.
class _Harlequin extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dw = size.width / 4, dh = size.height / 5;
    final dark = Paint()..color = const Color(0x381A0C2A);
    final light = Paint()..color = const Color(0x14F9E08C);
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
        canvas.drawPath(p, (row + col).isEven ? dark : light);
      }
    }
  }

  @override
  bool shouldRepaint(_Harlequin old) => false;
}

/// The King's cloth: ten rays from the crown, lit ones faint white (the
/// Jack's stripes' white at the edges, brighter at the crown) edged in fine
/// gold, a dark one running straight down; and a soft halo behind the crown.
class _Sunburst extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mm = _mm(size);
    final c = Offset(size.width / 2, 46.8 * mm);
    final r = size.longestSide * 1.5;
    const n = 10;
    const step = 2 * math.pi / n;
    const half = step * 0.3 / 2;
    final fade = RadialGradient(
      colors: const [Color(0x42FFFFFF), Color(0x12FFFFFF), Color(0x12FFFFFF)],
      stops: const [0, 0.5, 1],
    ).createShader(Rect.fromCircle(center: c, radius: 50.8 * mm));
    final edge = Paint()
      ..color = _goldLight.withValues(alpha: 0.7)
      ..strokeWidth = math.max(0.6, 0.26 * mm);
    for (int i = 0; i < n; i++) {
      final a = i * step + math.pi / 2 + step / 2;
      final p1 = c + Offset(math.cos(a - half), math.sin(a - half)) * r;
      final p2 = c + Offset(math.cos(a + half), math.sin(a + half)) * r;
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(p1.dx, p1.dy)
            ..lineTo(p2.dx, p2.dy)
            ..close(),
          Paint()..shader = fade);
    }
    final glow = Offset(c.dx, c.dy - 4.7 * mm);
    canvas.drawCircle(
        glow,
        23.5 * mm,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)])
              .createShader(Rect.fromCircle(center: glow, radius: 23.5 * mm)));
    for (int i = 0; i < n; i++) {
      final a = i * step + math.pi / 2 + step / 2;
      for (final e in [a - half, a + half]) {
        canvas.drawLine(c, c + Offset(math.cos(e), math.sin(e)) * r, edge);
      }
    }
  }

  @override
  bool shouldRepaint(_Sunburst old) => false;
}

/// The Jack's cloth: fine diagonal stripes in faint white.
class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x12FFFFFF)
      ..strokeWidth = size.width * 0.05;
    for (double x = -size.height; x < size.width; x += size.width * 0.16) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Stripes old) => false;
}

/// The Queen's cloth: a soft glow behind the tiara, and a lattice of fine
/// gold lines with a gold pearl on every crossing, one crossing at the
/// card's centre.
class _Lattice extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mm = _mm(size);
    final glow = Offset(size.width / 2, 43.1 * mm);
    canvas.drawCircle(
        glow,
        24.8 * mm,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x21FFFFFF), Color(0x00FFFFFF)])
              .createShader(Rect.fromCircle(center: glow, radius: 24.8 * mm)));
    final step = 22.83 * mm;
    final c = size.center(Offset.zero);
    final line = Paint()
      ..color = _goldLight.withValues(alpha: 0.5)
      ..strokeWidth = math.max(0.6, 0.18 * mm);
    final pearl = Paint()..color = _goldMid;
    final reach = size.width + size.height;
    final k = (reach / step).ceil();
    for (int i = -k; i <= k; i++) {
      // lines x - y = c.dx - c.dy + i step, and x + y = c.dx + c.dy + i step
      final a = c.dx - c.dy + i * step;
      final b = c.dx + c.dy + i * step;
      canvas.drawLine(Offset(a - 1, -1), Offset(a + size.height + 1, size.height + 1), line);
      canvas.drawLine(Offset(b + 1, -1), Offset(b - size.height - 1, size.height + 1), line);
    }
    for (int i = -k; i <= k; i++) {
      for (int j = -k; j <= k; j++) {
        final a = c.dx - c.dy + i * step;
        final b = c.dx + c.dy + j * step;
        final p = Offset((a + b) / 2, (b - a) / 2);
        if (p.dx >= -2 && p.dx <= size.width + 2 && p.dy >= -2 && p.dy <= size.height + 2) {
          canvas.drawCircle(p, math.max(1.0, 0.5 * mm), pearl);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Lattice old) => false;
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
        border: Border.all(color: Palette.gold, width: 1.5 + outlineWidth),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(color: outlineColour, width: outlineWidth),
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
    // Once face up, no 3D transform at all: on the web a lingering
    // perspective layer can cut a card off as it's drawn.
    if (t >= 1) return front;
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
