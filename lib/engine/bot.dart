/// Bots that play as your teammates. They are cooperative and, like a
/// friendly table, they know where every card is: each decision tries
/// every option in many quick random playouts of the rest of the round
/// and keeps the one that most often completes every task.
library;

import 'dart:math';

import 'cards.dart';
import 'conflicts.dart';
import 'deal_mix.dart';
import 'match.dart';
import 'rules.dart';

class Bot {
  Bot([Random? random]) : rand = random ?? Random();
  final Random rand;

  /// Playouts per decision, shared between the options.
  int budget = 900;

  /// Whether playouts are guided: in each one, every player mostly plays
  /// for their own tasks (winning a trick that holds a card they need,
  /// ducking one that holds a card they must avoid), with some play left
  /// random. Off, every playout is uniformly random, as the first bots
  /// were. Guided playouts look further ahead for the same cost.
  bool guided = true;

  /// How often a guided player follows their task rather than playing at
  /// random (the rest keeps the playouts varied).
  double guidance = 0.85;

  /// The task [seat] should pick.
  int choosePick(MatchState s, int seat) {
    final options = [
      for (int i = 0; i < s.tasks.length; i++)
        if (s.canTake(i, seat)) i
    ];
    if (options.length == 1) return options.first;
    final per = max(20, budget ~/ options.length);
    var best = options.first;
    var bestScore = -1.0;
    for (final i in options) {
      final assigned = {
        for (int t = 0; t < s.tasks.length; t++)
          if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
        i: seat,
      };
      final score = _scoreOf(s, assigned, per, freeX: true) +
          rand.nextDouble() * 0.01;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }

  /// The number of tricks [seat] should announce for task [task].
  int chooseX(MatchState s, int seat, int task) {
    final counts = List.filled(s.totalTricks + 1, 0);
    final all = List.filled(s.totalTricks + 1, 0);
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    final inPlay = s.inPlay;
    final guide = _guideFor(s, assigned);
    for (int n = 0; n < budget; n++) {
      final sim = _Sim.from(s);
      sim.playOut(rand, guide: guide);
      // Count this playout if everything else would succeed.
      final v = sim.view(s, inPlay);
      all[v.tricksWon(seat)]++;
      final others = assigned.entries.where((e) =>
          e.key != task && !needsX(s.tasks[e.key].description));
      if (others.every((e) =>
          taskRules[s.tasks[e.key].description]!(v, e.value, s.tasks[e.key].x) ==
          Verdict.done)) {
        counts[v.tricksWon(seat)]++;
      }
    }
    return _bestX(counts, all, s, seat);
  }

  /// The card [seat] should play.
  PlayingCard choosePlay(MatchState s, int seat) {
    final legal = s.legalFor(seat);
    if (legal.length == 1) return legal.first;
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    return _focus(legal, budget,
        (card, n) => _scoreOf(s, assigned, n, first: (seat, card)));
  }

  /// Whether the playouts are spent in two rounds: a look at every option,
  /// then the rest on the few that looked best (so the close calls get
  /// the most thought). Off, every option gets an equal share.
  bool focus = true;

  /// Picks the best of [options] with [total] playouts, by [score] (the
  /// average of n playouts), spending them where they tell the most.
  T _focus<T>(List<T> options, int total, double Function(T option, int n) score) {
    if (!focus) {
      final per = max(20, total ~/ options.length);
      T best = options.first;
      var bestScore = -1.0;
      for (final o in options) {
        final v = score(o, per) + rand.nextDouble() * 0.01;
        if (v > bestScore) {
          bestScore = v;
          best = o;
        }
      }
      return best;
    }
    // First look: a share of the budget over every option.
    final first = max(16, (total * 0.4) ~/ options.length);
    final scores = <T, (double, int)>{
      for (final o in options) o: (score(o, first), first)
    };
    // The best few get the rest, and their scores are pooled.
    final keep = max(2, (options.length / 3).ceil());
    final top = options.toList()
      ..sort((a, b) => scores[b]!.$1.compareTo(scores[a]!.$1));
    final finalists = top.take(keep).toList();
    final more = max(16, (total - first * options.length) ~/ finalists.length);
    T best = finalists.first;
    var bestScore = -1.0;
    for (final o in finalists) {
      final (s1, n1) = scores[o]!;
      final s2 = score(o, more);
      final pooled = (s1 * n1 + s2 * more) / (n1 + more) + rand.nextDouble() * 0.01;
      if (pooled > bestScore) {
        bestScore = pooled;
        best = o;
      }
    }
    return best;
  }

  /// How often random playouts from [s] complete the [assigned] tasks:
  /// 1 for each playout where all are done, plus a little for each task
  /// done in the ones that fall short. With [freeX], "exactly X" tasks
  /// count as done whatever X turns out to be (it's announced later).
  double score(MatchState s, Map<int, int> assigned, int playouts) =>
      _scoreOf(s, assigned, playouts);

  double _scoreOf(MatchState s, Map<int, int> assigned, int playouts,
      {(int, PlayingCard)? first, bool freeX = false}) {
    double total = 0;
    final inPlay = s.inPlay;
    final guide = _guideFor(s, assigned);
    for (int n = 0; n < playouts; n++) {
      total += _playout(s, assigned, inPlay, first, freeX, guide);
    }
    return total / playouts;
  }

  /// What each seat plays for in guided playouts, from the tasks they
  /// hold (null when playouts are random).
  _Guide? _guideFor(MatchState s, Map<int, int> assigned) =>
      guided ? _Guide.of(s, assigned, guidance) : null;

  /// One random playout's value: 1 if every assigned task is done, a
  /// little for each one done otherwise.
  double _playout(MatchState s, Map<int, int> assigned,
      Set<PlayingCard> inPlay, (int, PlayingCard)? first, bool freeX,
      [_Guide? guide]) {
    final sim = _Sim.from(s);
    var lostNow = false;
    if (first != null) {
      sim.play(first.$1, first.$2);
      // Finish this trick first: a card that loses a task in the trick it's
      // played in (the King led by someone who may win only the last trick)
      // is a blunder, whatever might happen later.
      sim.playOut(rand, until: s.tricks.length + 1, guide: guide);
      final now = sim.view(s, inPlay);
      for (final e in assigned.entries) {
        final t = s.tasks[e.key];
        if (needsX(t.description) && (freeX || t.x == null)) continue;
        if (t.verdict == Verdict.pending &&
            taskRules[t.description]!(now, e.value, t.x) == Verdict.failed) {
          lostNow = true;
          break;
        }
      }
    }
    sim.playOut(rand, guide: guide);
    final v = sim.view(s, inPlay);
    int done = 0;
    for (final e in assigned.entries) {
      final t = s.tasks[e.key];
      if (needsX(t.description) && (freeX || t.x == null)) {
        done++;
        continue;
      }
      if (taskRules[t.description]!(v, e.value, t.x) == Verdict.done) done++;
    }
    // Seals: tasks must be done in their order (Ω last), or the round is
    // lost even with every task done.
    if (done == assigned.length && !_sealsKept(s, assigned, v)) done--;
    final value =
        (done == assigned.length ? 1.0 : 0.2 * done / max(1, assigned.length)) -
            (lostNow ? 0.6 : 0);
    if (s.schemes.isEmpty) return value;
    // A traitor wants only their scheme; everyone else wants it stopped.
    final me = first?.$1;
    if (me != null && s.schemes.containsKey(me)) {
      return schemeSucceeded(s.schemes[me]!, v, me) ? 1 : 0;
    }
    final schemed = s.schemes.entries.any((e) => schemeSucceeded(e.value, v, e.key));
    return schemed ? value * 0.3 : value;
  }

  /// Whether the sealed tasks among [assigned] were done in seal order
  /// (numbered seals in turn, Ω after every other task) in the round [v].
  static bool _sealsKept(MatchState s, Map<int, int> assigned, RoundView v) {
    const omega = 99;
    final seals = {
      for (final e in assigned.entries)
        if (s.tasks[e.key].task.seal != null) e.key: s.tasks[e.key].task.seal!
    };
    if (seals.isEmpty) return true;
    // The trick each task was done on (they're all done by now).
    int doneAt(int t) {
      final task = s.tasks[t];
      for (int k = 1; k <= v.tricks.length; k++) {
        final upTo = RoundView(
            players: v.players,
            king: v.king,
            tricks: v.tricks.sublist(0, k),
            totalTricks: v.totalTricks,
            inPlay: v.inPlay);
        if (taskRules[task.description]!(upTo, assigned[t]!, task.x) ==
            Verdict.done) {
          return k;
        }
      }
      return v.tricks.length;
    }

    final hasOmega = seals.values.contains(omega);
    final at = {
      for (final t in hasOmega ? assigned.keys : seals.keys) t: doneAt(t)
    };
    final numbered = seals.entries.where((e) => e.value != omega).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (int i = 1; i < numbered.length; i++) {
      if (at[numbered[i].key]! < at[numbered[i - 1].key]!) return false;
    }
    if (hasOmega) {
      final o = seals.entries.firstWhere((e) => e.value == omega).key;
      if (at.entries.any((e) => e.key != o && e.value > at[o]!)) return false;
    }
    return true;
  }

  /// The number of tricks to announce: the count that most often lets
  /// every other task succeed, or failing that the most likely count. Never
  /// fewer than the tricks [seat] is sure to win (the King card always
  /// wins its trick).
  static int _bestX(List<int> counts, List<int> all, MatchState s, int seat) {
    final least = s.hands[seat].contains(PlayingCard.king) ? 1 : 0;
    final useful = counts.any((c) => c > 0) ? counts : all;
    var best = least;
    for (int x = least; x < useful.length; x++) {
      if (useful[x] > useful[best]) best = x;
    }
    return best;
  }

  // ------------------------------------------------- without blocking the UI
  //
  // The same decisions, done a slice at a time so the screen keeps
  // animating while a bot thinks (on the web everything shares one thread).
  // A slice is measured in time, not playouts: think for [sliceTime], then
  // let a frame draw. (Counting playouts meant dozens of hand-backs per
  // decision, each a few idle milliseconds on the web.)

  /// How long a bot thinks before giving the screen a turn: half a frame.
  static Duration sliceTime = const Duration(milliseconds: 8);

  /// The current slice's clock (one decision thinks at a time).
  final _clock = Stopwatch();

  void _begin() => _clock
    ..reset()
    ..start();

  /// A frame's turn, when the slice has run its time; null when thinking
  /// can go straight on (so the hot loop needn't wait on a future).
  Future<void>? _breathe() {
    if (_clock.elapsedMicroseconds < sliceTime.inMicroseconds) return null;
    return Future<void>.delayed(Duration.zero).then((_) => _clock.reset());
  }

  Future<double> _scoreAsync(MatchState s, Map<int, int> assigned,
      int playouts, {(int, PlayingCard)? first, bool freeX = false}) async {
    double total = 0;
    final inPlay = s.inPlay;
    final guide = _guideFor(s, assigned);
    for (int n = 0; n < playouts; n++) {
      total += _playout(s, assigned, inPlay, first, freeX, guide);
      final pause = _breathe();
      if (pause != null) await pause;
    }
    return total / playouts;
  }

  Future<double> scoreAsync(
      MatchState s, Map<int, int> assigned, int playouts) {
    _begin();
    return _scoreAsync(s, assigned, playouts);
  }

  /// How well the last pick chosen is likely to go (0 to 1).
  double lastPickScore = 1;

  Future<int> choosePickAsync(MatchState s, int seat) async {
    final options = [
      for (int i = 0; i < s.tasks.length; i++)
        if (s.canTake(i, seat)) i
    ];
    lastPickScore = 1;
    if (options.length == 1) return options.first;
    _begin();
    final per = max(20, budget ~/ options.length);
    var best = options.first;
    var bestScore = -1.0;
    for (final i in options) {
      final assigned = {
        for (int t = 0; t < s.tasks.length; t++)
          if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
        i: seat,
      };
      final score = await _scoreAsync(s, assigned, per, freeX: true) +
          rand.nextDouble() * 0.01;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    lastPickScore = bestScore;
    return best;
  }

  Future<PlayingCard> choosePlayAsync(MatchState s, int seat) async {
    final legal = s.legalFor(seat);
    if (legal.length == 1) return legal.first;
    _begin();
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    return _focusAsync(legal, budget,
        (card, n) => _scoreAsync(s, assigned, n, first: (seat, card)));
  }

  /// [_focus], a slice at a time.
  Future<T> _focusAsync<T>(List<T> options, int total,
      Future<double> Function(T option, int n) score) async {
    if (!focus) {
      final per = max(20, total ~/ options.length);
      T best = options.first;
      var bestScore = -1.0;
      for (final o in options) {
        final v = await score(o, per) + rand.nextDouble() * 0.01;
        if (v > bestScore) {
          bestScore = v;
          best = o;
        }
      }
      return best;
    }
    final first = max(16, (total * 0.4) ~/ options.length);
    final scores = <T, (double, int)>{};
    for (final o in options) {
      scores[o] = (await score(o, first), first);
    }
    final keep = max(2, (options.length / 3).ceil());
    final top = options.toList()
      ..sort((a, b) => scores[b]!.$1.compareTo(scores[a]!.$1));
    final finalists = top.take(keep).toList();
    final more = max(16, (total - first * options.length) ~/ finalists.length);
    T best = finalists.first;
    var bestScore = -1.0;
    for (final o in finalists) {
      final (s1, n1) = scores[o]!;
      final s2 = await score(o, more);
      final pooled = (s1 * n1 + s2 * more) / (n1 + more) + rand.nextDouble() * 0.01;
      if (pooled > bestScore) {
        bestScore = pooled;
        best = o;
      }
    }
    return best;
  }

  Future<int> chooseXAsync(MatchState s, int seat, int task) async {
    final counts = List.filled(s.totalTricks + 1, 0);
    final all = List.filled(s.totalTricks + 1, 0);
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    final inPlay = s.inPlay;
    // The other tasks whose success decides whether a count is usable;
    // worked out once, not once a playout.
    final others = [
      for (final e in assigned.entries)
        if (e.key != task && !needsX(s.tasks[e.key].description)) e
    ];
    final guide = _guideFor(s, assigned);
    _begin();
    for (int n = 0; n < budget; n++) {
      final sim = _Sim.from(s);
      sim.playOut(rand, guide: guide);
      final v = sim.view(s, inPlay);
      all[v.tricksWon(seat)]++;
      if (others.every((e) =>
          taskRules[s.tasks[e.key].description]!(v, e.value, s.tasks[e.key].x) ==
          Verdict.done)) {
        counts[v.tricksWon(seat)]++;
      }
      final pause = _breathe();
      if (pause != null) await pause;
    }
    return _bestX(counts, all, s, seat);
  }
}

/// A throwaway copy of a round, played out at random.
class _Sim {
  _Sim(this.players, this.hands, this.tricks, this.leader, this.seats,
      this.cards, this.totalTricks);

  factory _Sim.from(MatchState s) => _Sim(
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
  void playOut(Random rand, {int? until, _Guide? guide}) {
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

  RoundView view(MatchState s, Set<PlayingCard> inPlay) => RoundView(
      players: players,
      king: s.king,
      tricks: tricks,
      totalTricks: totalTricks,
      inPlay: inPlay);
}

/// What each seat plays for in a guided playout, from the tasks they hold:
/// the cards they need to win, the cards they must not win, and whether
/// they want tricks at all.
class _Guide {
  _Guide(this.need, this.avoid, this.temper, this.strength);

  /// Cards each seat must win.
  final List<Set<PlayingCard>> need;

  /// Cards each seat must not win (null when nothing is forbidden).
  final List<bool Function(PlayingCard)?> avoid;

  /// Whether each seat wants tricks (+1), wants to avoid them (-1), or
  /// doesn't mind (0).
  final List<int> temper;

  /// How often a player follows the guide rather than playing at random.
  final double strength;

  factory _Guide.of(MatchState s, Map<int, int> assigned, double strength) {
    final need = [for (int i = 0; i < s.players; i++) <PlayingCard>{}];
    final avoids = [for (int i = 0; i < s.players; i++) <bool Function(PlayingCard)>[]];
    final temper = List.filled(s.players, 0);
    for (final e in assigned.entries) {
      final t = s.tasks[e.key];
      if (t.verdict != Verdict.pending) continue;
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
    return _Guide(need, [
      for (final a in avoids)
        a.isEmpty ? null : (PlayingCard c) => a.any((f) => f(c))
    ], [for (final t in temper) t.sign], strength);
  }

  /// The card [seat] plays, following what they hold.
  PlayingCard choose(_Sim sim, int seat, List<PlayingCard> legal, Random rand) {
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
