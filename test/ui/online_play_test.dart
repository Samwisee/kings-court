/// Multiplayer on the page: starting a room from setup, a friend's device
/// joining it, and the two playing a round through the room to the same
/// end; and the host's device playing the seat of a friend who drops.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/modes/modes.dart';
import 'package:kings_court/net/headless_table.dart';
import 'package:kings_court/net/online_table.dart';
import 'package:kings_court/platform/build_info.dart';
import 'package:kings_court/platform/sfx.dart';
import 'package:kings_court/ui/app.dart';
import 'package:kings_court/ui/table_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_rooms.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sfx.muteForTests = true;
    OnlineTable.backoff = (_) => Duration.zero;
  });
  tearDown(() {
    HomePageTestHooks.rooms = null;
    HomePageTestHooks.seed = null;
  });

  for (final drop in [false, true]) {
    testWidgets(
        drop
            ? 'When a friend drops, the host’s device plays their seat to the end'
            : 'A room started on the page plays a round with a friend’s device to the same end',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      HomePageTestHooks.fast();
      final rooms = FakeRooms();
      HomePageTestHooks.rooms = rooms.open;
      HomePageTestHooks.seed = 11;

      await tester.pumpWidget(const TheKingsCourtApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('New game'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Multiplayer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start a room'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Ann');
      await tester.tap(find.text('Open the room'));
      await tester.pumpAndSettle();

      // The lobby: the code to share, and you in the first seat.
      final code = rooms.rooms.keys.single;
      expect(find.text(code), findsOneWidget);
      expect(find.textContaining('Ann (you)'), findsOneWidget);
      final ben = await OnlineTable.join(rooms.open, Uri.parse('https://rooms.test'),
          code: code, session: 'ben', name: 'Ben', build: buildVersion);
      await tester.pumpAndSettle();
      expect(ben.seat, 1);
      expect(find.textContaining('Ben'), findsOneWidget);
      expect(find.text('A courtier'), findsNothing, reason: 'empty until the start');
      await tester.tap(find.text('Start'));
      await tester.pump();

      final state = tester.state<HomePageState>(find.byType(HomePage));
      final game = state.game;
      expect(game.digital, isTrue);
      expect(game.players.map((p) => p.name).take(2), ['You', 'Ben']);
      expect(ben.started, isTrue);

      final rules = modeOf(GameMode.free).rules;
      final gameB = ben.setup!.start(rules, you: ben.seat);
      final b = HeadlessTable(gameB, ben, rules,
          you: 1, seats: ben.seats, host: false, bot: Bot()..budget = 20);
      var thinking = false;
      var benMoves = 0;
      var dropped = false;
      for (var i = 0;
          i < 4000 &&
              (game.outcome == RoundOutcome.inProgress ||
                  (!dropped && gameB.outcome == RoundOutcome.inProgress));
          i++) {
        await tester.pump(const Duration(milliseconds: 30));
        if (find.text('Skip').evaluate().isNotEmpty) {
          await tester.tap(find.text('Skip'));
        } else if (find.text('So be it').evaluate().isNotEmpty) {
          await tester.tap(find.text('So be it'));
        } else if (find.text('Announce').evaluate().isNotEmpty) {
          await tester.tap(find.text('Announce'));
        } else if (find.text('Got it').evaluate().isNotEmpty) {
          await tester.tap(find.text('Got it').first);
        } else {
          state.debugYourMove();
        }
        // The friend's device, playing its own seat (once it's dropped,
        // it does nothing more).
        if (!thinking && !(drop && dropped)) {
          thinking = true;
          unawaited(b.playAs(1).then((moved) {
            thinking = false;
            if (moved) benMoves++;
          }));
        }
        if (drop && !dropped && benMoves >= 2 && !thinking) {
          dropped = true;
          await ben.leave();
          rooms.rooms[code]!.drop('ben');
        }
      }
      String where(GameState g) {
        final r = g.round!;
        return 'king ${r.king} pick ${r.pickTurn} owners ${[for (final t in r.tasks) t.owner]} '
            'x ${[for (final t in r.tasks) t.x]} tricks ${r.tricks.length} current ${r.current.length} '
            'turn ${r.turn} settled ${r.settled} outcome ${g.outcome}';
      }
      expect(game.outcome, isNot(RoundOutcome.inProgress),
          reason: 'page: ${where(game)}\nben: ${where(gameB)}\n'
              'ben pending ${b.pending} refused ${[for (final a in b.refused) a.toJson()]}\n'
              'room moves ${rooms.rooms[code]!.moves.length}, page has ${state.debugLink.history.length}, '
              'ben has ${ben.history.length}, ben moves $benMoves, thinking $thinking\n'
              'last moves ${rooms.rooms[code]!.moves.reversed.take(6).toList()}');
      if (drop) {
        expect(dropped, isTrue);
      } else {
        // The same round on both devices, but for how a failure is worded
        // to each ("You won trick 5" is "Ann won trick 5" to Ben).
        String round(GameState g) =>
            jsonEncode(g.round!.toJson()).replaceAll(RegExp(',"why":"[^"]*"'), '');
        expect(gameB.outcome, game.outcome);
        expect(round(gameB), round(game));
      }
      b.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
