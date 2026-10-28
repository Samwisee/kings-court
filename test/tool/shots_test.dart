// Screenshots of solo Dynasty's story scenes, for checking the look
// without a phone. Run with --update-goldens; CI pushes them to the
// "shots" branch.
@Tags(['tool'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/game/courtiers.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/modes/tutorial/lessons.dart';
import 'package:kings_court/play/card_view.dart';
import 'package:kings_court/play/throne_room.dart';
import 'package:kings_court/sfx.dart';
import 'package:kings_court/ui/app.dart';
import 'package:kings_court/ui/table_page.dart';
import 'package:kings_court/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // The same deals and the same courtiers' choices every run, so a
    // screenshot that changed means the code did.
    HomePageTestHooks.seed = 7;
    await loadFonts();
  });

  testWidgets('Tutorial', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    HomePageTestHooks.fast();
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tut-0-welcome.png'));
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tut-0-play.png'));
    await tester.tap(find.text('Tutorial'));
    await tester.pumpAndSettle();
    // Each lesson's pages, shot one by one, then the lesson.
    Future<void> readPages(List<IntroPage> pages, String name, String finish) async {
      for (var i = 0; i < pages.length; i++) {
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('goldens/tut-$name-$i.png'));
        if (i == pages.length - 1) {
          await tester.tap(find.text(finish).last);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        } else {
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
        }
      }
    }

    await readPages(lessons[0].pages, '0-intro', 'Play lesson 1');
    final state = tester.state<HomePageState>(find.byType(HomePage));
    final game = state.game;
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
    }

    Future<void> snap(String name) => expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tut-$name.png'));
    for (var lesson = 0; lesson < 4; lesson++) {
      for (var i = 0; i < 300 && game.round!.pickTurn != 0; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await frames(40);
      await snap('${lesson + 1}a-pick');
      state.debugYourMove();
      await frames(80);
      await snap('${lesson + 1}b-play');
      for (var i = 0; i < 2000 && game.outcome == RoundOutcome.inProgress; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        state.debugYourMove();
      }
      await frames(40);
      await snap('${lesson + 1}c-done');
      final next = find.text(lesson == 3 ? 'Finish' : 'Next lesson');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await tester.pumpAndSettle();
      await readPages(
          lesson == 3 ? outroPages : lessons[lesson + 1].pages,
          lesson == 3 ? 'outro' : '${lesson + 2}-intro',
          lesson == 3 ? 'Finish' : 'Play lesson ${lesson + 2}');
    }
    await frames(30);
    await snap('5-ready');
  });

  testWidgets('A phone, a big round', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    HomePageTestHooks.fast();
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Single player'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();
    if (find.text('Next').evaluate().isNotEmpty) await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(90, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    final state = tester.state<HomePageState>(find.byType(HomePage));
    final game = state.game;
    var shot = 0;
    Future<void> snap() => expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/phone-${shot++}.png'));
    // Dealt, and waiting to hear whether you'll share a card.
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await snap();
    for (var i = 0; i < 400 && game.round!.pickTurn != null; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (i == 3) await snap();
      if (i % 4 == 0) state.debugYourMove();
    }
    for (var i = 0; i < 900 && shot < 5; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (i % 150 == 40) await snap();
      state.debugYourMove();
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('A laptop window during play', (tester) async {
    tester.view.physicalSize = const Size(2192, 1518);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    HomePageTestHooks.fast();
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/laptop-how.png'));
    await tester.tap(find.text('Single player'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();
    if (find.text('Next').evaluate().isNotEmpty) await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    final state = tester.state<HomePageState>(find.byType(HomePage));
    final game = state.game;
    var shot = 0;
    Future<void> snap() async {
      for (final e in find.byType(PlayingCardView).evaluate().take(3)) {
        final box = e.renderObject! as RenderBox;
        debugPrint('LAPTOP card ${box.localToGlobal(Offset.zero)} ${box.size}');
      }
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/laptop-${shot++}.png'));
    }

    for (var i = 0; i < 400 && game.round!.pickTurn != null; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (i == 40) await snap();
      state.debugYourMove();
    }
    await snap();
    for (var i = 0; i < 1500 && shot < 6; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (i % 120 == 60) await snap();
      state.debugYourMove();
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  for (final onScreen in [true, false]) {
    testWidgets('A wide screen, ${onScreen ? 'on-screen cards' : 'round table'}',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      HomePageTestHooks.fast();
      await tester.pumpWidget(const TheKingsCourtApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('New game'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(onScreen ? 'Single player' : 'In person'));
      if (onScreen) {
        // Frames through the page change, to check nothing jumps.
        await tester.pump();
        for (var f = 0; f < 6; f++) {
          await expectLater(find.byType(MaterialApp),
              matchesGoldenFile('goldens/zz-turn-$f.png'));
          await tester.pump(const Duration(milliseconds: 80));
        }
      }
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/wide-0-modes.png'));
      await tester.tap(find.text('Free play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(onScreen ? '3' : '4').last);
      await tester.pumpAndSettle();
      if (find.text('Next').evaluate().isNotEmpty) await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      if (!onScreen) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Start'));
      final state = tester.state<HomePageState>(find.byType(HomePage));
      final game = state.game;
      final name = onScreen ? 'screen' : 'table';
      if (onScreen) {
        for (var i = 0; i < 400 && game.round!.pickTurn != null; i++) {
          await tester.pump(const Duration(milliseconds: 30));
          state.debugYourMove();
        }
        for (var i = 0; i < 160; i++) {
          await tester.pump(const Duration(milliseconds: 30));
          if (i == 60) state.debugYourMove();
        }
      } else {
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byType(SeatToken).first);
        for (var i = 0; i < 250; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
      }
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/wide-$name-1.png'));
      // The menu and the points target.
      await tester.tap(find.byTooltip('Menu'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/wide-$name-menu.png'));
      await tester.tapAt(const Offset(40, 900));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      // Report a bug, from the menu.
      await tester.tap(find.byTooltip('Menu'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.tap(find.text('Report a bug'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.enterText(find.byKey(const ValueKey('bugMessage')),
          'I tapped the Jester and nothing happened.');
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/wide-$name-bug.png'));
      await tester.tap(find.text('Cancel'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      final points = find.byTooltip('Points target');
      if (points.evaluate().isNotEmpty) {
        await tester.tap(points.first);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('goldens/wide-$name-points.png'));
        await tester.tap(find.text('Cancel'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
      }
      // A task's close-up: what it means, its words, how it's going.
      final cards = find
          .textContaining(RegExp("^(Win|Don't|Never)"), findRichText: true)
          .hitTestable();
      if (cards.evaluate().isNotEmpty) {
        await tester.tap(cards.first);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('goldens/wide-$name-2-task.png'));
        final chip = find.byType(ChoiceChip);
        if (chip.evaluate().isNotEmpty) {
          await tester.tap(chip.first);
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 30));
          }
          await expectLater(find.byType(MaterialApp),
              matchesGoldenFile('goldens/wide-$name-3-word.png'));
        }
        final close = find.text('Close');
        if (close.evaluate().isNotEmpty) await tester.tap(close);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
      }
      if (onScreen) {
        await tester.tap(find.byTooltip('Card tracker'));
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('goldens/wide-$name-5-cards.png'));
        // A player in the key: what they may hold.
        final who = find.bySemanticsLabel(RegExp('^What .* may hold'));
        if (who.evaluate().isNotEmpty) {
          await tester.tap(who.first);
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 30));
          }
          await expectLater(find.byType(MaterialApp),
              matchesGoldenFile('goldens/wide-$name-6-hand.png'));
        }
        await tester.tap(find.byTooltip('Close').last);
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.tap(find.byTooltip('Menu'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.tap(find.text('Four-colour suits'));
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('goldens/wide-$name-4-four-colour.png'));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('The front page, wide', (tester) async {
    tester.view.physicalSize = const Size(3840, 2160);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    HomePageTestHooks.fast();
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/wide-welcome.png'));
  });

  testWidgets('The Court Cards', (tester) async {
    tester.view.physicalSize = const Size(1400, 560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0E4A2E),
        body: Center(
          child: Wrap(spacing: 16, runSpacing: 16, children: [
            for (final w in [150.0, 60.0])
              for (final c in [PlayingCard.joker, PlayingCard.jack, PlayingCard.queen, PlayingCard.king])
                PlayingCardView(card: c, width: w),
          ]),
        ),
      ),
    ));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/court-cards.png'));
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
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    for (final e in find.byType(AnimatedPositioned).evaluate()) {
      final box = e.renderObject! as RenderBox;
      debugPrint('POS ${box.localToGlobal(Offset.zero)} ${box.size}');
    }
    for (final e in find.byType(Opacity).evaluate()) {
      debugPrint('OPA ${(e.widget as Opacity).opacity}');
    }
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/zz-room.png'));
    await tester.pump(const Duration(seconds: 6));
  });
}
