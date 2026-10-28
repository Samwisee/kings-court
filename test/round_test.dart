/// The round's actions (engine/round.dart): `problem` says why a move
/// isn't allowed, `apply` is the one way play moves on, with the table's
/// full rules, and a seat's view of the round hides the other hands.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/decrees.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/engine/task.dart';

/// A four-player round with the given tasks, dealt and crowned.
Round table(List<String> tasks, {int seed = 3, Decree? decree, int? king}) {
  final r = Round(players: 4, target: 6)
    ..tasks = [for (final d in tasks) RoundTask(taskByDescription(d))]
    ..decree = decree;
  r.dealFor(1, Random(seed), king: king);
  r.crown(king ?? r.kingCardHolder, Random(seed));
  return r;
}

void main() {
  test('A task only one seat may take goes straight to them when the King is crowned', () {
    // "Win no Court Cards" can't be the King's, and clashes with seat 1's
    // task: only seat 2 may hold it, so it's theirs at once.
    final r = Round(players: 3, target: 5)
      ..tasks = [
        RoundTask(taskByDescription('Win no Court Cards')),
        RoundTask(taskByDescription('Win the Queen'), owner: 1),
      ];
    r.crown(0, Random(1));
    expect(r.tasks[0].owner, 2);
    expect(r.allTaken, isTrue);
    expect(r.pickTurn, isNull);
  });

  test('Picks follow the table’s rules: whose turn, what they may hold, who picks next', () {
    final r = table(['Win the 3♥', 'Win the 7♣', 'Win the first trick'], king: 1);
    expect(r.phase, Phase.picking);
    expect(r.pickTurn, 1);
    expect(r.problem(PickTask(2, 0)), 'Not your turn to pick');
    expect(r.problem(PickTask(1, 9)), 'No such task');
    final open = [for (var i = 0; i < r.tasks.length; i++) if (r.canTake(i, 1)) i];
    r.apply(PickTask(1, open.first));
    expect(r.tasks[open.first].owner, 1);
    expect(r.picksMade, 1);
    expect(r.pickTurn, r.allTaken ? isNull : isNot(1));
    expect(r.problem(PickTask(1, open.first)), 'That task is taken');
  });

  test('Under the King’s Command the King hands every task out', () {
    final r = table(['Win the 3♥', 'Win the 7♣'], king: 1, decree: Decree.kingsCommand);
    expect(r.pickTurn, 1);
    // Seat 3 may not pick for itself, but the King may hand it a task.
    expect(r.problem(PickTask(3, 0)), isNull);
    r.apply(PickTask(3, 0));
    expect(r.tasks[0].owner, 3);
    expect(r.pickTurn, r.allTaken ? null : 1, reason: 'the King keeps handing out');
  });

  test('Passing is refused when the round or the turn says so', () {
    final r = table(['Win the 3♥', 'Win the 7♣'], king: 1);
    expect(r.problem(Pass(2)), 'Not your turn to pick');
    expect(r.problem(Pass(1)), isNull);
    r.apply(Pass(1));
    expect(r.passed, contains(1));
    expect(r.pickTurn, isNot(1));
    final quiet = table(['Win the 3♥', 'Win the 7♣'], king: 1)..passing = false;
    expect(quiet.problem(Pass(1)), 'No passing now');
  });

  test('Showing a card needs the speech token, the decree’s leave and a showable card', () {
    final r = table(['Win the 3♥'], king: 0);
    final showable = r.hands[2].firstWhere((c) => r.revealFor(2, c) != null);
    final court = r.hands[2].firstWhere((c) => c.isCourt, orElse: () => showable);
    if (court != showable) expect(r.problem(ShowCard(2, court)), 'That card can’t be shown');
    expect(r.problem(ShowCard(2, showable)), isNull);
    r.apply(ShowCard(2, showable));
    expect(r.revealed[2], showable);
    expect(r.spoke[2], isTrue, reason: 'the token is used');
    expect(r.problem(ShowCard(2, showable)), 'That card reveal is used this round');
    final silent = table(['Win the 3♥'], king: 0, decree: Decree.silence);
    final card = silent.hands[2].firstWhere((c) => silent.revealFor(2, c) != null);
    expect(silent.problem(ShowCard(2, card)), contains('Silence'));
  });

  test('A table that turns the cards over itself plays without judging', () {
    final r = table(['Win the first trick'], king: 0);
    r.assign(r.tasks[0], 0);
    expect(r.phase, Phase.playing);
    expect(r.hands[0], contains(PlayingCard.king));
    r.apply(PlayCard(0, PlayingCard.king), judge: false);
    while (r.current.isNotEmpty) {
      r.apply(PlayCard(r.turn, r.legalFor(r.turn).first), judge: false);
    }
    expect(r.tricks, hasLength(1));
    expect(r.tasks[0].isPending, isTrue, reason: 'not judged yet');
    for (final f in r.judge()) {
      r.flip(f);
    }
    expect(r.tasks[0].isCompleted, isTrue);
    expect(r.outcome, RoundOutcome.won);
  });

  test('A seat’s view keeps its own hand and hides the others', () {
    final r = table(['Win the 3♥', 'Win the 7♣'], king: 1);
    final v = r.visibleTo(2);
    expect(v.hands[2], r.hands[2]);
    for (final s in [0, 1, 3]) {
      expect(v.hands[s], isEmpty);
      expect(v.handSize(s), r.hands[s].length);
    }
    expect(v.handSize(2), r.hands[2].length);
    expect(v.setAside, r.setAside, reason: 'kept, so every device judges alike');
    expect(v.king, r.king);
    expect(v.tasks.map((t) => t.description), r.tasks.map((t) => t.description));
    // The view travels as JSON and comes back whole.
    final back = Round.fromJson(jsonDecode(jsonEncode(v.toJson())) as Map<String, dynamic>);
    expect(back.handSize(0), r.hands[0].length);
    expect(back.hands[0], isEmpty);
    expect(back.hands[2], r.hands[2]);
    expect((v.toJson()['hands'] as List)[0], isEmpty);
  });
}
