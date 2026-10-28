/// The table's dialogs (ui/dialogs/): what each shows and what it gives
/// back: the points target, the announced number, who takes a task, the
/// task close-up's buttons and the courtier's card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/game/courtiers.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/ui/dialogs/courtier_card.dart';
import 'package:kings_court/ui/dialogs/table_dialogs.dart';
import 'package:kings_court/ui/dialogs/task_close_up.dart';

final players = [for (final n in ['Ann', 'Ben', 'Cal']) Player(n, colorValue: 0xFF336699)];

/// A page with one button, Open, that runs [open] (a dialog).
Future<void> opener(WidgetTester tester, Future<void> Function(BuildContext) open) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) =>
                  TextButton(onPressed: () => open(context), child: const Text('Open'))))));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('The points dialog gives the target back on Deal, nothing on Cancel', (tester) async {
    int? got;
    var closed = false;
    await opener(tester, (c) async {
      got = await showPointsDialog(c, current: 6);
      closed = true;
    });
    expect(find.text('Points target'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    await tester.tap(find.text('Deal'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(got, 6);
    await opener(tester, (c) async => got = await showPointsDialog(c, current: 6));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(got, isNull);
  });

  testWidgets('The announce dialog counts between the least and every trick', (tester) async {
    int? announced;
    await opener(tester, (c) async {
      announced = await showAnnounceDialog(c,
          text: 'Win exactly X tricks', least: 1, totalTricks: 3);
    });
    expect(find.text('How many tricks?'), findsOneWidget);
    expect(find.textContaining('You hold the King card'), findsOneWidget);
    final minus = find.widgetWithIcon(IconButton, Icons.remove);
    final plus = find.widgetWithIcon(IconButton, Icons.add);
    expect(tester.widget<IconButton>(minus).onPressed, isNull, reason: 'at the least already');
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(tester.widget<IconButton>(plus).onPressed, isNull, reason: 'every trick');
    await tester.tap(find.text('Announce'));
    await tester.pumpAndSettle();
    expect(announced, 3);
  });

  testWidgets('Who takes it: a name gives its seat back', (tester) async {
    int? seat;
    await opener(tester, (c) async {
      seat = await showWhoTakesDialog(c, seats: [1, 2], players: players);
    });
    expect(find.text('Ann'), findsNothing);
    await tester.tap(find.text('Cal'));
    await tester.pumpAndSettle();
    expect(seat, 2);
  });

  testWidgets('You’re ready: play a game, or not now', (tester) async {
    bool? play;
    await opener(tester, (c) async => play = await showReadyDialog(c));
    await tester.tap(find.text('Play a game'));
    await tester.pumpAndSettle();
    expect(play, isTrue);
  });

  group('The task close-up', () {
    final round = Round(players: 3, target: 6)
      ..tasks = [RoundTask(taskByDescription('Win the first trick'), owner: 1)];
    final task = round.tasks.first;

    testWidgets('on screen shows the card and takes it', (tester) async {
      var taken = false;
      await opener(
          tester,
          (c) => showTaskCloseUp(
              c,
              TaskCloseUp(
                  task: task,
                  round: round,
                  players: players,
                  quarterTurns: 0,
                  onScreen: true,
                  progress: '0/1',
                  onTake: () => taken = true)));
      expect(find.text('${task.points(3)}'), findsOneWidget);
      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      await tester.tap(find.text('Take'));
      await tester.pumpAndSettle();
      expect(taken, isTrue);
      expect(find.text('Close'), findsNothing, reason: 'closed');
      // Without a pick to make, no Take.
      await opener(
          tester,
          (c) => showTaskCloseUp(
              c,
              TaskCloseUp(
                  task: task, round: round, players: players, quarterTurns: 0, onScreen: true)));
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Take'), findsNothing);
    });

    testWidgets('at a real table marks it done or failed', (tester) async {
      final marks = <TaskStatus>[];
      Future<void> open(BuildContext c) => showTaskCloseUp(
          c,
          TaskCloseUp(
              task: task,
              round: round,
              players: players,
              quarterTurns: 1,
              onScreen: false,
              onMark: marks.add));
      await opener(tester, open);
      expect(find.text('Take'), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(marks, [TaskStatus.completed]);
      await opener(tester, open);
      await tester.tap(find.text('Failed'));
      await tester.pumpAndSettle();
      expect(marks, [TaskStatus.completed, TaskStatus.failed]);
    });
  });

  testWidgets('The courtier’s card names the King, tells their story and offers your reveal', (tester) async {
    final round = Round(players: 3, target: 6)..king = 1;
    var spoke = false;
    Future<void> open(BuildContext c, {int seat = 1, VoidCallback? onSpeak}) => showCourtierCard(
        c,
        CourtierCard(
            seat: seat,
            courtier: Courtier.duke,
            player: players[seat],
            round: round,
            quarterTurns: 0,
            onScreen: true,
            choosingKing: false,
            you: 0,
            onSpeak: onSpeak));
    await opener(tester, open);
    expect(find.text('Ben, the King'), findsOneWidget);
    expect(find.text(Courtier.duke.story), findsOneWidget);
    expect(find.text('Hasn’t shown a card.'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    // Your own card: the reveal is yours to use.
    await opener(tester, (c) => open(c, seat: 0, onSpeak: () => spoke = true));
    expect(find.text('Ann'), findsOneWidget);
    await tester.tap(find.text('Show a card'));
    await tester.pumpAndSettle();
    expect(spoke, isTrue);
  });
}
