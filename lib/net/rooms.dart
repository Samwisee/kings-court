/// Rooms: where people meet to play one game on several devices. A room
/// is made from a game's setup by its host and joined by code; each
/// session (one person on one device) takes a seat and gets a link to the
/// table. These are the interfaces a server will implement; [InMemoryRooms]
/// is the one in this process, on the fake network, for tests and for
/// building the screens before there is a server.
library;

import 'dart:async';
import 'dart:math';

import '../game/seats.dart';
import '../game/setup.dart';
import 'fake_network.dart';
import 'table_link.dart';

/// One person on one device.
class Session {
  const Session(this.id, this.name);

  /// Stays the same across reconnections, so a seat can be taken back.
  final String id;
  final String name;
}

abstract class Rooms {
  /// A new room for [setup], hosted by [host], who takes the first seat.
  Future<Room> create(GameSetup setup, Session host);

  /// Joins the room with [code]; null when there's no such room or it's
  /// full. A session that was in the room before gets its seat back.
  Future<Room?> join(String code, Session session);
}

abstract class Room {
  String get code;
  GameSetup get setup;

  /// The session hosting the room: its device runs the courtiers.
  Session get host;

  /// Who sits where, kept up to date.
  Seats get seats;

  /// Every change to the seats (someone sat down, dropped, came back).
  Stream<Seats> get seatChanges;

  /// The link [session] plays through.
  TableLink linkFor(Session session);

  /// [session] leaves for now: its seat is kept, played by the host.
  void drop(Session session);

  /// [session] is back in its seat.
  void rejoin(Session session);

  /// The host starts the game: empty seats go to courtiers.
  void start();
}

/// Rooms in this process, each on its own [FakeNetwork].
class InMemoryRooms implements Rooms {
  InMemoryRooms({Random? rand, FakeNetwork Function()? network})
      : _rand = rand ?? Random(),
        _network = network ?? FakeNetwork.new;

  final Random _rand;
  final FakeNetwork Function() _network;
  final rooms = <String, InMemoryRoom>{};

  @override
  Future<Room> create(GameSetup setup, Session host) async {
    String code;
    do {
      code = List.generate(4, (_) => 'ABCDEFGHJKMNPQRSTUVWXYZ'[_rand.nextInt(23)]).join();
    } while (rooms.containsKey(code));
    final room = InMemoryRoom(code, setup, host, _network());
    rooms[code] = room;
    return room;
  }

  @override
  Future<Room?> join(String code, Session session) async {
    final room = rooms[code];
    if (room == null) return null;
    return room._join(session) ? room : null;
  }
}

class InMemoryRoom implements Room {
  InMemoryRoom(this.code, this.setup, this.host, this.network)
      : seats = Seats(setup.players) {
    seats.sit(host.id, 0);
  }

  @override
  final String code;
  @override
  final GameSetup setup;
  @override
  final Session host;
  @override
  final Seats seats;

  /// The network the room's devices share.
  final FakeNetwork network;

  final _links = <String, FakeLink>{};
  final _changes = StreamController<Seats>.broadcast(sync: true);
  bool started = false;

  @override
  Stream<Seats> get seatChanges => _changes.stream;

  bool _join(Session session) {
    if (seats.seatOf(session.id) != null) {
      rejoin(session);
      return true;
    }
    if (started) return false;
    final seat = seats.firstEmpty;
    if (seat == null) return false;
    seats.sit(session.id, seat);
    _changes.add(seats);
    return true;
  }

  @override
  TableLink linkFor(Session session) =>
      _links.putIfAbsent(session.id, network.connect);

  @override
  void drop(Session session) {
    seats.drop(session.id);
    _links[session.id]?.disconnect();
    _changes.add(seats);
  }

  @override
  void rejoin(Session session) {
    seats.rejoin(session.id);
    _links[session.id]?.reconnect();
    _changes.add(seats);
  }

  @override
  void start() {
    started = true;
    seats.fillWithCourtiers();
    _changes.add(seats);
  }
}
