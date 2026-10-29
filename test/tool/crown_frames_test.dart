// Frames of the walk into a game on screen: the coronation from the menus,
// then the crown flying to the King's seat, every 40ms, for looking at
// the hand-over between the two. Run with --update-goldens.
@Tags(['tool'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/platform/sfx.dart';
import 'package:kings_court/ui/app.dart';
import 'package:kings_court/ui/table_page.dart';
import 'package:kings_court/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shots_test.dart' show loadFonts;

void main() {
  testWidgets('Into a game, frame by frame', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Sfx.muteForTests = true;
    HomePageTestHooks.seed = 7;
    CharacterToken.alive = true;
    await loadFonts();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('New game'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Single player'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Free play'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Start'));
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/crown-${i.toString().padLeft(2, '0')}.png'));
    }
  });
}
