import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/game/bot_turn.dart';
import 'package:kings_court/models.dart';

/// An on-screen 4-player game, dealt and crowned, with the cards' view of
/// it (what the page's _matchView gives the bots).
(GameState, MatchState) table({int seed = 7, int you = 0}) {
  final g = GameState()
    ..seed = seed
    ..players = [for (int i = 0; i < 4; i++) Player('P$i', color: const Color(0xff000000))]
    ..seatCourtiers()
    ..addTasksUntilTarget(4, 6);
  g.cards = MatchState(players: 4, target: 6)..dealFor(g.dealId, g.dealRandom());
  g.setKing(g.cards!.king);
  final c = g.cards!;
  c.tasks = [
    for (final t in g.tasks) MatchTask(t, owner: t.assignedPlayerIndex, x: c.announced[t.description])
  ];
  c.pickTurn = g.pickTurn;
  c.takeRule = (i, seat) => g.canTake(g.tasks[i], seat);
  return (g, c);
}

void main() {
  final bot = Bot()..budget = 40;

  test('A courtier picks a task they may take; you are left to pick yours', () async {
    final (g, c) = table();
    // Whoever picks first.
    final picker = g.pickTurn!;
    final d = await botDecision(g, c, bot, you: picker == 0 ? 1 : 0);
    expect(d, isA<BotPicks>());
    final pick = d as BotPicks;
    expect(pick.seat, picker);
    expect(g.canTake(g.tasks[pick.task], picker), isTrue);
    // With you to pick, nothing happens.
    expect(await botDecision(g, c, bot, you: picker), isNull);
  });

  test('Once every task is taken, a courtier plays a legal card on their turn', () async {
    final (g, c) = table();
    // Hand the tasks round, then refresh the view the way the page does.
    while (g.pickTurn != null) {
      final seat = g.pickTurn!;
      final t = g.tasks.firstWhere((t) => t.assignedPlayerIndex == null && g.canTake(t, seat),
          orElse: () => g.tasks.firstWhere((t) => t.assignedPlayerIndex == null));
      g.assign(t, g.canTake(t, seat) ? seat : (seat + 1) % 4);
    }
    for (final t in g.tasks) {
      if (needsX(t.description)) c.announced[t.description] = 1;
    }
    c.tasks = [for (final t in g.tasks) MatchTask(t, owner: t.assignedPlayerIndex, x: c.announced[t.description])];
    c.pickTurn = null;
    final turn = c.turn;
    final d = await botDecision(g, c, bot, you: (turn + 1) % 4);
    expect(d, anyOf(isA<BotPlays>(), isA<BotShows>()));
    if (d is BotPlays) {
      expect(d.seat, turn);
      expect(c.legalFor(turn), contains(d.card));
    }
    // On your turn, the table waits.
    expect(await botDecision(g, c, bot, you: turn), isNull);
  });
}
