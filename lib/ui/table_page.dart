/// The table: the one page of the app, on screen or at a real table,
/// with its menus, the tutorial flow and the end of each round. Its state,
/// [HomePageState], holds the game (through the controller) and everything
/// that is about drawing it: animations, where things are, what's open.
/// The widgets it's built from are libraries under lib/ui; see README.md
/// for the map.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../engine/bot.dart';
import '../engine/cards.dart';
import '../engine/conflicts.dart';
import '../engine/decrees.dart';
import '../engine/round.dart';
import '../engine/rules.dart';
import '../engine/task_help.dart';
import '../game/actions.dart';
import '../game/bot_turn.dart';
import '../game/dealer.dart';
import '../game/host.dart';
import '../game/judge.dart';
import '../game/setup.dart';
import '../game/state.dart';
import '../modes/chronicle/chapters.dart';
import '../modes/modes.dart';
import '../modes/progress.dart';
import '../modes/tutorial/lessons.dart';
import '../net/online_table.dart';
import '../net/table_link.dart';
import '../platform/analytics.dart';
import '../platform/game_log.dart';
import '../platform/service.dart';
import '../platform/settings.dart';
import '../platform/sfx.dart';
import '../skin/skin_scope.dart';
import '../skin/skins.dart';
import '../skin/strings.dart';
import '../skin/theme.dart';
import 'bug_report.dart';
import 'cards/card_view.dart';
import 'cards/task_chip.dart';
import 'controller.dart';
import 'dialogs/courtier_card.dart';
import 'dialogs/table_dialogs.dart';
import 'dialogs/task_close_up.dart';
import 'menu/menu.dart';
import 'menu/menu_entries.dart';
import 'modes/tutorial/coach.dart';
import 'modes/tutorial/tutorial_intro.dart';
import 'online/room_play.dart';
import 'overlays/crowning.dart';
import 'overlays/decree.dart';
import 'overlays/outcome_card.dart';
import 'overlays/play_flourish.dart';
import 'round_table/geometry.dart';
import 'round_table/round_table.dart';
import 'rules/rules_page.dart';
import 'setup/saves.dart';
import 'setup/setup_panel.dart';
import 'table/dealt_task.dart';
import 'table/game_bar.dart';
import 'table/hand_bar.dart';
import 'table/hand_card.dart';
import 'table/hand_drag.dart';
import 'table/keyboard.dart';
import 'table/open_task.dart';
import 'table/seats.dart';
import 'table/table_words.dart';
import 'table/task_flights.dart';
import 'table/trick_view.dart';
import 'tracker/card_tracker.dart';
import 'tracker/tracker_overlay.dart';
import 'welcome/welcome.dart';
import 'widgets.dart';
import 'widgets/buttons.dart';

/// Speeds up the on-screen card game for widget tests.
@visibleForTesting
class HomePageTestHooks {
  static void fast() {
    HomePageState.botDelay = const Duration(milliseconds: 1);
    HomePageState.trickPause = const Duration(milliseconds: 4);
    HomePageState.autoPlayStep = const Duration(milliseconds: 2);
    HomePageState.flipStagger = const Duration(milliseconds: 2);
    HomePageState.botBudget = 30;
    CharacterToken.alive = false;
  }

  /// Parts of the page left out, so a benchmark can tell what each costs:
  /// 'table', 'hand', 'bar', 'trim'.
  static Set<String> skip = {};

  /// When set, every new game deals from this seed and the courtiers think
  /// from it too, so a run (the screenshots) comes out the same every time.
  static int? seed;

  /// Rooms to play multiplayer through, in place of the web service's.
  static SocketOpener? rooms;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// The game itself: its state, the moves, saving (ui/controller.dart).
  /// This page draws it.
  final _ctrl = GameController();
  GameState get game => _ctrl.game;
  set game(GameState g) => _ctrl.game = g;

  /// The last choices made in setup, offered again next time.
  int _setupCount = 4;
  int _setupTarget = 5;

  /// The round table's layout: where every dealt task lies, the drag, the
  /// deal.
  late final _table = RoundTableController(vsync: this);

  /// The crown's flight to the new King's seat.
  late final AnimationController _crown = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  /// The "Play!" flourish once every task has an owner.
  late final AnimationController _play = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// The win or lose flourish when a round ends.
  late final AnimationController _outcome = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  /// A pause before the round's result comes up, while the last tasks
  /// turn over.
  late final AnimationController _outcomeHold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  /// Seat being crowned while the crown animation plays.
  int? _crowning;

  /// The crown from the walk into the game is waiting in the middle of the
  /// screen to be the King's crown (so there is only ever one crown).
  bool _crownWaiting = false;

  /// This crowning's crown starts as that waiting crown.
  bool _crownFromCentre = false;

  /// The walk-in's crown has gone to the King: the walk-in no longer draws
  /// it, even while the rest of it plays out.
  bool _crownHandedOver = false;

  /// The deal whose decree has been read out (see [_decreePending]).
  int _decreeReadFor = -1;

  /// Points chosen in the end-of-round dialog for the next round.
  int _nextTarget = 10;

  /// What the round just finished meant to its mode (crowns earned, the
  /// next target), and how to take that back if its last mark is undone.
  RoundEffects? _effects;

  /// Games saved from last time, one for each way to play, newest first.
  /// Play on the welcome screen offers them.
  List<SavedGame> _saves = [];

  /// Best win streak across every game on this device.
  int _bestStreak = 0;

  /// Before save slots, one game was kept under this key. It moves to its
  /// mode's slot the first time it's loaded.
  static const _bestKey = GameController.bestKey;
  static const _chronicleKey = 'kingsCourt.chronicle';
  static const _soundKey = 'kingsCourt.sound';
  static const _uprightKey = 'kingsCourt.upright';
  static const _suitsKey = 'kingsCourt.fourColourSuits';
  static const _keysKey = 'kingsCourt.showShortcuts';
  static const _skinKey = 'kingsCourt.skin';
  static const _tutorialDoneKey = 'kingsCourt.tutorialDone';

  /// Whether this player has finished the tutorial (or played before it
  /// existed): until then, setup points them to it first.
  bool _tutorialDone = false;

  /// Desktop: the keyboard shortcuts shown beside the table.
  bool _showKeys = false;

  /// A computer with a keyboard (not a phone or tablet).
  static bool get _desktop => const [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ].contains(defaultTargetPlatform);

  /// Laptop view: everything upright instead of turned to each seat.
  bool _upright = false;

  /// The New Game panel, while it's open.
  SetupArgs? _setupArgs;

  /// Setup opened from Continue: it lists the saved games instead.
  bool _setupContinuing = false;

  /// The player's progress on this device (the Chronicle's crowns).
  Progress _progress = Progress();

  /// The way this game is played (modes/): what each round is set up
  /// with, and what its result means.
  Mode get _mode => modeOf(game.mode);

  @override
  void initState() {
    super.initState();
    _moves = _link.moves.listen((m) => _onAction(m.action));
    // What a save holds beside the game: the real table's layout.
    _ctrl.saveExtras = () => _table.saveData(game);
    _ctrl.knownBest = () => _bestStreak;
    WidgetsBinding.instance.addObserver(this);
    // Create the animation controllers now, so dispose never makes one.
    for (final c in [_table.deal, _crown, _play, _outcome, _outcomeHold, _coronation]) {
      c.value;
    }
    _loadSaved();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

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

  /// Where the arrow keys are: your hand (0), the tasks on the table (1)
  /// or the Skip or Pass button (2).
  int _kbRow = 0;
  RoundTask? _kbTask;

  /// Where the last thing chosen with the arrow keys was, so the next
  /// choice is whatever is nearest it (when a card is played or a task
  /// taken, its neighbour is chosen).
  Rect? _kbLast;

  /// The Skip or Pass button beside your hand, while it's there.
  final _kbButtonKey = GlobalKey();

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

  /// Each card in your hand, where it sits (at rest) within it.
  final Map<PlayingCard, Rect> _handRects = {};

  /// The shortcuts are shown (the menu setting, on a computer with room).
  bool get _keysShown =>
      _showKeys && _desktop && MediaQuery.sizeOf(context).width >= 700;

  /// The card chosen in your hand with the arrow keys.
  PlayingCard? _kbCard;

  /// The space bar is down while the tracker is up: a tap or a hold?
  Timer? _spaceTimer;

  /// What tapping each card in your hand does, for the Enter key.
  final Map<PlayingCard, bool Function()> _handPlays = {};

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final best = prefs.getInt(_bestKey) ?? 0;
      final chronicleRaw = prefs.getString(_chronicleKey);
      final progress = chronicleRaw == null
          ? ChronicleProgress()
          : ChronicleProgress.fromJson(
              jsonDecode(chronicleRaw) as Map<String, dynamic>);
      Sfx.enabled = prefs.getBool(_soundKey) ?? true;
      _upright = prefs.getBool(_uprightKey) ?? false;
      Settings.fourColourSuits = prefs.getBool(_suitsKey) ?? false;
      _showKeys = prefs.getBool(_keysKey) ?? false;
      await GameLog.load(prefs);
      final skin = prefs.getString(_skinKey);
      if (skin != null && mounted) SkinScope.choose(context, skinById(skin));
      final saves = await readSaves(prefs);
      // Anyone with a saved game has played already.
      _tutorialDone = (prefs.getBool(_tutorialDoneKey) ?? false) || saves.isNotEmpty;
      if (!mounted) return;
      setState(() {
        _bestStreak = best;
        _progress = Progress(chronicle: progress);
        _saves = saves;
      });
    } catch (_) {
      // No saved game (or storage unavailable): start fresh.
    }
  }

  /// Saves after every change, so closing the app mid-round loses nothing.
  /// Skipped while a card is being dragged; saved again when it's dropped.
  ///
  /// A change to what's on screen only (a menu, a toast, a drag, the
  /// tracker, a key press): rebuilds without saving or waking the game.
  void _ui(VoidCallback fn) => super.setState(fn);

  /// A menu choice, for the benchmarks (the look's switch).
  @visibleForTesting
  void debugMenuChoice(String choice) => _onMenuChoice(choice);

  /// A screen-only change, for the benchmarks.
  @visibleForTesting
  void debugUi(VoidCallback fn) => _ui(fn);

  /// What a change to the game does besides rebuilding, for the benchmarks:
  /// each part's time in milliseconds.
  @visibleForTesting
  Map<String, double> debugGameWork() {
    final sw = Stopwatch();
    double time(void Function() f) {
      sw
        ..reset()
        ..start();
      f();
      sw.stop();
      return sw.elapsedMicroseconds / 1000;
    }

    return {
      'save (scheduling)': time(_save),
      'syncCards': time(_syncCards),
      'taskFlights': time(_launchTaskFlights),
      'scheduleBot': time(_scheduleBot),
    };
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (_table.dragging == null && _drag.card == null && _inGame) _save();
    if (_digital && _inGame) {
      _syncCards();
      _launchTaskFlights();
      _scheduleBot();
    }
  }

  /// Saves the game soon (saving waits for a pause in changes, so a
  /// burst of them is written once).
  void _save() => _ctrl.changed();

  /// Put in the background or closed: write any waiting save now.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _ctrl.savePending) _ctrl.saveNow();
  }

  /// Saves Chronicle progress and the sound setting.
  Future<void> _saveSettings() async {
    final skin = context.skin.id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skinKey, skin);
      await prefs.setString(_chronicleKey, jsonEncode(_progress.chronicle.toJson()));
      await prefs.setBool(_soundKey, Sfx.enabled);
      await prefs.setBool(_uprightKey, _upright);
      await prefs.setBool(_suitsKey, Settings.fourColourSuits);
      await prefs.setBool(_keysKey, _showKeys);
      await GameLog.save(prefs);
      await prefs.setBool(_tutorialDoneKey, _tutorialDone);
    } catch (_) {}
  }

  /// Starts a Chronicle chapter directly, skipping the setup dialog.
  @visibleForTesting
  void debugStartChapter(int chapter, int players) => _startGame(
      players,
      0,
      [for (int i = 0; i < players; i++) 'Player ${i + 1}'],
      GameMode.chronicle,
      chapter: chapter);

  /// Starts (or retries) a Chronicle chapter with the same players: sends
  /// the action.
  void _beginChapter(int chapter) => _link.send(NextRound(_you, chapter: chapter));

  /// Picks up a saved game exactly where it was left.
  void _continueSaved(SavedGame saved) {
    Analytics.event(['continue', saved.game.mode.name]);
    _leaveRoom();
    final g = saved.game;
    final data = saved.data;
    setState(() {
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

  @override
  void dispose() {
    _moves.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    HardwareKeyboard.instance.removeHandler(_onKey);
    _toastTimer?.cancel();
    _trackerTimer?.cancel();
    _table.dispose();
    _drag.dispose();
    _crown.dispose();
    _coronation.dispose();
    _outcomeHold.dispose();
    _play.dispose();
    _outcome.dispose();
    _keepAwake(false);
    _botTimer?.cancel();
    _crownTimer?.cancel();
    _tasks.cancel();
    for (final t in _trickTimers) {
      t.cancel();
    }
    super.dispose();
  }

  /// Keeps the screen on during a game so the phone doesn't dim mid-trick.
  /// Silently ignored where the platform doesn't support it (e.g. tests).
  void _keepAwake(bool on) {
    try {
      (on ? WakelockPlus.enable() : WakelockPlus.disable())
          .catchError((Object _) {});
    } catch (_) {}
  }

  bool get _inGame => game.tasks.isNotEmpty;
  bool get _choosingKing => _inGame && _round.king == null;

  /// A decree waiting to be read out after the crowning.
  bool get _decreePending =>
      _inGame &&
      !_choosingKing &&
      _round.decree != null &&
      _decreeReadFor != game.dealId &&
      _table.dealtFor != game.dealId;

  bool get _readyToDeal =>
      !_choosingKing && !_decreePending && _table.dealtFor != game.dealId;

  int _points(RoundTask t) => t.points(game.players.length);

  TableGeometry get _geo => _table.geometry(
      players: game.players.length,
      textOf: (t) => t.boardText(game.players.length),
      upright: _upright || game.digital,
      dealId: game.dealId,
      skin: context.skin);

  // --------------------------------------------------------- on-screen cards
  //
  // With on-screen cards the table runs the round itself: it deals hands,
  // the King card crowns the King, bots pick tasks and play for every seat but
  // yours (seat 0), and each task marks itself as the tricks fall. Every
  // mode works the same way on top of this.

  bool get _digital => game.digital;
  /// The seat you play from: the bottom of the table. Online, the seat
  /// you joined in (see GameController.mySeat).
  int get _you => _ctrl.mySeat;

  /// The courtiers' side of the table (game/host.dart): what they do, and
  /// sending it. The page keeps only its own pauses and the timers.
  late Host _host = _newHost();
  Host _newHost() =>
      Host(bot: Bot(), you: _you, seats: _room?.seats, send: (a) => _link.send(a));
  Timer? _botTimer;
  Timer? _crownTimer;
  final _trickTimers = <Timer>[];

  /// How long bots think and a finished trick stays on the table.
  @visibleForTesting
  static Duration botDelay = const Duration(milliseconds: 700);
  @visibleForTesting
  static Duration trickPause = const Duration(milliseconds: 1300);
  static Duration flipStagger = const Duration(milliseconds: 280);

  /// Playouts per bot decision.
  static int botBudget = 900;

  /// The trick just won, held on the table, and whether it's sweeping off.
  Trick? _lastTrick;
  bool _collecting = false;
  bool _askingX = false;

  Round get _round => game.round!;

  bool get _playing =>
      _digital &&
      !_choosingKing &&
      !_decreePending &&
      _table.dealtFor == game.dealId &&
      game.outcome == RoundOutcome.inProgress &&
      _round.settled;

  bool get _yourPlay =>
      _playing && !_autoPlaying && _lastTrick == null && _round.turn == _you;

  /// Every task is done with cards still in hand: the table plays the rest
  /// of the round out by itself, quickly, like a won game of FreeCell
  /// sending its cards home.
  bool _autoPlaying = false;
  int _autoDeal = -1;
  String? _autoSent;
  static Duration autoPlayStep = const Duration(milliseconds: 140);

  /// After a trick: if every task is done already with cards still in
  /// hand, play the round out (and judge the tasks at the end). True when
  /// it starts.
  bool _maybeAutoFinish() {
    if (_autoPlaying || !_playing || game.isTutorial) return false;
    if (!_round.canPlayOut) return false;
    _botTimer?.cancel();
    _botTimer = null;
    setState(() {
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
      setState(() => _autoPlaying = false);
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
    _trickTimers.add(Timer(autoPlayStep, _autoStep));
  }

  bool get _yourPick =>
      _digital &&
      !_choosingKing &&
      !_decreePending &&
      _table.dealtFor == game.dealId &&
      _round.pickTurn == _you;

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

  /// Lets whichever bot is due act, after a short pause.
  /// A card you chose early, played as soon as it's your turn.
  PlayingCard? _queued;

  void _scheduleBot() {
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
    final delay = game.isTutorial ? botDelay * 2 : botDelay;
    _botTimer = Timer(delay, () {
      _botTimer = null;
      if (mounted) _botStep();
    });
  }

  /// Picking hasn't started: nobody has taken a task yet, and a courtier
  /// picks first.
  bool get _openingPick =>
      _digital &&
      _round.pickTurn != null &&
      _round.hasCards &&
      // Nobody has picked yet (tasks that went straight to the only player
      // who could take them don't count).
      _round.picksMade == 0;

  /// Where each open task starts from in the deal (the middle of the
  /// table), measured once per deal.
  Map<RoundTask, Offset> _dealFrom = {};
  int _dealMeasuredFor = -1;

  /// The deal the table last asked "anyone want to show a card?" for.
  int _speakAskedFor = -1;

  /// Whether to ask before picking (off in fast tests unless switched on).
  static bool askToSpeak = true;

  /// The table is waiting to hear whether you'll show a card before the
  /// first task is taken.
  bool get _speakPromptDue =>
      askToSpeak &&
      !game.isTutorial &&
      _speakAskedFor != game.dealId &&
      _openingPick &&
      _mayAskToSpeak;

  /// Picking begins: courtiers may show a card a task on the table needs,
  /// then the first pick is made.
  void _startChoosing() {
    setState(() => _speakAskedFor = game.dealId);
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
    _host.bot.budget = botBudget;
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

  // ------------------------------------------------------------ moves
  //
  // Every move at the table goes through the table link (net/table_link
  // dart): taking a task, passing, announcing a number, playing a card,
  // showing one. The move is sent, and made when it comes back. On one
  // device it comes straight back; online, it would come back from the
  // server, in the same order on every device, so every table agrees.

  /// Where moves go: this device, for now.
  TableLink get _link => _ctrl.link;
  late StreamSubscription<Move> _moves;
  final _afterCrown = <TableAction>[];

  /// Plays through [link] from now on.
  void _useLink(TableLink link) {
    _moves.cancel();
    _ctrl.useLink(link);
    _moves = link.moves.listen((m) => _onAction(m.action));
  }

  // ------------------------------------------------------------ online
  // A room (ui/online/room_play.dart): every device plays the room's moves
  // in its order; the host's device does the table's work.

  RoomPlay? _room;

  /// Multiplayer setup is open, in place of the New Game panel.
  bool _onlineSetup = false;

  /// This device moves for the table: the courtiers, the crown, the deal.
  bool get _hostsTable => _room?.hosting ?? true;

  /// Whether a person plays [seat] (online; elsewhere only you).
  bool _personAt(int seat) => seat == _you || (_room?.personAt(seat) ?? false);

  Widget _buildOnlineSetup() => RoomPlay.setup(
      open: HomePageTestHooks.rooms,
      seed: HomePageTestHooks.seed,
      onCancel: () => setState(() => _onlineSetup = false),
      onPlay: _playOnline);

  /// The room's game has started: it's dealt here as on every device.
  void _playOnline(OnlineTable table) {
    _leaveRoom();
    _crownWaiting = false;
    final room = RoomPlay(table, onChange: (news) {
      if (!mounted || _room?.room != table) return;
      _host.seats = table.seats; // the host plays anyone away
      if (news != null) _showSnack(news, context.skin.feltDeep);
      setState(() => _room!.nameSeats(game));
    });
    setState(() {
      _onlineSetup = false;
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

  /// Out of the room, back to playing on this device.
  void _leaveRoom() {
    if (_room == null) return;
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
        setState(() => _round.apply(move));
      case PlayCard(:final seat, :final card):
        _playCardNow(seat, card);
      case ShowCard(:final seat):
        setState(() {
          _round.apply(move);
          if (seat == _you) _revealing = false;
        });
      case ReturnTask():
        setState(() {
          _round.apply(move);
          _table.layoutOwned(_geo);
        });
    }
  }

  /// One of the game's actions: crowning, a mark, the next round.
  void _onGameAction(GameAction action) {
    switch (action) {
      case Crown(:final king):
        // Applied once the crown has flown to its seat (see _crownKing).
        _crownKing(king);
      case Speak():
        setState(() => game.apply(action));
      case MarkTask(:final task):
        _markNow(game.tasks[task], action);
      case UndoMark():
        setState(() {
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
        setState(() {
          game.apply(action, setup: _nextRoundSetup);
          if (midRound) _decreeReadFor = game.dealId; // already read this round
          _resetTable();
        });
      case RetryRound():
      case Redeal():
        setState(() {
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
    setState(() {
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
    setState(() => _round.apply(Pass(seat)));
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
      setState(() {});
      return;
    }
    setState(() {
      _lastTrick = trick;
      _collecting = false;
    });
    // The tutorial holds each trick longer, so the coach can explain it;
    // a round playing itself out moves briskly.
    final pause = game.isTutorial
        ? trickPause * 3
        : _autoPlaying
            ? trickPause * 0.4
            : trickPause;
    _trickTimers.add(Timer(pause * 0.6, () {
      if (mounted) setState(() => _collecting = true);
    }));
    _trickTimers.add(Timer(pause, () {
      if (!mounted || !_digital) return;
      setState(() {
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
            if (_autoPlaying) setState(() => _autoPlaying = false);
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
        await Future<void>.delayed(flipStagger);
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
    setState(() {
      _round.flip(flip);
      _markFeedback(flip.task);
      if (game.recordOutcomeIfFinished()) _roundSettled();
    });
  }

  /// The round as the table shows it (see game/judge.dart): a trick still
  /// on the table doesn't count yet.
  RoundView get _shownView => shownView(_round, trickPending: _lastTrick != null);

  /// Tricks [seat] has won, as the table shows them.
  int _shownTricksWon(int seat) => shownTricksWon(_round, seat, _lastTrick);

  /// How far along an on-screen task is ("2/4"), for the card's corner.
  /// How [t] is going, in a sentence for its close-up (on-screen cards
  /// only, once it's been taken).
  String? _statusOf(RoundTask t) {
    if (!_digital ||
        !_round.hasCards ||
        t.owner == null) {
      return null;
    }
    if (t.isCompleted) return 'Done!';
    if (t.isFailed) return 'Failed this round.';
    if (_round.tricks.isEmpty && _round.pickTurn != null) {
      return 'The tricks haven’t started yet.';
    }
    return taskStatus(t.description, _shownView, t.owner!,
        t.x,
        names: [for (final p in game.players) p.name]);
  }

  /// The cards [t] names that its owner has already won, to cross out.
  Set<String> _wonNamed(RoundTask t) => !_digital || !_round.hasCards
      ? const {}
      : wonNamed(_round, t, trickPending: _lastTrick != null);

  /// Every card in the deck, by suit: played (and in which trick, by
  /// whom), in your hand, shown by someone, or still to come.
  /// The card tracker, docked over the bottom half of the screen.
  bool _trackerOpen = false;

  /// Built (opening, open or closing).
  bool _trackerMounted = false;
  Timer? _trackerTimer;

  /// Moving up or down (it's hidden when neither open nor moving).
  bool _trackerSliding = false;

  /// Hidden for a moment (its eye, or the space bar, held down) to see
  /// the table behind it.
  bool _trackerPeek = false;
  final _trackerKey = GlobalKey<CardTrackerState>();

  void _showCardTracker() {
    if (_trackerOpen) {
      _closeTracker();
      return;
    }
    _trackerTimer?.cancel();
    // First built unseen (the slow frame, if there is one), then faded in,
    // so the fade itself runs smoothly.
    _ui(() {
      _trackerMounted = true;
      _trackerSliding = true;
      _trackerPeek = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _trackerSliding) _ui(() => _trackerOpen = true);
      });
    });
  }

  void _closeTracker() {
    _ui(() {
      _trackerOpen = false;
      _trackerPeek = false;
      _trackerSliding = true;
    });
    _trackerTimer?.cancel();
    _trackerTimer = Timer(_trackerSlide + const Duration(milliseconds: 40), () {
      if (mounted && !_trackerOpen) {
        _ui(() {
          _trackerSliding = false;
          _trackerMounted = false;
        });
      }
    });
  }

  static const _trackerSlide = Duration(milliseconds: 320);

  List<MarkedCard> _cardStates(RoundTask t) =>
      cardStates(t, round: _round, players: game.players, you: _you, onScreen: _digital);

  String? _progressOf(RoundTask t) {
    if (!_digital ||
        !_round.hasCards ||
        t.owner == null ||
        t.status != TaskStatus.pending) {
      return null;
    }
    return taskProgress(t.description, _shownView, t.owner!,
        t.x);
  }

  /// Colours of the players whose open tasks need [card] won.
  List<Color> _marksFor(PlayingCard card) => [
        for (final t in game.tasks)
          if (t.owner != null &&
              t.status == TaskStatus.pending &&
              neededCards(t.description).contains(card))
            game.players[t.owner!].color
      ];

  /// A task's wording, with the announced number filled in.
  String _cardText(RoundTask t) {
    final text = t.boardText(game.players.length);
    final x = _digital ? t.x : null;
    if (x == null) return text;
    final secret = t.description.contains('secret') && t.owner != _you;
    return text.replaceFirst('X', secret ? '?' : '$x');
  }

  /// What the table says is happening, under the cards.
  String get _cardStatus => tableStatus(game, you: _you, lastTrick: _lastTrick,
      choosingKing: _choosingKing, speakPrompt: _speakPromptDue);

  /// Your hand along the bottom, fanned to fit: cards you may play stand
  /// up, the rest dim. Tap one to play it.
  /// A small gold button in the hand's status line.
  /// How wide the hand's cards may spread on a wide screen.
  double _handLimit = double.infinity;

  /// The height the on-screen game has, table and hand together.
  double _gameHeight = 800;

  Widget _buildHand() {
    final skin = context.skin;
    final c = _round;
    // Once a suit is led you may choose your card early; it's played as
    // soon as your turn comes.
    final canQueue = _playing &&
        !_yourPlay &&
        c.hasCards &&
        c.current.isNotEmpty &&
        !c.currentSeats.contains(_you) &&
        _lastTrick == null;
    if (!canQueue && !_yourPlay) _queued = null;
    // Showing a card: only those you may show stand out.
    final showing = _revealing || _speakPromptDue;
    final yourTurn = _yourPlay || showing;
    final legal = showing
        ? {
            for (final card in c.hasCards ? c.hands[_you] : const <PlayingCard>[])
              if (c.revealFor(_you, card) != null) card
          }
        : _yourPlay
            ? c.legalFor(_you).toSet()
            : const <PlayingCard>{};
    return Container(
      width: double.infinity,
      // Room below the cards so they clear the brass trim.
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
      decoration: BoxDecoration(
        color: skin.feltDeep,
        border: Border(top: BorderSide(color: skin.gold.withValues(alpha: 0x66 / 255))),
      ),
      child: Center(
        child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _handLimit),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HandBar(
            choice: !_barChoice
                ? null
                : _speakPromptDue
                    ? HandChoice.show
                    : HandChoice.pass,
            buttonKey: _kbButtonKey,
            buttonFocused: _kbRow == 2,
            onSkip: _skipShowing,
            onPass: _passPick,
            message: _toast != null
                ? _toast!
                : _revealing
                    ? 'Tap a card to show it (highest, lowest or only of its suit)'
                    : _queued != null
                        ? 'You\u2019ll play the ${_queued!.label} on your turn (tap it again to change your mind)'
                        : _wantsToSpeak && _playing
                            ? 'You\u2019ll show a card after this trick'
                            : _cardStatus,
            lit: yourTurn || _yourPick || _revealing,
            onTracker: _round.hasCards ? _showCardTracker : null,
            speech: (
              skipping: _speakPromptDue,
              revealing: _revealing,
              asked: _wantsToSpeak,
              ready: _mayAskToSpeak,
              used: _round.spoke.length > _you && _round.spoke[_you],
            ),
            onSpeak: _speakPromptDue
                ? _skipShowing
                : _mayAskToSpeak || _revealing
                    ? _speak
                    : null,
          ),
          const SizedBox(height: 2),
          LayoutBuilder(builder: (context, box) {
            final hand = c.hasCards ? c.hands[_you] : const <PlayingCard>[];
            final width = box.maxWidth;
            // Wider screens get bigger cards, as far as the height allows.
            final cardW = clampD(
                math.min(width / 6.2, _gameHeight * 0.105),
                44,
                108);
            final h = PlayingCardView.heightFor(cardW);
            if (hand.isEmpty) return SizedBox(height: h + 12);
            final step = hand.length == 1
                ? 0.0
                : math.min(cardW + 6, (width - cardW) / (hand.length - 1));
            final total = cardW + step * (hand.length - 1);
            return SizedBox(
              key: _handKey,
              height: h + 12,
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int i = 0; i < hand.length; i++)
                    () {
                      final card = hand[i];
                      final dragging = _drag.card == card.id;
                      final left = (width - total) / 2 + i * step;
                      if (i == 0) {
                        _handRects.clear();
                        // The card chosen with the arrow keys was played
                        // (or shown), or can't be played now a new trick
                        // has begun: the nearest card you can play is
                        // chosen instead.
                        final kb = _kbCard;
                        final pool = hand.where(legal.contains).toList();
                        if (_kbRow == 0 &&
                            kb != null &&
                            (!hand.contains(kb) ||
                                (pool.isNotEmpty && !pool.contains(kb)))) {
                          final area = _rectOn(_handKey);
                          final from = pool.isEmpty ? hand : pool;
                          final at = hand.indexOf(kb);
                          final lastX = at >= 0
                              ? (width - total) / 2 + at * step + cardW / 2
                              : _kbLast == null || area == null
                                  ? null
                                  : _kbLast!.center.dx - area.left;
                          if (lastX != null) {
                            final x = lastX;
                            _kbCard = from.reduce((a, b) {
                              double d(PlayingCard c) =>
                                  ((width - total) / 2 + hand.indexOf(c) * step + cardW / 2 - x)
                                      .abs();
                              return d(a) <= d(b) ? a : b;
                            });
                          }
                        }
                      }
                      _handRects[card] = Rect.fromLTWH(left, 0, cardW, h);
                      // The card chosen with the arrow keys stands up a
                      // little higher.
                      final chosen = _kbCard == card && _kbRow == 0;
                      final top = chosen
                          ? -8.0
                          : legal.contains(card) || _queued == card
                              ? 0.0
                              : 12.0;
                      // Whether the card went anywhere (played, shown or
                      // queued); a drag that didn't slides back.
                      bool play() {
                        if (_revealing || _speakPromptDue) {
                          if (_round.revealFor(_you, card) == null) {
                            _showSnack(
                                'Only your highest, lowest or only card of a suit can be shown, never a Court Card',
                                skin.feltDeep);
                            return false;
                          }
                          final opening = _speakPromptDue;
                          _reveal(_you, card);
                          if (opening) _startChoosing();
                          return true;
                        }
                        if (!_yourPlay && canQueue) {
                          final ok = legalPlays(c.hands[_you], c.current.first);
                          if (!ok.contains(card)) {
                            final led = c.current.first;
                            _showSnack(
                                led.isCourt
                                    ? 'You must follow with a Court Card'
                                    : 'You must follow ${led.suit.name}',
                                skin.feltDeep);
                            return false;
                          }
                          setState(() => _queued = _queued == card ? null : card);
                          return true;
                        }
                        if (!_yourPlay) return false;
                        if (!legal.contains(card)) {
                          final led = c.led!;
                          _showSnack(
                              led.isCourt
                                  ? 'You must follow with a Court Card'
                                  : 'You must follow ${led.suit.name}',
                              skin.feltDeep);
                          return false;
                        }
                        final area = _rectOn(_handKey);
                        if (area != null) {
                          _launchFrom[card.id] = area.topLeft +
                              Offset(left + cardW / 2, top + h / 2) +
                              (dragging ? _drag.offset.value : Offset.zero);
                        }
                        _playCard(_you, card);
                        return true;
                      }
                      _handPlays[card] = play;

                      return AnimatedPositioned(
                        key: ValueKey(card.id),
                        duration: dragging
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        left: left,
                        top: top,
                        child: ValueListenableBuilder<Offset>(
                          valueListenable: _drag.offset,
                          builder: (context, drag, child) => Transform.translate(
                              offset: dragging || _drag.snapping == card.id
                                  ? drag
                                  : Offset.zero,
                              child: child),
                          child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
                          onTap: play,
                          // Or drag it up onto the table.
                          onPanStart: (_) => _drag.start(card.id),
                          onPanUpdate: (d) => _drag.move(d.delta),
                          onPanEnd: (_) {
                            final far = _drag.offset.value.dy < -h * 0.6;
                            // Let go first, so the play below is saved.
                            _drag.card = null;
                            if (far && play()) {
                              _ui(() => _drag.offset.value = Offset.zero);
                            } else {
                              _drag.snapBack(card.id);
                            }
                          },
                          onPanCancel: () {
                            _drag.card = null;
                            _drag.snapBack(card.id);
                          },
                          child: HandCard(
                            card: card,
                            width: cardW,
                            index: i,
                            dealId: game.dealId,
                            lifted: dragging,
                            dimmed: yourTurn && !legal.contains(card),
                            glow: (yourTurn && card == _tutorialHint) || _queued == card || chosen,
                            marks: _marksFor(card),
                            // With the shortcuts showing: the key that plays it.
                            keyLabel: _keysShown && i < cardKeyLabels.length ? cardKeyLabels[i] : null,
                          ),
                        )),
                        ),
                      );
                    }(),
                ],
              ),
            );
          }),
        ],
      ),
      ),
      ),
    );
  }

  // ---------------------------------------------- the on-screen card table
  //
  // With on-screen cards the table isn't a circle: the bots sit across
  // the top with their tasks under them, the trick is played in the
  // middle, and your tasks and hand are at the bottom.

  final _digiKey = GlobalKey();
  final _middleKey = GlobalKey();
  final _handKey = GlobalKey();
  final _yourRowKey = GlobalKey();
  final _seatKeys = <int, GlobalKey>{};

  /// The tasks flying from the middle to whoever took them.
  final _tasks = TaskFlights();

  /// Where your played card left your hand, by card id.
  final _launchFrom = <int, Offset>{};

  /// A card of your hand being dragged towards the table.
  late final _drag = HandDrag(vsync: this, update: _ui);

  GlobalKey _seatKey(int seat) => _seatKeys.putIfAbsent(seat, GlobalKey.new);

  /// Where a widget sat on the on-screen table last frame (safe mid-build).
  Rect? _rectOn(GlobalKey key) {
    final box = (key.currentContext as Element?)?.renderObject as RenderBox?;
    final table = (_digiKey.currentContext as Element?)?.renderObject as RenderBox?;
    if (box == null || table == null || !box.attached || !box.hasSize) {
      return null;
    }
    // Global positions, since your hand sits below the table itself.
    return (box.localToGlobal(Offset.zero) - table.localToGlobal(Offset.zero)) &
        box.size;
  }

  /// Sends each newly taken task flying from the middle to its owner.
  void _launchTaskFlights() {
    if (!_digital) return;
    _tasks.launch(game.tasks,
        rectOn: _rectOn,
        flight: (t, from, to, toFont) => Flight(skin: context.skin, t, from, to, _points(t), _cardText(t),
            fromFont: _tasks.openFontSize,
            toFont: toFont,
            toColor: t.owner == null ? context.skin.inkSoft : game.players[t.owner!].color),
        mounted: () => mounted,
        update: setState);
  }

  Widget _buildDigitalTable() {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: LayoutBuilder(builder: (context, c) {
        _table.tableSize = Size(c.maxWidth, c.maxHeight);
        final width = c.maxWidth - 32;
        return Stack(
          key: _digiKey,
          clipBehavior: Clip.none,
          children: [
            Padding(
              // Room above the tokens so a King's crown clears the edge.
              // On a phone the courtiers sit higher, leaving more room for
              // tasks and cards.
              padding: EdgeInsets.fromLTRB(16, width < 600 ? 8 : 16, 16, 4),
              child: Column(
                children: [
                  // As much room as the bots' tasks need, leaving enough for
                  // the trick and your own row.
                  // (The middle always keeps room for a full-size trick.)
                  _digiOpponents(
                      width,
                      clampD(
                          c.maxHeight -
                              120 -
                              PlayingCardView.heightFor(trickCardWidth(
                                  width, game.players.length)),
                          110,
                          math.max(110.0, c.maxHeight * 0.6))),
                  Expanded(
                    child: SizedBox(
                      key: _middleKey,
                      width: double.infinity,
                      child: _digiMiddle(width),
                    ),
                  ),
                  KeyedSubtree(key: _yourRowKey, child: _digiYou(width)),
                ],
              ),
            ),
            for (final f in _tasks.flights) f.build(),
            if (_crowning != null)
              Positioned.fill(child: IgnorePointer(child: _digiCrowning())),
            Positioned.fill(child: IgnorePointer(child: PlayFlourish(animation: _play))),
          ],
        );
      }),
    );
  }

  bool _seatActive(int seat) =>
      !_choosingKing &&
      (_round.pickTurn != null
          ? _round.pickTurn == seat
          : _playing && _lastTrick == null && _round.turn == seat);

  /// What tapping a seat does: their courtier's card, or (without roles)
  /// asking them to show a card.
  VoidCallback? _seatTap(int seat) => _choosingKing
      ? null
      : game.hasRoles
          ? () => _showCourtier(seat)
          : _digital && seat != _you
              ? () => _askToSpeak(seat)
              : null;

  Widget _digiToken(int seat, double size, {bool tight = false}) {
    final labels = seatLabels(game.players);
    // Each courtier breathes, and springs in when they first come to the
    // table; the same courtier keeps the same token as they move seats.
    return CharacterToken(
        key: ValueKey('person-${game.hasRoles && seat < game.courtiers.length ? game.courtiers[seat].name : seat}'),
        mood: CharacterMood.arriving,
        delay: Duration(milliseconds: 150 * seat),
        phase: seat * 0.37,
        size: size,
        child: KeyedSubtree(
        key: _seatKey(seat),
        child: SeatToken(
        player: game.players[seat],
        label: labels[seat],
        isKing: _round.king == seat,
        size: size,
        highlighted: _seatActive(seat),
        exiled: _round.exiledSeat == seat,
        shape: game.hasRoles && seat < game.courtiers.length
            ? game.courtiers[seat].shape
            : null,
        // Tap a courtier to ask them to show a card (once a round).
        onTap: _seatTap(seat),
        tight: tight,
      ),
      ),
    );
  }

  /// A task in front of its owner. It's laid out as soon as the task is
  /// taken, but kept hidden while its flying copy travels there: the
  /// flight lands exactly on it, then it shows, so nothing jumps.
  Widget _miniTask(RoundTask t, double width, {double fontSize = 12}) {
    final skin = context.skin;
    _tasks.miniStyle[t] = (width, fontSize);
    return Opacity(
        key: ValueKey('mini-${t.description}'),
        opacity: _tasks.landing.contains(t) ? 0 : 1,
        child: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: KeyedSubtree(
            key: _tasks.destKeys.putIfAbsent(t, GlobalKey.new),
            child: TaskChip(
            task: t,
            points: _points(t),
            text: _cardText(t),
            color: t.owner == null
                ? skin.inkSoft
                : game.players[t.owner!].color,
            width: width,
            fontSize: fontSize,
            progress: _progressOf(t),
            struck: _wonNamed(t),
            focused: _kbRow == 1 && _kbTask == t,
            onTap: () => _showTaskDetail(t, Offset.zero),
            onLongPress: () => _showTaskDetail(t, Offset.zero),
          ),
          ),
        ),
      );
  }

  /// The crowning on the on-screen table: from the middle of the table to
  /// the new King's token, with a trumpet from everyone else.
  Widget _digiCrowning() => AnimatedBuilder(
        // Measured afresh every frame, so the crown lands where the token
        // is even if the table is still settling.
        animation: _crown,
        builder: (context, _) => _digiCrowningNow(),
      );

  Widget _digiCrowningNow() {
    final king = _crowning;
    if (king == null) return const SizedBox.shrink();
    final middle = _rectOn(_middleKey);
    final seat = _rectOn(_seatKey(king));
    if (middle == null || seat == null) return const SizedBox.shrink();
    // From the walk-in's crown: the middle of the screen, in the table's
    // own coordinates, at that crown's size.
    final table = _digiKey.currentContext?.findRenderObject() as RenderBox?;
    final screen = MediaQuery.sizeOf(context);
    final centre = table == null || !table.attached
        ? middle.center
        : screen.center(Offset.zero) - table.localToGlobal(Offset.zero);
    return CrowningScene(
      animation: _crown,
      from: _crownFromCentre ? centre : middle.center,
      startSize: _crownFromCentre
          ? math.min(screen.width, screen.height) * 0.28
          : null,
      // The crown sits in the slot above the token.
      to: seat.topCenter + const Offset(0, 8),
      spinTo: 0,
      seatSize: 44,
      king: king,
      seats: {
        for (int j = 0; j < game.players.length; j++)
          if (_rectOn(_seatKey(j)) case final r?) j: r.center
      },
    );
  }

  /// The bots across the top, each with their tasks under them.
  Widget _digiOpponents(double width, double maxHeight) {
    final c = _round;
    final big = width > 600;
    return OpponentsRow(
      // Round the table from you, in the order of play.
      seats: [for (var k = 1; k < game.players.length; k++) (_you + k) % game.players.length],
      width: width,
      maxHeight: maxHeight,
      name: (i) => game.hasRoles && i < game.courtiers.length && !_personAt(i)
          ? game.courtiers[i].short
          : game.players[i].name,
      token: (seat, size) => _withReveal(seat, _digiToken(seat, size, tight: true), size: size),
      onTap: _seatTap,
      // Trick counts once the tricks begin; their room is kept from the
      // start, so nothing shifts when they appear.
      tallyShown: c.hasCards && (_playing || c.tricks.isNotEmpty),
      tally: (seat) => c.hasCards
          ? '${_shownTricksWon(seat)} won · ${c.cardsIn(seat)} cards'
          : '0 won · 0 cards',
      tasks: (seat) => [for (final t in game.tasks) if (t.owner == seat) t],
      task: _miniTask,
      quip: (seat) => _quips[seat],
      tokenSize: big ? 48 : 38,
      taskWidth: big ? 170 : 130,
    );
  }

  Widget _withReveal(int seat, Widget token, {required double size}) =>
      withShownCard(token, _revealedView(seat, height: size), size: size);

  Widget? _revealedView(int seat, {double height = 40}) =>
      shownCard(context.skin, _round, seat, game.players[seat].color, height: height);

  Widget _digiYou(double width) => YourSeat(
        width: width,
        token: _digiToken(_you, 40),
        shown: _revealedView(_you),
        tallyShown: _round.hasCards && (_playing || _round.tricks.isNotEmpty),
        tally: _round.hasCards
            ? '${_shownTricksWon(_you)} trick${_shownTricksWon(_you) == 1 ? '' : 's'}'
            : '0 tricks',
        tasks: [for (final t in game.tasks) if (t.owner == _you) t],
        task: _miniTask,
        scrolled: _youScrolled,
      );

  /// The middle of the table: the tasks to take while picking (tap one),
  /// then the trick.
  final _middleTasksKey = GlobalKey(debugLabel: 'middle tasks');

  Widget _digiMiddle(double width) {
    if (_choosingKing) return const SizedBox.expand();
    final open = [for (final t in game.tasks) if (t.owner == null) t];
    if (open.isEmpty && _tasks.landing.isEmpty && _tasks.flights.isEmpty) {
      // The trick, laid out right here so it always shows.
      return LayoutBuilder(
        builder: (context, box) => Stack(
          clipBehavior: Clip.none,
          children: _trickCards(box.biggest),
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tasks.openRects = {
        for (final e in _tasks.openKeys.entries)
          if (e.key.owner == null)
            if (_rectOn(e.value) case final r?) e.key: r,
      };
    });
    // Bigger on a big screen, where there's room to read them easily.
    final big = width > 600;
    final w = math.min(big ? 200.0 : 130.0, (width - 16) / 3);
    _tasks.openFontSize = big ? 16 : 13;
    // Open tasks, and any still flying to their owner. Once a taken task
    // has landed the rest close up, so the middle never runs out of room.
    final slots = [
      for (final t in game.tasks)
        if (t.owner == null ||
            _tasks.landing.contains(t) ||
            _tasks.flights.any((f) => f.task == t))
          t
    ];
    // The deal: first laid out unseen to find each task's place, then
    // dealt from a pile in the middle out to those places.
    final measured = _dealMeasuredFor == game.dealId;
    if (!measured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _dealMeasuredFor == game.dealId) return;
        final middle = _rectOn(_middleKey);
        if (middle == null) return;
        setState(() {
          _dealFrom = {
            for (final t in slots)
              if (_tasks.openKeys[t] case final key?)
                if (_rectOn(key) case final r?) t: middle.center - r.center,
          };
          _dealMeasuredFor = game.dealId;
        });
      });
    }
    // A moment as a pile before the first card goes.
    const pileMs = 300;
    // Packed in columns so short and tall cards fill the space; when one
    // is taken the rest glide to their new places.
    final taskChips = <Widget>[
        for (int i = 0; i < slots.length; i++)
          KeyedSubtree(
            key: ValueKey('slot-${slots[i].description}'),
            child: () {
            final t = slots[i];
            final taken = t.owner != null;
            // Who could take it: a task only one player may take is marked
            // in their colour, so the table knows it's theirs to choose.
            // Only what everyone can see: your own hand counts for you,
            // but nobody else's cards do.
            final able = [
              for (int s = 0; s < game.players.length; s++)
                if (s == _you
                    ? _round.mayTake(t, s)
                    : _round.whyCantTake(t, s, publicOnly: true) == null)
                  s
            ];
            final only = !taken && able.length == 1 ? able.single : null;
            final chip = OpenTask(
              placeKey: _tasks.openKeys.putIfAbsent(t, GlobalKey.new),
              task: t,
              taken: taken,
              faded: _yourPick && !_mayTake(t) && only == null,
              points: _points(t),
              text: _cardText(t),
              width: w,
              fontSize: big ? 16 : 13,
              focused: _kbRow == 1 && _kbTask == t,
              only: only == null
                  ? null
                  : (
                      only == _you
                          ? 'Only you can take this'
                          : 'Only ${game.players[only].name} can take this',
                      game.players[only].color
                    ),
              // A tap reads it; press and hold to take it, so taking a
              // task is always meant.
              onTap: () => _showTaskDetail(t, Offset.zero),
              onLongPress: () => _yourPick ? _takeTask(t) : _showTaskDetail(t, Offset.zero),
            );
            if (!measured) return Opacity(opacity: 0, child: chip);
            return DealtTask(
              key: ValueKey('deal-${game.dealId}-${t.description}'),
              index: i,
              from: _dealFrom[t] ?? Offset.zero,
              startMs: pileMs + i * 170,
              child: chip,
            );
          }(),
          ),
    ];
    // Full size, always readable; on the rare table with no room left the
    // middle scrolls rather than spilling over anything. The tasks centre
    // themselves in the middle, so when they close up (two rows to one)
    // they glide to the new centre too.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: Masonry(
          key: _middleTasksKey,
          columnWidth: w,
          minHeight: box.maxHeight.isFinite ? box.maxHeight : 0,
          children: taskChips,
        ),
      ),
    );
  }

  bool _mayTake(RoundTask t) => _round.decree == Decree.kingsCommand || _round.mayTake(t, _you);

  /// Your pick: take a task. Under King's Command you're the King handing
  /// tasks out, so choose who gets it.
  Future<void> _takeTask(RoundTask t) async {
    if (_round.decree != Decree.kingsCommand) {
      if (!_round.mayTake(t, _you)) {
        _showSnack(_round.whyCantTake(t, _you)!, context.skin.feltDeep);
        return;
      }
      _assignTask(t, _you);
      return;
    }
    final seats = [
      for (int s = 0; s < game.players.length; s++)
        if (_round.mayTake(t, s)) s
    ];
    final seat = await showWhoTakesDialog(context, seats: seats, players: game.players);
    if (seat != null && mounted && t.owner == null) {
      _assignTask(t, seat);
    }
  }

  /// Whether your tasks have been scrolled under your token.
  final _youScrolled = ValueNotifier(false);

  /// You, with your tasks beside you.
  /// The trick in the middle of the table (ui/table/trick_view.dart),
  /// each card from where it was played: your hand, or a courtier's seat.
  List<Widget> _trickCards(Size area) {
    // Where the middle sits on the table, to work out where cards come
    // from; if it isn't known yet the cards simply fade in.
    final middle = _rectOn(_middleKey);
    final hand = _rectOn(_handKey);
    Offset? origin(int seat, PlayingCard card) {
      if (middle == null) return null;
      final p = seat == _you
          ? _launchFrom[card.id] ?? hand?.topCenter
          : _rectOn(_seatKey(seat))?.center;
      return p == null ? null : p - middle.topLeft;
    }

    return trickCards(
        area: area,
        round: _round,
        trick: _lastTrick,
        collecting: _collecting,
        players: game.players,
        origin: origin);
  }

  // ------------------------------------------- powers and reveals on screen

  /// Tap a card in your hand to show it with the speech token.
  bool _revealing = false;

  /// You asked to speak mid-trick: the game stops for you after it.
  bool _wantsToSpeak = false;

  /// The speech token can be asked for at any time in the round, even
  /// while tasks are picked: it's used at the next gap between tricks.
  bool get _mayAskToSpeak =>
      _digital &&
      _inGame &&
      !_choosingKing &&
      game.outcome == RoundOutcome.inProgress &&
      _round.hasCards &&
      _round.hands.length > _you &&
      _round.hands[_you].isNotEmpty &&
      _round.spoke.length > _you &&
      !_round.spoke[_you] &&
      _round.canSpeak(_you);

  /// Speak now if it's between tricks, otherwise as soon as this trick is
  /// over. The table waits while you choose.
  void _speak() {
    if (_revealing) {
      setState(() => _revealing = false);
      return;
    }
    if (!_mayAskToSpeak) return;
    // Mid-trick, you speak as soon as the trick is over. Otherwise, while
    // tasks are being chosen or between tricks, right away.
    if (_round.current.isNotEmpty || _lastTrick != null) {
      setState(() => _wantsToSpeak = !_wantsToSpeak);
      return;
    }
    if (!_round.hands[_you].any((c) => _round.revealFor(_you, c) != null)) {
      _showSnack(
          'Nothing you may show: only your highest, lowest or only card of a suit',
          context.skin.feltDeep);
      return;
    }
    setState(() => _revealing = true);
  }

  /// Shows [card] for [seat]: sends the move, which shows it when it
  /// comes back. The card stays in their hand, face up for all.
  void _reveal(int seat, PlayingCard card) {
    if (_round.revealFor(seat, card) == null) return;
    _link.send(ShowCard(seat, card));
  }

  /// You ask a courtier to show a card. They show one a task needs if they
  /// can, else one that says the most (the only card of its suit, or the
  /// highest of their longest suit).
  void _askToSpeak(int seat) {
    final c = _round;
    final name = game.players[seat].name;
    if (!c.hasCards || game.outcome != RoundOutcome.inProgress) return;
    String? no;
    if (_round.spoke[seat]) {
      no = '$name has already shown a card this round';
    } else if (!_round.canSpeak(seat)) {
      no = _round.whyCantSpeak() ?? 'No cards may be shown now';
    } else if (c.current.isNotEmpty) {
      no = '$name can show a card once this trick is over';
    }
    if (no != null) {
      _showSnack(no, context.skin.feltDeep);
      return;
    }
    final showable = [for (final card in c.hands[seat]) if (c.revealFor(seat, card) != null) card];
    if (showable.isEmpty) {
      _showSnack('$name has no card they may show', context.skin.feltDeep);
      return;
    }
    int score(PlayingCard card) {
      final needed = game.tasks.any((t) =>
          t.status == TaskStatus.pending && neededCards(t.description).contains(card));
      final hint = c.revealFor(seat, card);
      final suitCount = c.hands[seat].where((x) => x.suit == card.suit).length;
      return (needed ? 100 : 0) + (hint == 'only' ? 20 : 0) + suitCount;
    }
    showable.sort((a, b) => score(b).compareTo(score(a)));
    _haptic(HapticFeedback.selectionClick);
    _reveal(seat, showable.first);
  }

  /// Marks a task done, for tests.
  @visibleForTesting
  void debugComplete(RoundTask t) => _mark(t, TaskStatus.completed);

  /// Gives a task to a seat, for tests (as a drop onto that seat would).
  @visibleForTesting
  void debugAssign(RoundTask t, int seat) => _assignTask(t, seat);

  /// The table link, for tests.
  @visibleForTesting
  TableLink get debugLink => _link;

  /// Plays your part, for tests: picks, announces or plays the first
  /// thing allowed. Returns false when there's nothing for you to do.
  @visibleForTesting
  bool debugYourMove() {
    if (_speakPromptDue) {
      _startChoosing();
      return true;
    }
    if (_yourPick) {
      final t = game.tasks.firstWhere(
          (t) => t.owner == null && _round.mayTake(t, _you),
          orElse: () => game.tasks.firstWhere((t) => t.owner == null));
      _assignTask(t, _round.mayTake(t, _you) ? _you : (_you + 1) % game.players.length);
      return true;
    }
    if (_yourPlay) {
      // The tutorial follows its own advice.
      final legal = _round.legalFor(_you);
      final hint = _tutorialHint;
      _playCard(_you, hint != null && legal.contains(hint) ? hint : legal.first);
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- actions

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
    setState(() {
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

  // ------------------------------------------------------------ tutorial

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
    setState(() => _setupArgs = null);
    _startGame(3, 1, tutorialCourtiers, GameMode.tutorial,
        digital: true, lesson: i);
  }

  /// On to the next section's reading, then its lesson.
  Future<void> _nextLesson() => _openSection(game.lesson + 1);

  /// Leaves the tutorial for the welcome table, and offers a real game.
  Future<void> _finishTutorial() async {
    Analytics.event(['tutorial', 'finished']);
    _tutorialDone = true;
    unawaited(_saveSettings());
    _botTimer?.cancel();
    _botTimer = null;
    setState(() {
      game = GameState();
      _resetTable();
    });
    _keepAwake(false);
    // Any game saved before the tutorial can be continued again.
    await _loadSaved();
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
    final fromCentre = _crownWaiting;
    setState(() {
      _crowning = index;
      // The waiting crown becomes this one, in the same place.
      _crownFromCentre = fromCentre;
      if (fromCentre) _crownHandedOver = true;
      _crownWaiting = false;
    });
    // The walk-in already sounded the fanfare.
    if (!fromCentre) Sfx.fanfare();
    _crown.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _haptic(HapticFeedback.heavyImpact);
      setState(() {
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
        setState(() {
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
      setState(() {
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
    setState(() {
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

  /// What each courtier is calling out mid-hand.
  final Map<int, String> _quips = {};

  /// A courtier at [seat] calls out, for a moment.
  void _quip(int seat, String text) {
    if (text.isEmpty) return;
    _quips[seat] = text;
    _trickTimers.add(Timer(const Duration(milliseconds: 2800), () {
      if (mounted && _quips[seat] == text) setState(() => _quips.remove(seat));
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
    setState(() {
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
  /// Records each round as it's over (platform/game_log.dart).
  final _rounds = RoundLogger();

  void _roundSettled() {
    // Online, the host's device keeps the record.
    if (_hostsTable) {
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
      setState(() {});
      _outcome.forward(from: 0);
    });
  }

  /// A short message shown in the hand's status line for a moment (on
  /// screen; a pop-up bar there would cover your cards).
  String? _toast;
  Timer? _toastTimer;

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

  /// Opens the New Game panel on the table.
  void _showSetupDialog(
      {GameMode? startMode, int? startChapter, bool continuing = false}) {
    setState(() {
      _setupArgs = (mode: startMode, chapter: startChapter);
      _setupContinuing = continuing;
    });
  }

  void _closeSetup() => setState(() {
        _setupArgs = null;
        _onlineSetup = false;
      });

  /// From the menus into a game: the menu fades to the felt, the crown
  /// rises up in the middle in a burst of sparks, and as it lifts away the
  /// table is revealed beneath it.
  late final AnimationController _coronation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));

  void _startFromSetup(SetupResult r) {
    if (MediaQuery.disableAnimationsOf(context) || !CharacterToken.alive) {
      _beginFromSetup(r);
      return;
    }
    Sfx.fanfare();
    // On screen, the crown stays to crown the King at the table.
    _crownHandedOver = false;
    _crownWaiting = r.digital && r.mode != GameMode.tutorial;
    _coronation.forward(from: 0).whenComplete(() {
      // In case no crowning follows after all: let it go.
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _crownWaiting) setState(() => _crownWaiting = false);
      });
    });
    // The game is set out while the crown hides the change.
    Timer(const Duration(milliseconds: 560), () {
      if (mounted) _beginFromSetup(r);
    });
  }

  void _beginFromSetup(SetupResult r) {
    setState(() => _setupArgs = null);
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
          ? () => setState(() => _onlineSetup = true)
          : null,
      onSound: (on) {
        setState(() => Sfx.enabled = on);
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

  // ------------------------------------------------------------------ views

  /// [child] in the middle of a wide screen, no wider than [aspect] times
  /// its height, so on a laptop or desktop the seats and cards stay close
  /// together instead of drifting to the far edges.
  Widget _centred(Widget child, {required double aspect}) =>
      LayoutBuilder(builder: (context, c) {
        final most = math.max(480.0, c.maxHeight * aspect);
        if (c.maxWidth <= most) return child;
        return Center(child: SizedBox(width: most, child: child));
      });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // One page: the felt is always there. Before a game it shows the
    // crown and the main buttons; New Game opens its panel on the table.
    // On a wide screen the on-screen table sits in the middle with room
    // either side for the title and menu, so it can use the top bar's
    // height too.
    final screen = MediaQuery.sizeOf(context);
    // The setup panel uses it too, so every choice fits on a phone.
    // The front page too, so it doesn't jump as the menus open over it.
    final useTopBar = _setupArgs != null ||
        !_inGame ||
        _inGame &&
            _digital &&
            screen.width - math.max(480.0, screen.height) >= 560;
    return Stack(children: [
    Scaffold(
      extendBodyBehindAppBar: useTopBar,
      // The game's bar and the plain one cross-fade, so the round and
      // points don't pop in and out with the setup.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        // Its own layer: the bar is drawn again only when it changes.
        child: RepaintBoundary(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, if (current != null) current]),
          child: _inGame && _setupArgs == null
              ? KeyedSubtree(key: const ValueKey('game-bar'), child: HomePageTestHooks.skip.contains('bar') ? AppBar(toolbarHeight: 60, backgroundColor: Colors.transparent) : _buildAppBar())
              : AppBar(
                  key: const ValueKey('plain-bar'),
                  toolbarHeight: 60,
                  actions: [
                    // Not on the front page, which is just the title and
                    // its buttons; it fades in with setup.
                    IgnorePointer(
                      ignoring: _setupArgs == null,
                      child: AnimatedOpacity(
                        opacity: _setupArgs == null ? 0 : 1,
                        duration: const Duration(milliseconds: 250),
                        child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildMenu()),
                      ),
                    ),
                    const SizedBox(width: 18),
                  ]),
        )),
      ),
      body: SafeArea(
        top: !useTopBar,
        child: Stack(
          children: [
            if (_inGame) const Positioned.fill(child: RepaintBoundary(child: FeltLight())),
            Positioned.fill(
              child: _inGame
                  ? _digital
                      ? ScrollConfiguration(
                          // No scrollbars on the table: it's laid out to fit.
                          behavior: ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false),
                          child: LayoutBuilder(builder: (context, c) {
                          // On a wide screen the table and the coach stay in
                          // the middle; the hand's bar still runs edge to
                          // edge, with the cards centred in it.
                          final limit = math.max(480.0, c.maxHeight);
                          Widget mid(Widget w) => c.maxWidth <= limit
                              ? w
                              : Center(child: SizedBox(width: limit, child: w));
                          _handLimit = limit;
                          _gameHeight = c.maxHeight;
                          return Column(children: [
                          Expanded(child: HomePageTestHooks.skip.contains('table') ? const SizedBox() : mid(_buildDigitalTable())),
                          if (game.isTutorial)
                            mid(Coach(
                                lesson: game.lesson,
                                line: coachLine(game,
                                    you: _you,
                                    settingUp: _choosingKing ||
                                        _crowning != null ||
                                        _table.dealtFor != game.dealId,
                                    lastTrick: _lastTrick,
                                    yourPlay: _yourPlay),
                                onBack: () => _openSection(game.lesson),
                                onSkip: () => _openSection(game.lesson + 1))),
                          // (Not size-animated: that clipped the cards.)
                          if (!HomePageTestHooks.skip.contains('hand')) _buildHand(),
                        ]);
                        }))
                      : _centred(_buildTable(), aspect: 1.2)
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: _setupArgs == null ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Center(
                                child: WelcomeScreen(
                                    hasSaves: _saves.isNotEmpty,
                                    onContinue: _showContinue,
                                    onNewGame: _showSetupDialog)),
                          ),
                        ),
                      ],
                    ),
            ),
            // The setup fades in over the table, and fades away again
            // rather than vanishing.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _setupArgs == null,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (current, previous) => Stack(
                      fit: StackFit.expand,
                      children: [...previous, if (current != null) current]),
                  child: _setupArgs == null
                      ? const SizedBox.shrink(key: ValueKey('no-setup'))
                      : ColoredBox(
                          key: const ValueKey('setup'),
                          // In a game, wash the table out so the setup reads.
                          color: _inGame ? skin.felt : Colors.transparent,
                          child: Center(
                              child: _onlineSetup ? _buildOnlineSetup() : _buildSetupPanel()),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
      // Decrees and the end of a round cover the whole screen.
      if (_inGame && _setupArgs == null && _decreePending)
        Positioned.fill(
            child: Material(
                type: MaterialType.transparency,
                child: SafeArea(
                    child: DecreeOverlay(
                        round: _round,
                        players: game.players,
                        onAccept: () => setState(() => _decreeReadFor = game.dealId))))),
      if (_inGame &&
          _setupArgs == null &&
          game.outcome != RoundOutcome.inProgress &&
          !_outcomeHold.isAnimating &&
          // Once up it stays up, while a round won early plays out.
          (_lastTrick == null || _autoPlaying || _outcome.value > 0))
        Positioned.fill(
            child: Material(
                type: MaterialType.transparency,
                child: _buildOutcomeOverlay())),
      // The crowning between the menus and a game.
      Positioned.fill(
          child: CoronationOverlay(
              animation: _coronation,
              waiting: _crownWaiting,
              handedOver: _crownHandedOver)),
      // The brass inlay runs round the whole screen, the top bar included,
      // so it sits the same distance from every edge.
      // Its own layer: the trim (with its soft shadow) is painted once, not
      // every time something on the table changes.
      if (!HomePageTestHooks.skip.contains('trim'))
        const Positioned.fill(
            child: IgnorePointer(child: RepaintBoundary(child: SafeArea(child: TableTrim())))),
      // Keyboard shortcuts, when asked for, beside the table.
      // It slides up and fades in when turned on, and back out when off.
      if (_inGame && _setupArgs == null && _digital)
        Positioned(
          right: 22,
          bottom: 22,
          child: IgnorePointer(
            child: AnimatedSlide(
              offset: _keysShown ? Offset.zero : const Offset(0, 0.12),
              duration: const Duration(milliseconds: 260),
              curve: _keysShown ? Curves.easeOutCubic : Curves.easeInCubic,
              child: AnimatedOpacity(
                opacity: _keysShown ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: const ShortcutsCard(),
              ),
            ),
          ),
        ),
      // The card tracker: a panel in the middle of the screen over a dimmed
      // table (tap outside to put it away). Holding its eye, or the space
      // bar, hides it for a moment to see the table behind.
      if (_trackerMounted &&
          _inGame &&
          _setupArgs == null &&
          _digital &&
          _round.hasCards)
        Positioned.fill(
          key: const ValueKey('tracker'),
          child: TrackerOverlay(
            trackerKey: _trackerKey,
            open: _trackerOpen,
            peek: _trackerPeek,
            round: _round,
            you: _you,
            players: game.players,
            onClose: _closeTracker,
            onPeek: (on) => _ui(() => _trackerPeek = on),
          ),
        ),
    ]);
  }

  bool _menuOpen = false;

  /// The menu button: its bars fold into a cross while the menu is open.
  Widget _buildMenu() => Tooltip(
        message: Strings.menu,
        child: GoldBar(
          onTap: _openMenu,
          semanticLabel: 'Menu',
          child: OrnateMenuIcon(open: _menuOpen),
        ),
      );

  /// The menu: an ornate panel that drops down from the corner.
  Future<void> _openMenu() async {
    _ui(() => _menuOpen = true);
    final choice = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close the menu',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 260),
      // Settings switch in place and the menu stays open; anything that
      // goes somewhere closes it.
      pageBuilder: (context, _, __) => OrnateMenu(
        entries: _menuEntries,
        onToggle: _onMenuChoice,
      ),
      transitionBuilder: (context, a, _, child) {
        final t = Curves.easeOutCubic.transform(a.value);
        return Opacity(
          opacity: a.value,
          child: Transform.translate(offset: Offset(0, -14 * (1 - t)), child: child),
        );
      },
    );
    if (mounted) _ui(() => _menuOpen = false);
    if (choice == null || !mounted) return;
    _onMenuChoice(choice);
  }

  void _onMenuChoice(String choice) {
        Analytics.event([
          'menu',
          choice,
          if (choice == 'sound') Sfx.enabled ? 'off' : 'on',
          if (choice == 'suits') Settings.fourColourSuits ? 'off' : 'on',
          if (choice == 'keys') _showKeys ? 'off' : 'on',
          if (choice == 'share') GameLog.sharing ? 'off' : 'on',
        ]);
        switch (choice) {
          case 'new':
            _showSetupDialog();
          case 'rules':
            showRulesPage(context,
                game: _inGame && !game.isTutorial
                    ? RulesContext(
                        modeName: switch (game.mode) {
                          GameMode.free => 'Free play',
                          GameMode.endless => 'Endless',
                          GameMode.chronicle => 'The Chronicle',
                          GameMode.dynasty => 'Dynasty',
                          GameMode.tutorial => 'Tutorial',
                        },
                        onScreen: _digital,
                        players: game.players.length,
                        points: game.target,
                        seals: [
                          for (final t in game.tasks)
                            if (t.seal != null) t.seal!
                        ]..sort(),
                        decree: _round.decree?.title,
                        roles: game.hasRoles,
                      )
                    : null);
          case 'shuffle':
            _shuffleTasks();
          case 'upright':
            setState(() {
              _upright = !_upright;
              if (_inGame && _table.dealtFor == game.dealId) _table.layoutOwned(_geo);
            });
            _saveSettings();
          case 'sound':
            setState(() => Sfx.enabled = !Sfx.enabled);
            _saveSettings();
          case 'keys':
            _ui(() => _showKeys = !_showKeys);
            _saveSettings();
          case 'bug':
            showBugReport(context, details: _bugDetails);
          case 'leave': // a courtier takes your seat; back to the front page
            _leaveRoom();
            setState(() => game = GameState());
            _keepAwake(false);
          case 'skin':
            final next = skinAfter(context.skin, (s) => SkinScope.owns(context, s));
            // Everything that reads the skin depends on it, so it's all drawn
            // again in the new one (the painters compare their skin too).
            if (next != null && SkinScope.choose(context, next)) {
              // Saved once the page is under the new skin.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _saveSettings();
              });
            }
          case 'share':
            setState(() => GameLog.sharing = !GameLog.sharing);
            _saveSettings();
          case 'suits':
            setState(() => Settings.fourColourSuits = !Settings.fourColourSuits);
            // Every card on screen repaints in the new colours, even ones
            // built once and kept.
            void rebuild(Element e) {
              e.markNeedsBuild();
              e.visitChildren(rebuild);
            }
            (context as Element).visitChildren(rebuild);
            _saveSettings();
        }
  }

  List<MenuEntry> _menuEntries() => menuEntries(
        online: _room != null,
        newGame: (_inGame || _saves.isNotEmpty) && _setupArgs == null,
        shuffle: _inGame && _setupArgs == null,
        // Only round a real table does the view need turning.
        upright: _inGame && !_digital ? _upright : null,
        look: context.skin.name,
        keys: _desktop ? _showKeys : null,
        share: GameLog.sharing,
      );

  /// What goes with a bug report: where the player is, their settings, and
  /// the whole game as saved with every move of it, so it can be loaded
  /// (GameState.fromJson) and seen exactly as they saw it, or played again
  /// from the start move by move (net/replay.dart, tool/replay_report).
  Map<String, dynamic> _bugDetails() {
    final moves = _inGame ? _link.history : const <Move>[];
    return {
      'where': {
        'inGame': _inGame,
        if (_inGame) 'mode': game.mode.name,
        if (_inGame) 'round': game.roundNumber,
        'onScreen': _digital,
        'settingUp': _setupArgs != null,
      },
      'settings': {
        'sound': Sfx.enabled,
        'fourColourSuits': Settings.fourColourSuits,
        'keyboard': _showKeys,
      },
      if (_inGame) 'state': game.toJson(),
      if (moves.isNotEmpty) 'moves': [for (final m in moves) m.toJson()],
    };
  }

  PreferredSizeWidget _buildAppBar() {
    final picker = _round.pickTurn;
    return GameBar(
      title: game.mode == GameMode.chronicle && game.chapter != null
          ? 'Chapter ${game.chapter! + 1}'
          : game.isTutorial
              ? 'Lesson ${game.lesson + 1}'
              : 'Round ${game.roundNumber}',
      choosingKing: _choosingKing,
      decree: _round.decree,
      onDecree: () => showDecree(context, _round, game.players),
      // At a real table: whoever's picking may pass, once a round.
      passer: !_digital && picker != null && _round.canPass(picker)
          ? game.players[picker].name
          : null,
      onPass: () => _pass(_round.pickTurn!),
      target: game.target,
      onPoints: _showPointsDialog,
      menu: _buildMenu(),
    );
  }

  /// The table keeps a fixed text size so its layout always fits; dialogs
  /// and the rules still follow the phone's text size setting.
  Widget _buildTable() {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: RoundTable(
        table: _table,
        game: game,
        geometry: () => _geo,
        onScreen: _digital,
        choosingKing: _choosingKing,
        crowning: _crowning,
        crownAnimation: _crown,
        playAnimation: _play,
        readyToDeal: _readyToDeal,
        onDeal: () {
          if (mounted && _readyToDeal) setState(_dealCards);
        },
        // While choosing the King a tap crowns. During play a tap opens the
        // courtier's card, or with no roles just flips the card-reveal
        // token.
        seatTap: (i) => _choosingKing
            ? (_digital ? null : () => _sendCrown(i))
            : game.hasRoles
                ? () => _showCourtier(i)
                : () => _toggleSpoke(i),
        cardText: _cardText,
        onTaskTap: _showTaskDetail,
        onDragStart: _onDragStart,
        onDragUpdate: _onDragUpdate,
        onDragEnd: _onDragEnd,
      ),
    );
  }

  /// The end of a round. A win rains gold crowns and confetti and the
  /// result springs up; a loss pulses red and the result drops in with a
  /// shudder. Either way you can set the points for the next round here.
  /// The round's result, over the table.
  Widget _buildOutcomeOverlay() {
    final won = game.outcome == RoundOutcome.won;
    return OutcomeOverlay(
      animation: _outcome,
      won: won,
      dealId: game.dealId,
      child: game.isTutorial
          ? LessonCard(
              lesson: game.lesson, won: won, onRetry: _retryRound, onNext: _nextLesson)
          : OutcomeCard(
              game: game,
              won: won,
              you: _you,
              onScreen: _digital,
              crowns: _effects?.crowns ?? 0,
              nextTarget: _nextTarget,
              canUndo: game.lastMark != null,
              wording: _cardText,
              onRetry: _retryRound,
              onDeal: (target) => _shuffleTasks(target: target),
              onChapter: _beginChapter,
              onUndo: _undoLastMark),
    );
  }

  /// Puts the last done/failed mark back, for a mis-tap that ended the
  /// round by mistake: sends the action. The round's result is taken back
  /// off the record when it comes back.
  void _undoLastMark() {
    if (game.lastMark == null) return;
    _link.send(UndoMark(_you));
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
