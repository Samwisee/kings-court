/// The frame benchmark's measures off the web (the Mac app): the timeline
/// isn't open to the app there, so there's nothing per widget, and no log
/// server. Frames are still timed, by the engine and by the test.
library;

import 'package:flutter/foundation.dart';

Map<String, double> timelineMeasures() => const {};

void clearTimelineMeasures() {}

/// How far the run got, in flutter drive's output (tool/devices.sh keeps it).
void logLine(String line) => debugPrint(line);
