/// The same seed plays the same game: two tables started from one setup,
/// courtiers in every seat, make the same moves and end in the same
/// state. A replay of those moves rebuilds that state too.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/game/setup.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/modes/modes.dart';
import 'package:kings_court/net/headless_table.dart';
import 'package:kings_court/net/replay.dart';
import 'package:kings_court/net/table_link.dart';

const setup = GameSetup(
    mode: GameMode.free,
    names: ['P1', 'P2', 'P3', 'P4'],
    target: 6,
    seed: 2024,
    digital: true);

/// Plays [rounds] rounds on a fresh headless table; returns the game and
/// its moves.
Future<(GameState, List<Move>)> play({int rounds = 2, int seed = 2024}) async {
  final rules = modeOf(GameMode.free).rules;
  final link = LocalLink();
  final game = GameSetup(
          mode: setup.mode, names: setup.names, target: setup.target, seed: seed, digital: true)
      .start(rules);
  final table = HeadlessTable(game, link, rules, bot: Bot()..budget = 24);
  await table.playRounds(rounds);
  expect(table.refused, isEmpty);
  table.dispose();
  return (game, link.history);
}

String state(GameState g) => jsonEncode(g.toJson());

void main() {
  test('A setup travels as JSON and starts the same game', () {
    final back = GameSetup.fromJson(jsonDecode(jsonEncode(setup.toJson())) as Map<String, dynamic>);
    expect(back.toJson(), setup.toJson());
    final rules = modeOf(GameMode.free).rules;
    final a = setup.start(rules), b = back.start(rules);
    expect(state(a), state(b));
    expect(a.setup, isNotNull);
    expect(a.players.first.name, 'You');
    expect(a.players.skip(1).map((p) => p.name), everyElement(isNot('You')));
  });

  test('Two tables from one seed make the same moves and end the same', () async {
    final (a, movesA) = await play();
    final (b, movesB) = await play();
    expect(movesA, isNotEmpty);
    expect(a.roundNumber, 2);
    expect([for (final m in movesA) m.toJson()], [for (final m in movesB) m.toJson()]);
    expect(state(a), state(b));
    // Another seed plays another game.
    final (c, movesC) = await play(seed: 99);
    expect([for (final m in movesC) m.toJson()], isNot([for (final m in movesA) m.toJson()]));
    expect(state(c), isNot(state(a)));
  });

  test('A replay of the moves rebuilds the game', () async {
    final (a, moves) = await play();
    final skipped = <Move>[];
    final again = replay(a.setup!, moves, rules: modeOf(GameMode.free).rules, skipped: skipped);
    expect(skipped, isEmpty);
    expect(state(again), state(a));
    expect(again.round!.hands, a.round!.hands);
    expect(again.outcome, a.outcome);
    // Half the moves: half the game, still legal.
    final half = replay(a.setup!, moves.take(moves.length ~/ 2),
        rules: modeOf(GameMode.free).rules, skipped: skipped);
    expect(skipped, isEmpty);
    expect(half.roundNumber, lessThanOrEqualTo(a.roundNumber));
  });

  test('Moves travel as JSON and replay the same', () async {
    final (a, moves) = await play(rounds: 1);
    final wire = [for (final m in moves) jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>];
    final back = [for (final j in wire) Move.fromJson(j)!];
    final again = replay(a.setup!, back, rules: modeOf(GameMode.free).rules);
    expect(state(again), state(a));
    expect(again.round!.outcome, isNot(RoundOutcome.inProgress));
  });
}
