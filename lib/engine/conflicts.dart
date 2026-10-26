/// What each task needs and forbids, so a round never deals tasks that
/// can't all be done, and a player isn't handed two that fight each other.
library;

import 'cards.dart';

/// The parts of a task that can clash with others.
class TaskProfile {
  const TaskProfile({
    this.cards = const {},
    this.tricks = const {},
    this.ranks = const {},
    this.suits = const {},
    this.courts = 0,
    this.mostTricks = false,
    this.forbidCard,
    this.maxTricks,
    this.forbidTricks = const {},
  });

  /// Specific cards the holder must win.
  final Set<PlayingCard> cards;

  /// Tricks the holder must win, by number; -1 is the last trick.
  final Set<int> tricks;

  /// At least this many cards of a rank (1 = Ace) the holder must win.
  final Map<int, int> ranks;

  /// At least this many cards of a suit the holder must win.
  final Map<Suit, int> suits;

  /// At least this many Court Cards the holder must win.
  final int courts;

  /// The holder must win more tricks than anyone else.
  final bool mostTricks;

  /// Cards the holder must not win.
  final bool Function(PlayingCard c)? forbidCard;

  /// The most tricks the holder may win, if limited.
  final int? maxTricks;

  /// Tricks the holder must not win, by number.
  final Set<int> forbidTricks;

  /// The fewest tricks the holder must win.
  int get minTricks => tricks.length;
}

PlayingCard _c(String l) => PlayingCard.parse(l)!;
Set<PlayingCard> _cs(List<String> ls) => {for (final l in ls) _c(l)};
Set<PlayingCard> _rank(int r) => {
      for (final s in [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs])
        PlayingCard(s, r)
    };

final Map<String, TaskProfile> _profiles = {
  'Win more tricks than everyone else': const TaskProfile(mostTricks: true),
  'Win more tricks than everyone else together':
      const TaskProfile(mostTricks: true),
  'Win the 3♥': TaskProfile(cards: _cs(['3♥'])),
  'Win the A♦': TaskProfile(cards: _cs(['A♦'])),
  'Win the 4♠': TaskProfile(cards: _cs(['4♠'])),
  'Win the 6♣': TaskProfile(cards: _cs(['6♣'])),
  'Win all four 3s': TaskProfile(cards: _rank(3)),
  'Win all four 9s': TaskProfile(cards: _rank(9)),
  'Win at least three 5s': const TaskProfile(ranks: {5: 3}),
  'Win at least three 9s': const TaskProfile(ranks: {9: 3}),
  'Win at least two 7s': const TaskProfile(ranks: {7: 2}),
  'Win exactly three 6s': const TaskProfile(ranks: {6: 3}),
  'Win exactly two 9s': const TaskProfile(ranks: {9: 2}),
  'Win the A♠, 2♠ and 3♠': TaskProfile(cards: _cs(['A♠', '2♠', '3♠'])),
  'Win the 6♠ and the 7♦': TaskProfile(cards: _cs(['6♠', '7♦'])),
  'Win the 5♥ and the 6♦': TaskProfile(cards: _cs(['5♥', '6♦'])),
  'Win the 5♣ and the 8♠': TaskProfile(cards: _cs(['5♣', '8♠'])),
  'Win the 5♠ and the 8♥': TaskProfile(cards: _cs(['5♠', '8♥'])),
  'Win the 9♥ and the 8♦': TaskProfile(cards: _cs(['9♥', '8♦'])),
  'Win the A♥ and the 7♣': TaskProfile(cards: _cs(['A♥', '7♣'])),
  'Win the 9♦ and the 7♠': TaskProfile(cards: _cs(['9♦', '7♠'])),
  'Win the 3♣, 4♦ and 5♦': TaskProfile(cards: _cs(['3♣', '4♦', '5♦'])),
  'Win the 2♣ in the last trick':
      TaskProfile(cards: _cs(['2♣']), tricks: const {-1}),
  'Win exactly one ♥ and one ♣ card':
      const TaskProfile(suits: {Suit.hearts: 1, Suit.clubs: 1}),
  'Win at least seven ♦ cards': const TaskProfile(suits: {Suit.diamonds: 7}),
  'Win at least five ♥ cards': const TaskProfile(suits: {Suit.hearts: 5}),
  'Win exactly two ♣ cards': const TaskProfile(suits: {Suit.clubs: 2}),
  'Win exactly two ♠ cards': const TaskProfile(suits: {Suit.spades: 2}),
  'Win exactly one ♥ card': const TaskProfile(suits: {Suit.hearts: 1}),
  'Win no ♥ cards':
      TaskProfile(forbidCard: (c) => c.suit == Suit.hearts),
  'Win exactly one Court Card (redeal if one player holds all four)':
      const TaskProfile(courts: 1),
  'Win the Joker and no other Court Card (redeal if one player holds the Joker and King, or the Joker, Jack and Queen)':
      TaskProfile(
          cards: {PlayingCard.joker},
          courts: 1,
          forbidCard: (c) => c.isCourt && c != PlayingCard.joker),
  'Win the Jack and no other Court Card (redeal if one player holds the Jack and King, or the Joker, Jack and Queen)':
      TaskProfile(
          cards: {PlayingCard.jack},
          courts: 1,
          forbidCard: (c) => c.isCourt && c != PlayingCard.jack),
  'Win the Queen': TaskProfile(cards: {PlayingCard.queen}, courts: 1),
  'Win exactly two Court Cards (redeal if one player holds the Jack, Queen and King)':
      const TaskProfile(courts: 2),
  'Win exactly three Court Cards (redeal if one player holds all four)':
      const TaskProfile(courts: 3),
  'Win no Court Cards': TaskProfile(forbidCard: (c) => c.isCourt),
  'Win the 7♥ with a Court Card': TaskProfile(cards: _cs(['7♥']), courts: 1),
  'Win the 9♣ with a Court Card': TaskProfile(cards: _cs(['9♣']), courts: 1),
  "Don't win any ♣ cards":
      TaskProfile(forbidCard: (c) => c.suit == Suit.clubs),
  "Don't win any ♦ cards":
      TaskProfile(forbidCard: (c) => c.suit == Suit.diamonds),
  "Don't win any ♥ or ♠ cards": TaskProfile(
      forbidCard: (c) => c.suit == Suit.hearts || c.suit == Suit.spades),
  "Don't win any ♦ or ♣ cards": TaskProfile(
      forbidCard: (c) => c.suit == Suit.diamonds || c.suit == Suit.clubs),
  "Don't win any 8s or 9s":
      TaskProfile(forbidCard: (c) => !c.isCourt && c.rank >= 8),
  "Don't win any 9s": TaskProfile(forbidCard: (c) => !c.isCourt && c.rank == 9),
  "Don't win any 5s": TaskProfile(forbidCard: (c) => !c.isCourt && c.rank == 5),
  "Don't win any Aces":
      TaskProfile(forbidCard: (c) => !c.isCourt && c.rank == 1),
  "Don't win any Aces, 2s or 3s":
      TaskProfile(forbidCard: (c) => !c.isCourt && c.rank <= 3),
  "Don't win any of the first four tricks":
      const TaskProfile(forbidTricks: {0, 1, 2, 3}),
  "Don't win any of the first three tricks":
      const TaskProfile(forbidTricks: {0, 1, 2}),
  "Don't win any of the first five tricks":
      const TaskProfile(forbidTricks: {0, 1, 2, 3, 4}),
  "Don't win any tricks": const TaskProfile(maxTricks: 0),
  'Win the last trick': const TaskProfile(tricks: {-1}),
  'Win the first three tricks': const TaskProfile(tricks: {0, 1, 2}),
  'Win the first two tricks': const TaskProfile(tricks: {0, 1}),
  'Win the first trick': const TaskProfile(tricks: {0}),
  'Win the first and the last trick': const TaskProfile(tricks: {0, -1}),
  'Win only the last trick': const TaskProfile(tricks: {-1}, maxTricks: 1),
  'Win only the first trick': const TaskProfile(tricks: {0}, maxTricks: 1),
  'Win exactly one trick': const TaskProfile(maxTricks: 1),
  'Win exactly two tricks': const TaskProfile(maxTricks: 2),
  'Win exactly four tricks': const TaskProfile(maxTricks: 4),
  "Win exactly three tricks, and they're in a row":
      const TaskProfile(maxTricks: 3),
  "Win exactly two tricks, and they're in a row":
      const TaskProfile(maxTricks: 2),
  'Win a trick with a 4': const TaskProfile(ranks: {4: 1}),
  'Win a trick with a 7': const TaskProfile(ranks: {7: 1}),
  'Win the 2♦': TaskProfile(cards: _cs(['2♦'])),
  'Win the 8♣': TaskProfile(cards: _cs(['8♣'])),
  'Win the 9♠': TaskProfile(cards: _cs(['9♠'])),
  'Win the 2♥ and the 3♦': TaskProfile(cards: _cs(['2♥', '3♦'])),
  'Win at least two Aces': const TaskProfile(ranks: {1: 2}),
  'Win at least four ♠ cards': const TaskProfile(suits: {Suit.spades: 4}),
  'Win a trick containing an Ace and a 9':
      const TaskProfile(ranks: {1: 1, 9: 1}),
  'Win a trick led with a Court Card': const TaskProfile(courts: 1),
  'Win a 9 with a Court Card': const TaskProfile(ranks: {9: 1}, courts: 1),
};

TaskProfile profileOf(String description) =>
    _profiles[description] ?? const TaskProfile();

/// Cards (and the parts of the deck) a task asks its holder to win, for
/// highlighting them in a hand.
Set<PlayingCard> neededCards(String description) =>
    profileOf(description).cards;

/// Whether two tasks can't both be done when different players hold them.
bool clash(String a, String b) {
  final p = profileOf(a), q = profileOf(b);
  if (p.cards.intersection(q.cards).isNotEmpty) return true;
  if (p.tricks.intersection(q.tricks).isNotEmpty) return true;
  if (p.mostTricks && q.mostTricks) return true;
  // Not enough of a rank, a suit or Court Cards to go round.
  for (int r = 1; r <= 9; r++) {
    int need(TaskProfile t) => [
          t.ranks[r] ?? 0,
          t.cards.where((c) => !c.isCourt && c.rank == r).length,
        ].reduce((x, y) => x > y ? x : y);
    if (need(p) + need(q) > 4) return true;
  }
  for (final s in [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs]) {
    int need(TaskProfile t) => [
          t.suits[s] ?? 0,
          t.cards.where((c) => c.suit == s).length,
        ].reduce((x, y) => x > y ? x : y);
    if (need(p) + need(q) > 9) return true;
  }
  if (p.courts + q.courts > 4) return true;
  return false;
}

/// Whether adding [next] to the tasks already [drawn] would leave a card
/// nobody may win: every player would need an "avoid" task that forbids it,
/// but someone has to win every trick. Conservative: counts the tasks that
/// forbid each card, and allows at most one fewer than there are players
/// (so whoever's left can always take it).
bool overAvoided(List<String> drawn, String next, int players) {
  final all = [...drawn, next];
  int forbidding(PlayingCard c) => all.where((d) {
        final p = profileOf(d);
        if (p.maxTricks == 0) return true;
        return p.forbidCard?.call(c) ?? false;
      }).length;
  for (final c in fullDeck()) {
    if (forbidding(c) >= players) return true;
  }
  // Tasks that win no tricks at all: someone else must win them all.
  final none = all.where((d) => profileOf(d).maxTricks == 0).length;
  return none >= players;
}

/// Whether one player can't do both tasks, at a table of [players]
/// (the 2-player game deals three hands).
bool selfClash(String a, String b, {int players = 4}) {
  final p = profileOf(a), q = profileOf(b);
  // "More tricks than everyone else" with a cap on your own tricks: the
  // others can't share out the rest without one of them catching up.
  final hands = players < 3 ? 3 : players;
  final total = 40 ~/ hands;
  bool tooFew(String most, TaskProfile capped) {
    final n = capped.maxTricks;
    if (n == null) return false;
    if (most == 'Win more tricks than everyone else together') {
      return n * 2 <= total;
    }
    if (most == 'Win more tricks than everyone else') {
      return n + (hands - 1) * (n - 1) < total;
    }
    return false;
  }

  if (p.mostTricks && tooFew(a, q) || q.mostTricks && tooFew(b, p)) return true;
  bool forbids(TaskProfile f, TaskProfile n) {
    final bad = f.forbidCard;
    if (bad != null && n.cards.any(bad)) return true;
    // Counting tasks: not enough of what's counted is left once the other
    // task rules some of it out ("Don't win any 9s" with "Win at least
    // three 9s").
    if (bad != null) {
      final deck = fullDeck();
      for (final e in n.ranks.entries) {
        final ok = deck.where((c) => !c.isCourt && c.rank == e.key && !bad(c));
        if (ok.length < e.value) return true;
      }
      for (final e in n.suits.entries) {
        final ok = deck.where((c) => c.suit == e.key && !bad(c));
        if (ok.length < e.value) return true;
      }
      if (n.courts > 0 &&
          deck.where((c) => c.isCourt && !bad(c)).length < n.courts) {
        return true;
      }
    }
    if (f.maxTricks != null && n.minTricks > f.maxTricks!) return true;
    if (f.forbidTricks.intersection(n.tricks).isNotEmpty) return true;
    if (f.maxTricks == 0 && (n.cards.isNotEmpty || n.mostTricks)) return true;
    return false;
  }

  if (forbids(p, q) || forbids(q, p)) return true;
  // Two different exact trick counts.
  if (p.maxTricks != null &&
      q.maxTricks != null &&
      p.maxTricks != q.maxTricks &&
      (a.startsWith('Win exactly') || a.startsWith("Don't win any tricks")) &&
      (b.startsWith('Win exactly') || b.startsWith("Don't win any tricks"))) {
    return true;
  }
  return false;
}

/// Why a player holding [hand] can't do [d] at all, or null. Some tasks
/// need a particular card in your own hand ("Win a trick with a 6"), and
/// one can't be done if you hold the card it names ("Win the 7♥ with a
/// Court Card": you can't play the 7♥ and a Court Card in one trick).
String? handBlocks(String d, List<PlayingCard> hand) {
  final court = RegExp(r'^Win the ([A2-9][♥♦♠♣]) with a Court Card$').firstMatch(d);
  if (court != null) {
    final card = PlayingCard.parse(court.group(1)!)!;
    if (hand.contains(card)) {
      return 'You hold the ${card.label}: you can’t play it and win it with a Court Card in the same trick';
    }
    if (!hand.any((c) => c.isCourt)) return 'You need a Court Card in your hand for this';
  }
  if ((d == 'Win a 9 with a Court Card' || d == 'Win a trick led with a Court Card') &&
      !hand.any((c) => c.isCourt)) {
    return 'You need a Court Card in your hand for this';
  }
  bool has(int r) => hand.any((c) => !c.isCourt && c.rank == r);
  final withRank = RegExp(r'^Win (?:a trick|a \d|an \d|any \d) with (?:a|another) (\d)$').firstMatch(d);
  if (withRank != null) {
    final r = int.parse(withRank.group(1)!);
    if (!has(r)) return 'You need a $r in your hand to win a trick with it';
  }
  return null;
}

/// Every task that has a profile (for tests: they must all be real tasks).
Iterable<String> get profiledTasks => _profiles.keys;
