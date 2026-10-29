/// A room service in this process, answering as the web service's rooms
/// do (tool/bug_worker/rooms.js, which has tests of its own), for tests
/// of online play.
library;

import 'dart:async';
import 'dart:convert';

import 'package:kings_court/game/setup.dart';
import 'package:kings_court/net/online_table.dart';

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
      // Before the start an empty seat; after it a courtier's.
      seat = seats.indexWhere((h) => h['who'] == (started ? 'courtier' : 'empty'));
      if (seat < 0) return end.deliver({'t': 'error', 'why': 'full'});
    }
    seats[seat] = {'who': 'person', 'id': session, 'connected': true};
    names[session] = name;
    ends[session] = end;
    end.onSend = (text) => _message(session, jsonDecode(text) as Map<String, dynamic>);
    end.deliver({
      't': 'hello',
      'code': code,
      'setup': setup.toJson(),
      'seat': seat,
      ..._state(),
      'moves': [for (final m in moves) if (m['seq'] as int > (after ?? -1)) m],
    });
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
      case 'leave':
        final s = seatOf(session);
        if (s < 0) return;
        seats[s] = started ? {'who': 'courtier'} : {'who': 'empty'};
        if (host == session) {
          host = [for (final h in seats) if (h['who'] == 'person' && h['connected'] == true) h['id'] as String]
                  .firstOrNull ??
              host;
        }
        ends.remove(session)?.cut();
        _tellAll({'t': 'seats', ..._state()});
      case 'move':
        final a = msg['a'] as Map<String, dynamic>;
        final seat = a['seat'] as int;
        final h = seats[seat];
        final away = h['who'] != 'person' || h['connected'] == false;
        final own = seat == seatOf(session) || (a['type'] == 'pick' && seatOf(session) >= 0);
        if (!started || (!own && !(session == host && away))) return;
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
