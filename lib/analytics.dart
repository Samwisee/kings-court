/// A handful of anonymous counts, so we can see how far people get.
///
/// Counts go to GoatCounter (no cookies, nothing personal) when its site
/// code is set at build time (`--dart-define=GOATCOUNTER=<code>`); without
/// it, nothing is sent. Each event is a short path such as
/// `start/dynasty/3p/screen`, and GoatCounter shows how often each happened.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'build_info.dart';

const goatCounterCode = String.fromEnvironment('GOATCOUNTER');

abstract final class Analytics {
  /// Every event sent this session, newest last (for tests and bug reports).
  static final List<String> sent = [];

  /// Opening the game.
  static void visit() => _send('/', event: false);

  /// Something worth counting: [path] parts are joined with slashes.
  static void event(List<Object> path) =>
      _send(path.map((p) => '$p'.toLowerCase().replaceAll(' ', '-')).join('/'));

  /// A round number grouped, so the list stays short: 1 to 5, then 6-10,
  /// then 11+.
  static String roundBucket(int round) =>
      round <= 5 ? 'r$round' : round <= 10 ? 'r6-10' : 'r11+';

  static void _send(String path, {bool event = true}) {
    sent.add(path);
    if (sent.length > 50) sent.removeAt(0);
    if (goatCounterCode.isEmpty) return;
    final uri = Uri.https('$goatCounterCode.goatcounter.com', '/count', {
      'p': path,
      if (event) 'e': 'true',
      't': event ? path : "The King's Court ($buildVersion)",
      'rnd': '${DateTime.now().microsecondsSinceEpoch}',
    });
    // GoatCounter answers without CORS headers, so the browser reports an
    // error even though the count landed; that's expected and ignored.
    unawaited(http.get(uri).then((_) {}, onError: (Object e) {
      if (kDebugMode) debugPrint('analytics: $e');
    }));
  }
}
