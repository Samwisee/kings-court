/// A table shared through a room (net/online_table.dart), against a room
/// in this process that answers as the web service's rooms do
/// (tool/bug_worker/rooms.js, which has tests of its own): joining and
/// being turned away, moves in order, reconnecting after a drop, and two
/// devices playing a whole game to the same end.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/game/seats.dart';
import 'package:kings_court/game/setup.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/modes/modes.dart';
import 'package:kings_court/net/headless_table.dart';
import 'package:kings_court/net/online_table.dart';
import 'package:kings_court/net/replay.dart';

import 'fake_rooms.dart';

const setup = GameSetup(
    mode: GameMode.free, names: ['Ann', 'Ben', 'Cal', 'Dee'], target: 6, seed: 77, digital: true);
final service = Uri.parse('https://rooms.test');

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
    final ben = await OnlineTable.join(rooms.open, service, code: ann.code, session: 'ben', name: 'Ben', build: 'b1');
    final cal = await OnlineTable.join(rooms.open, service, code: ann.code, session: 'cal', name: 'Cal', build: 'b1');
    final dee = await OnlineTable.join(rooms.open, service, code: ann.code, session: 'dee', name: 'Dee', build: 'b1');
    final full = await OnlineTable.join(rooms.open, service, code: ann.code, session: 'y', name: 'Y', build: 'b1');
    expect(full.refusal, Refusal.full);
    expect([ben.seat, cal.seat, dee.seat], [1, 2, 3]);
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
    String round(GameState g) => jsonEncode(g.round!.toJson()).replaceAll(RegExp(',"why":"[^"]*"'), '');
    expect(round(gameB), round(gameA));
    expect(benLink.history.length, annLink.history.length);
    expect(a.refused.map((m) => m.toJson()), b.refused.map((m) => m.toJson()));
    a.dispose();
    b.dispose();
  });

  test('Someone can join a game under way, caught up, in a courtier’s seat, and leave it to one', () async {
    final rooms = FakeRooms();
    final rules = modeOf(GameMode.free).rules;
    final ann = await OnlineTable.create(rooms.open, service, setup: setup, session: 'ann', name: 'Ann', build: 'b1');
    ann.start();
    await settle();
    final game = ann.setup!.start(rules);
    final a = HeadlessTable(game, ann, rules, you: 0, seats: ann.seats, bot: Bot()..budget = 16);
    ann.changes.listen((_) => a.courtiers.seats = ann.seats);
    for (var i = 0; i < 12; i++) {
      await a.step();
      await a.playAs(0);
      await settle();
    }
    expect(ann.history, isNotEmpty);
    final cal = await OnlineTable.join(rooms.open, service, code: ann.code, session: 'cal', name: 'Cal', build: 'b1');
    await settle();
    expect(cal.started, isTrue);
    expect(cal.seats.holders[cal.seat], isA<Person>());
    expect(ann.seats.holders[cal.seat], isA<Person>(), reason: 'the host stops playing it');
    expect(cal.history.map((m) => m.toJson()), ann.history.map((m) => m.toJson()),
        reason: 'every move so far, the moment Cal is in');
    // The game Cal's device rebuilds is the one on the table.
    final caught = replay(cal.setup!, cal.history, rules: rules, you: cal.seat);
    String round(GameState g) => jsonEncode(g.round!.toJson()).replaceAll(RegExp(',"why":"[^"]*"'), '');
    expect(round(caught), round(game));
    await cal.leave();
    await settle();
    expect(ann.seats.holders[cal.seat], isA<CourtierSeat>(), reason: 'a courtier plays on');
    a.dispose();
  });

  test('Played ahead, a move shows at once and isn’t played twice; another’s first starts again', () async {
    final rooms = FakeRooms();
    final ann = await OnlineTable.create(rooms.open, service, setup: setup, session: 'ann', name: 'Ann', build: 'b1');
    final ben = await OnlineTable.join(rooms.open, service, code: ann.code, session: 'ben', name: 'Ben', build: 'b1');
    ann.start();
    await settle();
    ann.playAhead = true;
    final played = <String>[];
    var rebuilt = 0;
    ann.moves.listen((m) => played.add(m.action.toJson()['type'] as String));
    ann.rebuilt.listen((_) => rebuilt++);
    ann.send(const Pass(0));
    expect(played, ['pass'], reason: 'at once, before the room answers');
    expect(ann.history, isEmpty);
    await settle();
    expect(played, ['pass'], reason: 'its echo isn’t played again');
    expect(ann.history.map((m) => m.seq), [0]);
    // Ben's move reaches the room first; Ann's, played ahead, comes after.
    ben.send(const Ready(1));
    ann.send(const Ready(0));
    expect(played, ['pass', 'ready']);
    await settle();
    expect(rebuilt, 1, reason: 'the room put Ben’s first');
    expect(ann.history.map((m) => m.action.seat), [0, 1, 0]);
    // From there the moves come as anyone's: Ann's own again, in its place.
    expect(played, ['pass', 'ready', 'ready']);
    // A move this device may not make (Ben's) isn't played ahead.
    ann.send(const Pass(1));
    expect(played.length, 3);
  });

  test('Reconnecting waits a little longer each time, up to fifteen seconds', () {
    expect([for (var n = 0; n < 6; n++) waits(n).inSeconds], [1, 2, 4, 8, 15, 15]);
  });
}
