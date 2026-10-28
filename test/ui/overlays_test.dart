/// The table's overlays (ui/overlays/): the King prompt's wording, the
/// play flourish, the crowning scene with its fanfare, and the walk-in's
/// crown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/ui/overlays/crowning.dart';
import 'package:kings_court/ui/overlays/king_prompt.dart';
import 'package:kings_court/ui/overlays/play_flourish.dart';
import 'package:kings_court/widgets.dart';

Widget onTable(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 600, height: 400, child: child)));

void main() {
  testWidgets('The King prompt says what to do, on screen and at a real table', (tester) async {
    await tester.pumpWidget(onTable(
        const KingPrompt(maxWidth: 300, cardWidth: 60, onScreen: true, players: 4)));
    expect(find.text('Who holds the King card?'), findsOneWidget);
    expect(find.textContaining('Whoever holds the King card will be crowned'), findsOneWidget);
    await tester.pumpWidget(onTable(
        const KingPrompt(maxWidth: 300, cardWidth: 60, onScreen: false, players: 4)));
    expect(find.text('Tap their seat to crown the King and deal the tasks.'), findsOneWidget);
    await tester.pumpWidget(onTable(
        const KingPrompt(maxWidth: 300, cardWidth: 60, onScreen: false, players: 2)));
    expect(find.textContaining('If the Dummy has it, choose a King together.'), findsOneWidget);
  });

  testWidgets('"Play!" shows mid-flourish and not at either end', (tester) async {
    for (final t in [0.0, 1.0]) {
      await tester.pumpWidget(onTable(PlayFlourish(animation: AlwaysStoppedAnimation(t))));
      expect(find.text('Play!'), findsNothing, reason: 'at $t');
    }
    await tester.pumpWidget(
        onTable(const PlayFlourish(animation: AlwaysStoppedAnimation(0.4))));
    expect(find.text('Play!'), findsOneWidget);
  });

  testWidgets('The crowning glows, lands in sparks, and the other seats sound a fanfare', (tester) async {
    const seats = {
      0: Offset(300, 60),
      1: Offset(540, 200),
      2: Offset(300, 340),
      3: Offset(60, 200),
    };
    Widget scene(double t) => onTable(CrowningScene(
        animation: AlwaysStoppedAnimation(t),
        from: const Offset(300, 200),
        to: seats[2]!,
        spinTo: 0,
        seatSize: 44,
        king: 2,
        seats: seats));
    // In flight: the crown and the words, no sparks, no trumpets yet.
    await tester.pumpWidget(scene(0.3));
    expect(find.text('Long live the King'), findsOneWidget);
    expect(find.byType(CrownIcon), findsOneWidget);
    expect(find.byIcon(Icons.campaign_rounded), findsNothing);
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SparkBurst),
        findsNothing);
    // Landed: the sparks burst and every seat but the King's has a trumpet.
    await tester.pumpWidget(scene(0.8));
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SparkBurst),
        findsOneWidget);
    expect(find.byIcon(Icons.campaign_rounded), findsNWidgets(3));
  });

  testWidgets('The walk-in’s crown grows, lifts away, or waits for the King', (tester) async {
    Widget overlay(double t, {bool waiting = false, bool handedOver = false}) => onTable(
        CoronationOverlay(
            animation: AlwaysStoppedAnimation(t), waiting: waiting, handedOver: handedOver));
    await tester.pumpWidget(overlay(0));
    expect(find.byType(CrownIcon), findsNothing);
    await tester.pumpWidget(overlay(0.5));
    expect(find.byType(CrownIcon), findsOneWidget);
    // Lifted away at the end, unless it waits for the King to be chosen.
    await tester.pumpWidget(overlay(1));
    expect(find.byType(CrownIcon), findsNothing);
    await tester.pumpWidget(overlay(1, waiting: true));
    expect(find.byType(CrownIcon), findsOneWidget);
    // Once the crowning scene has taken the crown, only the felt remains.
    await tester.pumpWidget(overlay(1, waiting: true, handedOver: true));
    expect(find.byType(CrownIcon), findsNothing);
  });
}
