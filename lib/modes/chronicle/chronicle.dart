/// The Chronicle: 24 chapters, each a round with a fixed points target,
/// seals and perhaps a decree, beaten for crowns (see chapters.dart).
library;

import 'dart:math';

import '../../engine/round.dart';
import '../../game/state.dart';
import '../mode.dart';
import '../progress.dart';
import 'chapters.dart';

class ChronicleMode extends Mode {
  const ChronicleMode();

  @override
  GameMode get id => GameMode.chronicle;

  @override
  String get title => 'The Chronicle';

  /// The chapter being played, or the first.
  Chapter chapterOf(GameState g) => chronicle[g.chapter ?? 0];

  /// A chapter fixes its points, seals and decree, new round or re-deal.
  @override
  RoundSetup roundSetup(GameState g, int players, Random rand,
      {bool redeal = false}) {
    final chapter = chapterOf(g);
    return RoundSetup(
        target: chapter.points, sealCount: chapter.seals, decree: chapter.decree);
  }

  /// Winning a chapter earns crowns (3 at the first attempt, 2 within
  /// three, 1 after), recorded in the player's progress.
  @override
  RoundEffects afterRound(GameState g, RoundResult result, Progress progress) {
    final chapter = g.chapter;
    if (!result.won || chapter == null) return RoundEffects(nextTarget: g.target);
    final crowns = progress.chronicle.crowns;
    final before = crowns[chapter];
    final earned = progress.chronicle.recordWin(chapter);
    return RoundEffects(
        nextTarget: g.target,
        crowns: earned,
        undo: () {
          if (before == null) {
            crowns.remove(chapter);
          } else {
            crowns[chapter] = before;
          }
        });
  }

  @override
  String roundLabel(GameState g) => 'chapter${(g.chapter ?? 0) + 1}';
}
