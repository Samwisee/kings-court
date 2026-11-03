/// Signing in (platform/account.dart, ui/dialogs/account_sheet.dart): off
/// unless ?login=1; Google's ticket becomes a session that's kept; the
/// sheet offers what's set up, renames, and signs out.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kings_court/platform/account.dart';
import 'package:kings_court/ui/dialogs/account_sheet.dart';
import 'package:kings_court/ui/menu/menu_entries.dart';
import 'package:shared_preferences/shared_preferences.dart';

const service = 'https://service.example';
final game = Uri.parse('https://kings-court-c8n.pages.dev/');

/// A pretend service: what was asked, and Ann's account.
final asked = <String>[];
var name = 'Ann';
http.Client fakeService({bool google = true}) => MockClient((r) async {
      final path = r.url.path;
      asked.add('${r.method} $path ${r.headers['authorization'] ?? ''}');
      final me = {'id': 'a1', 'name': name, 'owns': <String>[], 'look': null, 'logins': [{'kind': 'google'}]};
      return switch (path) {
        '/auth/config' => http.Response(jsonEncode({'google': google, 'passkey': true}), 200),
        '/auth/ticket' => (jsonDecode(r.body) as Map)['ticket'] == 't1'
            ? http.Response(jsonEncode({'token': 'tok', 'me': me}), 200)
            : http.Response(jsonEncode({'error': 'That sign-in had expired'}), 401),
        '/me' when r.method == 'GET' => r.headers['authorization'] == 'Bearer tok'
            ? http.Response(jsonEncode(me), 200)
            : http.Response('{}', 401),
        '/me' => http.Response(jsonEncode({...me, 'name': name = (jsonDecode(r.body) as Map)['name'] as String}), 200),
        '/auth/out' => http.Response('{"ok":true}', 200),
        _ => http.Response('{}', 404),
      };
    });

Future<SharedPreferences> prefs([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  return SharedPreferences.getInstance();
}

void main() {
  setUp(() {
    Account.reset();
    Account.testing = true;
    Account.service = service;
    Account.client = fakeService();
    asked.clear();
    name = 'Ann';
  });

  test('Off until ?login=1, which is kept until ?login=0; nothing is asked of the service while off', () async {
    final p = await prefs();
    await Account.load(p, address: game);
    expect(Account.offered, isFalse);
    expect(asked, isEmpty);
    await Account.load(p, address: game.replace(queryParameters: {'login': '1'}));
    expect(Account.offered, isTrue);
    await Account.load(p, address: game);
    expect(Account.offered, isTrue, reason: 'kept');
    await Account.load(p, address: game.replace(queryParameters: {'login': '0'}));
    expect(Account.offered, isFalse);
  });

  test('Back from Google with a ticket: signed in, and still signed in next time', () async {
    final p = await prefs({'kingsCourt.login': true});
    final said = await Account.load(p, address: game.replace(queryParameters: {'signin': 't1'}));
    expect(said, 'Signed in as Ann');
    expect(Account.me.value!.hasGoogle, isTrue);
    expect(Account.google, isTrue);

    Account.reset();
    final again = await Account.load(p, address: game);
    expect(again, isNull);
    expect(Account.me.value?.name, 'Ann');
    expect(asked.last, 'GET /me Bearer tok');
  });

  test('An expired ticket, or Google turning it down, says so', () async {
    final p = await prefs({'kingsCourt.login': true});
    expect(await Account.load(p, address: game.replace(queryParameters: {'signin': 'old'})), 'That sign-in had expired');
    expect(Account.me.value, isNull);
    expect(await Account.load(p, address: game.replace(queryParameters: {'signin': 'failed'})), 'Couldn’t sign in with Google');
  });

  test('A session the service no longer knows is forgotten', () async {
    final p = await prefs({'kingsCourt.login': true, 'kingsCourt.session': 'stale'});
    await Account.load(p, address: game);
    expect(Account.me.value, isNull);
    expect(p.getString('kingsCourt.session'), isNull);
  });

  test('The menu offers signing in only when it is on, by the name signed in as', () {
    List<String> titles(String? account) => [
          for (final e in menuEntries(mainMenu: false, shuffle: false, upright: null, look: 'Classic', keys: null, share: true, account: account))
            if (e.value == 'account') e.title
        ];
    expect(titles(null), isEmpty);
    expect(titles(''), ['Sign in']);
    expect(titles('Ann'), ['Ann']);
  });

  testWidgets('The sheet: Google when it is set up; signed in, a new name is saved and signing out signs out', (tester) async {
    final p = await tester.runAsync(() => prefs({'kingsCourt.login': true}));
    await tester.runAsync(() => Account.load(p!, address: game));
    await tester.pumpWidget(const MaterialApp(home: AccountSheet()));
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byKey(const ValueKey('signInGoogle')), findsOneWidget);
    // Off the web there are no passkeys to offer.
    expect(find.byKey(const ValueKey('signInPasskey')), findsNothing);

    await tester.runAsync(() => Account.load(p!, address: game.replace(queryParameters: {'signin': 't1'})));
    await tester.pumpAndSettle();
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('Signed in with Google.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('accountName')), 'Lady Ann');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('saveName')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(Account.me.value!.name, 'Lady Ann');
    expect(find.text('Saved'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('signOut')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(Account.me.value, isNull);
    expect(find.text('Sign in'), findsOneWidget);
    expect(asked.last, 'POST /auth/out Bearer tok');
  });

  testWidgets('Without Google or passkeys, the sheet says there is no way in here', (tester) async {
    Account.client = fakeService(google: false);
    final p = await tester.runAsync(() => prefs({'kingsCourt.login': true}));
    await tester.runAsync(() => Account.load(p!, address: game));
    await tester.pumpWidget(const MaterialApp(home: AccountSheet()));
    expect(find.byKey(const ValueKey('signInGoogle')), findsNothing);
    expect(find.text('This browser can’t use passkeys.'), findsOneWidget);
  });
}
