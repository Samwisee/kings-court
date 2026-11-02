/// Steps through a Dynasty run in the app, for the flow test and the
/// screenshots: open its tile, read the court, pick, play, back to court.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/ui/setup/setup_panel.dart';
import 'package:kings_court/ui/table_page.dart';

Future<void> frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
}

/// From the front page: New game, Single player, the Dynasty tile five
/// times (it opens), then once more to begin.
Future<void> openDynasty(WidgetTester tester) async {
  await tester.tap(find.text('New game'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Single player'));
  await tester.pumpAndSettle();
  expect(find.text('(Coming soon)'), findsOneWidget);
  for (var i = 0; i < 5; i++) {
    await tester.tap(find.text('Dynasty'));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(SetupPanel.dynastyOpen, isTrue);
  expect(find.text('(Alpha)'), findsOneWidget);
  await tester.tap(find.text('Dynasty'));
  await frames(tester, 30);
}

/// Taps through the throne room until [stop] shows.
Future<void> tapCourtUntil(WidgetTester tester, Finder stop, {int guard = 40}) async {
  for (var i = 0; i < guard && stop.evaluate().isEmpty; i++) {
    await tester.tap(find.byKey(const ValueKey('court')), warnIfMissed: false);
    await frames(tester, 12);
  }
  expect(stop, findsWidgets);
}

/// Picks the project called [title], and begins the hand.
Future<void> pickAndBegin(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('begin-hand')));
  await frames(tester, 40);
}

/// Plays your part of the hand until its card offers the court.
Future<void> playHand(WidgetTester tester) async {
  final state = tester.state<HomePageState>(find.byType(HomePage));
  for (var i = 0; i < 3000 && state.game.outcome == RoundOutcome.inProgress; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    state.debugYourMove();
  }
  await frames(tester, 40);
}
