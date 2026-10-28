/// What the player has done across games, kept on the device: the
/// Chronicle's attempts and crowns. (The best streak and whether the
/// tutorial was played are kept beside it by the app, for now.)
library;

import 'chronicle/chapters.dart';

class Progress {
  Progress({ChronicleProgress? chronicle})
      : chronicle = chronicle ?? ChronicleProgress();

  ChronicleProgress chronicle;
}
