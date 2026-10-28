/// The trick in the middle of the on-screen table (ui/table/trick_view.dart):
/// the cards played so far, each edged in its player's colour, the winner's
/// glowing once the trick is won.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/play/card_view.dart';
import 'package:kings_court/ui/table/trick_view.dart';

final players = [
  for (final n in ['Ann', 'Ben', 'Cal'])
    Player(n, colorValue: 0xFF000000 | (n.codeUnitAt(0) << 8))
];

Widget middle(List<Widget> cards) => MaterialApp(
    home: SizedBox(
        width: 400, height: 200, child: Stack(clipBehavior: Clip.none, children: cards)));

void main() {
  test('Trick cards fit the table: narrower with more players, never tiny', () {
    expect(trickCardWidth(360, 3), lessThan(trickCardWidth(360, 2)));
    expect(trickCardWidth(100, 6), 34);
    expect(trickCardWidth(2000, 3), 100);
  });

  testWidgets('The cards played so far show from their seats; a won trick glows for the winner', (tester) async {
    final round = Round(players: 3, target: 6)
      ..hands = [
        [PlayingCard.parse('9♠'), PlayingCard.parse('2♥')],
        [PlayingCard.parse('3♠'), PlayingCard.parse('4♥')],
        [PlayingCard.parse('5♠'), PlayingCard.parse('6♥')],
      ]
      ..setAside = []
      ..king = 0
      ..leader = 0
      ..phase = Phase.playing;
    expect(trickCards(
        area: const Size(400, 200), round: round, trick: null, collecting: false,
        players: players, origin: (_, __) => null), isEmpty);
    round.apply(PlayCard(0, PlayingCard.parse('9♠')));
    round.apply(PlayCard(1, PlayingCard.parse('3♠')));
    final mid = trickCards(
        area: const Size(400, 200),
        round: round,
        trick: null,
        collecting: false,
        players: players,
        origin: (seat, _) => Offset(seat * 100.0, 0));
    await tester.pumpWidget(middle(mid));
    await tester.pumpAndSettle();
    expect(find.byType(PlayingCardView), findsNWidgets(2));
    final views = tester.widgetList<PlayingCardView>(find.byType(PlayingCardView)).toList();
    expect(views[0].edge, players[0].color);
    expect(views[1].edge, players[1].color);
    expect(views.any((v) => v.glow), isFalse);
    // The third card wins the trick (the 9♠ led; seat 0 wins it).
    round.apply(PlayCard(2, PlayingCard.parse('5♠')));
    final trick = round.tricks.last;
    expect(trick.winner, 0);
    final won = trickCards(
        area: const Size(400, 200),
        round: round,
        trick: trick,
        collecting: false,
        players: players,
        origin: (_, __) => null);
    await tester.pumpWidget(middle(won));
    await tester.pumpAndSettle();
    final after = tester.widgetList<PlayingCardView>(find.byType(PlayingCardView)).toList();
    expect(after, hasLength(3));
    expect([for (final v in after) v.glow], [true, false, false]);
  });
}
