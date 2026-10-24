import 'dart:math';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/conflicts.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/models.dart';

PlayingCard c(String label) => PlayingCard.parse(label)!;

void main() {
  test('The deck has 40 cards and deals evenly, never setting aside the K♠',
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
  });

  test('Hands sort ♥ ♠ ♦ ♣, then the Court Cards', () {
    final hand = [
      PlayingCard.king, c('2♣'), c('9♦'), c('A♠'), c('5♥'), PlayingCard.joker,
      c('3♥'),
    ]..sort();
    expect(hand.map((x) => x.label),
        ['3♥', '5♥', 'A♠', '9♦', '2♣', 'Joker', 'K♠']);
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

    final x = taskRules['Win exactly X tricks, announced to everyone']!;
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
    expect(clash('Win the 3♥', 'Win all four 3s'), isTrue);
    expect(clash('Win the first trick', 'Win the first two tricks'), isTrue);
    expect(clash('Win more tricks than everyone else',
        'Win more tricks than everyone else together'), isTrue);
    expect(clash('Win exactly three Court Cards (redeal if one player holds all four)',
        'Win exactly two Court Cards (redeal if one player holds the J♠, Q♠ and K♠)'), isTrue);
    expect(clash('Win the 3♥', 'Win the 4♠'), isFalse);
    expect(selfClash('Win no ♥ cards', 'Win the 3♥'), isTrue);
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

  test('Nobody may hold two tasks that work against each other', () {
    final g = GameState()
      ..players = [for (int i = 0; i < 4; i++) Player('P$i', color: const Color(0xFF000000))];
    Task task(String d) =>
        GameState.taskPool.firstWhere((t) => t.description == d).freshCopy();
    final noHearts = task('Win no ♥ cards')..assignedPlayerIndex = 1;
    final threeHearts = task('Win the 3♥');
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
          Trick(0, [0, 1, 2, 3], [c('3♥'), c('3♦'), c('5♥'), c('2♥')], 2),
        ],
        totalTricks: 10,
        inPlay: fullDeck().toSet());
    expect(taskProgress('Win all four 3s', v, 2, null), '2/4');
    expect(taskProgress('Win at least five ♥ cards', v, 2, null), '3/5');
    expect(taskProgress('Win exactly X tricks, announced to everyone', v, 2, 2),
        '1/2');
    expect(taskProgress('Win the 3♥', v, 2, null), isNull);
  });

  test('The King can never take a task the K♠ makes impossible', () {
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
