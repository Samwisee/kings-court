/// Everything a player does at the table that isn't a move within the
/// round's play: crowning the King, marking a task at a real table and
/// undoing a mark, using the speech token, and starting the next round.
/// With the round's own moves (engine/round.dart, [MatchAction]) these are
/// every change to a game, as plain data with JSON, so a table on several
/// devices can send each other exactly what happened.
///
/// [GameState.apply] carries them out; [GameState.problem] says why one
/// isn't allowed.
library;

import '../engine/round.dart';
import '../engine/task.dart';

sealed class GameAction extends TableAction {
  const GameAction(this.seat);
  @override
  final int seat;

  /// The action [j] encodes, or null if it isn't one of these.
  static GameAction? fromJson(Map<String, dynamic> j) {
    final seat = j['seat'] as int;
    return switch (j['type']) {
      'crown' => Crown(seat, j['king'] as int),
      'speak' => Speak(seat, on: j['on'] as bool),
      'mark' => MarkTask(seat, j['task'] as int, TaskStatus.values[j['status'] as int]),
      'undo' => UndoMark(seat),
      'next' => NextRound(seat,
          target: j['target'] as int?,
          chapter: j['chapter'] as int?,
          lesson: j['lesson'] as int?),
      'retry' => RetryRound(seat),
      'redeal' => Redeal(seat, j['target'] as int),
      _ => null,
    };
  }
}

/// The King card's holder is crowned (on screen, by the table; at a real
/// table, whoever taps their seat).
class Crown extends GameAction {
  const Crown(super.seat, this.king);
  final int king;
  @override
  Map<String, dynamic> toJson() => {'type': 'crown', 'seat': seat, 'king': king};
}

/// The speech token at a real table: [seat] has shown a card ([on]), or
/// takes that back.
class Speak extends GameAction {
  const Speak(super.seat, {required this.on});
  final bool on;
  @override
  Map<String, dynamic> toJson() => {'type': 'speak', 'seat': seat, 'on': on};
}

/// A task marked done or failed at a real table (the same mark again
/// clears it).
class MarkTask extends GameAction {
  const MarkTask(super.seat, this.task, this.status);
  final int task;
  final TaskStatus status;
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'mark', 'seat': seat, 'task': task, 'status': status.index};
}

/// The last mark put back (a mis-tap that ended the round).
class UndoMark extends GameAction {
  const UndoMark(super.seat);
  @override
  Map<String, dynamic> toJson() => {'type': 'undo', 'seat': seat};
}

/// New tasks: the next round once this one is over (to [target] points, or
/// the next [chapter] or [lesson]), or, mid-round, this round's tasks
/// dealt again with the King kept.
class NextRound extends GameAction {
  const NextRound(super.seat, {this.target, this.chapter, this.lesson});
  final int? target;
  final int? chapter;
  final int? lesson;
  @override
  Map<String, dynamic> toJson() => {
        'type': 'next',
        'seat': seat,
        if (target != null) 'target': target,
        if (chapter != null) 'chapter': chapter,
        if (lesson != null) 'lesson': lesson,
      };
}

/// The same tasks again in a new round.
class RetryRound extends GameAction {
  const RetryRound(super.seat);
  @override
  Map<String, dynamic> toJson() => {'type': 'retry', 'seat': seat};
}

/// The round dealt again from the start for a new points target, its
/// seals and decree kept; whoever is dealt the King card is King.
class Redeal extends GameAction {
  const Redeal(super.seat, this.target);
  final int target;
  @override
  Map<String, dynamic> toJson() => {'type': 'redeal', 'seat': seat, 'target': target};
}

/// Any action from its JSON: a move within the round, or one of the
/// game's. Null if it's neither.
TableAction? tableActionFromJson(Map<String, dynamic> j) =>
    MatchAction.fromJson(j) ?? GameAction.fromJson(j);
