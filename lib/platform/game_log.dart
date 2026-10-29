/// Every round played, recorded for balancing the game: how it was dealt,
/// who took what, every move, and how it ended. Nothing personal: no
/// names, just an anonymous id for this device so one player's rounds can
/// be told apart from another's.
///
/// Records go to the same small web service as bug reports
/// (`tool/bug_worker/`, its `/rounds` path), when that's set at build time
/// and the player hasn't turned "Share play data" off in the menu. Sending
/// never gets in the way of the game: it's fire and forget, and a failure
/// is dropped.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../game/state.dart';
import '../net/table_link.dart';
import 'build_info.dart';
import 'service.dart';

/// Rounds go to the service's `/rounds`.
const _service = serviceUrl;

abstract final class GameLog {
  /// The shape of a record; raise it when the shape changes, so old and
  /// new records can be read apart.
  static const version = 1;

  /// The menu's "Share play data" (on unless turned off).
  static bool sharing = true;

  /// This device's anonymous id, made the first time the game runs.
  static String? player;

  static const _sharingKey = 'kingsCourt.sharePlayData';
  static const _playerKey = 'kingsCourt.player';

  /// The setting and the id, as saved (the id made the first time).
  static Future<void> load(SharedPreferences prefs) async {
    sharing = prefs.getBool(_sharingKey) ?? true;
    player = prefs.getString(_playerKey);
    if (player == null) {
      player = newPlayerId();
      await prefs.setString(_playerKey, player!);
    }
  }

  static Future<void> save(SharedPreferences prefs) => prefs.setBool(_sharingKey, sharing);

  /// A new anonymous id: 16 random hex digits.
  static String newPlayerId([Random? rand]) {
    final r = rand ?? Random.secure();
    return [for (var i = 0; i < 8; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
  }

  /// The last few records made this session, newest last (for tests and
  /// bug reports).
  static final List<Map<String, dynamic>> recent = [];

  /// The record of [game]'s round, just over. [moves] are the moves since
  /// the last record (the round's, and anything between rounds); [people]
  /// the seats people played (the rest were courtiers).
  static Map<String, dynamic> record(GameState game,
      {required List<Move> moves, required List<int> people, required bool onScreen}) {
    final r = game.round!;
    return {
      'v': version,
      'build': buildVersion,
      'at': DateTime.now().toUtc().toIso8601String(),
      if (player != null) 'player': player,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'mode': game.mode.name,
      if (game.chapter != null) 'chapter': game.chapter,
      if (game.isTutorial) 'lesson': game.lesson,
      'onScreen': onScreen,
      'players': r.players,
      'people': people,
      'roundNumber': game.roundNumber,
      'outcome': switch (r.outcome) {
        RoundOutcome.won => 'won',
        RoundOutcome.lost => 'lost',
        RoundOutcome.inProgress => 'open',
      },
      // The round as it ended: the cards dealt (all played, or still in
      // hand), every task with its owner and how it went, the tricks.
      'round': r.toJson(),
      'moves': [for (final m in moves) m.toJson()],
    };
  }

  /// Sends [record], if sharing is on and there's somewhere to send it.
  static void send(Map<String, dynamic> record) {
    recent.add(record);
    if (recent.length > 5) recent.removeAt(0);
    if (!sharing || _service.isEmpty) return;
    () async {
      try {
        await http
            .post(Uri.parse('$_service/rounds'),
                headers: {'Content-Type': 'application/json'}, body: jsonEncode(record))
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        // Lost: the game goes on.
      }
    }();
  }
}

/// Records the rounds of one table, each once, with the moves since the
/// last record.
class RoundLogger {
  GameState? _game;
  int _moves = 0;
  int _deal = -1;

  /// [game]'s round is over: records it with the moves in [history] since
  /// the last. [you] is the seat a person plays on screen; null at a real
  /// table, where every seat is a person. Once per deal, even if a mark is
  /// undone and made again.
  void over(GameState game, List<Move> history, {required int? you}) {
    // A new game starts its moves (and its deals) again.
    if (!identical(game, _game) || _moves > history.length) {
      _game = game;
      _moves = 0;
      _deal = -1;
    }
    if (_deal == game.dealId) return;
    _deal = game.dealId;
    final moves = history.sublist(_moves);
    _moves = history.length;
    GameLog.send(GameLog.record(game,
        moves: moves,
        people: you == null ? [for (var i = 0; i < game.players.length; i++) i] : [you],
        onScreen: you != null));
  }
}
