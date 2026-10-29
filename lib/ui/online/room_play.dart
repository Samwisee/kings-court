/// An online game from the page's side: the room it's played in
/// (net/online_table.dart), who sits where, what to say when the
/// connection changes, and which device does the table's work. The host's
/// device plays the courtiers and anyone away, crowns the King and deals
/// each round; every device asks only its own player for moves.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../game/seats.dart';
import '../../game/setup.dart';
import '../../game/state.dart';
import '../../net/online_table.dart';
import '../../net/replay.dart';
import '../../platform/build_info.dart';
import '../../platform/game_log.dart';
import '../../platform/room_socket.dart';
import '../../platform/service.dart';
import 'online_setup.dart';

class RoomPlay {
  RoomPlay(this.room, {required this.onChange})
      : _status = room.status,
        _was = List.of(room.seats.holders) {
    _changes = room.changes.listen((_) {
      var news = _comings();
      if (room.status != _status) {
        _status = room.status;
        news = switch (room.status) {
          TableStatus.reconnecting => 'Reconnecting…',
          TableStatus.open => 'Back in the room',
          TableStatus.closed => (room.refusal ?? Refusal.unreachable).message,
          TableStatus.connecting => null,
        };
      }
      onChange(news);
    });
  }

  final OnlineTable room;

  /// Who came, went, dropped out or came back since the room last
  /// changed, in a few words (the last of them, if several).
  String? _comings() {
    String? news;
    final now = room.seats.holders;
    String name(String id) => room.names[id] ?? 'Someone';
    for (var s = 0; s < now.length && s < _was.length; s++) {
      final (was, isNow) = (_was[s], now[s]);
      if (isNow case Person(:final id, :final connected) when id != room.session) {
        if (was case Person(id: final wasId, connected: final wasThere) when wasId == id) {
          if (wasThere && !connected) {
            news = '${name(id)} dropped out${hosting ? ': you play their seat for now' : ''}';
          } else if (!wasThere && connected) {
            news = '${name(id)} is back';
          }
        } else {
          news = '${name(id)} joined';
        }
      } else if (was case Person(:final id) when id != room.session && isNow is CourtierSeat) {
        news = '${name(id)} left: a courtier plays on';
      }
    }
    _was = List.of(now);
    return news;
  }

  List<SeatHolder> _was;

  /// The room changed; [news] is a word about who came or went, or the
  /// connection, when one of them changed.
  final void Function(String? news) onChange;
  late final StreamSubscription<void> _changes;
  TableStatus _status;

  /// This device in rooms: its player's id, and a part for this run, so
  /// two windows on one computer are two players.
  static final session =
      '${GameLog.player ?? GameLog.newPlayerId()}-${GameLog.newPlayerId().substring(0, 4)}';

  /// Multiplayer setup, through the game's service (or [open]'s rooms,
  /// in tests).
  static Widget setup(
          {SocketOpener? open,
          int? seed,
          required VoidCallback onCancel,
          required ValueChanged<OnlineTable> onPlay}) =>
      OnlineSetup(
          open: open ?? openRoomSocket,
          service: Uri.parse(hasService ? serviceUrl : 'https://rooms.test'),
          session: session,
          build: buildVersion,
          seed: seed,
          onCancel: onCancel,
          onPlay: onPlay);

  int get seat => room.seat;
  bool get hosting => room.hosting;
  Seats get seats => room.seats;

  /// Whether a person plays [seat].
  bool personAt(int seat) => room.seats.holders[seat] is Person;

  /// The seats people play.
  List<int> people() => [for (var s = 0; s < room.seats.count; s++) if (personAt(s)) s];

  /// The room's game, dealt from its setup and played on through every
  /// move so far (joining one under way), with you in your seat and
  /// people's seats named after them.
  GameState start(ModeRules rules) =>
      nameSeats(replay(room.setup!, room.history, rules: rules, you: seat));

  /// People's seats go by their names (yours stays "You"); courtiers keep
  /// theirs.
  GameState nameSeats(GameState game) {
    for (var s = 0; s < game.players.length && s < room.seats.count; s++) {
      if (room.seats.holders[s] case Person(:final id) when s != seat) {
        game.players[s].name = room.names[id] ?? 'Player ${s + 1}';
      }
    }
    return game;
  }

  void close() => _changes.cancel();
}
