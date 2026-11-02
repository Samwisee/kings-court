/// Dynasty: a King's reign as a roguelike (see docs/DYNASTY.md and
/// run.dart). Each hand deals the projects the King picked; the run itself
/// rides along with the hand's game ([runOf]). The old story mode's lines,
/// dilemmas and arcs still wait in data/ for the story to come.
library;

import 'dart:math';

import '../../game/state.dart';
import '../mode.dart';
import 'run.dart';

export 'run.dart';

final _runs = Expando<DynastyRun>('dynasty run');

/// The run [g]'s hand belongs to, if it's a Dynasty hand.
DynastyRun? runOf(GameState g) => _runs[g];

/// Ties [g]'s hand to [run].
void attachRun(GameState g, DynastyRun run) => _runs[g] = run;

class Dynasty extends Mode {
  const Dynasty();

  @override
  GameMode get id => GameMode.dynasty;

  @override
  String get title => 'Dynasty';

  /// The projects the King picked, a task each.
  @override
  RoundSetup roundSetup(GameState g, int players, Random rand,
      {bool redeal = false}) {
    final run = runOf(g);
    if (run == null || run.picked.isEmpty) return const RoundSetup();
    return RoundSetup(tasks: run.tasks);
  }

  @override
  String roundLabel(GameState g) => 'hand${(runOf(g)?.hand ?? 0) + 1}';
}
