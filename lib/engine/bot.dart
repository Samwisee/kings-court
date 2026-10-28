/// Bots that play as your teammates. They are cooperative, and they play
/// fair: a bot sees only its own hand and what's public, and imagines the
/// hands it can't see (sampling.dart). Each decision tries every option in
/// many quick playouts of the rest of the round, spread over several
/// imagined deals, and keeps the one that most often completes every
/// task. ([omniscient] lets a bot see every hand instead, for the balance
/// tool and a hard setting.)
library;

import 'dart:math';

import 'cards.dart';
import 'conflicts.dart';
import 'deal_mix.dart';
import 'round.dart';
import 'rules.dart';
import 'sampling.dart';
import 'showing.dart';

class Bot {
  Bot([Random? random]) : rand = random ?? Random();

  /// The bot's dice: a game sets them from its seed at each deal, so the
  /// courtiers' choices replay.
  Random rand;

  /// Playouts per decision, shared between the options.
  int budget = 900;

  /// Whether the bot sees every hand. Off (the game), it knows only its own
  /// hand and what's public, and thinks across [samples] imagined deals
  /// of the rest.
  bool omniscient = false;

  /// How many imagined deals a fair bot thinks across per decision. The
  /// playouts are shared out between them.
  int samples = 8;

  /// The deals to think in: the real one when all-seeing, else [samples]
  /// deals of the cards [viewer] can't see that fit everything known.
  List<Round> _worldsFor(Round s, int viewer) {
    _decisionSeed = rand.nextInt(1 << 30);
    return omniscient ? [s] : sampleWorlds(s, viewer, samples, rand);
  }

  /// Whether every option is tried against the same imagined futures: the
  /// n-th playout of each card uses the same random numbers, so what
  /// differs between two cards is the cards, not the luck of the playouts.
  /// Far steadier comparisons for the same cost.
  bool paired = true;

  /// The seed this decision's playouts run from (see [paired]).
  int _decisionSeed = 0;

  /// The random numbers for playout [n] of this decision.
  Random _randFor(int n) => paired ? Random(_decisionSeed + n * 7919) : rand;

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
  int choosePick(Round s, int seat) {
    final options = [
      for (int i = 0; i < s.tasks.length; i++)
        if (s.canTake(i, seat)) i
    ];
    if (options.length == 1) return options.first;
    final per = max(20, budget ~/ options.length);
    final worlds = _worldsFor(s, seat);
    var best = options.first;
    var bestScore = -1.0;
    for (final i in options) {
      final assigned = {
        for (int t = 0; t < s.tasks.length; t++)
          if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
        i: seat,
      };
      final score = _scoreOf(worlds, assigned, per, freeX: true) +
          rand.nextDouble() * 0.01;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }

  /// The number of tricks [seat] should announce for task [task].
  int chooseX(Round s, int seat, int task) {
    final counts = List.filled(s.totalTricks + 1, 0);
    final all = List.filled(s.totalTricks + 1, 0);
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    final worlds = _worldsFor(s, seat);
    final guide = _guideFor(s, assigned);
    for (var n = 0; n < budget; n++) {
      final w = worlds[n % worlds.length];
      final sim = _Sim.from(w);
      sim.playOut(_randFor(n), guide: guide);
      // Count this playout if everything else would succeed.
      final v = sim.view(w, w.inPlay);
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
  PlayingCard choosePlay(Round s, int seat) {
    final legal = s.legalFor(seat);
    if (legal.length == 1) return legal.first;
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    final worlds = _worldsFor(s, seat);
    return _focus(legal, budget,
        (card, from, n) => _scoreOf(worlds, assigned, n, from: from, first: (seat, card)));
  }

  /// Whether the playouts are spent in two rounds: a look at every option,
  /// then the rest on the few that looked best (so the close calls get
  /// the most thought). Off, every option gets an equal share.
  bool focus = true;

  /// Picks the best of [options] with [total] playouts, by [score] (the
  /// average of n playouts numbered from `from`), spending them where they
  /// tell the most.
  T _focus<T>(List<T> options, int total, double Function(T option, int from, int n) score) {
    if (!focus) {
      final per = max(20, total ~/ options.length);
      var best = options.first;
      var bestScore = -1.0;
      for (final o in options) {
        final v = score(o, 0, per) + rand.nextDouble() * 0.01;
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
      for (final o in options) o: (score(o, 0, first), first)
    };
    // The best few get the rest, and their scores are pooled.
    final keep = max(2, (options.length / 3).ceil());
    final top = options.toList()
      ..sort((a, b) => scores[b]!.$1.compareTo(scores[a]!.$1));
    final finalists = top.take(keep).toList();
    final more = max(16, (total - first * options.length) ~/ finalists.length);
    var best = finalists.first;
    var bestScore = -1.0;
    for (final o in finalists) {
      final (s1, n1) = scores[o]!;
      final s2 = score(o, first, more);
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
  double score(Round s, int viewer, Map<int, int> assigned, int playouts) =>
      _scoreOf(_worldsFor(s, viewer), assigned, playouts);

  /// The playouts are spread over the [worlds] in turn, numbered from
  /// [from] (see [paired]).
  double _scoreOf(List<Round> worlds, Map<int, int> assigned, int playouts,
      {int from = 0, (int, PlayingCard)? first, bool freeX = false}) {
    double total = 0;
    final guide = _guideFor(worlds.first, assigned);
    for (var n = from; n < from + playouts; n++) {
      final w = worlds[n % worlds.length];
      total += _playout(w, assigned, w.inPlay, first, freeX, guide, _randFor(n));
    }
    return total / playouts;
  }

  /// What each seat plays for in guided playouts, from the tasks they
  /// hold (null when playouts are random).
  _Guide? _guideFor(Round s, Map<int, int> assigned) =>
      guided ? _Guide.of(s, assigned, guidance) : null;

  /// The seats that will show a card for the show tasks they hold, with
  /// those tasks (empty when nobody needs to).
  Map<int, List<String>> _plansFor(Round s, Map<int, int> assigned) {
    Map<int, List<String>>? out;
    for (final e in assigned.entries) {
      final d = s.tasks[e.key].description;
      if (!showTasks.contains(d) || s.revealed.containsKey(e.value)) continue;
      ((out ??= {})[e.value] ??= []).add(d);
    }
    return out ?? const {};
  }

  /// One random playout's value: 1 if every assigned task is done, a
  /// little for each one done otherwise.
  double _playout(Round s, Map<int, int> assigned,
      Set<PlayingCard> inPlay, (int, PlayingCard)? first, bool freeX,
      _Guide? guide, Random rand) {
    final sim = _Sim.from(s);
    // Cards about to be shown: whoever holds a task that asks them to show
    // a card, and hasn't yet, is imagined showing it now (otherwise every
    // imagined round would fail those tasks for want of a card shown).
    var shown = s.revealed, shownAt = s.revealedAt;
    final plans = _plansFor(s, assigned);
    if (plans.isNotEmpty) {
      shown = {...s.revealed};
      shownAt = {...s.revealedAt};
      for (final e in plans.entries) {
        final c = intendedShow(s, e.key, e.value);
        if (c == null) continue;
        shown[e.key] = c;
        shownAt[e.key] = s.tricks.length;
      }
    }
    var lostNow = false;
    if (first != null) {
      sim.play(first.$1, first.$2);
      // Finish this trick first: a card that loses a task in the trick it's
      // played in (the King led by someone who may win only the last trick)
      // is a blunder, whatever might happen later.
      sim.playOut(rand, until: s.tricks.length + 1, guide: guide);
      final now = sim.view(s, inPlay, shown, shownAt);
      for (final e in assigned.entries) {
        final t = s.tasks[e.key];
        if (needsX(t.description) && (freeX || t.x == null)) continue;
        if (t.isPending &&
            taskRules[t.description]!(now, e.value, t.x) == Verdict.failed) {
          lostNow = true;
          break;
        }
      }
    }
    sim.playOut(rand, guide: guide);
    final v = sim.view(s, inPlay, shown, shownAt);
    var done = 0;
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
    return value;
  }

  /// Whether the sealed tasks among [assigned] were done in seal order
  /// (numbered seals in turn, Ω after every other task) in the round [v].
  static bool _sealsKept(Round s, Map<int, int> assigned, RoundView v) {
    const omega = 99;
    final seals = {
      for (final e in assigned.entries)
        if (s.tasks[e.key].seal != null) e.key: s.tasks[e.key].seal!
    };
    if (seals.isEmpty) return true;
    // The trick each task was done on (they're all done by now).
    int doneAt(int t) {
      final task = s.tasks[t];
      for (var k = 1; k <= v.tricks.length; k++) {
        final upTo = v.upTo(k);
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
    for (var i = 1; i < numbered.length; i++) {
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
  static int _bestX(List<int> counts, List<int> all, Round s, int seat) {
    final least = s.hands[seat].contains(PlayingCard.king) ? 1 : 0;
    final useful = counts.any((c) => c > 0) ? counts : all;
    var best = least;
    for (var x = least; x < useful.length; x++) {
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

  Future<double> _scoreAsync(List<Round> worlds, Map<int, int> assigned,
      int playouts, {int from = 0, (int, PlayingCard)? first, bool freeX = false}) async {
    double total = 0;
    final guide = _guideFor(worlds.first, assigned);
    for (var n = from; n < from + playouts; n++) {
      final w = worlds[n % worlds.length];
      total += _playout(w, assigned, w.inPlay, first, freeX, guide, _randFor(n));
      final pause = _breathe();
      if (pause != null) await pause;
    }
    return total / playouts;
  }

  Future<double> scoreAsync(
      Round s, int viewer, Map<int, int> assigned, int playouts) {
    _begin();
    return _scoreAsync(_worldsFor(s, viewer), assigned, playouts);
  }

  /// How well the last pick chosen is likely to go (0 to 1).
  double lastPickScore = 1;

  Future<int> choosePickAsync(Round s, int seat) async {
    final options = [
      for (int i = 0; i < s.tasks.length; i++)
        if (s.canTake(i, seat)) i
    ];
    lastPickScore = 1;
    if (options.length == 1) return options.first;
    _begin();
    final per = max(20, budget ~/ options.length);
    final worlds = _worldsFor(s, seat);
    var best = options.first;
    var bestScore = -1.0;
    for (final i in options) {
      final assigned = {
        for (int t = 0; t < s.tasks.length; t++)
          if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
        i: seat,
      };
      final score = await _scoreAsync(worlds, assigned, per, freeX: true) +
          rand.nextDouble() * 0.01;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    lastPickScore = bestScore;
    return best;
  }

  Future<PlayingCard> choosePlayAsync(Round s, int seat) async {
    final legal = s.legalFor(seat);
    if (legal.length == 1) return legal.first;
    _begin();
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    final worlds = _worldsFor(s, seat);
    return _focusAsync(legal, budget,
        (card, from, n) => _scoreAsync(worlds, assigned, n, from: from, first: (seat, card)));
  }

  /// [_focus], a slice at a time.
  Future<T> _focusAsync<T>(List<T> options, int total,
      Future<double> Function(T option, int from, int n) score) async {
    if (!focus) {
      final per = max(20, total ~/ options.length);
      var best = options.first;
      var bestScore = -1.0;
      for (final o in options) {
        final v = await score(o, 0, per) + rand.nextDouble() * 0.01;
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
      scores[o] = (await score(o, 0, first), first);
    }
    final keep = max(2, (options.length / 3).ceil());
    final top = options.toList()
      ..sort((a, b) => scores[b]!.$1.compareTo(scores[a]!.$1));
    final finalists = top.take(keep).toList();
    final more = max(16, (total - first * options.length) ~/ finalists.length);
    var best = finalists.first;
    var bestScore = -1.0;
    for (final o in finalists) {
      final (s1, n1) = scores[o]!;
      final s2 = await score(o, first, more);
      final pooled = (s1 * n1 + s2 * more) / (n1 + more) + rand.nextDouble() * 0.01;
      if (pooled > bestScore) {
        bestScore = pooled;
        best = o;
      }
    }
    return best;
  }

  Future<int> chooseXAsync(Round s, int seat, int task) async {
    final counts = List.filled(s.totalTricks + 1, 0);
    final all = List.filled(s.totalTricks + 1, 0);
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    // The other tasks whose success decides whether a count is usable;
    // worked out once, not once a playout.
    final others = [
      for (final e in assigned.entries)
        if (e.key != task && !needsX(s.tasks[e.key].description)) e
    ];
    final worlds = _worldsFor(s, seat);
    final guide = _guideFor(s, assigned);
    _begin();
    for (var n = 0; n < budget; n++) {
      final w = worlds[n % worlds.length];
      final sim = _Sim.from(w);
      sim.playOut(_randFor(n), guide: guide);
      final v = sim.view(w, w.inPlay);
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

  factory _Sim.from(Round s) => _Sim(
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

  factory _Guide.of(Round s, Map<int, int> assigned, double strength) {
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
