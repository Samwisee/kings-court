/// Every way to play, by its [GameMode].
library;

import '../models.dart';
import 'chronicle/chronicle.dart';
import 'dynasty/dynasty.dart';
import 'endless/endless.dart';
import 'free/free_play.dart';
import 'mode.dart';
import 'tutorial/tutorial.dart';

export 'mode.dart';

const modes = <GameMode, Mode>{
  GameMode.free: FreePlay(),
  GameMode.endless: Endless(),
  GameMode.chronicle: ChronicleMode(),
  GameMode.dynasty: Dynasty(),
  GameMode.tutorial: Tutorial(),
};

Mode modeOf(GameMode id) => modes[id]!;
