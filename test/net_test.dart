import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/match.dart';
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
      final back = MatchAction.fromJson(move.toJson());
      expect(back.runtimeType, move.runtimeType);
      expect(back.toJson(), move.toJson());
    }
  });

  test('Passing moves the pick on, and only on your turn', () {
    final s = MatchState(players: 3, target: 5)..newRound(Random(3));
    final first = s.pickTurn!;
    expect(s.problem(Pass((first + 1) % 3)), isNotNull);
    expect(s.problem(Pass(first)), isNull);
    s.apply(Pass(first));
    expect(s.pickTurn, (first + 1) % 3);
    expect(s.phase, Phase.picking);
  });

  test('A local link plays each move at once, in order, and keeps them', () {
    final link = LocalLink();
    final seen = <MatchAction>[];
    link.moves.listen(seen.add);
    final a = PlayCard(0, PlayingCard.parse('9♥')!);
    final b = ShowCard(1, PlayingCard.parse('2♣')!);
    link.send(a);
    expect(seen, [a]); // straight back, before send returns
    link.send(b);
    expect(seen, [a, b]);
    expect(link.history, [a, b]);
    link.dispose();
  });

  test('The engine is plain Dart, ready to run on a server', () {
    for (final f in [
      ...Directory('lib/engine').listSync().whereType<File>(),
      File('lib/tasks.dart'),
      File('lib/net/table_link.dart'),
    ]) {
      final imports = f.readAsLinesSync().where((l) => l.startsWith('import '));
      for (final i in imports) {
        expect(i, isNot(contains('package:flutter')), reason: f.path);
        expect(i, isNot(contains('models.dart')), reason: f.path);
        expect(i, isNot(contains('theme.dart')), reason: f.path);
      }
    }
  });
}
