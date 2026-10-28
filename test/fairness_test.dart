/// The courtiers play fair: a bot's knowledge, its imagined deals and its
/// decisions depend only on what it could see. Moving the cards it can't
/// see between the other hands, in ways that keep every public fact,
/// changes nothing it does.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/inference.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/engine/sampling.dart';

PlayingCard c(String l) => PlayingCard.parse(l)!;

/// A 4-player round where seat 1 (the viewer) is the King and leads.
MatchState table({int seed = 3}) {
  final s = MatchState(players: 4, target: 6)..newRound(Random(seed));
  // Seat 1 takes the King card, so it's the King and leads.
  final holder = s.king;
  if (holder != 1) {
    final swap = s.hands[1].firstWhere((x) => !x.isCourt);
    s.hands[1].remove(swap);
    s.hands[holder].remove(PlayingCard.king);
    s.hands[1].add(PlayingCard.king);
    s.hands[holder].add(swap);
    s.hands[1].sort();
    s.hands[holder].sort();
    s.king = 1;
    s.leader = 1;
  }
  // Everyone takes a task, round-robin from the King.
  s.pickTurn = 1;
  while (s.phase == Phase.picking) {
    final seat = s.pickTurn!;
    final i = List.generate(s.tasks.length, (t) => t)
        .firstWhere((t) => s.canTake(t, seat), orElse: () => -1);
    if (i < 0) break;
    s.apply(PickTask(seat, i));
  }
  for (int i = 0; i < s.tasks.length; i++) {
    if (s.phase == Phase.announcing && s.tasks[i].x == null) {
      s.apply(Announce(s.tasks[i].owner!, i, 2));
    }
  }
  return s;
}

/// The same round with the hands seat 1 can't see shuffled between the
/// other seats (the King card stays with the King; sizes stay the same).
MatchState hiddenCardsMoved(MatchState s, Random rand) {
  final others = [for (int k = 0; k < s.players; k++) if (k != 1) k];
  final pool = [for (final k in others) ...s.hands[k]]..shuffle(rand);
  final hands = [for (final h in s.hands) List.of(h)];
  for (final k in others) {
    hands[k] = pool.sublist(0, s.hands[k].length)..sort();
    pool.removeRange(0, s.hands[k].length);
  }
  return worldWith(s, hands);
}

void main() {
  test('What a bot knows is the same whoever holds the cards it cannot see', () {
    final a = table();
    final b = hiddenCardsMoved(a, Random(11));
    expect(b.hands[1], a.hands[1]);
    expect(b.hands[0], isNot(a.hands[0]));
    final ga = guessHands(a, 1), gb = guessHands(b, 1);
    for (int i = 0; i < ga.length; i++) {
      expect(gb[i].seat, ga[i].seat);
      expect(gb[i].size, ga[i].size);
      expect(gb[i].voids, ga[i].voids);
      expect(gb[i].possible, ga[i].possible);
      expect(gb[i].certain, ga[i].certain);
    }
  });

  test('The deals a bot imagines are the same whoever holds the hidden cards', () {
    final a = table();
    final b = hiddenCardsMoved(a, Random(12));
    final wa = sampleWorlds(a, 1, 6, Random(5));
    final wb = sampleWorlds(b, 1, 6, Random(5));
    for (int k = 0; k < wa.length; k++) {
      expect(wb[k].hands, wa[k].hands);
      expect(wb[k].setAside, wa[k].setAside);
    }
  });

  test('A bot decides the same whoever holds the hidden cards', () {
    final a = table();
    final b = hiddenCardsMoved(a, Random(13));
    Bot bot() => Bot(Random(9))..budget = 200;
    expect(bot().choosePlay(b, 1), bot().choosePlay(a, 1));
    // Picking too: a fresh round, seat 1 to pick.
    final pa = MatchState(players: 4, target: 6)..newRound(Random(4));
    pa.pickTurn = 1;
    final pb = hiddenCardsMoved(pa, Random(14))..pickTurn = 1;
    expect(bot().choosePick(pb, 1), bot().choosePick(pa, 1));
    // And an all-seeing bot, which may not: the cards moved.
    expect(sampleWorlds(a, 1, 1, Random(1)).single.hands, isNot(a.hands));
  });

  test('Imagined deals honour every public fact', () {
    List<PlayingCard> cs(String l) => [for (final x in l.split(' ')) c(x)];
    final s = MatchState(players: 4, target: 6)
      ..hands = [
        cs('A♥ 2♥ 3♥ A♦ 2♦ 3♦ A♠ 2♠ 3♠') + [PlayingCard.joker],
        cs('4♥ 5♥ 6♥ 4♦ 5♦ 6♦ 4♠ 5♠ 6♠') + [PlayingCard.king],
        cs('A♣ 2♣ 3♣ 4♣ 5♣ 6♣ 7♣ 8♣ 9♣') + [PlayingCard.jack],
        cs('7♥ 8♥ 9♥ 7♦ 8♦ 9♦ 7♠ 8♠ 9♠') + [PlayingCard.queen],
      ]
      ..king = 1
      ..leader = 1
      ..phase = Phase.playing;
    // Trick 1: seat 1 leads a heart, seat 2 can't follow (it has none),
    // seat 3 takes it. Then seat 3 shows the 7♦ as its lowest diamond.
    final played = cs('5♥ 2♣ 7♥ 3♥');
    s.tricks.add(Trick(1, const [1, 2, 3, 0], played, 3));
    s.leader = 3;
    for (final h in s.hands) {
      h.removeWhere(played.contains);
    }
    final seven = c('7♦');
    s.revealed[3] = seven;
    s.revealHint[3] = 'lowest';
    final unseen = <PlayingCard>{...s.hands[0], ...s.hands[2], ...s.hands[3]};
    final rand = Random(2);
    final guesses = guessHands(s, 1);
    for (int n = 0; n < 200; n++) {
      final hands = sampleHands(s, 1, guesses, rand);
      expect(hands[1], s.hands[1]);
      final dealt = <PlayingCard>[];
      for (int k = 0; k < 4; k++) {
        if (k == 1) continue;
        expect(hands[k].length, s.hands[k].length, reason: 'seat $k size');
        dealt.addAll(hands[k]);
      }
      expect(dealt.toSet(), unseen, reason: 'every unseen card dealt once');
      expect(hands[2].any((x) => x.suit == Suit.hearts), isFalse, reason: 'seat 2 is out of hearts');
      expect(hands[3], contains(seven), reason: 'seat 3 holds the card it showed');
      expect(hands[3].any((x) => x.suit == Suit.diamonds && x.rank < 7), isFalse,
          reason: 'nothing below its lowest diamond');
      expect(hands[0].contains(seven), isFalse);
    }
    // And over many deals the unknown cards do move about.
    final firstHands = sampleHands(s, 1, guesses, Random(1))[0];
    var moved = false;
    for (int n = 0; n < 20 && !moved; n++) {
      moved = sampleHands(s, 1, guesses, Random(100 + n))[0].toString() != firstHands.toString();
    }
    expect(moved, isTrue);
  });

  test('In a 2-player game the imagined deals set cards aside', () {
    final s = MatchState(players: 2, target: 5)..newRound(Random(8));
    expect(s.setAside.length, 40 - 24);
    final worlds = sampleWorlds(s, 0, 5, Random(3));
    for (final w in worlds) {
      expect(w.hands[0], s.hands[0]);
      expect(w.hands[1].length, s.hands[1].length);
      expect(w.setAside.length, s.setAside.length);
      expect({...w.hands[0], ...w.hands[1], ...w.setAside}.length, 40);
    }
  });
}
