/// Where the moves of a game go.
///
/// Every move a player makes at the table (playing a card, showing one) is
/// a [MatchAction]: plain data that turns into JSON and back. The table
/// never changes the cards itself; it [TableLink.send]s the move, and
/// changes the cards when the move comes back on [TableLink.moves].
///
/// Today the link is [LocalLink]: everything is played on this device, so
/// a move comes straight back, at once. For online play, a network link
/// takes its place: it sends each move to the server, and every device
/// plays the moves the server sends back, in the same order, so every
/// table stays the same. Nothing else in the game needs to change.
library;

import 'dart:async';

import '../engine/round.dart';

abstract class TableLink {
  /// Every move, from every seat, in the order the table plays them.
  Stream<MatchAction> get moves;

  /// A move made on this device: yours, or a courtier's played here.
  void send(MatchAction move);

  /// Every move so far this session, oldest first (for replays, and for a
  /// device that joins late to catch up).
  List<MatchAction> get history;

  void dispose();
}

/// Everyone at one table on one device: a move comes straight back.
class LocalLink implements TableLink {
  final _moves = StreamController<MatchAction>.broadcast(sync: true);
  final _history = <MatchAction>[];

  @override
  Stream<MatchAction> get moves => _moves.stream;

  @override
  List<MatchAction> get history => List.unmodifiable(_history);

  @override
  void send(MatchAction move) {
    _history.add(move);
    _moves.add(move);
  }

  @override
  void dispose() => _moves.close();
}
