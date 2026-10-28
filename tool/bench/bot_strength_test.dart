/// How strong the bots are: the same seeded rounds played with random
/// playouts (the first bots) and with guided ones, and how often each wins.
/// Printed as BENCH lines, published with the screenshots. Within one run
/// the comparison is fair; across runs only the seeds are the same.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';

import '../balance/play_round.dart';

void main() {
  test('bot strength', () {
    const rounds = 100;
    for (final (players, target) in [(4, 8), (4, 14)]) {
      final line = StringBuffer('$players players, target $target, $rounds rounds:');
      for (final (name, guided, focus, budget) in [
        ('random 900', false, false, 900),
        ('guided 900', true, false, 900),
        ('guided+focus 900', true, true, 900),
        ('guided+focus 1500', true, true, 1500),
      ]) {
        // The same deals for both: the seed fixes the tasks and the cards.
        var wins = 0;
        final sw = Stopwatch()..start();
        for (int i = 0; i < rounds; i++) {
          final rand = Random(1000 + i);
          final bot = Bot(Random(7))
            ..budget = budget
            ..guided = guided
            ..focus = focus;
          final (won, _, _) = playRound(players, target, rand, bot);
          if (won) wins++;
        }
        sw.stop();
        line.write('  $name ${(wins * 100 / rounds).round()}% (${(sw.elapsedMilliseconds / rounds).round()} ms a round)');
      }
      // ignore: avoid_print
      print('BENCH $line');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
