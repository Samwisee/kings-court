/// Sharing on the web: the browser's share sheet (on phones), and the
/// page's address.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Opens the share sheet with [text] and [url]; false where the browser
/// has none (most computers). Cancelling it still counts as shared.
Future<bool> shareText(String text, String url) async {
  final nav = web.window.navigator;
  if (!nav.has('share')) return false;
  try {
    await nav.share(web.ShareData(text: text, url: url)).toDart;
  } catch (_) {
    // Cancelled, or turned down: nothing to do.
  }
  return true;
}

/// Takes `?room=` off the address without reloading.
void dropRoomFromAddress() {
  final here = Uri.base;
  if (!here.queryParameters.containsKey('room')) return;
  final rest = {...here.queryParameters}..remove('room');
  final to = here.replace(queryParameters: rest.isEmpty ? null : rest);
  web.window.history.replaceState(null, '', to.toString().replaceFirst(RegExp(r'\?$'), ''));
}
