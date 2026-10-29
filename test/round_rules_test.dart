/// The round's rules for the moves round_test.dart leaves out: handing a
/// task back at a real table, announcing a number, playing a card out of
/// turn or off suit, the decrees that hold cards back, and who picks next
/// under Exile. These are what online play checks every move against, so
/// they're pinned by the reason a move is refused.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/decrees.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/engine/task.dart';

const exactly = 'Win exactly X tricks, named before the first trick';

/// A four-player round with the given tasks, dealt (unless [cards] is off,
/// as at a real table) and crowned.
Round table(List<String> tasks, {int seed = 3, Decree? decree, int king = 0, bool cards = true}) {
  final r = Round(players: 4, target: 6)
    ..tasks = [for (final d in tasks) RoundTask(taskByDescription(d))]
    ..decree = decree;
  if (cards) r.dealFor(1, Random(seed), king: king);
  r.crown(king, Random(seed));
  return r;
}

/// Hands every open task to someone who may hold it, the picker first.
void handOut(Round r) {
  while (r.pickTurn != null) {
    final seat = r.pickTurn!;
    final i = [for (var i = 0; i < r.tasks.length; i++) if (r.tasks[i].owner == null) i]
        .firstWhere((i) => r.canTake(i, seat), orElse: () => -1);
    if (i < 0) {
      r.apply(Pass(seat));
    } else {
      r.apply(PickTask(seat, i));
    }
  }
}

void main() {
  test('At a real table a task taken by mistake can be handed back, and picking resumes', () {
    final r = table(['Win the 3♥', 'Win the 6♣'], cards: false);
    expect(r.hasCards, isFalse);
    expect(r.problem(const ReturnTask(0, 0)), 'That task is on the table');
    expect(r.problem(const ReturnTask(0, 7)), 'No such task');
    final seat = r.pickTurn!;
    r.apply(PickTask(seat, 0));
    expect(r.tasks[0].owner, seat);
    expect(r.problem(const ReturnTask(0, 0)), isNull);
    r.apply(const ReturnTask(0, 0));
    expect(r.tasks[0].owner, isNull);
    expect(r.phase, Phase.picking);
    expect(r.pickTurn, isNotNull);
  });

  test('With the cards on screen a task stays with whoever took it', () {
    final r = table(['Win the 3♥', 'Win the 6♣']);
    final seat = r.pickTurn!;
    final i = r.canTake(0, seat) ? 0 : 1;
    r.apply(PickTask(seat, i));
    expect(r.problem(ReturnTask(seat, i)), 'Tasks stay with whoever took them');
  });

  test('An "exactly X" task waits for its number, from its owner, within the tricks', () {
    final r = table([exactly, 'Win the 6♣']);
    expect(r.problem(const Announce(0, 0, 1)), 'Nothing to announce');
    handOut(r);
    expect(r.phase, Phase.announcing);
    expect(r.settled, isFalse);
    final owner = r.tasks[0].owner!;
    final other = (owner + 1) % 4;
    expect(r.problem(Announce(other, 0, 1)), 'Not your task');
    expect(r.problem(Announce(owner, 5, 1)), 'No such task');
    expect(r.problem(Announce(owner, 0, -1)), 'Not a possible number');
    expect(r.problem(Announce(owner, 0, r.totalTricks + 1)), 'Not a possible number');
    // Nothing is played before every number is in.
    expect(r.problem(PlayCard(r.turn, r.hands[r.turn].first)), 'Not playing yet');
    r.apply(Announce(owner, 0, 2));
    expect(r.tasks[0].x, 2);
    expect(r.phase, Phase.playing);
    expect(r.announced, isNotEmpty);
  });

  test('A card is played in turn, following the suit led', () {
    final r = table(['Win the 6♣'], king: 0);
    handOut(r);
    expect(r.phase, Phase.playing);
    final lead = r.turn;
    final notYou = (lead + 1) % 4;
    expect(r.problem(PlayCard(notYou, r.hands[notYou].first)), 'Not your turn');
    // Lead a plain suit someone else can follow but also holds another of.
    final card = r.legalFor(lead).firstWhere((c) => !c.isCourt, orElse: () => r.legalFor(lead).first);
    r.apply(PlayCard(lead, card));
    final next = r.turn;
    final offSuit = r.hands[next].where((c) => !r.legalFor(next).contains(c));
    if (offSuit.isNotEmpty) {
      expect(r.problem(PlayCard(next, offSuit.first)), startsWith('You must follow'));
    }
    expect(r.problem(PlayCard(next, r.legalFor(next).first)), isNull);
  });

  test('Silence holds every card back; Late Counsel until three tricks are played', () {
    final silent = table(['Win the 6♣'], decree: Decree.silence);
    expect(silent.canSpeak(1), isFalse);
    expect(silent.whyCantSpeak(), contains('Silence'));
    final late = table(['Win the 6♣'], decree: Decree.lateCounsel);
    expect(late.canSpeak(1), isFalse);
    expect(late.whyCantSpeak(), contains('Late Counsel'));
    final open = table(['Win the 6♣']);
    expect(open.canSpeak(1), isTrue);
    expect(open.whyCantSpeak(), isNull);
  });

  test('Under Exile someone other than the King sits out, and the pick passes them by', () {
    final r = table(['Win the 3♥', 'Win the 6♣', 'Win the first trick'],
        decree: Decree.exile, king: 1);
    final exiled = r.exiledSeat;
    expect(exiled, isNotNull);
    expect(exiled, isNot(1), reason: 'never the King');
    for (var from = 0; from < 4; from++) {
      expect(r.nextPicker(from), isNot(exiled));
    }
  });

  test('A lost round stops play; a won one may play itself out', () {
    final lost = table(['Win the 6♣'], king: 0);
    handOut(lost);
    lost.mark(lost.tasks[0], TaskStatus.failed);
    expect(lost.outcome, RoundOutcome.lost);
    expect(lost.problem(PlayCard(lost.turn, lost.legalFor(lost.turn).first)), 'The round is lost');
    final won = table(['Win the 6♣'], king: 0);
    handOut(won);
    won.mark(won.tasks[0], TaskStatus.completed);
    expect(won.outcome, RoundOutcome.won);
    expect(won.problem(PlayCard(won.turn, won.legalFor(won.turn).first)), isNull);
  });
}
