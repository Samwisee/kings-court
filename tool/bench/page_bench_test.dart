/// How long the page takes to rebuild in the middle of an on-screen round,
/// where every change (a card played, a bot's turn, a drag) rebuilds the
/// whole page. Printed as BENCH lines, published with the screenshots.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/main.dart';
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
    for (int i = 0; i < 600 && find.text('Skip').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    // ignore: avoid_implicit_dynamic
    final state = tester.state(find.byType(HomePage)) as dynamic;

    Future<double> time(String what, void Function() change, {int times = 20}) async {
      // One warm-up, then the average of [times] frames.
      change();
      await tester.pump();
      final sw = Stopwatch()..start();
      for (int i = 0; i < times; i++) {
        change();
        await tester.pump();
      }
      sw.stop();
      final ms = sw.elapsedMicroseconds / times / 1000;
      // ignore: avoid_print
      print('BENCH $what: ${ms.toStringAsFixed(1)} ms a frame');
      return ms;
    }

    await time('a change to the game (setState)', () => state.setState(() {}));
    await time('a change to the screen only (_ui)', () => state.debugUi(() {}));
    await time('a frame with nothing changed', () {});
  });
}
