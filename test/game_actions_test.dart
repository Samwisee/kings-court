/// The game's actions (game/actions.dart, applied by GameState.apply):
/// crowning, the speech token, marks and their undo at a real table, and
/// the next round, the same whether they come from this device or
/// another.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/decrees.dart';
import 'package:kings_court/game/actions.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/modes/chronicle/chapters.dart';
import 'package:kings_court/modes/modes.dart';

/// A real-table game of four, with a round drawn, uncrowned.
GameState table({GameMode mode = GameMode.free, int target = 8, int seed = 4}) {
  final g = GameState()
    ..mode = mode
    ..seed = seed
    ..target = target
    ..players = [for (var i = 0; i < 4; i++) Player('P$i', colorValue: 0xFF000000 + i)];
  g.startRound(4, target, setup: (rand) => modeOf(mode).roundSetup(g, 4, rand));
  return g;
}

RoundSetup setupFor(GameState g, Random rand, {bool redeal = false}) =>
    modeOf(g.mode).roundSetup(g, g.players.length, rand, redeal: redeal);

void main() {
  test('Nothing is allowed before a round, and the King is crowned once', () {
    final empty = GameState();
    expect(empty.problem(const Crown(0, 1)), isNotNull);
    final g = table();
    expect(g.problem(const Crown(0, 9)), 'No such seat');
    expect(g.problem(const Crown(0, 2)), isNull);
    g.apply(const Crown(0, 2));
    expect(g.round!.king, 2);
    expect(g.round!.pickTurn, isNotNull);
    expect(g.problem(const Crown(0, 1)), 'The King is crowned already');
  });

  test('The speech token is set and taken back, within the decree', () {
    final g = table()..apply(const Crown(0, 1));
    g.apply(const Speak(3, on: true));
    expect(g.round!.spoke[3], isTrue);
    g.apply(const Speak(3, on: false));
    expect(g.round!.spoke[3], isFalse);
    g.round!.decree = Decree.silence;
    expect(g.problem(const Speak(3, on: true)), contains('Silence'));
    expect(g.problem(const Speak(3, on: false)), isNull);
  });

  test('A mark by hand settles the round, and undoing it takes the result back', () {
    final g = table()..apply(const Crown(0, 1));
    final r = g.round!;
    for (var i = 0; i < r.tasks.length; i++) {
      r.tasks[i].owner = i % 4;
    }
    expect(g.problem(const MarkTask(0, 99, TaskStatus.failed)), 'No such task');
    expect(g.problem(const UndoMark(0)), 'Nothing to undo');
    // Every task but the last done: not over yet.
    for (var i = 0; i < r.tasks.length - 1; i++) {
      expect(g.apply(MarkTask(0, i, TaskStatus.completed)), isFalse);
    }
    expect(g.outcome, RoundOutcome.inProgress);
    // The same mark again clears it.
    g.apply(const MarkTask(0, 0, TaskStatus.completed));
    expect(r.tasks[0].isPending, isTrue);
    g.apply(const MarkTask(0, 0, TaskStatus.completed));
    // The last one failed: the round is lost and recorded.
    final last = r.tasks.length - 1;
    expect(g.apply(MarkTask(0, last, TaskStatus.failed)), isTrue);
    expect(g.outcome, RoundOutcome.lost);
    expect(g.losses, 1);
    expect(g.lastMark, isNotNull);
    // Undone: back in play, nothing on the record.
    g.apply(const UndoMark(0));
    expect(r.tasks[last].isPending, isTrue);
    expect(g.outcome, RoundOutcome.inProgress);
    expect(g.losses, 0);
    expect(g.lastMark, isNull);
    expect(g.problem(const UndoMark(0)), 'Nothing to undo');
  });

  test('The next round once this one is over counts a round and waits to be crowned', () {
    final g = table()..apply(const Crown(0, 1));
    final r = g.round!;
    for (final t in r.tasks) {
      t.owner = 0;
      t.status = TaskStatus.completed;
    }
    g.recordOutcomeIfFinished();
    expect(g.roundNumber, 1);
    g.apply(const NextRound(0, target: 10), setup: (rand, {redeal = false}) => setupFor(g, rand, redeal: redeal));
    expect(g.roundNumber, 2);
    expect(g.target, 10);
    expect(g.round, isNot(same(r)));
    expect(g.round!.king, isNull);
    expect(g.round!.tasks.every((t) => t.isPending && t.owner == null), isTrue);
    expect(g.wins, 1);
  });

  test('New tasks mid-round keep the round, the King and the decree', () {
    final g = table()..apply(const Crown(0, 1));
    g.round!.decree = Decree.lateCounsel;
    final before = [for (final t in g.tasks) t.description];
    g.apply(const NextRound(0), setup: (rand, {redeal = false}) => setupFor(g, rand, redeal: redeal));
    expect(g.roundNumber, 1);
    expect(g.round!.king, 1);
    expect(g.round!.pickTurn, 1);
    expect(g.round!.decree, Decree.lateCounsel);
    expect([for (final t in g.tasks) t.description], isNot(before));
  });

  test('The next chapter sets the chapter and its target', () {
    final g = table(mode: GameMode.chronicle, target: chronicle[0].points)..chapter = 0;
    g.apply(const NextRound(0, chapter: 3), setup: (rand, {redeal = false}) => setupFor(g, rand, redeal: redeal));
    expect(g.chapter, 3);
    expect(g.target, chronicle[3].points);
    expect(g.round!.target, chronicle[3].points);
    expect(g.round!.decree, chronicle[3].decree);
    expect(g.round!.sealCount, chronicle[3].seals);
  });

  test('A retry plays the same tasks again; a re-deal draws new ones for a new target', () {
    final g = table()..apply(const Crown(0, 1));
    final tasks = [for (final t in g.tasks) t.description];
    g.apply(const Retry(0));
    expect([for (final t in g.tasks) t.description], tasks);
    expect(g.round!.king, isNull);
    expect(g.roundNumber, 2);
    g.apply(const Crown(0, 2));
    g.apply(const Redeal(0, 11), setup: (rand, {redeal = false}) => setupFor(g, rand, redeal: redeal));
    expect(g.target, 11);
    expect(g.roundNumber, 2, reason: 'the same round, dealt again');
    expect(g.round!.king, isNull, reason: 'whoever is dealt the King card is King');
  });
}
