/// Bots that play as your teammates. They are cooperative and, like a
/// friendly table, they know where every card is: each decision tries
/// every option in many quick random playouts of the rest of the round
/// and keeps the one that most often completes every task.
library;

import 'dart:math';

import 'cards.dart';
import 'match.dart';
import 'rules.dart';

class Bot {
  Bot([Random? random]) : rand = random ?? Random();
  final Random rand;

  /// Playouts per decision, shared between the options.
  int budget = 900;

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
    for (int n = 0; n < budget; n++) {
      final sim = _Sim.from(s);
      sim.playOut(rand);
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
    final per = max(20, budget ~/ legal.length);
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    var best = legal.first;
    var bestScore = -1.0;
    for (final card in legal) {
      final score =
          _scoreOf(s, assigned, per, first: (seat, card)) + rand.nextDouble() * 0.01;
      if (score > bestScore) {
        bestScore = score;
        best = card;
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
    for (int n = 0; n < playouts; n++) {
      total += _playout(s, assigned, inPlay, first, freeX);
    }
    return total / playouts;
  }

  /// One random playout's value: 1 if every assigned task is done, a
  /// little for each one done otherwise.
  double _playout(MatchState s, Map<int, int> assigned,
      Set<PlayingCard> inPlay, (int, PlayingCard)? first, bool freeX) {
    final sim = _Sim.from(s);
    if (first != null) sim.play(first.$1, first.$2);
    sim.playOut(rand);
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
        done == assigned.length ? 1.0 : 0.2 * done / max(1, assigned.length);
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

  static const _slice = 24;

  Future<double> _scoreAsync(MatchState s, Map<int, int> assigned,
      int playouts, {(int, PlayingCard)? first, bool freeX = false}) async {
    double total = 0;
    final inPlay = s.inPlay;
    for (int n = 0; n < playouts; n++) {
      total += _playout(s, assigned, inPlay, first, freeX);
      if (n % _slice == _slice - 1) await Future<void>.delayed(Duration.zero);
    }
    return total / playouts;
  }

  Future<double> scoreAsync(
          MatchState s, Map<int, int> assigned, int playouts) =>
      _scoreAsync(s, assigned, playouts);

  Future<int> choosePickAsync(MatchState s, int seat) async {
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
      final score = await _scoreAsync(s, assigned, per, freeX: true) +
          rand.nextDouble() * 0.01;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }

  Future<PlayingCard> choosePlayAsync(MatchState s, int seat) async {
    final legal = s.legalFor(seat);
    if (legal.length == 1) return legal.first;
    final per = max(20, budget ~/ legal.length);
    final assigned = {
      for (int t = 0; t < s.tasks.length; t++)
        if (s.tasks[t].owner != null) t: s.tasks[t].owner!,
    };
    var best = legal.first;
    var bestScore = -1.0;
    for (final card in legal) {
      final score = await _scoreAsync(s, assigned, per, first: (seat, card)) +
          rand.nextDouble() * 0.01;
      if (score > bestScore) {
        bestScore = score;
        best = card;
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
    for (int n = 0; n < budget; n++) {
      final sim = _Sim.from(s);
      sim.playOut(rand);
      final v = sim.view(s, inPlay);
      all[v.tricksWon(seat)]++;
      final others = assigned.entries.where((e) =>
          e.key != task && !needsX(s.tasks[e.key].description));
      if (others.every((e) =>
          taskRules[s.tasks[e.key].description]!(v, e.value, s.tasks[e.key].x) ==
          Verdict.done)) {
        counts[v.tricksWon(seat)]++;
      }
      if (n % _slice == _slice - 1) await Future<void>.delayed(Duration.zero);
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

  void playOut(Random rand) {
    while (tricks.length < totalTricks) {
      final seat = turn;
      final legal = legalPlays(hands[seat], cards.isEmpty ? null : cards.first);
      if (legal.isEmpty) break;
      play(seat, legal[rand.nextInt(legal.length)]);
    }
  }

  RoundView view(MatchState s, Set<PlayingCard> inPlay) => RoundView(
      players: players,
      king: s.king,
      tricks: tricks,
      totalTricks: totalTricks,
      inPlay: inPlay);
}
