import 'dart:math';

import '../engine/deal_mix.dart';
import '../engine/decrees.dart';
import '../engine/round.dart';
import '../engine/rules.dart';
import '../engine/showing.dart';
import '../engine/task.dart';
import 'actions.dart';
import 'courtiers.dart';
import 'dice.dart';
import 'players.dart';
import 'saves.dart';
import 'setup.dart';

export '../engine/round.dart' show RoundOutcome;
export '../engine/task.dart';
export 'players.dart';
export 'saves.dart' show saveVersion, upgradeSave;

/// Free play; Endless (each win adds a point); the Chronicle chapters;
/// Dynasty, where the King reigns until they fall; or the Tutorial, short
/// set-up rounds that teach the game (see tutorial.dart). New modes go on
/// the end: saved games store the index.
enum GameMode { free, endless, chronicle, dynasty, tutorial }

const minPlayers = 2;
const maxPlayers = 6;

/// The highest points target a round can have. The balance report shows
/// rounds above this are close to impossible.
const maxTarget = 20;

/// What a round is set up with, as its mode decides: its tasks (or none,
/// for a draw to the points target), the target itself when the mode
/// fixes it (a chapter's), its seals and decree, and whether anyone may
/// pass on a pick.
class RoundSetup {
  const RoundSetup(
      {this.tasks,
      this.target,
      this.sealCount = 0,
      this.decree,
      this.passing = true});

  /// The seals, decree and rules of [round] again, for a re-deal; the
  /// tasks are drawn afresh.
  RoundSetup.keep(Round? round)
      : tasks = null,
        target = null,
        sealCount = round?.sealCount ?? 0,
        decree = round?.decree,
        passing = round?.passing ?? true;

  final List<Task>? tasks;
  final int? target;
  final int sealCount;
  final Decree? decree;
  final bool passing;
}

/// A game at the table: who's playing, how, the round in progress and the
/// record so far. Plain Dart (colours are numbers), so the whole game can
/// run on a server.
class GameState {
  List<Player> players = [];

  /// Which courtier sits in each seat (decides the token's shape).
  List<Courtier> courtiers = [];

  GameMode mode = GameMode.free;

  /// The points the round's tasks add up to.
  int target = 5;

  /// Endless mode: each win adds a point to the next round.
  bool get campaign => mode == GameMode.endless;
  set campaign(bool on) => mode = on ? GameMode.endless : GameMode.free;

  /// The Chronicle chapter being played, if any.
  int? chapter;

  /// The tutorial lesson being played (see modes/tutorial/lessons.dart).
  int lesson = 0;
  bool get isTutorial => mode == GameMode.tutorial;
  bool get isDynasty => mode == GameMode.dynasty;

  /// Free play and Endless: add random seals and decrees to each round.
  bool surprise = false;

  /// Whether everyone plays a courtier, with a house of their own.
  bool roles = true;
  bool get hasRoles => roles;

  /// On-screen cards: the round is played on the device, you in seat 0
  /// and bots in the rest. Otherwise the phone keeps the tasks for a real
  /// deck.
  bool digital = false;

  /// What the game was started with (game/setup.dart), so it can be
  /// started again exactly: a replay, a bug report. Null for a game from
  /// before setups were kept.
  GameSetup? setup;

  /// The round in progress: its tasks, deal and tricks. Null before a game
  /// is set up.
  Round? round;

  /// The round's tasks (none before a game is set up).
  List<RoundTask> get tasks => round?.tasks ?? const [];

  int roundNumber = 0;
  int wins = 0;
  int losses = 0;

  /// Rounds won in a row, and the best run (kept across games by the app).
  int streak = 0;
  int bestStreak = 0;

  /// Increases every time tasks are dealt or shuffled, so the UI can
  /// animate the change.
  int dealId = 0;

  /// The game's seed: every random choice in the game comes from it (see
  /// game/dice.dart), so a game can be dealt and played again exactly (a
  /// bug report, a shared hand, a daily deal). New games get a random one.
  int seed = Random().nextInt(1 << 30);

  /// The game's dice: the random numbers for each purpose on each deal.
  Dice get dice => Dice(seed);

  /// The random numbers for [purpose] on this deal.
  Random roll(Purpose purpose) => dice.roll(purpose, dealId: dealId);

  bool _resultRecorded = false;
  int _streakBefore = 0;
  int _bestBefore = 0;

  /// Every task in the game (see engine/task.dart).
  static final List<Task> taskPool = allTasks;

  /// Seats each player as a courtier, from the seed: a different shape
  /// for everyone.
  void seatCourtiers() {
    courtiers =
        (Courtier.houses..shuffle(roll(Purpose.seats))).take(players.length).toList();
  }

  /// How the round in progress stands.
  RoundOutcome get outcome => round?.outcome ?? RoundOutcome.inProgress;

  /// Crowns the King: the exile (under that decree) is chosen from the
  /// game's seed, tasks only one player may take go to them, and the King
  /// picks first.
  void crown(int? seat) => round!.crown(seat, roll(Purpose.exile));

  /// The last done or failed mark made by hand, so it can be undone from
  /// the round's result (not saved).
  (RoundTask, TaskStatus)? lastMark;

  /// Why [a] isn't allowed right now, or null if it is.
  String? problem(GameAction a) {
    final r = round;
    if (r == null || r.tasks.isEmpty) return 'No round in progress';
    switch (a) {
      case Crown(:final king):
        if (king < 0 || king >= players.length) return 'No such seat';
        if (r.king != null) return 'The King is crowned already';
      case Speak(:final seat, :final on):
        if (seat < 0 || seat >= players.length) return 'No such seat';
        if (on && !r.spoke[seat] && !r.canSpeak(seat)) {
          return r.whyCantSpeak() ?? 'No cards may be shown now';
        }
      case MarkTask(:final task):
        if (task < 0 || task >= r.tasks.length) return 'No such task';
      case UndoMark():
        if (lastMark == null) return 'Nothing to undo';
      case NextRound(:final chapter, :final lesson):
        if (chapter != null && chapter < 0) return 'No such chapter';
        if (lesson != null && lesson < 0) return 'No such lesson';
      case RetryRound():
      case Redeal():
        break;
    }
    return null;
  }

  /// Carries out [a], the one way the game changes outside a round's
  /// play. [setup] is the mode's say for a new round (the next round, a
  /// re-deal). Returns true when [a] settled the round's result (a mark
  /// that won or lost it), which the table then shows.
  bool apply(GameAction a,
      {RoundSetup Function(Random rand, {bool redeal})? setup}) {
    final why = problem(a);
    if (why != null) throw StateError(why);
    final r = round!;
    switch (a) {
      case Crown(:final king):
        crown(king);
      case Speak(:final seat, :final on):
        r.spoke[seat] = on;
      case MarkTask(:final task, :final status):
        final t = r.tasks[task];
        final previous = t.status;
        r.mark(t, status);
        lastMark = (t, previous);
        return recordOutcomeIfFinished();
      case UndoMark():
        final (task, previous) = lastMark!;
        undoOutcome();
        task.status = previous;
        lastMark = null;
      case NextRound(:final target, :final chapter, :final lesson):
        if (chapter != null) this.chapter = chapter;
        if (lesson != null) this.lesson = lesson;
        lastMark = null;
        shuffleTasks(players.length, target ?? this.target, setup: setup);
      case RetryRound():
        lastMark = null;
        retryRound();
      case Redeal(:final target):
        lastMark = null;
        startRound(players.length, target,
            setup: setup == null ? null : (rand) => setup(rand, redeal: true),
            countRound: false);
    }
    return false;
  }

  /// Updates the win/loss record and streak once per round. Returns true if
  /// a result was recorded by this call.
  bool recordOutcomeIfFinished() {
    final o = outcome;
    if (o == RoundOutcome.inProgress || _resultRecorded) return false;
    _streakBefore = streak;
    _bestBefore = bestStreak;
    if (o == RoundOutcome.won) {
      wins++;
      streak++;
      bestStreak = max(bestStreak, streak);
    } else {
      losses++;
      streak = 0;
    }
    _resultRecorded = true;
    return true;
  }

  /// Takes the finished round's result back off the record (used when the
  /// last mark is undone).
  void undoOutcome() {
    if (!_resultRecorded) return;
    if (outcome == RoundOutcome.won) {
      wins--;
    } else if (outcome == RoundOutcome.lost) {
      losses--;
    }
    streak = _streakBefore;
    bestStreak = _bestBefore;
    _resultRecorded = false;
  }

  /// Replays the same tasks in a new round: clears results and assignments.
  void retryRound() {
    final old = round!;
    roundNumber++;
    dealId++;
    _resultRecorded = false;
    round = _newRound(old.players, target)
      ..tasks = [for (final t in old.tasks) RoundTask(t.task, seal: t.seal)]
      ..sealCount = old.sealCount
      ..decree = old.decree
      ..passing = old.passing;
  }

  /// New tasks for the table: a new round once this one is over, or, mid-
  /// round, this round's tasks dealt again with the King kept (the King
  /// picks first again). [setup] is the mode's say for the round, told
  /// whether it's a re-deal.
  void shuffleTasks(int playerCount, int targetPoints,
      {RoundSetup Function(Random rand, {bool redeal})? setup}) {
    final old = round;
    final redeal = old != null && old.tasks.isNotEmpty && outcome == RoundOutcome.inProgress;
    final keep = RoundSetup.keep(old);
    startRound(playerCount, targetPoints,
        setup: (rand) => setup != null
            ? setup(rand, redeal: redeal)
            : redeal
                ? keep
                : const RoundSetup(),
        countRound: !redeal,
        keepKing: redeal);
  }

  /// Starts a round of [playerCount] seats played to [targetPoints] (or
  /// the target [setup] fixes): its tasks drawn at random to the target
  /// unless [setup] names them, with the seals, decree and rules [setup]
  /// gives it (none, by default). The setup rolls on [rand] first, so the
  /// same seed draws the same round. With [keepKing] the reigning King,
  /// the exile and the pick stay (a shuffle mid-round); otherwise the
  /// round waits to be crowned.
  void startRound(int playerCount, int targetPoints,
      {RoundSetup Function(Random rand)? setup,
      bool countRound = true,
      bool keepKing = false}) {
    final old = round;
    if (countRound) roundNumber++;
    dealId++;
    _resultRecorded = false;
    final rand = roll(Purpose.tasks);
    final rules = setup?.call(rand) ?? const RoundSetup();
    target = rules.target ?? targetPoints;
    final r = _newRound(playerCount, target);
    round = r;
    r.sealCount = rules.sealCount;
    r.decree = rules.decree;
    r.passing = rules.passing;
    // Exile needs someone to banish besides the King.
    if (r.decree == Decree.exile && playerCount < 3) r.decree = Decree.silence;
    if (rules.tasks case final fixed?) {
      r.tasks = [for (final t in fixed) RoundTask(t)];
    } else {
      // Draw the tasks, and if the round has seals, try a few draws for
      // enough tasks a seal can sit on.
      var best = const <Task>[];
      var bestFree = -1;
      for (var attempt = 0; attempt < 12; attempt++) {
        final drawn = _drawTasks(playerCount, target, r.decree, rand);
        final free = drawn.where(_sealable).length;
        if (free > bestFree) {
          best = drawn;
          bestFree = free;
        }
        if (r.sealCount < 2 || free >= r.sealCount) break;
      }
      r.tasks = [for (final t in best) RoundTask(t)];
      _placeSeals(r, rand);
    }
    if (keepKing && old != null) {
      r
        ..king = old.king
        ..exiledSeat = old.exiledSeat
        ..pickTurn = old.king;
      if (old.king != null) r.leader = old.king!;
    }
  }

  /// A fresh round for this game's seats, named after the players.
  Round _newRound(int playerCount, int targetPoints) =>
      Round(players: playerCount, target: targetPoints, dealId: dealId)
        ..names = [
          for (var i = 0; i < playerCount; i++)
            i < players.length ? players[i].name : 'Player ${i + 1}'
        ];

  /// A seal orders tasks by when they're done, so it only goes on a task
  /// that can be done on any trick (see [TaskTiming]).
  static bool _sealable(Task t) =>
      timingOf(t.description) == TaskTiming.anyTrick;

  List<Task> _drawTasks(int playerCount, int targetPoints, Decree? decree, Random rand) {
    final drawn = <Task>[];
    var currentTotal = 0;
    final pool = drawOrder(taskPool, rand,
        description: (t) => t.description,
        points: (t) => t.getPointsForPlayerCount(playerCount),
        target: targetPoints);
    final hands = playerCount < 3 ? 3 : playerCount;
    for (final task in pool) {
      if (currentTotal >= targetPoints) break;
      final points = task.getPointsForPlayerCount(playerCount);
      if (currentTotal + points > targetPoints) continue;
      // Nobody may show a card under Silence.
      if (decree == Decree.silence && needsShowing(task.description)) continue;
      // Never deal tasks that can't all be done (see deal_mix.dart).
      if (!fitsDeal([for (final t in drawn) t.description], task.description, hands)) {
        continue;
      }
      drawn.add(task);
      currentTotal += points;
    }
    return drawn;
  }

  /// Puts the round's seals on tasks that can take them. A single seal
  /// orders nothing, so a round has two or none. The Ω seal must be the
  /// last task done, so it's only used when no other task waits for the
  /// round to end; otherwise the seals are all numbered.
  static void _placeSeals(Round r, Random rand) {
    final free = r.tasks.where((t) => _sealable(t.task)).toList()..shuffle(rand);
    final count = min(r.sealCount, free.length);
    if (count < 2) return;
    final othersWait = r.tasks.any((t) =>
        !free.take(count).contains(t) &&
        timingOf(t.description) == TaskTiming.end);
    final seals = othersWait
        ? [for (var i = 1; i <= count; i++) i]
        : Seals.forCount(count);
    for (var i = 0; i < seals.length; i++) {
      free[i].seal = seals[i];
    }
  }

  // ------------------------------------------------------------ saving

  Map<String, dynamic> toJson() => {
        'version': saveVersion,
        if (setup != null) 'setup': setup!.toJson(),
        'players': [
          for (final p in players)
            {'name': p.name, 'color': p.colorValue},
        ],
        'courtiers': [for (final c in courtiers) c.index],
        'mode': mode.index,
        'target': target,
        'chapter': chapter,
        'lesson': lesson,
        'surprise': surprise,
        'roles': roles,
        'digital': digital,
        'round': round?.toJson(),
        'roundNumber': roundNumber,
        'wins': wins,
        'losses': losses,
        'streak': streak,
        'bestStreak': bestStreak,
        'dealId': dealId,
        'seed': seed,
        'resultRecorded': _resultRecorded,
      };

  /// Rebuilds a saved game of any version. Returns null if the save can't
  /// be read (for example after the task list changed in an update).
  static GameState? fromJson(Map<String, dynamic> saved) {
    try {
      final j = upgradeSave(saved);
      final g = GameState()
        ..players = [
          for (final p in (j['players'] as List<dynamic>).cast<Map<String, dynamic>>())
            Player(p['name'] as String, colorValue: p['color'] as int),
        ]
        ..courtiers = [
          for (final c in (j['courtiers'] as List?) ?? const [])
            Courtier.values[c as int]
        ]
        ..mode = GameMode.values[(j['mode'] as int?) ?? 0]
        ..target = (j['target'] as int?) ?? 5
        ..chapter = j['chapter'] as int?
        ..lesson = (j['lesson'] as int?) ?? 0
        ..surprise = (j['surprise'] as bool?) ?? false
        ..roles = (j['roles'] as bool?) ?? true
        ..digital = (j['digital'] as bool?) ?? false
        ..roundNumber = j['roundNumber'] as int
        ..wins = j['wins'] as int
        ..losses = j['losses'] as int
        ..streak = j['streak'] as int
        ..bestStreak = j['bestStreak'] as int
        ..dealId = j['dealId'] as int;
      if (j['seed'] is int) g.seed = j['seed'] as int;
      if (j['setup'] is Map) {
        g.setup = GameSetup.fromJson(Map<String, dynamic>.from(j['setup'] as Map));
      }
      g._resultRecorded = j['resultRecorded'] as bool;
      if (g.players.isEmpty) return null;
      // A game of the old Dynasty: its story no longer loads.
      if (g.isDynasty) return null;
      if (j['round'] is! Map) return null;
      final r = Round.fromJson(Map<String, dynamic>.from(j['round'] as Map));
      if (r.tasks.isEmpty) return null;
      g.round = r..names = [for (final p in g.players) p.name];
      if (g.courtiers.length != g.players.length) g.seatCourtiers();
      return g;
    } catch (_) {
      return null;
    }
  }


}
