/// Royal decrees and wax seals: the special rules a round can carry.
/// Plain Dart, part of the rules of a round.
library;

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
