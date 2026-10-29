/// A saved game, one per way to play.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../game/state.dart';
import '../../modes/modes.dart';
import '../controller.dart';

/// A game saved on this device: its state, the table layout that goes with
/// it, and when it was last saved.
class SavedGame {
  SavedGame(this.game, this.data, this.at);
  final GameState game;
  final Map<String, dynamic> data;
  final DateTime at;

  /// Whether the save's game carries its own points target (saves from
  /// before the target was part of the game kept it beside the game).
  bool get hasTarget => (data['game'] as Map<String, dynamic>).containsKey('target');

  String get title => modeOf(game.mode).title;

  /// Where the game had got to, in a few words.
  String get detail {
    final g = game;
    final seats = g.digital
        ? 'on-screen cards'
        : '${g.players.length} at the table';
    return switch (g.mode) {
      GameMode.chronicle =>
        'Chapter ${(g.chapter ?? 0) + 1} · $seats',
      GameMode.endless => 'Streak ${g.streak} · $seats',
      _ => 'Round ${math.max(1, g.roundNumber)} · $seats',
    };
  }

  String get ago {
    final d = DateTime.now().difference(at);
    if (at.millisecondsSinceEpoch == 0) return '';
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    if (d.inDays == 1) return 'yesterday';
    return '${d.inDays} days ago';
  }
}

/// Where saves were kept before there was one per way to play.
const _legacyKey = 'kingsCourt.game';

/// The games saved on this device, newest first: one per way to play, the
/// tutorial's left out, and only rounds still in progress. A save in the
/// old single slot is moved to its mode's first.
Future<List<SavedGame>> readSaves(SharedPreferences prefs) async {
  final legacy = prefs.getString(_legacyKey);
  if (legacy != null) {
    try {
      final data = jsonDecode(legacy) as Map<String, dynamic>;
      final g = GameState.fromJson(data['game'] as Map<String, dynamic>);
      if (g != null && prefs.getString(GameController.slotKey(g.mode)) == null) {
        await prefs.setString(GameController.slotKey(g.mode), legacy);
      }
    } catch (_) {}
    await prefs.remove(_legacyKey);
  }
  final saves = <SavedGame>[];
  for (final mode in GameMode.values) {
    if (mode == GameMode.tutorial) continue;
    final raw = prefs.getString(GameController.slotKey(mode));
    if (raw == null) continue;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final g = GameState.fromJson(data['game'] as Map<String, dynamic>);
      if (g == null || g.outcome != RoundOutcome.inProgress) continue;
      saves.add(SavedGame(g, data,
          DateTime.fromMillisecondsSinceEpoch(data['savedAt'] as int? ?? 0)));
    } catch (_) {
      // A save that no longer reads is skipped.
    }
  }
  saves.sort((a, b) => b.at.compareTo(a.at));
  return saves;
}
