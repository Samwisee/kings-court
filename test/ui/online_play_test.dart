/// Multiplayer on the page: starting a room from setup, a friend's device
/// joining it, and the two playing a round through the room to the same
/// end; a friend leaving part-way, a courtier playing on; and someone
/// joining part-way, caught up, in the courtier's seat.
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
import 'package:kings_court/net/replay.dart';
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

  const names = {
    'together': 'A room started on the page plays a round with a friend’s device to the same end',
    'leaves': 'When a friend leaves part-way, a courtier plays their seat to the end',
    'joins': 'Someone joining part-way takes the courtier’s seat, caught up, and plays to the same end',
  };
  for (final story in names.keys) {
    testWidgets(names[story]!, (tester) async {
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
      final service = Uri.parse('https://rooms.test');
      final gameB = ben.setup!.start(rules, you: ben.seat);
      final b = HeadlessTable(gameB, ben, rules,
          you: 1, seats: ben.seats, host: false, bot: Bot()..budget = 20);
      OnlineTable? cal;
      HeadlessTable? c;
      String where(GameState g) {
        final r = g.round!;
        return 'king ${r.king} pick ${r.pickTurn} owners ${[for (final t in r.tasks) t.owner]} '
            'x ${[for (final t in r.tasks) t.x]} tricks ${r.tricks.length} current ${r.current.length} '
            'turn ${r.turn} settled ${r.settled} outcome ${g.outcome}';
      }

      // Each friend's device plays its own seat, a move at a time.
      final thinking = <HeadlessTable>{};
      var benMoves = 0;
      void play(HeadlessTable t, int seat) {
        if (!thinking.add(t)) return;
        unawaited(t.playAs(seat).then((moved) {
          thinking.remove(t);
          if (moved && t == b) benMoves++;
        }));
      }

      var benLeft = false;
      bool done(GameState g) => g.outcome != RoundOutcome.inProgress;
      for (var i = 0;
          i < 4000 &&
              !(done(game) && (benLeft || done(gameB)) && (c == null || done(c.game)));
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
        if (benMoves >= 1 && !thinking.contains(b)) {
          if (story == 'leaves' && !benLeft) {
            benLeft = true;
            // (Not awaited: a socket's close doesn't finish in a test's
            // made-up time.)
            unawaited(ben.leave());
          }
          if (story == 'joins' && cal == null) {
            cal = await OnlineTable.join(rooms.open, service,
                code: code, session: 'cal', name: 'Cal', build: buildVersion);
            expect(cal.seat, 2, reason: 'the courtier’s seat');
            // Caught up from the moves so far, and on from here.
            c = HeadlessTable(replay(cal.setup!, cal.history, rules: rules, you: 2), cal, rules,
                you: 2, seats: cal.seats, host: false, bot: Bot()..budget = 20);
            await tester.pump();
            expect(find.textContaining('Cal joined'), findsOneWidget);
            expect(game.players[2].name, 'Cal');
          }
        }
        if (!benLeft) play(b, 1);
        if (c != null) play(c, 2);
      }
      expect(done(game), isTrue,
          reason: 'page: ${where(game)}\nben: ${where(gameB)}\n'
              'room moves ${rooms.rooms[code]!.moves.length}, page has ${state.debugLink.history.length}, '
              'ben has ${ben.history.length}, ben moves $benMoves\n'
              'last moves ${rooms.rooms[code]!.moves.reversed.take(6).toList()}');
      // The same round on every device still there, but for how a failure
      // is worded to each ("You won trick 5" is "Ann won trick 5" to Ben).
      String round(GameState g) =>
          jsonEncode(g.round!.toJson()).replaceAll(RegExp(',"why":"[^"]*"'), '');
      if (story == 'leaves') {
        expect(benLeft, isTrue);
        expect(rooms.rooms[code]!.seats[1]['who'], 'courtier');
      } else {
        expect(round(gameB), round(game));
      }
      if (c != null) expect(round(c.game), round(game));
      b.dispose();
      c?.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
