/// Two devices at one table, over a network that delays, reorders and
/// repeats the moves, and loses one device for a while: both end with the
/// same game. The host's courtiers play the empty seats and a dropped
/// person's; the person who returns catches up and plays on.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/game/seats.dart';
import 'package:kings_court/game/setup.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/modes/modes.dart';
import 'package:kings_court/net/fake_network.dart';
import 'package:kings_court/net/headless_table.dart';

const setup = GameSetup(
    mode: GameMode.free,
    names: ['Ann', 'Ben', 'Court', 'Court'],
    target: 6,
    seed: 77,
    digital: true);

String roundOf(GameState g) => jsonEncode(g.round!.toJson());

void main() {
  test('A link hands its table the moves in order, each once, however they arrive', () {
    final net = FakeNetwork(rand: Random(5), maxLatency: 3, duplicateOneIn: 2);
    final a = net.connect();
    final b = net.connect();
    final seen = <int>[];
    b.moves.listen((m) => seen.add(m.seq));
    for (var i = 0; i < 12; i++) {
      a.send(PickTask(0, i));
    }
    net.deliver();
    expect(seen, List.generate(12, (i) => i));
    expect(b.history.map((m) => (m.action as PickTask).task), List.generate(12, (i) => i));
    expect(a.history.length, 12);
    // Dropped off: nothing arrives, and what's sent is lost. Back on:
    // everything missed comes in, in order.
    b.disconnect();
    a.send(const Pass(0));
    b.send(const Pass(1));
    net.deliver();
    expect(seen.length, 12);
    expect(net.lost, 1);
    b.reconnect();
    expect(seen.length, 13);
    expect(b.history.last.action, isA<Pass>());
    expect(net.table.length, 13);
  });

  test('Two devices end with the same game, one of them having dropped out for a while', () async {
    final rules = modeOf(GameMode.free).rules;
    final net = FakeNetwork(rand: Random(3), maxLatency: 3, duplicateOneIn: 4);
    final seats = Seats.of([
      const Person('ann'),
      const Person('ben'),
      const CourtierSeat(),
      const CourtierSeat(),
    ]);
    final linkA = net.connect();
    final linkB = net.connect();
    final gameA = setup.start(rules);
    final gameB = setup.start(rules, you: 1);
    final a = HeadlessTable(gameA, linkA, rules, you: 0, seats: seats, bot: Bot()..budget = 24);
    final b = HeadlessTable(gameB, linkB, rules,
        you: 1, seats: seats, host: false, bot: Bot()..budget = 24);

    var benMoves = 0;
    var dropped = false;
    var back = false;
    for (var i = 0; i < 3000; i++) {
      final overA = gameA.outcome != RoundOutcome.inProgress;
      final overB = gameB.outcome != RoundOutcome.inProgress;
      if (overA && overB && !net.busy) break;
      await a.step();
      if (!overA) await a.playAs(0);
      if (!overB && !dropped) {
        if (await b.playAs(1)) benMoves++;
      }
      // Ben drops after his third move, and is back a while later.
      if (benMoves == 3 && !dropped && !back) {
        dropped = true;
        linkB.disconnect();
        seats.drop('ben');
      }
      if (dropped && !back && linkA.history.length >= benMoves + 25) {
        linkB.reconnect();
        seats.rejoin('ben');
        b.resync();
        dropped = false;
        back = true;
      }
      net.tick();
    }
    net.deliver();
    expect(back, isTrue, reason: 'Ben came back');
    expect(gameA.outcome, isNot(RoundOutcome.inProgress));
    expect(gameB.outcome, gameA.outcome);
    // A move Ben sent as he dropped may race the host playing his seat;
    // whichever came second, both tables let the same ones go.
    expect([for (final m in b.refused) m.toJson()], [for (final m in a.refused) m.toJson()]);
    expect(linkA.history.length, net.table.length);
    expect(linkB.history.length, net.table.length);
    expect(roundOf(gameB), roundOf(gameA));
    expect(gameB.wins, gameA.wins);
    expect(gameB.losses, gameA.losses);
    // Ben's seat was played while he was away, and by him after.
    final bySeat1 = net.table.where((m) => m.action.seat == 1).length;
    expect(bySeat1, greaterThan(benMoves));
    a.dispose();
    b.dispose();
  });
}
