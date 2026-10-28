/// The tutorial's coach (ui/modes/tutorial/coach.dart): what it says at
/// each moment of a lesson, and its note with the way back and forward.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/modes/tutorial/lessons.dart';
import 'package:kings_court/ui/modes/tutorial/coach.dart';

/// Lesson 1, dealt as the tutorial deals it, you the King, in play.
GameState lessonOne() {
  final d = lessons[0].deal();
  return GameState()
    ..mode = GameMode.tutorial
    ..lesson = 0
    ..players = [for (final n in ['You', 'Duke', 'Earl']) Player(n, colorValue: 0xFF000000)]
    ..round = (Round(players: 3, target: 1)
      ..hands = d.hands
      ..setAside = d.setAside
      ..king = 0
      ..leader = 0
      ..tasks = [
        for (int t = 0; t < lessons[0].tasks.length; t++)
          RoundTask(taskByDescription(lessons[0].tasks[t]), owner: t == 0 ? 0 : 1)
      ]
      ..phase = Phase.playing);
}

String? say(GameState g,
        {bool settingUp = false, Trick? lastTrick, bool yourPlay = false}) =>
    coachLine(g, you: 0, settingUp: settingUp, lastTrick: lastTrick, yourPlay: yourPlay);

void main() {
  test('The coach speaks to each moment of the lesson', () {
    final g = lessonOne();
    final l = lessons[0];
    expect(say(g, settingUp: true), l.intro);
    expect(say(g, yourPlay: true), l.yourTurn[0]);
    expect(say(g), l.watch[0]);
    // The first trick just taken: the lesson has a word on it. Later
    // tricks it says nothing of get the plain line, by you or a courtier.
    final cards = g.round!.hands.map((h) => h.first).toList();
    final mine = Trick(0, const [0, 1, 2], cards, 0);
    g.round!.tricks = [mine];
    expect(say(g, lastTrick: mine), l.afterTrick[0]);
    expect(say(g, yourPlay: true), 'Your lead: play any card.');
    expect(say(g), 'The courtiers are playing.');
    final theirs = Trick(0, const [0, 1, 2], cards, 2);
    g.round!.tricks = [mine, theirs];
    expect(say(g, lastTrick: theirs), 'Earl won the trick, and leads the next one.');
    expect(say(g, lastTrick: mine), 'You won the trick.');
    // Someone is choosing a task.
    g.round!.pickTurn = 1;
    expect(say(g), 'Duke is choosing a task.');
    g.round!.pickTurn = 0;
    expect(say(g), l.pick);
  });

  test('The coach is silent outside a tutorial round in progress', () {
    final g = lessonOne();
    expect(say(g..mode = GameMode.free), isNull);
    g.mode = GameMode.tutorial;
    expect(say(g..lesson = lessons.length), isNull);
    g.lesson = 0;
    g.round!.tasks.first.status = TaskStatus.completed;
    expect(say(g), isNull);
  });

  testWidgets('The note shows the lesson, its line, and leads back or on', (tester) async {
    var back = false;
    var skipped = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Coach(
                lesson: 1,
                line: 'Play the 3♥.',
                onBack: () => back = true,
                onSkip: () => skipped = true))));
    expect(find.text('Lesson 2 of ${lessons.length} · ${lessons[1].title}'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.tap(find.text('Skip'));
    expect(back, isTrue);
    expect(skipped, isTrue);
    // Nothing to say: the note folds away.
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Coach(lesson: 1, line: null, onBack: _nothing, onSkip: _nothing))));
    await tester.pumpAndSettle();
    expect(find.text('Back'), findsNothing);
  });
}

void _nothing() {}
