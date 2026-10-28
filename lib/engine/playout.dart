/// A bot's playouts: a throwaway copy of a round played out at random, and
/// the guide that tells each seat what it plays for.
library;

import 'dart:math';

import 'cards.dart';
import 'conflicts.dart';
import 'deal_mix.dart';
import 'round.dart';
import 'rules.dart';

/// A throwaway copy of a round, played out at random.
class Playout {
  Playout(this.players, this.hands, this.tricks, this.leader, this.seats,
      this.cards, this.totalTricks);

  factory Playout.from(Round s) => Playout(
        s.players,
        [for (final h in s.hands) List.of(h)],
        List.of(s.tricks),
        s.leader,
        List.of(s.currentSeats),
        List.of(s.current),
        s.totalTricks,
      );

  final int players;
  final List<List<PlayingCard>> hands;
  final List<Trick> tricks;
  int leader;
  List<int> seats;
  List<PlayingCard> cards;
  final int totalTricks;

  int get turn => cards.isEmpty ? leader : (seats.last + 1) % players;

  void play(int seat, PlayingCard card) {
    hands[seat].remove(card);
    seats.add(seat);
    cards.add(card);
    if (cards.length == players) {
      final w = seats[winningPlay(cards)];
      tricks.add(Trick(leader, seats, cards, w));
      leader = w;
      seats = [];
      cards = [];
    }
  }

  /// Plays on to the end of the round, or until [until] tricks have been
  /// played: at random, or mostly for each player's tasks with a [guide].
  void playOut(Random rand, {int? until, PlayoutGuide? guide}) {
    while (tricks.length < (until ?? totalTricks)) {
      final seat = turn;
      final legal = legalPlays(hands[seat], cards.isEmpty ? null : cards.first);
      if (legal.isEmpty) break;
      final chosen = guide != null && rand.nextDouble() < guide.strength
          ? guide.choose(this, seat, legal, rand)
          : legal[rand.nextInt(legal.length)];
      play(seat, chosen);
    }
  }

  /// The card winning the trick so far, or null when nothing's been led.
  PlayingCard? get ahead => cards.isEmpty ? null : cards[winningPlay(cards)];

  /// Whether [card], played now, would beat [best] (the card winning the
  /// trick so far; null when leading, which always "wins").
  bool beats(PlayingCard card, PlayingCard? best) {
    if (best == null) return true;
    if (card.isCourt) return !best.isCourt || card.rank > best.rank;
    return !best.isCourt && card.suit == cards.first.suit && card.rank > best.rank;
  }

  RoundView view(Round s, Set<PlayingCard> inPlay,
          [Map<int, PlayingCard>? shown, Map<int, int>? shownAt]) =>
      RoundView(
          players: players,
          king: s.king ?? s.leader,
          tricks: tricks,
          totalTricks: totalTricks,
          inPlay: inPlay,
          shown: shown ?? s.revealed,
          shownAt: shownAt ?? s.revealedAt);
}

/// What each seat plays for in a guided playout, from the tasks they hold:
/// the cards they need to win, the cards they must not win, and whether
/// they want tricks at all.
class PlayoutGuide {
  PlayoutGuide(this.need, this.avoid, this.temper, this.strength);

  /// Cards each seat must win.
  final List<Set<PlayingCard>> need;

  /// Cards each seat must not win (null when nothing is forbidden).
  final List<bool Function(PlayingCard)?> avoid;

  /// Whether each seat wants tricks (+1), wants to avoid them (-1), or
  /// doesn't mind (0).
  final List<int> temper;

  /// How often a player follows the guide rather than playing at random.
  final double strength;

  factory PlayoutGuide.of(Round s, Map<int, int> assigned, double strength) {
    final need = [for (int i = 0; i < s.players; i++) <PlayingCard>{}];
    final avoids = [for (int i = 0; i < s.players; i++) <bool Function(PlayingCard)>[]];
    final temper = List.filled(s.players, 0);
    for (final e in assigned.entries) {
      final t = s.tasks[e.key];
      if (!t.isPending) continue;
      final seat = e.value;
      final d = t.description;
      final p = profileOf(d);
      need[seat].addAll(p.cards);
      if (p.forbidCard != null) avoids[seat].add(p.forbidCard!);
      // Wanting tricks in general: only tasks about the count of tricks.
      // Capturing a card is about *which* trick, and is handled when the
      // card is on the table; leading high for its own sake wastes the
      // cards that win it later.
      switch (tierOf(d)) {
        case TaskTier.avoid:
          temper[seat] -= 1;
        case TaskTier.race:
          temper[seat] += d.contains('fewer') ? -1 : 1;
        case TaskTier.trick:
          if (d.contains('in a row')) temper[seat] += 1;
        case TaskTier.capture:
        case TaskTier.precise:
          break;
      }
      if (p.maxTricks != null && p.maxTricks! <= 1) temper[seat] -= 1;
    }
    return PlayoutGuide(need, [
      for (final a in avoids)
        a.isEmpty ? null : (PlayingCard c) => a.any((f) => f(c))
    ], [for (final t in temper) t.sign], strength);
  }

  /// The card [seat] plays, following what they hold.
  PlayingCard choose(Playout sim, int seat, List<PlayingCard> legal, Random rand) {
    PlayingCard lowest(Iterable<PlayingCard> cs) =>
        cs.reduce((a, b) => _value(a) <= _value(b) ? a : b);
    PlayingCard highest(Iterable<PlayingCard> cs) =>
        cs.reduce((a, b) => _value(a) >= _value(b) ? a : b);
    final best = sim.ahead;
    final winners = [for (final c in legal) if (sim.beats(c, best)) c];
    final losers = [for (final c in legal) if (!sim.beats(c, best)) c];
    final onTable = sim.cards;
    // A card they need is on the table: take the trick as cheaply as it
    // can be taken.
    if (onTable.any(need[seat].contains) && winners.isNotEmpty) {
      return lowest(winners);
    }
    // Playing together: a card a teammate needs goes to them when they're
    // winning the trick, and a trick holding a card a teammate needs is
    // left to them.
    if (onTable.isNotEmpty) {
      final ahead = sim.seats[winningPlay(onTable)];
      if (ahead != seat) {
        final gift = [for (final c in legal) if (need[ahead].contains(c)) c];
        if (gift.isNotEmpty && !sim.beats(gift.first, best)) return gift.first;
        final theirs = onTable.any(need[ahead].contains);
        if (theirs && losers.isNotEmpty) return highest(losers);
      }
    }
    // A card they must not win is on the table: stay under it, throwing
    // the biggest card that still loses.
    final forbid = avoid[seat];
    if (forbid != null && onTable.any(forbid)) {
      return losers.isNotEmpty ? highest(losers) : lowest(legal);
    }
    // Leading: those who want tricks lead high, those who don't lead low,
    // and a card someone else needs is never led by its holder's rivals
    // (nothing to be done about it; leave it to chance).
    if (onTable.isEmpty) {
      if (temper[seat] > 0) return highest(legal);
      if (temper[seat] < 0) return lowest(legal);
      return legal[rand.nextInt(legal.length)];
    }
    if (temper[seat] > 0) {
      return winners.isNotEmpty ? lowest(winners) : lowest(legal);
    }
    if (temper[seat] < 0) {
      return losers.isNotEmpty ? highest(losers) : lowest(legal);
    }
    return legal[rand.nextInt(legal.length)];
  }

  /// A card's strength: Court Cards above every plain card.
  static int _value(PlayingCard c) => c.isCourt ? 100 + c.rank : c.rank;
}
