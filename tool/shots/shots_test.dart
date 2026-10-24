// Screenshots of solo Dynasty's story scenes, for checking the look
// without a phone. Run with --update-goldens; CI pushes them to the
// "shots" branch.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kings_court/main.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/sfx.dart';
import 'package:kings_court/widgets.dart';
import 'package:kings_court/courtiers.dart';
import 'package:kings_court/play/throne_room.dart';

Future<void> loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }

  await family('CinzelDecorative', [
    'assets/fonts/CinzelDecorative-Bold.ttf',
    'assets/fonts/CinzelDecorative-Black.ttf',
  ]);
  await family('AlegreyaSans', [
    'assets/fonts/AlegreyaSans-Regular.ttf',
    'assets/fonts/AlegreyaSans-Medium.ttf',
    'assets/fonts/AlegreyaSans-Bold.ttf',
  ]);
  try {
    await family('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  } catch (_) {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Sfx.muteForTests = true;
    await loadFonts();
  });

  testWidgets('A throne room on its own', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ThroneRoom(
        title: 'A Test',
        figures: const [
          HallFigure('duke', Courtier.duke, Colors.blue),
          HallFigure('bishop', Courtier.bishop, Colors.purple),
          HallFigure('general', Courtier.general, Colors.teal),
        ],
        lines: const [
          HallLine('Hello there.', who: 'duke'),
          HallLine('The herald speaks.'),
        ],
        king: const SizedBox(width: 40, height: 40),
        kingName: 'King Test',
        coffers: 12,
        right: HallChoice('Go', () {}),
      ),
    ));
    for (int i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    for (final e in find.byType(AnimatedPositioned).evaluate()) {
      final box = e.renderObject as RenderBox;
      debugPrint('POS ${box.localToGlobal(Offset.zero)} ${box.size}');
    }
    for (final e in find.byType(Opacity).evaluate()) {
      debugPrint('OPA ${(e.widget as Opacity).opacity}');
    }
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/zz-room.png'));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Throne room scenes', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    HomePageTestHooks.fast();
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dynasty'));
    await tester.tap(find.text('Dynasty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final sw = find.widgetWithText(SwitchListTile, 'On-screen cards');
    if (!tester.widget<SwitchListTile>(sw).value) {
      await tester.tap(sw);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Begin the reign'));
    final state = tester.state(find.byType(HomePage)) as dynamic;
    final game = state.game as GameState;
    var shot = 0;
    Future<void> snap(String name) async {
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/${(shot++).toString().padLeft(2, '0')}-$name.png'));
    }

    // The coronation, part way through, then done.
    debugPrint('SHAPED ${find.byType(ShapedToken).evaluate().length}');
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await snap('coronation');
    final seen = <String>{};
    for (int i = 0; i < 6000 && shot < 14; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (i % 300 == 0) {
        debugPrint('LOOP $i outcome=${game.outcome} pick=${game.pickTurn} '
            'tasks=${game.tasks.map((t) => t.assignedPlayerIndex).toList()} '
            'tricks=${game.cards?.tricks.length} decree=${game.decree} '
            'texts=${find.byType(Text).hitTestable().evaluate().take(6).map((e) => (e.widget as Text).data).toList()}');
      }
      String? tap;
      for (final t in ['So it begins', 'Hear the council', 'The next matter', 'To the cards', 'Got it', 'Announce', 'Let it be done']) {
        if (find.text(t).hitTestable().evaluate().isNotEmpty) tap = t;
      }
      // A matter before the throne: take the first choice.
      final d = state.debugDilemma as int?;
      final key = '${game.dealId}-$tap-$d';
      if (tap != null && !seen.contains(key)) {
        seen.add(key);
        debugPrint('AT $tap shaped=${find.byType(ShapedToken).evaluate().length} '
            'court=${game.court} figures=${find.byType(CharacterToken).evaluate().length}');
        for (int k = 0; k < 70; k++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await snap(tap.replaceAll(' ', '-').toLowerCase());
      }
      if (tap != null) {
        await tester.tap(find.text(tap).hitTestable().first);
        continue;
      }
      if (d != null && game.outcome != RoundOutcome.inProgress) {
        final choices = find.byType(InkWell).hitTestable();
        if (choices.evaluate().length >= 2 && !seen.contains('d$d-${game.dealId}')) {
          seen.add('d$d-${game.dealId}');
          for (int k = 0; k < 70; k++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
          await snap('matter');
          await tester.tap(choices.first);
          continue;
        }
      }
      state.debugYourMove();
    }
  });
}
