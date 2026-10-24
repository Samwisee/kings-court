import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kings_court/chronicle.dart';
import 'package:kings_court/courtiers.dart';
import 'package:kings_court/main.dart';
import 'package:kings_court/sfx.dart';
import 'package:kings_court/story.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/widgets.dart';
import 'package:kings_court/engine/match.dart';

void setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // iPhone-sized
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> dealGame(WidgetTester tester, int players) async {
  await tester.pumpWidget(const TheKingsCourtApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Play'));
  await tester.pumpAndSettle();
  await setupThrough(tester, players: players, mode: 'Free play');
  await tester.tap(find.text('Deal tasks'));
  await tester.pumpAndSettle();
}

/// Walks the setup steps: way to play, players, names, then stops on the
/// last step.
Future<void> setupThrough(WidgetTester tester,
    {int players = 4, required String mode}) async {
  await tester.ensureVisible(find.text(mode));
  await tester.pumpAndSettle();
  await tester.tap(find.text(mode));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
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
    expect(find.text("The King's Court"), findsOneWidget);
    expect(find.text('Play'), findsOneWidget); // the only button
    expect(find.text('New Game'), findsNothing);
    expect(find.text('Continue'), findsNothing); // nothing saved yet
  });

  testWidgets('How to play opens as a dialog with the 2-player rules',
      (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How to Play'));
    await tester.pumpAndSettle();
    // Everything scrolls, the button included.
    await tester.scrollUntilVisible(find.text('Got it'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Two players'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Two players'), findsNothing);
  });

  testWidgets('A new round asks for the King before dealing', (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    expect(find.text('Who holds the K♠?'), findsOneWidget);
    expect(find.byType(TableCard), findsNothing);

    await tester.tap(find.byType(SeatToken).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Who holds the K♠?'), findsNothing);
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

    final state = tester.state(find.byType(HomePage)) as dynamic;
    final card = find.byType(TableCard).first;
    final seat = tester.getCenter(find.byType(SeatToken).at(1));
    final gesture = await tester.startGesture(tester.getCenter(card));
    await gesture.moveBy(const Offset(10, 10));
    await gesture.moveTo(seat);
    await gesture.up();
    await tester.pumpAndSettle();

    final tasks = (state.game as GameState).tasks;
    expect(tasks.where((t) => t.assignedPlayerIndex == 1), isNotEmpty);
  });

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
    expect(find.text('Who holds the K♠?'), findsNothing);
    expect(find.byType(TableCard), findsWidgets);
  });

  testWidgets('Points target can change without a new game', (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(HomePage)) as dynamic;
    final players = (state.game as GameState).players;

    await tester.tap(find.byTooltip('Points target'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Re-deal tasks'));
    await tester.pumpAndSettle();

    expect(state.targetPoints, isNot(10));
    expect((state.game as GameState).players, same(players));
    expect((state.game as GameState).kingIndex, 0);
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
    await tester.tap(find.text('Re-deal tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SeatToken).at(3)); // King at the top
    await tester.pumpAndSettle();

    // Give cards alternately to the bottom seat and its left neighbour.
    final cards = find.byType(TableCard);
    final total = tester.widgetList(cards).length;
    final count = total < 6 ? total : 6;
    for (int n = 0; n < count; n++) {
      final card = find
          .byWidgetPredicate((w) => w is TableCard && w.owner == null)
          .first;
      final seat = tester.getCenter(find.byType(SeatToken).at(n.isEven ? 0 : 1));
      final g = await tester.startGesture(tester.getCenter(card));
      await g.moveBy(const Offset(10, 10));
      await g.moveTo(seat);
      await g.up();
      await tester.pumpAndSettle();
    }

    final state = tester.state(find.byType(HomePage)) as dynamic;
    final owned = (state.game as GameState)
        .tasks
        .where((t) => t.assignedPlayerIndex != null)
        .toList();
    expect(owned.length, count);

    final rects = [
      for (final el in tester.elementList(cards))
        if ((el.widget as TableCard).owner != null)
          () {
            final box = el.renderObject as RenderBox;
            final a = box.localToGlobal(Offset.zero);
            final b = box.localToGlobal(box.size.bottomRight(Offset.zero));
            return Rect.fromPoints(a, b).deflate(1);
          }(),
    ];
    for (int i = 0; i < rects.length; i++) {
      for (int j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse,
            reason: 'cards $i and $j overlap');
      }
    }
  });

  test('Table cards use short wording for the player count', () {
    final total = GameState.taskPool
        .firstWhere((t) => t.description.contains('totalling more than'));
    expect(total.cardText(4),
        'Win a trick totalling more than 28, with no Court Cards');
    expect(total.cardText(2), contains('more than 23'));
    expect(total.cardText(6), contains('more than 34'));

    final redeal = GameState.taskPool
        .firstWhere((t) => t.description.startsWith('Win the Joker and no'));
    expect(redeal.cardText(4), 'Win the Joker and no other Court Card');
    expect(redeal.notes.single, startsWith('Redeal if'));

    final more = GameState.taskPool
        .firstWhere((t) => t.description.startsWith('Win more ♥ cards than ♣'));
    expect(more.cardText(4), 'Win more ♥ cards than ♣ cards');
    expect(more.notes.single, 'Winning no ♣ cards is fine.');
    expect(total.notes, isEmpty); // the player-count numbers aren't a note

    for (final t in GameState.taskPool) {
      expect(t.cardText(6).length, lessThanOrEqualTo(70), reason: t.description);
      expect(t.cardText(6), isNot(contains('(')), reason: t.description);
    }
  });

  testWidgets('Court Cards are always capitalised and bold', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SuitText('Win no court cards', style: TextStyle(fontSize: 14)),
      ),
    ));
    final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final term = rich.children!
        .cast<TextSpan>()
        .firstWhere((s) => s.text == 'Court Cards');
    expect(term.style!.fontWeight, FontWeight.w700);
  });

  test('Seat labels are short and never repeat', () {
    Player p(String n) => Player(n, color: Colors.red);
    expect(seatLabels([p('Player 1'), p('Player 2'), p('Player 3')]),
        ['1', '2', '3']);
    expect(seatLabels([p('Sam'), p('Mary Jane'), p('Player 3')]),
        ['S', 'MJ', '3']);
    expect(seatLabels([p('Sam'), p('Sim'), p('Jo')]), ['Sa', 'Si', 'J']);
    expect(seatLabels([p('Sam'), p('Sam')]), ['1', '2']);
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
    const width = 100.0;
    final short = TableCard.sizeFor('Win the 3♥', width);
    final long = TableCard.sizeFor(
        'Win a trick where every card is lower than 7, with no Court Cards',
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
    final deal = find.textContaining(RegExp(r'^Deal \d+ points$'));
    expect(deal, findsOneWidget);
    await tester.tap(deal);
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(HomePage)) as dynamic;
    expect(state.targetPoints, isNot(10));
    expect(find.text('Round 2'), findsOneWidget);
    expect(find.text('Who holds the K♠?'), findsOneWidget);
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
    final state = tester.state(find.byType(HomePage)) as dynamic;
    expect((state.game as GameState).losses, 0);
  });

  testWidgets('Picking moves clockwise from the King, then Play!',
      (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 3);
    await tester.tap(find.byType(SeatToken).at(1)); // seat 1 is King
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(HomePage)) as dynamic;
    final game = state.game as GameState;
    expect(game.pickTurn, 1);
    expect(find.byType(PulseRing), findsOneWidget);

    var seat = 1;
    while (game.pickTurn != null) {
      final card = find
          .byWidgetPredicate((w) =>
              w is TableCard &&
              w.owner == null &&
              game.canTake(w.task, game.pickTurn!))
          .first;
      final target =
          tester.getCenter(find.byType(SeatToken).at(game.pickTurn!));
      final g = await tester.startGesture(tester.getCenter(card));
      await g.moveBy(const Offset(10, 10));
      await g.moveTo(target);
      await g.up();
      await tester.pump();
      seat = (seat + 1) % 3;
      if (game.pickTurn != null) expect(game.pickTurn, seat);
      await tester.pumpAndSettle();
    }
    expect(game.tasks.every((t) => t.assignedPlayerIndex != null), isTrue);
    expect(find.byType(PulseRing), findsNothing);
  });

  testWidgets('Tapping a seat opens the courtier card to mark power and reveal',
      (tester) async {
    setPhoneSize(tester);
    await dealGame(tester, 4);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(HomePage)) as dynamic;
    final game = state.game as GameState;

    await tester.tap(find.byType(SeatToken).at(2));
    await tester.pumpAndSettle();
    expect(find.text(game.courtiers[2].house), findsOneWidget);
    await tester.tap(find.text('Use power'));
    await tester.pumpAndSettle();
    expect(game.powerUsed[2], isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(game.spoke[2], isTrue);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Without roles, tapping a seat flips its speech token',
      (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await setupThrough(tester, mode: 'Free play');
    await tester.ensureVisible(find.text('Courtly roles'));
    await tester.tap(find.text('Courtly roles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deal tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    final game = (tester.state(find.byType(HomePage)) as dynamic).game
        as GameState;
    expect(game.roles, isFalse);
    expect(find.byType(ShapedToken), findsNothing);
    await tester.tap(find.byType(SeatToken).at(3));
    await tester.pumpAndSettle();
    expect(game.spoke[3], isTrue);
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
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final live = (tester.state(find.byType(HomePage)) as dynamic).game as GameState;
    expect(live.spoke[1], isTrue, reason: 'the switch marks the reveal');
    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Start the app again from scratch with the same storage.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(HomePage)) as dynamic;
    final game = state.game as GameState;
    expect(game.kingIndex, 0);
    expect(game.spoke[1], isTrue);
    expect(find.byType(TableCard), findsWidgets);
    expect(find.text('Who holds the K♠?'), findsNothing);
  });

  test('Campaign streaks rise with wins and reset on a loss', () {
    final game = GameState()
      ..campaign = true
      ..players = [
        for (int i = 0; i < 3; i++) Player('P$i', color: Colors.red)
      ]
      ..addTasksUntilTarget(3, 6);
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
        for (int i = 0; i < 4; i++) Player('P$i', color: Colors.blue)
      ]
      ..addTasksUntilTarget(4, 10)
      ..setKing(2);
    game.assign(game.tasks.first, 3);
    game.toggleSpoke(1);
    final copy = GameState.fromJson(
        jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>)!;
    expect(copy.kingIndex, 2);
    expect(copy.tasks.first.assignedPlayerIndex, 3);
    expect(copy.spoke[1], isTrue);
    expect(copy.tasks.map((t) => t.description),
        game.tasks.map((t) => t.description));
  });

  test('Seals must be completed in order, Ω last', () {
    final game = GameState()
      ..players = [for (int i = 0; i < 4; i++) Player('P$i', color: Colors.red)]
      ..sealCount = 3
      ..addTasksUntilTarget(4, 14, newRound: false);
    final sealed = {for (final t in game.tasks) if (t.seal != null) t.seal!: t};
    expect(sealed.keys.toSet(), {1, 2, Seals.last});
    expect(game.sealProblem(sealed[2]!), contains('Seal I'));
    expect(game.sealProblem(sealed[1]!), isNull);
    sealed[1]!.status = TaskStatus.completed;
    expect(game.sealProblem(sealed[2]!), isNull);
    expect(game.sealProblem(sealed[Seals.last]!), contains('Ω'));
    for (final t in game.tasks) {
      if (t.seal != Seals.last) t.status = TaskStatus.completed;
    }
    expect(game.sealProblem(sealed[Seals.last]!), isNull);
  });

  test('Decrees change who can pick, speak and take tasks', () {
    GameState make(Decree d) => GameState()
      ..players = [for (int i = 0; i < 4; i++) Player('P$i', color: Colors.red)]
      ..addTasksUntilTarget(4, 10)
      ..decree = d;

    final exile = make(Decree.exile)..setKing(0);
    expect(exile.exiledSeat, isNotNull);
    expect(exile.exiledSeat, isNot(0));
    expect(exile.canTake(exile.tasks.first, exile.exiledSeat!), isFalse);

    final silence = make(Decree.silence)..setKing(0);
    expect(silence.canSpeak(1), isFalse);

    // Late Counsel is kept by the players: the app doesn't count tricks.
    final late = make(Decree.lateCounsel)..setKing(0);
    expect(late.canSpeak(1), isTrue);

    final command = make(Decree.kingsCommand)..setKing(2);
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
    for (int i = 0; i < 3; i++) {
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
    final state = tester.state(find.byType(HomePage)) as dynamic;
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

  GameState dynasty(int players) => GameState()
    ..mode = GameMode.dynasty
    ..players = [for (int i = 0; i < players; i++) Player('P$i', color: Colors.red)]
    ..seatCourtiers()
    ..addTasksUntilTarget(players, 8);

  test('Every seat gets a different courtier shape', () {
    final g = dynasty(6);
    expect(g.courtiers.map((c) => c.shape).toSet(), hasLength(6));
  });

  test('The King keeps the crown until wounds exceed a hidden toughness', () {
    final g = dynasty(4)..setKing(1);
    expect(g.reign, 1);
    expect(g.kingToughness, inInclusiveRange(1, 3));
    var rounds = 0;
    while (!g.kingFallen) {
      g.tasks.first.status = TaskStatus.failed;
      g.recordOutcomeIfFinished();
      if (!g.kingFallen) {
        g.nextDynastyRound(4, 8);
        expect(g.kingIndex, 1); // same King, new round
      }
      rounds++;
    }
    expect(rounds, g.kingToughness);
    g.succession();
    g.nextDynastyRound(4, 8);
    expect(g.kingIndex, isNull); // an heir must be crowned
    g.setKing(2);
    expect(g.reign, 2);
    expect(g.kingWounds, 0);
  });

  test('Losing all loyalty turns a courtier into an open antagonist', () {
    final g = dynasty(4)..setKing(0);
    const seat = 2;
    final who = g.courtiers[seat];
    g.applyChoice(Choice('x', 'y', [Loyalty(who, -5)]));
    expect(g.isAntagonist(seat), isTrue);
    expect(g.schemeOf[seat], isNotNull);
    expect(g.canTake(g.tasks.first, seat), isFalse);

    // A failed scheme does nothing; a successful one wounds the King.
    g.resolveScheme(seat, true);
    expect(g.kingWounds, 1);
    g.resolveScheme(seat, false);
    expect(g.kingWounds, 0);

    g.applyChoice(Choice('x', 'y', [Loyalty(who, 2)]));
    expect(g.isAntagonist(seat), isFalse); // won back
  });

  test('Dilemmas only involve courtiers at the table', () {
    final g = dynasty(3);
    for (int i = 0; i < 30; i++) {
      final d = dilemmas[g.pickDilemma()];
      for (final e in [...d.a.effects, ...d.b.effects].whereType<Loyalty>()) {
        expect(g.courtiers, contains(e.courtier));
      }
    }
  });

  test('A dynasty survives saving and loading', () {
    final g = dynasty(4)..setKing(3);
    g.applyChoice(Choice('x', 'y', [Loyalty(g.courtiers[1], -5), Wound(1)]));
    final copy = GameState.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>)!;
    expect(copy.courtiers, g.courtiers);
    expect(copy.kingWounds, 1);
    expect(copy.kingToughness, g.kingToughness);
    expect(copy.isAntagonist(1), isTrue);
  });

  test('Tidings lead to dilemmas that exist', () {
    final titles = dilemmas.map((d) => d.title).toSet();
    for (final t in tidings) {
      for (final f in [t.followWon, t.followLost]) {
        if (f != null) expect(titles, contains(f), reason: t.title);
      }
    }
  });

  test('A royal charge deals a house its task, and it counts', () {
    final g = dynasty(4);
    g.pendingCharge = g.courtiers[2];
    g.setKing(0);
    expect(g.currentTiding, isNotNull);
    if (g.exiledSeat != 2) {
      expect(g.chargeSeat, 2);
      expect(g.chargeByKing, isTrue);
      final charged = g.tasks.where(g.isCharged).single;
      expect(charged.assignedPlayerIndex, 2);
    }
  });

  test('Overruling the council costs loyalty', () {
    final g = dynasty(4)..setKing(0);
    final before = g.loyalty[1];
    g.overruled([1]);
    expect(g.loyalty[1], before - 1);
  });

  test('Deeds move loyalty: the busiest courtier gains favour', () {
    final g = dynasty(4)..setKing(0);
    g.chargeSeat = null; // no royal charge, to count deeds alone
    g.chargeTask = null;
    for (final t in g.tasks) {
      t.assignedPlayerIndex = 1;
      t.status = TaskStatus.completed;
    }
    final before = g.loyalty[1];
    expect(g.recordOutcomeIfFinished(), isTrue);
    expect(g.loyalty[1], before + 1);
    expect(g.roundLoyalty[1], 1);
    expect(g.reignWins, 1);
    g.undoOutcome();
    expect(g.loyalty[1], before);
    expect(g.reignWins, 0);
  });

  test('A dynasty ends in a Golden Age, a fall or a usurping', () {
    final g = dynasty(4)..setKing(0);
    expect(g.ending, isNull);
    g.reignWins = GameState.goldenAgeWins;
    expect(g.ending, DynastyEnding.goldenAge);
    expect(g.epithet, 'the Golden');
    g.reignWins = 0;
    g.applyChoice(Choice('x', 'y',
        [Loyalty(g.courtiers[1], -5), Loyalty(g.courtiers[2], -5)]));
    expect(g.ending, DynastyEnding.usurped);
    expect(g.epithet, 'the Stern');
    final h = dynasty(4)..setKing(1);
    for (int i = 0; i < GameState.maxFallenKings; i++) {
      h.succession();
      h.setKing(1);
    }
    expect(h.ending, DynastyEnding.fallen);
    expect(h.annals.length, GameState.maxFallenKings);
  });

  testWidgets('A Dynasty round ends with the King\'s dilemma', (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await setupThrough(tester, mode: 'Dynasty');
    expect(find.text('Points target'), findsNothing); // the story sets them
    await tester.tap(find.text('Begin the reign'));
    await tester.pumpAndSettle();
    expect(find.text('Who will be King?'), findsOneWidget);
    await tester.tap(find.byType(SeatToken).first);
    await tester.pumpAndSettle();
    // Every Dynasty round opens with tidings.
    expect(find.text('Tidings'), findsOneWidget);
    await tester.tap(find.text('So it begins'));
    await tester.pumpAndSettle();
    expect(find.byType(ShapedToken), findsWidgets);

    final state = tester.state(find.byType(HomePage)) as dynamic;
    final game = state.game as GameState;
    expect(game.reign, 1);

    // Win the round.
    final pending =
        find.byWidgetPredicate((w) => w is TableCard && !w.task.isCompleted);
    while (find.text('Round won').evaluate().isEmpty) {
      // Dynasty rounds have at most one seal, so any order is fine.
      final card = pending.first;
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Done')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('The King must decide'));
    await tester.pumpAndSettle();
    expect(find.text('The King\u2019s Dilemma'), findsOneWidget);
    final d = dilemmas[state.debugDilemma as int];
    if (d.council) {
      // Everyone votes A, and the King heeds the court.
      final votes = find.text('A');
      for (int i = 0; i < votes.evaluate().length; i++) {
        await tester.tap(votes.at(i));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.textContaining('Heed the court'));
    } else {
      await tester.tap(find.text(d.a.label));
    }
    await tester.pumpAndSettle();
    expect(find.text('So it is decided'), findsOneWidget);
    await tester.tap(find.text(game.kingFallen
        ? 'Attend the King'
        : game.ending != null
            ? 'The traitors rise'
            : 'Next round'));
    await tester.pumpAndSettle();
    if (!game.kingFallen && game.ending == null) {
      expect(game.kingIndex, 0); // the King reigns on
      expect(find.text('Who will be King?'), findsNothing);
    }
  });

  test('Seals come in twos or not at all', () {
    for (int i = 0; i < 50; i++) {
      final g = GameState()
        ..surprise = true
        ..addTasksUntilTarget(4, 3 + i % 12);
      final sealed = g.tasks.where((t) => t.seal != null).length;
      expect(sealed == 0 || sealed >= 2, isTrue);
    }
    expect(chronicle.every((c) => c.seals == 0 || c.seals >= 2), isTrue);
  });

  for (final mode in ['Free play', 'Dynasty']) {
    testWidgets('On-screen cards play a whole $mode round', (tester) async {
      setPhoneSize(tester);
      HomePageTestHooks.fast();
      await tester.pumpWidget(const TheKingsCourtApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(mode));
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('On-screen cards'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(mode == 'Dynasty' ? 'Begin the reign' : 'Deal tasks'));
      await tester.pump();

      final state = tester.state(find.byType(HomePage)) as dynamic;
      final game = state.game as GameState;
      expect(game.digital, isTrue);
      expect(game.players.first.name, 'You');
      for (int i = 0;
          i < 3000 && game.outcome == RoundOutcome.inProgress;
          i++) {
        await tester.pump(const Duration(milliseconds: 30));
        if (find.text('So it begins').evaluate().isNotEmpty) {
          await tester.tap(find.text('So it begins'));
        } else if (find.text('So be it').evaluate().isNotEmpty) {
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
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  test('Roman numerals for reigns', () {
    expect([1, 2, 4, 9, 14].map(roman), ['I', 'II', 'IV', 'IX', 'XIV']);
  });

  test('Task draw hits the target without repeats', () {
    for (final players in [2, 3, 4, 5, 6]) {
      for (final target in [5, 10, 20]) {
        final game = GameState()..addTasksUntilTarget(players, target);
        final total = game.tasks
            .fold<int>(0, (sum, t) => sum + t.getPointsForPlayerCount(players));
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
    final game = GameState()..addTasksUntilTarget(6, 12);
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
      ..addTasksUntilTarget(4, 10)
      ..setKing(1);
    game.shuffleTasks(4, 10);
    expect(game.roundNumber, 1);
    expect(game.kingIndex, 1);
  });

  test('The King cannot take King-relative tasks', () {
    final game = GameState();
    final kingTask = GameState.taskPool.firstWhere((t) => t.kingCantTake);
    game.tasks = [kingTask.freshCopy()..assignedPlayerIndex = 2];
    game.setKing(2);
    expect(game.tasks.first.assignedPlayerIndex, isNull);
    expect(game.canTake(game.tasks.first, 2), isFalse);
    expect(game.canTake(game.tasks.first, 0), isTrue);
  });

  test('Every task has 6-player points', () {
    for (final t in GameState.taskPool) {
      expect(t.sixPlayerPoints, greaterThan(0), reason: t.description);
    }
    expect(GameState.taskPool.length, 97);
  });
}
