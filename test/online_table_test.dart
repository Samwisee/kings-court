/// A table shared through a room (net/online_table.dart), against a room
/// in this process that answers as the web service's rooms do
/// (tool/bug_worker/rooms.js, which has tests of its own): joining and
/// being turned away, moves in order, reconnecting after a drop, and two
/// devices playing a whole game to the same end.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/game/setup.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/modes/modes.dart';
import 'package:kings_court/net/headless_table.dart';
import 'package:kings_court/net/online_table.dart';

const setup = GameSetup(
    mode: GameMode.free, names: ['Ann', 'Ben', 'Cal', 'Dee'], target: 6, seed: 77, digital: true);
final service = Uri.parse('https://rooms.test');

/// A room service in this process: the rules of rooms.js, in Dart.
class FakeRooms {
  final rooms = <String, FakeRoom>{};
  var _next = 0;

  Future<RoomSocket> open(Uri uri) async {
    final q = uri.queryParameters;
    final end = FakeEnd();
    var code = uri.pathSegments.last;
    if (code == 'new') {
      code = 'R${(_next++).toString().padLeft(3, '0')}';
      final s = GameSetup.fromJson(jsonDecode(q['setup']!) as Map<String, dynamic>);
      rooms[code] = FakeRoom(code, s, q['session']!, q['build']!);
    }
    final room = rooms[code];
    if (room == null) {
      end.deliver({'t': 'error', 'why': 'no-room'});
      return end;
    }
    room.come(end, q['session']!, q['name']!, q['build']!, int.tryParse(q['after'] ?? ''));
    return end;
  }
}

class FakeRoom {
  FakeRoom(this.code, this.setup, this.host, this.build)
      : seats = List.generate(setup.names.length, (_) => {'who': 'empty'});
  final String code;
  final GameSetup setup;
  final String build;
  String host;
  bool started = false;
  final List<Map<String, dynamic>> seats;
  final names = <String, String>{};
  final moves = <Map<String, dynamic>>[];
  final ends = <String, FakeEnd>{};

  int seatOf(String session) => seats.indexWhere((h) => h['who'] == 'person' && h['id'] == session);

  void come(FakeEnd end, String session, String name, String b, int? after) {
    if (b != build) return end.deliver({'t': 'error', 'why': 'version'});
    var seat = seatOf(session);
    if (seat < 0) {
      if (started) return end.deliver({'t': 'error', 'why': 'started'});
      seat = seats.indexWhere((h) => h['who'] == 'empty');
      if (seat < 0) return end.deliver({'t': 'error', 'why': 'full'});
    }
    seats[seat] = {'who': 'person', 'id': session, 'connected': true};
    names[session] = name;
    ends[session] = end;
    end.onSend = (text) => _message(session, jsonDecode(text) as Map<String, dynamic>);
    end.deliver({'t': 'hello', 'code': code, 'setup': setup.toJson(), 'seat': seat, ..._state()});
    for (final m in moves) {
      if (m['seq'] as int > (after ?? -1)) end.deliver({'t': 'move', 'm': m});
    }
    _tellAll({'t': 'seats', ..._state()});
  }

  Map<String, dynamic> _state() =>
      {'seats': seats, 'names': names, 'host': host, 'started': started};

  void _message(String session, Map<String, dynamic> msg) {
    switch (msg['t']) {
      case 'start':
        if (session != host) return;
        for (var s = 0; s < seats.length; s++) {
          if (seats[s]['who'] == 'empty') seats[s] = {'who': 'courtier'};
        }
        started = true;
        _tellAll({'t': 'seats', ..._state()});
      case 'move':
        final a = msg['a'] as Map<String, dynamic>;
        final seat = a['seat'] as int;
        final h = seats[seat];
        final away = h['who'] != 'person' || h['connected'] == false;
        if (!started || (seat != seatOf(session) && !(session == host && away))) return;
        final m = {...a, 'seq': moves.length};
        moves.add(m);
        _tellAll({'t': 'move', 'm': m});
    }
  }

  void _tellAll(Map<String, dynamic> msg) {
    for (final e in ends.values) {
      if (!e.closed) e.deliver(msg);
    }
  }

  /// The network drops [session]'s socket.
  void drop(String session) {
    ends.remove(session)?.cut();
    final s = seatOf(session);
    seats[s] = {...seats[s], 'connected': false};
    _tellAll({'t': 'seats', ..._state()});
  }
}

/// The device's end of a socket to a fake room.
class FakeEnd implements RoomSocket {
  final _in = StreamController<String>();
  void Function(String text)? onSend;
  bool closed = false;
  final sent = <Map<String, dynamic>>[];

  void deliver(Map<String, dynamic> msg) => _in.add(jsonEncode(msg));
  void cut() {
    closed = true;
    _in.close();
  }

  @override
  Stream<String> get incoming => _in.stream;
  @override
  void send(String text) {
    sent.add(jsonDecode(text) as Map<String, dynamic>);
    if (!closed) onSend?.call(text);
  }

  @override
  Future<void> close() async {
    if (!closed) cut();
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  final waits = OnlineTable.backoff;
  setUp(() => OnlineTable.backoff = (_) => Duration.zero);

  test('The creator hosts in seat 0; others join by code, in the next seat', () async {
    final rooms = FakeRooms();
    final ann = await OnlineTable.create(rooms.open, service,
        setup: setup, session: 'ann', name: 'Ann', build: 'b1');
    expect(ann.status, TableStatus.open);
    expect(ann.seat, 0);
    expect(ann.hosting, isTrue);
    expect(ann.setup!.seed, 77);
    final ben = await OnlineTable.join(rooms.open, service,
        code: ann.code.toLowerCase(), session: 'ben', name: 'Ben', build: 'b1');
    await settle();
    expect(ben.seat, 1);
    expect(ben.hosting, isFalse);
    expect(ann.names['ben'], 'Ben', reason: 'the host hears who came in');
    expect(ann.seats.present(1), isTrue);
  });

  test('A room that can’t be joined says why', () async {
    final rooms = FakeRooms();
    final none = await OnlineTable.join(rooms.open, service, code: 'ZZZZ', session: 's', name: 'S', build: 'b1');
    expect((none.status, none.refusal), (TableStatus.closed, Refusal.noRoom));
    final ann = await OnlineTable.create(rooms.open, service, setup: setup, session: 'ann', name: 'Ann', build: 'b1');
    final old = await OnlineTable.join(rooms.open, service, code: ann.code, session: 'x', name: 'X', build: 'b0');
    expect(old.refusal, Refusal.version);
    expect(old.refusal!.message, contains('refresh'));
    ann.start();
    await settle();
    final late = await OnlineTable.join(rooms.open, service, code: ann.code, session: 'y', name: 'Y', build: 'b1');
    expect(late.refusal, Refusal.started);
    final gone = await OnlineTable.join((_) => throw Exception('offline'), service,
        code: ann.code, session: 'z', name: 'Z', build: 'b1');
    expect(gone.refusal, Refusal.unreachable);
  });

  test('Moves come back numbered, in order; made while away, they wait and go on return', () async {
    final rooms = FakeRooms();
    final ann = await OnlineTable.create(rooms.open, service, setup: setup, session: 'ann', name: 'Ann', build: 'b1');
    final ben = await OnlineTable.join(rooms.open, service, code: ann.code, session: 'ben', name: 'Ben', build: 'b1');
    ann.start();
    await settle();
    expect(ben.started, isTrue);
    ann.send(const Pass(0));
    ben.send(const Pass(1));
    await settle();
    expect(ann.history.map((m) => m.seq), [0, 1]);
    expect(ben.history.map((m) => m.action.toJson()), ann.history.map((m) => m.action.toJson()));
    // Ben's connection drops; the room carries on; Ben's move waits.
    rooms.rooms[ann.code]!.drop('ben');
    await settle();
    expect(ben.status, isNot(TableStatus.open));
    ann.send(const Pass(0));
    ben.send(const Pass(1));
    await settle();
    await settle();
    // Back: the move he missed came in, then his went.
    expect(ben.status, TableStatus.open);
    expect(ben.history.map((m) => m.seq), [0, 1, 2, 3]);
    expect(ben.history.last.action.seat, 1);
    expect(ann.history.length, 4);
  });

  test('Two devices play a whole game through a room to the same end, one dropping for a while', () async {
    final rooms = FakeRooms();
    final rules = modeOf(GameMode.free).rules;
    final annLink = await OnlineTable.create(rooms.open, service, setup: setup, session: 'ann', name: 'Ann', build: 'b1');
    final benLink = await OnlineTable.join(rooms.open, service, code: annLink.code, session: 'ben', name: 'Ben', build: 'b1');
    annLink.start();
    await settle();
    final gameA = annLink.setup!.start(rules);
    final gameB = benLink.setup!.start(rules, you: benLink.seat);
    final a = HeadlessTable(gameA, annLink, rules, you: 0, seats: annLink.seats, bot: Bot()..budget = 24);
    final b = HeadlessTable(gameB, benLink, rules,
        you: 1, seats: benLink.seats, host: false, bot: Bot()..budget = 24);
    // The host's courtiers play by the room's seats as they change.
    annLink.changes.listen((_) => a.courtiers.seats = annLink.seats);
    var benMoves = 0;
    var dropped = false;
    for (var i = 0; i < 3000; i++) {
      if (gameA.outcome != RoundOutcome.inProgress && gameB.outcome != RoundOutcome.inProgress) break;
      await a.step();
      await a.playAs(0);
      if (benLink.status == TableStatus.open && await b.playAs(1)) benMoves++;
      if (benMoves == 3 && !dropped) {
        dropped = true;
        rooms.rooms[annLink.code]!.drop('ben');
      }
      await settle();
    }
    await settle();
    expect(dropped, isTrue);
    expect(gameA.outcome, isNot(RoundOutcome.inProgress));
    expect(gameB.outcome, gameA.outcome);
    // The same round, but for how a failure is worded to each player ("You
    // won trick 5" on one device is "The Bishop won trick 5" on another).
    String round(GameState g) => jsonEncode(g.round!.toJson()).replaceAll(RegExp(r',"why":"[^"]*"'), '');
    expect(round(gameB), round(gameA));
    expect(benLink.history.length, annLink.history.length);
    expect(a.refused.map((m) => m.toJson()), b.refused.map((m) => m.toJson()));
    a.dispose();
    b.dispose();
  });

  test('Reconnecting waits a little longer each time, up to fifteen seconds', () {
    expect([for (var n = 0; n < 6; n++) waits(n).inSeconds], [1, 2, 4, 8, 15, 15]);
  });
}
