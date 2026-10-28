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
    const rounds = 80;
    for (final (players, target) in [(4, 8), (4, 14)]) {
      final line = StringBuffer('$players players, target $target, $rounds rounds:');
      for (final (name, guided, strength) in [
        ('random', false, 0.0),
        ('guided 0.6', true, 0.6),
        ('guided 0.8', true, 0.8),
        ('guided 0.9', true, 0.9),
      ]) {
        // The same deals for both: the seed fixes the tasks and the cards.
        var wins = 0;
        final sw = Stopwatch()..start();
        for (int i = 0; i < rounds; i++) {
          final rand = Random(1000 + i);
          final bot = Bot(Random(7))
            ..budget = 400
            ..guided = guided
            ..guidance = strength;
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
