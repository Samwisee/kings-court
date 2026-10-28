import 'dart:math';

import 'chronicle.dart';
import 'courtiers.dart';
import 'engine/conflicts.dart';
import 'engine/deal_mix.dart';
import 'engine/match.dart';
import 'engine/rules.dart';
import 'engine/showing.dart';
import 'engine/task.dart';
import 'tasks.dart';
import 'tutorial.dart';

export 'engine/task.dart';

enum RoundOutcome { inProgress, won, lost }

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

class GameState {
  List<Player> players = [];
  List<Task> tasks = [];

  /// Index of the player holding the King card, or null if not chosen yet.
  int? kingIndex;

  int roundNumber = 0;
  int wins = 0;
  int losses = 0;

  /// Whether each player has used their once-per-round card reveal.
  List<bool> spoke = [];

  /// Seats that have passed on taking a task this round. Each player may
  /// pass once a round, handing the pick to the next player.
  Set<int> passed = {};

  /// Whose turn it is to pick a task, or null once every task has an owner.
  int? pickTurn;

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

  /// Free play and Endless: add random seals and decrees to each round.
  bool surprise = false;

  /// Whether everyone plays a courtier, with a house of their own.
  bool roles = true;
  bool get hasRoles => roles;

  /// On-screen cards: the round is played on the device, you in seat 0
  /// and bots in the rest. Null when playing with a real deck.
  MatchState? cards;
  bool get digital => cards != null;

  /// Seals in this round, the decree in force, and the exiled seat.
  int sealCount = 0;
  Decree? decree;
  int? exiledSeat;

  /// Which courtier sits in each seat (decides the token's shape).
  List<Courtier> courtiers = [];

  /// Seats each player as a courtier: a different shape for everyone.
  void seatCourtiers() {
    courtiers = (Courtier.houses..shuffle()).take(players.length).toList();
  }

  bool get isDynasty => mode == GameMode.dynasty;

  void _chooseExile() {
    exiledSeat = null;
    final king = kingIndex;
    if (king != null && decree == Decree.exile && players.length >= 3) {
      // Banish someone other than the King.
      final others = [
        for (int i = 0; i < players.length; i++)
          if (i != king) i
      ];
      if (others.isNotEmpty) exiledSeat = others[Random().nextInt(others.length)];
    }
  }

  /// The next seat clockwise after [from] that may pick a task.
  int? _nextPicker(int from) {
    // Skip anyone who can't take any of the tasks left.
    for (var step = 1; step <= players.length; step++) {
      final seat = (from + step) % players.length;
      if (seat != exiledSeat &&
          tasks.any((t) => t.assignedPlayerIndex == null && canTake(t, seat))) {
        return seat;
      }
    }
    for (var step = 1; step <= players.length; step++) {
      final seat = (from + step) % players.length;
      if (seat != exiledSeat) return seat;
    }
    return null;
  }

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

  /// A round is won when every task is completed and lost as soon as any
  /// task fails.
  RoundOutcome get outcome {
    if (tasks.isEmpty) return RoundOutcome.inProgress;
    if (tasks.any((t) => t.isFailed)) return RoundOutcome.lost;
    if (tasks.every((t) => t.isCompleted)) return RoundOutcome.won;
    return RoundOutcome.inProgress;
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

  /// Whether [playerIndex] may take [task].
  bool canTake(Task task, int playerIndex) =>
      whyCantTake(task, playerIndex) == null;

  /// Why [seat] can't take [task], or null if they can.
  /// With [publicOnly], nobody's hand is consulted: only what the whole
  /// table can see.
  String? whyCantTake(Task task, int seat, {bool publicOnly = false}) {
    if (seat == exiledSeat) return 'Exiled: no tasks this round';
    if (task.kingCantTake && seat == kingIndex) {
      return "The King can't take this task";
    }
    // Someone can't hold two tasks that work against each other.
    for (final o in tasks) {
      if (o != task &&
          o.assignedPlayerIndex == seat &&
          selfClash(o.description, task.description, players: players.length)) {
        return 'That clashes with a task they already hold';
      }
    }
    // On screen the app knows every hand: no task someone's cards make
    // impossible for them (unless nobody else could take it either).
    final m = cards;
    if (!publicOnly && m != null && m.dealId == dealId && seat < m.hands.length) {
      final why = handBlocks(task.description, m.hands[seat]);
      if (why != null) {
        final someoneElse = [
          for (int s = 0; s < players.length && s < m.hands.length; s++)
            if (s != seat &&
                s != exiledSeat &&
                !(task.kingCantTake && s == kingIndex) &&
                handBlocks(task.description, m.hands[s]) == null)
              s
        ].isNotEmpty;
        if (someoneElse) return why;
      }
    }
    return null;
  }

  /// Whether [seat] may reveal a card right now, given the decree.
  /// Late Counsel holds every card back until three tricks have been
  /// played (on screen, where the app sees the tricks; at a real table the
  /// players keep to it themselves).
  bool canSpeak(int seat) => switch (decree) {
        Decree.silence => false,
        Decree.lateCounsel =>
          !digital || (cards != null && cards!.dealId == dealId && cards!.tricks.length >= 3),
        _ => true,
      };

  /// Why no card may be shown now, or null if one may.
  String? whyCantSpeak() => switch (decree) {
        Decree.silence => 'Silence is decreed: no cards may be shown this round',
        Decree.lateCounsel when !canSpeak(0) =>
          'Late Counsel: no cards may be shown until three tricks have been played',
        _ => null,
      };

  /// Why completing [task] now would break the seal order, or null if it's
  /// fine. Completing a task out of order fails the round.
  String? sealProblem(Task task) {
    final seal = task.seal;
    if (seal == null) return null;
    if (seal == Seals.last) {
      final open = tasks.where((t) => t != task && !t.isCompleted);
      return open.isEmpty
          ? null
          : 'The Ω seal must be the last task done, and ${open.length} '
              'other task${open.length == 1 ? ' is' : 's are'} still open.';
    }
    final earlier = tasks.where((t) =>
        t.seal != null && t.seal != Seals.last && t.seal! < seal && !t.isCompleted);
    if (earlier.isEmpty) return null;
    final first = earlier.map((t) => t.seal!).reduce(min);
    return 'Seal ${Seals.label(first)} must be done before seal ${Seals.label(seal)}.';
  }

  /// Crowns the King, who picks the first task.
  void setKing(int? index) {
    kingIndex = index;
    _chooseExile();
    assignForced();
    // The King picks first, unless there's nothing they're allowed to take.
    final loose = tasks.where((t) => t.assignedPlayerIndex == null);
    pickTurn = loose.isEmpty || index == null
        ? null
        : loose.any((t) => canTake(t, index))
            ? index
            : _nextPicker(index);
    for (final t in tasks) {
      if (t.assignedPlayerIndex != null && !canTake(t, t.assignedPlayerIndex!)) {
        t.assignedPlayerIndex = null;
      }
    }
  }

  /// Gives [task] to [seat] (or takes it back with null). Picking moves on
  /// clockwise each time a loose task is taken. Returns true when this was
  /// the last task to be taken, so play can begin.
  bool assign(Task task, int? seat) {
    final wasLoose = task.assignedPlayerIndex == null;
    if (seat != null && wasLoose) picksMade++;
    task.assignedPlayerIndex = seat;
    if (seat != null) assignForced();
    final allTaken = tasks.every((t) => t.assignedPlayerIndex != null);
    if (allTaken) {
      final justFinished = pickTurn != null;
      pickTurn = null;
      return justFinished;
    }
    if (decree == Decree.kingsCommand) {
      pickTurn = kingIndex; // the King hands out every task
    } else if (seat != null && wasLoose && pickTurn != null) {
      pickTurn = _nextPicker(pickTurn!);
    } else if (pickTurn == null && kingIndex != null) {
      // A task was handed back after picking finished: picking resumes.
      pickTurn = seat == null ? kingIndex : pickTurn;
    }
    return false;
  }

  /// Tasks taken by a pick this round (not counting ones that went
  /// straight to the only player who could take them).
  int picksMade = 0;

  /// A task only one player can take goes straight to them.
  void assignForced() {
    if (kingIndex == null) return;
    var changed = true;
    while (changed) {
      changed = false;
      for (final t in tasks) {
        if (t.assignedPlayerIndex != null) continue;
        final able = [
          for (int s = 0; s < players.length; s++)
            if (canTake(t, s)) s
        ];
        if (able.length == 1) {
          t.assignedPlayerIndex = able.single;
          changed = true;
        }
      }
    }
    if (tasks.every((t) => t.assignedPlayerIndex != null)) pickTurn = null;
  }

  void toggleSpoke(int seat) => spoke[seat] = !spoke[seat];

  void _resetRoundCounters() {
    picksMade = 0;
    spoke = List.filled(players.length, false);
    pickTurn = null;
    passed = {};
  }

  /// Whether [seat] may pass on picking a task right now: it's their turn,
  /// they haven't passed this round, and someone else could pick instead.
  bool canPass(int seat) =>
      pickTurn == seat &&
      !isTutorial &&
      decree != Decree.kingsCommand &&
      !passed.contains(seat) &&
      tasks.any((t) => t.assignedPlayerIndex == null) &&
      _nextPicker(seat) != seat;

  /// [seat] passes: the pick moves on clockwise.
  void pass(int seat) {
    if (!canPass(seat)) return;
    passed.add(seat);
    pickTurn = _nextPicker(seat);
  }

  /// Replays the same tasks in a new round: clears results and assignments.
  void retryRound() {
    tasks = tasks.map((t) => t.freshCopy()).toList();
    kingIndex = null;
    exiledSeat = null;
    roundNumber++;
    dealId++;
    _resultRecorded = false;
    _resetRoundCounters();
  }

  /// Draws a new set of tasks. Starts a new round unless the current round
  /// is still in progress (shuffling mid-round replaces this round's tasks
  /// and the King picks first again).
  void shuffleTasks(int playerCount, int targetPoints) {
    final finished = tasks.isEmpty || outcome != RoundOutcome.inProgress;
    final king = kingIndex;
    final exiled = exiledSeat;
    final keepDecree = decree;
    addTasksUntilTarget(playerCount, targetPoints, newRound: finished);
    if (!finished) {
      roundNumber--; // same round, new tasks
      decree = keepDecree;
      kingIndex = king;
      exiledSeat = exiled;
      pickTurn = king;
    }
  }

  /// Draws random tasks (no repeats) whose points add up to [targetPoints]
  /// for the given player count, or as close as the pool allows.
  ///
  /// A new round also settles its seals and decree: a Chronicle chapter
  /// fixes them; with [surprise] on they're rolled at random.
  void addTasksUntilTarget(int playerCount, int targetPoints,
      {bool newRound = true, bool countRound = true}) {
    tasks.clear();
    kingIndex = null;
    exiledSeat = null;
    if (countRound) roundNumber++;
    dealId++;
    _resultRecorded = false;
    _resetRoundCounters();
    final rand = dealRandom(1);
    // The tutorial sets its own tasks, with no seals or decrees.
    if (isTutorial) {
      sealCount = 0;
      decree = null;
      final lessonTasks = lessons[max(0, min(lesson, lessons.length - 1))].tasks;
      tasks.addAll([
        for (final d in lessonTasks)
          taskPool.firstWhere((t) => t.description == d).freshCopy()..seal = null
      ]);
      return;
    }
    if (newRound) {
      if (mode == GameMode.chronicle && chapter != null) {
        sealCount = chronicle[chapter!].seals;
        decree = chronicle[chapter!].decree;
      } else if (surprise) {
        sealCount = const [0, 0, 2, 3][rand.nextInt(4)];
        decree = rand.nextBool()
            ? Decree.values[rand.nextInt(Decree.values.length)]
            : null;
      } else {
        sealCount = 0;
        decree = null;
      }
      if (decree == Decree.exile && playerCount < 3) decree = Decree.silence;
    }
    // Draw the tasks, and if the round has seals, try a few draws for
    // enough tasks a seal can sit on.
    var best = const <Task>[];
    var bestFree = -1;
    for (var attempt = 0; attempt < 12; attempt++) {
      final drawn = _drawTasks(playerCount, targetPoints, rand);
      final free = drawn.where(_sealable).length;
      if (free > bestFree) {
        best = drawn;
        bestFree = free;
      }
      if (sealCount < 2 || free >= sealCount) break;
    }
    tasks.addAll(best);
    _placeSeals(rand);
  }

  /// A seal orders tasks by when they're done, so it only goes on a task
  /// that can be done on any trick (see [TaskTiming]).
  static bool _sealable(Task t) =>
      timingOf(t.description) == TaskTiming.anyTrick;

  List<Task> _drawTasks(int playerCount, int targetPoints, Random rand) {
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
      drawn.add(task.freshCopy()..seal = null);
      currentTotal += points;
    }
    return drawn;
  }

  /// Puts [sealCount] seals on tasks that can take them. A single seal
  /// orders nothing, so a round has two or none. The Ω seal must be the
  /// last task done, so it's only used when no other task waits for the
  /// round to end; otherwise the seals are all numbered.
  void _placeSeals(Random rand) {
    final free = tasks.where(_sealable).toList()..shuffle(rand);
    final count = min(sealCount, free.length);
    if (count < 2) return;
    final othersWait = tasks.any((t) =>
        !free.take(count).contains(t) &&
        timingOf(t.description) == TaskTiming.end);
    final seals = othersWait
        ? [for (int i = 1; i <= count; i++) i]
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
        'tasks': [
          for (final t in tasks)
            {
              'description': t.description,
              'status': t.status.index,
              'owner': t.assignedPlayerIndex,
              'seal': t.seal,
            },
        ],
        'king': kingIndex,
        'round': roundNumber,
        'wins': wins,
        'losses': losses,
        'spoke': spoke,
        'passed': passed.toList(),
        'pickTurn': pickTurn,
        'mode': mode.index,
        'target': target,
        'chapter': chapter,
        'lesson': lesson,
        'surprise': surprise,
        'roles': roles,
        'cards': cards?.toJson(),
        'sealCount': sealCount,
        'decree': decree?.index,
        'exiled': exiledSeat,
        'courtiers': [for (final c in courtiers) c.index],
        'streak': streak,
        'bestStreak': bestStreak,
        'dealId': dealId,
        'seed': seed,
        'resultRecorded': _resultRecorded,
      };

  /// Rebuilds a saved game. Returns null if the save can't be read (for
  /// example after the task list changed in an update).
  static GameState? fromJson(Map<String, dynamic> j) {
    try {
      final byDescription = {for (final t in taskPool) t.description: t};
      final g = GameState()
        ..players = [
          for (final p in (j['players'] as List<dynamic>).cast<Map<String, dynamic>>())
            Player(p['name'] as String, colorValue: p['color'] as int),
        ]
        ..tasks = [
          for (final t in (j['tasks'] as List<dynamic>).cast<Map<String, dynamic>>())
            byDescription[renamedTasks[t['description'] as String] ??
                    t['description'] as String]!
                .freshCopy()
              ..status = TaskStatus.values[t['status'] as int]
              ..assignedPlayerIndex = t['owner'] as int?
              ..seal = t['seal'] as int?,
        ]
        ..kingIndex = j['king'] as int?
        ..roundNumber = j['round'] as int
        ..wins = j['wins'] as int
        ..losses = j['losses'] as int
        ..spoke = List<bool>.from(j['spoke'] as List)
        ..passed = {for (final s in (j['passed'] as List?) ?? const []) s as int}
        ..pickTurn = j['pickTurn'] as int?
        ..mode = GameMode.values[(j['mode'] as int?) ?? 0]
        ..target = (j['target'] as int?) ?? 5
        ..chapter = j['chapter'] as int?
        ..lesson = (j['lesson'] as int?) ?? 0
        ..surprise = (j['surprise'] as bool?) ?? false
        ..roles = (j['roles'] as bool?) ?? true
        ..cards = j['cards'] == null
            ? null
            : MatchState.fromJson(Map<String, dynamic>.from(j['cards'] as Map))
        ..sealCount = (j['sealCount'] as int?) ?? 0
        ..decree = j['decree'] == null ? null : Decree.values[j['decree'] as int]
        ..exiledSeat = j['exiled'] as int?
        ..courtiers = [
          for (final c in (j['courtiers'] as List?) ?? const [])
            Courtier.values[c as int]
        ]
        ..streak = j['streak'] as int
        ..bestStreak = j['bestStreak'] as int
        ..dealId = j['dealId'] as int;
      if (j['seed'] is int) g.seed = j['seed'] as int;
      g._resultRecorded = j['resultRecorded'] as bool;
      if (g.players.isEmpty || g.tasks.isEmpty) return null;
      // A game of the old Dynasty: its story no longer loads.
      if (g.isDynasty) return null;
      if (g.courtiers.length != g.players.length) g.seatCourtiers();
      return g;
    } catch (_) {
      return null;
    }
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
