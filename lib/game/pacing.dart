/// How long a courtier takes over a move, so they play like people: a
/// moment for a move with no choice in it, a little less than usual for an
/// easy one, and a visible hesitation over a close call the round turns
/// on, from how their thinking went (engine/race.dart). A courtier
/// hesitates at most once in every [Pacing.spacing] of their moves, and
/// never past a few seconds.
///
/// The pause is the whole time from the courtier's turn coming round to
/// their move: their thinking happens within it. The courtiers don't read
/// each other's pauses (nor yours): it's for the people at the table.
library;

import 'dart:math';

import '../engine/race.dart';

class Pacing {
  Pacing({this.usual = const Duration(milliseconds: 700)});

  /// The time a courtier usually takes over a move.
  Duration usual;

  /// The longest a pause may be, as a multiple of [usual].
  static const most = 3.5;

  /// A courtier hesitates at most once in this many of their moves.
  static const spacing = 4;

  /// Each seat's moves since it last hesitated.
  final _since = <int, int>{};

  /// How long [seat] takes over a move whose thinking went as [thought].
  Duration pauseFor(int seat, Thought thought) {
    final since = _since[seat] ?? spacing;
    final double k;
    if (thought.isForced) {
      k = 0.6;
    } else if (thought.clear) {
      k = 0.85;
    } else if (thought.close && since >= spacing) {
      // Longer the longer the thinking ran past its usual budget.
      k = 1.7 + min(0.9, 0.6 * max(0, thought.effort - 1));
    } else {
      k = 1;
    }
    _since[seat] = k > 1.5 ? 1 : since + 1;
    return Duration(microseconds: (usual.inMicroseconds * min(k, most)).round());
  }
}
