/// The courtiers' side of the table (game/host.dart), without widgets.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/game/bot_turn.dart';
import 'package:kings_court/game/dealer.dart';
import 'package:kings_court/game/host.dart';
import 'package:kings_court/models.dart';

GameState table({int seed = 3}) {
  final g = GameState()
    ..seed = seed
    ..target = 6
    ..digital = true
    ..players = [for (var i = 0; i < 4; i++) Player('P$i', colorValue: 0xFF000000 + i)]
    ..seatCourtiers()
    ..addTasksUntilTarget(4, 6);
  dealRound(g, you: 0);
  return g;
}

/// A table crowned with seat 1 as King, and you (seat 0) past your pick.
GameState crowned() {
  final g = table()..crown(1);
  final r = g.round!;
  // Picking starts from the King: if that's you, pass the turn on.
  while (r.pickTurn == 0) {
    r.assign(r.tasks.firstWhere((t) => t.owner == null && r.mayTake(t, 0)), 0);
  }
  return g;
}

void main() {
  test('The game is ready for a courtier once the King is crowned and the deal shown', () {
    final g = table();
    expect(Host.ready(g, dealtFor: g.dealId), isFalse);
    g.crown(g.round!.kingCardHolder);
    expect(Host.ready(g, dealtFor: -1), isFalse);
    expect(Host.ready(g, dealtFor: g.dealId), isTrue);
  });

  test('A courtier whose turn it is picks a task, and the move is sent', () async {
    final g = crowned();
    final sent = <MatchAction>[];
    final host = Host(bot: Bot()..budget = 30, you: 0, send: sent.add);
    final picker = g.round!.pickTurn!;
    final turn = await host.act(g);
    expect(turn.stale, isFalse);
    expect(turn.decision, anyOf(isA<BotPicks>(), isA<BotPasses>()));
    expect(sent.single, anyOf(isA<PickTask>(), isA<Pass>()));
    expect(sent.single.seat, picker);
    expect(host.busy, isFalse);
  });

  test('With nothing moving, a turn that finds the game changed is stale', () async {
    final g = crowned();
    final sent = <MatchAction>[];
    final host = Host(bot: Bot()..budget = 30, you: 0, send: sent.add);
    final turn = await host.act(g, still: () => false);
    expect(turn.stale, isTrue);
    expect(sent, isEmpty);
  });

  test('Before the first pick, courtiers show a card a task needs', () {
    final g = table()..crown(1);
    final host = Host(bot: Bot(), you: 0, send: (_) {});
    final shows = host.openingShows(g);
    final r = g.round!;
    for (final s in shows) {
      expect(s.seat, isNot(0));
      expect(r.revealFor(s.seat, s.card), isNotNull);
    }
    // One card each at most.
    expect(shows.map((s) => s.seat).toSet().length, shows.length);
  });

  test('A round playing itself out plays a legal card for whoever is on turn', () {
    final g = table()..crown(1);
    final host = Host(bot: Bot(), you: 0, send: (_) {});
    final r = g.round!;
    final play = host.playOutStep(g)!;
    expect(play.seat, r.turn);
    expect(r.legalFor(r.turn), contains(play.card));
  });
}
