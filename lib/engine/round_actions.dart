/// The moves a player makes in a round: [MatchAction]s, each one JSON
/// for the link.
library;


import 'cards.dart';

/// Something a player does at the table, as plain data: it turns into
/// JSON and back, so it can travel to every device at the table. The
/// moves within a round's play are [MatchAction]s; the rest (crowning,
/// marking a task at a real table, the next round) are the game's
/// (game/actions.dart).
abstract class TableAction {
  const TableAction();

  /// The seat making the move.
  int get seat;

  Map<String, dynamic> toJson();
}

/// A move within a round's play.
sealed class MatchAction extends TableAction {
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
        'ready' => Ready(j['seat'] as int),
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

/// Before anyone takes a task, [seat] won't show a card first: they're
/// ready for the picking to begin. At a table of several people, the
/// picking waits until every one of them is (or has shown a card).
class Ready extends MatchAction {
  const Ready(super.seat);
  @override
  Map<String, dynamic> toJson() => {'type': 'ready', 'seat': seat};
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
