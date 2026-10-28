import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/modes/tutorial/lessons.dart';

void main() {
  for (var i = 0; i < lessons.length; i++) {
    final lesson = lessons[i];

    test('Lesson ${i + 1} (${lesson.title}) deals a full, fair hand', () {
      final d = lesson.deal();
      final all = [...d.hands.expand((h) => h), ...d.setAside];
      expect(all.toSet(), fullDeck().toSet(), reason: 'every card once');
      expect(all, hasLength(40));
      expect(d.hands.map((h) => h.length).toSet(), {handSize(3)});
      expect(d.hands[0], contains(PlayingCard.king), reason: 'you are the King');
      for (var s = 0; s < 3; s++) {
        for (final label in lesson.cards[s]) {
          expect(d.hands[s], contains(PlayingCard.parse(label)), reason: label);
        }
        for (final suit in lesson.avoid[s] ?? const <Suit>{}) {
          final listed = lesson.cards[s].map(PlayingCard.parse).toSet();
          expect(
              d.hands[s].where((c) => c.suit == suit && !listed.contains(c)),
              isEmpty,
              reason: 'seat $s avoids ${suit.name}');
        }
      }
      for (final t in lesson.tasks) {
        expect(taskRules, contains(t), reason: 'a known task: $t');
      }
    });

    test('Lesson ${i + 1} (${lesson.title}) is won by following the coach', () {
      final d = lesson.deal();
      final m = Round(players: 3, target: 1)
        ..hands = d.hands
        ..setAside = d.setAside
        ..king = 0
        ..leader = 0
        ..tasks = [
          for (int t = 0; t < lesson.tasks.length; t++)
            RoundTask(taskByDescription(lesson.tasks[t]),
                // You take the first task; any other goes to the Duke.
                owner: t == 0 ? 0 : 1)
        ]
        ..phase = Phase.playing;
      var guard = 0;
      while (m.phase == Phase.playing && guard++ < 40) {
        final trick = m.tricks.length;
        final seat = m.turn;
        final card = seat == 0 ? lesson.hint(trick) : lesson.scripted(trick, seat);
        expect(card, isNotNull,
            reason: 'trick $trick, seat $seat has a planned card');
        expect(m.legalFor(seat), contains(card),
            reason: 'trick $trick: $card is a legal play for seat $seat');
        m.apply(PlayCard(seat, card!));
      }
      expect(m.won, isTrue);
      expect(m.tasks.every((t) => t.isCompleted), isTrue);
    });
  }
}
