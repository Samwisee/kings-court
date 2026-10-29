/// The line over your hand: what's happening (or a choice with a way out,
/// with its button), the card tracker, and the speech token.
library;

import 'package:flutter/material.dart';

import '../../skin/skin_scope.dart';
import '../widgets.dart';

/// A choice with a way out, its button beside the words.
enum HandChoice {
  /// Show a card, or Skip.
  show,

  /// Take a task, or Pass.
  pass,
}

/// Where the speech token is: [skipping] the offer to show a card before
/// the tasks, [revealing] (choosing a card to show), [asked] for after
/// this trick, [ready] to ask, and whether it's [used] this round.
typedef SpeechToken = ({bool skipping, bool revealing, bool asked, bool ready, bool used});

class HandBar extends StatelessWidget {
  const HandBar({
    super.key,
    required this.choice,
    required this.buttonKey,
    required this.buttonFocused,
    required this.onSkip,
    required this.onPass,
    required this.message,
    required this.lit,
    required this.onTracker,
    required this.speech,
    required this.onSpeak,
  });

  final HandChoice? choice;

  /// On the choice's button, for the keyboard; and whether it's chosen.
  final GlobalKey buttonKey;
  final bool buttonFocused;
  final VoidCallback onSkip;
  final VoidCallback onPass;

  /// What's happening, when there's no choice; in gold when it's [lit]
  /// (your turn, your pick, or showing a card).
  final String message;
  final bool lit;

  /// Opens the card tracker; null when there are no cards to track.
  final VoidCallback? onTracker;

  final SpeechToken speech;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final choice = this.choice;
    final closing = speech.revealing || speech.skipping;
    // One height whatever it holds (two lines of words, a button), so your
    // hand never moves up or down.
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: choice != null
                // A choice with a way out: show a card or skip, pick a task
                // or pass. Both right in the middle, where you're looking,
                // the button always in the same place.
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                            choice == HandChoice.show
                                ? 'Show a card, or'
                                : 'Hold a task to take it, or',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontFamily: skin.bodyFont,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                shadows: skin.feltShadow,
                                color: skin.gold)),
                      ),
                      const SizedBox(width: 8),
                      KeyedSubtree(
                        key: buttonKey,
                        child: choice == HandChoice.show
                            ? GlowButton(
                                key: const ValueKey('skip'),
                                label: 'Skip',
                                focused: buttonFocused,
                                onPressed: onSkip)
                            : GlowButton(
                                key: const ValueKey('pass'),
                                label: 'Pass',
                                focused: buttonFocused,
                                onPressed: onPass),
                      ),
                    ],
                  )
                : AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                        fontFamily: skin.bodyFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        shadows: skin.feltShadow,
                        color: lit ? skin.gold : Colors.white70),
                    child: SuitText(message,
                        style: TextStyle(color: lit ? skin.gold : Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                  ),
          ),
          // Every card: which are played, which are still to come.
          if (onTracker != null)
            IconButton(
              tooltip: 'Card tracker',
              onPressed: onTracker,
              icon: const TrackerIcon(),
            ),
          // The speech token: show one card, once a round.
          SizedBox(
            width: 44,
            // While Skip is showing beside it, this is its X: the two do the
            // same, so they look linked.
            child: IconButton(
              tooltip: speech.skipping
                  ? 'Skip showing a card'
                  : speech.revealing
                      ? 'Don’t show a card'
                      : 'Show a card (once a round)',
              onPressed: onSpeak,
              icon: closing
                  ? Icon(Icons.close_rounded, color: skin.gold)
                  : ShowCardIcon(
                      size: 28,
                      used: speech.used,
                      color: speech.asked
                          ? Colors.white
                          : speech.ready
                              ? skin.gold
                              : Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}
