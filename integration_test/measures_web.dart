/// The frame benchmark's measures in a browser: Flutter's timeline, which a
/// profile build writes as the browser's performance measures (build,
/// layout, paint, and with the debugProfile flags each widget and render
/// object), and a line to the CI job's log server.
library;

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// What the browser measured since the last clear: each name's own time
/// (its length less the measures inside it: they nest, a widget's build
/// holding its children's), summed.
Map<String, double> timelineMeasures() {
  final list = [
    for (final e in web.window.performance.getEntriesByType('measure').toDart) (e.name, e.startTime, e.startTime + e.duration)
  ]..sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : b.$3.compareTo(a.$3));
  final out = <String, double>{};
  final open = <(String, double, double)>[];
  final inner = <double>[];
  void close() {
    final m = open.removeLast();
    final kids = inner.removeLast();
    out[m.$1] = (out[m.$1] ?? 0) + math.max(0, (m.$3 - m.$2) - kids);
    if (inner.isNotEmpty) inner[inner.length - 1] += m.$3 - m.$2;
  }

  for (final m in list) {
    while (open.isNotEmpty && open.last.$3 <= m.$2) {
      close();
    }
    open.add(m);
    inner.add(0);
  }
  while (open.isNotEmpty) {
    close();
  }
  clearTimelineMeasures();
  return out;
}

/// Only the measures: Flutter's timeline closes each event against the
/// mark it opened with, so clearing marks mid-frame breaks every frame.
void clearTimelineMeasures() => web.window.performance.clearMeasures();

/// How far the run got, seen even if it hangs: on a real device in the
/// browser's console (tool/devices.sh keeps it); in CI to the job's log
/// server (port 9999), which only runs there.
void logLine(String line) {
  if (const bool.fromEnvironment('FRAMES_REAL_DEVICE')) {
    debugPrint(line);
    return;
  }
  try {
    web.window.fetch('http://localhost:9999/log'.toJS, web.RequestInit(method: 'POST', mode: 'no-cors', body: line.toJS));
  } catch (_) {
    // No log server: nothing to tell.
  }
}
