// Screenshots of solo Dynasty's story scenes, for checking the look
// without a phone. Run with --update-goldens; CI pushes them to the
// "shots" branch.
@Tags(['tool'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/game/courtiers.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/modes/tutorial/lessons.dart';
import 'package:kings_court/platform/sfx.dart';
import 'package:kings_court/skin/court/court_skin.dart';
import 'package:kings_court/skin/midnight/midnight_skin.dart';
import 'package:kings_court/skin/rooms/room_skins.dart';
import 'package:kings_court/skin/skin.dart';
import 'package:kings_court/skin/skin_scope.dart';
import 'package:kings_court/skin/skins.dart';
import 'package:kings_court/skin/tailored.dart';
import 'package:kings_court/ui/app.dart';
import 'package:kings_court/ui/cards/card_view.dart';
import 'package:kings_court/ui/cards/task_chip.dart';
import 'package:kings_court/ui/dynasty/hall_pieces.dart';
import 'package:kings_court/ui/dynasty/throne_room.dart';
import 'package:kings_court/ui/table_page.dart';
import 'package:kings_court/ui/widgets.dart';
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

  // Every skin beside the court's, wherever it's listed: the front page,
  // setup, a round and the menu.
  for (final skin in skins.skip(1)) {
  testWidgets('The ${skin.name} skin: front page, setup, a round, the menu', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    HomePageTestHooks.fast();
    await tester.pumpWidget(TheKingsCourtApp(skin: skin));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/skin-${skin.id}-0-welcome.png'));
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/skin-${skin.id}-1-setup.png'));
    await tester.tap(find.text('Single player'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();
    if (find.text('Next').evaluate().isNotEmpty) await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/skin-${skin.id}-2-table.png'));
    await tester.tap(find.byTooltip('Menu'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/skin-${skin.id}-3-menu.png'));
    // The Look dialog, worn in this skin.
    await tester.tap(find.text('Look: ${skin.name}'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/skin-${skin.id}-4-look.png'));
  });
  }

  // Looks mixed from the Look dialog's choices, at the table.
  BackChoice back(String id) => backChoices.firstWhere((b) => b.id == id);
  TaskChoice task(String id) => taskChoices.firstWhere((k) => k.id == id);
  final mixes = <String, Skin>{
    'stars': TailoredSkin(const MidnightSkin(), backChoice: back('herald'), taskChoice: task('decree')),
    'deco': TailoredSkin(const BallroomSkin(), backChoice: back('sunburst'), taskChoice: task('lacquer')),
    'tavern': TailoredSkin(const TavernSkin(), backChoice: back('crimson'), taskChoice: task('parchment')),
    'tiles': TailoredSkin(const CourtyardSkin(), backChoice: back('royal'), taskChoice: task('blueprint')),
  };

  for (final MapEntry(key: name, value: skin) in mixes.entries) {
    testWidgets('A look mixed in the Look dialog ($name), at the table', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      HomePageTestHooks.fast();
      await tester.pumpWidget(TheKingsCourtApp(skin: skin));
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
      await tester.tap(find.text('Start'));
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/mix-$name.png'));
    });
  }

  // Every card back and table the Look dialog offers, on the court.
  testWidgets('The backs and tables to choose from', (tester) async {
    tester.view.physicalSize = const Size(1600, 1700);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const court = CourtSkin();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: court.felt,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 14, runSpacing: 10, children: [
              for (final b in backChoices)
                SkinScope(skin: TailoredSkin(court, backChoice: b), child: const CardBack(width: 64)),
            ]),
            const SizedBox(height: 30),
            Wrap(spacing: 14, runSpacing: 10, children: [
              for (final t in tableChoices)
                Container(
                  width: 96,
                  height: 64,
                  color: t.table,
                  padding: const EdgeInsets.all(8),
                  child: ColoredBox(
                      color: t.felt,
                      child: CustomPaint(
                          painter: FeltPatternPainter(t.pattern, t.ink, ground: t.felt, scale: 0.5),
                          size: Size.infinite)),
                ),
            ]),
            const SizedBox(height: 20),
            // Every task card face, a task on each.
            Wrap(spacing: 14, runSpacing: 14, children: [
              for (final k in taskChoices)
                SkinScope(
                  skin: TailoredSkin(court, taskChoice: k),
                  child: SizedBox(
                    width: 130,
                    child: TaskChip(
                        task: RoundTask(taskByDescription('Win the first three tricks')),
                        points: 3,
                        text: 'Win the first three tricks',
                        color: court.players[k.id.length % 4],
                        width: 130,
                        progress: '1/3'),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/looks-choices.png'));
  });

  // Every skin's pieces side by side: the Court Cards and a few others,
  // large and small, a back, and the seats (the King's, whoever's turn).
  for (final skin in skins) {
    testWidgets('The ${skin.name} skin\'s pieces', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final players = [
        for (var i = 0; i < 4; i++) Player('P$i', colorValue: skin.players[i].toARGB32())
      ];
      await tester.pumpWidget(SkinScope(
        skin: skin,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: skin.theme(),
          home: Scaffold(
            backgroundColor: skin.felt,
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final c in [
                    PlayingCard.joker,
                    PlayingCard.jack,
                    PlayingCard.queen,
                    PlayingCard.king,
                    const PlayingCard(Suit.hearts, 7),
                    const PlayingCard(Suit.spades, 3),
                  ])
                    PlayingCardView(card: c, width: 96),
                  const CardBack(width: 96),
                ]),
                const SizedBox(height: 16),
                Wrap(spacing: 8, children: [
                  for (final c in [PlayingCard.king, const PlayingCard(Suit.diamonds, 9), const PlayingCard(Suit.clubs, 1)])
                    PlayingCardView(card: c, width: 44),
                  const CardBack(width: 44),
                ]),
                const SizedBox(height: 16),
                Wrap(spacing: 16, children: [
                  for (var i = 0; i < players.length; i++)
                    SeatToken(player: players[i], isKing: i == 0, highlighted: i == 1),
                ]),
              ]),
            ),
          ),
        ),
      ));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/skin-${skin.id}-pieces.png'));
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
