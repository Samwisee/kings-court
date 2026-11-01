/// The frame benchmark's measures off the web (the Mac app): the timeline
/// isn't open to the app there, so there's nothing per widget, and no log
/// server. Frames are still timed, by the engine and by the test.
library;

Map<String, double> timelineMeasures() => const {};

void clearTimelineMeasures() {}

void logLine(String line) {}
