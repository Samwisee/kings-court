/// Multiplayer setup, in the New Game panel's frame: start a room or join
/// one by its code, then wait in the room until the host starts the game.
/// The room itself is net/online_table.dart; once its game starts, the
/// table is handed to the page to play ([OnlineSetup.onPlay]).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/seats.dart';
import '../../game/setup.dart';
import '../../game/state.dart';
import '../../net/online_table.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../setup/setup_frame.dart';
import '../setup/setup_tiles.dart';
import '../widgets.dart';

class OnlineSetup extends StatefulWidget {
  const OnlineSetup({
    super.key,
    required this.open,
    required this.service,
    required this.session,
    required this.build,
    required this.onCancel,
    required this.onPlay,
    this.seed,
  });

  /// How to reach the rooms: the socket, the service's address, this
  /// device as the room knows it, and the game's build.
  final SocketOpener open;
  final Uri service;
  final String session;
  final String build;

  /// Back out of multiplayer, to the first step of setup.
  final VoidCallback onCancel;

  /// The room's game has started: the table is the page's now.
  final ValueChanged<OnlineTable> onPlay;

  /// A fixed seed for the room's game (tests); a random one otherwise.
  final int? seed;

  /// The name you went by last time, offered again.
  static String lastName = '';

  @override
  State<OnlineSetup> createState() => _OnlineSetupState();
}

class _OnlineSetupState extends State<OnlineSetup> {
  int step = 0;
  bool _forward = true;

  /// Starting a room (rather than joining one).
  bool starting = true;

  GameMode mode = GameMode.free;
  int count = 4;
  int target = 5;
  bool surprise = false;

  late final _name = TextEditingController(text: OnlineSetup.lastName);
  final _code = TextEditingController();

  OnlineTable? _room;
  StreamSubscription<void>? _changes;
  bool _connecting = false;
  String? _problem;
  bool _handedOver = false;

  @override
  void dispose() {
    _changes?.cancel();
    if (!_handedOver) _quit();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Out of the room for good (someone in it, they're told).
  void _quit() {
    if (_room case final room?) {
      unawaited(room.leave());
      room.dispose();
    }
  }

  void _go(int to) => setState(() {
        _forward = to > step;
        step = to;
      });

  String get _yourName => _name.text.trim().isEmpty ? 'Player' : _name.text.trim();

  Future<void> _connect() async {
    if (_connecting) return;
    if (!starting && _code.text.trim().length != 4) {
      setState(() => _problem = 'Room codes are four letters.');
      return;
    }
    OnlineSetup.lastName = _name.text.trim();
    setState(() {
      _connecting = true;
      _problem = null;
    });
    final room = starting
        ? await OnlineTable.create(widget.open, widget.service,
            setup: GameSetup(
                mode: mode,
                names: [for (var i = 0; i < count; i++) 'Player ${i + 1}'],
                target: target,
                seed: widget.seed ?? math.Random().nextInt(1 << 30),
                digital: true,
                surprise: surprise),
            session: widget.session,
            name: _yourName,
            build: widget.build)
        : await OnlineTable.join(widget.open, widget.service,
            code: _code.text, session: widget.session, name: _yourName, build: widget.build);
    if (!mounted) {
      room.dispose();
      return;
    }
    setState(() => _connecting = false);
    if (room.status == TableStatus.closed) {
      room.dispose();
      setState(() => _problem = (room.refusal ?? Refusal.bad).message);
      return;
    }
    _room = room;
    _changes = room.changes.listen((_) => _changed());
    _go(2);
    _changed();
  }

  void _changed() {
    final room = _room;
    if (room == null || !mounted) return;
    if (room.started && room.status != TableStatus.closed && !_handedOver) {
      _handedOver = true;
      _changes?.cancel();
      widget.onPlay(room);
      return;
    }
    if (room.status == TableStatus.closed) {
      _leave(problem: (room.refusal ?? Refusal.unreachable).message);
      return;
    }
    setState(() {});
  }

  void _leave({String? problem}) {
    _changes?.cancel();
    _changes = null;
    _quit();
    _room = null;
    _problem = problem;
    _go(1);
  }

  void _back() => switch (step) {
        0 => widget.onCancel(),
        1 => _go(0),
        _ => _leave(),
      };

  static TextStyle _heading(Skin skin) => TextStyle(
      fontFamily: skin.displayFont,
      fontWeight: FontWeight.w700,
      fontSize: 26,
      color: skin.gold,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 12)]);

  Widget _chooseStep() {
    Widget tile(String title, String description, IconData icon, bool start) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ModeTile(
            title: title,
            icon: icon,
            description: description,
            selected: false,
            onTap: () {
              starting = start;
              _problem = null;
              _go(1);
            },
          ),
        );
    return Column(
      key: const ValueKey('online-choose'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Multiplayer', textAlign: TextAlign.center, style: _heading(context.skin)),
        const SizedBox(height: 6),
        const Text('Everyone plays on their own phone. Courtiers take any empty seats.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.35)),
        const SizedBox(height: 14),
        tile('Start a room', 'Choose the game, then share its code with your friends.',
            Icons.add_circle_outline_rounded, true),
        tile('Join a room', 'Enter the code a friend gives you.', Icons.login_rounded, false),
      ],
    );
  }

  Widget _nameField() => TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        maxLength: 24,
        decoration: const InputDecoration(
            labelText: 'Your name', isDense: true, border: OutlineInputBorder(), counterText: ''),
      );

  Widget _problemText() => _problem == null
      ? const SizedBox(height: 22)
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_problem!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFB4A8), height: 1.35)),
        );

  Widget _detailsStep() {
    final skin = context.skin;
    if (!starting) {
      return Column(
        key: const ValueKey('online-join'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Join a room', textAlign: TextAlign.center, style: _heading(skin)),
          const SizedBox(height: 14),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: skin.displayFont, fontSize: 30, letterSpacing: 10, color: skin.gold),
            decoration: const InputDecoration(
                labelText: 'Room code', border: OutlineInputBorder(), counterText: ''),
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 12),
          _nameField(),
          _problemText(),
        ],
      );
    }
    return Column(
      key: const ValueKey('online-start'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Start a room', textAlign: TextAlign.center, style: _heading(skin)),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          for (final (m, label) in [(GameMode.free, 'Free play'), (GameMode.endless, 'Endless')])
            ChoiceChip(
                label: Text(label),
                selected: mode == m,
                onSelected: (_) => setState(() => mode = m)),
        ]),
        const SizedBox(height: 14),
        const Text('Seats at the table', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (var n = 3; n <= maxPlayers; n++)
            CountChip(n: n, selected: count == n, onTap: () => setState(() => count = n)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Text(mode == GameMode.endless ? 'First target' : 'Points target',
              style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text('$target',
              style: TextStyle(
                  fontFamily: skin.displayFont,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: skin.gold)),
          const SizedBox(width: 4),
          const CrownIcon(),
        ]),
        Slider(
          value: target.toDouble(),
          min: 1,
          max: maxTarget.toDouble(),
          divisions: maxTarget - 1,
          onChanged: (v) => setState(() => target = v.round()),
        ),
        PipTile(
          value: surprise,
          onChanged: (v) => setState(() => surprise = v),
          title: const Text('Seals and decrees', style: TextStyle(fontSize: 16)),
          subtitle: const Text('Rounds may bring order seals and royal decrees.',
              style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(height: 10),
        _nameField(),
        _problemText(),
      ],
    );
  }

  Widget _lobbyStep() {
    final skin = context.skin;
    final room = _room!;
    String who(int seat) => switch (room.seats.holders[seat]) {
          Person(:final id, :final connected) => [
              room.names[id] ?? 'Player',
              if (id == widget.session) '(you)',
              if (id == room.host) '· host',
              if (!connected) '· away',
            ].join(' '),
          CourtierSeat() => 'A courtier',
          EmptySeat() => 'Waiting for someone…',
        };
    return Column(
      key: const ValueKey('online-lobby'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Room code', style: TextStyle(fontSize: 16, color: Colors.white70)),
        SelectableText(room.code,
            style: TextStyle(
                fontFamily: skin.displayFont,
                fontWeight: FontWeight.w900,
                fontSize: 48,
                letterSpacing: 12,
                color: skin.gold,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 12)])),
        const Text('Friends join with this code from Multiplayer, Join a room.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.35)),
        const SizedBox(height: 16),
        for (var s = 0; s < room.seats.count; s++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              CircleAvatar(radius: 8, backgroundColor: skin.players[s % skin.players.length]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(who(s),
                    style: TextStyle(
                        fontSize: 16,
                        color: room.seats.holders[s] is EmptySeat ? Colors.white54 : Colors.white)),
              ),
            ]),
          ),
        const SizedBox(height: 10),
        Text(
          room.status == TableStatus.reconnecting
              ? 'Reconnecting…'
              : room.hosting
                  ? 'Start when everyone’s in. Courtiers take the empty seats.'
                  : 'The host starts the game when everyone’s in.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final body = switch (step) {
      0 => _chooseStep(),
      1 => _detailsStep(),
      _ => _lobbyStep(),
    };
    return SetupFrame(
      step: step,
      steps: 3,
      forward: _forward,
      canCancel: true,
      choosing: step == 0,
      nextLabel: switch (step) {
        1 when _connecting => 'Connecting…',
        1 => starting ? 'Open the room' : 'Join',
        _ when room != null && room.hosting => 'Start',
        _ => 'Waiting for the host',
      },
      onBack: _back,
      onNext: switch (step) {
        1 when !_connecting => _connect,
        2 when room != null && room.hosting && room.status == TableStatus.open => room.start,
        _ => null,
      },
      body: body,
    );
  }
}
