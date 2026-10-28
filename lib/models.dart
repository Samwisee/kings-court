import 'dart:math';

import 'engine/deal_mix.dart';
import 'engine/decrees.dart';
import 'engine/round.dart';
import 'engine/rules.dart';
import 'engine/showing.dart';
import 'engine/task.dart';
import 'game/actions.dart';
import 'game/courtiers.dart';

export 'engine/round.dart' show RoundOutcome;
export 'engine/task.dart';

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

/// The colours seats are given, as ARGB values (the Okabe–Ito set, which
/// stays distinct for colour-blind players and at a glance). The screen's
/// Palette.players is made from these.
const playerColours = <int>[
  0xFFE69F00, // orange
  0xFF56B4E9, // sky blue
  0xFFCC79A7, // reddish purple
  0xFF009E73, // bluish green
  0xFFF0E442, // yellow
  0xFF0072B2, // deep blue
];

class Player {
  String name;

  /// The seat's colour, as an ARGB value (the screen turns it into a
  /// Color; the game itself has no Flutter in it, so it can run on a server).
  int colorValue;
  Player(this.name, {required this.colorValue});
}

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

  /// The game's seed: with [dealId] it fixes the cards and tasks each round
  /// deals, so a round can be dealt again exactly (a bug report, a shared
  /// hand, a daily deal). New games get a random one.
  int seed = Random().nextInt(1 << 30);

  /// The random numbers for this deal: the same for the same game, round
  /// and [salt] every time.
  Random dealRandom([int salt = 0]) =>
      Random(seed ^ (dealId * 0x9E3779B1) ^ (salt * 0x85EBCA6B));
  bool _resultRecorded = false;
  int _streakBefore = 0;
  int _bestBefore = 0;

  /// Every task in the game (see engine/task.dart).
  static final List<Task> taskPool = allTasks;

  /// Seats each player as a courtier: a different shape for everyone.
  void seatCourtiers() {
    courtiers = (Courtier.houses..shuffle()).take(players.length).toList();
  }

  /// How the round in progress stands.
  RoundOutcome get outcome => round?.outcome ?? RoundOutcome.inProgress;

  /// Crowns the King: the exile (under that decree) is chosen from the
  /// game's seed, tasks only one player may take go to them, and the King
  /// picks first.
  void crown(int? seat) => round!.crown(seat, dealRandom(2));

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
      case Retry():
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
      case Retry():
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
    final rand = dealRandom(1);
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

  /// The shape saves are written in. A save from an older version is
  /// brought up to date one step at a time by [upgradeSave] before it's
  /// read, so each change to the format is one migration here:
  ///
  /// 1. before the refactor: the round's tasks, King, picks and so on
  ///    beside the game, and the on-screen cards apart under `cards`;
  /// 2. the round is one record under `round`.
  static const saveVersion = 2;

  Map<String, dynamic> toJson() => {
        'version': saveVersion,
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

  /// [saved] in the current shape: each migration from its version on,
  /// in turn. A save with no version is from before versions (1).
  static Map<String, dynamic> upgradeSave(Map<String, dynamic> saved) {
    var j = saved;
    var version = (j['version'] as int?) ?? 1;
    while (version < saveVersion) {
      j = _migrations[version]!(j);
      version++;
    }
    return j;
  }

  /// From each version to the next.
  static const _migrations = <int, Map<String, dynamic> Function(Map<String, dynamic>)>{
    1: _v1ToV2,
  };

  /// Version 1 kept the round's tasks, King, picks, seals and decree
  /// beside the game, and the on-screen cards apart under `cards` (with
  /// their own tasks, announced numbers and shown cards); the round
  /// number was `round`. Version 2 has the round as one record.
  static Map<String, dynamic> _v1ToV2(Map<String, dynamic> j) {
    final players = (j['players'] as List?)?.length ?? 0;
    final dealId = j['dealId'] as int;
    final tutorial = j['mode'] == GameMode.tutorial.index;
    final tasks = [
      for (final t in (j['tasks'] as List<dynamic>).cast<Map<String, dynamic>>())
        RoundTask.fromJson(t).toJson()
    ];
    // The cards, if they were dealt for this very deal.
    final raw = j['cards'];
    final cards = raw is Map && raw['dealId'] == dealId
        ? Map<String, dynamic>.from(raw)
        : null;
    if (cards != null) {
      final announced = (cards['announced'] as Map?) ?? const {};
      for (final t in tasks) {
        if (announced[t['d']] case final int x) t['x'] = x;
      }
    }
    final open = tasks.any((t) => t['owner'] == null);
    final failed = tasks.any((t) => t['status'] == TaskStatus.failed.index);
    final done = tasks.every((t) => t['status'] == TaskStatus.completed.index);
    final unannounced = tasks.any((t) => needsX(t['d'] as String) && t['x'] == null);
    final phase = failed || done
        ? Phase.roundOver
        : open
            ? Phase.picking
            : unannounced
                ? Phase.announcing
                : Phase.playing;
    final round = <String, dynamic>{
      'players': players,
      'target': (j['target'] as int?) ?? 5,
      'hands': cards?['hands'] ?? const <dynamic>[],
      'setAside': cards?['setAside'] ?? const <dynamic>[],
      'king': j['king'],
      'tasks': tasks,
      'pickTurn': j['pickTurn'],
      'passed': j['passed'] ?? const <dynamic>[],
      if (j['spoke'] case final List<dynamic> spoke when spoke.length == players)
        'spoke': spoke,
      'picksMade': 0,
      'sealCount': j['sealCount'] ?? 0,
      'decree': j['decree'],
      'exiled': j['exiled'],
      'passing': !tutorial,
      'tricks': cards?['tricks'] ?? const <dynamic>[],
      'leader': cards?['leader'] ?? 0,
      'currentSeats': cards?['currentSeats'] ?? const <dynamic>[],
      'current': cards?['current'] ?? const <dynamic>[],
      'phase': phase.index,
      'dealId': dealId,
      'revealed': cards?['revealed'] ?? const <String, dynamic>{},
      'revealHint': cards?['revealHint'] ?? const <String, dynamic>{},
      'revealedAt': cards?['revealedAt'] ?? const <String, dynamic>{},
    };
    return {
      ...j,
      'version': 2,
      'digital': j['cards'] != null,
      'round': round,
      'roundNumber': j['round'],
    }
      ..remove('tasks')
      ..remove('cards')
      ..remove('king')
      ..remove('pickTurn')
      ..remove('passed')
      ..remove('spoke')
      ..remove('sealCount')
      ..remove('decree')
      ..remove('exiled');
  }
}

/// Short labels for seat tokens and the owner badge on cards. Default
/// names ("Player 3") show the seat number; real names show initials. If
/// two players would share a label, they get the first two letters of
/// their name instead, and failing that their seat number.
List<String> seatLabels(List<Player> players) {
  final defaultName = RegExp(r'^player \d+$', caseSensitive: false);
  String initials(String name) {
    // "The General" is G: the article isn't part of the name.
    final words = name
        .replaceFirst(RegExp(r'^the\s+', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  final labels = <String>[
    for (int i = 0; i < players.length; i++)
      () {
        final name = players[i].name.trim();
        return name.isEmpty || defaultName.hasMatch(name)
            ? '${i + 1}'
            : initials(name);
      }(),
  ];

  for (var pass = 0; pass < 2; pass++) {
    final counts = <String, int>{};
    for (final l in labels) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    for (var i = 0; i < labels.length; i++) {
      if (counts[labels[i]]! < 2) continue;
      final name = players[i]
          .name
          .trim()
          .replaceFirst(RegExp(r'^the\s+', caseSensitive: false), '');
      labels[i] = pass == 0 && name.length >= 2 && !defaultName.hasMatch(name)
          ? '${name[0].toUpperCase()}${name[1].toLowerCase()}'
          : '${i + 1}';
    }
  }
  return labels;
}
