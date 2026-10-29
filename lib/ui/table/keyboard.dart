/// Choosing with the keyboard on the on-screen table: the keys that play
/// your cards, and how the arrow keys move between the places to stop.
library;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

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
