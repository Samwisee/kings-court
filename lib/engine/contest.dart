/// The Trial of Hearts: when the court is divided, everyone secretly takes
/// a side, then plays a round of hearts. Each ♥ won is a mark of shame,
/// and the Q♠ is five. There are no trumps: the Court Cards are just a
/// suit of their own, so a card off the suit led never wins. As in hearts,
/// the 2♣ leads, no ♥ or Q♠ may fall on the first trick, and ♥ can't be
/// led until one has been played. Nobody knows who is with them, so everyone plays
/// for themselves; at the end the side with the fewest marks per courtier
/// has its way, and a tie goes to the King's side.
library;

import 'dart:math';

import 'cards.dart';

class ContestState {
  ContestState._(this.players, this.king, this.sideA, this.hands)
      : leader = _opener(hands, king);

  /// Whoever holds the 2♣ leads (the King, if it was set aside).
  static int _opener(List<List<PlayingCard>> hands, int king) {
    for (int s = 0; s < hands.length; s++) {
      if (hands[s].any((c) => c.suit == Suit.clubs && c.rank == 2)) return s;
    }
    return king;
  }

  /// Deals the whole deck out evenly (any spare cards are set aside).
  /// [sideA] says which side each seat is on (true for the first choice).
  /// The King leads.
  factory ContestState.deal({
    required int players,
    required int king,
    required List<bool> sideA,
    required Random rand,
  }) =>
      ContestState._(players, king, sideA, deal(players, rand).hands);

  /// Marks of shame for winning [card].
  static int shameOf(PlayingCard card) => card == PlayingCard.queen
      ? 5
      : card.suit == Suit.hearts
          ? 1
          : 0;

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

  /// A ♥ has been won or thrown, so hearts may be led.
  bool get heartsBroken =>
      [...tricks.expand((t) => t.cards), ...current].any((c) => c.suit == Suit.hearts);

  List<PlayingCard> legalFor(int seat) {
    final hand = hands[seat];
    final follow = legalPlays(hand, current.isEmpty ? null : current.first);
    List<PlayingCard> unless(bool Function(PlayingCard) bad, List<PlayingCard> from) {
      final ok = from.where((c) => !bad(c)).toList();
      return ok.isEmpty ? from : ok;
    }

    if (current.isEmpty) {
      return heartsBroken ? follow : unless((c) => c.suit == Suit.hearts, follow);
    }
    if (tricks.isEmpty) return unless((c) => shameOf(c) > 0, follow);
    return follow;
  }

  /// Who wins: the highest card of the suit led. Nothing else can win.
  static int winnerOf(List<PlayingCard> cards) {
    final led = cards.first.suit;
    var best = 0;
    for (int i = 1; i < cards.length; i++) {
      if (cards[i].suit == led && cards[i].rank > cards[best].rank) best = i;
    }
    return best;
  }

  /// Plays [card] for [seat]; returns the finished trick, if this card
  /// completed one.
  Trick? play(int seat, PlayingCard card) {
    assert(seat == turn && legalFor(seat).contains(card));
    hands[seat].remove(card);
    seats.add(seat);
    current.add(card);
    if (current.length < players) return null;
    final w = seats[winnerOf(current)];
    final trick = Trick(leader, seats, current, w);
    tricks.add(trick);
    leader = w;
    seats = [];
    current = [];
    return trick;
  }

  /// Marks of shame [seat] has taken so far.
  int shame(int seat) => tricks
      .where((t) => t.winner == seat)
      .expand((t) => t.cards)
      .fold(0, (a, c) => a + shameOf(c));

  /// Marks per courtier on the first side (true) or the second (false).
  double sideShame(bool a) {
    final members = [for (int s = 0; s < players; s++) if (sideA[s] == a) s];
    if (members.isEmpty) return 0;
    return members.fold<int>(0, (n, s) => n + shame(s)) / members.length;
  }

  /// Whether the first side won: fewer marks per courtier. A tie goes to
  /// the King's side.
  bool get aWins {
    final a = sideShame(true), b = sideShame(false);
    return a == b ? sideA[king] : a < b;
  }

  /// A bot's card: keep out of tricks with hearts or the Q♠ in them, and
  /// pass them to someone else when it can.
  PlayingCard botPlay(int seat) {
    final legal = legalFor(seat);
    // The Q♠ is the card to be rid of; otherwise high cards are risky.
    int strength(PlayingCard c) =>
        c == PlayingCard.queen ? 30 : c.isCourt ? 10 + c.rank : c.rank;
    PlayingCard lowest(Iterable<PlayingCard> cs) =>
        cs.reduce((a, b) => strength(a) <= strength(b) ? a : b);
    PlayingCard highest(Iterable<PlayingCard> cs) =>
        cs.reduce((a, b) => strength(a) >= strength(b) ? a : b);
    if (current.isEmpty) {
      // Lead low, and not a heart if it can help it.
      final safe = legal.where((c) => !c.isCourt && c.suit != Suit.hearts);
      if (safe.isNotEmpty) return lowest(safe);
      final plain = legal.where((c) => !c.isCourt);
      return lowest(plain.isNotEmpty ? plain : legal);
    }
    bool wins(PlayingCard c) => winnerOf([...current, c]) == current.length;
    final losers = legal.where((c) => !wins(c)).toList();
    final followed = legal.first.suit == current.first.suit;
    if (!followed) {
      // Off suit: throw the most dangerous card that won't take the trick.
      final queen = losers.where((c) => c == PlayingCard.queen);
      if (queen.isNotEmpty) return queen.first;
      final hearts = losers.where((c) => c.suit == Suit.hearts);
      if (hearts.isNotEmpty) return highest(hearts);
      if (losers.isNotEmpty) return highest(losers);
      return lowest(legal);
    }
    // Following: duck under the winner with the highest card that still
    // loses; if it must win, win high (last to play) or as low as it can.
    if (losers.isNotEmpty) return highest(losers);
    final last = current.length == players - 1;
    final pricey = current.any((c) => shameOf(c) > 0);
    return last && !pricey ? highest(legal) : lowest(legal);
  }
}
