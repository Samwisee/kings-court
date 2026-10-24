/// A contest of cards: when the court is divided, the two sides play a
/// short hand against each other and the side that takes more tricks has
/// its way. Unlike a normal round it is competitive: no tasks, just
/// tricks, and each one counts for the side of whoever wins it.
library;

import 'dart:math';

import 'cards.dart';

class ContestState {
  ContestState._(this.players, this.king, this.sideA, this.hands)
      : leader = king;

  /// Deals [perHand] cards each from a fresh deck. [sideA] says which
  /// side each seat is on (true for the first choice). The King leads.
  factory ContestState.deal({
    required int players,
    required int king,
    required List<bool> sideA,
    required Random rand,
    int perHand = contestHand,
  }) {
    final deck = fullDeck()..shuffle(rand);
    final hands = [
      for (int p = 0; p < players; p++)
        deck.sublist(p * perHand, (p + 1) * perHand)..sort(),
    ];
    return ContestState._(players, king, sideA, hands);
  }

  /// Cards each in a contest: quick, but long enough for a comeback.
  static const contestHand = 5;

  final int players;
  final int king;
  final List<bool> sideA;
  final List<List<PlayingCard>> hands;
  final List<Trick> tricks = [];
  int leader;
  List<int> seats = [];
  List<PlayingCard> current = [];

  bool get over => hands.every((h) => h.isEmpty) && current.isEmpty;
  int get turn => current.isEmpty ? leader : (seats.last + 1) % players;

  List<PlayingCard> legalFor(int seat) =>
      legalPlays(hands[seat], current.isEmpty ? null : current.first);

  /// Plays [card] for [seat]; returns the finished trick, if this card
  /// completed one.
  Trick? play(int seat, PlayingCard card) {
    assert(seat == turn && legalFor(seat).contains(card));
    hands[seat].remove(card);
    seats.add(seat);
    current.add(card);
    if (current.length < players) return null;
    final w = seats[winningPlay(current)];
    final trick = Trick(leader, seats, current, w);
    tricks.add(trick);
    leader = w;
    seats = [];
    current = [];
    return trick;
  }

  /// Tricks taken by the first side (true) or the second (false).
  int tricksFor(bool a) => tricks.where((t) => sideA[t.winner] == a).length;

  /// Whether the first side won. A tie goes to the King's side.
  bool get aWins {
    final a = tricksFor(true), b = tricksFor(false);
    return a == b ? sideA[king] : a > b;
  }

  /// Whether one side has already won, whatever happens in the tricks left.
  bool get decided {
    final left = hands.first.length + (current.isEmpty ? 0 : 1);
    final a = tricksFor(true), b = tricksFor(false);
    final kingA = sideA[king];
    // The leading side can't be caught (ties go to the King's side).
    bool safe(int lead, int trail, bool leadIsKing) =>
        leadIsKing ? lead >= trail + left : lead > trail + left;
    return safe(a, b, kingA) || safe(b, a, !kingA);
  }

  /// A bot's card: win the trick for its side when it can, as cheaply as
  /// it can; otherwise throw away its weakest card.
  PlayingCard botPlay(int seat) {
    final legal = legalFor(seat);
    int strength(PlayingCard c) => c.isCourt ? 20 + c.rank : c.rank;
    final cheapest = legal.reduce((a, b) => strength(a) <= strength(b) ? a : b);
    if (current.isEmpty) {
      // Lead the strongest plain card; keep the Court Cards for later
      // unless that's all there is.
      final plain = legal.where((c) => !c.isCourt).toList();
      if (plain.isEmpty) return cheapest;
      return plain.reduce((a, b) => strength(a) >= strength(b) ? a : b);
    }
    final winning = seats[winningPlay(current)];
    if (sideA[winning] == sideA[seat]) return cheapest; // a friend has it
    final winners = [
      for (final c in legal)
        if (winningPlay([...current, c]) == current.length) c
    ];
    if (winners.isEmpty) return cheapest;
    return winners.reduce((a, b) => strength(a) <= strength(b) ? a : b);
  }
}
