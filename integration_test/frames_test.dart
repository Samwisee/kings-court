/// The frame benchmark: the game run as players run it, in Chrome, with
/// every animation it has played at its own speed, frame by frame. Each
/// scene (the front page, the walk in, the deal, picking tasks, tricks
/// flying to their piles, the tracker, the outcome, the menu, the Livery
/// page, a night sky's felt, changing skin) records how long every frame's
/// work took and how many screen refreshes went by without a new frame
/// (dropped frames). tool/frames/report.py turns it into frames.txt.
///
///     flutter drive --profile -d web-server \
///       --driver=test_driver/frames_driver.dart \
///       --target=integration_test/frames_test.dart
library;

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/ui/app.dart';
import 'package:kings_court/ui/menu/menu.dart';
import 'package:kings_court/ui/table_page.dart';
import 'package:kings_court/ui/widgets/character_token.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

/// Every frame of each scene: when it was due (the screen's refresh it
/// was drawn for) and how long its work took, start to finish.
class Frames {
  final _clock = Stopwatch()..start();
  _Scene? _now;
  final scenes = <_Scene>[];
  Duration? _begun;

  /// Starts watching: a callback at the start of every frame and one after
  /// it's drawn, which asks for the next frame, so frames come at every
  /// refresh and a slow one shows as a gap.
  void watch() {
    void begin(Duration _) {
      _begun = _clock.elapsed;
      _clearMeasures();
    }

    SchedulerBinding.instance.scheduleFrameCallback(begin);
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      final s = _now;
      if (s != null && _begun != null) {
        s.due.add(SchedulerBinding.instance.currentSystemFrameTimeStamp);
        final work = _clock.elapsed - _begun!;
        s.work.add(work);
        final named = _measures();
        s.measured += named.length;
        if (s.detail) {
          for (final e in named.entries) {
            s.totals[e.key] = (s.totals[e.key] ?? 0) + e.value;
          }
        }
        if (work.inMicroseconds > 12000 && s.slow.length < 12) {
          final top = named.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          s.slow.add('${(work.inMicroseconds / 1000).toStringAsFixed(1)} ms: '
              '${top.take(8).map((e) => '${e.key} ${e.value.toStringAsFixed(1)}').join(', ')}');
        }
      }
      _begun = null;
      SchedulerBinding.instance.scheduleFrameCallback(begin);
    });
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        _now?.engine.add(t.totalSpan);
      }
    });
  }

  /// What the browser measured since the last clear (Flutter's timeline
  /// in a profile build: build, layout, paint, and with the debugProfile
  /// flags each widget and render object): each name's own time, summed.
  static Map<String, double> _measures() {
    // Each measure's own time: its length less the measures inside it
    // (they nest, a widget's build holding its children's).
    final list = [
      for (final e in web.window.performance.getEntriesByType('measure').toDart) (e.name, e.startTime, e.startTime + e.duration)
    ]..sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : b.$3.compareTo(a.$3));
    final out = <String, double>{};
    final open = <(String, double, double)>[];
    final inner = <double>[];
    void close() {
      final m = open.removeLast();
      final kids = inner.removeLast();
      out[m.$1] = (out[m.$1] ?? 0) + math.max(0, (m.$3 - m.$2) - kids);
      if (inner.isNotEmpty) inner[inner.length - 1] += m.$3 - m.$2;
    }
    for (final m in list) {
      while (open.isNotEmpty && open.last.$3 <= m.$2) {
        close();
      }
      open.add(m);
      inner.add(0);
    }
    while (open.isNotEmpty) {
      close();
    }
    _clearMeasures();
    return out;
  }

  /// Only the measures: Flutter's timeline closes each event against the
  /// mark it opened with, so clearing marks mid-frame breaks every frame.
  static void _clearMeasures() => web.window.performance.clearMeasures();

  /// A line to the CI job's log server (port 9999), so how far the run got
  /// can be seen even if it hangs.
  static void log(String line) {
    try {
      web.window.fetch(
          'http://localhost:9999/log'.toJS,
          web.RequestInit(method: 'POST', mode: 'no-cors', body: line.toJS));
    } catch (_) {
      // No log server: nothing to tell.
    }
  }

  Future<void> scene(String name, Future<void> Function() run, {bool detail = false}) async {
    log('start $name');
    final s = _Scene(name)..detail = detail;
    // In detail, every widget's build and every render object's layout and
    // paint are timed too: slower, but it says where the time goes.
    debugProfileBuildsEnabled = detail;
    debugProfileLayoutsEnabled = detail;
    debugProfilePaintsEnabled = detail;
    _now = s;
    try {
      // A scene that hangs is stopped and reported, so the run still ends.
      await run().timeout(const Duration(seconds: 75));
    } catch (e, stack) {
      // A scene that goes wrong is reported, and the rest still run.
      s.error = '$e ${stack.toString().split('\n').take(6).join(' | ')}';
    }
    _now = null;
    debugProfileBuildsEnabled = false;
    debugProfileLayoutsEnabled = false;
    debugProfilePaintsEnabled = false;
    scenes.add(s);
    // ignore: avoid_print
    print('FRAMES ${s.line()}');
    log('done ${s.line()}');
  }
}

class _Scene {
  _Scene(this.name);
  final String name;
  String? error;
  int measured = 0;
  bool detail = false;

  /// In detail: each name's time, summed over the scene's frames.
  final totals = <String, double>{};
  final slow = <String>[];
  final due = <Duration>[];
  final work = <Duration>[];
  final engine = <Duration>[];

  static double _ms(Duration d) => d.inMicroseconds / 1000;

  static double _at(List<double> sorted, double q) =>
      sorted.isEmpty ? 0 : sorted[math.min(sorted.length - 1, (sorted.length * q).floor())];

  /// The refresh period: the commonest gap between frames.
  double get period {
    final gaps = [for (var i = 1; i < due.length; i++) _ms(due[i] - due[i - 1])]..sort();
    final p = _at(gaps, 0.25);
    return p > 4 ? p : 1000 / 60;
  }

  /// Refreshes that went by with no new frame.
  int get dropped {
    final p = period;
    var n = 0;
    for (var i = 1; i < due.length; i++) {
      n += math.max(0, (_ms(due[i] - due[i - 1]) / p).round() - 1);
    }
    return n;
  }

  double get worstGap {
    var w = 0.0;
    for (var i = 1; i < due.length; i++) {
      w = math.max(w, _ms(due[i] - due[i - 1]));
    }
    return w;
  }

  Map<String, Object> toJson() {
    final w = [for (final d in work) _ms(d)]..sort();
    final e = [for (final d in engine) _ms(d)]..sort();
    return {
      'name': name,
      if (error != null) 'error': error!,
      'frames': due.length,
      'period': double.parse(period.toStringAsFixed(2)),
      'dropped': dropped,
      'worstGap': double.parse(worstGap.toStringAsFixed(1)),
      'workP50': _at(w, 0.5),
      'workP90': _at(w, 0.9),
      'workP99': _at(w, 0.99),
      'workMax': w.isEmpty ? 0 : w.last,
      'over8': w.where((m) => m > 8).length,
      'over16': w.where((m) => m > 16).length,
      'engineP90': _at(e, 0.9),
      'engineMax': e.isEmpty ? 0 : e.last,
      // The slowest frames' work, for finding what they were.
      'measured': measured,
      if (detail)
        'totals': [
          for (final e in (totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(45))
            '${e.key} ${e.value.toStringAsFixed(0)}'
        ],
      'slow': slow,
      'slowest': [for (final m in w.reversed.take(5)) double.parse(m.toStringAsFixed(1))],
    };
  }

  String line() => toJson().toString();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Every animation, frame by frame', (tester) async {
    Frames.log('test begins');
    SharedPreferences.setMockInitialValues({});
    CharacterToken.loopUnderTest = true;
    HomePageTestHooks.seed = 7;
    final frames = Frames()..watch();

    Future<void> wait(int ms) => tester.binding.delayed(Duration(milliseconds: ms));
    Future<void> tap(Finder f, {int then = 900}) async {
      if (f.evaluate().isEmpty) {
        // ignore: avoid_print
        print('FRAMES missing $f');
        return;
      }
      await tester.tap(f.first, warnIfMissed: false);
      await wait(then);
    }

    await frames.scene('starting up', () async {
      await tester.pumpWidget(const TheKingsCourtApp());
      await wait(500);
    });
    await frames.scene('front page: the crown, the flourish, the glitter', () => wait(4000));

    await frames.scene('setup: its panels sliding in', () async {
      await tap(find.text('New game'), then: 1200);
      await tap(find.text('Single player'));
      await tap(find.text('Free play'));
      await tap(find.text('4'), then: 600);
      await tap(find.text('Next'));
    });

    final state = tester.state<HomePageState>(find.byType(HomePage, skipOffstage: false));
    await frames.scene('walk in, crowning the King, the deal', () async {
      await tap(find.text('Start'), then: 7000);
    });

    await frames.scene('picking tasks, in detail (slower: every widget timed)', () async {
      for (var i = 0; i < 6 && state.game.round?.pickTurn != null; i++) {
        state.debugYourMove();
        await wait(700);
      }
    }, detail: true);

    await frames.scene('picking tasks: tasks flying to their seats', () async {
      for (var i = 0; i < 120 && state.game.round?.pickTurn != null; i++) {
        state.debugYourMove();
        await wait(350);
      }
      await wait(1500);
    });

    await frames.scene('tricks: cards played, flown to the piles', () async {
      for (var i = 0; i < 40; i++) {
        state.debugYourMove();
        await wait(400);
      }
    });

    await frames.scene('the card tracker sliding in and out', () async {
      await tap(find.byTooltip('Card tracker'), then: 1500);
      // A tap on the felt above it puts it away.
      await tester.tapAt(const Offset(200, 60));
      await wait(1200);
    });

    await frames.scene('the rest of the round, the tasks judged, the outcome', () async {
      for (var i = 0; i < 150 && state.game.outcome == RoundOutcome.inProgress; i++) {
        state.debugYourMove();
        await wait(300);
      }
      await wait(4000);
    });

    await frames.scene('the menu opening and closing', () async {
      await tap(find.byTooltip('Menu'), then: 1200);
      final menu = find.byType(OrnateMenu);
      if (menu.evaluate().isNotEmpty) Navigator.of(tester.element(menu)).pop();
      await wait(900);
    });

    await frames.scene('the Livery page: opening, each tab, a choice in each', () async {
      state.debugMenuChoice('skin');
      await wait(1500);
      for (final (tab, kind) in [
        ('Faces', 'faces'),
        ('Court', 'court'),
        ('Backs', 'backs'),
        ('Tokens', 'tokens'),
        ('Tasks', 'tasks'),
        ('Style', 'style'),
      ]) {
        // The tab: the highest text of its name (a tile can share it).
        final named = find.text(tab).evaluate().toList();
        if (named.isNotEmpty) {
          named.sort((a, b) => tester.getCenter(find.byElementPredicate((e) => e == a)).dy
              .compareTo(tester.getCenter(find.byElementPredicate((e) => e == b)).dy));
          await tester.tap(find.byElementPredicate((e) => e == named.first), warnIfMissed: false);
          await wait(700);
        }
        final grid = find.byKey(ValueKey('look-grid-$kind'));
        final tiles = find.descendant(of: grid, matching: find.byType(Semantics));
        final n = tiles.evaluate().length;
        // The third and second tiles: each changes one part of the preview.
        for (final i in [2, 1]) {
          if (i < n) {
            await tester.tap(tiles.at(i), warnIfMissed: false);
            await wait(900);
          }
        }
        if (grid.evaluate().isEmpty) {
          final shown = [
            for (final e in find.byType(Text).evaluate())
              if ((e.widget as Text).data case final t?)
                '$t@${tester.getCenter(find.byElementPredicate((x) => x == e)).dy.round()}'
          ];
          throw StateError('no $kind grid; texts: ${shown.take(40).join(', ')}');
        }
        await tester.fling(grid, const Offset(0, -300), 1500, warnIfMissed: false);
        await wait(900);
        // And back, so the tabs are in reach again.
        await tester.fling(grid, const Offset(0, 600), 2500, warnIfMissed: false);
        await wait(700);
      }
    });

    await frames.scene('wearing the new look', () => tap(find.text('Done'), then: 2500));

    await frames.scene('the night sky\'s felt: stars twinkling, one shooting', () async {
      state.debugMenuChoice('skin');
      await wait(1200);
      await tap(find.text('Style'), then: 600);
      final grid = find.byKey(const ValueKey('look-grid-style'));
      final night = find.descendant(of: grid, matching: find.text('Midnight'));
      if (night.evaluate().isNotEmpty) await tap(night, then: 800);
      await tap(find.text('Done'), then: 8000);
    });

    await frames.scene('changing skin, five times', () async {
      for (var i = 0; i < 5; i++) {
        state.debugMenuChoice('nextLivery');
        await wait(1200);
      }
    });

    await frames.scene('back to the front page', () async {
      state.debugMenuChoice('main');
      await wait(3000);
    });

    await frames.scene('changing skin, in detail (slower: every widget timed)', () async {
      for (var i = 0; i < 2; i++) {
        state.debugMenuChoice('nextLivery');
        await wait(1500);
      }
    }, detail: true);

    Frames.log('tour over');
    binding.reportData = {'scenes': [for (final s in frames.scenes) s.toJson()]};
    CharacterToken.loopUnderTest = false;
  });
}
