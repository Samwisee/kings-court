/// Endless: free play where every win adds a point to the next round's
/// target, and the streak is the score.
library;

import 'dart:math';

import '../../engine/round.dart';
import '../../models.dart';
import '../free/free_play.dart';
import '../mode.dart';
import '../progress.dart';

class Endless extends FreePlay {
  const Endless();

  @override
  GameMode get id => GameMode.endless;

  @override
  String get title => 'Endless';

  @override
  RoundEffects afterRound(GameState g, RoundResult result, Progress progress) =>
      RoundEffects(
          nextTarget: result.won ? min(maxTarget, g.target + 1) : g.target);
}
