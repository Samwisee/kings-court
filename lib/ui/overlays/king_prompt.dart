/// "Who holds the King card?": the deck in the middle of the table before
/// the King is crowned, with what to do.
library;

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets.dart';

class KingPrompt extends StatelessWidget {
  const KingPrompt(
      {super.key,
      required this.maxWidth,
      required this.cardWidth,
      required this.onScreen,
      required this.players});

  final double maxWidth;

  /// The table's card width (the deck is drawn a little smaller).
  final double cardWidth;
  final bool onScreen;
  final int players;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DeckStack(width: cardWidth * 0.75),
          const SizedBox(height: 18),
          const Text('Who holds the King card?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            onScreen
                ? 'The cards are dealt. Whoever holds the King card will be crowned.'
                : players == 2
                ? 'Tap their seat to crown the King and deal the tasks. If the Dummy has it, choose a King together.'
                : 'Tap their seat to crown the King and deal the tasks.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, height: 1.35, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
