/// Every random choice in a game comes from the game's seed and what the
/// numbers are for, so the same seed plays the same game: the same deals
/// and tasks, the same exile, the same courtiers in the same seats, the
/// same choices from the courtiers. A game can be dealt again from a bug
/// report, replayed from its moves, or shared as a daily deal, and every
/// device at one table rolls alike.
library;

import 'dart:math';

/// What a roll of the dice is for.
enum Purpose {
  /// The cards of a deal.
  deal,

  /// The tasks drawn, and their seals.
  tasks,

  /// Who is exiled under that decree.
  exile,

  /// The courtiers' choices (the bots).
  courtiers,

  /// Which house sits in each seat.
  seats,
}

class Dice {
  const Dice(this.seed);
  final int seed;

  /// The random numbers for [purpose] on deal [dealId]: the same every
  /// time for the same seed, deal and purpose.
  Random roll(Purpose purpose, {int dealId = 0}) =>
      Random(seed ^ (dealId * 0x9E3779B1) ^ (purpose.index * 0x85EBCA6B));
}
