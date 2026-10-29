/// The card tracker over the on-screen table: a panel in the middle of the
/// screen (tap outside to put it away). Holding its eye, or the space bar,
/// hides it for a moment to see the table behind.
library;

import 'package:flutter/material.dart';

import '../../engine/round.dart';
import '../../game/state.dart';
import 'card_tracker.dart';

class TrackerOverlay extends StatelessWidget {
  const TrackerOverlay({
    super.key,
    required this.trackerKey,
    required this.open,
    required this.peek,
    required this.round,
    required this.you,
    required this.players,
    required this.onClose,
    required this.onPeek,
  });

  /// On the tracker, so the arrow keys can step through it.
  final GlobalKey<CardTrackerState> trackerKey;

  /// Up (it fades in and out); [peek]: hidden for a moment.
  final bool open;
  final bool peek;
  final Round round;
  final int you;
  final List<Player> players;
  final VoidCallback onClose;
  final ValueChanged<bool> onPeek;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: !open,
        child: AnimatedOpacity(
          opacity: open && !peek ? 1 : 0,
          duration: Duration(milliseconds: peek ? 120 : 220),
          curve: Curves.easeOut,
          child: Stack(children: [
            Positioned.fill(
              // No dimming: the table stays in view behind it. A tap
              // anywhere else puts it away.
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose),
            ),
            SafeArea(
              child: Center(
                child: AnimatedScale(
                  scale: open ? 1 : 0.95,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: 400, maxHeight: MediaQuery.sizeOf(context).height * 0.88),
                      child: Material(
                        type: MaterialType.transparency,
                        child: CardTracker(
                          key: trackerKey,
                          cards: round,
                          you: you,
                          players: players,
                          onClose: onClose,
                          onPeek: onPeek,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}
