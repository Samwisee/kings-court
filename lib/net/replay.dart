/// A game rebuilt from how it started and every move since: what a bug
/// report carries, and what a device joining late catches up from.
library;

import '../engine/round.dart';
import '../game/actions.dart';
import '../game/dealer.dart';
import '../game/setup.dart';
import '../models.dart';
import 'table_link.dart';

/// The game [setup] started, after [moves] in order. Rounds are dealt as
/// the table dealt them (from the seed), so the cards come out the same.
/// A move that isn't allowed when its turn comes is skipped and listed in
/// [skipped], since the table it came from must have let it go too.
GameState replay(GameSetup setup, Iterable<Move> moves,
    {required ModeRules rules, List<Move>? skipped}) {
  final game = setup.start(rules);
  for (final move in moves) {
    final round = game.round!;
    if (!round.hasCards) dealRound(game, rigged: rules.riggedDeal?.call(game));
    switch (move.action) {
      case final MatchAction a:
        if (round.problem(a) != null) {
          skipped?.add(move);
          continue;
        }
        round.apply(a);
        game.recordOutcomeIfFinished();
      case final GameAction a:
        if (game.problem(a) != null) {
          skipped?.add(move);
          continue;
        }
        game.apply(a,
            setup: (rand, {redeal = false}) =>
                rules.roundSetup(game, rand, redeal: redeal));
    }
  }
  final round = game.round!;
  if (!round.hasCards) dealRound(game, rigged: rules.riggedDeal?.call(game));
  return game;
}
