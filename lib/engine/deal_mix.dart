/// Which tasks go together in a round. Every task is sorted into a tier by
/// how it can go wrong, and the draw keeps the mix in check:
///
/// * precise: an exact amount, so too many and too few both fail ("Win
///   exactly two tricks", "Win only the last trick"). These fight
///   everything else at the table, so they come up less often and a round
///   has at most one.
/// * race: measured against other players ("more tricks than everyone
///   else", "fewer tricks than the King"). At most two a round.
/// * avoid: something not to win or do ("Don't win any 6s"). Someone else
///   must take what they avoid, so no card is avoided by every player.
/// * capture and trick: win particular cards, or a particular kind of
///   trick. Getting more never hurts, so they mix safely.
///
/// Past 8 points the draw leans more and more toward bigger tasks, so the challenge
/// comes from the tasks themselves rather than from ever more of them
/// tangling together.
library;

import 'dart:math';

import 'conflicts.dart';

enum TaskTier { capture, trick, avoid, race, precise }

TaskTier tierOf(String d) {
  if (d.startsWith('Win exactly') ||
      d.startsWith('Win only') ||
      d.startsWith('Win as many') ||
      d.contains('same number') ||
      d == "Don't win any tricks") {
    return TaskTier.precise;
  }
  if (d.contains('than anyone') ||
      d.contains('rest of the court') ||
      d.contains('than the King')) {
    return TaskTier.race;
  }
  if (d.startsWith("Don't") || d.startsWith('Win no ')) return TaskTier.avoid;
  if (d.startsWith('Win a trick') ||
      d.contains(' with a ') ||
      d.contains(' with another ') ||
      d.contains('in a row') ||
      d.contains('first') ||
      d.contains('last trick')) {
    return TaskTier.trick;
  }
  return TaskTier.capture;
}

/// How often each tier is drawn, compared with the rest.
const tierWeight = {
  TaskTier.capture: 1.0,
  TaskTier.trick: 1.0,
  TaskTier.avoid: 0.85,
  TaskTier.race: 0.8,
  TaskTier.precise: 0.5,
};

/// The most of a tier a round may have.
const tierLimit = {
  TaskTier.precise: 1,
  TaskTier.race: 2,
};

/// [pool] in the order a deal should try them: random, but weighted by
/// tier, and toward bigger tasks as [target] rises.
List<T> drawOrder<T>(List<T> pool, Random rand,
    {required String Function(T) description,
    required int Function(T) points,
    required int target}) {
  // The balance report shows the number of tasks, more than their points,
  // decides how winnable a round is, so big targets lean hard toward big
  // tasks.
  final lean = ((target - 8) / 7).clamp(0.0, 2.5);
  final keyed = [
    for (final t in pool)
      (
        t,
        pow(rand.nextDouble(),
                1 / (tierWeight[tierOf(description(t))]! * pow(max(1, points(t)), lean)))
            .toDouble()
      )
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final k in keyed) k.$1];
}

/// Whether [next] can join the tasks already [drawn] for a table of
/// [hands] hands: no two clash, no card is avoided by everyone, and no
/// tier is over its limit.
bool fitsDeal(List<String> drawn, String next, int hands) {
  if (drawn.any((d) => clash(d, next))) return false;
  if (overAvoided(drawn, next, hands)) return false;
  final tier = tierOf(next);
  final limit = tierLimit[tier];
  if (limit != null && drawn.where((d) => tierOf(d) == tier).length >= limit) {
    return false;
  }
  return true;
}
