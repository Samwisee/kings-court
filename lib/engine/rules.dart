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

/// Win no cards passing [test]: done as soon as the last of them has been
/// played without coming to [owner].
TaskRule winNone(bool Function(PlayingCard) test) => (v, owner, _) {
      if (v.won(owner).any(test)) return Verdict.failed;
      if (v.countLeft(test) == 0) return Verdict.done;
      return _end(v, true);
    };

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
  'Win more tricks than anyone else': atEnd((v, o) => [
        for (int s = 0; s < v.players; s++)
          if (s != o) s
      ].every((s) => v.tricksWon(o) > v.tricksWon(s))),
  'Win more tricks than the rest of the court put together': atEnd((v, o) =>
      v.tricksWon(o) > v.tricks.length - v.tricksWon(o)),
  'Win fewer tricks than anyone else': atEnd((v, o) => [
        for (int s = 0; s < v.players; s++)
          if (s != o) s
      ].every((s) => v.tricksWon(o) < v.tricksWon(s))),
  'Win more tricks than the King': atEnd((v, o) => v.tricksWon(o) > v.tricksWon(v.king)),
  'Win fewer tricks than the King': atEnd((v, o) => v.tricksWon(o) < v.tricksWon(v.king)),
  'Win the same number of tricks as the King': atEnd((v, o) => v.tricksWon(o) == v.tricksWon(v.king)),
  'Win exactly as many tricks as the player on your left': atEnd((v, o) => v.tricksWon(o) == v.tricksWon((o + 1) % v.players)),
  'Win a trick with a 3': winWith(3),
  'Win a trick with a 5': winWith(5),
  'Win a trick with a 7': winWith(7),
  'Win a trick with the Joker': anyTrick((t) => t.winningCard == PlayingCard.joker),
  'Win a trick with the Jack': anyTrick((t) => t.winningCard == PlayingCard.jack),
  'Win the Queen with the King': (v, o, _) {
    for (final t in v.tricks) {
      if (!t.cards.contains(PlayingCard.queen)) continue;
      return t.winner == o && t.winningCard == PlayingCard.king
          ? Verdict.done
          : Verdict.failed;
    }
    return _end(v, false);
  },
  'Win the 7♥ with a Court Card': winWithCourt(_c('7♥')),
  'Win a 9 with a Court Card': anyTrick(
      (t) => t.winningCard.isCourt && t.cards.any((c) => _rank(9)(c))),
  'Win a trick led with a Court Card': anyTrick((t) => t.cards.first.isCourt),
  'Win a trick containing an Ace and a 9': anyTrick((t) =>
      t.cards.any((c) => _rank(1)(c)) && t.cards.any((c) => _rank(9)(c))),
  'Win a trick with exactly two Court Cards in it': anyTrick((t) => t.cards.where(_court).length == 2),
  'Win a trick with three different suits in it': anyTrick((t) => {for (final c in t.cards) c.suit}.length >= 3),
  'Win a trick where no one followed suit': anyTrick((t) {
    final led = t.cards.first;
    return !led.isCourt && t.cards.skip(1).every((c) => c.suit != led.suit);
  }),
  'Win a trick with a card just one above the card led': anyTrick((t) {
    final led = t.cards.first, w = t.winningCard;
    return !led.isCourt && !w.isCourt && w.suit == led.suit && w.rank == led.rank + 1;
  }),
  'Win two tricks with cards of the same rank': (v, o, _) {
    final ranks = <int>[];
    for (final t in v.tricks) {
      if (t.winner != o || t.winningCard.isCourt) continue;
      if (ranks.contains(t.winningCard.rank)) return Verdict.done;
      ranks.add(t.winningCard.rank);
    }
    return _end(v, false);
  },
  'Win a trick you led': anyTrick((t) => t.leader == t.winner),
  'Win a trick as the last to play': anyTrick((t) => t.seats.last == t.winner),
  'Win a trick the King leads': (v, o, _) => v.tricks.any((t) => t.leader == v.king && t.winner == o)
      ? Verdict.done
      : _end(v, false),
  'Win the trick right after the King wins one': (v, o, _) {
    for (int i = 1; i < v.tricks.length; i++) {
      if (v.tricks[i - 1].winner == v.king && v.tricks[i].winner == o) return Verdict.done;
    }
    return _end(v, false);
  },
  'Win the trick after the Queen is played': (v, o, _) {
    for (int i = 0; i < v.tricks.length; i++) {
      if (!v.tricks[i].cards.contains(PlayingCard.queen)) continue;
      if (i + 1 >= v.totalTricks) return Verdict.failed;
      if (i + 1 < v.tricks.length) {
        return v.tricks[i + 1].winner == o ? Verdict.done : Verdict.failed;
      }
      return Verdict.pending;
    }
    return _end(v, false);
  },
  'Win the first trick': firstN(1),
  'Win the first two tricks': firstN(2),
  'Win the first trick with a Court Card': (v, o, _) {
    if (v.tricks.isEmpty) return Verdict.pending;
    final t = v.tricks.first;
    return t.winner == o && t.winningCard.isCourt ? Verdict.done : Verdict.failed;
  },
  'Win the last trick': atEnd((v, o) => v.tricks.last.winner == o),
  'Win the last trick with a Court Card': atEnd((v, o) => v.tricks.last.winner == o && v.tricks.last.winningCard.isCourt),
  'Win the second-to-last trick': (v, o, _) {
    final i = v.totalTricks - 2;
    if (v.tricks.length <= i) return Verdict.pending;
    return v.tricks[i].winner == o ? Verdict.done : Verdict.failed;
  },
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
  'Win exactly one trick': exactTricks(1),
  'Win exactly two tricks': exactTricks(2),
  'Win exactly three tricks': exactTricks(3),
  'Win exactly four tricks': exactTricks(4),
  'Win two tricks in a row': (v, o, _) =>
      v.longestRun(o) >= 2 ? Verdict.done : _end(v, false),
  'Win three tricks in a row': (v, o, _) =>
      v.longestRun(o) >= 3 ? Verdict.done : _end(v, false),
  'Win exactly X tricks, named before the first trick': (v, o, x) =>
      exactTricks(x ?? 0)(v, o, x),
  'Win the 3♥': winAll(_cs(['3♥'])),
  'Win the A♦': winAll(_cs(['A♦'])),
  'Win the 6♣': winAll(_cs(['6♣'])),
  'Win the 2♦': winAll(_cs(['2♦'])),
  'Win the 8♣': winAll(_cs(['8♣'])),
  'Win the 9♠': winAll(_cs(['9♠'])),
  'Win the Queen': winAll(const [PlayingCard.queen]),
  'Win the Joker': winAll(const [PlayingCard.joker]),
  'Win the Jack': winAll(const [PlayingCard.jack]),
  'Win the Jack and the Queen': winAll(const [PlayingCard.jack, PlayingCard.queen]),
  'Win the Joker, the Jack and the Queen': winAll(const [PlayingCard.joker, PlayingCard.jack, PlayingCard.queen]),
  'Win the 2♥ and the 3♦': winAll(_cs(['2♥', '3♦'])),
  'Win the A♥ and the 9♥': winAll(_cs(['A♥', '9♥'])),
  'Win the 5♠ and the 5♣': winAll(_cs(['5♠', '5♣'])),
  'Win the 7♥ and the 7♣': winAll(_cs(['7♥', '7♣'])),
  'Win the 3♦, 6♦ and 9♦': winAll(_cs(['3♦', '6♦', '9♦'])),
  'Win all four Aces': winAll(_cs(['A♥', 'A♦', 'A♠', 'A♣'])),
  'Win at least two Aces': atLeast(2, _rank(1)),
  'Win at least three 7s': atLeast(3, _rank(7)),
  'Win at least three 6s': atLeast(3, _rank(6)),
  'Win exactly two 4s': exactly(2, _rank(4)),
  'Win at least four ♠ cards': atLeast(4, _suit(Suit.spades)),
  'Win at least five ♦ cards': atLeast(5, _suit(Suit.diamonds)),
  'Win at least five ♣ cards': atLeast(5, _suit(Suit.clubs)),
  'Win exactly three ♥ cards': exactly(3, _suit(Suit.hearts)),
  'Win exactly two ♦ cards': exactly(2, _suit(Suit.diamonds)),
  'Win two tricks led with a ♥': (v, o, _) {
    final mine = v.tricks.where((t) => t.winner == o && t.cards.first.suit == Suit.hearts).length;
    if (mine >= 2) return Verdict.done;
    return _end(v, false);
  },
  'Win no ♠ cards': winNone(_suit(Suit.spades)),
  'Win no Court Cards': winNone(_court),
  'Win exactly one Court Card': exactly(1, _court),
  'Win exactly two Court Cards': exactly(2, _court),
  "Don't win any ♥ cards": winNone(_suit(Suit.hearts)),
  "Don't win any ♣ cards": winNone(_suit(Suit.clubs)),
  "Don't win any ♦ or ♠ cards": winNone((c) => c.suit == Suit.diamonds || c.suit == Suit.spades),
  "Don't win any Aces": winNone(_rank(1)),
  "Don't win any 9s": winNone(_rank(9)),
  "Don't win any 5s": winNone(_rank(5)),
  "Don't win any of the first three tricks": notFirst(3),
  "Don't win any tricks": never((v, o) => v.tricksWon(o) > 0),
  "Don't lead a trick with a Court Card": never((v, o) => v.tricks.any((t) => t.leader == o && t.led.isCourt)),
  'Win no tricks until the King has won one': (v, o, _) {
    for (final t in v.tricks) {
      if (t.winner == v.king) return Verdict.done;
      if (t.winner == o) return Verdict.failed;
    }
    return _end(v, true);
  },
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
  'Win a trick with a 3',
  'Win a trick with a 5',
  'Win a trick with a 7',
  'Win a trick with the Joker',
  'Win a trick with the Jack',
  'Win the Queen with the King',
  'Win the 7♥ with a Court Card',
  'Win a 9 with a Court Card',
  'Win a trick led with a Court Card',
  'Win a trick containing an Ace and a 9',
  'Win a trick with exactly two Court Cards in it',
  'Win a trick with three different suits in it',
  'Win a trick where no one followed suit',
  'Win a trick with a card just one above the card led',
  'Win two tricks with cards of the same rank',
  'Win a trick you led',
  'Win a trick as the last to play',
  'Win a trick the King leads',
  'Win the trick right after the King wins one',
  'Win the trick after the Queen is played',
  'Win two tricks in a row',
  'Win three tricks in a row',
  'Win the 3♥',
  'Win the A♦',
  'Win the 6♣',
  'Win the 2♦',
  'Win the 8♣',
  'Win the 9♠',
  'Win the Queen',
  'Win the Joker',
  'Win the Jack',
  'Win the Jack and the Queen',
  'Win the Joker, the Jack and the Queen',
  'Win the 2♥ and the 3♦',
  'Win the A♥ and the 9♥',
  'Win the 5♠ and the 5♣',
  'Win the 7♥ and the 7♣',
  'Win the 3♦, 6♦ and 9♦',
  'Win all four Aces',
  'Win at least two Aces',
  'Win at least three 7s',
  'Win at least three 6s',
  'Win at least four ♠ cards',
  'Win at least five ♦ cards',
  'Win at least five ♣ cards',
  'Win two tricks led with a ♥',
};

const _earlyTasks = {
  'Win the first trick',
  'Win the first two tricks',
  'Win the first trick with a Court Card',
  "Don't win any of the first three tricks",
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
  // Court Cards only ever go to whoever plays the highest one, so a player
  // holding too many of them leaves these tasks to no one else.
  if (description == 'Win exactly one Court Card') {
    return !someoneHolds([j, jack, q, k]);
  }
  if (description == 'Win exactly two Court Cards') {
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

/// How far along a task is, as a plain count for the corner of its card
/// ("2/4"), or null when there's nothing simple to count. Anything more is
/// in the task's close-up.
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
  if (d == 'Win all four Aces') return of(won((c) => rank(c, 1)), 4);
  final allFour = RegExp(r'^Win all four (\d)s$').firstMatch(d);
  if (allFour != null) {
    final r = int.parse(allFour.group(1)!);
    return of(won((c) => rank(c, r)), 4);
  }
  if (d == 'Win at least two Aces') return of(won((c) => rank(c, 1)), 2);
  final ranks = RegExp(r'^Win (at least|exactly) (two|three) (\d)s$').firstMatch(d);
  if (ranks != null) {
    final n = ranks.group(2) == 'two' ? 2 : 3;
    final r = int.parse(ranks.group(3)!);
    return of(won((c) => rank(c, r)), n);
  }
  const words = {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7};
  final suits = RegExp(r'^Win (at least|exactly) (\w+) ([♥♦♠♣]) cards?$').firstMatch(d);
  if (suits != null) {
    final suit = Suit.values.firstWhere((s) => s.symbol == suits.group(3));
    return of(won((c) => c.suit == suit), words[suits.group(2)] ?? 0);
  }
  final courts = RegExp(r'^Win exactly (\w+) Court Cards?').firstMatch(d);
  if (courts != null) return of(won((c) => c.isCourt), words[courts.group(1)] ?? 0);
  final tricks = RegExp(r'^Win exactly (\w+) tricks?').firstMatch(d);
  if (tricks != null) {
    final n = tricks.group(1) == 'X' ? x : words[tricks.group(1)];
    final secret = d.contains('secret');
    final mine = v.tricksWon(owner);
    return n == null || secret ? null : of(mine, n);
  }
  final firstN = RegExp(r'^Win the first (two|three) tricks$').firstMatch(d);
  if (firstN != null) {
    final n = words[firstN.group(1)]!;
    return of(v.tricks.take(n).where((t) => t.winner == owner).length, n);
  }
  if (d.startsWith('Win a card of every suit')) {
    final have = [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs]
        .where((s) => v.won(owner).any((c) => c.suit == s))
        .length;
    return of(have, 4);
  }
  // Tasks about what you mustn't do in the first tricks: how far through
  // them the round is.
  final notFirst = RegExp(r"^Don't win any of the first (\w+) tricks$").firstMatch(d);
  if (notFirst != null) {
    final n = words[notFirst.group(1)]!;
    return of(v.tricks.length < n ? v.tricks.length : n, n);
  }
  return null;
}
