/// How a bot shares its thinking between the options of one decision: a
/// first look at every option, then the rest on the few that looked best,
/// as a race between them.
///
/// With [Race.adaptive] on, the race also ends when it's decided, as a
/// person's thinking does: early, once one option is clearly ahead of the
/// rest; and late, past the usual budget (up to [Race.stretch] times it),
/// while the best two are still too close to tell apart on a decision that
/// matters (one where the round can still be won or lost by it). How the
/// race went is its [Thought], which the table uses to pace the courtier
/// (game/pacing.dart).
///
/// Pure Dart, like the rest of the engine.
library;

import 'dart:math';

/// How a decision went: how many options there were, how much thinking it
/// took against the usual budget, and how hard it was.
class Thought {
  const Thought({this.options = 1, this.spent = 0, this.budget = 1, this.clear = false, this.close = false});

  /// A move with only one option: nothing to think about.
  static const forced = Thought();

  /// A decision made the usual way, with no race (an announcement).
  static const usual = Thought(options: 2, spent: 1);

  final int options;
  final int spent;
  final int budget;

  /// One option was clearly best, so the thinking stopped early.
  final bool clear;

  /// The best two were still too close to tell apart when the thinking
  /// stopped, on a decision that matters.
  final bool close;

  bool get isForced => options <= 1;

  /// The thinking spent, against the usual budget (1 is the usual).
  double get effort => budget <= 0 ? 0 : spent / budget;

  @override
  String toString() => 'Thought($options options, ${effort.toStringAsFixed(2)} of the budget'
      '${clear ? ', clear' : ''}${close ? ', close' : ''})';
}

/// One decision's race between [options], over [budget] playouts. Ask it
/// for the [next] playouts to run, report each batch's average with
/// [add], and when [next] has nothing more, take the [best].
class Race<T> {
  Race(this.options, this.budget, {this.focus = true, this.adaptive = true, this.stretch = 2.5});

  final List<T> options;
  final int budget;

  /// A first look at every option, then the rest on the best few. Off,
  /// every option gets an equal share.
  final bool focus;

  /// The race ends when it's decided (see the library's notes).
  final bool adaptive;

  /// The most thinking a close, consequential decision may take, as a
  /// multiple of [budget].
  final double stretch;

  final _sum = <T, double>{};
  final _n = <T, int>{};
  int spent = 0;
  int _stage = 0;
  List<T> _finalists = const [];
  int _more = 0;
  bool _clear = false;

  /// Playouts each option has had: also where its next ones are numbered
  /// from, so the n-th playout of every option sees the same future.
  int playedFor(T o) => _n[o] ?? 0;

  double meanOf(T o) => (_n[o] ?? 0) == 0 ? -1 : _sum[o]! / _n[o]!;

  void add(T o, double mean, int n) {
    _sum[o] = (_sum[o] ?? 0) + mean * n;
    _n[o] = (_n[o] ?? 0) + n;
    spent += n;
  }

  /// The options still in it, best first.
  List<T> _ranked(Iterable<T> among) =>
      among.toList()..sort((a, b) => meanOf(b).compareTo(meanOf(a)));

  /// How far the leader of [among] is ahead of the next, in standard
  /// errors of the difference (playout scores read as rates of success).
  (double gap, double z, double lead) _lead(Iterable<T> among) {
    final top = _ranked(among);
    if (top.length < 2) return (1, double.infinity, meanOf(top.first));
    final a = top[0], b = top[1];
    double variance(T o) {
      final p = meanOf(o).clamp(0.0, 1.0);
      return max(p * (1 - p), 0.01) / max(1, _n[o] ?? 0);
    }

    final gap = meanOf(a) - meanOf(b);
    return (gap, gap / sqrt(variance(a) + variance(b)), meanOf(a));
  }

  /// Clearly decided: the leader well ahead, beyond the noise.
  bool _decided(Iterable<T> among) {
    final (gap, z, _) = _lead(among);
    return gap > 0.05 && z > 3;
  }

  /// Too close to call, on a decision the round turns on: the best two
  /// within the noise, and the leader neither sure to win nor sure to
  /// lose. Two options that fare all but the same aren't a dilemma: every
  /// option is played against the same imagined futures, so two cards
  /// that are as good as each other (a 2 or a 3 nobody needs) come out
  /// nearly level, and either will do.
  bool _tooClose(Iterable<T> among) {
    final (gap, z, lead) = _lead(among);
    return z < 1.5 && gap > interchangeable && lead > 0.05 && lead < 0.95;
  }

  /// How near two options' averages are for them to count as the same.
  static const interchangeable = 0.004;

  /// The next playouts to run, as (option, from, count); empty when the
  /// race is over.
  List<(T, int, int)> next() {
    if (options.length < 2) return const [];
    switch (_stage) {
      case 0:
        // The first look at every option.
        _stage = 1;
        final first = focus
            ? max(16, (budget * 0.4) ~/ options.length)
            : max(20, budget ~/ options.length);
        return [for (final o in options) (o, playedFor(o), first)];
      case 1:
        if (adaptive && _decided(options)) {
          _clear = true;
          return const [];
        }
        if (!focus) return _extend();
        // The best few go on, in two halves, so a clear winner can stop it.
        final keep = max(2, (options.length / 3).ceil());
        _finalists = _ranked(options).take(keep).toList();
        final first = playedFor(options.first);
        _more = max(16, (budget - first * options.length) ~/ _finalists.length);
        _stage = 2;
        return [for (final o in _finalists) (o, playedFor(o), (_more + 1) ~/ 2)];
      case 2:
        if (adaptive && _decided(_finalists)) {
          _clear = true;
          return const [];
        }
        _stage = 3;
        return [for (final o in _finalists) (o, playedFor(o), _more ~/ 2)];
      default:
        return _extend();
    }
  }

  /// Past the usual budget: while the best two are too close on a
  /// decision that matters, a quarter of the budget more on the two of
  /// them at a time, up to [stretch] times the budget in all.
  List<(T, int, int)> _extend() {
    _stage = 4;
    final among = focus ? _finalists : options;
    if (!adaptive || spent >= budget * stretch || !_tooClose(among)) return const [];
    final two = _ranked(among).take(2);
    final each = max(16, (budget * 0.25) ~/ 2);
    return [for (final o in two) (o, playedFor(o), each)];
  }

  /// The winner: the best average, ties broken by [rand].
  T best(Random rand) {
    final among = (_finalists.isNotEmpty ? _finalists : options).where((o) => (_n[o] ?? 0) > 0);
    var best = options.first;
    var bestScore = double.negativeInfinity;
    for (final o in among) {
      final v = meanOf(o) + rand.nextDouble() * 0.01;
      if (v > bestScore) {
        bestScore = v;
        best = o;
      }
    }
    return best;
  }

  /// How the race went.
  Thought get thought => Thought(
      options: options.length,
      spent: spent,
      budget: budget,
      clear: _clear,
      close: options.length > 1 && !_clear && _tooClose(_finalists.isNotEmpty ? _finalists : options));
}
