/// Writes saved games in the shape the game saved them before the refactor,
/// into tool/fixtures/out/, so test/saves_test.dart can prove they still
/// load afterwards. Run once, on the pre-refactor code; CI publishes the
/// files to the ci-<branch> branch.
///
/// Each file is what a save slot held (`game` plus the page's extras), and
/// beside each game a `facts` map says what the save meant, read with the
/// pre-refactor code, so the loader can be checked against it.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/chronicle.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/engine/task.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/theme.dart';

void main() {
  const outDir = 'tool/fixtures/out';

  GameState start(GameMode mode, int count, int target,
      {bool digital = true, bool surprise = false, int? chapter, int seed = 11}) {
    final g = GameState()
      ..mode = mode
      ..seed = seed
      ..chapter = chapter
      ..surprise = surprise
      ..players = [
        for (int i = 0; i < count; i++)
          Player(i == 0 && digital ? 'You' : 'Player ${i + 1}',
              colorValue: Palette.players[i % Palette.players.length].toARGB32())
      ]
      ..seatCourtiers()
      ..addTasksUntilTarget(count, target);
    if (digital) {
      g.cards = MatchState(players: count, target: target);
      for (int i = 1; i < count; i++) {
        g.players[i].name = g.courtiers[i].title;
      }
    }
    return g;
  }

  /// Deals the cards as the page does, and crowns the King.
  void deal(GameState g) {
    final c = g.cards!;
    c.dealFor(g.dealId, g.dealRandom(),
        accept: (hands, inPlay) =>
            g.tasks.every((t) => playableWith(t.description, hands, inPlay)));
    g.setKing(c.king);
  }

  /// Everyone takes a task in turn, from the King.
  void pickAll(GameState g) {
    var guard = 0;
    while (g.pickTurn != null && guard++ < 40) {
      final seat = g.pickTurn!;
      final t = g.tasks.firstWhere(
          (t) => t.assignedPlayerIndex == null && g.canTake(t, seat),
          orElse: () => g.tasks.firstWhere((t) => t.assignedPlayerIndex == null));
      g.assign(t, seat);
    }
    for (final t in g.tasks) {
      if (needsX(t.description)) g.cards!.announced[t.description] = 2;
    }
  }

  /// Plays [n] tricks with legal cards, judging tasks as the page would.
  void playTricks(GameState g, int n) {
    final c = g.cards!;
    for (int i = 0; i < n; i++) {
      while (c.current.isNotEmpty || c.tricks.length <= i) {
        final seat = c.turn;
        final legal = c.legalFor(seat);
        if (legal.isEmpty) return;
        if (c.playCard(seat, legal.first) != null) break;
      }
      final v = c.view;
      for (final t in g.tasks) {
        if (t.status != TaskStatus.pending || t.assignedPlayerIndex == null) continue;
        final verdict = taskRules[t.description]!(
            v, t.assignedPlayerIndex!, c.announced[t.description]);
        if (verdict == Verdict.done && g.sealProblem(t) == null) {
          t.status = TaskStatus.completed;
        } else if (verdict != Verdict.pending) {
          t.status = TaskStatus.failed;
        }
      }
    }
  }

  Map<String, dynamic> facts(GameState g, int playerCount, int target) => {
        'mode': g.mode.name,
        'players': [for (final p in g.players) p.name],
        'playerCount': playerCount,
        'target': target,
        'round': g.roundNumber,
        'wins': g.wins,
        'losses': g.losses,
        'streak': g.streak,
        'king': g.kingIndex,
        'pickTurn': g.pickTurn,
        'seals': g.sealCount,
        'decree': g.decree?.name,
        'exiled': g.exiledSeat,
        'tasks': [
          for (final t in g.tasks)
            {
              'd': t.description,
              'owner': t.assignedPlayerIndex,
              'status': t.status.name,
              'seal': t.seal,
            }
        ],
        'outcome': g.outcome.name,
        'dealId': g.dealId,
        'seed': g.seed,
        if (g.cards != null) ...{
          'hands': [for (final h in g.cards!.hands) [for (final c in h) c.label]],
          'tricks': g.cards!.tricks.length,
          'current': [for (final c in g.cards!.current) c.label],
          'turn': g.cards!.turn,
          'announced': g.cards!.announced,
          'shown': {for (final e in g.cards!.revealed.entries) '${e.key}': e.value.label},
        },
      };

  Future<void> write(String name, GameState g, int playerCount, int target,
      {Map<String, dynamic> extras = const {}}) async {
    final data = {
      'game': g.toJson(),
      'playerCount': playerCount,
      'targetPoints': target,
      'cardWidth': 120.0,
      'dealt': true,
      'pos': [for (final _ in g.tasks) null],
      'tilt': [for (final _ in g.tasks) 0.0],
      ...extras,
      'savedAt': 1761600000000,
      'facts': facts(g, playerCount, target),
    };
    final file = File('$outDir/$name.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  test('free play on screen, mid-round', () async {
    final g = start(GameMode.free, 4, 10);
    deal(g);
    pickAll(g);
    // Someone shows a card before play.
    final c = g.cards!;
    for (int seat = 1; seat < 4; seat++) {
      final card = c.hands[seat].where((x) => c.revealFor(seat, x) != null).firstOrNull;
      if (card != null) {
        c.apply(ShowCard(seat, card));
        break;
      }
    }
    playTricks(g, 3);
    expect(g.outcome, RoundOutcome.inProgress);
    await write('free-screen-midround', g, 4, 10);
  });

  test('free play on screen, between picking', () async {
    final g = start(GameMode.free, 3, 7, seed: 5);
    deal(g);
    g.assign(g.tasks.firstWhere((t) => g.canTake(t, g.pickTurn!)), g.pickTurn!);
    await write('free-screen-picking', g, 3, 7);
  });

  test('free play at a real table, with seals and a decree', () async {
    GameState g;
    var seed = 20;
    do {
      g = start(GameMode.free, 5, 12, digital: false, surprise: true, seed: seed++);
    } while (g.sealCount < 2 || g.decree == null || g.decree == Decree.exile);
    g.setKing(2);
    g.assign(g.tasks.firstWhere((t) => g.canTake(t, 2)), 2);
    g.tasks.firstWhere((t) => t.assignedPlayerIndex == 2).status = TaskStatus.completed;
    g.toggleSpoke(3);
    final rand = Random(1);
    await write('free-table-seals', g, 5, 12, extras: {
      'cardWidth': 96.0,
      'pos': [
        for (final _ in g.tasks) [rand.nextDouble() * 0.6 + 0.2, rand.nextDouble() * 0.6 + 0.2]
      ],
      'tilt': [for (final _ in g.tasks) (rand.nextDouble() - 0.5) * 0.08],
    });
  });

  test('free play at a real table, exile', () async {
    GameState g;
    var seed = 60;
    do {
      g = start(GameMode.free, 4, 9, digital: false, surprise: true, seed: seed++);
    } while (g.decree != Decree.exile);
    g.setKing(1);
    await write('free-table-exile', g, 4, 9);
  });

  test('endless, a few rounds in', () async {
    final g = start(GameMode.endless, 4, 6, seed: 3);
    deal(g);
    pickAll(g);
    // Two rounds won already.
    g
      ..wins = 2
      ..streak = 2
      ..bestStreak = 4
      ..roundNumber = 3;
    playTricks(g, 2);
    await write('endless-midround', g, 4, 6);
  });

  test('a round just won, not yet dealt again', () async {
    final g = start(GameMode.free, 3, 5, seed: 9);
    deal(g);
    pickAll(g);
    for (final t in g.tasks) {
      t.status = TaskStatus.completed;
    }
    expect(g.recordOutcomeIfFinished(), isTrue);
    expect(g.outcome, RoundOutcome.won);
    await write('free-screen-won', g, 3, 5);
  });

  test('the chronicle, chapter 7', () async {
    final g = start(GameMode.chronicle, 4, chronicle[6].points, chapter: 6, seed: 2);
    deal(g);
    pickAll(g);
    playTricks(g, 1);
    await write('chronicle-chapter7', g, 4, chronicle[6].points);
    final progress = ChronicleProgress(attempts: {0: 1, 1: 2, 6: 1}, crowns: {0: 3, 1: 2});
    final file = File('$outDir/chronicle-progress.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'progress': progress.toJson(),
      'facts': {'nextChapter': progress.nextChapter, 'totalCrowns': progress.totalCrowns},
    }));
  });

  test('the chronicle, King\'s Command', () async {
    final g = start(GameMode.chronicle, 4, chronicle[5].points, chapter: 5, seed: 8);
    deal(g);
    expect(g.decree, Decree.kingsCommand);
    await write('chronicle-kings-command', g, 4, chronicle[5].points);
  });

  test('every task in the library, saved and read back', () async {
    // A real table can hold any task; this checks every description survives.
    final g = start(GameMode.free, 4, 10, digital: false, seed: 1);
    g.tasks
      ..clear()
      ..addAll([for (final t in allTasks) t.freshCopy()]);
    g.setKing(0);
    await write('every-task', g, 4, 10);
  });
}
