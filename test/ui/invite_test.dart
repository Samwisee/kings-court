/// Invite links: what they look like, the code they carry, and opening
/// the game from one straight into the room's join step; and the lobby's
/// invite, copied where there's no share sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/game/setup.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/modes/modes.dart';
import 'package:kings_court/net/headless_table.dart';
import 'package:kings_court/net/online_table.dart';
import 'package:kings_court/platform/build_info.dart';
import 'package:kings_court/platform/invite.dart';
import 'package:kings_court/platform/sfx.dart';
import 'package:kings_court/ui/app.dart';
import 'package:kings_court/ui/table_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_rooms.dart';

void main() {
  final service = Uri.parse('https://rooms.test');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sfx.muteForTests = true;
    OnlineTable.backoff = (_) => Duration.zero;
  });
  tearDown(() {
    HomePageTestHooks.rooms = null;
    HomePageTestHooks.address = null;
  });

  test('An invite link carries the room, beside the game, and is read back', () {
    final game = Uri.parse('https://samwisee.github.io/kings-court/#/');
    final link = inviteLink('ABCD', game);
    expect(link.toString(), 'https://samwisee.github.io/kings-court/?room=ABCD');
    expect(invitedRoom(link), 'ABCD');
    expect(invitedRoom(Uri.parse('https://x/?room=abcd')), 'ABCD', reason: 'typed in lower case');
    expect(invitedRoom(Uri.parse('https://x/?room=AB1')), isNull, reason: 'not a code');
    expect(invitedRoom(game), isNull);
  });

  testWidgets('Opening the game from an invite goes straight to joining that room', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    HomePageTestHooks.fast();
    final rooms = FakeRooms();
    HomePageTestHooks.rooms = rooms.open;
    final setup = GameSetup(
        mode: GameMode.free, names: const ['A', 'B', 'C'], target: 4, seed: 9, digital: true);
    final ann = await OnlineTable.create(rooms.open, service,
        setup: setup, session: 'ann', name: 'Ann', build: buildVersion);
    HomePageTestHooks.address = inviteLink(ann.code, Uri.parse('https://x/kings-court/'));

    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    expect(find.text('Join a room'), findsOneWidget);
    expect(find.text(ann.code), findsOneWidget, reason: 'the code filled in');
    await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Ben');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ben (you)'), findsOneWidget);
    expect(ann.names.values, contains('Ben'));

    // The lobby's invite: no share sheet here, so the link is copied.
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    await tester.tap(find.text('Invite friends'));
    await tester.pumpAndSettle();
    expect(find.text('Invite link copied'), findsOneWidget);
    expect(copied, contains('?room=${ann.code}'));

    // The host starts: the game is on the table, Ben in his seat.
    final a = HeadlessTable(setup.start(modeOf(GameMode.free).rules), ann, modeOf(GameMode.free).rules,
        you: 0, seats: ann.seats, bot: Bot()..budget = 10);
    ann.start();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    final state = tester.state<HomePageState>(find.byType(HomePage));
    expect(state.game.digital, isTrue);
    expect(state.game.players[1].name, 'You');
    expect(state.game.players[0].name, 'Ann');
    a.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
