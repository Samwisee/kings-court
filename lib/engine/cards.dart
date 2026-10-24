/// The deck and the rules of a trick: pure Dart, no Flutter, so the same
/// code can run on a phone, in tests, or on a server.
library;

import 'dart:math';

/// The four plain suits, plus the Court Cards, which beat every suit.
enum Suit {
  hearts('♥'),
  diamonds('♦'),
  spades('♠'),
  clubs('♣'),
  court('');

  const Suit(this.symbol);
  final String symbol;

  bool get isRed => this == hearts || this == diamonds;
}

/// One card. Plain cards run Ace (1) to 9. Court Cards rank 1 to 4:
/// Joker, Jack, Queen, King.
class PlayingCard implements Comparable<PlayingCard> {
  const PlayingCard(this.suit, this.rank);
  final Suit suit;
  final int rank;

  static const joker = PlayingCard(Suit.court, 1);
  static const jack = PlayingCard(Suit.court, 2);
  static const queen = PlayingCard(Suit.court, 3);
  static const king = PlayingCard(Suit.court, 4);

  bool get isCourt => suit == Suit.court;

  /// "3♥", "A♦", "Joker", "King".
  String get label {
    if (isCourt) return const ['Joker', 'Jack', 'Queen', 'King'][rank - 1];
    return '${rank == 1 ? 'A' : rank}${suit.symbol}';
  }

  /// "3", "A" or the Court Card's letter, for the card's corner.
  String get rankLabel {
    if (isCourt) return const ['★', 'J', 'Q', 'K'][rank - 1];
    return rank == 1 ? 'A' : '$rank';
  }

  /// A stable number for saving: 0 to 39.
  int get id => suit.index * 9 + rank - 1;
  static PlayingCard fromId(int id) =>
      id >= 36 ? PlayingCard(Suit.court, id - 35) : PlayingCard(Suit.values[id ~/ 9], id % 9 + 1);

  /// Parses a label such as "3♥", "A♦", "Jack" or "Joker".
  static PlayingCard? parse(String label) {
    switch (label) {
      case 'Joker':
        return joker;
      case 'J♠':
      case 'Jack':
        return jack;
      case 'Q♠':
      case 'Queen':
        return queen;
      case 'K♠':
      case 'King':
        return king;
    }
    if (label.length != 2) return null;
    final rank = label[0] == 'A' ? 1 : int.tryParse(label[0]);
    final suit = Suit.values.where((s) => s.symbol == label[1] && s != Suit.court);
    if (rank == null || suit.isEmpty) return null;
    return PlayingCard(suit.first, rank);
  }

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => id;

  /// The order suits sit in a hand: red and black alternate, so
  /// neighbouring suits are easy to tell apart, and the gold Court Cards
  /// come last.
  static const handOrder = [
    Suit.hearts,
    Suit.spades,
    Suit.diamonds,
    Suit.clubs,
    Suit.court
  ];

  /// Hand order: ♥ ♠ ♦ ♣, low to high in each, then the Court Cards.
  @override
  int compareTo(PlayingCard other) {
    final bySuit =
        handOrder.indexOf(suit).compareTo(handOrder.indexOf(other.suit));
    return bySuit != 0 ? bySuit : rank.compareTo(other.rank);
  }

  @override
  String toString() => label;
}

/// All 40 cards: Ace to 9 in four suits, and the four Court Cards.
List<PlayingCard> fullDeck() => [
      for (final s in [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs])
        for (int r = 1; r <= 9; r++) PlayingCard(s, r),
      for (int r = 1; r <= 4; r++) PlayingCard(Suit.court, r),
    ];

/// Cards in each hand: the deck shared out, except two players hold 12
/// (the rest set aside), so a quiet round stays quick.
int handSize(int players) => players == 2 ? 12 : 40 ~/ players;

/// Deals every player the same number of cards. Any left over are set
/// aside unseen (never the King card, so there is always a King).
({List<List<PlayingCard>> hands, List<PlayingCard> setAside}) deal(
    int players, Random rand) {
  while (true) {
    final deck = fullDeck()..shuffle(rand);
    // Two players keep a hand of 12, so a quiet round stays quick; the
    // rest of the deck is set aside unseen.
    final each = handSize(players);
    final setAside = deck.sublist(each * players);
    if (setAside.contains(PlayingCard.king)) continue;
    final hands = [
      for (int p = 0; p < players; p++)
        deck.sublist(p * each, (p + 1) * each)..sort(),
    ];
    return (hands: hands, setAside: setAside);
  }
}

/// The cards [hand] may play on a trick that started with [led] (null when
/// leading): you must follow the suit led if you can. Court Cards count as
/// their own suit, so a Court Card lead must be followed by a Court Card.
List<PlayingCard> legalPlays(List<PlayingCard> hand, PlayingCard? led) {
  if (led == null) return List.of(hand);
  final follow = hand.where((c) => c.suit == led.suit).toList();
  return follow.isEmpty ? List.of(hand) : follow;
}

/// Which play wins: the highest Court Card if any was played, otherwise
/// the highest card of the suit led. Returns an index into [cards].
int winningPlay(List<PlayingCard> cards) {
  int best = 0;
  for (int i = 1; i < cards.length; i++) {
    final c = cards[i], b = cards[best];
    if (c.isCourt && (!b.isCourt || c.rank > b.rank)) {
      best = i;
    } else if (!b.isCourt && c.suit == cards[0].suit && c.rank > b.rank) {
      best = i;
    }
  }
  return best;
}

/// A finished trick: who led, each card in order of play, and who won.
class Trick {
  const Trick(this.leader, this.seats, this.cards, this.winner);
  final int leader;

  /// Who played each card, in order.
  final List<int> seats;
  final List<PlayingCard> cards;
  final int winner;

  PlayingCard get led => cards.first;

  /// The card the winner played.
  PlayingCard get winningCard => cards[seats.indexOf(winner)];
  PlayingCard cardOf(int seat) => cards[seats.indexOf(seat)];

  Map<String, dynamic> toJson() => {
        'leader': leader,
        'seats': seats,
        'cards': [for (final c in cards) c.id],
        'winner': winner,
      };
  static Trick fromJson(Map<String, dynamic> j) => Trick(
        j['leader'] as int,
        List<int>.from(j['seats'] as List),
        [for (final c in j['cards'] as List) PlayingCard.fromId(c as int)],
        j['winner'] as int,
      );
}
