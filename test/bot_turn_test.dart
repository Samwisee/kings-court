import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/game/bot_turn.dart';
import 'package:kings_court/game/dealer.dart';
import 'package:kings_court/game/state.dart';

/// An on-screen 4-player game, dealt and crowned.
GameState table({int seed = 7}) {
  final g = GameState()
    ..seed = seed
    ..digital = true
    ..players = [for (int i = 0; i < 4; i++) Player('P$i', colorValue: 0xff000000)]
    ..seatCourtiers()
    ..startRound(4, 6);
  dealRound(g);
  g.crown(g.round!.kingCardHolder);
  return g;
}

void main() {
  final bot = Bot()..budget = 40;

  test('A courtier picks a task they may take; you are left to pick yours', () async {
    final g = table();
    final r = g.round!;
    // Whoever picks first.
    final picker = r.pickTurn!;
    final d = await botDecision(g, bot, you: picker == 0 ? 1 : 0);
    expect(d, isA<BotPicks>());
    final pick = d! as BotPicks;
    expect(pick.seat, picker);
    expect(r.canTake(pick.task, picker), isTrue);
    // With you to pick, nothing happens.
    expect(await botDecision(g, bot, you: picker), isNull);
  });

  test('Once every task is taken, a courtier plays a legal card on their turn', () async {
    final g = table();
    final r = g.round!;
    // Hand the tasks round.
    while (r.pickTurn != null) {
      final seat = r.pickTurn!;
      final t = r.tasks.firstWhere((t) => t.owner == null && r.mayTake(t, seat),
          orElse: () => r.tasks.firstWhere((t) => t.owner == null));
      r.assign(t, r.mayTake(t, seat) ? seat : (seat + 1) % 4);
    }
    for (var i = 0; i < r.tasks.length; i++) {
      if (needsX(r.tasks[i].description)) r.announce(i, 1);
    }
    final turn = r.turn;
    final d = await botDecision(g, bot, you: (turn + 1) % 4);
    expect(d, anyOf(isA<BotPlays>(), isA<BotShows>()));
    if (d is BotPlays) {
      expect(d.seat, turn);
      expect(r.legalFor(turn), contains(d.card));
    }
    // On your turn, the table waits for you (a courtier may still show a
    // card between tricks).
    expect(await botDecision(g, bot, you: turn), anyOf(isNull, isA<BotShows>()));
  });
}
