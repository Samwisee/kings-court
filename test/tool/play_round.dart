/// One round played by bots alone, as the balance report and the bot
/// strength benchmark play them.
library;

import 'dart:math';

import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/conflicts.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/engine/showing.dart';
import 'package:kings_court/models.dart';

/// Plays one round with bots; returns whether it was won, which tasks
/// failed, and the tasks dealt.
///
/// Courtiers show cards as they do in the game: before the first pick, and
/// between tricks, a seat that hasn't shown one yet shows a card that a
/// task on the table needs (and that it may show). [onPlay] sees every
/// card about to be played, for benchmarks.
(bool, List<String>, List<String>) playRound(int players, int target, Random rand, Bot bot,
    {void Function(MatchState s, int seat, PlayingCard card)? onPlay, bool showing = true}) {
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
  // A card someone's task needs, shown once a round, as a courtier would.
  void showCards() {
    if (!showing || s.current.isNotEmpty) return;
    for (var seat = 0; seat < players; seat++) {
      if (s.revealed.containsKey(seat)) continue;
      // A task of its own that asks it to show a card comes first.
      final own = intendedShow(s, seat, [
        for (final t in s.tasks)
          if (t.owner == seat && t.verdict == Verdict.pending) t.description
      ]);
      if (own != null) {
        s.apply(ShowCard(seat, own));
        continue;
      }
      for (final card in s.hands[seat]) {
        if (s.revealFor(seat, card) == null) continue;
        final needed = s.tasks.any((t) =>
            t.verdict == Verdict.pending &&
            (t.owner == null || t.owner != seat) &&
            neededCards(t.description).contains(card));
        if (needed) {
          s.apply(ShowCard(seat, card));
          break;
        }
      }
    }
  }

  var guard = 0;
  while (s.phase != Phase.roundOver && guard++ < 400) {
    switch (s.phase) {
      case Phase.picking:
        if (s.tasks.every((t) => t.owner == null)) showCards();
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
        if (s.current.isEmpty) showCards();
        final card = bot.choosePlay(s, s.turn);
        onPlay?.call(s, s.turn, card);
        s.apply(PlayCard(s.turn, card));
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
