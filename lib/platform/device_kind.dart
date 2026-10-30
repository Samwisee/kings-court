/// The kind of device, coarsely, for the frame counts (frame_stats.dart):
/// off the web, the platform's name.
library;

export 'device_kind_any.dart' if (dart.library.js_interop) 'device_kind_web.dart';
