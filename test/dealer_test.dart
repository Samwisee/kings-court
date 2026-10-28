/// Dealing an on-screen round (game/dealer.dart): the same seed deals the
/// same cards, no task is impossible once dealt, and a lesson's rigged
/// deal is used as it is.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/game/dealer.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/tutorial.dart';

GameState game(int players, int target, {int seed = 11, GameMode mode = GameMode.free}) =>
    GameState()
      ..mode = mode
      ..seed = seed
      ..target = target
      ..players = [for (var i = 0; i < players; i++) Player('P$i', colorValue: 0xFF000000 + i)]
      ..seatCourtiers()
      ..addTasksUntilTarget(players, target)
      ..cards = MatchState(players: players, target: target);

void main() {
  test('The same seed deals the same cards, and a different seed does not', () {
    final a = game(4, 10);
    final b = game(4, 10);
    final c = game(4, 10, seed: 12);
    expect(dealRound(a, you: 0), isTrue);
    expect(dealRound(b, you: 0), isTrue);
    expect(dealRound(c, you: 0), isTrue);
    expect(a.cards!.hands, b.cards!.hands);
    expect(a.cards!.hands, isNot(c.cards!.hands));
    // Dealt once per round: asking again does nothing.
    expect(dealRound(a, you: 0), isFalse);
  });

  test('No task is impossible once the cards are dealt', () {
    for (var seed = 0; seed < 30; seed++) {
      for (final players in [3, 4, 5]) {
        final g = game(players, 8 + seed % 6, seed: seed);
        dealRound(g, you: 0);
        final c = g.cards!;
        expect(c.hands.length, players);
        for (final t in g.tasks) {
          expect(playableWith(t.description, c.hands, c.inPlay), isTrue,
              reason: '${t.description} (seed $seed, $players players)');
          expect(stillPossible(g, t, c.hands, c.inPlay, you: 0), isTrue,
              reason: '${t.description} (seed $seed, $players players)');
        }
      }
    }
  });

  test('A rigged deal is used as it is, with you as King', () {
    final g = game(3, 1, mode: GameMode.tutorial);
    final rigged = lessons[0].deal();
    expect(dealRound(g, you: 0, rigged: rigged), isTrue);
    final c = g.cards!;
    expect(c.hands, rigged.hands);
    expect(c.setAside, rigged.setAside);
    expect(c.king, 0);
    expect(c.leader, 0);
  });
}
