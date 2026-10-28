import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/engine/task.dart';
import 'package:kings_court/game/actions.dart';
import 'package:kings_court/net/table_link.dart';

void main() {
  test('Moves survive the trip to JSON and back', () {
    final card = PlayingCard.parse('7♠')!;
    for (final move in <MatchAction>[
      PlayCard(2, card),
      ShowCard(1, card),
      const PickTask(0, 3),
      const Announce(1, 2, 4),
      const Pass(2),
    ]) {
      final back = MatchAction.fromJson(move.toJson())!;
      expect(back.runtimeType, move.runtimeType);
      expect(back.toJson(), move.toJson());
    }
  });

  test('Passing moves the pick on, and only on your turn', () {
    final s = Round(players: 3, target: 5)..newRound(Random(3));
    final first = s.pickTurn!;
    expect(s.problem(Pass((first + 1) % 3)), isNotNull);
    expect(s.problem(Pass(first)), isNull);
    s.apply(Pass(first));
    expect(s.pickTurn, isNot(first));
    expect(s.passed, {first});
    expect(s.phase, Phase.picking);
  });

  test('A local link plays each move at once, in order, numbered, and keeps them', () {
    final link = LocalLink();
    final seen = <Move>[];
    link.moves.listen(seen.add);
    final a = PlayCard(0, PlayingCard.parse('9♥')!);
    final b = ShowCard(1, PlayingCard.parse('2♣')!);
    link.send(a);
    expect(seen.map((m) => m.action), [a]); // straight back, before send returns
    link.send(b);
    expect(seen.map((m) => m.action), [a, b]);
    expect(seen.map((m) => m.seq), [0, 1]);
    expect(link.history.map((m) => m.action), [a, b]);
    // A new game starts the moves again.
    link.reset();
    expect(link.history, isEmpty);
    link.send(b);
    expect(link.history.single.seq, 0);
    link.dispose();
  });

  test('A move travels as JSON with its number, as does every kind of action', () {
    final card = PlayingCard.parse('7♦')!;
    for (final action in <Action>[
      PlayCard(2, card),
      ShowCard(1, card),
      const PickTask(0, 3),
      const Announce(1, 2, 4),
      const Pass(2),
      const Crown(0, 2),
      const Speak(1, on: true),
      const MarkTask(0, 1, TaskStatus.failed),
      const UndoMark(0),
      const NextRound(0),
      const NextRound(0, target: 7, chapter: 3, lesson: 1),
      const Retry(0),
      const Redeal(0, 9),
    ]) {
      final move = Move(5, action);
      final back = Move.fromJson(jsonDecode(jsonEncode(move.toJson())) as Map<String, dynamic>)!;
      expect(back.seq, 5);
      expect(back.action.runtimeType, action.runtimeType);
      expect(back.action.toJson(), action.toJson());
      expect(back.action.seat, action.seat);
    }
    expect(Move.fromJson({'seq': 1, 'type': 'nonsense', 'seat': 0}), isNull);
  });
}
