/// A game played with real cards on screen: the deal, picking tasks,
/// playing tricks and checking every task automatically.
///
/// Everything that changes the game is an [MatchAction], applied by
/// [MatchState.apply]. The state is plain data that saves to JSON. That
/// is the shape an online version needs: each player sends actions, one
/// place (later a Firebase backend) applies them in order, and every
/// device renders the same state.
library;

import 'dart:math';

import '../models.dart';
import 'cards.dart';
import 'conflicts.dart';
import 'rules.dart';

enum Phase { picking, announcing, playing, roundOver }

/// A task on the table in a card game.
class MatchTask {
  MatchTask(this.task, {this.owner, this.x, this.verdict = Verdict.pending});
  final Task task;
  int? owner;

  /// The number announced for "exactly X tricks" tasks.
  int? x;
  Verdict verdict;

  String get description => task.description;

  Map<String, dynamic> toJson() => {
        'd': description,
        'owner': owner,
        'x': x,
        'verdict': verdict.index,
      };
}

/// Something a player does.
sealed class MatchAction {
  const MatchAction(this.seat);
  final int seat;

  Map<String, dynamic> toJson();

  static MatchAction fromJson(Map<String, dynamic> j) => switch (j['type']) {
        'pick' => PickTask(j['seat'] as int, j['task'] as int),
        'announce' =>
          Announce(j['seat'] as int, j['task'] as int, j['x'] as int),
        _ => PlayCard(j['seat'] as int, PlayingCard.fromId(j['card'] as int)),
      };
}

class PickTask extends MatchAction {
  const PickTask(super.seat, this.task);
  final int task;
  @override
  Map<String, dynamic> toJson() => {'type': 'pick', 'seat': seat, 'task': task};
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

class MatchState {
  MatchState({required this.players, required this.target});

  final int players;
  int target;

  int round = 0;
  int wins = 0;
  int losses = 0;
  int streak = 0;

  List<List<PlayingCard>> hands = [];
  List<PlayingCard> setAside = [];
  int king = 0;
  List<MatchTask> tasks = [];

  /// Whose turn it is to pick a task.
  int? pickTurn;

  List<Trick> tricks = [];

  /// The trick being played: who led, and the cards so far.
  int leader = 0;
  List<int> currentSeats = [];
  List<PlayingCard> current = [];

  Phase phase = Phase.picking;
  bool? won;

  /// When the cards sit under a table game: which deal they belong to,
  /// any extra rule on who may take what (exile, traitors), and the
  /// numbers announced for "exactly X" tasks, by task.
  int dealId = -1;
  bool Function(int task, int seat)? takeRule;
  Map<String, int> announced = {};

  /// Cards shown with the speech token this round: seat to card, and what
  /// was said about it ("highest", "lowest" or "only").
  Map<int, PlayingCard> revealed = {};
  Map<int, String> revealHint = {};

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

  int get totalTricks => 40 ~/ players;

  Set<PlayingCard> get inPlay =>
      fullDeck().where((c) => !setAside.contains(c)).toSet();

  /// Whose turn it is to play a card.
  int get turn =>
      current.isEmpty ? leader : (currentSeats.last + 1) % players;

  PlayingCard? get led => current.isEmpty ? null : current.first;

  List<PlayingCard> legalFor(int seat) => legalPlays(hands[seat], led);

  bool canTake(int task, int seat) =>
      tasks[task].owner == null &&
      !(tasks[task].task.kingCantTake && seat == king) &&
      (takeRule?.call(task, seat) ?? true);

  int tricksWon(int seat) => tricks.where((t) => t.winner == seat).length;

  RoundView get view => RoundView(
      players: players,
      king: king,
      tricks: tricks,
      totalTricks: totalTricks,
      inPlay: inPlay);

  // --------------------------------------------------------------- rounds

  /// Deals a new round and draws tasks worth [target] points.
  void newRound(Random rand) {
    round++;
    final d = deal(players, rand);
    hands = d.hands;
    setAside = d.setAside;
    king = hands.indexWhere((h) => h.contains(PlayingCard.king));
    tricks = [];
    current = [];
    currentSeats = [];
    leader = king;
    won = null;
    tasks = _drawTasks(rand);
    pickTurn = king;
    phase = Phase.picking;
  }

  List<MatchTask> _drawTasks(Random rand) {
    final inPlay = this.inPlay;
    final pool = List<Task>.of(GameState.taskPool)..shuffle(rand);
    final drawn = <MatchTask>[];
    int total = 0;
    for (final t in pool) {
      if (total >= target) break;
      final points = t.getPointsForPlayerCount(players);
      if (total + points > target) continue;
      if (!taskRules.containsKey(t.description)) continue;
      if (!playableWith(t.description, hands, inPlay)) continue;
      if (drawn.any((d) => clash(d.description, t.description))) continue;
      drawn.add(MatchTask(t.freshCopy()));
      total += points;
    }
    return drawn;
  }

  /// Deals a round for a table game. [accept] can refuse a deal (say, one
  /// that makes a task impossible); [king] keeps a reigning King, who takes
  /// the K♠ into their hand; [mayRule] says who may hold the K♠ otherwise.
  void dealFor(int dealId, Random rand,
      {int? king,
      bool Function(int seat)? mayRule,
      bool Function(List<List<PlayingCard>> hands, Set<PlayingCard> inPlay)?
          accept}) {
    this.dealId = dealId;
    for (int attempt = 0; attempt < 80; attempt++) {
      final d = deal(players, rand);
      hands = d.hands;
      setAside = d.setAside;
      if (accept == null || accept(hands, inPlay)) break;
    }
    var holder = hands.indexWhere((h) => h.contains(PlayingCard.king));
    final want = king ??
        (mayRule == null || mayRule(holder)
            ? holder
            : List.generate(players, (i) => i)
                .where(mayRule)
                .fold<int?>(null, (a, i) => a ?? i));
    if (want != null && want != holder) {
      // The K♠ goes to the King; a card of theirs goes the other way.
      final swap = hands[want][rand.nextInt(hands[want].length)];
      hands[want].remove(swap);
      hands[holder].remove(PlayingCard.king);
      hands[want].add(PlayingCard.king);
      hands[holder].add(swap);
      hands[want].sort();
      hands[holder].sort();
      holder = want;
    }
    this.king = holder;
    leader = holder;
    tricks = [];
    current = [];
    currentSeats = [];
    announced = {};
    revealed = {};
    revealHint = {};
    won = null;
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
        if (phase != Phase.picking) return 'Tasks are not being picked';
        if (seat != pickTurn) return 'Not your turn to pick';
        if (task < 0 || task >= tasks.length) return 'No such task';
        if (!canTake(task, seat)) {
          return tasks[task].owner != null
              ? 'That task is taken'
              : "The King can't take this task";
        }
      case Announce(:final seat, :final task, :final x):
        if (phase != Phase.announcing) return 'Nothing to announce';
        if (tasks[task].owner != seat) return 'Not your task';
        if (x < 0 || x > totalTricks) return 'Not a possible number';
      case PlayCard(:final seat, :final card):
        if (phase != Phase.playing) return 'Not playing yet';
        if (seat != turn) return 'Not your turn';
        if (!legalFor(seat).contains(card)) {
          return 'You must follow ${led!.isCourt ? 'with a Court Card' : led!.suit.symbol}';
        }
    }
    return null;
  }

  /// Carries out [a]. Returns the finished trick when [a] completed one.
  Trick? apply(MatchAction a) {
    final why = problem(a);
    if (why != null) throw StateError(why);
    switch (a) {
      case PickTask(:final seat, :final task):
        tasks[task].owner = seat;
        if (tasks.every((t) => t.owner != null)) {
          pickTurn = null;
          phase = tasks.any((t) => needsX(t.description) && t.x == null)
              ? Phase.announcing
              : Phase.playing;
        } else {
          // Clockwise, skipping anyone with nothing they may take.
          var next = seat;
          for (int i = 0; i < players; i++) {
            next = (next + 1) % players;
            if (List.generate(tasks.length, (t) => t).any((t) => canTake(t, next))) {
              break;
            }
          }
          pickTurn = next;
        }
        return null;
      case Announce(:final task, :final x):
        tasks[task].x = x;
        if (!tasks.any((t) => needsX(t.description) && t.x == null)) {
          phase = Phase.playing;
        }
        return null;
      case PlayCard(:final seat, :final card):
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
        _check();
        return trick;
    }
    return null;
  }

  /// Marks tasks done or failed after a trick, and ends the round when one
  /// fails or every one is done.
  void _check() {
    final v = view;
    for (final t in tasks) {
      if (t.verdict != Verdict.pending || t.owner == null) continue;
      t.verdict = taskRules[t.description]!(v, t.owner!, t.x);
    }
    final failed = tasks.any((t) => t.verdict == Verdict.failed);
    final allDone = tasks.every((t) => t.verdict == Verdict.done);
    if (failed || allDone || v.over) {
      phase = Phase.roundOver;
      won = !failed && allDone;
      if (won!) {
        wins++;
        streak++;
      } else {
        losses++;
        streak = 0;
      }
    }
  }

  // --------------------------------------------------------------- saving

  Map<String, dynamic> toJson() => {
        'players': players,
        'target': target,
        'round': round,
        'wins': wins,
        'losses': losses,
        'streak': streak,
        'hands': [
          for (final h in hands) [for (final c in h) c.id]
        ],
        'setAside': [for (final c in setAside) c.id],
        'king': king,
        'tasks': [for (final t in tasks) t.toJson()],
        'pickTurn': pickTurn,
        'tricks': [for (final t in tricks) t.toJson()],
        'leader': leader,
        'currentSeats': currentSeats,
        'current': [for (final c in current) c.id],
        'phase': phase.index,
        'won': won,
        'dealId': dealId,
        'announced': announced,
        'revealed': {for (final e in revealed.entries) '${e.key}': e.value.id},
        'revealHint': {for (final e in revealHint.entries) '${e.key}': e.value},
      };

  static MatchState fromJson(Map<String, dynamic> j) {
    final byDescription = {
      for (final t in GameState.taskPool) t.description: t
    };
    List<PlayingCard> cards(List l) =>
        [for (final c in l) PlayingCard.fromId(c as int)];
    return MatchState(players: j['players'] as int, target: j['target'] as int)
      ..round = j['round'] as int
      ..wins = j['wins'] as int
      ..losses = j['losses'] as int
      ..streak = j['streak'] as int
      ..hands = [for (final h in j['hands'] as List) cards(h as List)]
      ..setAside = cards(j['setAside'] as List)
      ..king = j['king'] as int
      ..tasks = [
        for (final t in j['tasks'] as List)
          MatchTask(byDescription[t['d']]!.freshCopy(),
              owner: t['owner'] as int?,
              x: t['x'] as int?,
              verdict: Verdict.values[t['verdict'] as int])
      ]
      ..pickTurn = j['pickTurn'] as int?
      ..tricks = [
        for (final t in j['tricks'] as List)
          Trick.fromJson(Map<String, dynamic>.from(t as Map))
      ]
      ..leader = j['leader'] as int
      ..currentSeats = List<int>.from(j['currentSeats'] as List)
      ..current = cards(j['current'] as List)
      ..phase = Phase.values[j['phase'] as int]
      ..won = j['won'] as bool?
      ..dealId = (j['dealId'] as int?) ?? -1
      ..announced =
          Map<String, int>.from((j['announced'] as Map?) ?? const {})
      ..revealed = {
        for (final e in ((j['revealed'] as Map?) ?? const {}).entries)
          int.parse(e.key as String): PlayingCard.fromId(e.value as int)
      }
      ..revealHint = {
        for (final e in ((j['revealHint'] as Map?) ?? const {}).entries)
          int.parse(e.key as String): e.value as String
      };
  }
}
