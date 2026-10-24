import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/cards.dart';
import '../theme.dart';
import '../widgets.dart';

/// A playing card drawn on screen. Plain suits show their pip. The Court
/// Cards have faces of their own: the Joker in motley purple, the J♠ with a
/// shield, the Q♠ with a rose, and the K♠ in royal red velvet with a
/// radiant crown.
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

  static const _velvet = [Color(0xFF8E1B2C), Color(0xFF3A0610)];
  static const _gold = [Color(0xFFF9E08C), Color(0xFFD4A63A)];
  static const _motley = [Color(0xFF6B3FA0), Color(0xFF2E1748)];
  static const _ink = Color(0xFF4A3000);

  bool get _isKing => card == PlayingCard.king;
  bool get _isJoker => card == PlayingCard.joker;

  Color get _inkColour => card.isCourt
      ? (_isKing || _isJoker ? Palette.gold : _ink)
      : card.suit.isRed
          ? Palette.cardRed
          : Palette.ink;

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
                    ? (_isKing ? Palette.gold : Palette.goldDeep)
                    : const Color(0xFFD9D2C3));
    final thick = glow || edge != null || marks.isNotEmpty || _isKing;

    return Semantics(
      label: card.label,
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          color: card.isCourt ? null : Palette.card,
          gradient: card.isCourt
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isKing
                      ? _velvet
                      : _isJoker
                          ? _motley
                          : _gold)
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
            // The King's inner gold frame.
            if (_isKing)
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
    final s = width * 0.5;
    if (!card.isCourt) {
      return Text(card.suit.symbol,
          style: TextStyle(
              fontFamily: bodyFont,
              fontWeight: FontWeight.w900,
              fontSize: width * 0.52,
              height: 1,
              color: _inkColour));
    }
    return switch (card.rank) {
      1 => Icon(Icons.theater_comedy_rounded, size: s, color: Palette.gold),
      2 => Icon(Icons.shield_rounded, size: s, color: _ink),
      3 => Icon(Icons.local_florist_rounded, size: s, color: Palette.cardRed),
      _ => SizedBox(
          width: width * 0.8,
          height: width * 0.7,
          child: CustomPaint(
            painter: _Sunburst(),
            child: Center(child: CrownIcon(size: s * 1.05, color: Palette.gold)),
          ),
        ),
    };
  }
}

/// Gold rays behind the King's crown.
class _Sunburst extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.62;
    final paint = Paint()..color = const Color(0x55F9E08C);
    for (int i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.12), c.dy + r * math.sin(a - 0.12))
        ..lineTo(c.dx + r * math.cos(a + 0.12), c.dy + r * math.sin(a + 0.12))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_Sunburst old) => false;
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
