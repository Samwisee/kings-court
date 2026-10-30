import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/race.dart';
import 'package:kings_court/game/pacing.dart';

/// Runs [race] with each option scoring its fixed rate in [rates].
Thought run(Race<String> race, Map<String, double> rates) {
  for (var batch = race.next(); batch.isNotEmpty; batch = race.next()) {
    for (final (o, _, n) in batch) {
      race.add(o, rates[o]!, n);
    }
  }
  return race.thought;
}

void main() {
  test('A race with a clear winner stops early', () {
    final race = Race(['a', 'b', 'c'], 900);
    final t = run(race, {'a': 0.9, 'b': 0.2, 'c': 0.1});
    expect(t.clear, isTrue);
    expect(t.close, isFalse);
    expect(race.spent, lessThan(900));
    expect(race.best(Random(1)), 'a');
  });

  test('A close call the round turns on is thought about for longer, up to the stretch', () {
    final race = Race(['a', 'b', 'c'], 900);
    final t = run(race, {'a': 0.5, 'b': 0.49, 'c': 0.1});
    expect(t.close, isTrue);
    expect(race.spent, greaterThan(900));
    expect(race.spent, lessThanOrEqualTo(900 * 2.5 + 2 * 112));
  });

  test("A close call that can't change the outcome isn't stretched", () {
    final sure = Race(['a', 'b'], 900);
    run(sure, {'a': 1.0, 'b': 0.99});
    expect(sure.spent, lessThanOrEqualTo(900));
    final lost = Race(['a', 'b'], 900);
    run(lost, {'a': 0.01, 'b': 0.0});
    expect(lost.spent, lessThanOrEqualTo(900));
  });

  test('Without adapting, a race spends its budget and no more', () {
    final race = Race(['a', 'b', 'c'], 900, adaptive: false);
    final t = run(race, {'a': 0.5, 'b': 0.49, 'c': 0.1});
    expect(t.clear, isFalse);
    expect(race.spent, inInclusiveRange(850, 950));
  });

  test('Every option is played from where it left off, so the n-th playouts match', () {
    final race = Race(['a', 'b'], 200, adaptive: false);
    final from = <String, List<int>>{'a': [], 'b': []};
    for (var batch = race.next(); batch.isNotEmpty; batch = race.next()) {
      for (final (o, f, n) in batch) {
        from[o]!.add(f);
        race.add(o, 0.5, n);
      }
    }
    expect(from['a'], from['b']);
  });

  test('Courtiers take a moment over no choice, less over an easy one, longer over a close call', () {
    final pace = Pacing();
    expect(pace.pauseFor(1, Thought.forced), lessThan(const Duration(milliseconds: 700)));
    expect(pace.pauseFor(1, const Thought(options: 3, spent: 400, budget: 900, clear: true)),
        lessThan(const Duration(milliseconds: 700)));
    final close = pace.pauseFor(1, const Thought(options: 3, spent: 2000, budget: 900, close: true));
    expect(close, greaterThan(const Duration(milliseconds: 1050)));
    expect(close, lessThanOrEqualTo(const Duration(milliseconds: 2450)));
    // Not twice running from the same courtier; another may.
    expect(pace.pauseFor(1, const Thought(options: 3, spent: 2000, budget: 900, close: true)),
        const Duration(milliseconds: 700));
    expect(pace.pauseFor(2, const Thought(options: 3, spent: 2000, budget: 900, close: true)),
        greaterThan(const Duration(milliseconds: 1050)));
  });
}
