/// Every task, written as a rule the computer can check as the tricks are
/// played. A rule looks at the tricks so far and answers: done, failed, or
/// not decided yet. When the last trick is in, it must decide.
library;

import 'cards.dart';

enum Verdict { pending, done, failed }

/// What a rule can see: the tricks played so far in the round.
class RoundView {
  RoundView({
    required this.players,
    required this.king,
    required this.tricks,
    required this.totalTricks,
    required this.inPlay,
  });

  final int players;
  final int king;
  final List<Trick> tricks;
  final int totalTricks;

  /// The cards dealt this round (the deck minus any set aside).
  final Set<PlayingCard> inPlay;

  bool get over => tricks.length >= totalTricks;

  int tricksWon(int seat) => tricks.where((t) => t.winner == seat).length;

  Iterable<PlayingCard> won(int seat) =>
      tricks.where((t) => t.winner == seat).expand((t) => t.cards);

  Iterable<PlayingCard> wonByOthers(int seat) =>
      tricks.where((t) => t.winner != seat).expand((t) => t.cards);

  int countWon(int seat, bool Function(PlayingCard) test) =>
      won(seat).where(test).length;

  /// Cards matching [test] still to be played.
  int countLeft(bool Function(PlayingCard) test) {
    final played = tricks.expand((t) => t.cards).toSet();
    return inPlay.where((c) => !played.contains(c) && test(c)).length;
  }

  /// Which tricks [seat] won, by number (0 = the first trick).
  List<int> wonIndexes(int seat) => [
        for (int i = 0; i < tricks.length; i++)
          if (tricks[i].winner == seat) i
      ];

  /// The longest run of tricks in a row won by [seat].
  int longestRun(int seat) {
    int best = 0, run = 0;
    for (final t in tricks) {
      run = t.winner == seat ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }
}

/// A rule: [owner] holds the task; [x] is the number they announced, for
/// the "exactly X tricks" tasks.
typedef TaskRule = Verdict Function(RoundView v, int owner, int? x);

// ------------------------------------------------------------- building blocks

Verdict _end(RoundView v, bool success) => v.over
    ? (success ? Verdict.done : Verdict.failed)
    : Verdict.pending;

/// Done as soon as [owner] wins a trick passing [test]; failed if the
/// round ends without one.
TaskRule anyTrick(bool Function(Trick t) test) => (v, owner, _) =>
    v.tricks.any((t) => t.winner == owner && test(t))
        ? Verdict.done
        : _end(v, false);

/// Failed as soon as [bad] happens; done once the round ends without it.
TaskRule never(bool Function(RoundView v, int owner) bad) =>
    (v, owner, _) => bad(v, owner) ? Verdict.failed : _end(v, true);

/// Decided at the end of the round.
TaskRule atEnd(bool Function(RoundView v, int owner) success) =>
    (v, owner, _) => _end(v, success(v, owner));

/// Win every one of [cards]: failed once anyone else wins one.
TaskRule winAll(List<PlayingCard> cards) => (v, owner, _) {
      if (v.wonByOthers(owner).any(cards.contains)) return Verdict.failed;
      final mine = v.won(owner).toSet();
      if (cards.every(mine.contains)) return Verdict.done;
      return _end(v, false);
    };

/// Win at least [n] cards passing [test].
TaskRule atLeast(int n, bool Function(PlayingCard) test) => (v, owner, _) {
      final mine = v.countWon(owner, test);
      if (mine >= n) return Verdict.done;
      if (mine + v.countLeft(test) < n) return Verdict.failed;
      return _end(v, false);
    };

/// Win exactly [n] cards passing [test].
TaskRule exactly(int n, bool Function(PlayingCard) test) => (v, owner, _) {
      final mine = v.countWon(owner, test);
      if (mine > n || mine + v.countLeft(test) < n) return Verdict.failed;
      if (mine == n && v.countLeft(test) == 0) return Verdict.done;
      return _end(v, mine == n);
    };

/// Win no cards passing [test].
TaskRule winNone(bool Function(PlayingCard) test) =>
    never((v, owner) => v.won(owner).any(test));

bool Function(PlayingCard) _suit(Suit s) => (c) => c.suit == s;
bool Function(PlayingCard) _rank(int r) => (c) => !c.isCourt && c.rank == r;
bool _court(PlayingCard c) => c.isCourt;
PlayingCard _c(String label) => PlayingCard.parse(label)!;
List<PlayingCard> _cs(List<String> labels) => [for (final l in labels) _c(l)];

/// "Win a trick with a 6": the card you won it with is a 6.
TaskRule winWith(int rank, {bool Function(Trick t)? also}) => anyTrick((t) {
      final w = t.winningCard;
      return !w.isCourt && w.rank == rank && (also?.call(t) ?? true);
    });

/// Win [card] with a Court Card. Failed if it falls any other way.
TaskRule winWithCourt(PlayingCard card) => (v, owner, _) {
      for (final t in v.tricks) {
        if (!t.cards.contains(card)) continue;
        return t.winner == owner && t.winningCard.isCourt
            ? Verdict.done
            : Verdict.failed;
      }
      return _end(v, false);
    };

/// Total of a trick's card values, or null if it has a Court Card.
int? _total(Trick t) =>
    t.cards.any(_court) ? null : t.cards.fold<int>(0, (a, c) => a + c.rank);

/// "Don't win any of the first [n] tricks."
TaskRule notFirst(int n) => (v, owner, _) {
      final early = v.tricks.take(n);
      if (early.any((t) => t.winner == owner)) return Verdict.failed;
      return v.tricks.length >= n || v.over ? Verdict.done : Verdict.pending;
    };

/// "Win the first [n] tricks."
TaskRule firstN(int n) => (v, owner, _) {
      final early = v.tricks.take(n).toList();
      if (early.any((t) => t.winner != owner)) return Verdict.failed;
      return early.length >= n ? Verdict.done : _end(v, false);
    };

/// Win exactly [n] tricks.
TaskRule exactTricks(int n) => (v, owner, _) {
      final mine = v.tricksWon(owner);
      if (mine > n) return Verdict.failed;
      if (mine + (v.totalTricks - v.tricks.length) < n) return Verdict.failed;
      return _end(v, mine == n);
    };

/// A trick where every plain card passes [test] and there are no Court
/// Cards.
bool _plainTrick(Trick t, bool Function(PlayingCard) test) =>
    t.cards.every((c) => !c.isCourt && test(c));

/// Totals for the "more than" and "less than" tasks, by player count.
int _byCount(int players, List<int> values) =>
    values[players <= 3 ? 0 : players - 3];

// ---------------------------------------------------------------- the rules

final Map<String, TaskRule> taskRules = {
  'Win more tricks than everyone else': atEnd((v, o) => [
        for (int s = 0; s < v.players; s++)
          if (s != o) s
      ].every((s) => v.tricksWon(o) > v.tricksWon(s))),
  'Win more tricks than everyone else together': atEnd((v, o) =>
      v.tricksWon(o) > v.tricks.length - v.tricksWon(o)),
  'Win fewer tricks than everyone else': atEnd((v, o) => [
        for (int s = 0; s < v.players; s++)
          if (s != o) s
      ].every((s) => v.tricksWon(o) < v.tricksWon(s))),
  'Win more tricks than the King':
      atEnd((v, o) => v.tricksWon(o) > v.tricksWon(v.king)),
  'Win fewer tricks than the King':
      atEnd((v, o) => v.tricksWon(o) < v.tricksWon(v.king)),
  'Win the same number of tricks as the King':
      atEnd((v, o) => v.tricksWon(o) == v.tricksWon(v.king)),
  'Win a trick where every card is lower than 7, with no Court Cards':
      anyTrick((t) => _plainTrick(t, (c) => c.rank < 7)),
  'Win a trick where every card is higher than 5':
      anyTrick((t) => t.cards.every((c) => c.isCourt || c.rank > 5)),
  'Win a trick with a 6': winWith(6),
  'Win a trick with a 5': winWith(5),
  'Win a trick with a 3': winWith(3),
  'Win a 5 with a 7':
      winWith(7, also: (t) => t.cards.any(_rank(5))),
  'Win an 8 with a 4':
      winWith(4, also: (t) => t.cards.any(_rank(8))),
  'Win any 6 with another 6':
      winWith(6, also: (t) => t.cards.where(_rank(6)).length >= 2),
  'Win a trick with a 2': winWith(2),
  'Win the 3♥': winAll(_cs(['3♥'])),
  'Win the A♦': winAll(_cs(['A♦'])),
  'Win the 4♠': winAll(_cs(['4♠'])),
  'Win the 6♣': winAll(_cs(['6♣'])),
  'Win all four 3s': winAll(_cs(['3♥', '3♦', '3♠', '3♣'])),
  'Win at least three 5s': atLeast(3, _rank(5)),
  'Win at least three 9s': atLeast(3, _rank(9)),
  'Win at least two 7s': atLeast(2, _rank(7)),
  'Win all four 9s': winAll(_cs(['9♥', '9♦', '9♠', '9♣'])),
  'Win exactly three 6s': exactly(3, _rank(6)),
  'Win exactly two 9s': exactly(2, _rank(9)),
  'Win the A♠, 2♠ and 3♠': winAll(_cs(['A♠', '2♠', '3♠'])),
  'Win the 6♠ and the 7♦': winAll(_cs(['6♠', '7♦'])),
  'Win the 5♥ and the 6♦': winAll(_cs(['5♥', '6♦'])),
  'Win the 5♣ and the 8♠': winAll(_cs(['5♣', '8♠'])),
  'Win the 5♠ and the 8♥': winAll(_cs(['5♠', '8♥'])),
  'Win the 9♥ and the 8♦': winAll(_cs(['9♥', '8♦'])),
  'Win the A♥ and the 7♣': winAll(_cs(['A♥', '7♣'])),
  'Win the 9♦ and the 7♠': winAll(_cs(['9♦', '7♠'])),
  'Win the 3♣, 4♦ and 5♦': winAll(_cs(['3♣', '4♦', '5♦'])),
  'Win the 2♣ in the last trick': (v, o, _) {
    final two = _c('2♣');
    for (int i = 0; i < v.tricks.length; i++) {
      if (!v.tricks[i].cards.contains(two)) continue;
      return i == v.totalTricks - 1 && v.tricks[i].winner == o
          ? Verdict.done
          : Verdict.failed;
    }
    return _end(v, false);
  },
  'Win exactly one ♥ and one ♣ card': (v, o, x) {
    final h = exactly(1, _suit(Suit.hearts))(v, o, x);
    final c = exactly(1, _suit(Suit.clubs))(v, o, x);
    if (h == Verdict.failed || c == Verdict.failed) return Verdict.failed;
    if (h == Verdict.done && c == Verdict.done) return Verdict.done;
    return Verdict.pending;
  },
  'Win at least seven ♦ cards': atLeast(7, _suit(Suit.diamonds)),
  'Win at least five ♥ cards': atLeast(5, _suit(Suit.hearts)),
  'Win exactly two ♣ cards': exactly(2, _suit(Suit.clubs)),
  'Win exactly two ♠ cards': exactly(2, _suit(Suit.spades)),
  'Win exactly one ♥ card': exactly(1, _suit(Suit.hearts)),
  'Win no ♥ cards': winNone(_suit(Suit.hearts)),
  "Win at least one card of each suit (Court Cards don't count)": (v, o, _) {
    const suits = [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs];
    final mine = v.won(o);
    if (suits.every((s) => mine.any(_suit(s)))) return Verdict.done;
    final lost = suits.any((s) =>
        !mine.any(_suit(s)) && v.countLeft(_suit(s)) == 0);
    return lost ? Verdict.failed : _end(v, false);
  },
  "Win every card of at least one suit (Court Cards don't count)": (v, o, _) {
    const suits = [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs];
    final others = v.wonByOthers(o);
    final open = suits.where((s) => !others.any(_suit(s)));
    if (open.isEmpty) return Verdict.failed;
    if (open.any((s) => v.countLeft(_suit(s)) == 0)) return Verdict.done;
    return _end(v, false);
  },
  'Win a trick of only even numbers (that means only 2s, 4s, 6s and 8s)':
      anyTrick((t) => _plainTrick(t, (c) => c.rank.isEven)),
  'Win a trick of only odd numbers (that means only Aces, 3s, 5s, 7s and 9s)':
      anyTrick((t) => _plainTrick(t, (c) => c.rank.isOdd)),
  'Win a trick totalling more than 23 / 28 / 31 / 34 (2–3 / 4 / 5 / 6 players), with no Court Cards':
      (v, o, x) => anyTrick((t) {
            final total = _total(t);
            return total != null && total > _byCount(v.players, [23, 28, 31, 34]);
          })(v, o, x),
  'Win a trick totalling less than 8 / 12 / 16 / 20 (2–3 / 4 / 5 / 6 players), with no Court Cards':
      (v, o, x) => anyTrick((t) {
            final total = _total(t);
            return total != null && total < _byCount(v.players, [8, 12, 16, 20]);
          })(v, o, x),
  'Win a trick totalling exactly 22 or 23': anyTrick((t) {
    final total = _total(t);
    return total == 22 || total == 23;
  }),
  'Win exactly one Court Card (redeal if one player holds all four)':
      exactly(1, _court),
  'Win the Joker and no other Court Card (redeal if one player holds the Joker and King, or the Joker, Jack and Queen)':
      (v, o, _) {
    final others = v.wonByOthers(o);
    final mine = v.won(o);
    if (others.contains(PlayingCard.joker) ||
        mine.any((c) => c.isCourt && c != PlayingCard.joker)) {
      return Verdict.failed;
    }
    final rest = v.countLeft((c) => c.isCourt && c != PlayingCard.joker);
    if (mine.contains(PlayingCard.joker) && rest == 0) return Verdict.done;
    return _end(v, mine.contains(PlayingCard.joker));
  },
  'Win the Jack and no other Court Card (redeal if one player holds the Jack and King, or the Joker, Jack and Queen)':
      (v, o, _) {
    final others = v.wonByOthers(o);
    final mine = v.won(o);
    if (others.contains(PlayingCard.jack) ||
        mine.any((c) => c.isCourt && c != PlayingCard.jack)) {
      return Verdict.failed;
    }
    final rest = v.countLeft((c) => c.isCourt && c != PlayingCard.jack);
    if (mine.contains(PlayingCard.jack) && rest == 0) return Verdict.done;
    return _end(v, mine.contains(PlayingCard.jack));
  },
  'Win the Queen': winAll(const [PlayingCard.queen]),
  'Win exactly two Court Cards (redeal if one player holds the Jack, Queen and King)':
      exactly(2, _court),
  'Win exactly three Court Cards (redeal if one player holds all four)':
      exactly(3, _court),
  'Win no Court Cards': winNone(_court),
  'Win the 7♥ with a Court Card': winWithCourt(_c('7♥')),
  'Win the 9♣ with a Court Card': winWithCourt(_c('9♣')),
  "Don't lead a trick with a ♥, ♦ or ♠ card": never((v, o) => v.tricks.any(
      (t) => t.leader == o &&
          const [Suit.hearts, Suit.diamonds, Suit.spades].contains(t.led.suit))),
  "Don't lead a trick with a ♥ or ♣ card": never((v, o) => v.tricks.any(
      (t) => t.leader == o &&
          const [Suit.hearts, Suit.clubs].contains(t.led.suit))),
  "Don't win any ♣ cards": winNone(_suit(Suit.clubs)),
  "Don't win any ♦ cards": winNone(_suit(Suit.diamonds)),
  "Don't win any ♥ or ♠ cards":
      winNone((c) => c.suit == Suit.hearts || c.suit == Suit.spades),
  "Don't win any ♦ or ♣ cards":
      winNone((c) => c.suit == Suit.diamonds || c.suit == Suit.clubs),
  "Don't win any 8s or 9s":
      winNone((c) => !c.isCourt && (c.rank == 8 || c.rank == 9)),
  "Don't win any 9s": winNone(_rank(9)),
  "Don't win any 5s": winNone(_rank(5)),
  "Don't win any Aces": winNone(_rank(1)),
  "Don't win any Aces, 2s or 3s": winNone((c) => !c.isCourt && c.rank <= 3),
  "Don't win any of the first four tricks": notFirst(4),
  "Don't win any of the first three tricks": notFirst(3),
  "Don't win any of the first five tricks": notFirst(5),
  "Don't win any tricks": never((v, o) => v.tricksWon(o) > 0),
  "Don't win two tricks in a row": never((v, o) => v.longestRun(o) >= 2),
  'Win the last trick': atEnd((v, o) => v.tricks.last.winner == o),
  'Win the first three tricks': firstN(3),
  'Win the first two tricks': firstN(2),
  'Win the first trick': firstN(1),
  'Win the first and the last trick': (v, o, _) {
    if (v.tricks.isNotEmpty && v.tricks.first.winner != o) {
      return Verdict.failed;
    }
    return _end(v, v.tricks.isNotEmpty && v.tricks.last.winner == o);
  },
  'Win only the last trick': (v, o, _) {
    final mine = v.wonIndexes(o);
    if (mine.any((i) => i != v.totalTricks - 1)) return Verdict.failed;
    return _end(v, mine.length == 1);
  },
  'Win only the first trick': (v, o, _) {
    final mine = v.wonIndexes(o);
    if (v.tricks.isNotEmpty && v.tricks.first.winner != o) {
      return Verdict.failed;
    }
    if (mine.any((i) => i != 0)) return Verdict.failed;
    return _end(v, true);
  },
  'Win exactly one trick': exactTricks(1),
  'Win exactly two tricks': exactTricks(2),
  'Win two tricks in a row': (v, o, _) =>
      v.longestRun(o) >= 2 ? Verdict.done : _end(v, false),
  'Win three tricks in a row': (v, o, _) =>
      v.longestRun(o) >= 3 ? Verdict.done : _end(v, false),
  'Win exactly four tricks': exactTricks(4),
  "Win exactly three tricks, and they're in a row": (v, o, x) {
    final e = exactTricks(3)(v, o, x);
    if (e == Verdict.failed) return e;
    return _end(v, v.tricksWon(o) == 3 && v.longestRun(o) == 3);
  },
  "Win exactly two tricks, and they're in a row": (v, o, x) {
    final e = exactTricks(2)(v, o, x);
    if (e == Verdict.failed) return e;
    return _end(v, v.tricksWon(o) == 2 && v.longestRun(o) == 2);
  },
  'Win exactly X tricks, announced to everyone': (v, o, x) =>
      exactTricks(x ?? 0)(v, o, x),
  'Win exactly X tricks, kept secret (write X down and keep it hidden)':
      (v, o, x) => exactTricks(x ?? 0)(v, o, x),
  'Win as many ♥ cards as ♦ cards (you must win at least one of each)':
      atEnd((v, o) {
    final h = v.countWon(o, _suit(Suit.hearts));
    final d = v.countWon(o, _suit(Suit.diamonds));
    return h == d && h > 0;
  }),
  'Win a trick with as many ♣ cards as ♦ cards (you must win at least one of each)':
      anyTrick((t) {
    final c = t.cards.where(_suit(Suit.clubs)).length;
    final d = t.cards.where(_suit(Suit.diamonds)).length;
    return c == d && c > 0;
  }),
  'Win a trick with as many ♥ cards as ♠ cards (you must win at least one of each)':
      anyTrick((t) {
    final h = t.cards.where(_suit(Suit.hearts)).length;
    final s = t.cards.where(_suit(Suit.spades)).length;
    return h == s && h > 0;
  }),
  'Win more ♦ cards than ♠ cards (winning no ♠ cards is fine)': atEnd((v, o) =>
      v.countWon(o, _suit(Suit.diamonds)) > v.countWon(o, _suit(Suit.spades))),
  'Win more ♥ cards than ♣ cards (winning no ♣ cards is fine)': atEnd((v, o) =>
      v.countWon(o, _suit(Suit.hearts)) > v.countWon(o, _suit(Suit.clubs))),
  'Win a mixed-suit trick with no Court Cards': anyTrick((t) =>
      !t.cards.any(_court) && t.cards.map((c) => c.suit).toSet().length > 1),
};

/// When a task can be completed, which decides whether a seal on it makes
/// sense. A seal orders tasks by when they're done, so it needs tasks that
/// can be done on any trick: a task only settled when the round ends
/// ("Don't win any ♦ cards") can't come before anything, and one settled by
/// the first few tricks can't come after anything.
enum TaskTiming {
  /// Done the moment it happens, on any trick.
  anyTrick,

  /// Settled within the first few tricks.
  early,

  /// Only settled when the round ends (or close to it).
  end,
}

const _anyTrickTasks = {
  'Win a trick where every card is lower than 7, with no Court Cards',
  'Win a trick where every card is higher than 5',
  'Win a trick with a 6',
  'Win a trick with a 5',
  'Win a trick with a 3',
  'Win a 5 with a 7',
  'Win an 8 with a 4',
  'Win any 6 with another 6',
  'Win a trick with a 2',
  'Win the 3♥',
  'Win the A♦',
  'Win the 4♠',
  'Win the 6♣',
  'Win all four 3s',
  'Win at least three 5s',
  'Win at least three 9s',
  'Win at least two 7s',
  'Win all four 9s',
  'Win the A♠, 2♠ and 3♠',
  'Win the 6♠ and the 7♦',
  'Win the 5♥ and the 6♦',
  'Win the 5♣ and the 8♠',
  'Win the 5♠ and the 8♥',
  'Win the 9♥ and the 8♦',
  'Win the A♥ and the 7♣',
  'Win the 9♦ and the 7♠',
  'Win the 3♣, 4♦ and 5♦',
  'Win at least seven ♦ cards',
  'Win at least five ♥ cards',
  "Win at least one card of each suit (Court Cards don't count)",
  'Win a trick of only even numbers (that means only 2s, 4s, 6s and 8s)',
  'Win a trick of only odd numbers (that means only Aces, 3s, 5s, 7s and 9s)',
  'Win a trick totalling more than 23 / 28 / 31 / 34 (2–3 / 4 / 5 / 6 players), with no Court Cards',
  'Win a trick totalling less than 8 / 12 / 16 / 20 (2–3 / 4 / 5 / 6 players), with no Court Cards',
  'Win a trick totalling exactly 22 or 23',
  'Win the Queen',
  'Win the 7♥ with a Court Card',
  'Win the 9♣ with a Court Card',
  'Win two tricks in a row',
  'Win three tricks in a row',
  'Win a trick with as many ♣ cards as ♦ cards (you must win at least one of each)',
  'Win a trick with as many ♥ cards as ♠ cards (you must win at least one of each)',
  'Win a mixed-suit trick with no Court Cards',
};

const _earlyTasks = {
  "Don't win any of the first four tricks",
  "Don't win any of the first three tricks",
  "Don't win any of the first five tricks",
  'Win the first three tricks',
  'Win the first two tricks',
  'Win the first trick',
};

/// Every task named in the timing lists, for checking they're real tasks.
Set<String> get timedTaskNames => {..._anyTrickTasks, ..._earlyTasks};

TaskTiming timingOf(String description) => _anyTrickTasks.contains(description)
    ? TaskTiming.anyTrick
    : _earlyTasks.contains(description)
        ? TaskTiming.early
        : TaskTiming.end;

/// Tasks that need an announced number of tricks.
bool needsX(String description) => description.startsWith('Win exactly X');

/// Whether a task can be played with this deal: the cards it names were
/// all dealt, and its redeal condition (if any) doesn't apply.
bool playableWith(String description, List<List<PlayingCard>> hands,
    Set<PlayingCard> inPlay) {
  for (final m in RegExp(r'([A2-9])([♥♦♠♣])').allMatches(description)) {
    final card = PlayingCard.parse(m.group(0)!);
    if (card != null && !inPlay.contains(card)) return false;
  }
  bool someoneHolds(List<PlayingCard> cards) =>
      hands.any((h) => cards.every(h.contains));
  const j = PlayingCard.joker, q = PlayingCard.queen;
  const jack = PlayingCard.jack, k = PlayingCard.king;
  if (description.contains('redeal if one player holds all four')) {
    return !someoneHolds([j, jack, q, k]);
  }
  if (description.startsWith('Win the Joker and no other')) {
    return !someoneHolds([j, k]) && !someoneHolds([j, jack, q]);
  }
  if (description.startsWith('Win the Jack and no other')) {
    return !someoneHolds([jack, k]) && !someoneHolds([j, jack, q]);
  }
  if (description.contains('redeal if one player holds the Jack, Queen and King')) {
    return !someoneHolds([jack, q, k]);
  }
  return true;
}

/// Whether a Dynasty traitor's open scheme (by index into `schemes` in
/// courtiers.dart) came off, judged from the tricks played.
bool schemeSucceeded(int scheme, RoundView v, int seat) {
  final king = v.king;
  switch (scheme) {
    case 0: // Win the trick that the King card is played in.
      return v.tricks.any(
          (t) => t.cards.contains(PlayingCard.king) && t.winner == seat);
    case 1: // The King must win no tricks at all.
      return v.tricksWon(king) == 0;
    case 2: // Win the last trick of the round.
      return v.over && v.tricks.last.winner == seat;
    case 3: // Win more tricks than the King.
      return v.tricksWon(seat) > v.tricksWon(king);
    case 4: // Win at least two Court Cards.
      return v.countWon(seat, (c) => c.isCourt) >= 2;
    case 5: // Win the first trick and the last trick.
      return v.over &&
          v.tricks.first.winner == seat &&
          v.tricks.last.winner == seat;
    case 6: // The King must win exactly one trick.
      return v.tricksWon(king) == 1;
    case 7: // Win three tricks in a row.
      return v.longestRun(seat) >= 3;
  }
  return false;
}

// ------------------------------------------------------------- progress

/// How far along a task is, in a few characters for the corner of its
/// card ("2/4", "1 trick"), or null when there's nothing to count.
String? taskProgress(String d, RoundView v, int owner, int? x) {
  int won(bool Function(PlayingCard) test) => v.countWon(owner, test);
  String of(int a, int b) => '$a/$b';
  bool rank(PlayingCard c, int r) => !c.isCourt && c.rank == r;

  // Named cards: how many of them are won.
  final named = [
    for (final m in RegExp(r'([A2-9])([♥♦♠♣])').allMatches(d))
      PlayingCard.parse(m.group(0)!)!
  ];
  if (d.startsWith('Win the ') &&
      named.length > 1 &&
      !d.contains(' with ') &&
      !d.contains('last trick')) {
    final mine = v.won(owner).toSet();
    return of(named.where(mine.contains).length, named.length);
  }
  final allFour = RegExp(r'^Win all four (\d)s$').firstMatch(d);
  if (allFour != null) {
    final r = int.parse(allFour.group(1)!);
    return of(won((c) => rank(c, r)), 4);
  }
  final ranks = RegExp(r'^Win (at least|exactly) (two|three) (\d)s$').firstMatch(d);
  if (ranks != null) {
    final n = ranks.group(2) == 'two' ? 2 : 3;
    final r = int.parse(ranks.group(3)!);
    return of(won((c) => rank(c, r)), n);
  }
  const words = {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'seven': 7};
  final suits = RegExp(r'^Win (at least|exactly) (\w+) ([♥♦♠♣]) cards?$').firstMatch(d);
  if (suits != null) {
    final suit = Suit.values.firstWhere((s) => s.symbol == suits.group(3));
    return of(won((c) => c.suit == suit), words[suits.group(2)] ?? 0);
  }
  if (d == 'Win exactly one ♥ and one ♣ card') {
    return '♥${won((c) => c.suit == Suit.hearts)} ♣${won((c) => c.suit == Suit.clubs)}';
  }
  final courts = RegExp(r'^Win exactly (\w+) Court Cards?').firstMatch(d);
  if (courts != null) return of(won((c) => c.isCourt), words[courts.group(1)] ?? 0);
  final tricks = RegExp(r'^Win exactly (\w+) tricks?').firstMatch(d);
  if (tricks != null) {
    final n = tricks.group(1) == 'X' ? x : words[tricks.group(1)];
    final secret = d.contains('secret');
    final mine = v.tricksWon(owner);
    return n == null || secret ? '$mine' : of(mine, n);
  }
  final firstN = RegExp(r'^Win the first (two|three) tricks$').firstMatch(d);
  if (firstN != null) {
    final n = words[firstN.group(1)]!;
    return of(v.tricks.take(n).where((t) => t.winner == owner).length, n);
  }
  if (d.contains('as many ♥ cards as ♦')) {
    return '♥${won((c) => c.suit == Suit.hearts)} ♦${won((c) => c.suit == Suit.diamonds)}';
  }
  if (d.startsWith('Win more ♦ cards than ♠')) {
    return '♦${won((c) => c.suit == Suit.diamonds)} ♠${won((c) => c.suit == Suit.spades)}';
  }
  if (d.startsWith('Win more ♥ cards than ♣')) {
    return '♥${won((c) => c.suit == Suit.hearts)} ♣${won((c) => c.suit == Suit.clubs)}';
  }
  if (d.contains('than the King') || d.contains('as the King')) {
    return '${v.tricksWon(owner)} v ${v.tricksWon(v.king)}';
  }
  if (d.startsWith('Win more tricks than everyone') ||
      d.startsWith('Win fewer tricks than everyone')) {
    return '${v.tricksWon(owner)} tricks';
  }
  if (d.contains('in a row') && !d.startsWith("Don't")) {
    return 'run ${v.longestRun(owner)}';
  }
  if (d == 'Win at least one card of each suit (Court Cards don\'t count)') {
    final have = [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs]
        .where((s) => v.won(owner).any((c) => c.suit == s))
        .length;
    return of(have, 4);
  }
  // Tasks about what you mustn't do: how far you've got safely.
  final notFirst = RegExp(r"^Don't win any of the first (\w+) tricks$").firstMatch(d);
  if (notFirst != null) {
    final n = words[notFirst.group(1)]!;
    return 'safe ${of(v.tricks.length < n ? v.tricks.length : n, n)}';
  }
  if (d.startsWith("Don't") || d.startsWith('Win no ')) {
    return 'safe ${of(v.tricks.length, v.totalTricks)}';
  }
  if (d.contains('last trick')) {
    return '${v.totalTricks - v.tricks.length} to go';
  }
  return null;
}
