// The balance report: the bots play many rounds at each table size and
// point target, and we count how often they win, overall and with each
// task on the table. The bots play fair, seeing only their own hand, as
// they do in the game, so a task or pairing they rarely win with is hard
// for people too (BALANCE_OMNISCIENT=1 gives all-seeing bots, the old
// best-case numbers).
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

import 'play_round.dart';

class _Tally {
  int rounds = 0, wins = 0;
  double get rate => rounds == 0 ? 0 : wins / rounds;
  void add(bool won) {
    rounds++;
    if (won) wins++;
  }

  String get pct => '${(rate * 100).toStringAsFixed(0).padLeft(3)}%';
}

bool precise(String d) => tierOf(d) == TaskTier.precise;

void main() {
  test('Balance report', () {
    final seconds = int.tryParse(Platform.environment['BALANCE_SECONDS'] ?? '') ?? 60;
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    final rand = Random(2026);
    // The same thinking as the bots in the game: fair, seeing only their
    // own hand (BALANCE_OMNISCIENT=1 lets them see every card instead).
    final bot = Bot(rand)
      ..budget = int.tryParse(Platform.environment['BALANCE_BUDGET'] ?? '') ?? 900
      ..omniscient = Platform.environment['BALANCE_OMNISCIENT'] == '1';
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
      ..writeln('$n rounds, ${bot.omniscient ? 'bots see every card (best case)' : 'bots see only their own hand (fair, as in the game)'}, ${bot.budget} playouts per decision.')
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
    const prior = 25;
    double hardness(double fail) => -log(max(0.02, 1 - fail));
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

    // The scale: at each table size, the average task keeps the average
    // points it has now, so the points targets mean what they did.
    List<int> nowOf(String d) {
      final t = pool[d]!;
      return [t.threePlayerPoints, t.fourPlayerPoints, t.fivePlayerPoints, t.sixPlayerPoints];
    }

    final scale = <int, double>{};
    for (final (i, p) in [3, 4, 5, 6].indexed) {
      final pts = pool.keys.map((d) => nowOf(d)[i]).reduce((a, b) => a + b);
      final hard = pool.keys.map((d) => hardness(rateAt(d, p))).reduce((a, b) => a + b);
      scale[p] = pts / hard;
    }
    int pointsFor(String d, int p) =>
        (scale[p]! * hardness(rateAt(d, p))).round().clamp(1, 7);
    out
      ..writeln()
      ..writeln('POINTS SCALE (points per unit of hardness, -ln(chance of success)): '
          '${[for (final p in [3, 4, 5, 6]) '$p: ${scale[p]!.toStringAsFixed(2)}'].join(', ')}');

    out
      ..writeln()
      ..writeln('POINTS FROM DIFFICULTY (3 / 4 / 5 / 6 players): fail rate, points now, points suggested')
      ..writeln('(! = 2 or more off at some table size)');
    final names = pool.keys.toList()
      ..sort((a, b) => overall(a).compareTo(overall(b)));
    for (final d in names) {
      final now = nowOf(d);
      final want = [for (final p in [3, 4, 5, 6]) pointsFor(d, p)];
      final off = [for (int i = 0; i < 4; i++) (now[i] - want[i]).abs()].reduce(max) >= 2;
      final rates = [for (final p in [3, 4, 5, 6]) '${(rateAt(d, p) * 100).round()}'].join('/');
      out.writeln('${rates.padLeft(11)}%  ${now.join('/')}  ->  ${want.join('/')} ${off ? '!' : ' '} $d');
    }
    out
      ..writeln()
      ..writeln('SUGGESTED POINTS, ready to paste: description | three | four | five | six');
    for (final d in pool.keys) {
      final want = [for (final p in [3, 4, 5, 6]) pointsFor(d, p)];
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
