/// The decree overlay (ui/overlays/decree.dart): the scroll says the
/// decree and who it names, and clears when accepted; the dialog opens for
/// a round under a decree and not otherwise.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/decrees.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/ui/overlays/decree.dart';
import 'package:kings_court/ui/widgets.dart';

final players = [for (final n in ['Ann', 'Ben', 'Cal']) Player(n, colorValue: 0xFF000000)];

Round roundUnder(Decree? decree, {int? exiled}) => Round(players: 3, target: 6)
  ..decree = decree
  ..exiledSeat = exiled;

void main() {
  test('The detail names the exiled seat, and nothing under other decrees', () {
    expect(decreeDetail(roundUnder(Decree.exile, exiled: 1), players),
        'Seat B is exiled this round.');
    expect(decreeDetail(roundUnder(Decree.silence), players), isNull);
    expect(decreeDetail(roundUnder(Decree.exile), players), isNull);
  });

  testWidgets('The overlay reads the decree and is accepted', (tester) async {
    var accepted = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DecreeOverlay(
                round: roundUnder(Decree.exile, exiled: 2),
                players: players,
                onAccept: () => accepted = true))));
    await tester.pumpAndSettle();
    expect(find.text(Decree.exile.title), findsOneWidget);
    expect(find.text('Seat C is exiled this round.'), findsOneWidget);
    await tester.tap(find.byType(FilledButton).first);
    expect(accepted, isTrue);
  });

  testWidgets('The dialog opens for a round under a decree, and not for one without', (tester) async {
    Future<void> open(Round round) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showDecree(context, round, players),
                      child: const Text('Seal'))))));
      await tester.tap(find.text('Seal'));
      await tester.pumpAndSettle();
    }

    await open(roundUnder(Decree.silence));
    expect(find.text(Decree.silence.title), findsOneWidget);
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    expect(find.text(Decree.silence.title), findsNothing);
    await open(roundUnder(null));
    expect(find.byType(DecreeScroll), findsNothing);
  });
}
