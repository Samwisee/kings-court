/// A card in your hand: dealt face down and turned up one by one, a
/// little larger while dragged, with the key that plays it in its corner
/// when the shortcuts are showing.
library;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../cards/card_view.dart';
import '../widgets.dart';

class HandCard extends StatelessWidget {
  const HandCard({
    super.key,
    required this.card,
    required this.width,
    required this.index,
    required this.dealId,
    required this.lifted,
    required this.dimmed,
    required this.glow,
    required this.marks,
    required this.keyLabel,
  });

  final PlayingCard card;
  final double width;

  /// Its place in the hand, left to right: the cards turn up in order.
  final int index;

  /// The deal it came in (a new deal turns the cards up again).
  final int dealId;

  /// Being dragged.
  final bool lifted;
  final bool dimmed;
  final bool glow;

  /// The colours of the players whose tasks need it.
  final List<Color> marks;

  /// The key that plays it, or null.
  final String? keyLabel;

  @override
  Widget build(BuildContext context) {
    final key = keyLabel;
    return AnimatedScale(
      scale: lifted ? 1.1 : 1,
      duration: const Duration(milliseconds: 120),
      child: TweenAnimationBuilder<double>(
        key: ValueKey('hand-$dealId-${card.id}'),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 420 + index * 70),
        curve: Interval((index * 70) / (420 + index * 70), 1, curve: Curves.easeOut),
        builder: (context, f, child) =>
            FlipIn(t: f, front: child!, back: CardBack(width: width)),
        child: Stack(clipBehavior: Clip.none, children: [
          PlayingCardView(card: card, width: width, dimmed: dimmed, glow: glow, marks: marks),
          if (key != null)
            Positioned(
              left: width * 0.08,
              bottom: width * 0.08,
              child: KeyCap(key, size: width * 0.2),
            ),
        ]),
      ),
    );
  }
}
