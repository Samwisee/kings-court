/// One round of the court: the deal, the tasks and who holds them, the
/// tricks, and how it ended. The one record of a round, for the table on
/// screen, the phone at a real table (where there are no cards to deal)
/// and the bots alike. Plain data that saves to JSON.
///
/// Everything a player does to a round is a [MatchAction], applied by
/// [Round.apply]; [Round.problem] says why one isn't allowed. That is the
/// shape online play needs: each player sends actions, one place applies
/// them in order, and every device holds the same round.
library;

import 'dart:math';

import '../task_help.dart';
import '../tasks.dart';
import 'cards.dart';
import 'conflicts.dart';
import 'deal_mix.dart';
import 'decrees.dart';
import 'rules.dart';
import 'task.dart';

enum Phase { picking, announcing, playing, roundOver }

enum RoundOutcome { inProgress, won, lost }

/// A task on the table this round: who holds it, and how it's going.
class RoundTask {
  RoundTask(this.task,
      {this.owner,
      this.x,
      this.seal,
      this.status = TaskStatus.pending,
      this.whyFailed});
  final Task task;

  /// The seat holding it, once taken.
  int? owner;

  /// The number announced for "exactly X tricks" tasks.
  int? x;

  /// Wax seal fixing when it must be done (see [Seals]).
  int? seal;

  TaskStatus status;

  /// Why it failed, for the end of the round.
  String? whyFailed;

  String get description => task.description;
  String cardText(int playerCount) => task.cardText(playerCount);
  String boardText(int playerCount) => task.boardText(playerCount);
  String fullText(int playerCount) => task.fullText(playerCount);
  int points(int playerCount) => task.getPointsForPlayerCount(playerCount);
  bool get kingCantTake => task.kingCantTake;
  bool get noCourtCards => task.noCourtCards;
  List<String> get notes => task.notes;
  bool get hasNotes => task.hasNotes;
  bool get isPending => status == TaskStatus.pending;
  bool get isCompleted => status == TaskStatus.completed;
  bool get isFailed => status == TaskStatus.failed;

  Map<String, dynamic> toJson() => {
        'd': description,
        'owner': owner,
        'x': x,
        'seal': seal,
        'status': status.index,
        if (whyFailed != null) 'why': whyFailed,
      };

  /// Reads a saved task; also the older shape (`verdict` for the status,
  /// `description` for the words).
  static RoundTask fromJson(Map<String, dynamic> j) {
    final name = (j['d'] ?? j['description']) as String;
    final task = taskByDescription(renamedTasks[name] ?? name);
    final status = j['status'] != null
        ? TaskStatus.values[j['status'] as int]
        : j['verdict'] != null
            ? const [TaskStatus.pending, TaskStatus.completed, TaskStatus.failed][
                j['verdict'] as int]
            : TaskStatus.pending;
    return RoundTask(task,
        owner: j['owner'] as int?,
        x: j['x'] as int?,
        seal: j['seal'] as int?,
        status: status,
        whyFailed: j['why'] as String?);
  }
}

/// How a round ended, for the mode that played it and the outcome card:
/// won or lost, each task as it finished (its owner, status and why it
/// failed), the King and the tricks played.
class RoundResult {
  const RoundResult(
      {required this.won,
      required this.tasks,
      required this.king,
      required this.tricksPlayed,
      required this.target});
  final bool won;
  final List<RoundTask> tasks;
  final int? king;
  final int tricksPlayed;

  /// The points the tasks were drawn to.
  final int target;

  Iterable<RoundTask> get failed => tasks.where((t) => t.isFailed);
}

/// A task the tricks have settled: done, or failed and why.
class TaskFlip {
  const TaskFlip(this.task, this.status, {this.why});
  final RoundTask task;
  final TaskStatus status;
  final String? why;
}

/// Something a player does at the table, as plain data: it turns into
/// JSON and back, so it can travel to every device at the table. The
/// moves within a round's play are [MatchAction]s; the rest (crowning,
/// marking a task at a real table, the next round) are the game's
/// (game/actions.dart).
abstract class Action {
  const Action();

  /// The seat making the move.
  int get seat;

  Map<String, dynamic> toJson();
}

/// A move within a round's play.
sealed class MatchAction extends Action {
  const MatchAction(this.seat);
  @override
  final int seat;

  /// The move [j] encodes, or null if it isn't one of these.
  static MatchAction? fromJson(Map<String, dynamic> j) => switch (j['type']) {
        'pick' => PickTask(j['seat'] as int, j['task'] as int),
        'announce' =>
          Announce(j['seat'] as int, j['task'] as int, j['x'] as int),
        'show' => ShowCard(j['seat'] as int, PlayingCard.fromId(j['card'] as int)),
        'pass' => Pass(j['seat'] as int),
        'play' => PlayCard(j['seat'] as int, PlayingCard.fromId(j['card'] as int)),
        'return' => ReturnTask(j['seat'] as int, j['task'] as int),
        _ => null,
      };
}

/// Passing on a pick: the turn to take a task moves on.
class Pass extends MatchAction {
  const Pass(super.seat);
  @override
  Map<String, dynamic> toJson() => {'type': 'pass', 'seat': seat};
}

/// Task [task] goes to [seat]: their own pick, or one the King hands out
/// under the King's Command. At a real table, where the phone only keeps
/// the tasks, a task may also be moved from one seat to another.
class PickTask extends MatchAction {
  const PickTask(super.seat, this.task);
  final int task;
  @override
  Map<String, dynamic> toJson() => {'type': 'pick', 'seat': seat, 'task': task};
}

/// Task [task] put back on the table by whoever held it (a real table).
class ReturnTask extends MatchAction {
  const ReturnTask(super.seat, this.task);
  final int task;
  @override
  Map<String, dynamic> toJson() => {'type': 'return', 'seat': seat, 'task': task};
}

class Announce extends MatchAction {
  const Announce(super.seat, this.task, this.x);
  final int task;
  final int x;
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'announce', 'seat': seat, 'task': task, 'x': x};
}

class PlayCard extends MatchAction {
  const PlayCard(super.seat, this.card);
  final PlayingCard card;
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'play', 'seat': seat, 'card': card.id};
}

/// Showing a card: a player's highest, lowest or only card of a suit,
/// face up in their hand until played.
class ShowCard extends MatchAction {
  const ShowCard(super.seat, this.card);
  final PlayingCard card;
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'show', 'seat': seat, 'card': card.id};
}

class Round {
  Round({required this.players, required this.target, this.dealId = 0})
      : spoke = List.filled(players, false),
        names = [for (var i = 0; i < players; i++) 'Player ${i + 1}'];

  final int players;
  int target;

  /// Which deal of the game this is (the game's dealId).
  int dealId;

  // ------------------------------------------------------------ the deal

  /// Everyone's cards. Empty at a real table, where the phone only keeps
  /// the tasks.
  List<List<PlayingCard>> hands = [];
  List<PlayingCard> setAside = [];
  bool get hasCards => hands.isNotEmpty;

  /// The seat holding the King card, once crowned.
  int? king;

  // ----------------------------------------------------------- the tasks

  List<RoundTask> tasks = [];

  /// Whose turn it is to pick a task, or null once every task has an owner.
  int? pickTurn;

  /// Seats that have passed on taking a task this round. Each player may
  /// pass once a round, handing the pick to the next player.
  Set<int> passed = {};

  /// Whether each seat has used their once-per-round card reveal.
  List<bool> spoke;

  /// Tasks taken by a pick this round (not counting ones that went
  /// straight to the only player who could take them).
  int picksMade = 0;

  /// Seals in this round, the decree in force, and the exiled seat.
  int sealCount = 0;
  Decree? decree;
  int? exiledSeat;

  /// Whether anyone may pass on a pick this round (the tutorial's lessons
  /// walk through every pick, so there nobody does).
  bool passing = true;

  /// The players' names, for the wording of a failed task ("Player 2 won
  /// the 3♥"). Not saved: the game sets them.
  List<String> names;

  // ---------------------------------------------------------- the tricks

  List<Trick> tricks = [];

  /// The trick being played: who led, and the cards so far.
  int leader = 0;
  List<int> currentSeats = [];
  List<PlayingCard> current = [];

  Phase phase = Phase.picking;

  /// Cards shown with the speech token this round: seat to card, what was
  /// said about it ("highest", "lowest" or "only"), and how many tricks
  /// had been played when it was shown.
  Map<int, PlayingCard> revealed = {};
  Map<int, String> revealHint = {};
  Map<int, int> revealedAt = {};

  // ------------------------------------------------------------- queries

  /// A round is won when every task is completed and lost as soon as any
  /// task fails.
  RoundOutcome get outcome {
    if (tasks.isEmpty) return RoundOutcome.inProgress;
    if (tasks.any((t) => t.isFailed)) return RoundOutcome.lost;
    if (tasks.every((t) => t.isCompleted)) return RoundOutcome.won;
    return RoundOutcome.inProgress;
  }

  /// Won, lost, or null while the round is still going.
  bool? get won => switch (outcome) {
        RoundOutcome.inProgress => null,
        RoundOutcome.won => true,
        RoundOutcome.lost => false,
      };

  /// How the round ended, once it has.
  RoundResult? get result => switch (won) {
        null => null,
        final won => RoundResult(
            won: won,
            tasks: List.unmodifiable(tasks),
            king: king,
            tricksPlayed: tricks.length,
            target: target),
      };

  /// Every task has an owner.
  bool get allTaken => tasks.every((t) => t.owner != null);

  /// Every task has an owner and every "exactly X" number is announced.
  bool get settled =>
      allTaken && tasks.every((t) => !needsX(t.description) || t.x != null);

  /// The numbers announced for "exactly X" tasks, by task wording.
  Map<String, int> get announced =>
      {for (final t in tasks) if (t.x != null) t.description: t.x!};

  int get totalTricks => handSize(players);

  /// The cards dealt this round: the deck less any set aside. Worked out
  /// once per deal (it's asked for in every playout and every deal check).
  Set<PlayingCard> get inPlay {
    if (!identical(_inPlayFor, setAside)) {
      _inPlayFor = setAside;
      _inPlay = fullDeck().where((c) => !setAside.contains(c)).toSet();
    }
    return _inPlay!;
  }

  Set<PlayingCard>? _inPlay;
  List<PlayingCard>? _inPlayFor;

  /// Whose turn it is to play a card.
  int get turn =>
      current.isEmpty ? leader : (currentSeats.last + 1) % players;

  PlayingCard? get led => current.isEmpty ? null : current.first;

  List<PlayingCard> legalFor(int seat) => legalPlays(hands[seat], led);

  int tricksWon(int seat) => tricks.where((t) => t.winner == seat).length;

  /// The tricks so far, as the task rules see them.
  RoundView get view => RoundView(
      players: players,
      king: king ?? leader,
      tricks: tricks,
      totalTricks: totalTricks,
      inPlay: inPlay,
      shown: revealed,
      shownAt: revealedAt);

  /// What may be said about [card] in [seat]'s hand, or null if it can't
  /// be shown (Court Cards, or a card in the middle of its suit).
  String? revealFor(int seat, PlayingCard card) {
    if (card.isCourt || !hands[seat].contains(card)) return null;
    final suit = hands[seat].where((c) => c.suit == card.suit).toList();
    if (suit.length == 1) return 'only';
    final ranks = suit.map((c) => c.rank);
    if (card.rank == ranks.reduce((a, b) => a > b ? a : b)) return 'highest';
    if (card.rank == ranks.reduce((a, b) => a < b ? a : b)) return 'lowest';
    return null;
  }

  /// Whether [seat] may take task [i], which nobody holds yet.
  bool canTake(int i, int seat) =>
      tasks[i].owner == null && whyCantTake(tasks[i], seat) == null;

  /// Whether [seat] may hold [t] (taken or not).
  bool mayTake(RoundTask t, int seat) => whyCantTake(t, seat) == null;

  /// Why [seat] can't hold [t], or null if they can. With [publicOnly],
  /// nobody's hand is consulted: only what the whole table can see.
  String? whyCantTake(RoundTask t, int seat, {bool publicOnly = false}) {
    if (seat == exiledSeat) return 'Exiled: no tasks this round';
    if (t.task.kingCantTake && seat == king) {
      return "The King can't take this task";
    }
    // Someone can't hold two tasks that work against each other.
    for (final o in tasks) {
      if (o != t &&
          o.owner == seat &&
          selfClash(o.description, t.description, players: players)) {
        return 'That clashes with a task they already hold';
      }
    }
    // On screen the app knows every hand: no task someone's cards make
    // impossible for them (unless nobody else could take it either).
    if (!publicOnly && hasCards && seat < hands.length) {
      final why = handBlocks(t.description, hands[seat]);
      if (why != null) {
        final someoneElse = [
          for (var s = 0; s < players && s < hands.length; s++)
            if (s != seat &&
                s != exiledSeat &&
                !(t.task.kingCantTake && s == king) &&
                handBlocks(t.description, hands[s]) == null)
              s
        ].isNotEmpty;
        if (someoneElse) return why;
      }
    }
    return null;
  }

  /// Whether [seat] may reveal a card right now, given the decree. Late
  /// Counsel holds every card back until three tricks have been played
  /// (on screen, where the app sees the tricks; at a real table the
  /// players keep to it themselves).
  bool canSpeak(int seat) => switch (decree) {
        Decree.silence => false,
        Decree.lateCounsel => !hasCards || tricks.length >= 3,
        _ => true,
      };

  /// Why no card may be shown now, or null if one may.
  String? whyCantSpeak() => switch (decree) {
        Decree.silence => 'Silence is decreed: no cards may be shown this round',
        Decree.lateCounsel when !canSpeak(0) =>
          'Late Counsel: no cards may be shown until three tricks have been played',
        _ => null,
      };

  /// Why completing [t] now would break the seal order, or null if it's
  /// fine. Completing a task out of order fails the round.
  String? sealProblem(RoundTask t) {
    final seal = t.seal;
    if (seal == null) return null;
    if (seal == Seals.last) {
      final open = tasks.where((o) => o != t && !o.isCompleted);
      return open.isEmpty
          ? null
          : 'The Ω seal must be the last task done, and ${open.length} '
              'other task${open.length == 1 ? ' is' : 's are'} still open.';
    }
    final earlier = tasks.where((o) =>
        o.seal != null && o.seal != Seals.last && o.seal! < seal && !o.isCompleted);
    if (earlier.isEmpty) return null;
    final first = earlier.map((o) => o.seal!).reduce(min);
    return 'Seal ${Seals.label(first)} must be done before seal ${Seals.label(seal)}.';
  }

  /// Whether [seat] may pass on picking a task right now: the round allows
  /// it, it's their turn, they haven't passed this round, and someone else
  /// could pick instead.
  bool canPass(int seat) =>
      passing &&
      pickTurn == seat &&
      decree != Decree.kingsCommand &&
      !passed.contains(seat) &&
      tasks.any((t) => t.owner == null) &&
      nextPicker(seat) != seat;

  /// The next seat clockwise after [from] that may pick a task: skipping
  /// anyone who can't take any of the tasks left, then anyone exiled.
  int? nextPicker(int from) {
    for (var step = 1; step <= players; step++) {
      final seat = (from + step) % players;
      if (seat != exiledSeat &&
          tasks.any((t) => t.owner == null && whyCantTake(t, seat) == null)) {
        return seat;
      }
    }
    for (var step = 1; step <= players; step++) {
      final seat = (from + step) % players;
      if (seat != exiledSeat) return seat;
    }
    return null;
  }

  // ------------------------------------------------------------- changes

  /// Crowns [seat] the King (or uncrowns with null): the exile is chosen
  /// with [rand], tasks only one player may take go to them, and the King
  /// picks first unless there's nothing they're allowed to take.
  void crown(int? seat, Random rand) {
    king = seat;
    chooseExile(rand);
    assignForced();
    final loose = tasks.where((t) => t.owner == null);
    pickTurn = loose.isEmpty || seat == null
        ? null
        : loose.any((t) => whyCantTake(t, seat) == null)
            ? seat
            : nextPicker(seat);
    for (final t in tasks) {
      if (t.owner != null && !mayTake(t, t.owner!)) t.owner = null;
    }
    if (seat != null) leader = seat;
    _settle();
  }

  /// Under Exile, banishes someone other than the King.
  void chooseExile(Random rand) {
    exiledSeat = null;
    final k = king;
    if (k != null && decree == Decree.exile && players >= 3) {
      final others = [for (var i = 0; i < players; i++) if (i != k) i];
      if (others.isNotEmpty) exiledSeat = others[rand.nextInt(others.length)];
    }
  }

  /// Gives [t] to [seat] (or takes it back with null). Picking moves on
  /// clockwise each time a loose task is taken. Returns true when this was
  /// the last task to be taken, so play can begin.
  bool assign(RoundTask t, int? seat) {
    final wasLoose = t.owner == null;
    if (seat != null && wasLoose) picksMade++;
    t.owner = seat;
    if (seat != null) assignForced();
    if (allTaken) {
      final justFinished = pickTurn != null;
      pickTurn = null;
      _settle();
      return justFinished;
    }
    if (decree == Decree.kingsCommand) {
      pickTurn = king; // the King hands out every task
    } else if (seat != null && wasLoose && pickTurn != null) {
      pickTurn = nextPicker(pickTurn!);
    } else if (pickTurn == null && king != null) {
      // A task was handed back after picking finished: picking resumes.
      pickTurn = seat == null ? king : pickTurn;
    }
    _settle();
    return false;
  }

  /// A task only one player can take goes straight to them.
  void assignForced() {
    if (king == null) return;
    var changed = true;
    while (changed) {
      changed = false;
      for (final t in tasks) {
        if (t.owner != null) continue;
        final able = [
          for (var s = 0; s < players; s++)
            if (whyCantTake(t, s) == null) s
        ];
        if (able.length == 1) {
          t.owner = able.single;
          changed = true;
        }
      }
    }
    if (allTaken) pickTurn = null;
  }

  /// [seat] passes: the pick moves on clockwise.
  void pass(int seat) {
    if (!canPass(seat)) return;
    passed.add(seat);
    pickTurn = nextPicker(seat);
  }

  void toggleSpoke(int seat) => spoke[seat] = !spoke[seat];

  /// Marks a task by hand (a real table): done, failed, or back to pending
  /// when the same mark is chosen again.
  void mark(RoundTask t, TaskStatus status) {
    t.status = t.status == status ? TaskStatus.pending : status;
    if (t.status != TaskStatus.failed) t.whyFailed = null;
    _settle();
  }

  /// The tasks the tricks so far have settled, in the order they turn
  /// over: sealed tasks by their seal, and nothing after the one that lost
  /// the round. Nothing is changed; [flip] applies each.
  List<TaskFlip> judge() {
    final v = view;
    int order(RoundTask t) => t.seal ?? 0;
    final pending = tasks.where((t) => t.isPending && t.owner != null).toList()
      ..sort((a, b) => order(a).compareTo(order(b)));
    final flips = <TaskFlip>[];
    final tried = <RoundTask>[];
    for (final t in pending) {
      final verdict = taskRules[t.description]!(v, t.owner!, t.x);
      if (verdict == Verdict.pending) continue;
      final problem = sealProblem(t);
      if (verdict == Verdict.done && problem == null) {
        flips.add(TaskFlip(t, TaskStatus.completed));
        // Doing one task may settle a seal for the next.
        t.status = TaskStatus.completed;
        tried.add(t);
        continue;
      }
      flips.add(TaskFlip(t, TaskStatus.failed,
          why: verdict == Verdict.done
              ? 'Done out of order: $problem'
              : failReason(t.description, v, t.owner!, t.x, names)));
      break;
    }
    for (final t in tried) {
      t.status = TaskStatus.pending;
    }
    return flips;
  }

  /// Turns a task over as the judge decided.
  void flip(TaskFlip f) {
    f.task.status = f.status;
    f.task.whyFailed = f.why;
    _settle();
  }

  /// Sets [phase] from where the round has got to.
  void _settle() {
    if (outcome != RoundOutcome.inProgress || (hasCards && view.over)) {
      phase = Phase.roundOver;
    } else if (!allTaken) {
      phase = Phase.picking;
    } else if (!settled) {
      phase = Phase.announcing;
    } else {
      phase = Phase.playing;
    }
  }

  /// Announces [x] tricks for task [i].
  void announce(int i, int x) {
    tasks[i].x = x;
    _settle();
  }

  /// Whether every open task is done with cards still in hand, so a table
  /// can play the rest of the round out by itself. A round that merely
  /// can't be lost is still played to the end by hand, and sealed tasks
  /// hang on their order, so those rounds play on too.
  bool get canPlayOut {
    if (!hasCards || current.isNotEmpty || tricks.length >= totalTricks) return false;
    final open = tasks.where((t) => t.isPending && t.owner != null).toList();
    if (open.isEmpty || open.any((t) => t.seal != null)) return false;
    final v = view;
    return open.every((t) => taskRules[t.description]!(v, t.owner!, t.x) == Verdict.done);
  }

  // --------------------------------------------------------------- rounds

  /// Deals a new round and draws tasks worth [target] points (the balance
  /// and benchmark tools' rounds, played by bots alone).
  void newRound(Random rand) {
    final d = deal(players, rand);
    hands = d.hands;
    setAside = d.setAside;
    king = hands.indexWhere((h) => h.contains(PlayingCard.king));
    tricks = [];
    current = [];
    currentSeats = [];
    leader = king!;
    tasks = _drawTasks(rand);
    pickTurn = king;
    phase = Phase.picking;
  }

  List<RoundTask> _drawTasks(Random rand) {
    final inPlay = this.inPlay;
    final pool = drawOrder(allTasks, rand,
        description: (t) => t.description,
        points: (t) => t.getPointsForPlayerCount(players),
        target: target);
    final drawn = <RoundTask>[];
    var total = 0;
    for (final t in pool) {
      if (total >= target) break;
      final points = t.getPointsForPlayerCount(players);
      if (total + points > target) continue;
      if (!taskRules.containsKey(t.description)) continue;
      if (!playableWith(t.description, hands, inPlay)) continue;
      if (!fitsDeal([for (final d in drawn) d.description], t.description,
          players < 3 ? 3 : players)) {
        continue;
      }
      drawn.add(RoundTask(t));
      total += points;
    }
    return drawn;
  }

  /// Who holds the King card, once the cards are dealt: the table crowns
  /// them (see [crown]).
  int? get kingCardHolder {
    final holder = hands.indexWhere((h) => h.contains(PlayingCard.king));
    return holder < 0 ? null : holder;
  }

  /// Deals the cards for a table game. [accept] can refuse a deal (say,
  /// one that makes a task impossible); [king] keeps a reigning King, who
  /// takes the King card into their hand. Otherwise the round stays
  /// uncrowned until the table crowns the card's holder, who leads
  /// meanwhile.
  void dealFor(int dealId, Random rand,
      {int? king,
      bool Function(List<List<PlayingCard>> hands, Set<PlayingCard> inPlay)?
          accept}) {
    this.dealId = dealId;
    for (var attempt = 0; attempt < 80; attempt++) {
      final d = deal(players, rand);
      hands = d.hands;
      setAside = d.setAside;
      if (accept == null || accept(hands, inPlay)) break;
    }
    var holder = kingCardHolder!;
    if (king != null && king != holder) {
      // The King card goes to the King; a card of theirs goes the other way.
      final swap = hands[king][rand.nextInt(hands[king].length)];
      hands[king].remove(swap);
      hands[holder].remove(PlayingCard.king);
      hands[king].add(PlayingCard.king);
      hands[holder].add(swap);
      hands[king].sort();
      hands[holder].sort();
      holder = king;
    }
    if (king != null) this.king = king;
    leader = holder;
    tricks = [];
    current = [];
    currentSeats = [];
    revealed = {};
    revealHint = {};
    revealedAt = {};
    for (final t in tasks) {
      t.x = null;
    }
  }

  /// Plays a card with no checks beyond the rules of the trick. Returns the
  /// trick when this card finished one.
  Trick? playCard(int seat, PlayingCard card) {
    if (seat != turn || !legalFor(seat).contains(card)) return null;
    hands[seat].remove(card);
    currentSeats.add(seat);
    current.add(card);
    if (current.length < players) return null;
    final w = currentSeats[winningPlay(current)];
    final trick = Trick(leader, currentSeats, current, w);
    tricks.add(trick);
    current = [];
    currentSeats = [];
    leader = w;
    return trick;
  }

  // -------------------------------------------------------------- actions

  /// Why [a] isn't allowed right now, or null if it is.
  String? problem(MatchAction a) {
    switch (a) {
      case PickTask(:final seat, :final task):
        if (task < 0 || task >= tasks.length) return 'No such task';
        if (seat < 0 || seat >= players) return 'No such seat';
        if (!hasCards) {
          // A real table: the phone keeps the tasks as the players share
          // them out, and a task may move from seat to seat.
          if (outcome != RoundOutcome.inProgress) return 'The round is over';
          return whyCantTake(tasks[task], seat);
        }
        if (phase != Phase.picking) return 'Tasks are not being picked';
        if (tasks[task].owner != null) return 'That task is taken';
        // Under the King's Command the King hands every task out.
        final kingsCommand = decree == Decree.kingsCommand && pickTurn == king;
        if (seat != pickTurn && !kingsCommand) return 'Not your turn to pick';
        return whyCantTake(tasks[task], seat);
      case ReturnTask(:final task):
        if (task < 0 || task >= tasks.length) return 'No such task';
        if (hasCards) return 'Tasks stay with whoever took them';
        if (tasks[task].owner == null) return 'That task is on the table';
      case Pass(:final seat):
        if (phase != Phase.picking) return 'Tasks are not being picked';
        if (seat != pickTurn) return 'Not your turn to pick';
        if (!canPass(seat)) return 'No passing now';
      case Announce(:final seat, :final task, :final x):
        if (phase != Phase.announcing) return 'Nothing to announce';
        if (task < 0 || task >= tasks.length) return 'No such task';
        if (tasks[task].owner != seat) return 'Not your task';
        if (x < 0 || x > totalTricks) return 'Not a possible number';
      case ShowCard(:final seat, :final card):
        if (!hasCards || seat >= hands.length) return 'No cards to show';
        if (spoke[seat]) return 'That card reveal is used this round';
        if (!canSpeak(seat)) return whyCantSpeak() ?? 'No cards may be shown now';
        if (revealFor(seat, card) == null) return 'That card can’t be shown';
      case PlayCard(:final seat, :final card):
        if (phase != Phase.playing) return 'Not playing yet';
        if (seat != turn) return 'Not your turn';
        if (!legalFor(seat).contains(card)) {
          return 'You must follow ${led!.isCourt ? 'with a Court Card' : led!.suit.symbol}';
        }
    }
    return null;
  }

  /// Carries out [a], the one way a round's play moves on. Returns the
  /// finished trick when [a] completed one. The tasks are judged as the
  /// trick ends unless [judge] is off (a table that turns the cards over
  /// at its own pace judges with [Round.judge] and [flip]).
  Trick? apply(MatchAction a, {bool judge = true}) {
    final why = problem(a);
    if (why != null) throw StateError(why);
    switch (a) {
      case PickTask(:final seat, :final task):
        assign(tasks[task], seat);
        return null;
      case ReturnTask(:final task):
        assign(tasks[task], null);
        return null;
      case Pass(:final seat):
        pass(seat);
        _settle();
        return null;
      case Announce(:final task, :final x):
        announce(task, x);
        return null;
      case ShowCard(:final seat, :final card):
        revealHint[seat] = revealFor(seat, card)!;
        revealed[seat] = card;
        revealedAt[seat] = tricks.length;
        spoke[seat] = true; // the speech token is used
        return null;
      case PlayCard(:final seat, :final card):
        final trick = playCard(seat, card);
        if (trick != null && judge) _check();
        return trick;
    }
  }

  /// Marks tasks done or failed after a trick, and ends the round when one
  /// fails or every one is done.
  void _check() {
    for (final f in this.judge()) {
      flip(f);
    }
    _settle();
  }

  // --------------------------------------------------------------- views

  /// How many cards [seat] holds: counted from their hand, or, in a view
  /// where their hand is hidden, as told.
  int handSize(int seat) =>
      handSizes != null && hands[seat].isEmpty ? handSizes![seat] : hands[seat].length;

  /// In a view for one seat, how many cards each of the others holds.
  List<int>? handSizes;

  /// The round as [seat] may see it: their own hand, how many cards the
  /// others hold, and everything public. (The cards set aside stay, so
  /// every device judges the tasks alike; a server judging for everyone
  /// could withhold them.) What goes to a device at that seat.
  Round visibleTo(int seat) {
    final v = Round.fromJson(toJson())
      ..names = names
      ..handSizes = [for (final h in hands) h.length];
    for (var s = 0; s < v.hands.length; s++) {
      if (s != seat) v.hands[s] = [];
    }
    return v;
  }

  // --------------------------------------------------------------- saving

  Map<String, dynamic> toJson() => {
        'players': players,
        'target': target,
        'hands': [
          for (final h in hands) [for (final c in h) c.id]
        ],
        'setAside': [for (final c in setAside) c.id],
        'king': king,
        'tasks': [for (final t in tasks) t.toJson()],
        'pickTurn': pickTurn,
        'passed': passed.toList(),
        'spoke': spoke,
        'picksMade': picksMade,
        'sealCount': sealCount,
        'decree': decree?.index,
        'exiled': exiledSeat,
        'passing': passing,
        'tricks': [for (final t in tricks) t.toJson()],
        'leader': leader,
        'currentSeats': currentSeats,
        'current': [for (final c in current) c.id],
        'phase': phase.index,
        'dealId': dealId,
        'revealed': {for (final e in revealed.entries) '${e.key}': e.value.id},
        'revealHint': {for (final e in revealHint.entries) '${e.key}': e.value},
        'revealedAt': {for (final e in revealedAt.entries) '${e.key}': e.value},
        if (handSizes != null) 'handSizes': handSizes,
      };

  static Round fromJson(Map<String, dynamic> j) {
    List<PlayingCard> cards(List<dynamic> l) =>
        [for (final c in l) PlayingCard.fromId(c as int)];
    final players = j['players'] as int;
    final r = Round(players: players, target: j['target'] as int)
      ..hands = [for (final h in j['hands'] as List) cards(h as List)]
      ..setAside = cards(j['setAside'] as List)
      ..king = j['king'] as int?
      ..tasks = [
        for (final t in (j['tasks'] as List<dynamic>).cast<Map<String, dynamic>>())
          RoundTask.fromJson(t)
      ]
      ..pickTurn = j['pickTurn'] as int?
      ..passed = {for (final s in (j['passed'] as List?) ?? const []) s as int}
      ..picksMade = (j['picksMade'] as int?) ?? 0
      ..sealCount = (j['sealCount'] as int?) ?? 0
      ..decree = j['decree'] == null ? null : Decree.values[j['decree'] as int]
      ..exiledSeat = j['exiled'] as int?
      ..passing = (j['passing'] as bool?) ?? true
      ..tricks = [
        for (final t in j['tricks'] as List)
          Trick.fromJson(Map<String, dynamic>.from(t as Map))
      ]
      ..leader = j['leader'] as int
      ..currentSeats = List<int>.from(j['currentSeats'] as List)
      ..current = cards(j['current'] as List)
      ..phase = Phase.values[j['phase'] as int]
      ..dealId = (j['dealId'] as int?) ?? -1
      ..revealed = {
        for (final e in ((j['revealed'] as Map?) ?? const {}).entries)
          int.parse(e.key as String): PlayingCard.fromId(e.value as int)
      }
      ..revealHint = {
        for (final e in ((j['revealHint'] as Map?) ?? const {}).entries)
          int.parse(e.key as String): e.value as String
      }
      ..revealedAt = {
        for (final e in ((j['revealedAt'] as Map?) ?? const {}).entries)
          int.parse(e.key as String): e.value as int
      };
    if (j['spoke'] case final List<dynamic> spoke when spoke.length == players) {
      r.spoke = List<bool>.from(spoke);
    }
    if (j['handSizes'] case final List<dynamic> sizes) {
      r.handSizes = List<int>.from(sizes);
    }
    // Older saves kept the announced numbers beside the tasks.
    for (final e in ((j['announced'] as Map?) ?? const {}).entries) {
      for (final t in r.tasks) {
        if (t.description == e.key) t.x = e.value as int;
      }
    }
    return r;
  }
}
