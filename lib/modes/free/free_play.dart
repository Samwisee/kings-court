/// Free play: rounds to a points target of your choosing, with surprise
/// seals and decrees if you like.
library;

import 'dart:math';

import '../../engine/decrees.dart';
import '../../models.dart';
import '../mode.dart';

class FreePlay extends Mode {
  const FreePlay();

  @override
  GameMode get id => GameMode.free;

  @override
  String get title => 'Free play';

  /// With surprises on, a new round rolls its seals and decree; a re-deal
  /// keeps the round's.
  @override
  RoundSetup roundSetup(GameState g, int players, Random rand,
      {bool redeal = false}) {
    if (redeal || !g.surprise) return super.roundSetup(g, players, rand, redeal: redeal);
    final seals = const [0, 0, 2, 3][rand.nextInt(4)];
    final decree = rand.nextBool()
        ? Decree.values[rand.nextInt(Decree.values.length)]
        : null;
    return RoundSetup(sealCount: seals, decree: decree);
  }
}
