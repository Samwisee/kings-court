/// Bots that play as your teammates. They are cooperative, and they play
/// fair: a bot sees only its own hand and what's public, and imagines the
/// hands it can't see (sampling.dart). Each decision tries every option in
/// many quick playouts of the rest of the round, spread over several
/// imagined deals, and keeps the one that most often completes every
/// task. ([omniscient] lets a bot see every hand instead, for the balance
/// tool and a hard setting.) How the thinking is shared between the
/// options, and when it stops, is race.dart's.
library;

import 'dart:math';

import 'cards.dart';
import 'playout.dart';
import 'race.dart';
import 'round.dart';
import 'rules.dart';
import 'sampling.dart';
import 'showing.dart';

export 'race.dart' show Thought;

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
    final options = _pickable(s, seat);
    lastThought = Thought.forced;
    if (options.length == 1) return options.first;
    final worlds = _worldsFor(s, seat);
    return _run(_race(options),
        (i, from, n) => _scoreOf(worlds, _with(s, i, seat), n, from: from, freeX: true));
  }

  /// The tasks [seat] may take.
  static List<int> _pickable(Round s, int seat) => [
        for (int i = 0; i < s.tasks.length; i++)
          if (s.canTake(i, seat)) i
      ];

  /// The tasks owned so far, and task [i] given to [seat].
  static Map<int, int> _with(Round s, int i, int seat) => {
        for (int t = 0; t < s.tasks.length; t++)
          if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
        i: seat,
      };

  /// The number of tricks [seat] should announce for task [task].
  int chooseX(Round s, int seat, int task) {
    lastThought = Thought.usual;
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
      final sim = Playout.from(w);
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
    lastThought = Thought.forced;
    if (legal.length == 1) return legal.first;
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    final worlds = _worldsFor(s, seat);
    return _run(_race(legal),
        (card, from, n) => _scoreOf(worlds, assigned, n, from: from, first: (seat, card)));
  }

  /// Whether the playouts are spent in two rounds: a look at every option,
  /// then the rest on the few that looked best (so the close calls get
  /// the most thought). Off, every option gets an equal share.
  bool focus = true;

  /// Whether a decision's thinking ends when it's decided (race.dart):
  /// early once one option is clearly best, later on a close call the
  /// round turns on. Off, every decision spends the budget.
  bool adaptive = true;

  /// How the last decision went (race.dart): the table paces the courtier
  /// by it (game/pacing.dart).
  Thought lastThought = Thought.forced;

  Race<T> _race<T>(List<T> options) => Race(options, budget, focus: focus, adaptive: adaptive);

  /// Runs [race] to its end, each option scored by [score] (the average
  /// of n playouts numbered from `from`), and gives its winner.
  T _run<T>(Race<T> race, double Function(T option, int from, int n) score) {
    for (var batch = race.next(); batch.isNotEmpty; batch = race.next()) {
      for (final (o, from, n) in batch) {
        race.add(o, score(o, from, n), n);
      }
    }
    lastThought = race.thought;
    return race.best(rand);
  }

  /// [_run], a slice at a time.
  Future<T> _runAsync<T>(Race<T> race, Future<double> Function(T option, int from, int n) score) async {
    for (var batch = race.next(); batch.isNotEmpty; batch = race.next()) {
      for (final (o, from, n) in batch) {
        race.add(o, await score(o, from, n), n);
      }
    }
    lastThought = race.thought;
    return race.best(rand);
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
  PlayoutGuide? _guideFor(Round s, Map<int, int> assigned) =>
      guided ? PlayoutGuide.of(s, assigned, guidance) : null;

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
      PlayoutGuide? guide, Random rand) {
    final sim = Playout.from(s);
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
    final options = _pickable(s, seat);
    lastPickScore = 1;
    lastThought = Thought.forced;
    if (options.length == 1) return options.first;
    _begin();
    final worlds = _worldsFor(s, seat);
    final race = _race(options);
    final best = await _runAsync(race,
        (i, from, n) => _scoreAsync(worlds, _with(s, i, seat), n, from: from, freeX: true));
    lastPickScore = race.meanOf(best);
    return best;
  }

  Future<PlayingCard> choosePlayAsync(Round s, int seat) async {
    final legal = s.legalFor(seat);
    lastThought = Thought.forced;
    if (legal.length == 1) return legal.first;
    _begin();
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    final worlds = _worldsFor(s, seat);
    return _runAsync(_race(legal),
        (card, from, n) => _scoreAsync(worlds, assigned, n, from: from, first: (seat, card)));
  }

  Future<int> chooseXAsync(Round s, int seat, int task) async {
    lastThought = Thought.usual;
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
      final sim = Playout.from(w);
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
