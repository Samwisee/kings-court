/// Plausible hands: what the cards a player can't see *might* be.
///
/// A courtier playing fair knows only what's public (see inference.dart):
/// the cards played, who couldn't follow a suit, the cards shown with the
/// speech token, who the King is, and how many cards everyone holds. To
/// think ahead it deals the unseen cards into the other hands in a way that
/// fits all of that, imagines the round from there, and does it again with
/// another deal. Each such deal is a *world*: a copy of the round with
/// guessed hands in place of the real ones.
///
/// Pure Dart, like the rest of the engine.
library;

import 'dart:math';

import 'cards.dart';
import 'inference.dart';
import 'match.dart';

/// A deal of the cards [viewer] can't see into the other seats' hands, as
/// one possible world: each seat gets exactly the number of cards it holds,
/// only cards it could hold, and every card it's known to hold. Whatever is
/// left over is set aside (2-player games deal only part of the deck).
///
/// [guesses] is `guessHands(m, viewer)`, passed in so one deduction serves
/// many samples. Never fails: when the facts can't all be honoured at once
/// (they can, in a real game, but a saved game from an older version might
/// not), the leftovers are dealt out wherever there's room.
List<List<PlayingCard>> sampleHands(
    MatchState m, int viewer, List<HandGuess> guesses, Random rand) {
  final hands = [for (int s = 0; s < m.players; s++) <PlayingCard>[]];
  if (m.hands.length > viewer) hands[viewer] = List.of(m.hands[viewer]);
  // The cards to place: every unseen card that someone could hold. Any
  // beyond what the hands can take must be set aside (2-player games deal
  // only part of the deck).
  final unseen = <PlayingCard>{for (final g in guesses) ...g.possible};
  final totalRoom = guesses.fold(0, (a, g) => a + g.size);
  final mustAside = max(0, unseen.length - totalRoom);
  int holders(PlayingCard c) =>
      guesses.where((g) => g.possible.contains(c)).length;
  for (var attempt = 0; attempt < 12; attempt++) {
    final room = {for (final g in guesses) g.seat: g.size};
    final dealt = {for (final g in guesses) g.seat: <PlayingCard>[]};
    final left = <PlayingCard>{...unseen};
    var ok = true;
    // Known cards first.
    for (final g in guesses) {
      for (final c in g.certain) {
        if (!left.remove(c)) continue;
        dealt[g.seat]!.add(c);
        room[g.seat] = room[g.seat]! - 1;
      }
      if (room[g.seat]! < 0) ok = false;
    }
    if (!ok) break;
    // Then the rest, the most constrained cards first (those only one or
    // two seats could hold), each to a random seat that could hold it and
    // has room; a card is set aside when nobody can take it, or by the
    // luck of the draw while there's set-aside room to fill.
    final rest = left.toList()..shuffle(rand);
    rest.sort((a, b) => holders(a).compareTo(holders(b)));
    var asideLeft = mustAside;
    var remaining = rest.length;
    for (final c in rest) {
      remaining--;
      final can = [
        for (final g in guesses)
          if (g.possible.contains(c) && room[g.seat]! > 0) g.seat
      ];
      if (can.isEmpty || rand.nextInt(remaining + 1) < asideLeft) {
        if (asideLeft == 0) {
          ok = false;
          break;
        }
        asideLeft--;
        continue;
      }
      final seat = can[rand.nextInt(can.length)];
      dealt[seat]!.add(c);
      room[seat] = room[seat]! - 1;
    }
    if (ok && room.values.every((r) => r == 0)) {
      for (final g in guesses) {
        hands[g.seat] = dealt[g.seat]!..sort();
      }
      return hands;
    }
  }
  // The facts couldn't be honoured together: deal what's known, then fill
  // every seat from whatever is left, so thinking can still go on.
  final left = unseen.toList()..shuffle(rand);
  for (final g in guesses) {
    final hand = <PlayingCard>[];
    for (final c in g.certain) {
      if (left.remove(c)) hand.add(c);
    }
    while (hand.length < g.size && left.isNotEmpty) {
      final i = left.indexWhere(g.possible.contains);
      hand.add(left.removeAt(i < 0 ? 0 : i));
    }
    hands[g.seat] = hand..sort();
  }
  return hands;
}

/// A copy of the round [m] as [viewer] might imagine it: the same tricks,
/// tasks and rules, with [hands] in place of the real ones, and the cards
/// dealt to nobody set aside.
MatchState worldWith(MatchState m, List<List<PlayingCard>> hands) {
  final w = MatchState(players: m.players, target: m.target)
    ..round = m.round
    ..wins = m.wins
    ..losses = m.losses
    ..streak = m.streak
    ..hands = hands
    ..king = m.king
    ..tasks = m.tasks
    ..pickTurn = m.pickTurn
    ..tricks = m.tricks
    ..leader = m.leader
    ..currentSeats = m.currentSeats
    ..current = m.current
    ..phase = m.phase
    ..won = m.won
    ..dealId = m.dealId
    ..takeRule = m.takeRule
    ..announced = m.announced
    ..revealed = m.revealed
    ..revealHint = m.revealHint
    ..revealedAt = m.revealedAt;

  // Whatever isn't in a hand, in a trick or on the table was set aside.
  final seen = <PlayingCard>{
    for (final h in hands) ...h,
    for (final t in m.tricks) ...t.cards,
    ...m.current,
  };
  w.setAside = [for (final c in fullDeck()) if (!seen.contains(c)) c];
  return w;
}

/// [count] worlds [viewer] might be in, from what they can see of [m].
List<MatchState> sampleWorlds(MatchState m, int viewer, int count, Random rand) {
  final guesses = guessHands(m, viewer);
  return [
    for (int k = 0; k < count; k++)
      worldWith(m, sampleHands(m, viewer, guesses, rand))
  ];
}
