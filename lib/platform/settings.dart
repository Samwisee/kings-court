/// Settings the whole app reads, kept between visits by the page.
library;

abstract final class Settings {
  /// Four-colour suits (a setting in the menu): ♦ blue and ♣ green, so no
  /// two suits share a colour. Every suit keeps its own shape either way.
  static bool fourColourSuits = false;
}
