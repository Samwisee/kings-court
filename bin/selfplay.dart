/// The headless runner: the courtiers play round after round with no
/// screen, on every core, and every round goes to a JSON-lines file in
/// the shape the game sends (lib/platform/game_log.dart), with the run's
/// own details under "selfplay" (lib/sim/self_play.dart).
///
/// Each seed deals one round, and it's played at every rung of strength
/// asked for, so the rungs can be compared on the same deals. A run picks
/// up after the last seed in its file, so it can be stopped (Ctrl-C) and
/// started again. Make the report with tool/selfplay/curves.py.
///
///     dart run bin/selfplay.dart --minutes 60
///     dart run bin/selfplay.dart --minutes 480 --rungs usual,fixed --teach
///
/// Options (all optional):
///   --minutes N      how long to play (default 10), or
///   --seeds N        how many seeds to play
///   --rungs a,b,...  the strengths to play each deal at
///                    (default weak,casual,usual,strong,seeing; also fixed:
///                    the usual courtiers without adaptive thinking)
///   --players 3,4,5  the table sizes (default 3,4,5)
///   --targets 5,8,.. the points targets (default 5,8,11,14,17)
///   --workers N      how many cores to use (default all)
///   --out FILE       where rounds go (default selfplay/rounds.jsonl)
///   --teach          also asks an all-seeing courtier every card play, and
///                    writes where it would have played another card to
///                    selfplay/disagreements.jsonl (each card play thought
///                    about twice: slower)
///   --from SEED      the first seed (default: after the file's last)
///
/// For a faster run, compile it first:
///     dart compile exe bin/selfplay.dart -o selfplay/run && selfplay/run --minutes 60
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:kings_court/sim/self_play.dart';

class _Job {
  _Job(this.port, this.worker, this.workers, this.from, this.until, this.deadline, this.players, this.targets,
      this.rungs, this.teach);
  final SendPort port;
  final int worker, workers, from, until, deadline;
  final List<int> players, targets;
  final List<String> rungs;
  final bool teach;
}

/// One worker: every [workers]-th seed from [from] + its number, until the
/// seeds or the time run out. Sends each round's record (and each
/// disagreement, marked 'D') as a line, then null.
void _work(_Job job) {
  final rungs = [for (final r in job.rungs) rungNamed(r)];
  for (var seed = job.from + job.worker; seed < job.until; seed += job.workers) {
    if (DateTime.now().millisecondsSinceEpoch > job.deadline) break;
    final pick = Random(seed ^ 0x2545F491);
    final players = job.players[pick.nextInt(job.players.length)];
    final target = job.targets[pick.nextInt(job.targets.length)];
    for (final rung in rungs) {
      final (record, disagreements) = selfPlay(seed, players, target, rung, teach: job.teach);
      job.port.send(jsonEncode(record));
      for (final d in disagreements) {
        job.port.send('D${jsonEncode(d)}');
      }
    }
  }
  job.port.send(null);
}

String? _option(List<String> args, String name) {
  final i = args.indexOf('--$name');
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

List<int> _ints(String? s, List<int> otherwise) =>
    s == null ? otherwise : [for (final p in s.split(',')) int.parse(p.trim())];

/// The seed after the last one in [file] (0 when there's none).
Future<int> _resumeAfter(File file) async {
  if (!file.existsSync()) return 0;
  var last = -1;
  final seed = RegExp(r'"seed":(\d+)');
  await for (final line in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
    final m = seed.firstMatch(line);
    if (m != null) last = max(last, int.parse(m.group(1)!));
  }
  // The last seed may have stopped part way through its rungs: it's played
  // again from the next one on, and the report uses only seeds with every
  // rung.
  return last + 1;
}

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('See the notes at the top of bin/selfplay.dart.');
    return;
  }
  final minutes = double.tryParse(_option(args, 'minutes') ?? '');
  final seeds = int.tryParse(_option(args, 'seeds') ?? '');
  final rungs = (_option(args, 'rungs') ?? 'weak,casual,usual,strong,seeing').split(',');
  rungs.forEach(rungNamed);
  final players = _ints(_option(args, 'players'), [3, 4, 5]);
  final targets = _ints(_option(args, 'targets'), [5, 8, 11, 14, 17]);
  final workers = int.tryParse(_option(args, 'workers') ?? '') ?? Platform.numberOfProcessors;
  final out = File(_option(args, 'out') ?? 'selfplay/rounds.jsonl');
  final teach = args.contains('--teach');
  final taught = File('${out.parent.path}/disagreements.jsonl');
  out.parent.createSync(recursive: true);

  final from = int.tryParse(_option(args, 'from') ?? '') ?? await _resumeAfter(out);
  final until = seeds == null ? 1 << 40 : from + seeds;
  final deadline = DateTime.now()
      .add(minutes == null && seeds != null ? const Duration(days: 365) : Duration(seconds: ((minutes ?? 10) * 60).round()))
      .millisecondsSinceEpoch;

  stdout.writeln('Playing from seed $from on $workers cores, at ${rungs.join(', ')}; '
      '${seeds != null ? '$seeds seeds' : '${minutes ?? 10} minutes'}. Rounds go to ${out.path}'
      '${teach ? ', disagreements to ${taught.path}' : ''}. Ctrl-C stops (what\'s played is kept).');

  final sink = out.openWrite(mode: FileMode.append);
  final teachSink = teach ? taught.openWrite(mode: FileMode.append) : null;
  final inbox = ReceivePort();
  final clock = Stopwatch()..start();
  var rounds = 0, disagreements = 0, running = workers;
  final wins = <String, int>{}, played = <String, int>{};

  var finished = false;
  Future<void> finish() async {
    if (finished) return;
    finished = true;
    inbox.close();
    await sink.flush();
    await sink.close();
    await teachSink?.flush();
    await teachSink?.close();
    final mins = clock.elapsed.inSeconds / 60;
    stdout.writeln('\n$rounds rounds in ${mins.toStringAsFixed(1)} minutes'
        '${teach ? ', $disagreements disagreements' : ''}.');
    for (final r in rungs) {
      final n = played[r] ?? 0;
      if (n > 0) stdout.writeln('  $r: ${(100 * (wins[r] ?? 0) / n).toStringAsFixed(1)}% won of $n');
    }
  }

  StreamSubscription<ProcessSignal>? stop;
  stop = ProcessSignal.sigint.watch().listen((_) async {
    await stop?.cancel();
    await finish();
    exit(0);
  });

  final progress = Timer.periodic(const Duration(seconds: 30), (_) {
    final perMin = rounds / max(1, clock.elapsed.inSeconds) * 60;
    stdout.writeln('${clock.elapsed.inMinutes} min: $rounds rounds (${perMin.toStringAsFixed(0)} a minute)');
  });

  for (var w = 0; w < workers; w++) {
    await Isolate.spawn(
        _work, _Job(inbox.sendPort, w, workers, from, until, deadline, players, targets, rungs, teach));
  }
  await for (final message in inbox) {
    if (message == null) {
      if (--running == 0) break;
      continue;
    }
    final line = message as String;
    if (line.startsWith('D')) {
      teachSink?.writeln(line.substring(1));
      disagreements++;
      continue;
    }
    sink.writeln(line);
    rounds++;
    final rung = RegExp(r'"rung":"(\w+)"').firstMatch(line)?.group(1) ?? '?';
    played[rung] = (played[rung] ?? 0) + 1;
    if (line.contains('"outcome":"won"')) wins[rung] = (wins[rung] ?? 0) + 1;
  }
  progress.cancel();
  await stop.cancel();
  await finish();
}
