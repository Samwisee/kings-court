/// The outcome card (ui/overlays/outcome_card.dart): what it says of a
/// won or lost round, the Chronicle's crowns and buttons, the next
/// round's target, and the lesson card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/modes/chronicle/chapters.dart';
import 'package:kings_court/modes/tutorial/lessons.dart';
import 'package:kings_court/ui/overlays/outcome_card.dart';
import 'package:kings_court/ui/widgets.dart';

GameState finished({required bool won, GameMode mode = GameMode.free, int? chapter}) {
  final g = GameState()
    ..mode = mode
    ..chapter = chapter
    ..players = [for (var i = 0; i < 3; i++) Player('P$i', colorValue: 0xFF000000)]
    ..startRound(3, 6);
  for (final t in g.tasks) {
    t.owner = 1;
    t.status = TaskStatus.completed;
  }
  if (!won) {
    g.tasks.first.status = TaskStatus.failed;
    g.tasks.first.whyFailed = 'The 3♥ went elsewhere.';
  }
  g.recordOutcomeIfFinished();
  return g;
}

Widget card(GameState g,
    {int crowns = 0,
    int nextTarget = 7,
    bool canUndo = false,
    void Function(int)? onDeal,
    void Function(int)? onChapter,
    VoidCallback? onUndo}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OutcomeCard(
            game: g,
            won: g.outcome == RoundOutcome.won,
            you: 0,
            onScreen: true,
            crowns: crowns,
            nextTarget: nextTarget,
            canUndo: canUndo,
            wording: (t) => t.description,
            onRetry: () {},
            onDeal: onDeal ?? (_) {},
            onChapter: onChapter ?? (_) {},
            onUndo: onUndo ?? () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('A won round rejoices and offers the next deal at the slider’s target', (tester) async {
    int? dealt;
    await tester.pumpWidget(card(finished(won: true), onDeal: (t) => dealt = t));
    expect(find.text('Round won'), findsOneWidget);
    expect(find.text('Every task is done. The court rejoices.'), findsOneWidget);
    expect(find.text('Won 1, lost 0 so far'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Undo last mark'), findsNothing);
    await tester.tap(find.text('Deal'));
    expect(dealt, 7);
  });

  testWidgets('A lost round names the task that failed, whose it was and why', (tester) async {
    var undone = false;
    await tester.pumpWidget(card(finished(won: false), canUndo: true, onUndo: () => undone = true));
    expect(find.text('Round lost'), findsOneWidget);
    expect(find.text('This task failed:'), findsOneWidget);
    // SuitText sets the suit in its own span, so match its text as given.
    expect(find.byWidgetPredicate((w) => w is SuitText && w.text == 'P1’s task. The 3♥ went elsewhere.'),
        findsOneWidget);
    await tester.tap(find.text('Undo last mark'));
    expect(undone, isTrue);
  });

  testWidgets('A won chapter shows its crowns and leads to the next', (tester) async {
    int? next;
    await tester.pumpWidget(card(finished(won: true, mode: GameMode.chronicle, chapter: 2),
        crowns: 2, onChapter: (c) => next = c));
    expect(find.text('Chapter 3: ${chronicle[2].title}'), findsOneWidget);
    expect(find.text('Replay chapter'), findsOneWidget);
    expect(find.text('Deal'), findsNothing);
    await tester.tap(find.text('Next chapter'));
    expect(next, 3);
    // The last chapter has no next.
    await tester.pumpWidget(card(finished(won: true, mode: GameMode.chronicle, chapter: chronicle.length - 1)));
    expect(find.text('Next chapter'), findsNothing);
    // A lost chapter: try again.
    await tester.pumpWidget(card(finished(won: false, mode: GameMode.chronicle, chapter: 2)));
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Next chapter'), findsNothing);
  });

  testWidgets('The lesson card tells the lesson, and the last one finishes the tutorial', (tester) async {
    var next = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LessonCard(lesson: 0, won: true, onRetry: () {}, onNext: () => next = true))));
    expect(find.text('Lesson 1: ${lessons[0].title}'), findsOneWidget);
    expect(find.text('Lesson complete'), findsOneWidget);
    await tester.tap(find.text('Next lesson'));
    expect(next, isTrue);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LessonCard(lesson: lessons.length - 1, won: false, onRetry: () {}, onNext: () {}))));
    expect(find.text('Not quite'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
  });
}
