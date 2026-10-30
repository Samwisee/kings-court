/// How fast the bots think. Not a test of anything: it prints timings,
/// which CI publishes to the `shots` branch as bench.txt (see
/// .github/workflows/shots.yml). Run it by hand with
/// `flutter test test/tool/bot_bench_test.dart`.
///
/// It plays the same seeded rounds every time, so one run compares with
/// the last: playouts a second (the engine's speed), and how much longer
/// the slice-at-a-time version takes than thinking straight through (the
/// time given back to the screen, which should be small).
@Tags(['tool'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/round.dart';

void main() {
  test('bot timings', () async {
    final out = StringBuffer();
    void say(String s) {
      out.writeln(s);
      // The timings are the output: printed, for CI to collect.
      // ignore: avoid_print
      print('BENCH $s');
    }

    for (final players in [3, 4, 5]) {
      // A fresh, fixed deal each time, so the numbers mean the same thing
      // run to run.
      Round fresh() => Round(players: players, target: 6)..newRound(Random(11 + players));
      // Everyone takes a task, round-robin from the King.
      void settle(Round s) {
        while (s.phase == Phase.picking) {
          final seat = s.pickTurn!;
          final i = List.generate(s.tasks.length, (t) => t)
              .firstWhere((t) => s.canTake(t, seat), orElse: () => -1);
          if (i < 0) break;
          s.apply(PickTask(seat, i));
        }
        for (var i = 0; i < s.tasks.length; i++) {
          if (s.tasks[i].x == null && s.phase == Phase.announcing) s.apply(Announce(s.tasks[i].owner!, i, 2));
        }
      }

      const budget = 900;
      final s = fresh();
      settle(s);
      // Raw speed: every decision spends the budget (adaptive thinking would
      // stop some early and stretch others, and the count below assumes not).
      final bot = Bot(Random(1))
        ..budget = budget
        ..adaptive = false;
      final legal = s.legalFor(s.turn).length;

      // Straight through.
      final sw = Stopwatch()..start();
      for (var i = 0; i < 3; i++) {
        bot.choosePlay(s, s.turn);
      }
      sw.stop();
      final syncMs = sw.elapsedMilliseconds / 3;

      // A slice at a time, as the game does it.
      sw
        ..reset()
        ..start();
      for (var i = 0; i < 3; i++) {
        await bot.choosePlayAsync(s, s.turn);
      }
      sw.stop();
      final asyncMs = sw.elapsedMilliseconds / 3;

      // Picking (every option scored) and announcing.
      final p = fresh();
      sw
        ..reset()
        ..start();
      bot.choosePick(p, p.pickTurn!);
      sw.stop();
      final pickMs = sw.elapsedMilliseconds;

      final playouts = max(20, budget ~/ legal) * legal;
      say('$players players: ${s.tasks.length} tasks, $legal legal plays, '
          '$playouts playouts: play ${syncMs.toStringAsFixed(0)} ms '
          '(${(playouts / max(1, syncMs) * 1000).round()} playouts/s), '
          'sliced ${asyncMs.toStringAsFixed(0)} ms '
          '(+${(asyncMs - syncMs).toStringAsFixed(0)} ms), pick $pickMs ms');
    }
    expect(out.isNotEmpty, isTrue);
  });
}
