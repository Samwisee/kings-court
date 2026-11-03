/// Passkeys in the browser (WebAuthn), and the page's address. What goes
/// to the service is what auth.js checks: the passkey's id, the browser's
/// clientDataJSON, the authenticator's data, and the public key (made) or
/// the signature (used), all base64url.
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class PasskeyError implements Exception {
  PasskeyError(this.message);
  final String message;
}

bool passkeysHere() => globalContext.has('PublicKeyCredential') && web.window.isSecureContext;

String _b64(JSArrayBuffer b) => base64Url.encode(b.toDart.asUint8List()).replaceAll('=', '');
JSUint8Array _bytes(String b64) => base64Url.decode(base64Url.normalize(b64)).toJS;

/// What the browser threw, in words; null when the player just cancelled.
/// (A JS error reaches Dart differently under dart2js and wasm; its words
/// name it either way.)
String? _why(Object e) {
  final said = '$e';
  if (said.contains('NotAllowedError') || said.contains('AbortError')) return null;
  if (said.contains('InvalidStateError')) return 'This device has a passkey for the game already';
  if (said.contains('SecurityError')) return 'Passkeys don’t work on this address';
  return 'This browser couldn’t use a passkey';
}

Future<Map<String, Object?>?> createPasskey({required String challenge, required String user, required String name}) async {
  final key = JSObject()
    ..['challenge'] = _bytes(challenge)
    ..['rp'] = {'name': "The King's Court"}.jsify()
    ..['user'] = (JSObject()
      ..['id'] = _bytes(user)
      ..['name'] = name.toJS
      ..['displayName'] = name.toJS)
    ..['pubKeyCredParams'] = [
      for (final alg in const [-7, -8, -257]) {'type': 'public-key', 'alg': alg}
    ].jsify()
    ..['authenticatorSelection'] = {'residentKey': 'required', 'userVerification': 'preferred'}.jsify()
    ..['attestation'] = 'none'.toJS
    ..['timeout'] = 120000.toJS;
  final web.Credential? made;
  try {
    made = await web.window.navigator.credentials.create(web.CredentialCreationOptions(publicKey: key as web.PublicKeyCredentialCreationOptions)).toDart;
  } catch (e) {
    final why = _why(e);
    if (why == null) return null;
    throw PasskeyError(why);
  }
  if (made == null) return null;
  final c = made as web.PublicKeyCredential;
  final r = c.response as web.AuthenticatorAttestationResponse;
  final JSArrayBuffer? publicKey;
  try {
    publicKey = r.getPublicKey();
  } catch (_) {
    throw PasskeyError('This browser is too old for passkeys');
  }
  if (publicKey == null) throw PasskeyError('A kind of passkey the game can’t use');
  return {
    'credentialId': _b64(c.rawId),
    'clientDataJSON': _b64(r.clientDataJSON),
    'authenticatorData': _b64(r.getAuthenticatorData()),
    'publicKey': _b64(publicKey),
    'alg': r.getPublicKeyAlgorithm(),
  };
}

Future<Map<String, Object?>?> usePasskey({required String challenge}) async {
  final key = JSObject()
    ..['challenge'] = _bytes(challenge)
    ..['userVerification'] = 'preferred'.toJS
    ..['timeout'] = 120000.toJS;
  final web.Credential? used;
  try {
    used = await web.window.navigator.credentials.get(web.CredentialRequestOptions(publicKey: key as web.PublicKeyCredentialRequestOptions)).toDart;
  } catch (e) {
    final why = _why(e);
    if (why == null) return null;
    throw PasskeyError(why);
  }
  if (used == null) return null;
  final c = used as web.PublicKeyCredential;
  final r = c.response as web.AuthenticatorAssertionResponse;
  return {
    'credentialId': _b64(c.rawId),
    'clientDataJSON': _b64(r.clientDataJSON),
    'authenticatorData': _b64(r.authenticatorData),
    'signature': _b64(r.signature),
  };
}

void goTo(String url) => web.window.location.assign(url);

/// Takes `?<key>=` off the address without reloading.
void dropFromAddress(String key) {
  final here = Uri.base;
  if (!here.queryParameters.containsKey(key)) return;
  final rest = {...here.queryParameters}..remove(key);
  final to = here.replace(queryParameters: rest.isEmpty ? null : rest);
  web.window.history.replaceState(null, '', to.toString().replaceFirst(RegExp(r'\?$'), ''));
}
