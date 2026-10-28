/// How strong the bots are: the same seeded rounds played by all-seeing
/// bots (the courtiers until today) and by fair ones that see only their
/// own hand, and how often each wins. Also whether showing a card changes
/// a fair bot's play: at every play made after a card was shown this
/// round, the same bot is asked again with the shown cards forgotten.
/// Printed as BENCH lines, published with the screenshots.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/sampling.dart';

import '../balance/play_round.dart';

void main() {
  test('bot strength', () {
    const rounds = 300;
    for (final (players, target) in [(4, 10), (4, 14)]) {
      final line = StringBuffer('$players players, target $target, $rounds rounds:');
      var afterShow = 0, changed = 0, noise = 0;
      for (final (name, omniscient) in [
        ('all-seeing (before)', true),
        ('fair (now)', false),
      ]) {
        // The same deals for both: the seed fixes the tasks and the cards.
        var wins = 0;
        final sw = Stopwatch()..start();
        for (int i = 0; i < rounds; i++) {
          final rand = Random(1000 + i);
          final bot = Bot(Random(7))
            ..budget = 900
            ..omniscient = omniscient;
          final (won, _, _) = playRound(players, target, rand, bot,
              onPlay: omniscient || i % 5 != 0
                  ? null
                  : (s, seat, card) {
                      if (s.revealed.isEmpty) return;
                      // The same decision with the shown cards forgotten.
                      afterShow++;
                      final forgot = worldWith(s, s.hands)
                        ..revealed = {}
                        ..revealHint = {};
                      final seed = 100 + afterShow;
                      final a = (Bot(Random(seed))..budget = 900).choosePlay(s, seat);
                      final b = (Bot(Random(seed))..budget = 900).choosePlay(forgot, seat);
                      if (a != b) changed++;
                      // How often the same decision differs just from
                      // thinking again, for comparison.
                      final c = (Bot(Random(seed + 1))..budget = 900).choosePlay(s, seat);
                      if (a != c) noise++;
                    });
          if (won) wins++;
        }
        sw.stop();
        line.write('  $name ${(wins * 100 / rounds).round()}% (${(sw.elapsedMilliseconds / rounds).round()} ms a round)');
      }
      // ignore: avoid_print
      print('BENCH $line');
      // ignore: avoid_print
      print('BENCH   shown cards: of $afterShow plays made after a card was shown, '
          '${afterShow == 0 ? 0 : (changed * 100 / afterShow).round()}% would have been different without it '
          '(${afterShow == 0 ? 0 : (noise * 100 / afterShow).round()}% differ just from thinking again)');
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
