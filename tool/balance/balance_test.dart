// The balance report: the bots play many rounds at each table size and
// point target, and we count how often they win, overall and with each
// task on the table. The bots see every card, so these are best-case
// numbers: a task or pairing the bots rarely win with is close to
// impossible for people.
//
// Run with: flutter test tool/balance/balance_test.dart
// BALANCE_SECONDS sets how long to play for (default 60).
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/conflicts.dart';
import 'package:kings_court/engine/deal_mix.dart';
import 'package:kings_court/engine/match.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/models.dart';

class _Tally {
  int rounds = 0, wins = 0;
  double get rate => rounds == 0 ? 0 : wins / rounds;
  void add(bool won) {
    rounds++;
    if (won) wins++;
  }

  String get pct => '${(rate * 100).toStringAsFixed(0).padLeft(3)}%';
}

/// Plays one round with bots; returns whether it was won, which tasks
/// failed, and the tasks dealt.
(bool, List<String>, List<String>) playRound(int players, int target, Random rand, Bot bot) {
  final g = GameState()..addTasksUntilTarget(players, target);
  final s = MatchState(players: players, target: target);
  s.dealFor(1, rand,
      accept: (hands, inPlay) =>
          g.tasks.every((t) => playableWith(t.description, hands, inPlay)));
  s.tasks = [for (final t in g.tasks) MatchTask(t.freshCopy()..seal = null)];
  final dealt = [for (final t in s.tasks) t.description];
  // Nobody takes two tasks that work against each other (as in the game).
  s.takeRule = (task, seat) => !s.tasks.any((o) =>
      o.owner == seat &&
      selfClash(o.description, s.tasks[task].description, players: players));
  s.pickTurn = s.king;
  s.phase = Phase.picking;
  var guard = 0;
  while (s.phase != Phase.roundOver && guard++ < 400) {
    switch (s.phase) {
      case Phase.picking:
        final seat = s.pickTurn!;
        final options = [
          for (int i = 0; i < s.tasks.length; i++)
            if (s.canTake(i, seat)) i
        ];
        if (options.isEmpty) {
          // Stuck: nobody may take what's left. Counts as a loss.
          return (false, ['(no one could take a task)'], dealt);
        }
        s.apply(PickTask(seat, bot.choosePick(s, seat)));
      case Phase.announcing:
        final i =
            s.tasks.indexWhere((t) => needsX(t.description) && t.x == null);
        s.apply(Announce(s.tasks[i].owner!, i, bot.chooseX(s, s.tasks[i].owner!, i)));
      case Phase.playing:
        s.apply(PlayCard(s.turn, bot.choosePlay(s, s.turn)));
      case Phase.roundOver:
        break;
    }
  }
  final v = s.view;
  final failed = [
    for (final t in s.tasks)
      if (t.owner != null &&
          taskRules[t.description]!(v, t.owner!, t.x) != Verdict.done)
        t.description
  ];
  return (s.won ?? false, failed, dealt);
}

bool precise(String d) => tierOf(d) == TaskTier.precise;

void main() {
  test('Balance report', () {
    final seconds = int.tryParse(Platform.environment['BALANCE_SECONDS'] ?? '') ?? 60;
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    final rand = Random(2026);
    // The same thinking time as the bots in the game.
    final bot = Bot(rand)
      ..budget = int.tryParse(Platform.environment['BALANCE_BUDGET'] ?? '') ?? 900;
    // How often each task fails itself at four players, against its points.
    final dealt4 = <String, int>{}, failed4 = <String, int>{};
    final configs = [
      for (final p in [3, 4, 5])
        for (final t in [6, 10, 14, 18, 22]) (p, t)
    ];
    final byConfig = {for (final c in configs) c: _Tally()};
    final byPrecise = <int, _Tally>{};
    final byTaskCount = <int, _Tally>{};
    final byTask = <String, _Tally>{};
    final failedCount = <String, int>{};
    final byPair = <String, _Tally>{};
    var n = 0;
    while (DateTime.now().isBefore(deadline)) {
      final (p, t) = configs[n++ % configs.length];
      // Same draw as the game, then played out.
      final (won, failed, tasks) = playRound(p, t, rand, bot);
      byConfig[(p, t)]!.add(won);
      for (final f in failed) {
        failedCount[f] = (failedCount[f] ?? 0) + 1;
      }
      if (p == 4) {
        for (final d in tasks) {
          dealt4[d] = (dealt4[d] ?? 0) + 1;
        }
        for (final f in failed) {
          failed4[f] = (failed4[f] ?? 0) + 1;
        }
      }
      byPrecise.putIfAbsent(tasks.where(precise).length.clamp(0, 2), _Tally.new).add(won);
      byTaskCount.putIfAbsent(tasks.length, _Tally.new).add(won);
      for (final d in tasks) {
        byTask.putIfAbsent(d, _Tally.new).add(won);
      }
      for (int i = 0; i < tasks.length; i++) {
        for (int j = i + 1; j < tasks.length; j++) {
          final k = ([tasks[i], tasks[j]]..sort()).join('  +  ');
          byPair.putIfAbsent(k, _Tally.new).add(won);
        }
      }
    }
    final out = StringBuffer()
      ..writeln('BALANCE REPORT  ${DateTime.now().toUtc()}')
      ..writeln('$n rounds, bots see every card (best case), ${bot.budget} playouts per decision.')
      ..writeln()
      ..writeln('WIN RATE BY TABLE SIZE AND TARGET')
      ..writeln('players  target  rounds  won');
    for (final c in configs) {
      final t = byConfig[c]!;
      out.writeln('${'${c.$1}'.padLeft(7)}  ${'${c.$2}'.padLeft(6)}  ${'${t.rounds}'.padLeft(6)}  ${t.pct}');
    }
    out
      ..writeln()
      ..writeln('WIN RATE BY NUMBER OF PRECISE TASKS (exactly / only / same / as many)');
    for (final k in byPrecise.keys.toList()..sort()) {
      out.writeln('${k == 2 ? '2+' : '$k '}  ${byPrecise[k]!.pct}  (${byPrecise[k]!.rounds} rounds)');
    }
    out
      ..writeln()
      ..writeln('WIN RATE BY NUMBER OF TASKS');
    for (final k in byTaskCount.keys.toList()..sort()) {
      out.writeln('${'$k'.padLeft(2)}  ${byTaskCount[k]!.pct}  (${byTaskCount[k]!.rounds} rounds)');
    }
    out
      ..writeln()
      ..writeln('TASKS, HARDEST FIRST: round win rate with it on the table, times it was dealt, times it failed itself')
      ..writeln('(task dealt fewer than 6 times are left out)');
    final tasks = byTask.entries.where((e) => e.value.rounds >= 6).toList()
      ..sort((a, b) => a.value.rate.compareTo(b.value.rate));
    for (final e in tasks) {
      out.writeln('${e.value.pct}  ${'${e.value.rounds}'.padLeft(4)}  fail ${'${failedCount[e.key] ?? 0}'.padLeft(3)}  ${e.key}');
    }
    // Points from difficulty: rank the tasks by how often they fail
    // themselves, and hand out the game's own spread of points in that
    // order. Tasks far from their suggestion are mispriced.
    final pool = {for (final t in GameState.taskPool) t.description: t.fourPlayerPoints};
    final rated = [
      for (final e in dealt4.entries)
        if (e.value >= 20 && pool.containsKey(e.key))
          (e.key, (failed4[e.key] ?? 0) / e.value)
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final spread = [for (final t in rated) pool[t.$1]!]..sort();
    out
      ..writeln()
      ..writeln('POINTS CHECK AT FOUR PLAYERS: how often a task fails itself, its points, and')
      ..writeln('the points its difficulty suggests (! = 2 or more off)')
      ..writeln('fails  dealt  pts  suggest');
    for (int i = 0; i < rated.length; i++) {
      final (d, rate) = rated[i];
      final now = pool[d]!, want = spread[i];
      out.writeln('${'${(rate * 100).round()}%'.padLeft(5)}  ${'${dealt4[d]}'.padLeft(5)}  '
          '${'$now'.padLeft(3)}  ${'$want'.padLeft(3)} ${(now - want).abs() >= 2 ? '!' : ' '}  $d');
    }
    out
      ..writeln()
      ..writeln('WORST PAIRS (dealt together at least 30 times)');
    final pairs = byPair.entries.where((e) => e.value.rounds >= 30).toList()
      ..sort((a, b) => a.value.rate.compareTo(b.value.rate));
    for (final e in pairs.take(25)) {
      out.writeln('${e.value.pct}  ${'${e.value.rounds}'.padLeft(3)}  ${e.key}');
    }
    final dir = Directory('tool/balance/out')..createSync(recursive: true);
    File('${dir.path}/report.txt').writeAsStringSync(out.toString());
    // ignore: avoid_print
    print(out);
  }, timeout: const Timeout(Duration(minutes: 40)));
}
