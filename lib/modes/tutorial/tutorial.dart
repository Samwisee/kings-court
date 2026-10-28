/// The tutorial: short, set-up rounds that teach the game one idea at a
/// time (see lessons.dart). Each lesson fixes its tasks and everyone's
/// cards, scripts the courtiers, and never lets anyone pass on a pick.
library;

import 'dart:math';

import '../../game/bot_turn.dart';
import '../../game/dealer.dart';
import '../../game/state.dart';
import '../mode.dart';
import 'lessons.dart';

class Tutorial extends Mode {
  const Tutorial();

  @override
  GameMode get id => GameMode.tutorial;

  @override
  String get title => 'Tutorial';

  /// The lesson being played.
  Lesson lessonOf(GameState g) =>
      lessons[max(0, min(g.lesson, lessons.length - 1))];

  /// A lesson's tasks, with no seals or decree and no passing.
  @override
  RoundSetup roundSetup(GameState g, int players, Random rand,
          {bool redeal = false}) =>
      RoundSetup(
          tasks: [for (final d in lessonOf(g).tasks) taskByDescription(d)],
          passing: false);

  /// A lesson deals the same cards every time.
  @override
  RiggedDeal? riggedDeal(GameState g) => lessonOf(g).deal();

  /// The courtiers follow the lesson's script while it holds, and keep
  /// their cards to themselves between tricks.
  @override
  CourtierScript script(GameState g) => CourtierScript(
      play: lessonOf(g).scripted, showsBetweenTricks: false);

  @override
  String roundLabel(GameState g) => 'lesson${g.lesson + 1}';
}
