/// Rooms (net/rooms.dart): made by a host, joined by code, seats taken,
/// kept through a drop and given back, and a game played through the
/// room's links.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/game/seats.dart';
import 'package:kings_court/game/setup.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/modes/modes.dart';
import 'package:kings_court/net/fake_network.dart';
import 'package:kings_court/net/headless_table.dart';
import 'package:kings_court/net/rooms.dart';

const setup = GameSetup(
    mode: GameMode.free, names: ['Ann', 'Ben', 'Cal', 'Dee'], target: 5, seed: 5, digital: true);

const ann = Session('ann', 'Ann');
const ben = Session('ben', 'Ben');
const cal = Session('cal', 'Cal');

void main() {
  test('A room is made, joined by code, filled, and kept through a drop', () async {
    final rooms = InMemoryRooms(rand: Random(1));
    final room = await rooms.create(setup, ann);
    expect(room.code, hasLength(4));
    expect(room.seats.seatOf('ann'), 0);
    expect(await rooms.join('NOPE', ben), isNull);
    final changes = <List<SeatHolder>>[];
    room.seatChanges.listen((s) => changes.add(List.of(s.holders)));
    expect(await rooms.join(room.code, ben), same(room));
    expect(room.seats.seatOf('ben'), 1);
    expect(changes, hasLength(1));
    // The game starts: the empty seats are the courtiers'.
    room.start();
    expect(room.seats.holders.skip(2), everyElement(isA<CourtierSeat>()));
    expect(await rooms.join(room.code, cal), isNull, reason: 'started, and full');
    // Ben drops: his seat is kept, played by the host; back, it's his.
    room.drop(ben);
    expect(room.seats.hostPlays(1), isTrue);
    expect(room.seats.present(1), isFalse);
    expect(await rooms.join(room.code, ben), same(room), reason: 'his seat again');
    expect(room.seats.present(1), isTrue);
    expect(room.seats.hostPlays(1), isFalse);
    // Seats travel as JSON.
    final back = Seats.fromJson(jsonDecode(jsonEncode(room.seats.toJson())) as List);
    expect(back.holders, room.seats.holders);
  });

  test('A game is played through the room’s links', () async {
    final rooms = InMemoryRooms(
        rand: Random(2), network: () => FakeNetwork(rand: Random(2)));
    final room = await rooms.create(setup, ann);
    await rooms.join(room.code, ben);
    room.start();
    final rules = modeOf(GameMode.free).rules;
    final gameA = setup.start(rules);
    final gameB = setup.start(rules, you: 1);
    final a = HeadlessTable(gameA, room.linkFor(ann), rules, you: 0, seats: room.seats, bot: Bot()..budget = 24);
    final b = HeadlessTable(gameB, room.linkFor(ben), rules,
        you: 1, seats: room.seats, host: false, bot: Bot()..budget = 24);
    final net = (room as InMemoryRoom).network;
    for (var i = 0; i < 2000; i++) {
      final over = gameA.outcome != RoundOutcome.inProgress &&
          gameB.outcome != RoundOutcome.inProgress;
      if (over && !net.busy) break;
      await a.step();
      await a.playAs(0);
      await b.playAs(1);
      net.tick();
    }
    expect(gameA.outcome, isNot(RoundOutcome.inProgress));
    expect(jsonEncode(gameB.round!.toJson()), jsonEncode(gameA.round!.toJson()));
    expect(a.refused, isEmpty);
    expect(b.refused, isEmpty);
    a.dispose();
    b.dispose();
  });
}
