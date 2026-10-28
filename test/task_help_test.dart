import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/engine/conflicts.dart';
import 'package:kings_court/task_help.dart';

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

  test("Tasks about what not to do have trackers too", () {
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
    expect(selfClash(most, two, players: 4), isTrue);
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

  test('Your own hand can rule a task out', () {
    PlayingCard c(String l) => PlayingCard.parse(l)!;
    expect(handBlocks('Win the 7♥ with a Court Card', [c('7♥'), PlayingCard.jack]),
        contains('You hold the 7♥'));
    expect(handBlocks('Win the 7♥ with a Court Card', [c('2♣')]), isNotNull);
    expect(handBlocks('Win the 7♥ with a Court Card', [c('2♣'), PlayingCard.jack]),
        isNull);
    expect(handBlocks('Win a trick with an Ace', [c('2♣')]), isNotNull);
    expect(handBlocks('Win a trick with the Joker', [c('2♣')]), isNotNull);
    expect(handBlocks('Win the Queen with the King', [PlayingCard.king, PlayingCard.queen]), isNotNull);
    expect(handBlocks('Win the Queen with the King', [PlayingCard.king, c('2♣')]), isNull);
    expect(handBlocks('Win a trick with a 3', [c('3♣')]), isNull);
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
