import 'package:flutter/material.dart';

import '../engine/cards.dart';
import '../theme.dart';
import '../widgets.dart';

/// A playing card drawn on screen. Plain suits show their pip; Court Cards
/// are gilded, with their letter (or the Joker's star) in the middle.
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    required this.card,
    required this.width,
    this.dimmed = false,
    this.glow = false,
    this.edge,
  });

  /// A coloured border, such as the colour of the player who played it.
  final Color? edge;

  final PlayingCard card;
  final double width;

  /// Not playable right now: shaded (but never see-through).
  final bool dimmed;

  /// Won the trick.
  final bool glow;

  static double heightFor(double width) => width * 1.42;

  Color get _ink => card.isCourt
      ? const Color(0xFF4A3000)
      : card.suit.isRed
          ? Palette.cardRed
          : Palette.ink;

  @override
  Widget build(BuildContext context) {
    final h = heightFor(width);
    final corner = TextStyle(
        fontFamily: card.isCourt ? displayFont : bodyFont,
        fontWeight: FontWeight.w800,
        fontSize: width * 0.26,
        height: 1,
        color: _ink);
    return Semantics(
      label: card.label,
      child: Container(
          width: width,
          height: h,
          decoration: BoxDecoration(
            color: card.isCourt ? null : Palette.card,
            gradient: card.isCourt
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF9E08C), Color(0xFFD4A63A)])
                : null,
            borderRadius: BorderRadius.circular(width * 0.1),
            border: Border.all(
                color: edge ??
                    (glow
                        ? Palette.gold
                        : card.isCourt
                            ? Palette.goldDeep
                            : const Color(0xFFD9D2C3)),
                width: glow || edge != null ? 3 : card.isCourt ? 2 : 1),
            boxShadow: [
              if (glow)
                const BoxShadow(color: Palette.gold, blurRadius: 14)
              else
                const BoxShadow(
                    color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          foregroundDecoration: dimmed
              ? BoxDecoration(
                  color: const Color(0x66000000),
                  borderRadius: BorderRadius.circular(width * 0.1))
              : null,
          child: Stack(
            children: [
              Positioned(
                left: width * 0.08,
                top: width * 0.07,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(card.rankLabel, style: corner),
                    Text(card.isCourt ? '♠' : card.suit.symbol,
                        style: corner.copyWith(fontSize: width * 0.22)),
                  ],
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: width * 0.18),
                  child: card == PlayingCard.king
                      ? CrownIcon(size: width * 0.5, color: const Color(0xFF4A3000))
                      : Text(
                          card.isCourt ? card.rankLabel : card.suit.symbol,
                          style: TextStyle(
                              fontFamily: card.isCourt ? displayFont : bodyFont,
                              fontWeight: FontWeight.w900,
                              fontSize: width * 0.52,
                              height: 1,
                              color: _ink)),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

/// The back of a card, for hands you can't see.
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
      ),
      alignment: Alignment.center,
      child: CrownIcon(size: width * 0.5, color: Palette.gold),
    );
  }
}
