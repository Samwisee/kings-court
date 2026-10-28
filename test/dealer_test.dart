/// Dealing an on-screen round (game/dealer.dart): the same seed deals the
/// same cards, no task is impossible once dealt, and a lesson's rigged
/// deal is used as it is.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/game/dealer.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/modes/tutorial/lessons.dart';

GameState game(int players, int target, {int seed = 11, GameMode mode = GameMode.free}) =>
    GameState()
      ..mode = mode
      ..seed = seed
      ..target = target
      ..digital = true
      ..players = [for (var i = 0; i < players; i++) Player('P$i', colorValue: 0xFF000000 + i)]
      ..seatCourtiers()
      ..startRound(players, target);

void main() {
  test('The same seed deals the same cards, and a different seed does not', () {
    final a = game(4, 10);
    final b = game(4, 10);
    final c = game(4, 10, seed: 12);
    expect(dealRound(a), isTrue);
    expect(dealRound(b), isTrue);
    expect(dealRound(c), isTrue);
    expect(a.round!.hands, b.round!.hands);
    expect(a.round!.hands, isNot(c.round!.hands));
    // Dealt once per round: asking again does nothing.
    expect(dealRound(a), isFalse);
  });

  test('A dealt round waits for the table to crown the King card’s holder', () {
    final g = game(4, 8);
    dealRound(g);
    final r = g.round!;
    expect(r.king, isNull);
    expect(r.kingCardHolder, isNotNull);
    expect(r.hands[r.kingCardHolder!], contains(PlayingCard.king));
    expect(r.leader, r.kingCardHolder, reason: 'the King leads the first trick');
  });

  test('A re-deal keeps a reigning King, with the King card in their hand', () {
    final g = game(4, 8);
    dealRound(g);
    g.crown(2);
    g.shuffleTasks(4, 8);
    expect(g.round!.hasCards, isFalse, reason: 'new tasks, new cards');
    expect(dealRound(g), isTrue);
    expect(g.round!.king, 2);
    expect(g.round!.hands[2], contains(PlayingCard.king));
  });

  test('No task is impossible once the cards are dealt', () {
    for (var seed = 0; seed < 30; seed++) {
      for (final players in [3, 4, 5]) {
        final g = game(players, 8 + seed % 6, seed: seed);
        dealRound(g);
        final r = g.round!;
        expect(r.hands.length, players);
        for (final t in r.tasks) {
          expect(playableWith(t.description, r.hands, r.inPlay), isTrue,
              reason: '${t.description} (seed $seed, $players players)');
          expect(stillPossible(r, t, r.hands, r.inPlay), isTrue,
              reason: '${t.description} (seed $seed, $players players)');
        }
      }
    }
  });

  test('A rigged deal is used as it is, with the King card in your hand', () {
    final g = game(3, 1, mode: GameMode.tutorial);
    final rigged = lessons[0].deal();
    expect(dealRound(g, rigged: rigged), isTrue);
    final r = g.round!;
    expect(r.hands, rigged.hands);
    expect(r.setAside, rigged.setAside);
    expect(r.kingCardHolder, 0);
    expect(r.leader, 0);
  });
}
