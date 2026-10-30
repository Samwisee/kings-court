part of 'table_page.dart';

/// Moves coming in off the link (this screen's own, the bots', or other players' online), and the room they come from.
extension _Moves on HomePageState {
  /// Plays through [link] from now on.
  void _useLink(TableLink link) {
    _moves.cancel();
    _ctrl.useLink(link);
    _moves = link.moves.listen((m) => _onAction(m.action));
  }

  Widget _buildOnlineSetup() => RoomPlay.setup(
      open: HomePageTestHooks.rooms,
      seed: HomePageTestHooks.seed,
      joinCode: _online,
      onCancel: () => _set(() => _online = null),
      onPlay: _playOnline);

  /// The room's game has started: it's dealt here as on every device.
  void _playOnline(OnlineTable table) {
    _leaveRoom();
    _walkIn.waiting = false;
    final room = RoomPlay(table, onChange: (news) {
      if (!mounted || _room?.room != table) return;
      _host.seats = table.seats; // the host plays anyone away
      if (news != null) _showSnack(news, context.skin.feltDeep);
      _set(() => _room!.nameSeats(game));
    }, onRebuilt: () {
      if (!mounted || _room?.room != table) return;
      // The room put someone else's move first: the game again from its moves.
      _set(() {
        _lastTrick = null;
        _crowning = null;
        game = _room!.start(modeOf(table.setup!.mode).rules);
        _resetTable();
      });
    });
    _set(() {
      _online = null;
      _setupArgs = null;
      _room = room;
      _ctrl.mySeat = room.seat;
      _useLink(table);
      _host = _newHost();
      game = room.start(modeOf(table.setup!.mode).rules);
      _ctrl.online = true;
      _resetTable();
    });
    _keepAwake(true);
  }

  /// You've been a while: your courtier makes your move.
  void _standIn() {
    if (mounted && _speakPromptDue) return _startChoosing();
    if (!mounted || !(_yourPick || _yourPlay)) return;
    _showSnack('Your courtier moved for you', context.skin.feltDeep);
    unawaited(Host.standIn(_you, game.players.length, bot: Bot(), send: _link.send).act(game));
  }

  /// Out of the room, back to playing on this device.
  void _leaveRoom() {
    if (_room == null) return;
    unawaited(_room!.room.leave());
    _room!.close();
    _room = null;
    _ctrl.online = false;
    _ctrl.mySeat = 0;
    _useLink(LocalLink());
    _host = _newHost();
  }

  /// Whether this device may deal: online, only the host (others are told).
  bool get _mayDeal {
    if (_hostsTable) return true;
    _showSnack('The host deals the next round', context.skin.feltDeep);
    return false;
  }

  /// The mode's say for a new round, for the game to apply the actions
  /// that start one.
  RoundSetup Function(math.Random rand, {bool redeal}) get _nextRoundSetup =>
      (rand, {redeal = false}) =>
          _mode.rules.roundSetup(game, rand, redeal: redeal);

  /// An action coming back from the link: make it on the table. One that
  /// isn't allowed any more (the table moved on) is let go.
  void _onAction(TableAction action) {
    if (!mounted || !_inGame) return;
    // Online, play goes on while the crown flies: what comes meanwhile is
    // made once it lands, in order.
    if (_crowning != null) return _afterCrown.add(action);
    if (_digital && !_round.hasCards) dealRound(game, rigged: _mode.riggedDeal(game)); // before it came
    switch (action) {
      case MatchAction():
        if (_round.problem(action) != null) return;
        _onMove(action);
      case GameAction():
        if (game.problem(action) != null) return;
        _onGameAction(action);
    }
  }

  /// A move within the round's play.
  void _onMove(MatchAction move) {
    switch (move) {
      case PickTask(:final seat, :final task):
        _assignTaskNow(game.tasks[task], seat);
      case Pass(:final seat):
        _passNow(seat);
      case Announce():
        _set(() => _round.apply(move));
      case PlayCard(:final seat, :final card):
        _playCardNow(seat, card);
      case ShowCard(:final seat):
        _set(() {
          _round.apply(move);
          if (seat == _you) _revealing = false;
        });
      case ReturnTask():
        _set(() {
          _round.apply(move);
          _table.layoutOwned(_geo);
        });
      case Ready():
        _set(() => _round.apply(move));
    }
  }

  /// One of the game's actions: crowning, a mark, the next round.
  void _onGameAction(GameAction action) {
    switch (action) {
      case Crown(:final king):
        // Applied once the crown has flown to its seat (see _crownKing).
        _crownKing(king);
      case Speak():
        _set(() => game.apply(action));
      case MarkTask(:final task):
        _markNow(game.tasks[task], action);
      case UndoMark():
        _set(() {
          // Whatever the result meant to the mode (crowns) is taken back too.
          if (_effects?.undo case final undo?) {
            undo();
            _saveSettings();
          }
          _effects = null;
          game.apply(action);
        });
      case NextRound(:final chapter):
        final midRound = _inGame &&
            game.outcome == RoundOutcome.inProgress &&
            _round.king != null;
        if (chapter != null) {
          _progress.chronicle.startAttempt(chapter);
          _saveSettings();
        }
        _set(() {
          game.apply(action, setup: _nextRoundSetup);
          if (midRound) _decreeReadFor = game.dealId; // already read this round
          _resetTable();
        });
      case RetryRound():
      case Redeal():
        _set(() {
          game.apply(action, setup: _nextRoundSetup);
          _resetTable();
        });
    }
  }

  /// Gives a task to a seat, as dropping it there would: sends the move.
  void _assignTask(RoundTask t, int seat) {
    final i = game.tasks.indexOf(t);
    if (i < 0) return;
    _link.send(PickTask(seat, i));
  }

  void _assignTaskNow(RoundTask t, int seat) {
    _set(() {
      final wasPicking = _round.pickTurn != null;
      _round.apply(PickTask(seat, game.tasks.indexOf(t)));
      // The last task taken: play begins.
      if (wasPicking && _round.allTaken) _play.forward(from: 0);
      _table.layoutOwned(_geo);
    });
  }

  /// [seat] passes on picking a task: sends the move.
  void _pass(int seat) {
    if (!_round.canPass(seat)) return;
    _link.send(Pass(seat));
  }

  void _passNow(int seat) {
    if (seat != _you) {
      _quip(seat, 'I\u2019ll pass for now.');
      _showSnack('${game.players[seat].name} passes', context.skin.feltDeep);
    }
    _set(() => _round.apply(Pass(seat)));
  }

  /// The number announced for an "exactly X tricks" task: sends the move.
  void _announce(RoundTask t, int x) {
    final i = game.tasks.indexOf(t);
    if (i < 0 || t.owner == null) return;
    _link.send(Announce(t.owner!, i, x));
  }

  /// Plays a card: sends the move, which plays it when it comes back.
  void _playCard(int seat, PlayingCard card) => _link.send(PlayCard(seat, card));

  /// Plays a card on the table. When it finishes a trick, the trick stays
  /// a moment, sweeps to the winner, and then the tasks are judged.
  void _playCardNow(int seat, PlayingCard card) {
    // The table turns the cards over at its own pace: see _judgeTasks.
    final trick = _round.apply(PlayCard(seat, card), judge: false);
    if (trick == null) {
      _set(() {});
      return;
    }
    _set(() {
      _lastTrick = trick;
      _collecting = false;
    });
    // The tutorial holds each trick longer, so the coach can explain it;
    // a round playing itself out moves briskly.
    final pause = game.isTutorial
        ? HomePageState.trickPause * 3
        : _autoPlaying
            ? HomePageState.trickPause * 0.4
            : HomePageState.trickPause;
    _trickTimers.add(Timer(pause * 0.6, () {
      if (mounted) _set(() => _collecting = true);
    }));
    _trickTimers.add(Timer(pause, () {
      if (!mounted || !_digital) return;
      _set(() {
        _lastTrick = null;
        _collecting = false;
      });
      final c = _round;
      final more = c.tricks.length < c.totalTricks;
      // A round playing itself out is judged once, at the end. And when
      // the round is won already with cards to spare, it plays out first.
      if (!(_autoPlaying && more) && !(more && _maybeAutoFinish())) {
        _judgeTasks().then((_) {
          if (!mounted) return;
          if (game.outcome != RoundOutcome.inProgress) {
            if (_autoPlaying) _set(() => _autoPlaying = false);
          }
        });
      }
      if (_wantsToSpeak && game.outcome == RoundOutcome.inProgress) {
        _wantsToSpeak = false;
        _speak();
      }
    }));
  }

  /// Marks each task done or failed from the tricks so far (game/judge.dart
  /// decides; the cards turn over here, several done at once one after
  /// another).
  Future<void> _judgeTasks() async {
    var flipped = 0;
    for (final flip in _round.judge()) {
      if (game.outcome != RoundOutcome.inProgress) break;
      if (!mounted || !game.tasks.contains(flip.task)) continue;
      // Several done at once turn over one after another.
      if (flip.status == TaskStatus.completed && flipped++ > 0) {
        await Future<void>.delayed(HomePageState.flipStagger);
        if (!mounted || !game.tasks.contains(flip.task)) continue;
      }
      _flipNow(flip);
    }
    // Nothing to undo when the cards decided.
    game.lastMark = null;
  }

  /// Turns a task over as the judge decided, and shows the result when
  /// that settles the round.
  void _flipNow(TaskFlip flip) {
    _set(() {
      _round.flip(flip);
      _markFeedback(flip.task);
      if (game.recordOutcomeIfFinished()) _roundSettled();
    });
  }
}
