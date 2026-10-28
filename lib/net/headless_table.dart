/// A table with no screen: it deals, crowns the King card's holder, has
/// the courtiers play the seats nobody sits in, and applies every move
/// that comes back on its link at once. The page does the same with
/// animations between; a server would do this for a room. Tests play
/// whole games on it, and replays rebuild a game from its moves.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../engine/bot.dart';
import '../engine/round.dart';
import '../game/actions.dart';
import '../game/bot_turn.dart';
import '../game/dealer.dart';
import '../game/host.dart';
import '../game/seats.dart';
import '../game/setup.dart';
import '../models.dart';
import 'table_link.dart';

class HeadlessTable {
  /// This device plays from seat [you] (-1 for none: a server, or a game
  /// of courtiers alone) and the courtiers play the seats [seats] gives
  /// them (every other seat, by default). The [host] table deals the
  /// crown and the next round; every table deals the cards (from the
  /// seed, the same everywhere).
  HeadlessTable(this.game, this.link, this.rules,
      {this.you = -1, Bot? bot, this.seats, this.host = true})
      : bot = bot ?? Bot() {
    _moves = link.moves.listen(_onMove);
  }

  final GameState game;
  final TableLink link;
  final ModeRules rules;
  final int you;
  final bool host;
  final Bot bot;
  final Seats? seats;
  late final Host courtiers = Host(bot: bot, you: you, seats: seats, send: _send);
  late final StreamSubscription<Move> _moves;

  /// Actions this table couldn't apply (stale ones), for tests to check.
  final refused = <TableAction>[];

  /// Actions sent from here that haven't come back yet (on a network they
  /// take a moment): the courtiers wait for them before thinking again.
  final pending = <String>[];

  Round get round => game.round!;

  void _send(TableAction action) {
    pending.add(jsonEncode(action.toJson()));
    link.send(action);
  }

  void _onMove(Move m) {
    pending.remove(jsonEncode(m.action.toJson()));
    apply(m.action);
  }

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

  /// Deals the round if it has no cards, and (the host) crowns the King
  /// card's holder if nobody reigns. Returns true when something was done.
  bool prepare() {
    var did = false;
    if (!round.hasCards && game.digital) {
      dealRound(game, rigged: rules.riggedDeal?.call(game));
      did = true;
    }
    if (host && round.king == null && round.hasCards && pending.isEmpty) {
      _send(Crown(you < 0 ? 0 : you, round.kingCardHolder!));
      did = true;
    }
    return did;
  }

  /// The courtiers' next move, if one is due (the host's courtiers; a
  /// table that isn't the host runs none). Returns false when nothing
  /// happened: a move of ours is still on its way, the round is over, or
  /// it's a person's move.
  Future<bool> step() async {
    if (prepare()) return true;
    if (!host || pending.isNotEmpty) return false;
    if (game.outcome != RoundOutcome.inProgress) return false;
    courtiers.script = rules.script?.call(game) ?? const CourtierScript();
    final turn = await courtiers.act(game);
    return turn.decision != null && turn.decision is! YourAnnouncement;
  }

  /// The person at [seat] on this device makes their move, when it's
  /// theirs: a courtier decides for them (tests play people this way).
  Future<bool> playAs(int seat) async {
    prepare();
    if (pending.isNotEmpty || game.outcome != RoundOutcome.inProgress) return false;
    final only = Seats.of([
      for (var s = 0; s < game.players.length; s++)
        s == seat ? const CourtierSeat() : Person('other$s')
    ]);
    final person = Host(bot: bot, you: -1, seats: only, send: _send)
      ..script = rules.script?.call(game) ?? const CourtierScript();
    final turn = await person.act(game);
    return turn.decision != null && turn.decision is! YourAnnouncement;
  }

  /// After a disconnection: whatever was sent and lost is forgotten, so
  /// the courtiers think again from the moves that did come back.
  void resync() => pending.clear();

  /// Plays the round out with the courtiers until it's over or it's a
  /// person's move. Returns the round's outcome then.
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
      if (r < rounds - 1) _send(NextRound(you < 0 ? 0 : you));
    }
  }

  void dispose() {
    _moves.cancel();
  }
}
