/// One round played by bots alone, as the balance report and the bot
/// strength benchmark play them: lib/sim/self_play.dart's, as the
/// (won, failed tasks, tasks dealt) these tools read.
library;

import 'dart:math';

import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/sim/self_play.dart' as sim;

(bool, List<String>, List<String>) playRound(int players, int target, Random rand, Bot bot,
    {void Function(Round s, int seat, PlayingCard card)? onPlay, bool showing = true}) {
  final played = sim.playRound(players, target, rand, bot, onPlay: onPlay, showing: showing);
  return (played.won, played.failed, played.dealt);
}
