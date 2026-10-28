/// Judging a round (engine/round.dart, [Round.judge]) and what the table
/// shows of it (game/judge.dart): tasks turn over in seal order, nothing
/// after the one that lost the round, a won round with cards to spare may
/// play itself out, and a trick still on the table doesn't count yet.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/game/dealer.dart';
import 'package:kings_court/game/judge.dart';
import 'package:kings_court/models.dart';

/// A three-player round on screen with the given tasks, dealt and crowned.
Round table(List<String> tasks, {int seed = 5}) {
  final g = GameState()
    ..seed = seed
    ..target = 5
    ..digital = true
    ..players = [for (var i = 0; i < 3; i++) Player('P$i', colorValue: 0xFF000000 + i)]
    ..seatCourtiers()
    ..addTasksUntilTarget(3, 5);
  g.round!.tasks = [for (final d in tasks) RoundTask(taskByDescription(d))];
  dealRound(g, you: 0);
  g.crown(g.round!.kingCardHolder);
  return g.round!;
}

/// Plays the whole trick, the first legal card each time.
void playTrick(Round r) {
  do {
    r.playCard(r.turn, r.legalFor(r.turn).first);
  } while (r.current.isNotEmpty);
}

/// The King leads the King card, which always wins, and the trick plays out.
void kingWinsTrick(Round r) {
  final king = r.king!;
  r.playCard(king, PlayingCard.king);
  while (r.current.isNotEmpty) {
    r.playCard(r.turn, r.legalFor(r.turn).first);
  }
}

void main() {
  test('A task the tricks settle turns over; the others wait', () {
    final r = table(['Win the first trick', 'Win the last trick']);
    final first = r.tasks[0];
    final last = r.tasks[1];
    final king = r.king!;
    // The King leads the first trick; give them "Win the first trick" and
    // the last-trick task to the next seat.
    r.assign(first, king);
    r.assign(last, (king + 1) % 3);
    expect(r.judge(), isEmpty);
    playTrick(r);
    final flips = r.judge();
    expect(flips, hasLength(1));
    expect(flips.single.task, first);
    final winner = r.tricks.single.winner;
    expect(flips.single.status,
        winner == king ? TaskStatus.completed : TaskStatus.failed);
    if (winner != king) expect(flips.single.why, isNotNull);
    // Judging changes nothing itself; flipping does.
    expect(first.status, TaskStatus.pending);
    r.flip(flips.single);
    expect(first.status, flips.single.status);
    expect(first.whyFailed, flips.single.why);
  });

  test('Sealed tasks turn over in seal order, and one done out of order fails', () {
    final r = table(['Win the first trick', 'Win the last trick', 'Win exactly one trick']);
    final king = r.king!;
    expect(r.hands[king], contains(PlayingCard.king));
    // "Win the first trick" sealed second, after the last trick: doing it
    // first breaks the seal.
    r.tasks[0].seal = 2;
    r.tasks[1].seal = 1;
    r.assign(r.tasks[0], king);
    r.assign(r.tasks[1], (king + 1) % 3);
    r.assign(r.tasks[2], (king + 2) % 3);
    kingWinsTrick(r);
    final flips = r.judge();
    // Done, but out of order: it fails, and nothing is judged after it.
    expect(flips.first.task, r.tasks[0]);
    expect(flips.first.status, TaskStatus.failed);
    expect(flips.first.why, startsWith('Done out of order'));
    expect(flips, hasLength(1));
  });

  test('A round plays itself out only once every open task is done', () {
    final r = table(['Win the first trick']);
    final king = r.king!;
    expect(r.hands[king], contains(PlayingCard.king));
    r.assign(r.tasks[0], king);
    expect(r.canPlayOut, isFalse);
    kingWinsTrick(r);
    expect(r.canPlayOut, isTrue);
    // A sealed task keeps the round in hand.
    r.tasks[0].seal = 1;
    expect(r.canPlayOut, isFalse);
  });

  test('A failed task ends the round; every task done wins it', () {
    final r = table(['Win the first trick']);
    final king = r.king!;
    r.assign(r.tasks[0], (king + 1) % 3);
    kingWinsTrick(r);
    for (final f in r.judge()) {
      r.flip(f);
    }
    expect(r.outcome, RoundOutcome.lost);
    expect(r.won, isFalse);
    expect(r.phase, Phase.roundOver);
    expect(r.tasks[0].whyFailed, isNotNull);

    final w = table(['Win the first trick']);
    w.assign(w.tasks[0], w.king!);
    kingWinsTrick(w);
    for (final f in w.judge()) {
      w.flip(f);
    }
    expect(w.outcome, RoundOutcome.won);
    expect(w.phase, Phase.roundOver);
  });

  test('The shown view leaves a trick still on the table out', () {
    final r = table(['Win the first trick']);
    playTrick(r);
    expect(r.view.tricks, hasLength(1));
    expect(shownView(r, trickPending: true).tricks, isEmpty);
    expect(shownView(r, trickPending: false).tricks, hasLength(1));
    final winner = r.tricks.single.winner;
    expect(shownTricksWon(r, winner, r.tricks.single), 0);
    expect(shownTricksWon(r, winner, null), 1);
  });
}
