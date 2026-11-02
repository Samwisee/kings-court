/// Dynasty in the app: five taps open its tile, the court speaks, a work
/// is picked, the hand is played at the table, and the court follows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/platform/sfx.dart';
import 'package:kings_court/ui/app.dart';
import 'package:kings_court/ui/setup/setup_panel.dart';
import 'package:kings_court/ui/table_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dynasty_steps.dart';

void main() {
  testWidgets('Five taps open Dynasty; a hand is picked, played, and the court follows', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Sfx.muteForTests = true;
    HomePageTestHooks.seed = 5;
    addTearDown(() {
      SetupPanel.dynastyOpen = false;
      HomePageTestHooks.seed = null;
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    HomePageTestHooks.fast();
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await openDynasty(tester);
    expect(find.byKey(const ValueKey('court')), findsOneWidget);
    await tapCourtUntil(tester, find.byKey(const ValueKey('begin-hand')));
    expect(find.text('Raise the cathedral'), findsOneWidget);
    await pickAndBegin(tester, 'Raise the cathedral');
    final state = tester.state<HomePageState>(find.byType(HomePage));
    expect(state.game.isDynasty, isTrue);
    expect(state.game.tasks.single.description, 'Win at least four ♠ cards');
    await playHand(tester);
    await tester.tap(find.byKey(const ValueKey('to-court')));
    await frames(tester, 30);
    expect(find.byKey(const ValueKey('court')), findsOneWidget);
    // The herald's news of the hand, the next hand to come.
    expect(find.textContaining('Hand 2'), findsWidgets);
    // The throne room's figures wander on a timer: let it go.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
