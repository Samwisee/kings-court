/// Where the actions of a game go.
///
/// Everything a player does at the table (playing a card, showing one,
/// crowning the King, marking a task, dealing the next round) is an
/// [Action]: plain data that turns into JSON and back. The table never
/// changes the game itself; it [TableLink.send]s the action, and changes
/// the game when the action comes back on [TableLink.moves], numbered in
/// the order the table plays them.
///
/// Today the link is [LocalLink]: everything is played on this device, so
/// an action comes straight back, at once. For online play a network link
/// takes its place: it sends each action to the server, and every device
/// plays the moves the server sends back, in the same order, so every
/// table stays the same. Nothing else in the game needs to change (see
/// fake_network.dart for a link that behaves like a network).
library;

import 'dart:async';

import '../engine/round.dart';
import '../game/actions.dart';

/// An action as the table played it: the [seq]th move of the game.
class Move {
  const Move(this.seq, this.action);
  final int seq;
  final Action action;

  Map<String, dynamic> toJson() => {'seq': seq, ...action.toJson()};

  static Move? fromJson(Map<String, dynamic> j) {
    final action = actionFromJson(j);
    return action == null ? null : Move(j['seq'] as int, action);
  }

  @override
  String toString() => '#$seq ${action.toJson()}';
}

abstract class TableLink {
  /// Every move, from every seat, in the order the table plays them.
  Stream<Move> get moves;

  /// An action made on this device: yours, or a courtier's played here.
  void send(Action action);

  /// Every move so far this game, oldest first (for replays, and for a
  /// device that joins late to catch up).
  List<Move> get history;

  /// A new game at the table: the moves start again from the first.
  void reset();

  void dispose();
}

/// Everyone at one table on one device: an action comes straight back,
/// numbered.
class LocalLink implements TableLink {
  final _moves = StreamController<Move>.broadcast(sync: true);
  final _history = <Move>[];

  @override
  Stream<Move> get moves => _moves.stream;

  @override
  List<Move> get history => List.unmodifiable(_history);

  @override
  void send(Action action) {
    final move = Move(_history.length, action);
    _history.add(move);
    _moves.add(move);
  }

  @override
  void reset() => _history.clear();

  @override
  void dispose() => _moves.close();
}
