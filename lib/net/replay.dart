/// A game rebuilt from how it started and every move since: what a bug
/// report carries, and what a device joining late catches up from.
library;

import 'dart:convert';

import '../engine/round.dart';
import '../game/actions.dart';
import '../game/dealer.dart';
import '../game/setup.dart';
import '../game/state.dart';
import 'table_link.dart';

/// The game [setup] started, after [moves] in order. Rounds are dealt as
/// the table dealt them (from the seed), so the cards come out the same.
/// A move that isn't allowed when its turn comes is skipped and listed in
/// [skipped], since the table it came from must have let it go too. [you]
/// is the seat it's rebuilt for (a device joining late: its own).
GameState replay(GameSetup setup, Iterable<Move> moves,
    {required ModeRules rules, List<Move>? skipped, int you = 0}) {
  final game = setup.start(rules, you: you);
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

/// A bug report played again from its setup and moves, held against the
/// state it carried: the same round means the report is reproducible from
/// its moves alone; a difference names the parts that don't match.
class ReplayedReport {
  const ReplayedReport(
      {required this.replayed, required this.reported, required this.skipped, required this.differences});

  /// The game the setup and moves make.
  final GameState replayed;

  /// The game the report carried, or null if it couldn't be read.
  final GameState? reported;

  /// Moves that weren't allowed when their turn came.
  final List<Move> skipped;

  /// The parts of the round (and record) that differ: empty when the
  /// replay matches.
  final List<String> differences;

  bool get matches => reported != null && differences.isEmpty;

  String get verdict => reported == null
      ? 'the report\'s state could not be read'
      : matches
          ? 'the replay matches the reported state'
          : 'the replay differs in: ${differences.join(', ')}';
}

/// Replays a bug report (`setup`, `moves`, `state` as `_bugDetails` in
/// main.dart writes them). [rulesFor] gives each mode's rules.
ReplayedReport? replayReport(Map<String, dynamic> report,
    {required ModeRules Function(GameMode mode) rulesFor}) {
  final state = report['state'];
  final reported = state is Map
      ? GameState.fromJson(Map<String, dynamic>.from(state))
      : null;
  final rawSetup = reported?.setup?.toJson() ?? report['setup'];
  if (rawSetup is! Map) return null;
  final setup = GameSetup.fromJson(Map<String, dynamic>.from(rawSetup));
  final moves = [
    for (final m in (report['moves'] as List?) ?? const [])
      if (Move.fromJson(Map<String, dynamic>.from(m as Map)) case final move?) move
  ];
  final skipped = <Move>[];
  final replayed = replay(setup, moves, rules: rulesFor(setup.mode), skipped: skipped);
  final differences = <String>[];
  if (reported != null) {
    final a = replayed.round!.toJson();
    final b = reported.round!.toJson();
    for (final key in a.keys) {
      if (jsonEncode(a[key]) != jsonEncode(b[key])) differences.add(key);
    }
    for (final (key, x, y) in [
      ('wins', replayed.wins, reported.wins),
      ('losses', replayed.losses, reported.losses),
      ('roundNumber', replayed.roundNumber, reported.roundNumber),
      ('dealId', replayed.dealId, reported.dealId),
    ]) {
      if (x != y) differences.add(key);
    }
  }
  return ReplayedReport(
      replayed: replayed, reported: reported, skipped: skipped, differences: differences);
}
