/// How strong the bots are: the same seeded rounds played by bots of
/// different settings, and how often each wins. Also whether showing a card
/// changes a fair bot's play: at some plays made after a card was shown this
/// round, the same bot is asked again with the shown cards forgotten, and
/// (for comparison) asked again with the cards remembered.
///
/// STRENGTH_CONFIGS names the bots to compare, comma-separated, each a
/// colon-separated list of settings: `seeing` or `fair`, `s<samples>`,
/// `b<budget>`, `unpaired`, `unfocused`, `unguided`, and `noshow` (nobody
/// shows a card all round, to see what showing is worth). STRENGTH_ROUNDS is
/// the rounds per table. Printed as BENCH lines; the Screenshots workflow
/// runs a short version, the Strength workflow a long one.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/engine/sampling.dart';

import '../balance/play_round.dart';

Bot botFor(String config, Random rand) {
  final bot = Bot(rand);
  for (final part in config.split(':')) {
    if (part == 'seeing') bot.omniscient = true;
    if (part == 'fair') bot.omniscient = false;
    if (part == 'unpaired') bot.paired = false;
    if (part == 'unfocused') bot.focus = false;
    if (part == 'unguided') bot.guided = false;
    if (part.startsWith('s')) bot.samples = int.tryParse(part.substring(1)) ?? bot.samples;
    if (part.startsWith('b')) bot.budget = int.tryParse(part.substring(1)) ?? bot.budget;
  }
  return bot;
}

void main() {
  test('bot strength', () {
    final rounds = int.tryParse(Platform.environment['STRENGTH_ROUNDS'] ?? '') ?? 100;
    final configs = (Platform.environment['STRENGTH_CONFIGS'] ?? 'seeing:b900,fair:s8:b900').split(',');
    for (final (players, target) in [(4, 10), (4, 14)]) {
      final line = StringBuffer('$players players, target $target, $rounds rounds:');
      final shown = StringBuffer();
      for (final config in configs) {
        var afterShow = 0, changed = 0, noise = 0;
        // The same deals for every bot: the seed fixes the tasks and cards.
        var wins = 0;
        final sw = Stopwatch()..start();
        for (int i = 0; i < rounds; i++) {
          final rand = Random(1000 + i);
          final bot = botFor(config, Random(7));
          // At some fair plays made after a card was shown: the same
          // decision with the shown cards forgotten, and the same decision
          // thought through again.
          void check(MatchState s, int seat, PlayingCard card) {
            if (s.revealed.isEmpty) return;
            afterShow++;
            final forgot = worldWith(s, s.hands)
              ..revealed = <int, PlayingCard>{}
              ..revealHint = <int, String>{};
            final seed = 100 + afterShow;
            final a = botFor(config, Random(seed)).choosePlay(s, seat);
            final b = botFor(config, Random(seed)).choosePlay(forgot, seat);
            if (a != b) changed++;
            final c = botFor(config, Random(seed + 1)).choosePlay(s, seat);
            if (a != c) noise++;
          }

          final (won, _, _) = playRound(players, target, rand, bot,
              onPlay: bot.omniscient || i % 5 != 0 ? null : check,
              showing: !config.split(':').contains('noshow'));
          if (won) wins++;
        }
        sw.stop();
        line.write('  [$config] ${(wins * 100 / rounds).round()}% (${(sw.elapsedMilliseconds / rounds).round()} ms a round)');
        if (afterShow > 0) {
          shown.write('  [$config] of $afterShow plays after a card was shown, '
              '${(changed * 100 / afterShow).round()}% change without it, '
              '${(noise * 100 / afterShow).round()}% change on rethinking');
        }
      }
      // ignore: avoid_print
      print('BENCH $line');
      // ignore: avoid_print
      if (shown.isNotEmpty) print('BENCH   shown cards:$shown');
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
