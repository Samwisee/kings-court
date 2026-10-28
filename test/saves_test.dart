/// Saved games from before the refactor still load, and mean the same.
///
/// The files in test/fixtures/saves were written by the pre-refactor code
/// (tool/fixtures/make_saves_test.dart, run once in CI): each holds a save
/// slot's data and a `facts` map saying what that save meant at the time.
/// Bug reports carry the same `game` JSON, so this keeps them readable too.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/chronicle.dart';
import 'package:kings_court/models.dart';

void main() {
  final files = Directory('test/fixtures/saves')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && !f.path.endsWith('progress.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('There are saves to check', () => expect(files, isNotEmpty));

  for (final file in files) {
    test('${file.uri.pathSegments.last} loads and means the same', () {
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
      expect(game.kingIndex, facts['king']);
      expect(game.pickTurn, facts['pickTurn']);
      expect(game.sealCount, facts['seals']);
      expect(game.decree?.name, facts['decree']);
      expect(game.exiledSeat, facts['exiled']);
      expect(game.outcome.name, facts['outcome']);
      expect(game.dealId, facts['dealId']);
      expect(game.seed, facts['seed']);
      final tasks = facts['tasks'] as List<dynamic>;
      expect(game.tasks.length, tasks.length);
      for (var i = 0; i < tasks.length; i++) {
        final t = tasks[i] as Map<String, dynamic>;
        expect(game.tasks[i].description, t['d']);
        expect(game.tasks[i].assignedPlayerIndex, t['owner']);
        expect(game.tasks[i].status.name, t['status']);
        expect(game.tasks[i].seal, t['seal']);
      }
      if (facts.containsKey('hands')) {
        final cards = game.cards!;
        expect([for (final h in cards.hands) [for (final c in h) c.label]], facts['hands']);
        expect(cards.tricks.length, facts['tricks']);
        expect([for (final c in cards.current) c.label], facts['current']);
        expect(cards.turn, facts['turn']);
        expect(cards.announced, facts['announced']);
        expect({for (final e in cards.revealed.entries) '${e.key}': e.value.label},
            facts['shown']);
      } else {
        expect(game.cards, isNull);
      }
      // The target was kept beside the game then; the page reads it in.
      expect(data['playerCount'], facts['playerCount']);
      expect(data['targetPoints'], facts['target']);
      expect(game.players.length, facts['playerCount']);
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
