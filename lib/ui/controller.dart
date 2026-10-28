/// The game being played, apart from how it's drawn.
///
/// [GameController] owns the [GameState] (and with it the cards on screen,
/// [Round]), the [TableLink] every move goes through, and saving. The
/// page (HomePage) draws the controller and turns taps into calls on it;
/// it keeps only what is about drawing: animations, where things are on
/// screen, what's open.
///
/// For online play the controller is where a network [TableLink] plugs in,
/// and where moves from other devices arrive. For performance it is a
/// [ChangeNotifier]: parts of the screen can listen to it, or to its
/// narrower notifiers, instead of the whole page rebuilding.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/round.dart';
import '../game/state.dart';
import '../net/table_link.dart';

class GameController extends ChangeNotifier {
  GameController({TableLink? link}) : link = link ?? LocalLink();

  /// Where moves go: this device, for now (see net/table_link.dart).
  final TableLink link;

  /// The seat this device plays from. On one device it's seat 0, drawn at
  /// the bottom of the table; online it's the seat joined in.
  int mySeat = 0;

  GameState _game = GameState();

  /// The game on the table. Setting a new one (a new game, a saved game
  /// carried on) tells everyone listening; it's saved once it's played
  /// ([changed]), so swapping in a blank game never overwrites a save.
  GameState get game => _game;
  set game(GameState g) {
    if (!identical(g, _game)) {
      // The last game's waiting save goes in first, to its own slot.
      if (_saveTimer != null) saveNow();
      // A new game: its moves start from the first.
      link.reset();
    }
    _game = g;
    notifyListeners();
  }

  // ------------------------------------------------------------ saving

  /// Where each way to play keeps its save.
  static String slotKey(GameMode mode) => 'kingsCourt.game.${mode.name}';

  /// The best win streak, kept apart from any one game.
  static const bestKey = 'kingsCourt.bestStreak';

  /// What the page adds to a save: the real table's layout and the like.
  Map<String, dynamic> Function()? saveExtras;

  /// The best streak known to the page (from earlier games).
  int Function()? knownBest;

  /// Saving waits this long after the last change, so a burst of changes
  /// (a trick, a deal, every frame of a drag) is written once.
  static const saveDelay = Duration(milliseconds: 400);

  Timer? _saveTimer;

  /// Something about the game changed: it'll be saved shortly, and anyone
  /// listening is told now.
  void changed() {
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () {
      _saveTimer = null;
      saveNow();
    });
  }

  /// Whether a save is waiting to be written.
  bool get savePending => _saveTimer != null;

  /// Writes the game now (when the page goes away or the app is put in the
  /// background, so nothing is lost).
  Future<void> saveNow() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    // The tutorial is never saved, so it can't replace a game in progress.
    if (_game.isTutorial) return;
    try {
      final data = {
        'game': _game.toJson(),
        ...?saveExtras?.call(),
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };
      final encoded = jsonEncode(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(slotKey(_game.mode), encoded);
      final best = [knownBest?.call() ?? 0, _game.bestStreak]
          .reduce((a, b) => a > b ? a : b);
      if (best > (prefs.getInt(bestKey) ?? 0)) await prefs.setInt(bestKey, best);
    } catch (_) {
      // Saving is best-effort.
    }
  }

  @override
  void dispose() {
    if (_saveTimer != null) saveNow();
    link.dispose();
    super.dispose();
  }
}
