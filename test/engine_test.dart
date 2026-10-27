import 'dart:math';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/conflicts.dart';
import 'package:kings_court/engine/deal_mix.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/models.dart';

PlayingCard c(String label) => PlayingCard.parse(label)!;

void main() {
  test('The deck has 40 cards and deals evenly, never setting aside the King card',
      () {
    expect(fullDeck().toSet(), hasLength(40));
    for (final players in [3, 4, 5, 6]) {
      for (int seed = 0; seed < 20; seed++) {
        final d = deal(players, Random(seed));
        expect(d.hands.map((h) => h.length).toSet(), {40 ~/ players});
        expect(d.setAside, hasLength(40 % players));
        expect(d.setAside, isNot(contains(PlayingCard.king)));
      }
    }
    // Two players hold 12 each, so the round doesn't drag.
    final two = deal(2, Random(1));
    expect(two.hands.map((h) => h.length).toSet(), {12});
    expect(two.setAside, hasLength(16));
    expect(two.setAside, isNot(contains(PlayingCard.king)));
  });

  test('A two-player hand is played to its end', () {
    final m = MatchState(players: 2, target: 6)..dealFor(1, Random(4), king: 0);
    expect(m.totalTricks, 12);
    var guard = 0;
    while (m.hands.any((h) => h.isNotEmpty) && guard++ < 100) {
      final seat = m.turn;
      m.playCard(seat, m.legalFor(seat).first);
    }
    expect(m.tricks, hasLength(m.totalTricks));
  });

  test('Hands sort ♥ ♠ ♦ ♣, then the Court Cards', () {
    final hand = [
      PlayingCard.king, c('2♣'), c('9♦'), c('A♠'), c('5♥'), PlayingCard.joker,
      c('3♥'),
    ]..sort();
    expect(hand.map((x) => x.label),
        ['3♥', '5♥', 'A♠', '9♦', '2♣', 'Joker', 'King']);
  });

    test('Card ids and labels round-trip', () {
    for (final card in fullDeck()) {
      expect(PlayingCard.fromId(card.id), card);
      expect(PlayingCard.parse(card.label), card);
    }
  });

  test('You must follow suit, and a Court Card lead needs a Court Card', () {
    final hand = [c('3♥'), c('7♥'), c('2♣'), PlayingCard.joker];
    expect(legalPlays(hand, c('9♥')), [c('3♥'), c('7♥')]);
    expect(legalPlays(hand, c('5♦')), hand);
    expect(legalPlays(hand, PlayingCard.queen), [PlayingCard.joker]);
    expect(legalPlays(hand, null), hand);
  });

  test('The highest Court Card wins, otherwise the highest of the suit led',
      () {
    expect(winningPlay([c('5♥'), c('9♥'), c('9♣')]), 1);
    expect(winningPlay([c('5♥'), c('9♣'), c('2♥')]), 0);
    expect(winningPlay([c('5♥'), PlayingCard.joker, c('9♥')]), 1);
    expect(
        winningPlay([PlayingCard.jack, PlayingCard.king, PlayingCard.joker]),
        1);
  });

  test('Every task has a rule', () {
    for (final t in GameState.taskPool) {
      expect(taskRules.containsKey(t.description), isTrue,
          reason: t.description);
    }
  });

  RoundView view(List<Trick> tricks, {int total = 10}) => RoundView(
      players: 4,
      king: 0,
      tricks: tricks,
      totalTricks: total,
      inPlay: fullDeck().toSet());

  test('Rules decide early when they can', () {
    final win3 = taskRules['Win the 3♥']!;
    final t1 = Trick(0, [0, 1, 2, 3], [c('A♥'), c('3♥'), c('9♥'), c('2♥')], 2);
    expect(win3(view([t1]), 2, null), Verdict.done);
    expect(win3(view([t1]), 1, null), Verdict.failed);
    expect(win3(view([]), 1, null), Verdict.pending);

    final none = taskRules["Don't win any tricks"]!;
    expect(none(view([t1]), 2, null), Verdict.failed);
    expect(none(view([t1]), 1, null), Verdict.pending);
    expect(none(view([t1], total: 1), 1, null), Verdict.done);

    final x = taskRules['Win exactly X tricks, said out loud before the first trick']!;
    expect(x(view([t1], total: 1), 2, 1), Verdict.done);
    expect(x(view([t1], total: 1), 2, 0), Verdict.failed);

    final withSix = taskRules['Win a trick with a 6']!;
    final t2 = Trick(0, [0, 1, 2, 3], [c('6♣'), c('2♣'), c('9♦'), c('A♣')], 0);
    expect(withSix(view([t2]), 0, null), Verdict.done);
  });

  test('Every rule reaches a verdict by the end of the round', () {
    final rand = Random(7);
    for (int game = 0; game < 40; game++) {
      final players = 3 + game % 4;
      final s = MatchState(players: players, target: 0)..newRound(rand);
      s.phase = Phase.playing;
      while (s.tricks.length < s.totalTricks) {
        final legal = s.legalFor(s.turn);
        s.apply(PlayCard(s.turn, legal[rand.nextInt(legal.length)]));
        s.phase = Phase.playing; // keep going whatever the tasks say
      }
      final v = s.view;
      for (final e in taskRules.entries) {
        for (int owner = 0; owner < players; owner++) {
          expect(e.value(v, owner, 2), isNot(Verdict.pending), reason: e.key);
        }
      }
    }
  });

  test('Bots can play a whole round', () {
    final rand = Random(3);
    final bot = Bot(rand)..budget = 40;
    final s = MatchState(players: 4, target: 6)..newRound(rand);
    var guard = 0;
    while (s.phase != Phase.roundOver && guard++ < 200) {
      switch (s.phase) {
        case Phase.picking:
          s.apply(PickTask(s.pickTurn!, bot.choosePick(s, s.pickTurn!)));
        case Phase.announcing:
          final i = s.tasks.indexWhere(
              (t) => needsX(t.description) && t.x == null);
          s.apply(Announce(s.tasks[i].owner!, i,
              bot.chooseX(s, s.tasks[i].owner!, i)));
        case Phase.playing:
          s.apply(PlayCard(s.turn, bot.choosePlay(s, s.turn)));
        case Phase.roundOver:
          break;
      }
    }
    expect(s.phase, Phase.roundOver);
    expect(s.won, isNotNull);
    expect(s.wins + s.losses, 1);
  });

  test('A game in progress saves and loads', () {
    final rand = Random(5);
    final s = MatchState(players: 4, target: 5)..newRound(rand);
    for (int i = 0; i < s.tasks.length; i++) {
      s.apply(PickTask(s.pickTurn!, s.tasks.indexWhere((t) =>
          t.owner == null && !(t.task.kingCantTake && s.pickTurn == s.king))));
    }
    if (s.phase == Phase.announcing) {
      for (int i = 0; i < s.tasks.length; i++) {
        if (needsX(s.tasks[i].description)) {
          s.apply(Announce(s.tasks[i].owner!, i, 1));
        }
      }
    }
    s.apply(PlayCard(s.turn, s.legalFor(s.turn).first));
    final copy = MatchState.fromJson(s.toJson());
    expect(copy.toJson(), s.toJson());
    expect(MatchAction.fromJson(PlayCard(2, c('7♦')).toJson()).toJson(),
        PlayCard(2, c('7♦')).toJson());
  });

  test('Illegal moves are refused', () {
    final s = MatchState(players: 4, target: 5)..newRound(Random(9));
    final notYou = (s.pickTurn! + 1) % 4;
    expect(s.problem(PickTask(notYou, 0)), isNotNull);
    expect(() => s.apply(PlayCard(0, s.hands[0].first)), throwsStateError);
  });

  test('Task profiles name real tasks', () {
    final names = GameState.taskPool.map((t) => t.description).toSet();
    for (final d in profiledTasks) {
      expect(names, contains(d), reason: d);
    }
  });

  test('Clashing tasks are spotted', () {
    expect(clash('Win the 2♦', 'Win all four 2s'), isTrue);
    expect(clash('Win a trick with a 2', 'Win all four 2s'), isTrue);
    expect(clash('Win the first trick', 'Win the first two tricks'), isTrue);
    expect(clash('Win more tricks than anyone else',
        'Win more tricks than the rest of the court put together'), isTrue);
    expect(clash('Win exactly three Court Cards (redeal if one player has all four)',
        'Win exactly two Court Cards (redeal if one player has the Jack, Queen and King)'), isTrue);
    expect(clash('Win the 3♥', 'Win the 4♠'), isFalse);
    expect(selfClash('Win no ♠ cards', 'Win the 9♠'), isTrue);
    expect(selfClash("Don't win any tricks", 'Win the last trick'), isTrue);
    expect(selfClash('Win exactly one trick', 'Win exactly two tricks'), isTrue);
    expect(selfClash('Win the 3♥', 'Win the 4♠'), isFalse);
  });

  test('Rounds never deal tasks that clash', () {
    for (int i = 0; i < 300; i++) {
      final g = GameState()..addTasksUntilTarget(3 + i % 4, 10 + i % 21);
      for (final a in g.tasks) {
        for (final b in g.tasks) {
          if (a != b) {
            expect(clash(a.description, b.description), isFalse,
                reason: '${a.description} / ${b.description}');
          }
        }
      }
    }
  });

  test('Avoiding something clashes with needing enough of it', () {
    expect(selfClash("Don't win any 6s", 'Win at least three 7s'), isTrue);
    expect(selfClash("Don't win any ♦ or ♠ cards", 'Win at least six ♣ cards'), isTrue);
    expect(selfClash('Win no Court Cards', 'Win exactly two Court Cards (redeal if one player has the Jack, Queen and King)'), isTrue);
    expect(selfClash("Don't win any 6s", 'Win at least three 4s'), isFalse);
  });

  test('No card is avoided by every player', () {
    const a = "Don't win any ♦ cards", b = "Don't win any ♦ or ♠ cards";
    expect(overAvoided([a, b], "Don't win any tricks", 3), isTrue);
    expect(overAvoided([a], b, 3), isFalse);
    expect(overAvoided([a, b], 'Win the 3♥', 3), isFalse);
  });

  test('Every task has a tier, and deals keep within the tier limits', () {
    expect(tierOf('Win exactly two tricks'), TaskTier.precise);
    expect(tierOf('Win only the last trick'), TaskTier.precise);
    expect(tierOf("Don't win any 6s"), TaskTier.avoid);
    expect(tierOf('Win more tricks than the King'), TaskTier.race);
    expect(tierOf('Win the 3♥'), TaskTier.capture);
    expect(tierOf('Win a trick with a 6'), TaskTier.trick);
    for (int i = 0; i < 400; i++) {
      final players = 3 + i % 3;
      final g = GameState()..addTasksUntilTarget(players, 6 + i % 25);
      final ds = g.tasks.map((t) => t.description).toList();
      for (final e in tierLimit.entries) {
        expect(ds.where((d) => tierOf(d) == e.key).length,
            lessThanOrEqualTo(e.value), reason: ds.join(' / '));
      }
      for (int k = 0; k < ds.length; k++) {
        expect(overAvoided(ds.sublist(0, k) + ds.sublist(k + 1), ds[k], players), isFalse,
            reason: ds.join(' / '));
      }
    }
  });

  test('Nobody may hold two tasks that work against each other', () {
    final g = GameState()
      ..players = [for (int i = 0; i < 4; i++) Player('P$i', color: const Color(0xFF000000))];
    Task task(String d) =>
        GameState.taskPool.firstWhere((t) => t.description == d).freshCopy();
    final noHearts = task('Win no ♠ cards')..assignedPlayerIndex = 1;
    final threeHearts = task('Win the 9♠');
    g.tasks = [noHearts, threeHearts];
    expect(g.canTake(threeHearts, 1), isFalse);
    expect(g.whyCantTake(threeHearts, 1), contains('clashes'));
    expect(g.canTake(threeHearts, 2), isTrue);
  });

  test('Progress counts what a task has won so far', () {
    final v = RoundView(
        players: 4,
        king: 0,
        tricks: [
          Trick(0, [0, 1, 2, 3], [c('2♦'), c('2♥'), c('5♦'), c('3♦')], 2),
        ],
        totalTricks: 10,
        inPlay: fullDeck().toSet());
    expect(taskProgress('Win all four 2s', v, 2, null), '2/4');
    expect(taskProgress('Win at least five ♦ cards', v, 2, null), '3/5');
    expect(taskProgress('Win exactly X tricks, said out loud before the first trick', v, 2, 2),
        '1/2');
    expect(taskProgress('Win the 3♥', v, 2, null), isNull);
  });

  test('The King can never take a task the King card makes impossible', () {
    for (final d in ['Win no Court Cards', "Don't win any tricks"]) {
      expect(
          GameState.taskPool.firstWhere((t) => t.description == d).kingCantTake,
          isTrue,
          reason: d);
    }
  });

  test("If the King can't take any task, the next player picks first", () {
    final g = GameState()
      ..players = [for (int i = 0; i < 3; i++) Player('P$i', color: const Color(0xFF000000))]
      ..tasks = [
        GameState.taskPool
            .firstWhere((t) => t.description == 'Win no Court Cards')
            .freshCopy()
      ];
    g.setKing(0);
    expect(g.pickTurn, 1);
  });
}
