import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/platform/frame_stats.dart';

/// A frame due at [at] ms that took [build] ms to build and [raster] to
/// draw.
FrameTiming frame(int at, double build, double raster) {
  final v = at * 1000;
  final b = (build * 1000).round(), r = (raster * 1000).round();
  return FrameTiming(
    vsyncStart: v,
    buildStart: v,
    buildFinish: v + b,
    rasterStart: v + b,
    rasterFinish: v + b + r,
    rasterFinishWallTime: v + b + r,
  );
}

void main() {
  test('Frames are counted where the player is, late ones apart, and taken once', () {
    FrameStats.take();
    FrameStats.at = 'table';
    FrameStats.debugAdd([frame(0, 2, 3), frame(17, 3, 2), frame(34, 10, 12), frame(51, 1, 1)]);
    FrameStats.at = 'livery';
    FrameStats.debugAdd([frame(1000, 40, 70)]);
    final taken = FrameStats.take()!;
    final table = taken['table']! as Map;
    expect(table['frames'], 4);
    expect(table['late'], 1, reason: '10 + 12 ms is past a 60 Hz refresh');
    expect(table['worst'], 22.0);
    // Builds of 2, 3 and 1 ms are under 4; one of 10 is under 12.
    expect(table['build'], [3, 0, 1, 0, 0, 0, 0, 0, 0]);
    final livery = taken['livery']! as Map;
    expect(livery['late'], 1);
    expect(livery['raster'], [0, 0, 0, 0, 0, 0, 0, 1, 0]);
    expect(taken['period'], closeTo(16.7, 0.1));
    expect(taken['device'], isA<String>());
    expect(FrameStats.take(), isNull, reason: 'taken: counting starts again');
  });
}
