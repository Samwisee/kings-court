/// The courtiers' side of the table (game/host.dart), without widgets.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/game/bot_turn.dart';
import 'package:kings_court/game/dealer.dart';
import 'package:kings_court/game/host.dart';
import 'package:kings_court/models.dart';

GameState table({int seed = 3}) {
  final g = GameState()
    ..seed = seed
    ..target = 6
    ..players = [for (var i = 0; i < 4; i++) Player('P$i', colorValue: 0xFF000000 + i)]
    ..seatCourtiers()
    ..addTasksUntilTarget(4, 6)
    ..cards = MatchState(players: 4, target: 6);
  dealRound(g, you: 0);
  return g;
}

void main() {
  test('The game is ready for a courtier once the King is crowned and the deal shown', () {
    final g = table();
    expect(Host.ready(g, dealtFor: g.dealId), isFalse);
    g.setKing(g.cards!.king);
    expect(Host.ready(g, dealtFor: -1), isFalse);
    expect(Host.ready(g, dealtFor: g.dealId), isTrue);
  });

  test('A courtier whose turn it is picks a task, and the move is sent', () async {
    final g = table()..setKing(1);
    // Picking starts from the King: if that's you, pass the turn on.
    while (g.pickTurn == 0) {
      g.assign(g.tasks.firstWhere((t) => t.assignedPlayerIndex == null && g.canTake(t, 0)), 0);
    }
    final sent = <MatchAction>[];
    final host = Host(bot: Bot()..budget = 30, you: 0, send: sent.add);
    final picker = g.pickTurn!;
    final turn = await host.act(g);
    expect(turn.stale, isFalse);
    expect(turn.decision, anyOf(isA<BotPicks>(), isA<BotPasses>()));
    expect(sent.single, anyOf(isA<PickTask>(), isA<Pass>()));
    expect(sent.single.seat, picker);
    expect(host.busy, isFalse);
  });

  test('With nothing moving, a turn that finds the game changed is stale', () async {
    final g = table()..setKing(1);
    while (g.pickTurn == 0) {
      g.assign(g.tasks.firstWhere((t) => t.assignedPlayerIndex == null && g.canTake(t, 0)), 0);
    }
    final sent = <MatchAction>[];
    final host = Host(bot: Bot()..budget = 30, you: 0, send: sent.add);
    final turn = await host.act(g, still: () => false);
    expect(turn.stale, isTrue);
    expect(sent, isEmpty);
  });

  test('Before the first pick, courtiers show a card a task needs', () {
    final g = table()..setKing(1);
    final host = Host(bot: Bot(), you: 0, send: (_) {});
    final shows = host.openingShows(g);
    final c = g.cards!;
    for (final s in shows) {
      expect(s.seat, isNot(0));
      expect(c.revealFor(s.seat, s.card), isNotNull);
    }
    // One card each at most.
    expect(shows.map((s) => s.seat).toSet().length, shows.length);
  });

  test('A round playing itself out plays a legal card for whoever is on turn', () {
    final g = table()..setKing(1);
    final host = Host(bot: Bot(), you: 0, send: (_) {});
    final c = g.cards!;
    final play = host.playOutStep(g)!;
    expect(play.seat, c.turn);
    expect(c.legalFor(c.turn), contains(play.card));
  });
}
