/// One round played by bots alone, as the balance report and the bot
/// strength benchmark play them.
library;

import 'dart:math';

import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/conflicts.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/models.dart';

/// Plays one round with bots; returns whether it was won, which tasks
/// failed, and the tasks dealt.
(bool, List<String>, List<String>) playRound(int players, int target, Random rand, Bot bot) {
  // The seed from [rand], so a seeded run deals the same tasks every time.
  final g = GameState()
    ..seed = rand.nextInt(1 << 30)
    ..addTasksUntilTarget(players, target);
  final s = MatchState(players: players, target: target);
  s.dealFor(1, rand,
      accept: (hands, inPlay) =>
          g.tasks.every((t) => playableWith(t.description, hands, inPlay)));
  s.tasks = [for (final t in g.tasks) MatchTask(t.freshCopy()..seal = null)];
  final dealt = [for (final t in s.tasks) t.description];
  // Nobody takes two tasks that work against each other (as in the game).
  s.takeRule = (task, seat) => !s.tasks.any((o) =>
      o.owner == seat &&
      selfClash(o.description, s.tasks[task].description, players: players));
  s.pickTurn = s.king;
  s.phase = Phase.picking;
  var guard = 0;
  while (s.phase != Phase.roundOver && guard++ < 400) {
    switch (s.phase) {
      case Phase.picking:
        final seat = s.pickTurn!;
        final options = [
          for (int i = 0; i < s.tasks.length; i++)
            if (s.canTake(i, seat)) i
        ];
        if (options.isEmpty) {
          // Stuck: nobody may take what's left. Counts as a loss.
          return (false, ['(no one could take a task)'], dealt);
        }
        s.apply(PickTask(seat, bot.choosePick(s, seat)));
      case Phase.announcing:
        final i =
            s.tasks.indexWhere((t) => needsX(t.description) && t.x == null);
        s.apply(Announce(s.tasks[i].owner!, i, bot.chooseX(s, s.tasks[i].owner!, i)));
      case Phase.playing:
        s.apply(PlayCard(s.turn, bot.choosePlay(s, s.turn)));
      case Phase.roundOver:
        break;
    }
  }
  final v = s.view;
  final failed = [
    for (final t in s.tasks)
      if (t.owner != null &&
          taskRules[t.description]!(v, t.owner!, t.x) != Verdict.done)
        t.description
  ];
  return (s.won ?? false, failed, dealt);
}

