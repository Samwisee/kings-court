/// A task: what it asks, its points at each table size, and how it's
/// going this round. Plain Dart, with no Flutter, so the same rules can run
/// on a server for online play.
library;

import '../tasks.dart';

enum TaskStatus { pending, completed, failed }

class Task {
  final String description;
  final int threePlayerPoints;
  final int fourPlayerPoints;
  final int fivePlayerPoints;
  final int sixPlayerPoints;

  /// Tasks measured against the King (e.g. "win more tricks than the King")
  /// can't be taken by the King.
  final bool kingCantTake;

  TaskStatus status;
  int? assignedPlayerIndex;

  /// Wax seal fixing when this task must be completed (see [Seals]).
  int? seal;

  Task({
    required this.description,
    required this.threePlayerPoints,
    required this.fourPlayerPoints,
    required this.fivePlayerPoints,
    required this.sixPlayerPoints,
    this.kingCantTake = false,
    this.status = TaskStatus.pending,
    this.assignedPlayerIndex,
  });

  bool get isCompleted => status == TaskStatus.completed;
  bool get isFailed => status == TaskStatus.failed;

  /// Difficulty for [playerCount]. The 2-player variant (with the Dummy)
  /// uses the 3-player difficulty.
  int getPointsForPlayerCount(int playerCount) {
    switch (playerCount) {
      case 4:
        return fourPlayerPoints;
      case 5:
        return fivePlayerPoints;
      case 6:
        return sixPlayerPoints;
      default:
        return threePlayerPoints;
    }
  }

  static final _perPlayerCount =
      RegExp(r'(\d+) / (\d+) / (\d+) / (\d+) \(2–3 / 4 / 5 / 6 players\)');
  static final _bracketed = RegExp(r'\s*\(([^)]*)\)');

  /// Short wording for the card on the table. Tasks with a number per
  /// player count show only the number that applies, and any bracketed
  /// condition is left off (see [notes]); the card shows an info icon
  /// instead.
  String cardText(int playerCount) {
    var text = description;
    final m = _perPlayerCount.firstMatch(text);
    if (m != null) {
      final group = playerCount <= 3 ? 1 : playerCount - 2;
      text = text.replaceRange(m.start, m.end, m.group(group)!);
    }
    return text.replaceAll(_bracketed, '');
  }

  /// The trick it's about can't have any Court Cards in it: shown as an
  /// icon beside the points.
  bool get noCourtCards => description.contains('with no Court Cards');

  /// The full wording for the close-up, less "with no Court Cards", which
  /// its icon says.
  String fullText(int playerCount) =>
      cardText(playerCount).replaceAll(RegExp(r',? with no Court Cards'), '').trim();

  /// The task as short as it can go, for the card on the table: the same
  /// meaning in fewer words, with Court Cards as a crown (\uE001) and "with no
  /// Court Cards" as a struck-out crown (\uE000). The close-up keeps the full
  /// wording.
  String boardText(int playerCount) {
    var t = cardText(playerCount).trim();
    for (final (from, to) in _shorter) {
      t = t.replaceAllMapped(
          from,
          (m) => to.replaceAllMapped(
              RegExp(r'\$(\d)'), (g) => m.group(int.parse(g[1]!)) ?? ''));
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static final List<(Pattern, String)> _shorter = [
    // Shown as an icon beside the points instead.
    (RegExp(r',? with no Court Cards'), ''),
    ('Win more tricks than anyone else', 'Win the most tricks'),
    ('Win fewer tricks than anyone else', 'Win the fewest tricks'),
    ('than the rest of the court put together', 'than everyone else combined'),
    ('Win the same number of tricks as', 'Win as many tricks as'),
    ("Don't win any of the first", 'Win none of the first'),
    ("Don't win any", 'Win no'),
    ("Don't lead a trick with a", 'Never lead'),
    ('named before the first trick', 'named first'),
    ('a trick containing an Ace and a 9', 'an Ace and a 9 in one trick'),
    ('a trick with exactly two Court Cards in it', 'a trick holding two Court Cards'),
    ('a trick with three different suits in it', 'a trick of three suits'),
    ('a trick where no one followed suit', 'a trick nobody followed'),
    ('a trick with a card just one above the card led', 'a trick by one rank'),
    ('two tricks with cards of the same rank', 'two tricks with the same number'),
    ('the trick right after the King wins one', 'the trick after the King wins'),
    ('the trick after the Queen is played', 'the trick after the Queen'),
    ('exactly as many tricks as the player on your left', 'as many tricks as your left neighbour'),
    ('Win no tricks until the King has won one', 'Win nothing before the King does'),
    ('two tricks led with a ♥', 'two ♥-led tricks'),
    (RegExp(r'([♥♦♠♣]) cards?\b'), r'$1'),
    ('Win no Court Cards', 'Win no \uE001'),
    (RegExp(r'Court Cards?'), '\uE001'),
  ];

  /// The bracketed conditions, as sentences, for the close-up view.
  List<String> get notes {
    final text = description.replaceAll(_perPlayerCount, '');
    return [
      for (final m in _bracketed.allMatches(text))
        '${m.group(1)![0].toUpperCase()}${m.group(1)!.substring(1)}.',
    ];
  }

  bool get hasNotes => notes.isNotEmpty;

  Task freshCopy() => Task(
        description: description,
        threePlayerPoints: threePlayerPoints,
        fourPlayerPoints: fourPlayerPoints,
        fivePlayerPoints: fivePlayerPoints,
        sixPlayerPoints: sixPlayerPoints,
        kingCantTake: kingCantTake,
      )..seal = seal;
}

/// Every task in the game, built from [tasksData].
final List<Task> allTasks = _buildTaskPool();

/// The King holds the King card, the highest card, so whenever they play it they
/// win that trick and a Court Card with it. These can never be theirs.
const _impossibleForTheKing = [
  'Win no Court Cards',
  "Don't win any tricks",
];

List<Task> _buildTaskPool() {
  return tasksData
      .map((m) => Task(
            description: m['description'] as String,
            threePlayerPoints: m['three'] as int,
            fourPlayerPoints: m['four'] as int,
            fivePlayerPoints: m['five'] as int,
            sixPlayerPoints: m['six'] as int,
            kingCantTake: ((m['kingCantTake'] as bool?) ?? false) ||
                _impossibleForTheKing.any(
                    (d) => (m['description'] as String).startsWith(d)),
          ))
      .toList();
}
