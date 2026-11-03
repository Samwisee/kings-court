/// Signing in, with Google or a passkey (the service's auth.js). Playing
/// never needs an account: one keeps what a player owns and wears on
/// every device they sign in on. Still being built, so it's off unless the
/// page was opened with `?login=1` (kept until `?login=0`), and only on
/// the web, where the service is.
///
/// Google goes by whole-page redirect (the page is cross-origin isolated,
/// which breaks Google's pop-ups): off to Google and back to this page
/// with `?signin=<ticket>`, which [load] turns into a session. The session
/// is a token kept on the device and sent as `Authorization: Bearer`.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'game_log.dart';
import 'passkey.dart' if (dart.library.js_interop) 'passkey_web.dart' as native;
import 'service.dart';

/// The signed-in account, as the service has it.
@immutable
class Me {
  const Me({required this.id, required this.name, this.owns = const [], this.look, this.logins = const []});

  final String id;
  final String name;

  /// The looks bought (skin ids).
  final List<String> owns;

  /// The look worn, or null for whatever the device wears.
  final String? look;

  /// The ways in: 'google', 'passkey' (one each).
  final List<String> logins;

  bool get hasPasskey => logins.contains('passkey');
  bool get hasGoogle => logins.contains('google');

  static Me? fromJson(Object? j) {
    if (j is! Map) return null;
    return Me(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      owns: [for (final o in (j['owns'] as List? ?? const [])) '$o'],
      look: j['look'] as String?,
      logins: [for (final l in (j['logins'] as List? ?? const [])) if (l is Map) '${l['kind']}'],
    );
  }
}

abstract final class Account {
  /// Whether signing in is offered at all (see the library's note).
  static bool enabled = false;

  /// Who's signed in, or null.
  static final me = ValueNotifier<Me?>(null);

  /// Whether Google sign-in is set up on the service (passkeys always are).
  static bool google = false;

  /// The service, and how to reach it (tests swap both).
  @visibleForTesting
  static String service = serviceUrl;
  @visibleForTesting
  static http.Client client = http.Client();

  static String? _token;
  static SharedPreferences? _prefs;

  static const _enabledKey = 'kingsCourt.login';
  static const _tokenKey = 'kingsCourt.session';
  static const nameMax = 24;

  /// Whether this build could offer it: the web, with a service.
  static bool get possible => (kIsWeb || _testing) && service.isNotEmpty;
  static bool _testing = false;
  @visibleForTesting
  static set testing(bool v) => _testing = v;

  /// Whether the menu offers signing in.
  static bool get offered => enabled && possible;

  /// The switch and the session, as saved; `?login=` in [address] turns it
  /// on or off; `?signin=` back from Google finishes signing in. Returns
  /// what to tell the player, if anything ("Signed in as Ann").
  static Future<String?> load(SharedPreferences prefs, {Uri? address}) async {
    _prefs = prefs;
    final at = address ?? Uri.base;
    final flag = at.queryParameters['login'];
    if (flag == '1' || flag == '0') await prefs.setBool(_enabledKey, enabled = flag == '1');
    enabled = prefs.getBool(_enabledKey) ?? false;
    _token = prefs.getString(_tokenKey);
    final ticket = at.queryParameters['signin'];
    if (ticket != null) native.dropFromAddress('signin');
    if (!offered) return null;
    try {
      final config = await _get('/auth/config');
      google = config?['google'] == true;
      if (ticket == 'failed') return 'Couldn’t sign in with Google';
      if (ticket != null) {
        final err = await _signedIn(await _post('/auth/ticket', {'ticket': ticket, 'player': GameLog.player}));
        return err ?? 'Signed in as ${me.value!.name}';
      }
      if (_token != null) {
        final j = await _get('/me');
        if (j == null) {
          await _forget();
        } else {
          me.value = Me.fromJson(j);
        }
      }
    } catch (_) {
      // Offline: try again next time.
    }
    return null;
  }

  /// Off to Google; the page comes back signed in.
  static void signInWithGoogle() {
    final back = Uri.base.removeFragment();
    final rest = {...back.queryParameters}..remove('signin');
    final here = back.replace(queryParameters: rest.isEmpty ? null : rest).toString().replaceFirst(RegExp(r'\?$'), '');
    native.goTo('$service/auth/google/start?back=${Uri.encodeQueryComponent(here)}');
  }

  /// Whether this browser can use passkeys.
  static bool get passkeys => native.passkeysHere();

  /// A new account with a new passkey, named [name]; or, signed in, a
  /// passkey added to this account. Null when it worked, else why not.
  static Future<String?> makePasskey({String? name}) async {
    try {
      final begun = await _post('/auth/passkey/begin', const {});
      if (begun == null) return 'Couldn’t reach the game’s service';
      final shown = (me.value?.name ?? name ?? 'Courtier').trim();
      final made = await native.createPasskey(
          challenge: '${begun['challenge']}', user: '${begun['user']}', name: shown.isEmpty ? 'Courtier' : shown);
      if (made == null) return null == me.value ? 'No passkey was made' : 'No passkey was added';
      return _signedIn(await _post('/auth/passkey/create',
          {...made, 'id': begun['id'], 'name': name, 'player': GameLog.player}));
    } on native.PasskeyError catch (e) {
      return e.message;
    } catch (_) {
      return 'Couldn’t reach the game’s service';
    }
  }

  /// Signs in with a passkey made before. Null when it worked.
  static Future<String?> signInWithPasskey() async {
    try {
      final begun = await _post('/auth/passkey/begin', const {});
      if (begun == null) return 'Couldn’t reach the game’s service';
      final signed = await native.usePasskey(challenge: '${begun['challenge']}');
      if (signed == null) return 'No passkey was used';
      return _signedIn(await _post('/auth/passkey/sign', {...signed, 'id': begun['id'], 'player': GameLog.player}));
    } on native.PasskeyError catch (e) {
      return e.message;
    } catch (_) {
      return 'Couldn’t reach the game’s service';
    }
  }

  /// The name others see. Null when it worked.
  static Future<String?> rename(String name) async {
    try {
      final j = await _post('/me', {'name': name.trim()});
      if (j == null || j['error'] != null) return '${j?['error'] ?? 'Couldn’t save that'}';
      me.value = Me.fromJson(j);
      return null;
    } catch (_) {
      return 'Couldn’t reach the game’s service';
    }
  }

  static Future<void> signOut() async {
    try {
      if (_token != null) await _post('/auth/out', const {});
    } catch (_) {}
    await _forget();
  }

  static Future<void> _forget() async {
    _token = null;
    me.value = null;
    await _prefs?.remove(_tokenKey);
  }

  /// A session from the service's answer; null when it worked.
  static Future<String?> _signedIn(Map<String, dynamic>? j) async {
    if (j == null) return 'Couldn’t reach the game’s service';
    if (j['token'] is! String) return '${j['error'] ?? 'Couldn’t sign in'}';
    _token = j['token'] as String;
    await _prefs?.setString(_tokenKey, _token!);
    me.value = Me.fromJson(j['me']);
    return null;
  }

  static Map<String, String> get _headers =>
      {'Content-Type': 'application/json', if (_token != null) 'Authorization': 'Bearer $_token'};

  /// The answer as JSON, null when signed out (401) or unreachable.
  static Future<Map<String, dynamic>?> _get(String path) async {
    final r = await client.get(Uri.parse('$service$path'), headers: _headers).timeout(const Duration(seconds: 15));
    return r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic> : null;
  }

  /// The answer as JSON (errors too, as {error}).
  static Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    final r = await client
        .post(Uri.parse('$service$path'), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void reset() {
    enabled = google = false;
    _token = null;
    _prefs = null;
    me.value = null;
  }
}
