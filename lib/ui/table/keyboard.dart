/// Choosing with the keyboard on the on-screen table: the keys that play
/// your cards, and how the arrow keys move between the places to stop.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AxisDirection;

import '../round_table/geometry.dart';

/// The stop in [stops] nearest [r]: across first, then up or down.
KbStop closestStop(List<KbStop> stops, Rect r) {
  double d(KbStop st) =>
      (st.rect.center.dx - r.center.dx).abs() +
      (st.rect.center.dy - r.center.dy).abs() * 0.25;
  return stops.reduce((a, b) => d(a) <= d(b) ? a : b);
}

/// [stops] as they're read: row by row from the top, each row left to
/// right (the tasks are packed in columns of different heights, so a
/// row is whatever overlaps it side by side).
List<KbStop> readingOrder(List<KbStop> stops) {
  final rest = [...stops]..sort((a, b) => a.rect.top.compareTo(b.rect.top));
  final out = <KbStop>[];
  while (rest.isNotEmpty) {
    final first = rest.first;
    final row = [
      for (final st in rest)
        if (st.rect.top < first.rect.bottom - 4) st
    ]..sort((a, b) => a.rect.left.compareTo(b.rect.left));
    out.addAll(row);
    rest.removeWhere(row.contains);
  }
  return out;
}

/// The keys that play the cards in your hand, left to right.
final cardKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.minus,
  LogicalKeyboardKey.equal,
  LogicalKeyboardKey.keyQ,
  LogicalKeyboardKey.keyW,
  LogicalKeyboardKey.keyE,
];

/// What's printed on each of those keys.
const cardKeyLabels = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 'Q', 'W', 'E'];

/// Which way an arrow key goes, or null for another key.
AxisDirection? arrowStep(LogicalKeyboardKey key) => switch (key) {
      LogicalKeyboardKey.arrowUp => AxisDirection.up,
      LogicalKeyboardKey.arrowDown => AxisDirection.down,
      LogicalKeyboardKey.arrowLeft => AxisDirection.left,
      LogicalKeyboardKey.arrowRight => AxisDirection.right,
      _ => null,
    };

/// Where an arrow key [step] goes from [here] (the stop chosen now, if
/// it's still there), among [stops]: up and down to the nearest row that
/// way, then whatever is nearest along it; left and right along the row
/// [here] is on ([row] if nothing is chosen), running on round. [last] is
/// where the last choice was and [hand] where your hand is, to start from
/// when nothing is chosen. [handled] is whether the key was used; [to] is
/// null when it was used but there was nowhere to go.
({bool handled, KbStop? to}) arrowMove(List<KbStop> stops,
    {required KbStop? here,
    required Rect? last,
    required int row,
    required Rect? hand,
    required AxisDirection step}) {
  if (step == AxisDirection.up || step == AxisDirection.down) {
    final up = step == AxisDirection.up;
    // Nothing chosen yet: start from your hand.
    final hand0 = [for (final st in stops) if (st.row == 0) st];
    if (here == null && last == null && !up && hand0.isNotEmpty) {
      return (handled: true, to: hand0[hand0.length ~/ 2]);
    }
    final from = here?.rect ?? last ?? hand;
    if (from == null) return (handled: false, to: null);
    final ahead = [
      for (final st in stops)
        if (!identical(st, here) &&
            (up ? st.rect.center.dy < from.top + 4 : st.rect.center.dy > from.bottom - 4))
          st
    ];
    if (ahead.isEmpty) return (handled: true, to: null);
    // The nearest row that way, then the nearest thing along it.
    double gap(KbStop st) => up ? from.top - st.rect.bottom : st.rect.top - from.bottom;
    final nearest = ahead.reduce((a, b) => gap(a) <= gap(b) ? a : b);
    final line = [
      for (final st in ahead)
        if (st.rect.top < nearest.rect.bottom && st.rect.bottom > nearest.rect.top) st
    ];
    return (handled: true, to: closestStop(line, from));
  }
  final by = step == AxisDirection.right ? 1 : -1;
  var kind = here?.row ?? row;
  if (!stops.any((st) => st.row == kind)) kind = 0;
  final same = readingOrder([for (final st in stops) if (st.row == kind) st]);
  if (same.isEmpty) return (handled: false, to: null);
  final at = here == null ? -1 : same.indexWhere((st) => st.row == here.row && st.item == here.item);
  // Nothing chosen yet (or it's gone): start nearest the last choice.
  if (at < 0) {
    return (
      handled: true,
      to: last == null ? same[by > 0 ? 0 : same.length - 1] : closestStop(same, last)
    );
  }
  return (handled: true, to: same[(at + by) % same.length]);
}
