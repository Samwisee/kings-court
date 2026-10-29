/// A table shared with other devices through a room on the game's web
/// service (tool/bug_worker/rooms.js): who sits where, and the link every
/// move goes through. The room numbers each move as it arrives and sends
/// it to every device, so every table plays the same moves in the same
/// order and stays the same (the fake network in fake_network.dart is a
/// stand-in for it in tests).
///
/// The socket itself comes from outside ([RoomSocket], made by the
/// platform), so this stays plain Dart and is tested on a fake. A dropped
/// socket is reopened on its own, asking for the moves after the last one
/// played; moves made meanwhile wait and go when it's back.
///
/// People come and go as they like: someone joining a game under way
/// takes a courtier's seat and catches up on every move so far (they come
/// with the room's hello, so [history] is whole the moment it's open);
/// someone who [leave]s hands their seat back to a courtier.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../engine/round.dart';
import '../game/seats.dart';
import '../game/setup.dart';
import 'table_link.dart';

/// One open connection to a room: text both ways.
abstract class RoomSocket {
  Stream<String> get incoming;
  void send(String text);
  Future<void> close();
}

/// Opens a socket to [uri] (a `wss://` address); throws if it can't.
typedef SocketOpener = Future<RoomSocket> Function(Uri uri);

enum TableStatus {
  /// Opening the room's socket for the first time.
  connecting,

  /// In the room.
  open,

  /// The socket dropped: trying again.
  reconnecting,

  /// Left, or turned away ([OnlineTable.refusal] says why).
  closed,
}

/// Why a room turned this device away.
enum Refusal {
  noRoom('There’s no room with that code.'),
  full('That room is full.'),
  started('That game has already begun.'),
  version('That room is on another version of the game: refresh to update, then try again.'),
  unreachable('The room can’t be reached. Check your connection and try again.'),
  bad('Something went wrong joining the room.');

  const Refusal(this.message);
  final String message;

  static Refusal of(String? why) => switch (why) {
        'no-room' => noRoom,
        'full' => full,
        'started' => started,
        'version' => version,
        _ => bad,
      };
}

class OnlineTable implements TableLink {
  OnlineTable._(this._open, this._service, this.session, this.name, this.build, this._first);

  /// Makes a new room for [setup] on the service at [service] (an
  /// `https://` address); this device hosts it, in seat 0. Completes once
  /// the room has answered (check [refusal]).
  static Future<OnlineTable> create(SocketOpener open, Uri service,
          {required GameSetup setup,
          required String session,
          required String name,
          required String build}) =>
      _connect(OnlineTable._(open, service, session, name, build,
          _address(service, 'new', {'setup': jsonEncode(setup.toJson())})));

  /// Joins the room [code] (or comes back to it, in the same seat).
  static Future<OnlineTable> join(SocketOpener open, Uri service,
          {required String code,
          required String session,
          required String name,
          required String build}) =>
      _connect(OnlineTable._(open, service, session, name, build,
          _address(service, code.trim().toUpperCase(), const {})));

  static Uri _address(Uri service, String room, Map<String, String> extra) => service.replace(
        scheme: service.scheme == 'http' ? 'ws' : 'wss',
        path: '${service.path.replaceAll(RegExp(r'/+$'), '')}/rooms/$room',
        queryParameters: extra,
      );

  static Future<OnlineTable> _connect(OnlineTable t) async {
    await t._openSocket(t._first);
    if (t.status == TableStatus.connecting) {
      // The first message decides: in the room, or why not.
      await t._settled.future.timeout(const Duration(seconds: 15), onTimeout: () {
        t._refuse(Refusal.unreachable);
      });
    }
    return t;
  }

  final SocketOpener _open;
  final Uri _service;

  /// This device, as the room knows it (the same each time, so a seat can
  /// be taken back), and what the others see it called.
  final String session;
  final String name;

  /// The game's build: a room only takes devices on the same one.
  final String build;
  final Uri _first;

  RoomSocket? _socket;
  StreamSubscription<String>? _listening;
  final _settled = Completer<void>();

  TableStatus status = TableStatus.connecting;
  Refusal? refusal;

  /// The room, once in it.
  String code = '';
  GameSetup? setup;
  Seats seats = Seats(0);

  /// What each person is called, by their session.
  Map<String, String> names = const {};

  /// The session hosting: its device plays the courtiers and anyone away.
  String host = '';
  bool started = false;

  /// The seat this device plays.
  int seat = 0;

  bool get hosting => host == session;

  /// Something about the room changed: who's in it, the start, the
  /// connection.
  Stream<void> get changes => _changes.stream;
  final _changes = StreamController<void>.broadcast(sync: true);

  final _moves = StreamController<Move>.broadcast(sync: true);
  final _history = <Move>[];
  final _held = <int, Move>{};

  /// Moves made while the socket was down, sent once it's back.
  final _outbox = <TableAction>[];

  /// The last move played.
  int get lastSeq => _history.isEmpty ? -1 : _history.last.seq;

  @override
  Stream<Move> get moves => _moves.stream;

  @override
  List<Move> get history => List.unmodifiable(_history);

  @override
  void send(TableAction action) {
    if (status == TableStatus.open) {
      _write({'t': 'move', 'a': action.toJson()});
    } else if (status != TableStatus.closed) {
      _outbox.add(action);
    }
  }

  /// The host starts the game: empty seats go to courtiers.
  void start() => _write({'t': 'start'});

  /// Leaves the room for good: a courtier takes the seat.
  Future<void> leave() async {
    if (status == TableStatus.open) _write({'t': 'leave'});
    status = TableStatus.closed;
    _retry?.cancel();
    await _listening?.cancel();
    await _socket?.close();
    if (!_changes.isClosed) _changes.add(null);
  }

  /// The room's moves start again with a new game; nothing to do here (a
  /// room is one game).
  @override
  void reset() {}

  @override
  void dispose() {
    unawaited(leave());
    _moves.close();
    _changes.close();
  }

  void _write(Map<String, dynamic> msg) => _socket?.send(jsonEncode(msg));

  Future<void> _openSocket(Uri uri) async {
    final q = {...uri.queryParameters, 'session': session, 'name': name, 'build': build};
    if (_history.isNotEmpty) q['after'] = '$lastSeq';
    try {
      final s = await _open(uri.replace(queryParameters: q));
      if (status == TableStatus.closed) {
        await s.close();
        return;
      }
      _socket = s;
      _listening = s.incoming.listen(_receive, onDone: _dropped, onError: (_) => _dropped());
    } catch (_) {
      if (!_settled.isCompleted) {
        _refuse(Refusal.unreachable);
      } else {
        _dropped();
      }
    }
  }

  void _receive(String text) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['t']) {
      case 'hello':
        code = msg['code'] as String;
        setup = GameSetup.fromJson(Map<String, dynamic>.from(msg['setup'] as Map));
        seat = msg['seat'] as int;
        _seats(msg);
        // Every move since the last this device played, in order.
        for (final m in (msg['moves'] as List?) ?? const []) {
          if (Move.fromJson(Map<String, dynamic>.from(m as Map)) case final move?) _arrive(move);
        }
        status = TableStatus.open;
        _tries = 0;
        if (!_settled.isCompleted) _settled.complete();
        final waiting = List.of(_outbox);
        _outbox.clear();
        waiting.forEach(send);
        _changes.add(null);
      case 'seats':
        _seats(msg);
        _changes.add(null);
      case 'move':
        final move = Move.fromJson(Map<String, dynamic>.from(msg['m'] as Map));
        if (move != null) _arrive(move);
      case 'error':
        _refuse(Refusal.of(msg['why'] as String?));
    }
  }

  void _seats(Map<String, dynamic> msg) {
    seats = Seats.fromJson(msg['seats'] as List);
    names = {
      for (final e in ((msg['names'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'
    };
    host = (msg['host'] as String?) ?? host;
    started = (msg['started'] as bool?) ?? started;
  }

  /// A move from the room: played in order, once.
  void _arrive(Move move) {
    if (move.seq <= lastSeq) return;
    _held[move.seq] = move;
    while (_held.containsKey(lastSeq + 1)) {
      final next = _held.remove(lastSeq + 1)!;
      _history.add(next);
      _moves.add(next);
    }
  }

  void _refuse(Refusal why) {
    refusal = why;
    status = TableStatus.closed;
    if (!_settled.isCompleted) _settled.complete();
    unawaited(_listening?.cancel());
    unawaited(_socket?.close());
    _changes.add(null);
  }

  Timer? _retry;
  int _tries = 0;

  /// How long to wait before reopening the socket the [n]th time: a
  /// second, then longer, up to fifteen (tests make it nothing).
  static Duration Function(int n) backoff =
      (n) => Duration(milliseconds: min(15000, 1000 * (1 << min(n, 4))));

  void _dropped() {
    if (status == TableStatus.closed) return;
    // Gone before the room said a word: there's no room to go back to.
    if (!_settled.isCompleted) {
      _refuse(Refusal.unreachable);
      return;
    }
    status = TableStatus.reconnecting;
    _socket = null;
    _changes.add(null);
    _retry?.cancel();
    _retry = Timer(backoff(_tries++), () {
      if (status == TableStatus.reconnecting) unawaited(_openSocket(_address(_service, code, const {})));
    });
  }
}
