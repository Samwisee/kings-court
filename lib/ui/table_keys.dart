part of 'table_page.dart';

/// The keyboard: moving between the tasks, the hand and the bar, and what each key does.
extension _Keys on HomePageState {
  /// Keys (see [_shortcuts]): ← and → choose a card in your hand and
  /// Enter plays it; S starts (or cancels) showing a card; T or the space
  /// bar brings up the card tracker, and while it's up, holding the space
  /// bar hides it to see the table; Escape puts it away.
  bool _onKey(KeyEvent e) {
    final key = e.logicalKey;
    if (e is KeyUpEvent) {
      if (key == LogicalKeyboardKey.space && _spaceTimer != null) {
        // A short tap puts the tracker away; a hold only hid it.
        _spaceTimer!.cancel();
        _spaceTimer = null;
        if (_trackerPeek) {
          _ui(() => _trackerPeek = false);
        } else if (_trackerOpen) {
          _closeTracker();
        }
        return true;
      }
      return false;
    }
    if (!tableTakes(e)) return false;
    // Not while typing (player names), or off the on-screen game.
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) return false;
    // Nor under a dialog or another page.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (!mounted ||
        !_inGame ||
        _setupArgs != null ||
        !_digital ||
        !_round.hasCards) {
      return false;
    }
    if (key == LogicalKeyboardKey.space && _trackerOpen) {
      // Held past a moment: hide it to see the table, until let go.
      _spaceTimer?.cancel();
      _spaceTimer = Timer(const Duration(milliseconds: 220), () {
        if (mounted && _trackerOpen) _ui(() => _trackerPeek = true);
      });
      return true;
    }
    if (key == LogicalKeyboardKey.space) {
      _showCardTracker();
      return true;
    }
    if (_trackerOpen) {
      // The arrows step through the deck and the others' hands.
      if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
        _trackerKey.currentState?.step(key == LogicalKeyboardKey.arrowRight ? 1 : -1);
        return true;
      }
      return false;
    }
    if (key == LogicalKeyboardKey.keyS) {
      // While the table asks whether you'll show a card, S again skips.
      if (_speakPromptDue) {
        _skipShowing();
        return true;
      }
      if (!(_mayAskToSpeak || _revealing)) return false;
      _speak();
      return true;
    }
    final hand = _round.hands.length > _you ? _round.hands[_you] : const <PlayingCard>[];
    // A card by its key: 1 to 9, 0, - and = along the top row, then Q W E.
    final keyAt = cardKeys.indexOf(key);
    if (keyAt >= 0) {
      if (keyAt >= hand.length) return false;
      final play = _handPlays[hand[keyAt]];
      if (play == null) return false;
      _ui(() {
        _kbRow = 0;
        _kbCard = hand[keyAt];
        final r = _handRects[hand[keyAt]];
        final area = _rectOn(_handKey);
        if (r != null && area != null) _kbLast = r.shift(area.topLeft);
      });
      play();
      return true;
    }
    // The arrows move round the table as it looks: up from your hand to
    // the Skip or Pass button (when there is one), then up through the
    // rows of tasks; left and right along a row, running on round. They
    // only stop on tasks you may take and cards you may play (or show),
    // and always go to whatever is nearest the last thing chosen.
    final open = [
      for (final t in game.tasks)
        if (t.owner == null &&
            (!_yourPick || (_mayTake(t) && _round.mayTake(t, _you))))
          t
    ];
    final stops = _kbStops(open, kbCards(_round, _you, showing: _revealing || _speakPromptDue));
    if (stops.isEmpty) return false;
    final here = _kbHere(stops);
    void go(KbStop to) => _ui(() {
          _kbRow = to.row;
          if (to.item case final RoundTask t) _kbTask = t;
          if (to.item case final PlayingCard c) _kbCard = c;
          _kbLast = to.rect;
        });
    if (arrowStep(key) case final step?) {
      final move = arrowMove(stops,
          here: here, last: _kbLast, row: _kbRow, hand: _rectOn(_handKey), step: step);
      if (move.to case final to?) go(to);
      return move.handled;
    }
    // Enter: open the chosen task (its Take button is ready for Enter),
    // press the button, or play (or show) the chosen card.
    if (here == null) return false;
    switch (here.item) {
      case final RoundTask t:
        _showTaskDetail(t, Offset.zero);
      case final PlayingCard c:
        _handPlays[c]?.call();
      default:
        _kbButtonPress?.call();
        // The button's gone: back down to your hand.
        _ui(() => _kbRow = 0);
    }
    return true;
  }

  /// Everything the arrow keys can stop on just now, where it is.
  List<KbStop> _kbStops(List<RoundTask> open, List<PlayingCard> cards) => [
        for (final t in open)
          if (_tasks.openKeys[t] case final key?)
            if (_rectOn(key) case final r?) KbStop(1, t, r),
        // Tasks already taken, in front of whoever took them: to read
        // again (Enter opens them).
        for (final t in game.tasks)
          if (t.owner != null && !_tasks.landing.contains(t))
            if (_tasks.destKeys[t] case final key?)
              if (_rectOn(key) case final r?) KbStop(1, t, r),
        if (_kbButtonPress != null)
          if (_rectOn(_kbButtonKey) case final r?) KbStop(2, null, r),
        if (_rectOn(_handKey) case final area?)
          for (final c in cards)
            if (_handRects[c] case final r?) KbStop(0, c, r.shift(area.topLeft)),
      ];

  /// Where the arrow keys are now, if it's still there to stop on.
  KbStop? _kbHere(List<KbStop> stops) => stopAt(stops, row: _kbRow, task: _kbTask, card: _kbCard);

  /// A choice with a way out is up: show a card or Skip, take a task or
  /// Pass. The button sits beside your hand.
  bool get _barChoice =>
      (_speakPromptDue || (_round.pickTurn == _you && _round.canPass(_you))) &&
      _toast == null;

  /// What that button does, for the Enter key.
  VoidCallback? get _kbButtonPress =>
      !_barChoice ? null : _speakPromptDue ? _skipShowing : _passPick;

  /// Skip: you won't show a card before the tasks are taken.
  void _skipShowing() => _startChoosing();

  /// Pass on taking a task this time round.
  void _passPick() => _pass(_you);

  /// The shortcuts are shown (the menu setting, on a computer with room).
  bool get _keysShown =>
      _showKeys && HomePageState._desktop && MediaQuery.sizeOf(context).width >= 700;
}
