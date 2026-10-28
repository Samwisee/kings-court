import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/conflicts.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/engine/task_help.dart';

void main() {
  RoundView view(List<Trick> tricks) => RoundView(
      players: 3,
      king: 0,
      tricks: tricks,
      totalTricks: 13,
      inPlay: fullDeck().toSet());

  test('Every task is explained in plain words', () {
    for (final d in taskRules.keys) {
      final e = explainTask(d);
      expect(e, isNot(d), reason: 'no explanation for: $d');
      expect(e.length, greaterThan(40), reason: d);
    }
  });

  test('Every game word a task uses is in the glossary', () {
    for (final d in taskRules.keys) {
      for (final t in termsIn(d)) {
        expect(glossary, contains(t), reason: '$d uses $t');
      }
    }
    expect(termsIn('Win the 3♥'), containsAll(['Trick', 'Win a card', 'Suit']));
    expect(termsIn('Win the first trick'), contains('Win a trick'));
  });

  test('Every task says how it is going, from the first trick', () {
    for (final d in taskRules.keys) {
      expect(taskStatus(d, view(const []), 1, 2), isNotEmpty, reason: d);
    }
  });

  test('Tasks about what not to do have trackers too', () {
    final t = Trick(0, const [0, 1, 2],
        [PlayingCard.parse('9♠')!, PlayingCard.parse('2♠')!, PlayingCard.parse('3♠')!], 0);
    final v = view([t]);
    expect(taskProgress("Don't win any of the first three tricks", v, 1, null), '1/3');
    // Nothing simple to count: the close-up says how it's going.
    expect(taskProgress("Don't win any tricks", v, 1, null), isNull);
    expect(taskProgress('Win the last trick', v, 1, null), isNull);
    expect(taskStatus("Don't win any of the first three tricks", v, 1, null),
        contains('1 of the first 3'));
  });

  test('A failed task says why', () {
    PlayingCard c(String l) => PlayingCard.parse(l)!;
    final names = ['You', 'The Duke', 'The Bishop'];
    final t = Trick(0, const [0, 1, 2], [c('2♥'), c('3♥'), c('9♣')], 1);
    final v = view([t]);
    expect(failReason('Win the 3♥', v, 0, null, names),
        'The Duke won the 3♥ in trick 1.');
    final mine = Trick(0, const [0, 1, 2], [c('9♠'), c('2♠'), c('3♠')], 0);
    expect(
        failReason("Don't win any of the first three tricks", view([mine]), 0,
            null, names),
        'You won trick 1.');
    expect(failReason("Don't win any ♥ cards", view([Trick(0, const [0, 1, 2], [c('9♥'), c('2♥'), c('3♠')], 0)]), 0, null, names),
        contains('trick 1'));
  });

  test('Number tasks track which cards are still to come', () {
    PlayingCard c(String l) => PlayingCard.parse(l)!;
    final v = view([Trick(0, const [0, 1, 2], [c('7♥'), c('2♥'), c('3♥')], 0)]);
    expect(taskProgress('Win at least three 7s', v, 1, null), '0/3');
    final s = taskStatus('Win at least three 7s', v, 1, null);
    expect(s, contains('0 of 3'));
    expect(s, isNot(contains('Not yet')));
  });

  test('Some pairs of trick tasks are impossible at a bigger table', () {
    const most = 'Win more tricks than anyone else';
    const two = 'Win exactly two tricks';
    expect(selfClash(most, two), isTrue);
    expect(selfClash(two, most, players: 5), isTrue);
  });

  test('The court’s own tasks judge the tricks right', () {
    PlayingCard c(String l) => PlayingCard.parse(l)!;
    // The King (seat 0) leads and wins trick 1; seat 1 wins the next: the
    // trick after the King's.
    final t1 = Trick(0, const [0, 1, 2], [c('9♠'), c('2♠'), c('3♠')], 0);
    final t2 = Trick(0, const [0, 1, 2], [c('4♥'), c('5♥'), c('2♥')], 1);
    final after = taskRules['Win the trick right after the King wins one']!;
    expect(after(view([t1]), 1, null), Verdict.pending);
    expect(after(view([t1, t2]), 1, null), Verdict.done);
    expect(taskRules['Win a trick the King leads']!(view([t1]), 0, null), Verdict.done);
    expect(taskRules['Win a trick as the last to play']!(view([t1]), 2, null), Verdict.pending);
    expect(taskRules['Win a trick with a card just one above the card led']!(view([t2]), 1, null), Verdict.done);
    expect(taskRules['Win no tricks until the King has won one']!(view([t1, t2]), 1, null), Verdict.done);
    expect(taskRules['Win no tricks until the King has won one']!(view([t2]), 1, null), Verdict.failed);
    // The Queen falls in trick 1; trick 2 is the one after.
    final q = Trick(0, const [0, 1, 2], [c('9♠'), PlayingCard.queen, c('3♠')], 1);
    expect(taskRules['Win the trick after the Queen is played']!(view([q, t2]), 1, null), Verdict.done);
    expect(taskRules['Win the trick after the Queen is played']!(view([q, t2]), 2, null), Verdict.failed);
    // The Queen won with the King.
    final qk = Trick(0, const [0, 1, 2], [c('9♠'), PlayingCard.queen, PlayingCard.king], 2);
    expect(taskRules['Win the Queen with the King']!(view([qk]), 2, null), Verdict.done);
    expect(taskRules['Win the Queen with the King']!(view([q]), 1, null), Verdict.failed);
    // Three suits in one trick; nobody followed.
    final mixed = Trick(0, const [0, 1, 2], [c('9♠'), c('2♥'), c('3♣')], 0);
    expect(taskRules['Win a trick with three different suits in it']!(view([mixed]), 0, null), Verdict.done);
    expect(taskRules['Win a trick where no one followed suit']!(view([mixed]), 0, null), Verdict.done);
    expect(taskRules['Win a trick where no one followed suit']!(view([t1]), 0, null), Verdict.pending);
  });

  test('Tasks about shown cards judge what was shown, and when', () {
    PlayingCard c(String l) => PlayingCard.parse(l)!;
    final t1 = Trick(0, const [0, 1, 2], [c('9♠'), c('2♠'), c('3♠')], 0);
    final t2 = Trick(0, const [0, 1, 2], [c('4♥'), c('5♥'), c('2♥')], 1);
    RoundView shown(List<Trick> tricks, Map<int, PlayingCard> s, Map<int, int> at) => RoundView(
        players: 3, king: 0, tricks: tricks, totalTricks: 13,
        inPlay: fullDeck().toSet(), shown: s, shownAt: at);
    // Seat 0 showed the 9♠ before the first trick, and won it.
    final v = shown([t1, t2], {0: c('9♠')}, {0: 0});
    expect(taskRules['Win the card you showed']!(v, 0, null), Verdict.done);
    expect(taskRules["Don't win the card you showed"]!(v, 0, null), Verdict.failed);
    expect(taskRules['Win the trick right after you show a card']!(v, 0, null), Verdict.done);
    expect(taskRules['Win a card someone else showed']!(v, 1, null), Verdict.pending);
    // Seat 1 showed only after trick 1 and won trick 2: fine.
    final late = shown([t1, t2], {1: c('5♥')}, {1: 1});
    expect(taskRules["Don't win a trick before you've shown a card"]!(late, 1, null), Verdict.done);
    // Seat 0 won trick 1 before showing anything.
    expect(taskRules["Don't win a trick before you've shown a card"]!(late, 0, null), Verdict.failed);
    // Nothing shown: these can't be done yet.
    final none = shown([t1], {}, {});
    expect(taskRules['Win the card you showed']!(none, 0, null), Verdict.pending);
    expect(selfClash('Win the card you showed', "Don't win the card you showed"), isTrue);
  });

  test('More of the court’s tasks judge the tricks right', () {
    PlayingCard c(String l) => PlayingCard.parse(l)!;
    final followed = Trick(0, const [0, 1, 2], [c('4♥'), c('5♥'), c('2♥')], 1);
    final ran = Trick(1, const [1, 2, 0], [c('3♣'), c('9♦'), c('7♣')], 0);
    final jj = Trick(0, const [0, 1, 2], [PlayingCard.joker, PlayingCard.jack, c('2♣')], 1);
    expect(taskRules['Win a trick where everyone followed suit']!(view([followed]), 1, null), Verdict.done);
    expect(taskRules['Win the trick in which someone first runs out of a suit']!(view([followed, ran]), 0, null), Verdict.done);
    expect(taskRules['Win the first trick a Court Card falls in']!(view([followed, jj]), 1, null), Verdict.done);
    expect(taskRules['Win the trick right after you lose one with a Court Card']!(view([jj, ran]), 0, null), Verdict.done);
    expect(taskRules['Win your first trick with a Court Card']!(view([followed]), 1, null), Verdict.failed);
    expect(taskRules['Win your first trick with a Court Card']!(view([jj]), 1, null), Verdict.done);
    expect(taskRules['Never win two tricks in a row']!(view([followed, followed]), 1, null), Verdict.failed);
  });

  test('Your own hand can rule a task out', () {
    PlayingCard c(String l) => PlayingCard.parse(l)!;
    expect(handBlocks('Win the 7♥ with a Court Card', [c('7♥'), PlayingCard.jack]),
        contains('You hold the 7♥'));
    expect(handBlocks('Win the 7♥ with a Court Card', [c('2♣')]), isNotNull);
    expect(handBlocks('Win the 7♥ with a Court Card', [c('2♣'), PlayingCard.jack]),
        isNull);
    expect(handBlocks('Win a trick with the Joker', [c('2♣')]), isNotNull);
    expect(handBlocks('Win the Queen with the King', [PlayingCard.king, PlayingCard.queen]), isNotNull);
    expect(handBlocks('Win the Queen with the King', [PlayingCard.king, c('2♣')]), isNull);
    expect(handBlocks('Win a trick with a 5', [c('5♣')]), isNull);
  });

  test('A task close-up shows the cards it is about', () {
    PlayingCard c(String l) => PlayingCard.parse(l)!;
    expect(relevantCards('Win the A♥ and the 9♥'), [c('A♥'), c('9♥')]);
    expect(relevantCards('Win at least three 7s'), hasLength(4));
    expect(relevantCards('Win a trick with the Joker'), hasLength(4));
    expect(relevantCards('Win no Court Cards'), hasLength(4));
    expect(relevantCards("Don't win any ♦ or ♠ cards"), hasLength(18));
    expect(relevantCards('Win the first trick'), isEmpty);
  });
}
