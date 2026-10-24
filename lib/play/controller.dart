import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../engine/bot.dart';
import '../engine/cards.dart';
import '../engine/match.dart';
import '../engine/rules.dart';
import '../models.dart';

/// Where actions go. Today every action is applied on this device; an
/// online game would send them to a shared backend (such as Firebase) and
/// apply them as they come back, in order, on every device.
abstract class MatchConnection {
  void send(MatchAction action);
}

/// Runs a card game on this device: you at seat 0, bots everywhere else.
class MatchController extends ChangeNotifier implements MatchConnection {
  MatchController({required int players, required int target, int? seed})
      : rand = Random(seed),
        state = MatchState(players: players, target: target) {
    bot = Bot(rand);
  }

  final Random rand;
  final MatchState state;
  late final Bot bot;

  /// The seat on this device.
  static const human = 0;

  /// How long bots wait before acting, and how long a finished trick
  /// stays on the table. Shortened in tests.
  static Duration botDelay = const Duration(milliseconds: 650);
  static Duration trickPause = const Duration(milliseconds: 1300);

  /// The trick just finished, held on the table for a moment.
  Trick? lastTrick;

  /// A bot is deciding.
  bool thinking = false;

  bool _disposed = false;
  Timer? _timer;

  void start() {
    state.newRound(rand);
    _sync();
    _advance();
  }

  void nextRound(int target) {
    state.target = target;
    lastTrick = null;
    start();
  }

  /// A task waiting for you to announce its number, if any.
  int? get pendingAnnouncement {
    if (state.phase != Phase.announcing) return null;
    for (int i = 0; i < state.tasks.length; i++) {
      final t = state.tasks[i];
      if (t.owner == human && needsX(t.description) && t.x == null) return i;
    }
    return null;
  }

  bool get yourPick =>
      state.phase == Phase.picking && state.pickTurn == human;

  bool get yourPlay =>
      state.phase == Phase.playing && state.turn == human && lastTrick == null;

  @override
  void send(MatchAction action) {
    if (_disposed || state.problem(action) != null) return;
    final trick = state.apply(action);
    _sync();
    if (trick != null) {
      lastTrick = trick;
      _notify();
      _timer = Timer(trickPause, () {
        lastTrick = null;
        _notify();
        _advance();
      });
      return;
    }
    _notify();
    _advance();
  }

  /// Lets the bot whose turn it is act, after a short pause.
  void _advance() {
    if (_disposed || lastTrick != null) return;
    final MatchAction? Function()? decide = switch (state.phase) {
      Phase.picking when state.pickTurn != null && state.pickTurn != human =>
        () => PickTask(state.pickTurn!, bot.choosePick(state, state.pickTurn!)),
      Phase.announcing when _botMustAnnounce => _botAnnouncement,
      Phase.playing when state.turn != human => () =>
          PlayCard(state.turn, bot.choosePlay(state, state.turn)),
      _ => null,
    };
    if (decide == null) {
      thinking = false;
      _notify();
      return;
    }
    thinking = true;
    _notify();
    _timer = Timer(botDelay, () {
      if (_disposed) return;
      final action = decide();
      thinking = false;
      if (action != null) {
        send(action);
      } else {
        _notify();
      }
    });
  }

  bool get _botMustAnnounce => state.tasks.any((t) =>
      t.owner != null &&
      t.owner != human &&
      needsX(t.description) &&
      t.x == null);

  MatchAction? _botAnnouncement() {
    for (int i = 0; i < state.tasks.length; i++) {
      final t = state.tasks[i];
      if (t.owner != null &&
          t.owner != human &&
          needsX(t.description) &&
          t.x == null) {
        return Announce(t.owner!, i, bot.chooseX(state, t.owner!, i));
      }
    }
    return null;
  }

  /// Mirrors each verdict onto its task so the table cards flip and redden.
  void _sync() {
    for (final t in state.tasks) {
      t.task.status = switch (t.verdict) {
        Verdict.done => TaskStatus.completed,
        Verdict.failed => TaskStatus.failed,
        Verdict.pending => TaskStatus.pending,
      };
      t.task.assignedPlayerIndex = t.owner;
    }
  }

  /// Plays a card for you (tests and hints).
  PlayingCard suggestion() => bot.choosePlay(state, human);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
