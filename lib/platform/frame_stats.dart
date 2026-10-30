/// How smoothly the game draws on this device: every frame's build and
/// raster times, as the engine reports them, counted into a few buckets by
/// where the player was (the table, the Livery page, the menus). Taken and
/// sent with each round's record (game_log.dart), under the same "Share
/// play data" setting, so real phones' numbers can be read beside the
/// benchmark's (integration_test/frames_test.dart). Nothing but counts and
/// the kind of device.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'device_kind.dart';

abstract final class FrameStats {
  /// Where the player is now: 'table', 'livery' or 'menus'. Frames are
  /// counted under it.
  static String at = 'menus';

  /// The frame times' buckets, in ms: a frame is counted in the first it's
  /// under, or past the last.
  static const buckets = [4, 8, 12, 16, 25, 33, 50, 100];

  static final _by = <String, _Counts>{};
  static double _period = 1000 / 60;
  static Duration? _lastVsync;
  static bool _started = false;

  /// Starts counting: once, at start up.
  static void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// [timings] counted as if the engine had reported them.
  @visibleForTesting
  static void debugAdd(List<FrameTiming> timings) => _onTimings(timings);

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      // The refresh period: the shortest gap between frames seen yet (a
      // 120 Hz screen gives 8.3 ms).
      final vsync = Duration(microseconds: t.timestampInMicroseconds(FramePhase.vsyncStart));
      final last = _lastVsync;
      if (last != null) {
        final gap = (vsync - last).inMicroseconds / 1000;
        if (gap >= 4 && gap < _period) _period = gap;
      }
      _lastVsync = vsync;
      (_by[at] ??= _Counts()).add(t.buildDuration, t.rasterDuration, _period);
    }
  }

  /// The counts since the last take, and starts again: null when there's
  /// nothing.
  static Map<String, Object>? take() {
    if (_by.isEmpty) return null;
    final out = <String, Object>{
      'period': double.parse(_period.toStringAsFixed(1)),
      'device': deviceKind(),
      'dpr': double.parse(PlatformDispatcher.instance.views.first.devicePixelRatio.toStringAsFixed(2)),
      if (kIsWasm) 'wasm': true,
      for (final e in _by.entries) e.key: e.value.toJson(),
    };
    _by.clear();
    return out;
  }
}

class _Counts {
  int frames = 0;

  /// Frames whose build and raster together took longer than a refresh:
  /// on the web they're one after the other on one thread, so the frame
  /// missed its refresh.
  int late = 0;
  double worst = 0;
  final build = List.filled(FrameStats.buckets.length + 1, 0);
  final raster = List.filled(FrameStats.buckets.length + 1, 0);

  static int _bucket(double ms) {
    for (var i = 0; i < FrameStats.buckets.length; i++) {
      if (ms < FrameStats.buckets[i]) return i;
    }
    return FrameStats.buckets.length;
  }

  void add(Duration b, Duration r, double period) {
    final bm = b.inMicroseconds / 1000, rm = r.inMicroseconds / 1000;
    frames++;
    if (bm + rm > period) late++;
    worst = math.max(worst, bm + rm);
    build[_bucket(bm)]++;
    raster[_bucket(rm)]++;
  }

  Map<String, Object> toJson() => {
        'frames': frames,
        'late': late,
        'worst': double.parse(worst.toStringAsFixed(1)),
        'build': build,
        'raster': raster,
      };
}
