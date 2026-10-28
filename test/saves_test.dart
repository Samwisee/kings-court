/// Saved games of every version still load, and mean the same.
///
/// test/fixtures/saves holds saves written by the pre-refactor code
/// (version 1; tool/fixtures/make_saves_test.dart, run once in CI) and,
/// under v<n>/, saves written in each later shape (test/tool/make_saves_test.dart
/// writes them). Each file holds a save slot's data and a `facts` map
/// saying what that save meant when it was written, so the loader can be
/// checked against it. Bug reports carry the same `game` JSON, so this
/// keeps them readable too.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/modes/chronicle/chapters.dart';

void main() {
  final files = Directory('test/fixtures/saves')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && !f.path.endsWith('progress.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('There are saves to check', () => expect(files, isNotEmpty));

  test('Every version up to the current one has fixtures', () {
    for (var v = 2; v <= GameState.saveVersion; v++) {
      expect(files.where((f) => f.path.contains('/v$v/')), isNotEmpty,
          reason: 'no fixtures for save version $v: run test/tool/make_saves_test.dart');
    }
  });

  test('A save says its version, and loading one again changes nothing', () {
    final g = GameState()
      ..players = [for (var i = 0; i < 3; i++) Player('P$i', colorValue: 0)]
      ..startRound(3, 6);
    final json = g.toJson();
    expect(json['version'], GameState.saveVersion);
    expect(GameState.upgradeSave(json), same(json));
  });

  for (final file in files) {
    final name = file.path.split('test/fixtures/saves/').last;
    test('$name loads and means the same', () {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final facts = data['facts'] as Map<String, dynamic>;
      final g = GameState.fromJson(data['game'] as Map<String, dynamic>);
      expect(g, isNotNull, reason: 'the save no longer loads');
      final game = g!;
      expect(game.mode.name, facts['mode']);
      expect([for (final p in game.players) p.name], facts['players']);
      expect(game.roundNumber, facts['round']);
      expect(game.wins, facts['wins']);
      expect(game.losses, facts['losses']);
      expect(game.streak, facts['streak']);
      final round = game.round!;
      expect(round.king, facts['king']);
      expect(round.pickTurn, facts['pickTurn']);
      expect(round.sealCount, facts['seals']);
      expect(round.decree?.name, facts['decree']);
      expect(round.exiledSeat, facts['exiled']);
      expect(game.outcome.name, facts['outcome']);
      expect(game.dealId, facts['dealId']);
      expect(round.dealId, facts['dealId']);
      expect(game.seed, facts['seed']);
      final tasks = facts['tasks'] as List<dynamic>;
      expect(round.tasks.length, tasks.length);
      for (var i = 0; i < tasks.length; i++) {
        final t = tasks[i] as Map<String, dynamic>;
        expect(round.tasks[i].description, t['d']);
        expect(round.tasks[i].owner, t['owner']);
        expect(round.tasks[i].status.name, t['status']);
        expect(round.tasks[i].seal, t['seal']);
      }
      if (facts.containsKey('hands')) {
        expect(game.digital, isTrue);
        expect([for (final h in round.hands) [for (final c in h) c.label]], facts['hands']);
        expect(round.tricks.length, facts['tricks']);
        expect([for (final c in round.current) c.label], facts['current']);
        expect(round.turn, facts['turn']);
        expect(round.announced, facts['announced']);
        expect({for (final e in round.revealed.entries) '${e.key}': e.value.label},
            facts['shown']);
      } else {
        expect(game.digital, isFalse);
        expect(round.hasCards, isFalse);
      }
      // What loads saves again in the new shape, and loads back the same.
      final again = GameState.fromJson(
          jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>)!;
      expect(jsonEncode(again.toJson()), jsonEncode(game.toJson()));
      expect(again.round!.king, round.king);
      expect(again.round!.turn, round.turn);
      expect([for (final t in again.tasks) t.owner], [for (final t in round.tasks) t.owner]);
      expect(game.players.length, facts['playerCount']);
      // Version 1 kept the target beside the game; the page reads it in.
      if (data.containsKey('targetPoints')) {
        expect(data['playerCount'], facts['playerCount']);
        expect(data['targetPoints'], facts['target']);
      } else {
        expect(game.target, facts['target']);
      }
    });
  }

  test('Chronicle progress from before the refactor loads', () {
    final data = jsonDecode(File('test/fixtures/saves/chronicle-progress.json').readAsStringSync())
        as Map<String, dynamic>;
    final p = ChronicleProgress.fromJson(data['progress'] as Map<String, dynamic>);
    final facts = data['facts'] as Map<String, dynamic>;
    expect(p.nextChapter, facts['nextChapter']);
    expect(p.totalCrowns, facts['totalCrowns']);
  });
}
