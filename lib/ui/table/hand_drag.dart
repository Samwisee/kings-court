/// A card of your hand dragged towards the table: which card, how far it
/// has moved, and its slide back into the hand when it wasn't played.
library;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

class HandDrag {
  HandDrag({required TickerProvider vsync, required this.update}) {
    _snap = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 220))
      ..addListener(() =>
          offset.value = _snapFrom * (1 - Curves.easeOutCubic.transform(_snap.value)))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          update(() {
            snapping = null;
            offset.value = Offset.zero;
          });
        }
      });
  }

  /// Changes what's shown on screen.
  final void Function(VoidCallback change) update;

  /// The card being dragged (its id), if any.
  int? card;

  /// The card sliding back into the hand after a drag that didn't play it.
  int? snapping;

  /// How far the dragged card has moved. Only that card listens, so a drag
  /// moves one card, not the whole page.
  final offset = ValueNotifier(Offset.zero);

  Offset _snapFrom = Offset.zero;
  late final AnimationController _snap;

  /// Picks card [id] up.
  void start(int id) => update(() {
        _snap.stop();
        snapping = null;
        card = id;
        offset.value = Offset.zero;
      });

  void move(Offset by) => offset.value += by;

  /// Slides card [id] back to its place in the hand.
  void snapBack(int id) {
    update(() {
      snapping = id;
      _snapFrom = offset.value;
    });
    _snap.forward(from: 0);
  }

  void dispose() {
    _snap.dispose();
    offset.dispose();
  }
}
