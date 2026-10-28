/// How long the page takes to rebuild in the middle of an on-screen round,
/// where every change (a card played, a bot's turn, a drag) rebuilds the
/// whole page. Printed as BENCH lines, published with the screenshots.
@Tags(['tool'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/ui/app.dart';
import 'package:kings_court/ui/table_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('page rebuild timings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    HomePageTestHooks.fast();
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Single player'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Free play'));
    await tester.tap(find.text('Free play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();
    if (find.text('Next').evaluate().isNotEmpty) await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    for (var i = 0; i < 600 && find.text('Skip').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    final state = tester.state<HomePageState>(find.byType(HomePage));

    Future<double> time(String what, void Function() change, {int times = 20}) async {
      // One warm-up, then the average of [times] frames.
      change();
      await tester.pump();
      final sw = Stopwatch()..start();
      for (var i = 0; i < times; i++) {
        change();
        await tester.pump();
      }
      sw.stop();
      final ms = sw.elapsedMicroseconds / times / 1000;
      // The timings are the output: printed, for CI to collect.
      // ignore: avoid_print
      print('BENCH $what: ${ms.toStringAsFixed(1)} ms a frame');
      return ms;
    }

    // Warm up first, so the first number isn't the slowest for being first.
    for (var i = 0; i < 20; i++) {
      state.setState(() {});
      await tester.pump();
    }
    await time('a change to the game (setState)', () => state.setState(() {}));
    final whole = await time('a change to the screen only (_ui)', () => state.debugUi(() {}));
    await time('a frame with nothing changed', () {});

    // The frame's phases on their own: building widgets, laying them out
    // and recording the paint (what the framework does), apart from
    // rasterising, which the test harness does on the CPU at 3x and a
    // phone's GPU does for next to nothing.
    Future<void> phases(String what) async {
      final binding = tester.binding;
      double build = 0, layout = 0, paint = 0;
      const n = 20;
      for (var i = 0; i < n; i++) {
        state.debugUi(() {});
        final sw = Stopwatch()..start();
        binding.buildOwner!.buildScope(binding.rootElement!);
        build += sw.elapsedMicroseconds;
        sw.reset();
        binding.rootPipelineOwner.flushLayout();
        binding.rootPipelineOwner.flushCompositingBits();
        layout += sw.elapsedMicroseconds;
        sw.reset();
        binding.rootPipelineOwner.flushPaint();
        paint += sw.elapsedMicroseconds;
        await tester.pump();
      }
      // The timings are the output: printed, for CI to collect.
      // ignore: avoid_print
      print('BENCH $what: build ${(build / n / 1000).toStringAsFixed(1)} ms, '
          'layout ${(layout / n / 1000).toStringAsFixed(1)} ms, '
          'paint ${(paint / n / 1000).toStringAsFixed(1)} ms');
    }

    await phases('the framework\'s work a frame');
    // What each part of the page costs: the frame without it.
    for (final part in ['table', 'hand', 'bar', 'trim']) {
      HomePageTestHooks.skip = {part};
      state.debugUi(() {});
      await tester.pump();
      final without = await time('  without the $part', () => state.debugUi(() {}));
      // The timings are the output: printed, for CI to collect.
      // ignore: avoid_print
      print('BENCH  so the $part costs about ${(whole - without).toStringAsFixed(1)} ms');
      await phases('  without the $part');
    }
    HomePageTestHooks.skip = {};
    // What a change to the game does besides the rebuild.
    final work = <String, double>{};
    for (var i = 0; i < 20; i++) {
      final w = state.debugGameWork();
      w.forEach((k, v) => work[k] = (work[k] ?? 0) + v / 20);
    }
    work.forEach((k, v) {
      // The timings are the output: printed, for CI to collect.
      // ignore: avoid_print
      print('BENCH  after a change, $k: ${v.toStringAsFixed(2)} ms');
    });
  });
}
