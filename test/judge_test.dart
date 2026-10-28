/// Judging an on-screen round (game/judge.dart): tasks turn over in seal
/// order, nothing after the one that lost the round, and a won round with
/// cards to spare may play itself out.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/game/dealer.dart';
import 'package:kings_court/game/judge.dart';
import 'package:kings_court/models.dart';

/// A three-player game on screen with the given tasks, dealt and crowned.
GameState table(List<String> tasks, {int seed = 5}) {
  final g = GameState()
    ..seed = seed
    ..target = 5
    ..players = [for (var i = 0; i < 3; i++) Player('P$i', colorValue: 0xFF000000 + i)]
    ..seatCourtiers()
    ..addTasksUntilTarget(3, 5);
  g.tasks
    ..clear()
    ..addAll([
      for (final d in tasks) GameState.taskPool.firstWhere((t) => t.description == d).freshCopy()
    ]);
  g.cards = MatchState(players: 3, target: 5);
  dealRound(g, you: 0);
  g.setKing(g.cards!.king);
  return g;
}

/// Plays the whole trick, the first legal card each time.
void playTrick(GameState g) {
  final c = g.cards!;
  do {
    c.playCard(c.turn, c.legalFor(c.turn).first);
  } while (c.current.isNotEmpty);
}

void main() {
  test('A task the tricks settle turns over; the others wait', () {
    final g = table(['Win the first trick', 'Win the last trick']);
    final first = g.tasks[0];
    final last = g.tasks[1];
    final king = g.kingIndex!;
    // The King leads the first trick; give them "Win the first trick" and
    // the last-trick task to the next seat.
    g.assign(first, king);
    g.assign(last, (king + 1) % 3);
    expect(judgeTasks(g), isEmpty);
    playTrick(g);
    final flips = judgeTasks(g);
    expect(flips, hasLength(1));
    expect(flips.single.task, first);
    final winner = g.cards!.tricks.single.winner;
    expect(flips.single.status,
        winner == king ? TaskStatus.completed : TaskStatus.failed);
    if (winner != king) expect(flips.single.why, isNotNull);
    // Judging changes nothing itself.
    expect(first.status, TaskStatus.pending);
  });

  test('Sealed tasks turn over in seal order, and one done out of order fails', () {
    final g = table(['Win the first trick', 'Win the last trick', 'Win exactly one trick']);
    final king = g.kingIndex!;
    // "Win the first trick" sealed second, after the last trick: doing it
    // first breaks the seal.
    g.tasks[0].seal = 2;
    g.tasks[1].seal = 1;
    g.assign(g.tasks[0], king);
    g.assign(g.tasks[1], (king + 1) % 3);
    g.assign(g.tasks[2], (king + 2) % 3);
    final c = g.cards!;
    // Lead a card the King wins: the trick is theirs if they hold the King card.
    if (!c.hands[king].contains(PlayingCard.king)) return;
    c.playCard(king, PlayingCard.king);
    while (c.current.isNotEmpty) {
      c.playCard(c.turn, c.legalFor(c.turn).first);
    }
    final flips = judgeTasks(g);
    // Done, but out of order: it fails, and nothing is judged after it.
    expect(flips.first.task, g.tasks[0]);
    expect(flips.first.status, TaskStatus.failed);
    expect(flips.first.why, startsWith('Done out of order'));
    expect(flips, hasLength(1));
  });

  test('A round plays itself out only once every open task is done', () {
    final g = table(['Win the first trick']);
    final king = g.kingIndex!;
    g.assign(g.tasks[0], king);
    expect(canPlayOut(g), isFalse);
    final c = g.cards!;
    if (!c.hands[king].contains(PlayingCard.king)) return;
    c.playCard(king, PlayingCard.king);
    while (c.current.isNotEmpty) {
      c.playCard(c.turn, c.legalFor(c.turn).first);
    }
    expect(canPlayOut(g), isTrue);
    // A sealed task keeps the round in hand.
    g.tasks[0].seal = 1;
    expect(canPlayOut(g), isFalse);
  });

  test('The shown view leaves a trick still on the table out', () {
    final g = table(['Win the first trick']);
    playTrick(g);
    expect(roundView(g).tricks, hasLength(1));
    expect(shownView(g, trickPending: true).tricks, isEmpty);
    expect(shownView(g, trickPending: false).tricks, hasLength(1));
    final winner = g.cards!.tricks.single.winner;
    expect(shownTricksWon(g, winner, g.cards!.tricks.single), 0);
    expect(shownTricksWon(g, winner, null), 1);
  });
}
