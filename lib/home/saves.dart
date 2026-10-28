// A saved game, one per way to play.
part of '../main.dart';

/// A game saved on this device: its state, the table layout that goes with
/// it, and when it was last saved.
class _SavedGame {
  _SavedGame(this.game, this.data, this.at);
  final GameState game;
  final Map<String, dynamic> data;
  final DateTime at;

  /// Whether the save's game carries its own points target (saves from
  /// before the target was part of the game kept it beside the game).
  bool get hasTarget => (data['game'] as Map<String, dynamic>).containsKey('target');

  String get title => switch (game.mode) {
        GameMode.free => 'Free play',
        GameMode.endless => 'Endless',
        GameMode.chronicle => 'The Chronicle',
        GameMode.dynasty => 'Dynasty',
        GameMode.tutorial => 'Tutorial',
      };

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
