/// Writes the save fixtures for the current save version: every older
/// fixture in test/fixtures/saves, loaded and saved again in today's
/// shape, with the same `facts`. Run in CI (the check workflow publishes
/// test/tool/out/fixtures to the ci-<branch> branch); commit the files
/// under test/fixtures/saves/v<version>/ whenever the version changes, so
/// test/saves_test.dart keeps checking every shape ever written.
@Tags(['tool'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/game/state.dart';

void main() {
  test('Every older fixture saved again in the current shape', () {
    final out = Directory('test/tool/out/fixtures/v${GameState.saveVersion}')
      ..createSync(recursive: true);
    final files = Directory('test/fixtures/saves')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json') && !f.path.endsWith('progress.json'));
    var written = 0;
    for (final file in files) {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final game = GameState.fromJson(data['game'] as Map<String, dynamic>);
      if (game == null) continue;
      // Version 1 kept the target beside the game; the page reads it in.
      final saved = data['game'] as Map<String, dynamic>;
      if (!saved.containsKey('target') && data['targetPoints'] is int) {
        game.target = data['targetPoints'] as int;
      }
      final name = file.uri.pathSegments.last;
      File('${out.path}/$name').writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
        'game': game.toJson(),
        'cardWidth': data['cardWidth'],
        'dealt': data['dealt'],
        'pos': data['pos'],
        'tilt': data['tilt'],
        'savedAt': data['savedAt'],
        'facts': data['facts'],
      }));
      written++;
    }
    expect(written, greaterThan(0));
  });
}
