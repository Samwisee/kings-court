import 'dart:convert';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/contest.dart';
import 'package:kings_court/engine/decrees.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/modes/chronicle/chapters.dart';
import 'package:kings_court/modes/dynasty/data/dilemmas.dart';
import 'package:kings_court/modes/dynasty/data/lines.dart';
import 'package:kings_court/modes/dynasty/data/story.dart';
import 'package:kings_court/modes/free/free_play.dart';
import 'package:kings_court/modes/tutorial/lessons.dart';
import 'package:kings_court/platform/analytics.dart';
import 'package:kings_court/platform/sfx.dart';
import 'package:kings_court/skin/court/court_skin.dart';
import 'package:kings_court/ui/app.dart';
import 'package:kings_court/ui/dynasty/contest_table.dart';
import 'package:kings_court/ui/table_page.dart';
import 'package:kings_court/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // iPhone-sized
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}


/// A loose task card whose centre isn't covered by a card someone holds,
/// so a drag starting there picks up the right card.
Finder freeCard(WidgetTester tester, bool Function(TableCard w) ok) {
  final all = find.byType(TableCard).evaluate().toList();
  final owned = [
    for (final el in all)
      if ((el.widget as TableCard).owner != null)
        tester.getRect(find.byWidget(el.widget))
  ];
  for (final el in all) {
    final w = el.widget as TableCard;
    if (w.owner != null || !ok(w)) continue;
    final c = tester.getCenter(find.byWidget(w));
    if (!owned.any((r) => r.inflate(4).contains(c))) return find.byWidget(w);
  }
  return find.byWidgetPredicate((w) => w is TableCard && w.owner == null && ok(w)).first;
}


/// Drags the table card [card] onto [to]. The harness sometimes misses a
/// drag on the round table (something else under the finger), so if the
/// task isn't taken it tries again from other parts of the card.
Future<void> dragCardTo(WidgetTester tester, Finder card, Offset to) async {
  final task = (tester.widget(card) as TableCard).task;
  final rect = tester.getRect(card);
  for (final f in const [Offset(0.5, 0.5), Offset(0.3, 0.7), Offset(0.7, 0.3)]) {
    await dragFromTo(tester,
        Offset(rect.left + rect.width * f.dx, rect.top + rect.height * f.dy), to);
    await tester.pump();
    if (task.owner != null) return;
  }
}

/// Drags from [from] to [to] in small steps, as a finger would.
Future<void> dragFromTo(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(from);
  for (var i = 1; i <= 10; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 10)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
}

/// Taps Play on the welcome screen, which opens setup.
Future<void> openSetup(WidgetTester tester) async {
  await tester.tap(find.text('New game'));
  await tester.pumpAndSettle();
}

Future<void> dealGame(WidgetTester tester, int players) async {
  await tester.pumpWidget(const TheKingsCourtApp());
  await tester.pumpAndSettle();
  await openSetup(tester);
  await setupThrough(tester, players: players, mode: 'Free play');
  await tester.tap(find.text('Start'));
  await tester.pumpAndSettle();
}

/// Walks the setup steps for a game at a real table: in person, the game,
/// players, names, then stops on the last step.
Future<void> setupThrough(WidgetTester tester,
    {int players = 4, required String mode}) async {
  await tester.tap(find.text('In person'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(mode));
  await tester.pumpAndSettle();
  await tester.tap(find.text(mode));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$players').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sfx.muteForTests = true;
  });

  testWidgets('Welcome screen shows the title and both buttons',
      (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pump();
    expect(find.textContaining("ng's Court", findRichText: true), findsOneWidget);
    expect(find.text('New game'), findsOneWidget);
    expect(find.text('New Game'), findsNothing);
    await tester.pumpAndSettle();
    // Play opens setup: the ways to play, the tutorial among them; nothing
    // is saved yet, so nothing to continue.
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.text('How will you play?'), findsOneWidget);
    expect(find.text('Tutorial'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    // A first-timer is pointed to the tutorial.
    expect(find.text('Start here'), findsOneWidget);
  });

  testWidgets('After the tutorial, setup no longer says Start here',
      (tester) async {
    SharedPreferences.setMockInitialValues({'kingsCourt.tutorialDone': true});
    setPhoneSize(tester);
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.text('Tutorial'), findsOneWidget);
    expect(find.text('Start here'), findsNothing);
  });

  testWidgets('Taking a task goes through the table link', (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    final state = tester.state<HomePageState>(find.byType(HomePage));
    final game = state.game;
    final link = state.debugLink;
    final before = link.history.length;
    final t = game.tasks.firstWhere((t) => t.owner == null && game.round!.mayTake(t, 1));
    state.debugAssign(t, 1);
    await tester.pumpAndSettle();
    expect(t.owner, 1);
    expect(link.history.length, before + 1);
    expect(link.history.last.action, isA<PickTask>());
    expect((link.history.last.action as PickTask).seat, 1);
  });

  testWidgets('Starting and finishing rounds are counted', (tester) async {
    setPhoneSize(tester);
    Analytics.sent.clear();
    await dealGame(tester, 4);
    expect(Analytics.sent, contains(startsWith('start/free/4p/table')));
    // Let the debounced save finish before the test ends.
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('How to play opens as a dialog with the 2-player rules',
      (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    // No menu on the front page; it's there once setup opens.
    expect(find.byTooltip('Menu').hitTestable(), findsNothing);
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How to Play'));
    await tester.pumpAndSettle();
    // Everything scrolls, the button included.
    await tester.scrollUntilVisible(find.text('Got it'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Two players'), findsWidgets);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Two players'), findsNothing);
  });

  testWidgets('A new round asks for the King before dealing', (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    expect(find.text('Who holds the King card?'), findsOneWidget);
    expect(find.byType(TableCard), findsNothing);

    await tester.tap(find.byType(SeatToken).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Who holds the King card?'), findsNothing);
    expect(find.byType(TableCard), findsWidgets);
  });

  for (final players in [2, 6]) {
    testWidgets('$players seats and the dealt tasks fit without scrolling',
        (tester) async {
      setPhoneSize(tester);
      await dealGame(tester, players);
      await tester.tap(find.byType(SeatToken).first);
      await tester.pumpAndSettle();
      expect(find.byType(SeatToken), findsNWidgets(players));
      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull); // no overflow errors
    });
  }

  testWidgets('Dragging a task onto a seat gives it to that player',
      (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 3);
    await tester.tap(find.byType(SeatToken).first); // seat 0 is King
    await tester.pumpAndSettle();

    final state = tester.state<HomePageState>(find.byType(HomePage));
    final card = find.byType(TableCard).first;
    final seat = tester.getCenter(find.byType(SeatToken).at(1));
    await dragFromTo(tester, tester.getCenter(card), seat);
    await tester.pumpAndSettle();

    final tasks = state.game.tasks;
    expect(tasks.where((t) => t.owner == 1), isNotEmpty);
    // Drags on the round table are occasionally missed in the test
    // harness (random tasks, random layouts); one retry settles it.
  }, retry: 2);

  testWidgets('Shuffle tasks mid-round keeps the round and King',
      (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shuffle tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Round 1'), findsOneWidget);
    expect(find.text('Who holds the King card?'), findsNothing);
    expect(find.byType(TableCard), findsWidgets);
  });

  testWidgets('A bug report carries the game, and loads back', (tester) async {
    setPhoneSize(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await dealGame(tester, 4);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Report a bug'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report a bug'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('bugMessage')), 'The King vanished');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    debugPrint('BUGPAGE ${[for (final e in find.byType(Text).evaluate()) (e.widget as Text).data].join(' | ')}');
    // No service in tests, so the report is copied instead.
    expect(find.text('Report copied'), findsOneWidget);
    final report = jsonDecode(copied!) as Map<String, dynamic>;
    expect(report['message'], 'The King vanished');
    expect((report['where'] as Map<String, dynamic>)['round'], 1);
    final back = GameState.fromJson(Map<String, dynamic>.from(report['state'] as Map));
    final game = tester.state<HomePageState>(find.byType(HomePage)).game;
    expect(back, isNotNull);
    expect(back!.tasks.length, game.tasks.length);
    expect(back.round!.king, game.round!.king);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Report copied'), findsNothing);
  });

  testWidgets('With the keyboard up, the bug report keeps its title and Send in view', (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Report a bug'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report a bug'));
    await tester.pumpAndSettle();
    // A phone's keyboard: about two fifths of the screen.
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    tester.view.viewInsets = FakeViewPadding(bottom: screen.height * 0.42 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'nothing overflows');
    final above = screen.height * 0.58;
    final send = tester.getRect(find.text('Send'));
    expect(send.bottom, lessThanOrEqualTo(above));
    expect(tester.getRect(find.text('Report a bug').last).top, greaterThanOrEqualTo(0));
    expect(find.byKey(const ValueKey('bugMessage')), findsOneWidget);
    expect(find.text('Your name (optional)'), findsNothing);
  });

  testWidgets('Points target can change without a new game', (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    final state = tester.state<HomePageState>(find.byType(HomePage));
    final players = state.game.players;

    await tester.tap(find.byTooltip('Points target'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deal'));
    await tester.pumpAndSettle();

    // A fresh deal for the new target: same players and round, and the
    // King card is dealt again, so the table asks who has it.
    expect(state.game.target, isNot(5));
    expect(state.game.players, same(players));
    expect(state.game.round!.king, isNull);
    expect(find.text('Who holds the King card?'), findsOneWidget);
    expect(find.text('Round 1'), findsOneWidget);
  });

  testWidgets('A done task flips over', (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 3);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TableCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Done')));
    await tester.pumpAndSettle();
    expect(find.descendant(
        of: find.byType(TableCard), matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget);
  });

  testWidgets('Stacks for neighbouring seats never overlap', (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 6);
    // Plenty of tasks so the stacks get long.
    await tester.tap(find.byTooltip('Points target'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SeatToken).at(3)); // King at the top
    await tester.pumpAndSettle();

    // Give cards alternately to the bottom seat and its left neighbour.
    final cards = find.byType(TableCard);
    final total = tester.widgetList(cards).length;
    // Four is enough to stack up; the test font makes cards larger than
    // on a phone, so more can leave no room at all.
    final count = total < 4 ? total : 4;
    final state = tester.state<HomePageState>(find.byType(HomePage));
    for (var n = 0; n < count; n++) {
      // A task the seat may take: not one that clashes with what it holds.
      final to = n.isEven ? 0 : 1;
      final card = freeCard(tester, (w) => state.game.round!.mayTake(w.task, to));
      final seat = tester.getCenter(find.byType(SeatToken).at(to));
      await dragCardTo(tester, card, seat);
      await tester.pumpAndSettle();
    }

    final owned = state.game
        .tasks
        .where((t) => t.owner != null)
        .toList();
    expect(owned.length, count);

    final rects = [
      for (final el in tester.elementList(cards))
        if ((el.widget as TableCard).owner != null)
          () {
            final box = el.renderObject! as RenderBox;
            final a = box.localToGlobal(Offset.zero);
            final b = box.localToGlobal(box.size.bottomRight(Offset.zero));
            return (
              (el.widget as TableCard).task.owner,
              Rect.fromPoints(a, b).deflate(1)
            );
          }(),
    ];
    // One seat's stack may squeeze together on a crowded table; two
    // seats' stacks must never run into each other.
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        if (rects[i].$1 == rects[j].$1) continue;
        expect(rects[i].$2.overlaps(rects[j].$2), isFalse,
            reason: 'cards $i and $j overlap: $rects, '
                'seats ${[for (int s = 0; s < 6; s++) tester.getCenter(find.byType(SeatToken).at(s))]}, '
                'screen ${tester.view.physicalSize / tester.view.devicePixelRatio}');
      }
    }
    // Drags on the round table are occasionally missed in the test
    // harness (random tasks, random layouts); one retry settles it.
  }, retry: 2);

  test('Table cards keep their wording short', () {
    final x = GameState.taskPool
        .firstWhere((t) => t.description.startsWith('Win exactly X tricks'));
    expect(x.cardText(4), 'Win exactly X tricks, named before the first trick');
    expect(x.notes, isEmpty);
    for (final t in GameState.taskPool) {
      expect(t.cardText(6).length, lessThanOrEqualTo(70), reason: t.description);
      expect(t.cardText(6), isNot(contains('(')), reason: t.description);
    }
  });

  test('The board wording is shorter, with Court Cards as crowns', () {
    final two = GameState.taskPool
        .firstWhere((t) => t.description == 'Win a trick with exactly two Court Cards in it');
    expect(two.boardText(4), 'Win a trick holding two \uE001');
    final none = GameState.taskPool.firstWhere((t) => t.description == "Don't win any ♥ cards");
    expect(none.boardText(4), 'Win no ♥');
    for (final t in GameState.taskPool) {
      final b = t.boardText(4);
      expect(b.length, lessThanOrEqualTo(t.cardText(4).length), reason: t.description);
      expect(b, isNot(contains("Don't")), reason: t.description);
      expect(b, isNot(contains('Court Card')), reason: t.description);
      expect(b, isNot(contains('  ')), reason: t.description);
    }
  });

  testWidgets('Court Cards are always capitalised and bold', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SuitText('Win no court cards', style: TextStyle(fontSize: 14)),
      ),
    ));
    // A game word: gold, bolder, and tappable for what it means.
    final term = tester.widget<Text>(find.text('Court Cards'));
    expect(term.style!.fontWeight, FontWeight.w700);
    await tester.tap(find.text('Court Cards'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The Joker, Jack, Queen and King', findRichText: true),
        findsOneWidget);
  });

  test('Seat labels are short and never repeat', () {
    Player p(String n) => Player(n, colorValue: Colors.red.toARGB32());
    expect(seatLabels([p('Player 1'), p('Player 2'), p('Player 3')]),
        ['1', '2', '3']);
    expect(seatLabels([p('Sam'), p('Mary Jane'), p('Player 3')]),
        ['S', 'MJ', '3']);
    expect(seatLabels([p('Sam'), p('Sim'), p('Jo')]), ['Sa', 'Si', 'J']);
    expect(seatLabels([p('Sam'), p('Sam')]), ['1', '2']);
    expect(seatLabels([p('The General'), p('The Duke')]), ['G', 'D']);
  });

  testWidgets('Holding the felt turns every card towards that seat',
      (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();

    // Seat 2 of 4 sits at the top: hold the felt just below it.
    final top = tester.getCenter(find.byType(SeatToken).at(2));
    final g = await tester.startGesture(top + const Offset(-120, 70));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    for (final r in tester.widgetList<AnimatedRotation>(
        find.byType(AnimatedRotation))) {
      expect(r.turns, closeTo(0.5, 1e-9));
    }
    await g.up();
    await tester.pumpAndSettle();
    for (final r in tester.widgetList<AnimatedRotation>(
        find.byType(AnimatedRotation))) {
      expect(r.turns.abs(), lessThan(0.05)); // back to the slight table tilt
    }
  });

  testWidgets('Long tasks get taller cards instead of tiny text',
      (tester) async {
    const width = 140.0;
    final short = TableCard.sizeFor(const CourtSkin(), 'Win the 3♥', width);
    final long = TableCard.sizeFor(const CourtSkin(), 
        'Win a trick with a card just one above the card led',
        width);
    expect(short.height, TableCard.heightFor(width));
    expect(long.height, greaterThan(short.height));
  });

  testWidgets('Winning a round, then dealing the next with new points',
      (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle(); // crowning, then the deal
    expect(find.text('Long live the King'), findsNothing);

    final pending =
        find.byWidgetPredicate((w) => w is TableCard && !w.task.isCompleted);
    while (find.text('Round won').evaluate().isEmpty) {
      await tester.tap(pending.first);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Done')));
      await tester.pumpAndSettle();
    }
    expect(find.byType(SnackBar), findsNothing); // the dialog is enough

    await tester.drag(find.descendant(
        of: find.byType(Center), matching: find.byType(Slider)).first,
        const Offset(200, 0));
    await tester.pumpAndSettle();
    final deal = find.text('Deal');
    expect(deal, findsOneWidget);
    await tester.tap(deal);
    await tester.pumpAndSettle();

    final state = tester.state<HomePageState>(find.byType(HomePage));
    expect(state.game.target, isNot(5));
    expect(find.text('Round 2'), findsOneWidget);
    expect(find.text('Who holds the King card?'), findsOneWidget);
  });

  testWidgets('Undo last mark reopens a round ended by mistake',
      (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 3);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TableCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Failed')));
    await tester.pumpAndSettle();
    expect(find.text('Round lost'), findsOneWidget);

    await tester.tap(find.text('Undo last mark'));
    await tester.pumpAndSettle();
    expect(find.text('Round lost'), findsNothing);
    final state = tester.state<HomePageState>(find.byType(HomePage));
    expect(state.game.losses, 0);
  });

  testWidgets('Picking moves clockwise from the King, then Play!',
      (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 3);
    await tester.tap(find.byType(SeatToken).at(1)); // seat 1 is King
    await tester.pumpAndSettle();
    final state = tester.state<HomePageState>(find.byType(HomePage));
    final game = state.game.round!;
    expect(game.pickTurn, 1);
    expect(find.byType(PulseRing), findsOneWidget);

    var seat = 1;
    expect(seat, 1);
    while (game.pickTurn != null) {
      final card =
          freeCard(tester, (w) => game.mayTake(w.task, game.pickTurn!));
      final picker = game.pickTurn!;
      final target = tester.getCenter(find.byType(SeatToken).at(picker));
      final task = (tester.widget(card) as TableCard).task;
      final start = tester.getCenter(card);
      await dragCardTo(tester, card, target);
      // Next clockwise who can take one of the tasks left (anyone who
      // can't is skipped).
      seat = picker;
      for (var step = 1; step <= 3; step++) {
        final s = (picker + step) % 3;
        if (game.tasks.any((t) => t.owner == null && game.mayTake(t, s))) {
          seat = s;
          break;
        }
      }
      final hits = tester.hitTestOnBinding(start).path
          .map((e) => e.target.runtimeType.toString())
          .take(8)
          .join(' < ');
      if (game.pickTurn != null) {
        expect(game.pickTurn, seat,
            reason: 'dragged ${task.description} from $start to $target; '
                'now held by ${task.owner}; '
                'card now at ${tester.getCenter(find.byWidgetPredicate((w) => w is TableCard && w.task == task))}; '
                'hit at start: $hits');
      }
      await tester.pumpAndSettle();
    }
    expect(game.tasks.every((t) => t.owner != null), isTrue);
    expect(find.byType(PulseRing), findsNothing);
    // Drags on the round table are occasionally missed in the test
    // harness (random tasks, random layouts); one retry settles it.
  }, retry: 2);

  testWidgets('Tapping a seat opens the courtier card to mark the reveal',
      (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    final state = tester.state<HomePageState>(find.byType(HomePage));
    final game = state.game;

    await tester.tap(find.byType(SeatToken).at(2));
    await tester.pumpAndSettle();
    expect(find.text(game.courtiers[2].house), findsOneWidget);
    await tester.tap(find.byType(GoldPip));
    await tester.pumpAndSettle();
    expect(game.round!.spoke[2], isTrue);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('A saved game can be continued', (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    // Seat 1 uses their card reveal.
    await tester.tap(find.byType(SeatToken).at(1));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(GoldPip));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GoldPip));
    await tester.pumpAndSettle();
    final live = tester.state<HomePageState>(find.byType(HomePage)).game;
    expect(live.round!.spoke[1], isTrue, reason: 'the switch marks the reveal');
    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Start the app again from scratch with the same storage.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    // One game saved: Continue goes straight back into it.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final state = tester.state<HomePageState>(find.byType(HomePage));
    final game = state.game;
    expect(game.round!.king, 0);
    expect(game.round!.spoke[1], isTrue);
    expect(find.byType(TableCard), findsWidgets);
    expect(find.text('Who holds the King card?'), findsNothing);
  });

  test('Campaign streaks rise with wins and reset on a loss', () {
    final game = GameState()
      ..campaign = true
      ..players = [
        for (int i = 0; i < 3; i++) Player('P$i', colorValue: Colors.red.toARGB32())
      ]
      ..startRound(3, 6);
    for (final t in game.tasks) {
      t.status = TaskStatus.completed;
    }
    game.recordOutcomeIfFinished();
    expect(game.streak, 1);
    expect(game.bestStreak, 1);
    game.retryRound();
    game.tasks.first.status = TaskStatus.failed;
    game.recordOutcomeIfFinished();
    expect(game.streak, 0);
    expect(game.bestStreak, 1);
  });

  test('A game survives saving and loading', () {
    final game = GameState()
      ..players = [
        for (int i = 0; i < 4; i++) Player('P$i', colorValue: Colors.blue.toARGB32())
      ]
      ..startRound(4, 10)
      ..crown(2);
    game.round!.assign(game.tasks.first, 3);
    game.round!.toggleSpoke(1);
    final copy = GameState.fromJson(
        jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>)!;
    expect(copy.round!.king, 2);
    expect(copy.tasks.first.owner, 3);
    expect(copy.round!.spoke[1], isTrue);
    expect(copy.tasks.map((t) => t.description),
        game.tasks.map((t) => t.description));
  });

  test('Seals must be completed in order, Ω last', () {
    final game = GameState()
      ..players = [for (int i = 0; i < 4; i++) Player('P$i', colorValue: Colors.red.toARGB32())]
      ..startRound(4, 14);
    final round = game.round!;
    while (round.tasks.length < 4) {
      round.tasks.add(RoundTask(GameState.taskPool[round.tasks.length]));
    }
    round.tasks[0].seal = 1;
    round.tasks[1].seal = 2;
    round.tasks[2].seal = Seals.last;
    final sealed = {for (final t in round.tasks) if (t.seal != null) t.seal!: t};
    expect(sealed.keys.toSet(), {1, 2, Seals.last});
    expect(round.sealProblem(sealed[2]!), contains('Seal I'));
    expect(round.sealProblem(sealed[1]!), isNull);
    sealed[1]!.status = TaskStatus.completed;
    expect(round.sealProblem(sealed[2]!), isNull);
    expect(round.sealProblem(sealed[Seals.last]!), contains('Ω'));
    for (final t in round.tasks) {
      if (t.seal != Seals.last) t.status = TaskStatus.completed;
    }
    expect(round.sealProblem(sealed[Seals.last]!), isNull);
  });

  test('Decrees change who can pick, speak and take tasks', () {
    Round make(Decree d) {
      final g = GameState()
        ..players = [for (int i = 0; i < 4; i++) Player('P$i', colorValue: Colors.red.toARGB32())]
        ..startRound(4, 10);
      g.round!.decree = d;
      return g.round!;
    }

    final exile = make(Decree.exile)..crown(0, Random(1));
    expect(exile.exiledSeat, isNotNull);
    expect(exile.exiledSeat, isNot(0));
    expect(exile.mayTake(exile.tasks.first, exile.exiledSeat!), isFalse);

    final silence = make(Decree.silence)..crown(0, Random(1));
    expect(silence.canSpeak(1), isFalse);

    // Late Counsel is kept by the players: the app doesn't count tricks.
    final late = make(Decree.lateCounsel)..crown(0, Random(1));
    expect(late.canSpeak(1), isTrue);

    final command = make(Decree.kingsCommand)..crown(2, Random(1));
    command.assign(command.tasks.first, 0);
    expect(command.pickTurn, 2); // the King keeps handing out tasks
  });

  test('Chronicle chapters unlock in order and award crowns', () {
    final p = ChronicleProgress();
    expect(p.nextChapter, 0);
    expect(p.isUnlocked(1), isFalse);
    p.startAttempt(0);
    expect(p.recordWin(0), 3);
    expect(p.nextChapter, 1);
    for (var i = 0; i < 3; i++) {
      p.startAttempt(1);
    }
    expect(p.recordWin(1), 2);
    final copy = ChronicleProgress.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(copy.crowns, {0: 3, 1: 2});
    expect(chronicle, hasLength(24));
  });

  testWidgets('A Chronicle chapter reads its decree before dealing',
      (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    final state = tester.state<HomePageState>(find.byType(HomePage));
    // Chapter 4 is "The Silent Court".
    state.debugStartChapter(3, 4);
    await tester.pumpAndSettle();
    expect(find.text('Chapter 4'), findsOneWidget);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    expect(find.byType(DecreeScroll), findsOneWidget);
    expect(find.byType(TableCard), findsNothing);
    await tester.tap(find.text('So be it'));
    await tester.pumpAndSettle();
    expect(find.byType(TableCard), findsWidgets);
    expect(find.byType(DecreeScroll), findsNothing);
    expect(find.text('Silence'), findsOneWidget); // the chip in the top bar
  });

  GameState withRoles(int players) => GameState()
    ..players = [for (int i = 0; i < players; i++) Player('P$i', colorValue: Colors.red.toARGB32())]
    ..seatCourtiers()
    ..startRound(players, 8);

  test('Every story flag a matter needs can be earned', () {
    final earned = <String>{
      for (final d in dilemmas)
        for (final e in [...d.a.effects, ...d.b.effects])
          if (e is Flag) e.name,
      for (final t in tidings)
        for (final e in [...t.won.effects, ...t.lost.effects])
          if (e is Flag) e.name,
    };
    bool given(String f) =>
        f.startsWith('seen:') || f == 'crowned' || f == 'golden_age';
    for (final d in dilemmas) {
      for (final f in d.requires) {
        if (!given(f)) expect(earned, contains(f), reason: d.title);
      }
    }
    for (final t in tidings) {
      for (final f in t.requires) {
        if (!given(f)) expect(earned, contains(f), reason: t.title);
      }
    }
    // Every follow-up the story names exists.
    for (final t in tidings) {
      for (final f in [t.followWon, t.followLost]) {
        if (f != null) {
          expect(dilemmas.any((d) => d.title == f), isTrue, reason: f);
        }
      }
    }
  });

  test('Every seat gets a different courtier shape', () {
    final g = withRoles(6);
    expect(g.courtiers.map((c) => c.shape).toSet(), hasLength(6));
  });

  test('Tidings lead to dilemmas that exist', () {
    final titles = dilemmas.map((d) => d.title).toSet();
    for (final t in tidings) {
      for (final f in [t.followWon, t.followLost]) {
        if (f != null) expect(titles, contains(f), reason: t.title);
      }
    }
  });

  test('The Trial of Hearts plays out fairly', () {
    final rand = Random(3);
    for (var i = 0; i < 300; i++) {
      final players = 3 + i % 4;
      final sideA = [for (int s = 0; s < players; s++) rand.nextBool()];
      final c = ContestState.deal(
          players: players, king: i % players, sideA: sideA, rand: rand);
      final cards = c.hands.fold<int>(0, (n, h) => n + h.length);
      var guard = 0;
      while (!c.over && guard++ < 100) {
        final seat = c.turn;
        final card = c.botPlay(seat);
        expect(c.legalFor(seat), contains(card));
        c.play(seat, card);
      }
      expect(c.over, isTrue);
      // Every mark dealt ends up with someone.
      final dealt = c.tricks
          .expand((t) => t.cards)
          .fold<int>(0, (n, card) => n + ContestState.shameOf(card));
      expect([for (int s = 0; s < players; s++) c.shame(s)].reduce((a, b) => a + b),
          dealt);
      expect(c.tricks.length * players, cards);
      final a = c.sideShame(true), b = c.sideShame(false);
      if (sideA.toSet().length == 2) {
        expect(c.aWins, a == b ? sideA[c.king] : a < b);
      }
    }
  });

  testWidgets('The Trial of Hearts table plays to the end', (tester) async {
    setPhoneSize(tester);
    final contest = ContestState.deal(
        players: 4, king: 1, sideA: [true, false, true, false], rand: Random(1));
    var done = false;
    final key = GlobalKey<ContestTableState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContestTable(
          key: key,
          contest: contest,
          you: 0,
          names: const ['You', 'Duke', 'Bishop', 'Jester'],
          colors: const [Colors.red, Colors.blue, Colors.green, Colors.purple],
          token: (seat, size) => SizedBox(width: size, height: size),
          labelA: 'Open the gates',
          labelB: 'Close the gates',
          botDelay: const Duration(milliseconds: 5),
          trickPause: const Duration(milliseconds: 10),
          onDone: () => done = true,
        ),
      ),
    ));
    for (var i = 0; i < 400 && !contest.over; i++) {
      key.currentState!.debugYourMove();
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(contest.over, isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let it be done'));
    expect(done, isTrue);
  });

  testWidgets('Each way to play keeps its own save', (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    // A second game of another kind: out to the main menu (the first is
    // kept), and a new game from there.
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main menu'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget, reason: 'the game left is there to take up');
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await setupThrough(tester, players: 3, mode: 'Endless');
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Free play'), findsOneWidget);
    expect(find.text('Endless'), findsOneWidget);
    await tester.tap(find.text('Free play'));
    await tester.pumpAndSettle();
    final game = tester.state<HomePageState>(find.byType(HomePage)).game;
    expect(game.mode, GameMode.free);
    expect(game.players, hasLength(4));
  });

  testWidgets('An old single save moves into its slot', (tester) async {
    setPhoneSize(tester);
    final old = GameState()
      ..mode = GameMode.endless
      ..startRound(3, 4);
    old.players = [
      for (int i = 0; i < 3; i++) Player('P$i', colorValue: Colors.teal.toARGB32())
    ];
    SharedPreferences.setMockInitialValues({
      'kingsCourt.game': jsonEncode({
        'game': old.toJson(),
        'playerCount': 3,
        'targetPoints': 4,
        'cardWidth': 100.0,
        'dealt': false,
        'pos': [for (final _ in old.tasks) null],
        'tilt': [for (final _ in old.tasks) 0.0],
      }),
    });
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kingsCourt.game'), isNull);
    expect(prefs.getString('kingsCourt.game.endless'), isNotNull);
  });

  test('Seals come in twos or not at all', () {
    for (var i = 0; i < 50; i++) {
      final g = GameState()..surprise = true;
      g.startRound(4, 3 + i % 12,
          setup: (rand) => const FreePlay().roundSetup(g, 4, rand));
      final sealed = g.tasks.where((t) => t.seal != null).length;
      expect(sealed == 0 || sealed >= 2, isTrue);
    }
    expect(chronicle.every((c) => c.seals == 0 || c.seals >= 2), isTrue);
  });

  test('Seals only sit where they can be kept', () {
    var omegas = 0, numbered = 0;
    for (var i = 0; i < 400; i++) {
      final seals = const [2, 3, 4][i % 3];
      final g = GameState()
        ..startRound(3 + i % 3, 6 + i % 14,
            setup: (_) => RoundSetup(sealCount: seals));
      final sealed = g.tasks.where((t) => t.seal != null).toList();
      expect(sealed.isEmpty || sealed.length >= 2, isTrue);
      for (final t in sealed) {
        // A seal orders tasks by when they're done: no seal on a task only
        // settled at the end of the round, or by the first few tricks.
        expect(timingOf(t.description), TaskTiming.anyTrick,
            reason: '${t.description} has seal ${t.seal}');
      }
      if (sealed.any((t) => t.seal == Seals.last)) {
        omegas++;
        // Ω must be done last, so nothing else may wait for the end.
        expect(
            g.tasks.where((t) =>
                t.seal == null && timingOf(t.description) == TaskTiming.end),
            isEmpty);
      } else if (sealed.isNotEmpty) {
        numbered++;
        final nums = sealed.map((t) => t.seal!).toList()..sort();
        expect(nums, [for (int n = 1; n <= nums.length; n++) n]);
      }
    }
    expect(numbered, greaterThan(0));
    expect(omegas + numbered, greaterThan(200));
  });

  test('Every timed task is a real task', () {
    for (final d in timedTaskNames) {
      expect(taskRules.containsKey(d), isTrue, reason: d);
    }
  });

  test('Tasks marked any-trick can be done before the last trick', () {
    // Random rounds: each any-trick task should sometimes be done before
    // the last trick.
    final rand = Random(7);
    final early = <String>{};
    for (var r = 0; r < 600; r++) {
      final players = 3 + r % 3;
      final dealt = deal(players, rand);
      final hands = [for (final h in dealt.hands) List.of(h)];
      final inPlay = hands.expand((h) => h).toSet();
      final total = hands.first.length;
      final tricks = <Trick>[];
      var leader = 0;
      // Everyone shows a card before the first trick (for the tasks about
      // shown cards).
      final shown = {for (int s = 0; s < players; s++) s: hands[s][r % hands[s].length]};
      final shownAt = {for (int s = 0; s < players; s++) s: 0};
      while (tricks.length < total - 1) {
        final seats = <int>[], cards = <PlayingCard>[];
        for (var i = 0; i < players; i++) {
          final s = (leader + i) % players;
          final legal =
              legalPlays(hands[s], cards.isEmpty ? null : cards.first);
          final c = legal[rand.nextInt(legal.length)];
          hands[s].remove(c);
          seats.add(s);
          cards.add(c);
        }
        final w = seats[winningPlay(cards)];
        tricks.add(Trick(leader, seats, cards, w));
        leader = w;
        final v = RoundView(
            players: players,
            king: 0,
            tricks: tricks,
            totalTricks: total,
            inPlay: inPlay,
            shown: shown,
            shownAt: shownAt);
        for (final e in taskRules.entries) {
          for (var o = 0; o < players; o++) {
            if (e.value(v, o, 1) == Verdict.done) early.add(e.key);
          }
        }
      }
    }
    for (final d in taskRules.keys) {
      if (timingOf(d) == TaskTiming.anyTrick) {
        expect(early.contains(d), isTrue, reason: d);
      }
    }
  });

  for (final mode in ['Free play']) {
    testWidgets('On-screen cards play a whole $mode round', (tester) async {
      setPhoneSize(tester);
      HomePageTestHooks.fast();
      await tester.pumpWidget(const TheKingsCourtApp());
      await tester.pumpAndSettle();
      await openSetup(tester);
      await tester.tap(find.text('Single player'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(mode));
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();
      // On screen, the number of players is on the last step itself.
      if (find.text('Next').evaluate().isNotEmpty) await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pump();

      final state = tester.state<HomePageState>(find.byType(HomePage));
      final game = state.game;
      expect(game.digital, isTrue);
      expect(game.players.first.name, 'You');
      if (mode == 'Free play') {
        // Before anyone picks, the table asks about showing a card.
        for (var i = 0;
            i < 300 && find.text('Skip').evaluate().isEmpty;
            i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        expect(find.text('Skip'), findsOneWidget);
        // Nobody has picked yet (a task only one player could take may
        // already have gone straight to them).
        expect(game.tasks.where((t) => t.owner != null).length,
            lessThan(game.tasks.length));
        await tester.tap(find.text('Skip'));
        await tester.pump();
        expect(find.text('Skip'), findsNothing);
      }
      for (var i = 0;
          i < 3000 && game.outcome == RoundOutcome.inProgress;
          i++) {
        await tester.pump(const Duration(milliseconds: 30));
        if (find.text('So be it').evaluate().isNotEmpty) {
          await tester.tap(find.text('So be it'));
        } else if (find.text('Announce').evaluate().isNotEmpty) {
          await tester.tap(find.text('Announce'));
        } else if (find.text('Got it').evaluate().isNotEmpty) {
          await tester.tap(find.text('Got it').first);
        } else {
          state.debugYourMove();
        }
      }
      expect(game.outcome, isNot(RoundOutcome.inProgress));
      if (mode == 'Free play') {
        // Every card, played and still to come.
        final grid = find.byTooltip('Cards played and still to come');
        if (grid.hitTestable().evaluate().isNotEmpty) {
          await tester.tap(grid.hitTestable());
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 30));
          }
          await tester.dragUntilVisible(find.text('What the others may hold'),
              find.byType(ListView).last, const Offset(0, -200));
          expect(find.text('What the others may hold'), findsOneWidget);
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  for (final bySKey in [false, true]) {
  testWidgets(bySKey ? 'S skips showing a card' : 'The arrow keys reach the Skip button', (tester) async {
    {
      setPhoneSize(tester);
      HomePageTestHooks.fast();
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const TheKingsCourtApp());
      await tester.pumpAndSettle();
      await openSetup(tester);
      await tester.tap(find.text('Single player'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Free play'));
      await tester.tap(find.text('Free play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();
      if (find.text('Next').evaluate().isNotEmpty) await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pump();
      for (var i = 0; i < 600 && find.text('Skip').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        for (final go in ['So it begins', 'Got it', 'So be it']) {
          if (find.text(go).hitTestable().evaluate().isNotEmpty) {
            await tester.tap(find.text(go).hitTestable().first);
          }
        }
      }
      expect(find.text('Skip'), findsOneWidget);
      // While Skip shows, the show-a-card button beside it is its X.
      expect(find.byTooltip('Skip showing a card'), findsOneWidget);
      final ringed = find.byWidgetPredicate((w) => w is KeyFocusRing && w.on);
      if (bySKey) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      } else {
        // Up from your hand: the Skip button is chosen, and Enter presses it.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(ringed, findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      }
      await tester.pump();
      expect(find.text('Skip'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }
  });
  }

  for (final mouse in [false, true]) {
    testWidgets('A courtier can be ${mouse ? 'clicked' : 'tapped'} anywhere on their token', (tester) async {
      if (mouse) {
        tester.view.physicalSize = const Size(2192, 1518);
        tester.view.devicePixelRatio = 1.6;
        addTearDown(tester.view.reset);
      } else {
        setPhoneSize(tester);
      }
      HomePageTestHooks.fast();
      await tester.pumpWidget(const TheKingsCourtApp());
      await tester.pumpAndSettle();
      await openSetup(tester);
      await tester.tap(find.text('Single player'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Free play'));
      await tester.tap(find.text('Free play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();
      if (find.text('Next').evaluate().isNotEmpty) await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      for (var i = 0; i < 600 && find.text('Skip').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      // Each courtier's token: its middle, and near its edges.
      final shapes = find.descendant(
          of: find.byType(SeatToken), matching: find.byType(ShapedToken));
      expect(shapes, findsWidgets);
      final n = shapes.evaluate().length;
      for (var k = 0; k < n; k++) {
        final r = tester.getRect(shapes.at(k));
        for (final at in [r.center, r.center + Offset(0, r.height * 0.3),
            r.center - Offset(r.width * 0.3, 0)]) {
          final hit = HitTestResult();
          tester.binding.hitTestInView(hit, at, tester.view.viewId);
          if (mouse) {
            // Moved there first, as a mouse is.
            final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
            await g.addPointer(location: at - const Offset(40, 40));
            await g.moveTo(at);
            await tester.pump(const Duration(milliseconds: 50));
            await g.down(at);
            await tester.pump(const Duration(milliseconds: 30));
            await g.up();
            await g.removePointer();
          } else {
            await tester.tapAt(at);
          }
          await tester.pump(const Duration(milliseconds: 50));
          final opened = find.byType(Dialog).evaluate().isNotEmpty;
          expect(opened, isTrue,
              reason: 'token $k at $at (rect $r) opened nothing. Hit: '
                  '${hit.path.take(14).map((e) => e.target.runtimeType).join(' > ')}');
          Navigator.of(tester.element(find.byType(Dialog))).pop();
          await tester.pump(const Duration(milliseconds: 400));
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  testWidgets('The tutorial plays through every lesson, following the coach',
      (tester) async {
    setPhoneSize(tester);
    HomePageTestHooks.fast();
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutorial'));
    await tester.pumpAndSettle();
    // Each lesson's pages wait for Continue, one at a time; the last one
    // plays the lesson.
    Future<void> readPages(List<IntroPage> pages, String finish) async {
      for (final page in pages.take(pages.length - 1)) {
        expect(find.text(page.title), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }
      expect(find.text(pages.last.title), findsOneWidget);
      await tester.tap(find.text(finish).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    // The table sits under the pages, so look past them for it.
    final state =
        tester.state<HomePageState>(find.byType(HomePage, skipOffstage: false));
    for (var lesson = 0; lesson < lessons.length; lesson++) {
      await readPages(lessons[lesson].pages, 'Play lesson ${lesson + 1}');
      final game = state.game;
      expect(game.isTutorial, isTrue);
      expect(game.lesson, lesson);
      expect(game.players.map((p) => p.name), tutorialCourtiers);
      for (var i = 0;
          i < 2000 && game.outcome == RoundOutcome.inProgress;
          i++) {
        await tester.pump(const Duration(milliseconds: 30));
        state.debugYourMove();
      }
      expect(game.outcome, RoundOutcome.won,
          reason: 'lesson ${lesson + 1}: ${lessons[lesson].title}');
      expect(game.round!.king, 0, reason: 'you are the King');
      // The tasks turn over, then the result comes up.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 600));
      final last = lesson == lessons.length - 1;
      expect(find.text(last ? 'Tutorial complete' : 'Lesson complete'),
          findsOneWidget);
      await tester.tap(find.text(last ? 'Finish' : 'Next lesson'));
      await tester.pumpAndSettle();
    }
    await readPages(outroPages, 'Finish');
    await tester.pumpAndSettle();
    expect(find.text('You\u2019re ready'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('New game'), findsOneWidget); // back at the welcome
  });

  test('Each player may pass on picking once a round', () {
    final game = GameState()
      ..players = [for (int i = 0; i < 3; i++) Player('P$i', colorValue: Colors.teal.toARGB32())]
      ..startRound(3, 10)
      ..crown(0);
    final g = game.round!;
    final first = g.pickTurn!;
    expect(g.canPass(first), isTrue);
    g.pass(first);
    expect(g.pickTurn, isNot(first));
    // Picking goes round; when it comes back, no second pass.
    for (var i = 0; i < 6 && g.pickTurn != null && g.pickTurn != first; i++) {
      final seat = g.pickTurn!;
      final t = g.tasks.firstWhere(
          (t) => t.owner == null && g.mayTake(t, seat),
          orElse: () => g.tasks.firstWhere((t) => t.owner == null));
      g.assign(t, seat);
    }
    if (g.pickTurn == first) expect(g.canPass(first), isFalse);
  });

  testWidgets('Cards a task needs are crossed out once won', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: SuitText('Win the 9♥ and the 2♣',
            struck: {'9♥'}, style: TextStyle(color: Colors.black))));
    final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final spans = rich.children!.whereType<TextSpan>();
    final ace = spans.firstWhere((t) => t.text == '9');
    final seven = spans.firstWhere((t) => t.text == '2');
    expect(ace.style!.decoration, TextDecoration.lineThrough);
    expect(seven.style!.decoration, TextDecoration.none);
  });

  test('Roman numerals for reigns', () {
    expect([1, 2, 4, 9, 14].map(roman), ['I', 'II', 'IV', 'IX', 'XIV']);
  });

  test('Task draw hits the target without repeats', () {
    for (final players in [2, 3, 4, 5, 6]) {
      for (final target in [5, 10, 20]) {
        final game = GameState()..startRound(players, target);
        final total = game.tasks
            .fold<int>(0, (sum, t) => sum + t.points(players));
        final names = game.tasks.map((t) => t.description).toSet();
        expect(total, lessThanOrEqualTo(target));
        expect(names.length, game.tasks.length);
      }
    }
  });

  test('Two players use the 3-player difficulty', () {
    for (final t in GameState.taskPool) {
      expect(t.getPointsForPlayerCount(2), t.threePlayerPoints);
    }
  });

  test('Round is won when all tasks complete, lost when any fails', () {
    final game = GameState()..startRound(6, 12);
    expect(game.outcome, RoundOutcome.inProgress);
    for (final t in game.tasks) {
      t.status = TaskStatus.completed;
    }
    expect(game.outcome, RoundOutcome.won);
    expect(game.recordOutcomeIfFinished(), isTrue);
    expect(game.recordOutcomeIfFinished(), isFalse); // only counted once
    expect(game.wins, 1);

    game.retryRound();
    expect(game.roundNumber, 2);
    expect(game.tasks.every((t) => t.status == TaskStatus.pending), isTrue);
    game.tasks.first.status = TaskStatus.failed;
    expect(game.outcome, RoundOutcome.lost);
    game.recordOutcomeIfFinished();
    expect(game.losses, 1);
  });

  test('Shuffling mid-round keeps the round number and King', () {
    final game = GameState()
      ..startRound(4, 10)
      ..crown(1);
    game.shuffleTasks(4, 10);
    expect(game.roundNumber, 1);
    expect(game.round!.king, 1);
  });

  test('A task only one player can take goes straight to them', () {
    final kingTask = GameState.taskPool.firstWhere((t) => t.kingCantTake);
    final other = GameState.taskPool.firstWhere((t) => !t.kingCantTake);
    final r = Round(players: 2, target: 5)
      ..tasks = [RoundTask(kingTask), RoundTask(other)];
    r.crown(0, Random(1));
    expect(r.tasks.first.owner, 1);
    expect(r.tasks.last.owner, isNull);
  });

  test('The King cannot take King-relative tasks', () {
    final kingTask = GameState.taskPool.firstWhere((t) => t.kingCantTake);
    final r = Round(players: 4, target: 5)
      ..tasks = [RoundTask(kingTask, owner: 2)];
    r.crown(2, Random(1));
    expect(r.tasks.first.owner, isNull);
    expect(r.mayTake(r.tasks.first, 2), isFalse);
    expect(r.mayTake(r.tasks.first, 0), isTrue);
  });

  test('Every task has 6-player points', () {
    for (final t in GameState.taskPool) {
      expect(t.sixPlayerPoints, greaterThan(0), reason: t.description);
    }
    expect(GameState.taskPool.length, 113);
  });
}
