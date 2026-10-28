/// Dynasty: the story of a reign, to come as a roguelike. Its content (the
/// courtiers' lines, the dilemmas, the tidings and story arcs) waits in
/// data/; the mode itself is not yet playable and the setup shows it as
/// coming soon.
library;

import '../../models.dart';
import '../mode.dart';

class Dynasty extends Mode {
  const Dynasty();

  @override
  GameMode get id => GameMode.dynasty;

  @override
  String get title => 'Dynasty';
}
