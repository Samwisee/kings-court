/// The modes (modes/): each sets its rounds up its own way, and reads a
/// round's result its own way, through one interface.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/decrees.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/modes/chronicle/chapters.dart';
import 'package:kings_court/modes/modes.dart';
import 'package:kings_court/modes/progress.dart';
import 'package:kings_court/modes/tutorial/lessons.dart';

GameState game(GameMode mode, {int players = 4, int target = 6, int seed = 3}) {
  final g = GameState()
    ..mode = mode
    ..seed = seed
    ..target = target
    ..players = [for (var i = 0; i < players; i++) Player('P$i', colorValue: 0xFF000000)];
  g.startRound(players, target,
      setup: (rand) => modeOf(mode).roundSetup(g, players, rand));
  return g;
}

/// A finished round: every task done, or the first one failed.
RoundResult finish(GameState g, {required bool won}) {
  for (final t in g.tasks) {
    t.owner = 0;
    t.status = TaskStatus.completed;
  }
  if (!won) g.tasks.first.status = TaskStatus.failed;
  return g.round!.result!;
}

void main() {
  test('Every way to play is in the registry, under its own id', () {
    for (final m in GameMode.values) {
      expect(modeOf(m).id, m);
      expect(modeOf(m).title, isNotEmpty);
    }
  });

  test('Free play draws to the target; with surprises on, the seed rolls the seals and decree', () {
    final plain = game(GameMode.free);
    expect(plain.round!.sealCount, 0);
    expect(plain.round!.decree, isNull);
    expect(plain.round!.passing, isTrue);
    expect(plain.tasks, isNotEmpty);

    var rolled = 0;
    for (var seed = 0; seed < 40; seed++) {
      final a = GameState()
        ..mode = GameMode.free
        ..surprise = true
        ..seed = seed;
      final b = GameState()
        ..mode = GameMode.free
        ..surprise = true
        ..seed = seed;
      for (final g in [a, b]) {
        g.startRound(4, 8, setup: (rand) => modeOf(GameMode.free).roundSetup(g, 4, rand));
      }
      expect(a.round!.decree, b.round!.decree);
      expect(a.round!.sealCount, b.round!.sealCount);
      expect([for (final t in a.tasks) t.description], [for (final t in b.tasks) t.description]);
      if (a.round!.decree != null || a.round!.sealCount > 0) rolled++;
    }
    expect(rolled, greaterThan(10));
  });

  test('A re-deal in free play keeps the round’s seals and decree', () {
    final g = GameState()
      ..mode = GameMode.free
      ..surprise = true
      ..seed = 5;
    g.startRound(4, 8, setup: (_) => const RoundSetup(sealCount: 2, decree: Decree.silence));
    final again = modeOf(GameMode.free).roundSetup(g, 4, Random(1), redeal: true);
    expect(again.sealCount, 2);
    expect(again.decree, Decree.silence);
    expect(again.tasks, isNull, reason: 'the tasks are drawn afresh');
  });

  test('Endless adds a point to the target after a win, up to the most', () {
    final mode = modeOf(GameMode.endless);
    final won = game(GameMode.endless, target: 6);
    expect(mode.afterRound(won, finish(won, won: true), Progress()).nextTarget, 7);
    final lost = game(GameMode.endless, target: 6);
    expect(mode.afterRound(lost, finish(lost, won: false), Progress()).nextTarget, 6);
    final top = game(GameMode.endless, target: maxTarget);
    expect(mode.afterRound(top, finish(top, won: true), Progress()).nextTarget, maxTarget);
  });

  test('A Chronicle chapter fixes the round’s seals and decree, and a win earns crowns', () {
    final mode = modeOf(GameMode.chronicle);
    for (var c = 0; c < chronicle.length; c++) {
      final g = GameState()
        ..mode = GameMode.chronicle
        ..chapter = c
        ..players = [for (var i = 0; i < 4; i++) Player('P$i', colorValue: 0)];
      g.startRound(4, chronicle[c].points,
          setup: (rand) => mode.roundSetup(g, 4, rand));
      expect(g.round!.sealCount, chronicle[c].seals, reason: chronicle[c].title);
      expect(g.round!.decree, chronicle[c].decree, reason: chronicle[c].title);
      expect(mode.roundLabel(g), 'chapter${c + 1}');
    }
    final progress = Progress();
    final g = game(GameMode.chronicle)..chapter = 2;
    progress.chronicle.startAttempt(2);
    final effects = mode.afterRound(g, finish(g, won: true), progress);
    expect(effects.crowns, 3, reason: 'first attempt');
    expect(progress.chronicle.crowns[2], 3);
    // Undone: the crowns go back.
    effects.undo!();
    expect(progress.chronicle.crowns.containsKey(2), isFalse);
    // A loss earns nothing.
    final lost = game(GameMode.chronicle)..chapter = 2;
    expect(mode.afterRound(lost, finish(lost, won: false), progress).crowns, 0);
  });

  test('The tutorial fixes each lesson’s tasks, deals its cards and scripts the courtiers', () {
    final mode = modeOf(GameMode.tutorial);
    for (var i = 0; i < lessons.length; i++) {
      final g = GameState()
        ..mode = GameMode.tutorial
        ..lesson = i
        ..players = [for (var s = 0; s < 3; s++) Player('P$s', colorValue: 0)];
      g.startRound(3, 1, setup: (rand) => mode.roundSetup(g, 3, rand));
      expect([for (final t in g.tasks) t.description], lessons[i].tasks);
      expect(g.round!.passing, isFalse);
      expect(g.round!.canPass(0), isFalse);
      expect(mode.riggedDeal(g)!.hands, lessons[i].deal().hands);
      final script = mode.script(g);
      expect(script.showsBetweenTricks, isFalse);
      expect(script.play!(0, 1), lessons[i].scripted(0, 1));
      expect(mode.roundLabel(g), 'lesson${i + 1}');
    }
  });

  test('A round’s result says how it went', () {
    final g = game(GameMode.free);
    expect(g.round!.result, isNull);
    final r = finish(g, won: false);
    expect(r.won, isFalse);
    expect(r.failed.single, g.tasks.first);
    expect(r.target, 6);
  });
}
