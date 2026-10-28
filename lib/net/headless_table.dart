/// A table with no screen: it deals, crowns the King card's holder, has
/// the courtiers play the seats nobody sits in, and applies every move
/// that comes back on its link at once. The page does the same with
/// animations between; a server would do this for a room. Tests play
/// whole games on it, and replays rebuild a game from its moves.
library;

import 'dart:async';
import 'dart:math';

import '../engine/bot.dart';
import '../engine/round.dart';
import '../game/actions.dart';
import '../game/bot_turn.dart';
import '../game/dealer.dart';
import '../game/host.dart';
import '../game/setup.dart';
import '../models.dart';
import 'table_link.dart';

class HeadlessTable {
  /// [seats] are the seats this table plays the courtiers for (every seat
  /// but [you]'s, by default; all of them with [you] -1).
  HeadlessTable(this.game, this.link, this.rules, {this.you = -1, Bot? bot})
      : host = Host(bot: bot ?? Bot(), you: you, send: link.send) {
    _moves = link.moves.listen((m) => apply(m.action));
  }

  final GameState game;
  final TableLink link;
  final ModeRules rules;
  final int you;
  final Host host;
  late final StreamSubscription<Move> _moves;

  /// Actions this table couldn't apply (stale ones), for tests to check.
  final refused = <TableAction>[];

  Round get round => game.round!;

  /// Makes [action] on the table; a stale one is let go.
  void apply(TableAction action) {
    switch (action) {
      case MatchAction():
        if (round.problem(action) != null) {
          refused.add(action);
          return;
        }
        round.apply(action);
        game.recordOutcomeIfFinished();
      case GameAction():
        if (game.problem(action) != null) {
          refused.add(action);
          return;
        }
        game.apply(action, setup: _setupFor);
    }
  }

  RoundSetup _setupFor(Random rand, {bool redeal = false}) =>
      rules.roundSetup(game, rand, redeal: redeal);

  /// Deals the round if it has no cards, and crowns the King card's holder
  /// if nobody reigns. Returns true when something was done.
  bool prepare() {
    var did = false;
    if (!round.hasCards && game.digital) {
      dealRound(game, rigged: rules.riggedDeal?.call(game));
      did = true;
    }
    if (round.king == null && round.hasCards) {
      link.send(Crown(you < 0 ? 0 : you, round.kingCardHolder!));
      did = true;
    }
    return did;
  }

  /// The courtiers' next move, if one is due. Returns false when nothing
  /// happened: the round is over, or it's [you]'s move.
  Future<bool> step() async {
    prepare();
    if (game.outcome != RoundOutcome.inProgress) return false;
    host.script = rules.script?.call(game) ?? const CourtierScript();
    final turn = await host.act(game);
    return turn.decision != null && turn.decision is! YourAnnouncement;
  }

  /// Plays the round out with the courtiers until it's over or it's
  /// [you]'s move. Returns the round's outcome then.
  Future<RoundOutcome> playRound({int guard = 400}) async {
    for (var i = 0; i < guard; i++) {
      if (!await step()) break;
    }
    return game.outcome;
  }

  /// Plays [rounds] rounds in a row with the courtiers alone (nobody at
  /// [you]'s seat), starting the next round each time one ends.
  Future<void> playRounds(int rounds) async {
    for (var r = 0; r < rounds; r++) {
      final outcome = await playRound();
      if (outcome == RoundOutcome.inProgress) break; // stuck: see refused
      if (r < rounds - 1) link.send(NextRound(you < 0 ? 0 : you));
    }
  }

  void dispose() {
    _moves.cancel();
  }
}
