import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/conflicts.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/engine/task.dart';
import 'package:kings_court/game/courtiers.dart';
import 'package:kings_court/modes/dynasty/data/works.dart';
import 'package:kings_court/modes/dynasty/dynasty.dart';
import 'package:kings_court/modes/dynasty/realm.dart';

/// Plays [run]'s hand with all-seeing courtiers in every seat, you (seat 0)
/// as King: for each picked project, whether its task was done.
List<bool?> playHand(DynastyRun run, Random rand) {
  final bot = Bot()
    ..budget = 16
    ..omniscient = true;
  final s = Round(players: run.players, target: 1)..dealFor(1, rand);
  s.tasks = [for (final t in run.tasks) RoundTask(t)];
  s
    ..king = 0
    ..pickTurn = 0
    ..phase = Phase.picking;
  var guard = 0;
  while (s.phase != Phase.roundOver && guard++ < 400) {
    switch (s.phase) {
      case Phase.picking:
        final seat = s.pickTurn!;
        if (!s.tasks.indexed.any((e) => s.canTake(e.$1, seat))) {
          return [for (final _ in s.tasks) false];
        }
        s.apply(PickTask(seat, bot.choosePick(s, seat)));
      case Phase.announcing:
        final i = s.tasks.indexWhere((t) => needsX(t.description) && t.x == null);
        s.apply(Announce(s.tasks[i].owner!, i, bot.chooseX(s, s.tasks[i].owner!, i)));
      case Phase.playing:
        final seat = s.turn;
        s.apply(PlayCard(seat, bot.choosePlay(s, seat)));
      case Phase.roundOver:
        break;
    }
  }
  final v = s.view;
  return [
    for (final t in s.tasks)
      t.owner == null ? null : taskRules[t.description]!(v, t.owner!, t.x) == Verdict.done
  ];
}

void main() {
  test('Every project stage is a task in the library, and fits a deal on its own', () {
    for (final p in projects) {
      for (final d in p.stages) {
        expect(() => taskByDescription(d), returnsNormally, reason: '${p.title}: $d');
      }
    }
    for (final p in petitions) {
      for (final c in p.choices) {
        if (c.effect.project case final id?) expect(() => projectById(id), returnsNormally);
      }
      expect(p.choices.any((c) => c.cost == 0), isTrue, reason: '${p.id}: one answer must be free');
    }
  });

  test('A run starts with the keystone and three projects, and a table of three', () {
    final run = DynastyRun(1);
    expect(run.pool.first.project.keystone, isTrue);
    expect(run.pool, hasLength(4));
    expect(run.table, hasLength(3));
    expect(run.players, 4);
    expect(run.picks, 4);
    expect(run.over, isFalse);
  });

  test('A picked project moves on when its task is done, pays its points, and finishes', () {
    final run = DynastyRun(2);
    final w = Work(projectById('bandits'));
    run.pool.add(w);
    run.pick([w]);
    expect(run.tasks.single.description, 'Win a trick with a 7');
    final before = run.coffers;
    final people = run.meters[Meter.people]!;
    run.afterHand([true]);
    expect(w.finished, isTrue);
    expect(run.pool, isNot(contains(w)));
    expect(run.coffers, greaterThan(before));
    expect(run.meters[Meter.people], people + 1, reason: 'its reward');
    expect(run.hand, 1);
  });

  test('A failed stage hurts the realm; the court eats the stores every hand', () {
    final run = DynastyRun(3);
    final w = Work(projectById('missing'));
    run.pool.add(w);
    run.pick([w]);
    run.afterHand([false]);
    expect(w.stage, 0);
    expect(run.meters[Meter.people], 3, reason: 'the failure: -2');
    expect(run.meters[Meter.stores], 4, reason: 'the upkeep: -1');
  });

  test('A meter run out ends the reign', () {
    final run = DynastyRun(4)..meters[Meter.people] = 1;
    final w = Work(projectById('missing'));
    run.pool.add(w);
    run.pick([w]);
    run.afterHand([false]);
    expect(run.ending, Ending.revolt);
    expect(run.petition, isNull);
  });

  test('A petition’s answer costs gold, moves the realm and seats the next table', () {
    final run = DynastyRun(5);
    run.petition = petitions.firstWhere((p) => p.id == 'roof');
    run.coffers = 3;
    expect(run.affords(run.petition!.choices[0]), isFalse, reason: 'the work costs 4');
    run.coffers = 10;
    run.choose(0);
    expect(run.coffers, 6);
    expect(run.pool.any((w) => w.project.id == 'temple'), isTrue);
    expect(run.table.first, Courtier.bishop, reason: 'the Bishop sits next');
    run.petition = petitions.firstWhere((p) => p.id == 'abbey');
    run.choose(1);
    expect(run.table, isNot(contains(Courtier.duke)), reason: 'the Duke is kept away');
  });

  test('A courtier out of loyalty turns traitor, and is dealt with first', () {
    final run = DynastyRun(6)..loyalty[Courtier.merchant] = 1;
    final w = Work(projectById('tax'));
    run.pool.add(w);
    run.pick([w]);
    run.table = [Courtier.duke, Courtier.bishop, Courtier.general];
    // Tax the guilds twice: the Merchant's loyalty runs out at the reward.
    w.stage = 1;
    run.afterHand([true]);
    expect(run.traitor, Courtier.merchant);
    expect(run.petition!.id, 'treason');
    run.coffers = 10;
    run.choose(0);
    expect(run.court, isNot(contains(Courtier.merchant)));
    expect(run.traitor, isNull);
  });

  test('A seeded run, played to its end by all-seeing courtiers, ends', () {
    for (final seed in [11, 12]) {
      final run = DynastyRun(seed);
      final rand = Random(seed);
      var hands = 0;
      while (!run.over && hands < 12) {
        // The King picks as many projects as fit, keystone last.
        final chosen = <Work>[];
        for (final w in [...run.pool.skip(1), run.pool.first]) {
          if (chosen.length < 2 && run.canPick(w, chosen)) chosen.add(w);
        }
        expect(chosen, isNotEmpty);
        run.pick(chosen);
        run.afterHand(playHand(run, rand));
        hands++;
        if (run.petition case final p?) {
          run.choose(p.choices.indexWhere(run.affords));
        }
      }
      expect(run.over, isTrue, reason: 'seed $seed: within an act');
    }
  });
}
