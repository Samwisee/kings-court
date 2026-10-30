part of 'table_page.dart';

/// Starting games: saves and settings, setup, the tutorial's lessons and the chronicle's chapters.
extension _Setup on HomePageState {
  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final best = prefs.getInt(HomePageState._bestKey) ?? 0;
      final chronicleRaw = prefs.getString(HomePageState._chronicleKey);
      final progress = chronicleRaw == null
          ? ChronicleProgress()
          : ChronicleProgress.fromJson(
              jsonDecode(chronicleRaw) as Map<String, dynamic>);
      Sfx.enabled = prefs.getBool(HomePageState._soundKey) ?? true;
      _upright = prefs.getBool(HomePageState._uprightKey) ?? false;
      Settings.fourColourSuits = prefs.getBool(HomePageState._suitsKey) ?? false;
      _showKeys = prefs.getBool(HomePageState._keysKey) ?? false;
      await GameLog.load(prefs);
      final skin = prefs.getString(HomePageState._skinKey);
      if (skin != null && mounted) SkinScope.choose(context, skinById(skin));
      final saves = await readSaves(prefs);
      // Anyone with a saved game has played already.
      _tutorialDone = (prefs.getBool(HomePageState._tutorialDoneKey) ?? false) || saves.isNotEmpty;
      if (!mounted) return;
      _set(() {
        _bestStreak = best;
        _progress = Progress(chronicle: progress);
        _saves = saves;
      });
      // Back to a game the app was closed in, or into one an invite link is for.
      final (:room, :invited) = await RoomPlay.onOpen(open: HomePageTestHooks.rooms, address: HomePageTestHooks.address);
      if (room != null) mounted && !_inGame ? _playOnline(room) : room.dispose();
      if (invited != null && mounted) _set(() { _online = invited; _setupArgs = (mode: null, chapter: null); });
    } catch (_) {
      // No saved game (or storage unavailable): start fresh.
    }
  }

  /// Saves Chronicle progress and the sound setting.
  Future<void> _saveSettings() async {
    final skin = context.skin.id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(HomePageState._skinKey, skin);
      await prefs.setString(HomePageState._chronicleKey, jsonEncode(_progress.chronicle.toJson()));
      await prefs.setBool(HomePageState._soundKey, Sfx.enabled);
      await prefs.setBool(HomePageState._uprightKey, _upright);
      await prefs.setBool(HomePageState._suitsKey, Settings.fourColourSuits);
      await prefs.setBool(HomePageState._keysKey, _showKeys);
      await GameLog.save(prefs);
      await prefs.setBool(HomePageState._tutorialDoneKey, _tutorialDone);
    } catch (_) {}
  }

  /// Starts (or retries) a Chronicle chapter with the same players: sends
  /// the action.
  void _beginChapter(int chapter) => _link.send(NextRound(_you, chapter: chapter));

  /// Picks up a saved game exactly where it was left.
  void _continueSaved(SavedGame saved) {
    Analytics.event(['continue', saved.game.mode.name]);
    _leaveRoom();
    final g = saved.game;
    final data = saved.data;
    _set(() {
      game = g;
      // Saves from before the target was part of the game kept it beside.
      if (data['targetPoints'] case final int t when !saved.hasTarget) {
        g.target = t.clamp(1, maxTarget);
      }
      _setupCount = g.players.length;
      _setupTarget = g.target;
      _resetTable();
      _table.restore(data, g); // already on the table: no re-deal
      _saves = [for (final s in _saves) if (s.game.mode != g.mode) s];
    });
    _keepAwake(true);
    // A trick won just before the game was closed still needs judging.
    if (_digital) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _playing) _judgeTasks();
      });
    }
  }

  void _startGame(int count, int target, List<String> names, GameMode mode,
      {bool surprise = false,
      bool roles = true,
      bool digital = false,
      int? chapter,
      int lesson = 0}) {
    _leaveRoom();
    if (chapter != null) {
      target = chronicle[chapter].points;
      _progress.chronicle.startAttempt(chapter);
      _saveSettings();
    }
    // Leaving a round part-way for a new game counts as giving up on it.
    if (_inGame && !game.isTutorial && game.outcome == RoundOutcome.inProgress) {
      Analytics.event(['left', game.mode.name, roundBucket(game.roundNumber)]);
    }
    Analytics.event([
      'start',
      mode.name,
      '${count}p',
      digital ? 'screen' : 'table',
      if (mode != GameMode.tutorial && mode != GameMode.dynasty) roles ? 'roles' : 'plain',
    ]);
    _set(() {
      _setupCount = count;
      _setupTarget = target;
      // The tutorial's courtiers are always the same: you, the Duke and
      // the Bishop, each with their house's token.
      final tutorial = mode == GameMode.tutorial;
      final setup = GameSetup(
          mode: mode,
          names: names.take(count).toList(),
          target: target,
          seed: HomePageTestHooks.seed ?? math.Random().nextInt(1 << 30),
          digital: digital,
          surprise: surprise,
          roles: roles,
          chapter: chapter,
          lesson: lesson,
          courtiers: tutorial ? tutorialHouses : null,
          botNames: tutorial ? tutorialCourtiers : null);
      game = setup.start(modeOf(mode).rules, you: _you)..bestStreak = _bestStreak;
      _resetTable();
      // A new game takes the place of any saved game of the same kind.
      _saves = [for (final s in _saves) if (s.game.mode != mode) s];
    });
    _keepAwake(true);
  }

  /// The tutorial: a few pages of rules before each lesson, then the
  /// lesson that plays them out (see tutorial.dart).
  Future<void> _startTutorial() => _openSection(0);

  /// Opens the tutorial's reading section [i] (the pages before lesson [i],
  /// or the closing pages after the last lesson), then plays on from it:
  /// lesson [i], or out of the tutorial. Back on its first page returns to
  /// wherever you were.
  Future<void> _openSection(int i) async {
    final closing = i >= lessons.length;
    final String? r;
    if (closing) {
      r = await showTutorialPages(context,
          pages: outroPages,
          heading: 'Part ${lessons.length + 1} of ${lessons.length + 1}',
          finishLabel: 'Finish');
    } else {
      r = await _lessonPages(i);
    }
    if (!mounted) return;
    // Leaving, or done: out of the tutorial (if a lesson was under way).
    if (r == 'quit' || (closing && r == 'go')) {
      if (_inGame && game.isTutorial) await _finishTutorial();
      return;
    }
    if (r != 'go') return;
    if (_inGame && game.isTutorial) {
      _shuffleTasks(lesson: i);
    } else {
      _beginLesson(i);
    }
  }

  /// The pages read before lesson [i].
  Future<String?> _lessonPages(int i) => showTutorialPages(context,
      pages: lessons[i].pages,
      heading: 'Part ${i + 1} of ${lessons.length + 1}',
      finishLabel: 'Play lesson ${i + 1}');

  /// Starts tutorial lesson [i] (see tutorial.dart): three seats, you as
  /// King, cards on screen.
  void _beginLesson(int i) {
    _set(() => _setupArgs = null);
    _startGame(3, 1, tutorialCourtiers, GameMode.tutorial,
        digital: true, lesson: i);
  }

  /// On to the next section's reading, then its lesson.
  Future<void> _nextLesson() => _openSection(game.lesson + 1);

  /// Leaves the tutorial for the welcome table, and offers a real game.
  /// Wears [skin]: everything that reads the skin depends on it, so it's
  /// all drawn again in the new one (the painters compare their skin too).
  /// Saved once the page is under it.
  bool _wear(Skin skin) {
    if (!SkinScope.choose(context, skin)) return false;
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _saveSettings() : null);
    return true;
  }

  /// Back to the front page: the game is kept (Continue takes it up), an
  /// online one left.
  Future<void> _mainMenu() async {
    _leaveRoom();
    await _ctrl.saveNow();
    _botTimer?.cancel();
    _botTimer = null;
    if (!mounted) return;
    _set(() {
      game = GameState();
      _resetTable();
    });
    _keepAwake(false);
    // Every saved game, this one among them, to carry on with.
    await _loadSaved();
  }

  Future<void> _finishTutorial() async {
    Analytics.event(['tutorial', 'finished']);
    _tutorialDone = true;
    unawaited(_saveSettings());
    await _mainMenu();
    if (!mounted) return;
    final play = await showReadyDialog(context);
    if (play ?? false) {
      if (mounted) _showSetupDialog();
    }
  }

  /// The card the tutorial suggests on this trick, if it's your turn.
  PlayingCard? get _tutorialHint => game.isTutorial &&
          _digital &&
          _round.hasCards &&
          game.lesson < lessons.length
      ? lessons[game.lesson].hint(_round.tricks.length)
      : null;

  void _resetTable() {
    _table.reset();
    _tasks.landing.clear();
    _afterCrown.clear();
  }

  /// New tasks: a new round once this one is over (to [target] points, or
  /// the next lesson), or the round in progress dealt again. Sends the
  /// action.
  void _shuffleTasks({int? target, int? lesson}) {
    if (_mayDeal) _link.send(NextRound(_you, target: target, lesson: lesson));
  }

  /// The same tasks again in a new round: sends the action.
  void _retryRound() {
    if (_mayDeal) _link.send(RetryRound(_you));
  }

  /// Opens the New Game panel on the table.
  void _showSetupDialog(
      {GameMode? startMode, int? startChapter, bool continuing = false}) {
    _set(() {
      _setupArgs = (mode: startMode, chapter: startChapter);
      _setupContinuing = continuing;
    });
  }

  void _closeSetup() => _set(() {
        _setupArgs = null;
        _online = null;
      });

  void _startFromSetup(SetupResult r) {
    if (MediaQuery.disableAnimationsOf(context) || !CharacterToken.alive) return _beginFromSetup(r);
    Sfx.fanfare();
    // The table's felt drawn now, before the walk in moves, so the walk in
    // doesn't stop to draw it when the table appears beneath it.
    FeltLight.ready(context.skin);
    // The crown stays for the King on screen, the game set out beneath it;
    // the tutorial's pages come up over the felt once it's gone.
    final tutorial = r.mode == GameMode.tutorial;
    void begin() { if (mounted) _beginFromSetup(r); }
    _walkIn.start(
        crowning: r.digital && !tutorial,
        stillDue: () => mounted && _inGame && _choosingKing && _crowning == null,
        onDone: tutorial ? begin : null);
    Timer(const Duration(milliseconds: 560), () => mounted && tutorial ? _ui(() => _setupArgs = null) : begin());
  }

  void _beginFromSetup(SetupResult r) {
    _set(() => _setupArgs = null);
    if (r.mode == GameMode.tutorial) {
      _startTutorial();
      return;
    }
    _startGame(r.count, r.target, r.names, r.mode,
        surprise: r.surprise,
        roles: r.roles,
        digital: r.digital,
        chapter: r.chapter);
  }

  Widget _buildSetupPanel() {
    final args = _setupArgs!;
    return SetupPanel(
      players: game.players,
      playerCount: _setupCount,
      targetPoints: _setupTarget,
      mode: args.mode ?? game.mode,
      surprise: game.surprise,
      roles: game.roles,
      chapter: args.chapter ?? _progress.chronicle.nextChapter,
      progress: _progress.chronicle,
      canCancel: true,
      onCancel: _closeSetup,
      onStart: _startFromSetup,
      // From the front page, saved games to carry on with.
      saves: _setupContinuing ? _saves : const [],
      onContinue: (save) {
        _closeSetup();
        _continueSaved(save);
      },
      // On-screen cards unless the game being replaced used a real deck.
      digital: !_inGame || game.digital,
      newPlayer: !_tutorialDone,
      onOnline: hasService || HomePageTestHooks.rooms != null
          ? () => _set(() => _online = '')
          : null,
      onSound: (on) {
        _set(() => Sfx.enabled = on);
        _saveSettings();
      },
    );
  }

  /// Changes the points target mid-game. Players and the King stay; the
  /// tasks are re-dealt to match the new target.
  Future<void> _showPointsDialog() async {
    final target = await showPointsDialog(context, current: game.target);
    if (target == null || !mounted) return;
    // The round is dealt again from the start, cards, tasks and all, for
    // the new target: whoever's dealt the King card is King.
    if (_mayDeal) _link.send(Redeal(_you, target));
  }

  /// Continue on the welcome screen: the saved games, to pick one up.
  Future<void> _showContinue() async {
    try {
      // A save still waiting goes in first, so the list is up to date.
      if (_ctrl.savePending) await _ctrl.saveNow();
      final saves = await readSaves(await SharedPreferences.getInstance());
      if (mounted) _ui(() => _saves = saves);
    } catch (_) {}
    if (!mounted) return;
    if (_saves.length == 1) {
      _continueSaved(_saves.first);
    } else if (_saves.isNotEmpty) {
      _showSetupDialog(continuing: true);
    }
  }
}
