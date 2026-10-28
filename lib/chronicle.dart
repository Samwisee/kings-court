/// Royal decrees: special rules for a round.
enum Decree {
  silence(
    'Silence',
    'No one may reveal a card this round.',
  ),
  kingsCommand(
    "King's Command",
    'The King hands out every task. Nobody else picks.',
  ),
  lateCounsel(
    'Late Counsel',
    'Card reveals are only allowed once three tricks have been played.',
  ),
  exile(
    'Exile',
    'One player has been banished from court and may not take any tasks.',
  );

  const Decree(this.title, this.rule);
  final String title;
  final String rule;
}

/// Wax seals that fix the order tasks must be completed in. Seals I, II and
/// III go in number order; the Ω seal must be the very last task done.
class Seals {
  Seals._();

  static const last = 99;

  /// The seals a round with [count] seals uses: up to two numbered, then
  /// the last one becomes Ω once there are three or more.
  static List<int> forCount(int count) {
    if (count <= 0) return const [];
    if (count <= 2) return [for (int i = 1; i <= count; i++) i];
    return [for (int i = 1; i < count; i++) i, last];
  }

  static String label(int seal) => switch (seal) {
        1 => 'I',
        2 => 'II',
        3 => 'III',
        4 => 'IV',
        last => 'Ω',
        _ => '$seal',
      };

  static String describe(int seal) => seal == last
      ? 'Ω seal: this must be the last task completed.'
      : 'Seal ${label(seal)}: complete it before any higher seal'
          '${seal > 1 ? ', and after seal ${label(seal - 1)}' : ''}.';
}

/// One chapter of the Chronicle: a fixed points target, a number of
/// seals, and perhaps a decree.
class Chapter {
  const Chapter(this.title, this.points, {this.seals = 0, this.decree});
  final String title;
  final int points;
  final int seals;
  final Decree? decree;
}

/// The Chronicle of the King's Court: chapters that build up points, seals
/// and decrees.
const chronicle = <Chapter>[
  Chapter('The Coronation', 3),
  Chapter('A Quiet Supper', 4),
  Chapter('The First Seals', 5, seals: 2),
  Chapter('The Silent Court', 5, decree: Decree.silence),
  Chapter('Matters of Precedence', 6, seals: 2),
  Chapter('By Royal Command', 6, decree: Decree.kingsCommand),
  Chapter('Counsel Delayed', 7, seals: 2, decree: Decree.lateCounsel),
  Chapter('The Ambassador', 7, seals: 2),
  Chapter('The Exile', 8, decree: Decree.exile),
  Chapter('Three Seals', 8, seals: 3),
  Chapter('Whispers in the Hall', 9, seals: 2, decree: Decree.silence),
  Chapter('The King Decides', 9, seals: 2, decree: Decree.kingsCommand),
  Chapter('The Long Night', 10, decree: Decree.lateCounsel),
  Chapter('A Banished Friend', 10, seals: 2, decree: Decree.exile),
  Chapter('The Sealed Letter', 11, seals: 3, decree: Decree.silence),
  Chapter('Royal Favour', 11, seals: 2, decree: Decree.kingsCommand),
  Chapter('The Council Waits', 12, seals: 2, decree: Decree.lateCounsel),
  Chapter('Traitor at Court', 12, seals: 3, decree: Decree.exile),
  Chapter('The Grand Feast', 13, seals: 2, decree: Decree.silence),
  Chapter('Edict of the Crown', 14, seals: 3, decree: Decree.kingsCommand),
  Chapter('Into the Wilds', 15, seals: 2, decree: Decree.exile),
  Chapter('The Final Counsel', 16, seals: 3, decree: Decree.lateCounsel),
  Chapter('A Silent Throne', 17, seals: 2, decree: Decree.silence),
  Chapter('Long Live the King', 18, seals: 4),
];

/// Crowns earned for beating a chapter: 3 on the first attempt, 2 within
/// three attempts, 1 otherwise.
int crownsFor(int attempts) => attempts <= 1 ? 3 : attempts <= 3 ? 2 : 1;

/// How far a table has got through the Chronicle.
class ChronicleProgress {
  ChronicleProgress({Map<int, int>? attempts, Map<int, int>? crowns})
      : attempts = attempts ?? {},
        crowns = crowns ?? {};

  /// Attempts per chapter (by index), including the one in progress.
  final Map<int, int> attempts;

  /// Best crowns earned per beaten chapter.
  final Map<int, int> crowns;

  /// The first chapter not yet beaten (or the last chapter when all are).
  int get nextChapter {
    for (var i = 0; i < chronicle.length; i++) {
      if (!crowns.containsKey(i)) return i;
    }
    return chronicle.length - 1;
  }

  bool isUnlocked(int chapter) => chapter <= nextChapter;

  int get totalCrowns => crowns.values.fold(0, (a, c) => a + c);

  void startAttempt(int chapter) =>
      attempts[chapter] = (attempts[chapter] ?? 0) + 1;

  /// Records a win; returns the crowns earned this time.
  int recordWin(int chapter) {
    final earned = crownsFor(attempts[chapter] ?? 1);
    crowns[chapter] = (crowns[chapter] ?? 0) > earned ? crowns[chapter]! : earned;
    return earned;
  }

  Map<String, dynamic> toJson() => {
        'attempts': {for (final e in attempts.entries) '${e.key}': e.value},
        'crowns': {for (final e in crowns.entries) '${e.key}': e.value},
      };

  static ChronicleProgress fromJson(Map<String, dynamic> j) {
    Map<int, int> read(String key) => {
          for (final e in ((j[key] as Map?) ?? {}).entries)
            int.parse(e.key as String): e.value as int,
        };
    return ChronicleProgress(attempts: read('attempts'), crowns: read('crowns'));
  }
}
