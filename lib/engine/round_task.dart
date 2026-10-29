/// A task on the table this round, a round's result, and a task turning
/// over as it's judged.
library;


import 'decrees.dart';
import 'task.dart';
import 'tasks.dart';

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
