/// Whether blurred shadows and glows are drawn blurred.
///
/// On the web every frame draws the whole screen again, and every blur in
/// it is drawn afresh each time: on a phone's graphics chip that's much of
/// a frame. A build made with `--dart-define=NO_BLUR=true` draws the same
/// shadows unblurred, so the frame benchmark (tool/perf.sh --no-blur) can
/// show what the blurs cost on a real device. A constant: in the usual
/// build every `blurs ? x : 0` is just `x`.
library;

const blurs = !bool.fromEnvironment('NO_BLUR');
