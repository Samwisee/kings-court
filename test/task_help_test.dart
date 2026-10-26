import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/rules.dart';
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
    expect(taskProgress("Don't win any of the first three tricks", v, 1, null),
        'safe 1/3');
    expect(taskProgress("Don't win any tricks", v, 1, null), 'safe 1/13');
    expect(taskProgress('Win no Court Cards', v, 1, null), 'safe 1/13');
    expect(taskProgress('Win the last trick', v, 1, null), '12 to go');
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
    expect(failReason("Don't win any ♣ cards", view([Trick(0, const [0, 1, 2], [c('9♣'), c('2♣'), c('3♠')], 0)]), 0, null, names),
        contains('trick 1'));
  });

  test('Number tasks track which cards are still to come', () {
    PlayingCard c(String l) => PlayingCard.parse(l)!;
    final v = view([Trick(0, const [0, 1, 2], [c('6♥'), c('2♥'), c('3♥')], 0)]);
    expect(taskProgress('Win any 6 with another 6', v, 1, null), '6s: 3 left');
    final s = taskStatus('Win any 6 with another 6', v, 1, null);
    expect(s, contains('6♥ (trick 1)'));
    expect(s, contains('6♦'));
    expect(s, isNot(contains('Not yet')));
  });
}
