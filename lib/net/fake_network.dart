/// Several devices at one table, joined by a network that behaves like
/// one. Each device holds a [FakeLink]; the [FakeNetwork] is the server
/// between them: it numbers each action as it arrives and sends every
/// move to every device, late, out of order, twice, or not at all while a
/// device is disconnected. A device that reconnects asks for everything
/// after the last move it saw. A link only ever hands its table the moves
/// in order, each once, so the tables stay the same; the two-device test
/// proves it.
///
/// Time is a tick: nothing moves until [tick] (or [deliver], every tick
/// until quiet), so a test is exact.
library;

import 'dart:async';
import 'dart:math';

import '../engine/round.dart';
import 'table_link.dart';

class FakeNetwork {
  /// [latency] is how many ticks a packet takes, at most ([maxLatency]);
  /// with [reorder] packets may overtake each other, with [duplicates]
  /// one in [duplicateOneIn] arrives twice. [rand] decides which.
  FakeNetwork(
      {Random? rand,
      this.maxLatency = 2,
      this.reorder = true,
      this.duplicateOneIn = 0})
      : rand = rand ?? Random(1);

  final Random rand;
  final int maxLatency;
  final bool reorder;
  final int duplicateOneIn;

  /// The server's record: every move, in the order it arrived.
  final table = <Move>[];

  final links = <FakeLink>[];

  /// Packets on their way: the link they go to, the move, and the tick
  /// they arrive.
  final _packets = <_Packet>[];
  int _now = 0;

  /// Actions sent while disconnected, counted (they're lost).
  int lost = 0;

  /// A new device at the table.
  FakeLink connect() {
    final link = FakeLink._(this);
    links.add(link);
    return link;
  }

  /// A device's action reaches the server: numbered and sent to everyone.
  void _receive(FakeLink from, TableAction action) {
    if (!from.connected) {
      lost++;
      return;
    }
    final move = Move(table.length, action);
    table.add(move);
    for (final link in links) {
      _post(link, move);
    }
  }

  void _post(FakeLink link, Move move) {
    final copies = duplicateOneIn > 0 && rand.nextInt(duplicateOneIn) == 0 ? 2 : 1;
    for (var c = 0; c < copies; c++) {
      final delay = maxLatency == 0 ? 0 : 1 + rand.nextInt(maxLatency);
      _packets.add(_Packet(link, move, _now + delay));
    }
  }

  /// A tick of time: every packet due arrives (in a shuffled order, when
  /// the network reorders).
  void tick() {
    _now++;
    final due = [for (final p in _packets) if (p.at <= _now) p];
    _packets.removeWhere((p) => p.at <= _now);
    if (reorder) due.shuffle(rand);
    for (final p in due) {
      if (p.link.connected) p.link._arrive(p.move);
    }
  }

  /// Ticks until nothing is on its way.
  void deliver() {
    var guard = 0;
    while (_packets.isNotEmpty && guard++ < 1000) {
      tick();
    }
  }

  /// Whether anything is still on its way.
  bool get busy => _packets.isNotEmpty;

  /// The moves after [seq], for a device catching up.
  List<Move> since(int seq) => [for (final m in table) if (m.seq > seq) m];
}

class _Packet {
  _Packet(this.link, this.move, this.at);
  final FakeLink link;
  final Move move;
  final int at;
}

/// One device's end of the network.
class FakeLink implements TableLink {
  FakeLink._(this.network);
  final FakeNetwork network;

  final _moves = StreamController<Move>.broadcast(sync: true);
  final _history = <Move>[];

  /// Moves that arrived early, waiting for the ones before them.
  final _held = <int, Move>{};

  bool connected = true;

  /// The last move this device has played.
  int get lastSeq => _history.isEmpty ? -1 : _history.last.seq;

  @override
  Stream<Move> get moves => _moves.stream;

  @override
  List<Move> get history => List.unmodifiable(_history);

  @override
  void send(TableAction action) => network._receive(this, action);

  /// A move from the network: played in order, once; an early one waits
  /// for the gap before it to fill, a repeat is dropped.
  void _arrive(Move move) {
    if (move.seq <= lastSeq) return; // seen already
    _held[move.seq] = move;
    while (_held.containsKey(lastSeq + 1)) {
      final next = _held.remove(lastSeq + 1)!;
      _history.add(next);
      _moves.add(next);
    }
  }

  /// The device drops off: nothing reaches it, and what it sends is lost.
  void disconnect() => connected = false;

  /// Back on: everything missed comes in, in order.
  void reconnect() {
    connected = true;
    for (final m in network.since(lastSeq)) {
      _arrive(m);
    }
  }

  @override
  void reset() {
    _history.clear();
    _held.clear();
  }

  @override
  void dispose() => _moves.close();
}
