import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/game/self_play.dart';

Map<String, Object?> sp(Map<String, Object?> record) => record['selfplay']! as Map<String, Object?>;

void main() {
  test('A seed always plays the same round', () {
    final (a, _) = selfPlay(42, 4, 8, rungNamed('weak'));
    final (b, _) = selfPlay(42, 4, 8, rungNamed('weak'));
    expect(a['round'], b['round']);
    expect(a['moves'], b['moves']);
    expect(a['outcome'], b['outcome']);
  });

  test('Every rung plays the same deal', () {
    final (weak, _) = selfPlay(7, 3, 5, rungNamed('weak'));
    final (casual, _) = selfPlay(7, 3, 5, rungNamed('casual'));
    List<String> dealt(Map<String, Object?> r) => [for (final t in sp(r)['tasks']! as List) (t as Map)['d'] as String];
    expect(dealt(weak), dealt(casual));
    // The hands as dealt: the first move of each is the same position.
    expect(sp(weak)['rung'], 'weak');
    expect(sp(casual)['rung'], 'casual');
    expect(sp(weak)['seed'], 7);
  });

  test('A record has what the game sends and what the run adds', () {
    final (r, none) = selfPlay(3, 4, 11, rungNamed('weak'));
    for (final key in ['v', 'build', 'players', 'outcome', 'round', 'moves', 'selfplay']) {
      expect(r.containsKey(key), isTrue, reason: key);
    }
    final run = sp(r);
    for (final key in ['seed', 'target', 'rung', 'budget', 'tasks', 'decisions', 'effort', 'ms']) {
      expect(run.containsKey(key), isTrue, reason: key);
    }
    expect(none, isEmpty, reason: 'no teacher asked');
  });

  test('Taught, the courtiers are asked against an all-seeing one', () {
    var seen = 0;
    for (var seed = 1; seed <= 3; seed++) {
      final (_, disagreements) = selfPlay(seed, 4, 8, rungNamed('weak'), teach: true);
      for (final d in disagreements) {
        expect(d['fair'], isNot(d['seeing']));
        expect(d['seed'], seed);
        seen++;
      }
    }
    expect(seen, greaterThan(0), reason: 'a weak courtier differs from an all-seeing one somewhere in three rounds');
  });

  test('Every rung on the ladder has its own name', () {
    expect(ladder.map((r) => r.name).toSet().length, ladder.length);
    expect(() => rungNamed('nobody'), throwsArgumentError);
  });

  test('The headless runner reaches only the plain Dart layers', () {
    // It runs with plain Dart (dart run bin/selfplay.dart). The layers it
    // may use are kept free of Flutter by layers_test.dart.
    const pure = {'engine', 'game', 'net', 'modes'};
    for (final f in Directory('bin').listSync(recursive: true).whereType<File>()) {
      for (final m in RegExp("import '([^']+)'").allMatches(f.readAsStringSync())) {
        final target = m.group(1)!;
        if (target.startsWith('dart:')) continue;
        final layer = RegExp(r'^package:kings_court/(\w+)/').firstMatch(target)?.group(1);
        expect(pure.contains(layer), isTrue, reason: '${f.path} imports $target');
      }
    }
  });
}
