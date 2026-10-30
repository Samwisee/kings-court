part of 'table_page.dart';

/// What a player does at the table: crowning, dragging tasks, marking them, and what the table says back.
extension _Play on HomePageState {
  /// A haptic tap where the device supports it.
  void _haptic(Future<void> Function() feedback) {
    try {
      feedback().catchError((Object _) {});
    } catch (_) {}
  }

  /// The speech token at a real table: sends the action.
  void _toggleSpoke(int seat) {
    final action = Speak(seat, on: !_round.spoke[seat]);
    final why = game.problem(action);
    if (why != null) {
      _showSnack(why, context.skin.feltDeep);
      return;
    }
    _haptic(HapticFeedback.selectionClick);
    _link.send(action);
  }

  /// Crowns [index]: sends the action (the King card's holder on screen, a
  /// tapped seat at a real table).
  void _sendCrown(int index) {
    if (_crowning != null || game.problem(Crown(_you, index)) != null) return;
    _link.send(Crown(_you, index));
  }

  /// The crowning's flourish: the crown flies from the deck to the seat and
  /// lands with a burst of gold, and the Crown is applied as it lands (so
  /// the table keeps "choosing the King" until then); then the tasks are
  /// dealt.
  void _crownKing(int index) {
    if (_crowning != null) return;
    final fromCentre = _walkIn.waiting;
    _set(() {
      _crowning = index;
      _crownFromCentre = fromCentre;
    });
    // The walk-in's crown becomes this one, in the same place, once the
    // walk-in is done. It already sounded the fanfare.
    _walkIn.handOver(() {
      if (mounted && _crowning == index) _flyCrown(fromCentre);
    });
  }

  void _flyCrown(bool fromCentre) {
    final index = _crowning!;
    _set(() {});
    if (!fromCentre) Sfx.fanfare();
    _crown.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _haptic(HapticFeedback.heavyImpact);
      _set(() {
        final crown = Crown(_you, index);
        if (game.problem(crown) == null) game.apply(crown);
        _crowning = null;
        _crownFromCentre = false;
      });
      final held = List.of(_afterCrown);
      _afterCrown.clear();
      held.forEach(_onAction);
    });
  }

  /// Lays the round's cards out from the deck in the middle of the table.
  void _dealCards() => _table.dealCards(_geo, game.tasks, game.dealId);

  void _onDragStart(RoundTask t) => _ui(() => _table.dragStart(t));

  /// The page rebuilds only when the seat under the card changes; otherwise
  /// the card alone redraws.
  void _onDragUpdate(RoundTask t, Offset delta) {
    final hover = _table.dragMove(t, delta, _geo, _round.mayTake);
    if (hover != _table.hoverSeat) {
      _ui(() => _table.hoverSeat = hover);
    } else {
      _table.taskDragTick.value++;
    }
  }

  void _onDragEnd(RoundTask t) {
    if (_digital) {
      final p = _table.toPx(_table.pos[t]!);
      final seat = _geo.seatAt(p);
      final kingsCommand = _round.decree == Decree.kingsCommand;
      final allowed = _yourPick &&
          t.owner == null &&
          seat != null &&
          (seat == _you || kingsCommand) &&
          _round.mayTake(t, seat);
      if (!allowed) {
        _set(() {
          _table.dragging = null;
          _table.hoverSeat = null;
          _table.layoutOwned(_geo);
        });
        if (seat != null) {
          _showSnack(
              !_yourPick
                  ? 'Wait for your turn to pick'
                  : t.owner != null
                      ? 'Tasks stay with whoever took them'
                      : !_round.mayTake(t, seat)
                          ? _round.whyCantTake(t, seat)!
                          : 'Take tasks onto your own seat',
              context.skin.feltDeep);
        }
        return;
      }
      _set(() {
        _table.dragging = null;
        _table.hoverSeat = null;
      });
      _assignTask(t, seat);
      return;
    }
    // A real table: the task goes to the seat it's dropped on, or back
    // onto the table. Either is sent as the move it is.
    final p = _table.toPx(_table.pos[t]!);
    final seat = _table.dropSeat(_geo, p);
    final i = game.tasks.indexOf(t);
    final taken = seat != null && _round.mayTake(t, seat);
    _set(() {
      _table.dragging = null;
      _table.hoverSeat = null;
      if (!taken && seat != null) {
        // Dropped on the King, who can't take it: leave it just inside.
        _table.pos[t] = _table.toFrac(_geo.clampToTable(
            Offset.lerp(_geo.seatCenter(seat), _geo.center, 0.45)!));
      }
    });
    if (taken) {
      if (t.owner != seat) _haptic(HapticFeedback.selectionClick);
      _link.send(PickTask(seat, i));
    } else if (t.owner != null) {
      _link.send(ReturnTask(_you, i));
    }
    if (seat != null && !taken) {
      _haptic(HapticFeedback.heavyImpact);
      _showSnack(_round.whyCantTake(t, seat)!, context.skin.lost);
    }
  }

  /// A courtier at [seat] calls out, for a moment.
  void _quip(int seat, String text) {
    if (text.isEmpty) return;
    _quips[seat] = text;
    _trickTimers.add(Timer(const Duration(milliseconds: 2800), () {
      if (mounted && _quips[seat] == text) _set(() => _quips.remove(seat));
    }));
  }

  /// Marks a task done or failed by hand (choosing its mark again clears
  /// it): sends the action.
  void _mark(RoundTask task, TaskStatus status) {
    final i = game.tasks.indexOf(task);
    if (i < 0) return;
    _link.send(MarkTask(_you, i, status));
  }

  void _markNow(RoundTask task, MarkTask action) {
    _set(() {
      final settled = game.apply(action);
      _markFeedback(task);
      if (settled) _roundSettled();
    });
  }

  /// A buzz for a task failed, a tap for one done.
  void _markFeedback(RoundTask task) {
    if (task.isFailed) {
      _haptic(HapticFeedback.vibrate);
    } else if (task.isCompleted) {
      _haptic(HapticFeedback.mediumImpact);
    }
  }

  /// The round's result was just recorded: what it means to the mode, the
  /// sounds, and the outcome card coming up.
  void _roundSettled() {
    if (_hostsTable) { // online, the host's device keeps the record
      _rounds.over(game, _link.history,
          you: _digital ? _you : null,
          people: _room?.people());
    }
    final result = _round.result!;
    final won = result.won;
    Analytics.event(
        ['round', game.mode.name, _mode.roundLabel(game), won ? 'won' : 'lost']);
    if (won) {
      Sfx.win();
    } else {
      Sfx.lose();
    }
    // What the result means to the mode: crowns, the next target.
    final effects = _mode.afterRound(game, result, _progress);
    _effects = effects;
    if (effects.crowns > 0) _saveSettings();
    _nextTarget = effects.nextTarget;
    if (game.bestStreak > _bestStreak) _bestStreak = game.bestStreak;
    // The last tasks turn over first, then the result comes up.
    _outcome.value = 0;
    _outcomeHold.duration = Duration(milliseconds: won ? 800 : 450);
    _outcomeHold.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _set(() {});
      _outcome.forward(from: 0);
    });
  }

  void _showSnack(String text, Color color) {
    if (_digital && _inGame) {
      _toastTimer?.cancel();
      _ui(() => _toast = text);
      _toastTimer = Timer(const Duration(milliseconds: 2600), () {
        if (mounted && _toast == text) _ui(() => _toast = null);
      });
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ));
  }

  /// Tapping a seat with roles: the courtier's house and their card reveal
  /// (mark it used), facing the player.
  Future<void> _showCourtier(int seat) async {
    if (seat >= game.courtiers.length) return;
    await showCourtierCard(
        context,
        CourtierCard(
          seat: seat,
          courtier: game.courtiers[seat],
          player: game.players[seat],
          round: _round,
          quarterTurns: _geo.edge(seat),
          onScreen: _digital,
          choosingKing: _choosingKing,
          you: _you,
          onSpeak: _mayAskToSpeak ? _speak : null,
          onToggleReveal: (on) {
            _haptic(HapticFeedback.selectionClick);
            _link.send(Speak(seat, on: on));
          },
        ));
  }

  /// The close-up of a task, turned to face the player who holds it.
  Future<void> _showTaskDetail(RoundTask task, Offset tapGlobal) async {
    // An owned task's close-up turns to face its owner; a loose task's
    // stays upright.
    final quarterTurns = task.owner == null ? 0 : _geo.edge(task.owner!);
    await showTaskCloseUp(
        context,
        TaskCloseUp(
          task: task,
          round: _round,
          players: game.players,
          quarterTurns: quarterTurns,
          onScreen: _digital,
          progress: _progressOf(task),
          struck: _wonNamed(task),
          status: _statusOf(task),
          cards: _cardStates(task),
          onTake: _yourPick && task.owner == null && _mayTake(task)
              ? () => _takeTask(task)
              : null,
          onMark: (status) => _mark(task, status),
        ));
  }

  /// Puts the last done/failed mark back, for a mis-tap that ended the
  /// round by mistake: sends the action. The round's result is taken back
  /// off the record when it comes back.
  void _undoLastMark() {
    if (game.lastMark == null) return;
    _link.send(UndoMark(_you));
  }
}
