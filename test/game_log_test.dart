/// The record of each round played (platform/game_log.dart): what it holds
/// (and what it leaves out), that it reads back, and that a table's rounds
/// are each recorded once with their own moves.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/game/actions.dart';
import 'package:kings_court/game/setup.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/modes/modes.dart';
import 'package:kings_court/net/headless_table.dart';
import 'package:kings_court/net/table_link.dart';
import 'package:kings_court/platform/game_log.dart';

/// A game of courtiers alone, on screen, after its first round.
Future<(GameState, LocalLink, HeadlessTable)> oneRound({int seed = 7}) async {
  final rules = modeOf(GameMode.free).rules;
  final link = LocalLink();
  final game = GameSetup(
          mode: GameMode.free,
          names: const ['Ann', 'Ben', 'Cal', 'Dee'],
          target: 6,
          seed: seed,
          digital: true)
      .start(rules);
  final table = HeadlessTable(game, link, rules, bot: Bot()..budget = 16);
  await table.playRound();
  return (game, link, table);
}

void main() {
  setUp(GameLog.recent.clear);

  test('A round’s record holds the deal, the tasks, the moves and the result, and no names', () async {
    final (game, link, table) = await oneRound();
    GameLog.player = GameLog.newPlayerId(Random(1));
    final r = GameLog.record(game, moves: link.history, people: const [0], onScreen: true);
    final text = jsonEncode(r);
    for (final name in ['Ann', 'Ben', 'Cal', 'Dee']) {
      expect(text, isNot(contains(name)), reason: 'no names');
    }
    expect(r['v'], GameLog.version);
    expect(r['mode'], 'free');
    expect(r['players'], 4);
    expect(r['people'], [0]);
    expect(r['player'], hasLength(16));
    expect(r['outcome'], anyOf('won', 'lost'));
    expect(r['moves'], hasLength(link.history.length));
    // The round reads back as it ended.
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final back = Round.fromJson(Map<String, dynamic>.from(decoded['round'] as Map));
    expect(back.tasks.map((t) => t.description), game.round!.tasks.map((t) => t.description));
    expect(back.tricks, hasLength(game.round!.tricks.length));
    expect(back.outcome, game.round!.outcome);
    table.dispose();
  });

  test('A table’s rounds are each recorded once, each with its own moves', () async {
    final (game, link, table) = await oneRound(seed: 9);
    final logger = RoundLogger();
    logger.over(game, link.history, you: 0);
    logger.over(game, link.history, you: 0);
    expect(GameLog.recent, hasLength(1), reason: 'once a round');
    final first = link.history.length;
    expect(GameLog.recent.last['moves'], hasLength(first));
    // The next round: only the moves since.
    link.send(const NextRound(0));
    await table.playRound();
    logger.over(game, link.history, you: 0);
    expect(GameLog.recent, hasLength(2));
    expect(GameLog.recent.last['moves'], hasLength(link.history.length - first));
    // A new game starts again from its own first move.
    final (other, otherLink, otherTable) = await oneRound(seed: 11);
    logger.over(other, otherLink.history, you: null);
    expect(GameLog.recent.last['moves'], hasLength(otherLink.history.length));
    expect(GameLog.recent.last['people'], [0, 1, 2, 3], reason: 'at a real table every seat is a person');
    expect(GameLog.recent.last['onScreen'], isFalse);
    table.dispose();
    otherTable.dispose();
  });

  test('An anonymous id is sixteen hex digits, new each time', () {
    final a = GameLog.newPlayerId();
    expect(a, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(GameLog.newPlayerId(), isNot(a));
  });
}
