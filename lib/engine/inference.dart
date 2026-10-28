/// What one player can work out about everyone else's hands from what's
/// public: the cards played, who couldn't follow suit, and the cards shown
/// with the speech token (with their "highest", "lowest" or "only" mark).
///
/// Pure Dart, like the rest of the engine, so the same reasoning could one
/// day drive bots that play only on what they could fairly know.
library;

import 'cards.dart';
import 'match.dart';

/// What [viewer] can tell about one other seat's hand.
class HandGuess {
  HandGuess(this.seat, this.size);
  final int seat;

  /// How many cards they still hold (everyone can count).
  final int size;

  /// Suits (Court Cards count as one) they've shown they have none of.
  final Set<Suit> voids = {};

  /// Cards they could be holding.
  final Set<PlayingCard> possible = {};

  /// Cards they must be holding.
  final Set<PlayingCard> certain = {};
}

/// Everything [viewer] can deduce about the other hands in [m].
List<HandGuess> guessHands(MatchState m, int viewer) {
  final played = <PlayingCard>{
    for (final t in m.tricks) ...t.cards,
    ...m.current,
  };
  final mine = m.hands.length > viewer ? m.hands[viewer].toSet() : <PlayingCard>{};
  final unseen = [
    for (final c in fullDeck())
      if (!played.contains(c) && !mine.contains(c)) c
  ];
  final guesses = [
    for (int s = 0; s < m.players; s++)
      if (s != viewer) HandGuess(s, m.hands[s].length)
  ];
  HandGuess? of(int seat) {
    for (final g in guesses) {
      if (g.seat == seat) return g;
    }
    return null;
  }

  // Not following the suit led means having none of it.
  void voidsFrom(List<int> seats, List<PlayingCard> cards) {
    if (cards.isEmpty) return;
    final led = cards.first.suit;
    for (var k = 1; k < cards.length; k++) {
      if (cards[k].suit != led) of(seats[k])?.voids.add(led);
    }
  }

  for (final t in m.tricks) {
    voidsFrom(t.seats, t.cards);
  }
  voidsFrom(m.currentSeats, m.current);

  // Shown cards: theirs for certain (while unplayed), and their mark rules
  // out others of the suit.
  final shownBy = <PlayingCard, int>{};
  for (final e in m.revealed.entries) {
    if (!played.contains(e.value)) shownBy[e.value] = e.key;
  }
  // Everyone knows who the King is, so everyone knows who holds the King.
  if (!played.contains(PlayingCard.king) &&
      m.king != viewer &&
      m.king >= 0 &&
      m.king < m.players) {
    shownBy[PlayingCard.king] = m.king;
  }
  bool ruledOut(HandGuess g, PlayingCard c) {
    final owner = shownBy[c];
    if (owner != null) return owner != g.seat;
    if (g.voids.contains(c.suit)) return true;
    final r = m.revealed[g.seat];
    final hint = m.revealHint[g.seat];
    if (r != null && hint != null && c.suit == r.suit && c != r) {
      if (hint == 'only') return true;
      if (hint == 'highest' && c.rank > r.rank) return true;
      if (hint == 'lowest' && c.rank < r.rank) return true;
    }
    return false;
  }

  for (final g in guesses) {
    for (final c in unseen) {
      if (!ruledOut(g, c)) g.possible.add(c);
    }
    for (final e in shownBy.entries) {
      if (e.value == g.seat) g.certain.add(e.key);
    }
  }

  // Narrow it down: a hand with exactly as many possible cards as it holds
  // must hold them all; a card only one player could hold is theirs (unless
  // it might have been set aside).
  final maybeSetAside = m.setAside.isNotEmpty;
  for (var changed = true; changed;) {
    changed = false;
    for (final g in guesses) {
      if (g.possible.length == g.size && g.certain.length < g.size) {
        g.certain.addAll(g.possible);
        changed = true;
      }
    }
    if (!maybeSetAside) {
      for (final c in unseen) {
        final holders = [for (final g in guesses) if (g.possible.contains(c)) g];
        if (holders.length == 1 && holders.single.certain.add(c)) changed = true;
      }
    }
    // A full set of certain cards leaves no room for anything else.
    for (final g in guesses) {
      if (g.certain.length == g.size && g.possible.length > g.size) {
        g.possible.retainAll(g.certain);
        changed = true;
      }
    }
    // Cards certain for one player can't be anyone else's.
    for (final g in guesses) {
      for (final c in g.certain) {
        for (final o in guesses) {
          if (o != g && o.possible.remove(c)) changed = true;
        }
      }
    }
  }
  return guesses;
}
