/// A clamp that never throws.
library;

/// Clamps [v] to [lo]..[hi] as a double. Unlike num.clamp it never throws
/// when the range is inverted (e.g. on a tiny window); it returns [lo].
double clampD(double v, double lo, double hi) =>
    v > hi ? (hi < lo ? lo : hi) : (v < lo ? lo : v);
