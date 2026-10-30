part of 'table_page.dart';

/// Whose turn it is and what happens next: dealing, the bots thinking, playing on by itself when the rest is certain.
extension _Turns on HomePageState {
  /// After a trick: if every task is done already with cards still in
  /// hand, play the round out (and judge the tasks at the end). True when
  /// it starts.
  bool _maybeAutoFinish() {
    if (_autoPlaying || !_playing || game.isTutorial) return false;
    if (!_round.canPlayOut) return false;
    _botTimer?.cancel();
    _botTimer = null;
    _set(() {
      _autoPlaying = true;
      _autoDeal = game.dealId;
      _queued = null;
    });
    // The round is won now: its card comes up, and the rest of the cards
    // play out behind it.
    _judgeTasks();
    _trickTimers.add(Timer(const Duration(milliseconds: 700), _autoStep));
    return true;
  }

  void _autoStep() {
    if (!mounted || !_autoPlaying) return;
    final c = _round;
    if (game.dealId != _autoDeal) {
      // A new round or game began meanwhile: hand play back.
      _set(() => _autoPlaying = false);
      _scheduleBot();
      return;
    }
    // Every card played: the last trick's pause ends the play-out.
    if (c.tricks.length >= c.totalTricks) return;
    if (_lastTrick == null) {
      // Online, each device plays out its own seat (the host, the rest);
      // once per card, however long it takes to come back.
      final play = _host.playOutStep(game);
      final now = Host.moment(game);
      if (play != null && now != _autoSent && (play.seat == _you || (_hostsTable && _host.plays(play.seat)))) {
        _autoSent = now;
        _link.send(play);
      }
    }
    _trickTimers.add(Timer(HomePageState.autoPlayStep, _autoStep));
  }

  /// Deals hands for a new round (or after a reload with an old deal), and
  /// lets the King card choose the King.
  void _syncCards() {
    if (!_digital || !_inGame) return;
    if (dealRound(game, rigged: _mode.riggedDeal(game))) {
      _lastTrick = null;
      _collecting = false;
      _revealing = false;
      _wantsToSpeak = false;
    }
    // No task cards to deal onto a circle: the round is ready once the King
    // is crowned and any decree is read.
    if (!_choosingKing && !_decreePending && _table.dealtFor != game.dealId) {
      _table.dealtFor = game.dealId;
    }
    if (_choosingKing && _hostsTable && _crowning == null && _crownTimer == null) {
      // Long live the King first; the tasks are shuffled out after.
      _crownTimer = Timer(const Duration(milliseconds: 350), () {
        _crownTimer = null;
        final holder = _round.kingCardHolder;
        if (mounted && _choosingKing && holder != null) _sendCrown(holder);
      });
    }
  }

  void _scheduleBot() {
    if (_openingPick && _room != null && !_speakPromptDue && _round.problem(Ready(_you)) == null) _link.send(Ready(_you));
    _room?.watch(Host.moment(game), yours: _yourPick || _yourPlay || _speakPromptDue, standIn: _standIn,
        warn: (words) => _showSnack(words, context.skin.feltDeep));
    if (_queued != null && _yourPlay) {
      final card = _queued!;
      _queued = null;
      if (_round.legalFor(_you).contains(card)) {
        scheduleMicrotask(() {
          if (mounted && _yourPlay) _playCard(_you, card);
        });
        return;
      }
    }
    // You asked to speak: once play is between tricks, stop for you.
    if (_wantsToSpeak &&
        !_revealing &&
        _playing &&
        _round.current.isEmpty &&
        _lastTrick == null) {
      _wantsToSpeak = false;
      scheduleMicrotask(() {
        if (mounted) _speak();
      });
      return;
    }
    if (!_digital || _botTimer != null || _host.busy) return;
    // Before anyone takes a task, the table pauses a moment so a card can
    // be shown first.
    final delay = game.isTutorial ? HomePageState.botDelay * 2 : HomePageState.botDelay;
    _botTimer = Timer(delay, () {
      _botTimer = null;
      if (mounted) _botStep();
    });
  }

  /// Picking begins: courtiers may show a card a task on the table needs,
  /// then the first pick is made.
  void _startChoosing() {
    _set(() => _speakAskedFor = game.dealId);
    if (_round.problem(Ready(_you)) == null) _link.send(Ready(_you));
    if (_hostsTable) _host.openingShows(game).forEach(_link.send);
  }

  Future<void> _botStep() async {
    if (_host.busy) return;
    final acted = await _botThink();
    if (acted && mounted) _scheduleBot();
  }

  /// Returns true when a bot acted, so the next one can be scheduled.
  /// What the move is comes from game/host.dart; here is only whether a
  /// courtier may move right now, given what the screen is doing.
  Future<bool> _botThink() async {
    if (_autoPlaying ||
        _revealing ||
        _speakPromptDue ||
        (_wantsToSpeak && _playing && _round.current.isEmpty)) {
      return false;
    }
    if (!Host.ready(game, dealtFor: _table.dealtFor) ||
        _othersDeciding ||
        _crowning != null ||
        _decreePending ||
        _table.dragging != null ||
        _lastTrick != null) {
      return false;
    }
    // Online, away from the host: nobody here but you to ask.
    if (!_hostsTable) {
      if (yourNumberDue(_round, you: _you) case final i?) unawaited(_askX(game.tasks[i]));
      return false;
    }
    _host.bot.budget = HomePageState.botBudget;
    _host.script = _mode.script(game);
    final turn = await _host.act(game, still: () => mounted);
    // Nothing may have moved while the bot thought; if it did, the next
    // turn will think again.
    if (turn.stale) return true;
    switch (turn.decision) {
      case null:
        return false;
      case YourAnnouncement(:final task):
        // Yours to say; someone else's online, said on their device.
        if (game.tasks[task].owner == _you) unawaited(_askX(game.tasks[task]));
        return false;
      default:
        return true;
    }
  }

  /// Asks how many tricks you'll win for an "exactly X" task.
  Future<void> _askX(RoundTask task) async {
    if (_askingX) return;
    _askingX = true;
    // The King card always wins its trick, so whoever holds it wins at
    // least one.
    final least = _round.hands[_you].contains(PlayingCard.king) ? 1 : 0;
    final chosen = await showAnnounceDialog(context,
        text: task.cardText(game.players.length),
        least: least,
        totalTricks: _round.totalTricks);
    _askingX = false;
    if (!mounted || !_digital) return;
    _announce(task, chosen);
  }
}
