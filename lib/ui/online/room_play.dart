/// An online game from the page's side: the room it's played in
/// (net/online_table.dart), who sits where, what to say when the
/// connection changes, and which device does the table's work. The host's
/// device plays the courtiers and anyone away, crowns the King and deals
/// each round; every device asks only its own player for moves.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../engine/round.dart';
import '../../game/seats.dart';
import '../../game/setup.dart';
import '../../game/state.dart';
import '../../net/online_table.dart';
import '../../net/replay.dart';
import '../../platform/build_info.dart';
import '../../platform/game_log.dart';
import '../../platform/invite.dart';
import '../../platform/room_socket.dart';
import '../../platform/service.dart';
import 'online_setup.dart';

class RoomPlay {
  RoomPlay(this.room, {required this.onChange, required VoidCallback onRebuilt})
      : _status = room.status,
        _was = List.of(room.seats.holders) {
    // Moves made here are played at once; the room's order wins if it
    // differs ([OnlineTable.playAhead]).
    room.playAhead = true;
    _rebuilds = room.rebuilt.listen((_) => onRebuilt());
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
    unawaited(_remember());
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
  late final StreamSubscription<void> _rebuilds;
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
          String? joinCode,
          required VoidCallback onCancel,
          required ValueChanged<OnlineTable> onPlay}) =>
      OnlineSetup(
          open: open ?? openRoomSocket,
          service: _service,
          session: session,
          build: buildVersion,
          seed: seed,
          joinCode: joinCode == '' ? null : joinCode,
          onCancel: onCancel,
          onPlay: onPlay);

  int get seat => room.seat;
  bool get hosting => room.hosting;
  Seats get seats => room.seats;

  /// Whether a person plays [seat].
  bool personAt(int seat) => room.seats.holders[seat] is Person;

  /// Whether someone at the table but [you] is still to say, before the
  /// first pick of [r], whether they'll show a card first.
  bool deciding(Round r, {required int you}) => [
        for (var s = 0; s < r.players && s < room.seats.count; s++)
          if (s != you && room.seats.present(s) && !r.ready.contains(s) && !r.spoke[s]) s
      ].isNotEmpty;

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

  /// Invites someone into the room (it can be joined mid-game): the share
  /// sheet, or the link copied, when there's no sheet; what to say then.
  Future<String?> invite() async => await shareInvite(room.code) ? null : 'Invite link copied';

  /// The room as a bug report tells it.
  Map<String, dynamic> details() => {
        'code': room.code,
        'seat': seat,
        'hosting': hosting,
        'status': room.status.name,
        'seats': room.seats.toJson(),
      };

  // ------------------------------------------------- coming back to it

  static const _key = 'kingsCourt.room';
  static Uri get _service => Uri.parse(hasService ? serviceUrl : 'https://rooms.test');

  /// Kept until you leave, so the game can be taken up again after the app
  /// is closed: the room, and who this device was in it.
  Future<void> _remember() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key,
          jsonEncode({
            'code': room.code,
            'session': room.session,
            'name': room.name,
            'at': DateTime.now().millisecondsSinceEpoch,
          }));
    } catch (_) {}
  }

  static Future<void> _forget() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }

  /// The game this device was playing when the app was last closed, back
  /// in its seat (through [open]'s rooms in tests); null when there's none,
  /// it's over, or someone else has the seat now.
  static Future<OnlineTable?> rejoin({SocketOpener? open}) async {
    if (!hasService && open == null) return null;
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (saved == null) return null;
      final j = jsonDecode(saved) as Map<String, dynamic>;
      final age = DateTime.now().millisecondsSinceEpoch - (j['at'] as int);
      if (age < const Duration(days: 2).inMilliseconds) {
        final t = await OnlineTable.join(open ?? openRoomSocket, _service,
            code: j['code'] as String,
            session: j['session'] as String,
            name: j['name'] as String,
            build: buildVersion,
            rejoin: true);
        if (t.status == TableStatus.open && t.started) return t;
        t.dispose();
      }
      await _forget();
    } catch (_) {}
    return null;
  }

  /// As the game opens: the online game it was closed in, back in its
  /// seat ([rejoin]), or else the room an invite link ([address]) is for.
  static Future<({OnlineTable? room, String? invited})> onOpen(
      {SocketOpener? open, Uri? address}) async {
    final room = await rejoin(open: open);
    final invited = room == null ? invitedRoom(address) : null;
    forgetInvite();
    return (room: room, invited: invited);
  }

  // ------------------------------------------------- someone walked away

  /// How long a move waits on you before your courtier makes it, so
  /// someone who's walked away holds nobody up; you're warned [warning]
  /// before.
  static Duration idleLimit = const Duration(seconds: 45);
  static const warning = Duration(seconds: 10);
  Timer? _idle;
  Timer? _warn;
  String? _idleAt;

  /// The table changed: [moment] is where the game has got to, [yours]
  /// whether it waits on you. Once it's waited at the same moment for
  /// [idleLimit], [standIn] makes your move; [warn] says so a little
  /// before, in words to show.
  void watch(String moment,
      {required bool yours, required VoidCallback standIn, required ValueChanged<String> warn}) {
    if (!yours) {
      _idle?.cancel();
      _warn?.cancel();
      _idleAt = null;
      return;
    }
    if (moment == _idleAt) return;
    _idleAt = moment;
    _idle?.cancel();
    _warn?.cancel();
    if (idleLimit > warning * 2) {
      _warn = Timer(idleLimit - warning,
          () => warn('Your move: your courtier takes it in ${warning.inSeconds} seconds'));
    }
    _idle = Timer(idleLimit, () {
      _idleAt = null;
      standIn();
    });
  }

  /// Out of the room for good: nothing to come back to.
  void close() {
    _changes.cancel();
    _rebuilds.cancel();
    _idle?.cancel();
    _warn?.cancel();
    unawaited(_forget());
  }
}
