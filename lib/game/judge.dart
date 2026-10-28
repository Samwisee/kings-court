/// Judging an on-screen round from its tricks, with no screen in it.
///
/// After every trick the tasks are judged (`taskRules`, engine/rules.dart):
/// each pending task is done, failed, or still open. Sealed tasks are
/// judged in seal order, and one done out of order fails. The page turns
/// the verdicts into cards flipping over; this file only decides them.
library;

import '../engine/cards.dart';
import '../engine/match.dart';
import '../engine/rules.dart';
import '../models.dart';

/// A task the tricks have settled: done, or failed and why.
class TaskFlip {
  const TaskFlip(this.task, this.status, {this.why});
  final Task task;
  final TaskStatus status;

  /// Why it failed, for the end of the round.
  final String? why;
}

/// The tricks so far, as the task rules see them.
RoundView roundView(GameState game) {
  final c = game.cards!;
  return RoundView(
      players: c.players,
      king: game.kingIndex ?? c.king,
      tricks: c.tricks,
      totalTricks: c.totalTricks,
      inPlay: c.inPlay,
      shown: c.revealed,
      shownAt: c.revealedAt);
}

/// The round as the table shows it: with [trickPending], a trick still
/// lying on the table (before it's swept to its winner) doesn't count yet,
/// so the tasks' tallies and crossed-out cards change as the cards arrive.
RoundView shownView(GameState game, {required bool trickPending}) {
  final c = game.cards!;
  final pending = trickPending && c.tricks.isNotEmpty;
  return RoundView(
      players: c.players,
      king: game.kingIndex ?? c.king,
      tricks: pending ? c.tricks.sublist(0, c.tricks.length - 1) : c.tricks,
      totalTricks: c.totalTricks,
      inPlay: c.inPlay,
      shown: c.revealed,
      shownAt: c.revealedAt);
}

/// The tasks the tricks so far have settled, in the order they turn over:
/// sealed tasks by their seal, and nothing after the one that lost the
/// round. Nothing is changed; the page applies each flip.
List<TaskFlip> judgeTasks(GameState game) {
  final c = game.cards!;
  final v = roundView(game);
  int order(Task t) => t.seal ?? 0;
  final pending = game.tasks
      .where((t) => t.status == TaskStatus.pending && t.assignedPlayerIndex != null)
      .toList()
    ..sort((a, b) => order(a).compareTo(order(b)));
  final flips = <TaskFlip>[];
  final names = [for (final p in game.players) p.name];
  for (final t in pending) {
    final verdict = taskRules[t.description]!(
        v, t.assignedPlayerIndex!, c.announced[t.description]);
    if (verdict == Verdict.pending) continue;
    final sealProblem = game.sealProblem(t);
    if (verdict == Verdict.done && sealProblem == null) {
      flips.add(TaskFlip(t, TaskStatus.completed));
      // Doing one task may settle a seal for the next; a completed task
      // counts as done for the seals that follow.
      t.status = TaskStatus.completed;
      continue;
    }
    flips.add(TaskFlip(t, TaskStatus.failed,
        why: verdict == Verdict.done
            ? 'Done out of order: $sealProblem'
            : failReason(t.description, v, t.assignedPlayerIndex!,
                c.announced[t.description], names)));
    break;
  }
  // The statuses tried on above are the page's to set, with its flips.
  for (final f in flips) {
    f.task.status = TaskStatus.pending;
  }
  return flips;
}

/// Whether every open task is done with cards still in hand, so the table
/// can play the rest of the round out by itself. A round that merely
/// can't be lost is still played to the end by hand, and sealed tasks
/// hang on their order, so those rounds play on too.
bool canPlayOut(GameState game) {
  final c = game.cards!;
  if (c.current.isNotEmpty || c.tricks.length >= c.totalTricks) return false;
  final open = [
    for (final t in game.tasks)
      if (t.status == TaskStatus.pending && t.assignedPlayerIndex != null) t
  ];
  if (open.isEmpty || open.any((t) => t.seal != null)) return false;
  final v = roundView(game);
  final verdicts = [
    for (final t in open)
      taskRules[t.description]!(v, t.assignedPlayerIndex!, c.announced[t.description])
  ];
  return verdicts.every((x) => x == Verdict.done);
}

/// The cards' view of the round, with this table's tasks, owners and
/// rules on who may take what, for the courtiers to think with.
MatchState matchView(GameState game) {
  final c = game.cards!;
  c.target = game.target;
  c.king = game.kingIndex ?? c.king;
  c.tasks = [
    for (final t in game.tasks)
      MatchTask(t, owner: t.assignedPlayerIndex, x: c.announced[t.description])
  ];
  c.pickTurn = game.pickTurn;
  c.takeRule = (i, seat) => game.canTake(game.tasks[i], seat);
  return c;
}

/// Whether every task has an owner and every "exactly X" number is announced.
bool tasksSettled(GameState game) =>
    game.tasks.every((t) => t.assignedPlayerIndex != null) &&
    game.tasks.every((t) =>
        !needsX(t.description) || game.cards!.announced.containsKey(t.description));

/// The cards [t] names that its owner has already won, to cross out.
Set<String> wonNamed(GameState game, Task t, {required bool trickPending}) {
  final owner = t.assignedPlayerIndex;
  if (owner == null || t.description.startsWith("Don't")) return const {};
  final won = {
    for (final c in shownView(game, trickPending: trickPending).won(owner)) c.label
  };
  return {
    for (final m in RegExp('[A2-9][♥♦♠♣]').allMatches(t.description))
      if (won.contains(m.group(0))) m.group(0)!
  };
}

/// Tricks [seat] has won as the table shows them: a trick still on the
/// table ([lastTrick]) isn't counted yet.
int shownTricksWon(GameState game, int seat, Trick? lastTrick) {
  final n = game.cards!.tricksWon(seat);
  return lastTrick != null && lastTrick.winner == seat ? n - 1 : n;
}
