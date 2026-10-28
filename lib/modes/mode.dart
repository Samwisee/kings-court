/// A way to play: what a mode decides about each round, and what a
/// finished round means to it.
///
/// The game (models.dart) plays any round the same way; a mode only says
/// how a round is set up (its tasks, seals, decree and rules), what the
/// courtiers are told, and what follows a result: the next target, crowns
/// earned, the label a round goes under. The registry is modes.dart; each
/// mode's rules live under modes/<name>/ and its screens under
/// ui/modes/<name>/.
library;

import 'dart:math';

import '../engine/round.dart';
import '../game/bot_turn.dart';
import '../game/dealer.dart';
import '../models.dart';
import 'progress.dart';

/// What a finished round changes, as the mode worked it out: the points
/// target the next round is played to, crowns earned (the Chronicle), and
/// how to take it back if the round's last mark is undone.
class RoundEffects {
  const RoundEffects({required this.nextTarget, this.crowns = 0, this.undo});
  final int nextTarget;
  final int crowns;
  final void Function()? undo;
}

abstract class Mode {
  const Mode();

  GameMode get id;

  /// The mode's name, as the saved games list and the setup show it.
  String get title;

  /// How a round of [players] seats in [g] is set up: its tasks (or a
  /// draw to the target), seals, decree and rules. Rolled on [rand] (the
  /// game's dice for that deal, so the same seed sets up the same round).
  /// A [redeal] keeps what the round in progress had.
  RoundSetup roundSetup(GameState g, int players, Random rand,
          {bool redeal = false}) =>
      redeal ? RoundSetup.keep(g.round) : const RoundSetup();

  /// A deal fixed in advance for the round (a lesson's), or null to deal
  /// from the seed.
  RiggedDeal? riggedDeal(GameState g) => null;

  /// What the courtiers are told this round.
  CourtierScript script(GameState g) => const CourtierScript();

  /// What [result] means for the mode: the next target, crowns, and any
  /// progress recorded in [progress].
  RoundEffects afterRound(GameState g, RoundResult result, Progress progress) =>
      RoundEffects(nextTarget: g.target);

  /// How a round of this mode is labelled in the analytics.
  String roundLabel(GameState g) => roundBucket(g.roundNumber);
}

/// Rounds grouped for the analytics: each of the first five, then 6 to 10,
/// then the rest.
String roundBucket(int round) =>
    round <= 5 ? 'r$round' : round <= 10 ? 'r6-10' : 'r11+';
