import 'dart:math';

import 'chronicle.dart';
import 'courtiers.dart';
import 'engine/deal_mix.dart';
import 'engine/round.dart';
import 'engine/rules.dart';
import 'engine/showing.dart';
import 'engine/task.dart';
import 'tutorial.dart';

export 'engine/round.dart' show RoundOutcome;
export 'engine/task.dart';

/// Free play; Endless (each win adds a point); the Chronicle chapters;
/// Dynasty, where the King reigns until they fall; or the Tutorial, short
/// set-up rounds that teach the game (see tutorial.dart). New modes go on
/// the end: saved games store the index.
enum GameMode { free, endless, chronicle, dynasty, tutorial }

const minPlayers = 2;
const maxPlayers = 6;

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

  /// The tutorial lesson being played (see [lessons]).
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
      ..decree = old.decree;
  }

  /// Draws a new set of tasks. Starts a new round unless the current round
  /// is still in progress (shuffling mid-round replaces this round's tasks
  /// and the King picks first again).
  void shuffleTasks(int playerCount, int targetPoints) {
    final old = round;
    final finished = old == null || old.tasks.isEmpty || outcome != RoundOutcome.inProgress;
    addTasksUntilTarget(playerCount, targetPoints, newRound: finished);
    if (!finished) {
      roundNumber--; // same round, new tasks
      final r = round!
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

  /// Draws random tasks (no repeats) whose points add up to [targetPoints]
  /// for the given player count, or as close as the pool allows, into a
  /// new round.
  ///
  /// A new round also settles its seals and decree: a Chronicle chapter
  /// fixes them; with [surprise] on they're rolled at random. Otherwise
  /// (a re-deal) the round keeps the seals and decree it had.
  void addTasksUntilTarget(int playerCount, int targetPoints,
      {bool newRound = true, bool countRound = true}) {
    final old = round;
    if (countRound) roundNumber++;
    dealId++;
    _resultRecorded = false;
    final r = _newRound(playerCount, targetPoints);
    round = r;
    final rand = dealRandom(1);
    // The tutorial sets its own tasks, with no seals or decrees.
    if (isTutorial) {
      final lessonTasks = lessons[max(0, min(lesson, lessons.length - 1))].tasks;
      r.tasks = [for (final d in lessonTasks) RoundTask(taskByDescription(d))];
      return;
    }
    if (newRound) {
      if (mode == GameMode.chronicle && chapter != null) {
        r.sealCount = chronicle[chapter!].seals;
        r.decree = chronicle[chapter!].decree;
      } else if (surprise) {
        r.sealCount = const [0, 0, 2, 3][rand.nextInt(4)];
        r.decree = rand.nextBool()
            ? Decree.values[rand.nextInt(Decree.values.length)]
            : null;
      }
      if (r.decree == Decree.exile && playerCount < 3) r.decree = Decree.silence;
    } else if (old != null) {
      r.sealCount = old.sealCount;
      r.decree = old.decree;
    }
    // Draw the tasks, and if the round has seals, try a few draws for
    // enough tasks a seal can sit on.
    var best = const <Task>[];
    var bestFree = -1;
    for (var attempt = 0; attempt < 12; attempt++) {
      final drawn = _drawTasks(playerCount, targetPoints, r.decree, rand);
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

  /// Rebuilds a saved game. Returns null if the save can't be read (for
  /// example after the task list changed in an update). Reads saves from
  /// before the round was one record too (`tasks` beside `cards`).
  static GameState? fromJson(Map<String, dynamic> j) {
    try {
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
        ..roundNumber = (j['roundNumber'] ?? j['round']) as int
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
      if (j['round'] is Map) {
        g.digital = (j['digital'] as bool?) ?? false;
        g.round = Round.fromJson(Map<String, dynamic>.from(j['round'] as Map));
      } else {
        g.digital = j['cards'] != null;
        g.round = _legacyRound(j, g);
      }
      final r = g.round;
      if (r == null || r.tasks.isEmpty) return null;
      r.names = [for (final p in g.players) p.name];
      if (g.courtiers.length != g.players.length) g.seatCourtiers();
      return g;
    } catch (_) {
      return null;
    }
  }

  /// A round from a save that kept the tasks and the cards apart.
  static Round _legacyRound(Map<String, dynamic> j, GameState g) {
    final r = Round(players: g.players.length, target: g.target, dealId: g.dealId)
      ..tasks = [
        for (final t in (j['tasks'] as List<dynamic>).cast<Map<String, dynamic>>())
          RoundTask.fromJson(t)
      ]
      ..king = j['king'] as int?
      ..passed = {for (final s in (j['passed'] as List?) ?? const []) s as int}
      ..pickTurn = j['pickTurn'] as int?
      ..sealCount = (j['sealCount'] as int?) ?? 0
      ..decree = j['decree'] == null ? null : Decree.values[j['decree'] as int]
      ..exiledSeat = j['exiled'] as int?;
    if (j['spoke'] case final List<dynamic> spoke when spoke.length == r.players) {
      r.spoke = List<bool>.from(spoke);
    }
    // The cards, if they were dealt for this very deal.
    if (j['cards'] case final Map<dynamic, dynamic> cards
        when cards['dealId'] == g.dealId) {
      final c = Round.fromJson(Map<String, dynamic>.from(cards));
      r
        ..hands = c.hands
        ..setAside = c.setAside
        ..tricks = c.tricks
        ..leader = c.leader
        ..currentSeats = c.currentSeats
        ..current = c.current
        ..revealed = c.revealed
        ..revealHint = c.revealHint
        ..revealedAt = c.revealedAt;
      for (final t in r.tasks) {
        final x = c.announced[t.description];
        if (x != null) t.x = x;
      }
    }
    return r;
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
