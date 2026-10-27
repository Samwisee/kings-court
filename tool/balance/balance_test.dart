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
    // How often each task fails itself at each table size.
    final dealtAt = {for (final p in [3, 4, 5, 6]) p: <String, int>{}};
    final failedAt = {for (final p in [3, 4, 5, 6]) p: <String, int>{}};
    final configs = [
      for (final p in [3, 4, 5, 6])
        for (final t in [5, 8, 11, 14, 17, 20]) (p, t)
    ];
    final byConfig = {for (final c in configs) c: _Tally()};
    final tasksIn = {for (final c in configs) c: 0};
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
      tasksIn[(p, t)] = tasksIn[(p, t)]! + tasks.length;
      for (final f in failed) {
        failedCount[f] = (failedCount[f] ?? 0) + 1;
      }
      for (final d in tasks) {
        dealtAt[p]![d] = (dealtAt[p]![d] ?? 0) + 1;
      }
      for (final f in failed) {
        failedAt[p]![f] = (failedAt[p]![f] ?? 0) + 1;
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
      ..writeln('players  target  rounds  won  tasks (average)');
    for (final c in configs) {
      final t = byConfig[c]!;
      out.writeln('${'${c.$1}'.padLeft(7)}  ${'${c.$2}'.padLeft(6)}  ${'${t.rounds}'.padLeft(6)}  ${t.pct}  '
          '${(tasksIn[c]! / max(1, t.rounds)).toStringAsFixed(1)}');
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
    // Points from difficulty. A task's points are its share of how hard
    // the round is: -ln(chance it succeeds), scaled, so tasks that each
    // succeed half the time add up the same however they're combined.
    // Each table size is pulled toward the task's overall rate when it was
    // dealt only a few times there.
    final pool = {for (final t in GameState.taskPool) t.description: t};
    const k = 2.4, prior = 25;
    int pointsFor(double fail) =>
        (k * -log(max(0.02, 1 - fail))).round().clamp(1, 7);
    double overall(String d) {
      var n = 0, f = 0;
      for (final p in [3, 4, 5, 6]) {
        n += dealtAt[p]![d] ?? 0;
        f += failedAt[p]![d] ?? 0;
      }
      return n == 0 ? 0.5 : f / n;
    }

    double rateAt(String d, int p) {
      final n = dealtAt[p]![d] ?? 0, f = failedAt[p]![d] ?? 0;
      return (f + prior * overall(d)) / (n + prior);
    }

    out
      ..writeln()
      ..writeln('POINTS FROM DIFFICULTY (3 / 4 / 5 / 6 players): fail rate, points now, points suggested')
      ..writeln('(! = 2 or more off at some table size)');
    final names = pool.keys.toList()
      ..sort((a, b) => overall(a).compareTo(overall(b)));
    for (final d in names) {
      final t = pool[d]!;
      final now = [t.threePlayerPoints, t.fourPlayerPoints, t.fivePlayerPoints, t.sixPlayerPoints];
      final want = [for (final p in [3, 4, 5, 6]) pointsFor(rateAt(d, p))];
      final off = [for (int i = 0; i < 4; i++) (now[i] - want[i]).abs()].reduce(max) >= 2;
      out.writeln('${'${(overall(d) * 100).round()}%'.padLeft(4)}  ${now.join('/')}  ->  ${want.join('/')} ${off ? '!' : ' '} $d');
    }
    out
      ..writeln()
      ..writeln('SUGGESTED POINTS, ready to paste: description | three | four | five | six');
    for (final d in pool.keys) {
      final want = [for (final p in [3, 4, 5, 6]) pointsFor(rateAt(d, p))];
      out.writeln('POINTS|$d|${want.join('|')}');
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
