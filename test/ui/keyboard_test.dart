/// The arrow keys on the on-screen table (ui/table/keyboard.dart): from
/// your hand up to the button and the tasks, along a row and round, and
/// where they start when nothing is chosen.
library;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/ui/round_table/geometry.dart';
import 'package:kings_court/ui/table/keyboard.dart';

void main() {
  // Three cards in a hand along the bottom, the Pass button over it, and
  // two rows of tasks above.
  final cards = [for (var i = 0; i < 3; i++) KbStop(0, 'card$i', Rect.fromLTWH(100.0 + i * 60, 500, 50, 70))];
  const button = KbStop(2, null, Rect.fromLTWH(160, 430, 60, 30));
  final tasks = [
    const KbStop(1, 'a', Rect.fromLTWH(40, 100, 100, 40)),
    const KbStop(1, 'b', Rect.fromLTWH(160, 100, 100, 60)),
    const KbStop(1, 'c', Rect.fromLTWH(40, 200, 100, 40)),
  ];
  final stops = [...tasks, button, ...cards];
  const hand = Rect.fromLTWH(80, 490, 300, 90);

  ({bool handled, KbStop? to}) move(KbStop? here, AxisDirection step, {Rect? last, int row = 0}) =>
      arrowMove(stops, here: here, last: last, row: row, hand: hand, step: step);

  test('With nothing chosen, down starts in the middle of your hand', () {
    expect(move(null, AxisDirection.down).to, same(cards[1]));
  });

  test('Up goes to the nearest row that way, then the nearest along it', () {
    expect(move(cards[1], AxisDirection.up).to, same(button));
    // Over the button: the lower row of tasks, then the upper one.
    expect(move(button, AxisDirection.up).to, same(tasks[2]));
    expect(move(tasks[2], AxisDirection.up).to, same(tasks[0]));
    // Nothing above the top row: the key is used, but nothing moves.
    final top = move(tasks[0], AxisDirection.up);
    expect(top.handled, isTrue);
    expect(top.to, isNull);
  });

  test('Left and right run along the row in reading order, and round', () {
    expect(move(cards[0], AxisDirection.right).to, same(cards[1]));
    expect(move(cards[2], AxisDirection.right).to, same(cards[0]));
    expect(move(cards[0], AxisDirection.left).to, same(cards[2]));
    // The tasks read row by row: a, b (side by side), then c.
    expect(move(tasks[1], AxisDirection.right).to, same(tasks[2]));
  });

  test('With the choice gone, left and right start nearest the last one', () {
    expect(move(null, AxisDirection.right, last: cards[2].rect).to, same(cards[2]));
    expect(move(null, AxisDirection.right).to, same(cards[0]));
    expect(move(null, AxisDirection.left).to, same(cards[2]));
  });

  test('Only the arrows step', () {
    expect(arrowStep(LogicalKeyboardKey.arrowUp), AxisDirection.up);
    expect(arrowStep(LogicalKeyboardKey.enter), isNull);
  });
}
