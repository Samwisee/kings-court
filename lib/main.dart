/// The King's Court: the app, and its one page, the table. The state of
/// the table (HomePage) lives here; the widgets it's built from are in the
/// part files in lib/home, one family each. See README.md for the map.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'chronicle.dart';
import 'courtiers.dart';
import 'story.dart';
import 'models.dart';
import 'engine/bot.dart';
import 'engine/cards.dart';
import 'engine/conflicts.dart';
import 'engine/deal_mix.dart';
import 'engine/contest.dart';
import 'engine/inference.dart';
import 'engine/match.dart';
import 'engine/rules.dart';
import 'game/controller.dart';
import 'net/table_link.dart';
import 'play/card_view.dart';
import 'play/contest_table.dart';
import 'play/throne_room.dart';
import 'play/tutorial_intro.dart';
import 'play/rules_page.dart';
import 'sfx.dart';
import 'task_help.dart';
import 'theme.dart';
import 'tutorial.dart';
import 'widgets.dart';

part 'home/geometry.dart';
part 'home/welcome.dart';
part 'home/menu.dart';
part 'home/chronicle_ui.dart';
part 'home/setup.dart';
part 'home/house_banner.dart';
part 'home/task_widgets.dart';
part 'home/saves.dart';
part 'home/card_tracker.dart';
part 'home/transitions.dart';
part 'home/mini_card.dart';
part 'home/buttons.dart';

void main() {
  runApp(const TheKingsCourtApp());
}

class TheKingsCourtApp extends StatelessWidget {
  const TheKingsCourtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "The King's Court",
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomePage(),
    );
  }
}


/// Speeds up the on-screen card game for widget tests.
@visibleForTesting
class HomePageTestHooks {
  static void fast() {
    _HomePageState.botDelay = const Duration(milliseconds: 1);
    _HomePageState.trickPause = const Duration(milliseconds: 4);
    _HomePageState.autoPlayStep = const Duration(milliseconds: 2);
    _HomePageState.flipStagger = const Duration(milliseconds: 2);
    _HomePageState.botBudget = 30;
    CharacterToken.alive = false;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// The game itself: its state, the moves, saving (game/controller.dart).
  /// This page draws it.
  final _ctrl = GameController();
  GameState get game => _ctrl.game;
  set game(GameState g) => _ctrl.game = g;
  int playerCount = 4;
  int targetPoints = 5;

  /// Card centres as fractions of the table size, so they survive rotation
  /// and window resizes.
  final Map<Task, Offset> _pos = {};
  final Map<Task, double> _tilt = {};

  /// Draw order: the last card is on top.
  List<Task> _order = [];

  Task? _dragging;
  int? _hoverSeat;

  /// While someone holds the felt: the seat nearest their finger. Every
  /// card turns to face that side of the table.
  int? _readerSeat;
  int _dealtFor = -1;
  Size _tableSize = Size.zero;
  double _cardWidth = 120;

  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

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

  /// Crowns earned for the chapter just won, and what it had before (so an
  /// undo can put it back).
  int _crownsEarned = 0;
  int? _crownsBefore;

  /// Dynasty: where the end-of-round story has got to.
  _DynastyStep _step = _DynastyStep.result;
  int? _dilemma;

  /// A divided court: which side each seat takes (true for the first
  /// choice), settled by a Trial of Hearts.
  Map<int, bool> _votes = {};

  /// Further matters before the throne before the next hand is dealt.
  int _mattersLeft = 0;

  /// The sides are secret: shown only once the trial is played (at the
  /// table), or at the end of the trial (on screen).
  bool _sidesShown = false;

  /// The Trial of Hearts being played on screen, if any.
  ContestState? _contest;
  final _contestKey = GlobalKey<ContestTableState>();
  /// What came of the King's choice: who (if anyone) and how they took it.
  List<(Courtier?, String, CharacterMood)> _verdict = const [];
  String _verdictStory = '';

  /// The last done/failed mark, so it can be undone from the round result.
  (Task, TaskStatus)? _lastMark;

  final _tableKey = GlobalKey();

  /// Games saved from last time, one for each way to play, newest first.
  /// Play on the welcome screen offers them.
  List<_SavedGame> _saves = [];

  /// Best win streak across every game on this device.
  int _bestStreak = 0;

  /// Before save slots, one game was kept under this key. It moves to its
  /// mode's slot the first time it's loaded.
  static const _legacySaveKey = 'kingsCourt.game';
  static String _slotKey(GameMode mode) => GameController.slotKey(mode);
  static const _bestKey = GameController.bestKey;
  static const _chronicleKey = 'kingsCourt.chronicle';
  static const _soundKey = 'kingsCourt.sound';
  static const _uprightKey = 'kingsCourt.upright';
  static const _suitsKey = 'kingsCourt.fourColourSuits';
  static const _keysKey = 'kingsCourt.showShortcuts';

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
  _SetupArgs? _setupArgs;

  /// Setup opened from Continue: it lists the saved games instead.
  bool _setupContinuing = false;

  /// Chronicle progress on this device.
  ChronicleProgress _progress = ChronicleProgress();

  @override
  void initState() {
    super.initState();
    _moves = _link.moves.listen(_onMove);
    // What a save holds beside the game: the real table's layout.
    _ctrl.saveExtras = () => {
          'playerCount': playerCount,
          'targetPoints': targetPoints,
          'cardWidth': _cardWidth,
          'dealt': _dealtFor == game.dealId,
          'pos': [
            for (final t in game.tasks)
              if (_pos[t] != null) [_pos[t]!.dx, _pos[t]!.dy] else null,
          ],
          'tilt': [for (final t in game.tasks) _tilt[t] ?? 0.0],
        };
    _ctrl.knownBest = () => _bestStreak;
    WidgetsBinding.instance.addObserver(this);
    // Create the animation controllers now, so dispose never makes one.
    for (final c in [_deal, _crown, _play, _outcome, _outcomeHold, _coronation]) {
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
    // Arrows keep moving while held; everything else acts once.
    const arrows = [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ];
    if (e is! KeyDownEvent && !(e is KeyRepeatEvent && arrows.contains(key))) return false;
    final handled = [
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      ..._cardKeys,
    ];
    if (!handled.contains(key)) return false;
    // Not while typing (player names), or off the on-screen game.
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) return false;
    // Nor under a dialog or another page.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (!mounted ||
        !_inGame ||
        _setupArgs != null ||
        !_digital ||
        _cards.dealId != game.dealId) {
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
    final hand = _cards.hands.length > _you ? _cards.hands[_you] : const <PlayingCard>[];
    // A card by its key: 1 to 9, 0, - and = along the top row, then Q W E.
    final keyAt = _cardKeys.indexOf(key);
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
        if (t.assignedPlayerIndex == null &&
            !game.isCharged(t) &&
            (!_yourPick || (_mayTake(t) && game.canTake(t, _you))))
          t
    ];
    final showing = _revealing || _speakPromptDue;
    final playable = [
      for (final c in hand)
        if (showing
            ? _cards.revealFor(_you, c) != null
            : _cards.turn == _you
                ? _cards.legalFor(_you).contains(c)
                : _cards.current.isEmpty ||
                    legalPlays(hand, _cards.current.first).contains(c))
          c
    ];
    final choices = playable.isEmpty ? hand : playable;
    final stops = _kbStops(open, choices);
    if (stops.isEmpty) return false;
    final here = _kbHere(stops);
    void go(_KbStop to) => _ui(() {
          _kbRow = to.row;
          if (to.item case final Task t) _kbTask = t;
          if (to.item case final PlayingCard c) _kbCard = c;
          _kbLast = to.rect;
        });
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      final up = key == LogicalKeyboardKey.arrowUp;
      // Nothing chosen yet: start from your hand.
      final hand0 = [for (final st in stops) if (st.row == 0) st];
      if (here == null && _kbLast == null && !up && hand0.isNotEmpty) {
        go(hand0[hand0.length ~/ 2]);
        return true;
      }
      final from = here?.rect ?? _kbLast ?? _rectOn(_handKey);
      if (from == null) return false;
      final ahead = [
        for (final st in stops)
          if (st.item != here?.item &&
              (up
                  ? st.rect.center.dy < from.top + 4
                  : st.rect.center.dy > from.bottom - 4))
            st
      ];
      if (ahead.isEmpty) return true;
      // The nearest row that way, then the nearest thing along it.
      double gap(_KbStop st) =>
          up ? from.top - st.rect.bottom : st.rect.top - from.bottom;
      final nearest = ahead.reduce((a, b) => gap(a) <= gap(b) ? a : b);
      final row = [
        for (final st in ahead)
          if (st.rect.top < nearest.rect.bottom && st.rect.bottom > nearest.rect.top) st
      ];
      go(_closestTo(row, from));
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      final step = key == LogicalKeyboardKey.arrowRight ? 1 : -1;
      var kind = here?.row ?? _kbRow;
      if (!stops.any((st) => st.row == kind)) kind = 0;
      final same = _readingOrder([for (final st in stops) if (st.row == kind) st]);
      if (same.isEmpty) return false;
      final at = here == null ? -1 : same.indexWhere((st) => st.item == here.item);
      if (at < 0) {
        // Nothing chosen yet (or it's gone): start nearest the last choice.
        go(_kbLast == null
            ? same[step > 0 ? 0 : same.length - 1]
            : _closestTo(same, _kbLast!));
      } else {
        go(same[(at + step) % same.length]);
      }
      return true;
    }
    // Enter: open the chosen task (its Take button is ready for Enter),
    // press the button, or play (or show) the chosen card.
    if (here == null) return false;
    switch (here.item) {
      case final Task t:
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
  List<_KbStop> _kbStops(List<Task> open, List<PlayingCard> cards) => [
        for (final t in open)
          if (_openTaskKeys[t] case final key?)
            if (_rectOn(key) case final r?) _KbStop(1, t, r),
        if (_kbButtonPress != null)
          if (_rectOn(_kbButtonKey) case final r?) _KbStop(2, null, r),
        if (_rectOn(_handKey) case final area?)
          for (final c in cards)
            if (_handRects[c] case final r?) _KbStop(0, c, r.shift(area.topLeft)),
      ];

  /// Where the arrow keys are now, if it's still there to stop on.
  _KbStop? _kbHere(List<_KbStop> stops) {
    for (final st in stops) {
      if (st.row != _kbRow) continue;
      if (_kbRow == 1 && st.item == _kbTask) return st;
      if (_kbRow == 0 && st.item == _kbCard) return st;
      if (_kbRow == 2) return st;
    }
    return null;
  }

  /// The stop in [stops] nearest [r]: across first, then up or down.
  static _KbStop _closestTo(List<_KbStop> stops, Rect r) {
    double d(_KbStop st) =>
        (st.rect.center.dx - r.center.dx).abs() +
        (st.rect.center.dy - r.center.dy).abs() * 0.25;
    return stops.reduce((a, b) => d(a) <= d(b) ? a : b);
  }

  /// [stops] as they're read: row by row from the top, each row left to
  /// right (the tasks are packed in columns of different heights, so a
  /// row is whatever overlaps it side by side).
  static List<_KbStop> _readingOrder(List<_KbStop> stops) {
    final rest = [...stops]..sort((a, b) => a.rect.top.compareTo(b.rect.top));
    final out = <_KbStop>[];
    while (rest.isNotEmpty) {
      final first = rest.first;
      final row = [
        for (final st in rest)
          if (st.rect.top < first.rect.bottom - 4) st
      ]..sort((a, b) => a.rect.left.compareTo(b.rect.left));
      out.addAll(row);
      rest.removeWhere(row.contains);
    }
    return out;
  }

  /// The keys that play the cards in your hand, left to right.
  static final _cardKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.minus,
    LogicalKeyboardKey.equal,
    LogicalKeyboardKey.keyQ,
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyE,
  ];

  /// What's printed on each of those keys.
  static const _cardKeyLabels = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 'Q', 'W', 'E'];

  /// Where the arrow keys are: your hand (0), the tasks on the table (1)
  /// or the Skip or Pass button (2).
  int _kbRow = 0;
  Task? _kbTask;

  /// Where the last thing chosen with the arrow keys was, so the next
  /// choice is whatever is nearest it (when a card is played or a task
  /// taken, its neighbour is chosen).
  Rect? _kbLast;

  /// The Skip or Pass button beside your hand, while it's there.
  final _kbButtonKey = GlobalKey();

  /// A choice with a way out is up: show a card or Skip, take a task or
  /// Pass. The button sits beside your hand.
  bool get _barChoice =>
      (_speakPromptDue || (game.pickTurn == _you && game.canPass(_you))) &&
      _toast == null;

  /// What that button does, for the Enter key.
  VoidCallback? get _kbButtonPress =>
      !_barChoice ? null : _speakPromptDue ? _skipShowing : _passPick;

  /// Skip: you won't show a card before the tasks are taken.
  void _skipShowing() => _startChoosing();

  /// Pass on taking a task this time round.
  void _passPick() => setState(() => game.pass(_you));

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
      Palette.fourColourSuits = prefs.getBool(_suitsKey) ?? false;
      _showKeys = prefs.getBool(_keysKey) ?? false;
      final saves = await _readSaves(prefs);
      if (!mounted) return;
      setState(() {
        _bestStreak = best;
        _progress = progress;
        _saves = saves;
      });
    } catch (_) {
      // No saved game (or storage unavailable): start fresh.
    }
  }

  /// Reads every saved game still in progress, newest first, moving an old
  /// single save into its slot.
  static Future<List<_SavedGame>> _readSaves(SharedPreferences prefs) async {
    final legacy = prefs.getString(_legacySaveKey);
    if (legacy != null) {
      try {
        final data = jsonDecode(legacy) as Map<String, dynamic>;
        final g = GameState.fromJson(data['game'] as Map<String, dynamic>);
        if (g != null && prefs.getString(_slotKey(g.mode)) == null) {
          await prefs.setString(_slotKey(g.mode), legacy);
        }
      } catch (_) {}
      await prefs.remove(_legacySaveKey);
    }
    final saves = <_SavedGame>[];
    for (final mode in GameMode.values) {
      if (mode == GameMode.tutorial) continue;
      final raw = prefs.getString(_slotKey(mode));
      if (raw == null) continue;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final g = GameState.fromJson(data['game'] as Map<String, dynamic>);
        if (g == null || g.outcome != RoundOutcome.inProgress) continue;
        saves.add(_SavedGame(g, data,
            DateTime.fromMillisecondsSinceEpoch(data['savedAt'] as int? ?? 0)));
      } catch (_) {
        // A save that no longer reads is skipped.
      }
    }
    saves.sort((a, b) => b.at.compareTo(a.at));
    return saves;
  }

  /// Saves after every change, so closing the app mid-round loses nothing.
  /// Skipped while a card is being dragged; saved again when it's dropped.
  ///
  /// A change to what's on screen only (a menu, a toast, a drag, the
  /// tracker, a key press): rebuilds without saving or waking the game.
  void _ui(VoidCallback fn) => super.setState(fn);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (_dragging == null && _handDragCard == null && _inGame) _save();
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chronicleKey, jsonEncode(_progress.toJson()));
      await prefs.setBool(_soundKey, Sfx.enabled);
      await prefs.setBool(_uprightKey, _upright);
      await prefs.setBool(_suitsKey, Palette.fourColourSuits);
      await prefs.setBool(_keysKey, _showKeys);
    } catch (_) {}
  }

  /// The dilemma on the table, for tests.
  @visibleForTesting
  int? get debugDilemma => _dilemma;

  /// Starts a Chronicle chapter directly, skipping the setup dialog.
  @visibleForTesting
  void debugStartChapter(int chapter, int players) => _startGame(
      players,
      0,
      [for (int i = 0; i < players; i++) 'Player ${i + 1}'],
      GameMode.chronicle,
      chapter: chapter);


  /// Starts (or retries) a Chronicle chapter with the same players.
  void _beginChapter(int chapter) {
    _progress.startAttempt(chapter);
    _saveSettings();
    setState(() {
      game.chapter = chapter;
      targetPoints = chronicle[chapter].points;
      game.shuffleTasks(playerCount, targetPoints);
      _resetTable();
    });
  }

  /// Picks up a saved game exactly where it was left.
  void _continueSaved(_SavedGame saved) {
    final g = saved.game;
    final data = saved.data;
    setState(() {
      game = g;
      playerCount = data['playerCount'] as int;
      targetPoints = (data['targetPoints'] as int).clamp(1, maxTarget);
      _resetTable();
      final pos = data['pos'] as List;
      final tilt = data['tilt'] as List;
      final restored = data['dealt'] == true &&
          pos.length == g.tasks.length &&
          pos.every((p) => p != null);
      if (restored) {
        _cardWidth = (data['cardWidth'] as num).toDouble();
        for (int i = 0; i < g.tasks.length; i++) {
          final p = pos[i] as List;
          _pos[g.tasks[i]] = Offset(
              (p[0] as num).toDouble(), (p[1] as num).toDouble());
          _tilt[g.tasks[i]] = (tilt[i] as num).toDouble();
        }
        _order = List.of(g.tasks);
        _dealtFor = g.dealId; // already on the table: no re-deal
      }
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
    _deal.dispose();
    _handSnap.dispose();
    _handDragV.dispose();
    _taskDragTick.dispose();
    _stillTick.dispose();
    _crown.dispose();
    _coronation.dispose();
    _outcomeHold.dispose();
    _play.dispose();
    _outcome.dispose();
    _keepAwake(false);
    _botTimer?.cancel();
    _crownTimer?.cancel();
    for (final t in [..._trickTimers, ..._flightTimers]) {
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
  bool get _choosingKing => _inGame && game.kingIndex == null;

  /// A decree (or a Dynasty round's tidings) waiting to be read out after
  /// the crowning.
  bool get _decreePending =>
      !_choosingKing &&
      (game.decree != null || game.currentTiding != null) &&
      _decreeReadFor != game.dealId &&
      _dealtFor != game.dealId;

  bool get _readyToDeal =>
      !_choosingKing && !_decreePending && _dealtFor != game.dealId;

  int _points(Task t) => t.getPointsForPlayerCount(playerCount);

  _TableGeometry get _geo => _TableGeometry(
      _tableSize, game.players.length, (t) => t.boardText(playerCount),
      fixedCardWidth: _dealtFor == game.dealId ? _cardWidth : null,
      upright: _upright || game.digital);

  Offset _toPx(Offset f) =>
      Offset(f.dx * _tableSize.width, f.dy * _tableSize.height);
  Offset _toFrac(Offset p) =>
      Offset(p.dx / _tableSize.width, p.dy / _tableSize.height);

  // --------------------------------------------------------- on-screen cards
  //
  // With on-screen cards the table runs the round itself: it deals hands,
  // the King card crowns the King, bots pick tasks and play for every seat but
  // yours (seat 0), and each task marks itself as the tricks fall. Every
  // mode works the same way on top of this.

  bool get _digital => game.digital;
  static const _you = 0;
  final _rand = math.Random();
  final _bot = Bot();
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

  MatchState get _cards => game.cards!;

  /// The cards' view of the round, with this table's tasks, owners and
  /// rules on who may take what.
  MatchState _matchView() {
    final c = _cards;
    c.target = targetPoints;
    c.king = game.kingIndex ?? c.king;
    c.tasks = [
      for (final t in game.tasks)
        MatchTask(t,
            owner: t.assignedPlayerIndex, x: c.announced[t.description])
    ];
    c.pickTurn = game.pickTurn;
    c.takeRule = (i, seat) => game.canTake(game.tasks[i], seat);
    return c;
  }

  bool get _tasksSettled =>
      game.tasks.every((t) => t.assignedPlayerIndex != null) &&
      game.tasks.every((t) =>
          !needsX(t.description) || _cards.announced.containsKey(t.description));

  bool get _playing =>
      _digital &&
      !_choosingKing &&
      !_decreePending &&
      _dealtFor == game.dealId &&
      game.outcome == RoundOutcome.inProgress &&
      _tasksSettled;

  bool get _yourPlay =>
      _playing && !_autoPlaying && _lastTrick == null && _cards.turn == _you;

  /// Every task is done with cards still in hand: the table plays the rest
  /// of the round out by itself, quickly, like a won game of FreeCell
  /// sending its cards home.
  bool _autoPlaying = false;
  int _autoDeal = -1;
  static Duration autoPlayStep = const Duration(milliseconds: 140);

  /// After a trick: if every task is done already with cards still in
  /// hand, play the round out (and judge the tasks at the end). True when
  /// it starts.
  bool _maybeAutoFinish() {
    if (_autoPlaying || !_playing || game.isTutorial) return false;
    final c = _cards;
    if (c.current.isNotEmpty || c.tricks.length >= c.totalTricks) return false;
    final open = [
      for (final t in game.tasks)
        if (t.status == TaskStatus.pending && t.assignedPlayerIndex != null) t
    ];
    // Sealed tasks hang on their order, and traitors on their schemes:
    // those rounds play on by hand.
    if (open.isEmpty || open.any((t) => t.seal != null)) return false;
    if (game.isDynasty && game.antagonists.isNotEmpty) return false;
    final v = _roundView;
    final verdicts = [
      for (final t in open)
        taskRules[t.description]!(
            v, t.assignedPlayerIndex!, c.announced[t.description])
    ];
    if (verdicts.contains(Verdict.failed)) return false;
    // Only once every task has actually been done: a round that merely
    // can't be lost is still played to the end by hand.
    final certain = verdicts.every((x) => x == Verdict.done);
    if (!certain) return false;
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
    final c = _cards;
    if (game.dealId != _autoDeal) {
      // A new round or game began meanwhile: hand play back.
      setState(() => _autoPlaying = false);
      _scheduleBot();
      return;
    }
    // Every card played: the last trick's pause ends the play-out.
    if (c.tricks.length >= c.totalTricks) return;
    if (_lastTrick == null) {
      final seat = c.turn;
      final legal = c.legalFor(seat);
      if (legal.isNotEmpty) _playCard(seat, legal.first);
    }
    _trickTimers.add(Timer(autoPlayStep, _autoStep));
  }

  bool get _yourPick =>
      _digital &&
      !_choosingKing &&
      !_decreePending &&
      _dealtFor == game.dealId &&
      game.pickTurn == _you;

  /// Deals hands for a new round (or after a reload with an old deal), and
  /// lets the King card choose the King.
  void _syncCards() {
    if (!_digital || !_inGame) return;
    final c = _cards;
    if (c.dealId != game.dealId) {
      c.dealFor(
        game.dealId,
        _rand,
        // Solo Dynasty: you are always the King.
        king: game.kingIndex ?? (game.isDynasty ? _you : null),
        mayRule: (seat) => !game.isAntagonist(seat),
        accept: (hands, inPlay) => game.tasks.every((t) =>
            playableWith(t.description, hands, inPlay) &&
            _possible(t, hands, inPlay)),
      );
      // The tutorial deals the same cards every time, with you as King.
      if (game.isTutorial) {
        final d = lessons[game.lesson].deal();
        c.hands = d.hands;
        c.setAside = d.setAside;
        c.king = _you;
        c.leader = _you;
      }
      // Any task the deal still makes impossible is swapped for one that
      // can be done.
      for (int i = 0; i < game.tasks.length && !game.isTutorial; i++) {
        final t = game.tasks[i];
        if (t.assignedPlayerIndex != null || _possible(t, c.hands, c.inPlay)) {
          continue;
        }
        final names = game.tasks.map((x) => x.description).toSet();
        final swap = (List.of(GameState.taskPool)..shuffle(_rand)).where((p) =>
            !names.contains(p.description) &&
            !needsX(p.description) &&
            _points(p) <= _points(t) + 1 &&
            fitsDeal([for (final o in game.tasks) if (o != t) o.description],
                p.description, math.max(3, game.players.length)) &&
            playableWith(p.description, c.hands, c.inPlay) &&
            _possible(p, c.hands, c.inPlay)).firstOrNull;
        if (swap != null) game.tasks[i] = swap.freshCopy()..seal = t.seal;
      }
      _lastTrick = null;
      _collecting = false;
      _revealing = false;
      _wantsToSpeak = false;
    }
    // No task cards to deal onto a circle: the round is ready once the King
    // is crowned and any tidings or decree are read.
    if (!_choosingKing && !_decreePending && _dealtFor != game.dealId) {
      _dealtFor = game.dealId;
    }
    // Solo Dynasty: you are crowned in the throne room, not at the table.
    if (_choosingKing && game.solo) {
      game.setKing(_you);
    }
    if (_choosingKing && _crowning == null && _crownTimer == null) {
      // Long live the King first; the tasks are shuffled out after.
      _crownTimer = Timer(const Duration(milliseconds: 350), () {
        _crownTimer = null;
        if (mounted && _choosingKing) _crownKing(_cards.king);
      });
    }
  }

  /// Whether [t] could still be done by someone allowed to take it, with
  /// these cards in play: no task should be lost before the first trick.
  bool _possible(Task t, List<List<PlayingCard>> hands, Set<PlayingCard> inPlay) {
    if (needsX(t.description) || hands.isEmpty || hands.first.isEmpty) return true;
    final v = RoundView(
        players: hands.length,
        king: game.kingIndex ?? _you,
        tricks: const [],
        totalTricks: hands.first.length,
        inPlay: inPlay);
    final rule = taskRules[t.description]!;
    return [
      for (int s = 0; s < hands.length; s++)
        if (t.assignedPlayerIndex == s || game.canTake(t, s)) s
    ].any((s) {
      try {
        return rule(v, s, null) != Verdict.failed;
      } catch (_) {
        return true;
      }
    });
  }

  /// Lets whichever bot is due act, after a short pause.
  /// A card you chose early, played as soon as it's your turn.
  PlayingCard? _queued;

  void _scheduleBot() {
    if (_queued != null && _yourPlay) {
      final card = _queued!;
      _queued = null;
      if (_cards.legalFor(_you).contains(card)) {
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
        _cards.current.isEmpty &&
        _lastTrick == null) {
      _wantsToSpeak = false;
      scheduleMicrotask(() {
        if (mounted) _speak();
      });
      return;
    }
    if (!_digital || _botTimer != null || _botBusy) return;
    // Before anyone takes a task, the table pauses a moment so a card can
    // be shown first.
    final delay = game.isTutorial ? botDelay * 2 : botDelay;
    _botTimer = Timer(delay, () {
      _botTimer = null;
      if (mounted) _botStep();
    });
  }

  /// Picking hasn't started: nobody has taken a task yet (royal charges
  /// aside), and a courtier picks first.
  bool get _openingPick =>
      _digital &&
      game.pickTurn != null &&
      _cards.dealId == game.dealId &&
      // Nobody has picked yet (tasks that went straight to the only player
      // who could take them, or royal charges, don't count).
      game.picksMade == 0;

  /// Where each open task starts from in the deal (the middle of the
  /// table), measured once per deal.
  Map<Task, Offset> _dealFrom = {};
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
      !_storyActive &&
      _speakAskedFor != game.dealId &&
      _openingPick &&
      _mayAskToSpeak;

  /// Picking begins: courtiers may show a card a task on the table needs,
  /// then the first pick is made.
  void _startChoosing() {
    setState(() => _speakAskedFor = game.dealId);
    final open = [for (final t in game.tasks) if (t.assignedPlayerIndex == null) t];
    for (int seat = 0; seat < game.players.length; seat++) {
      if (seat == _you || game.spoke[seat] || !game.canSpeak(seat)) continue;
      for (final card in _cards.hands[seat]) {
        if (_cards.revealFor(seat, card) == null) continue;
        if (open.any((t) => neededCards(t.description).contains(card))) {
          _reveal(seat, card);
          break;
        }
      }
    }
  }

  /// A bot is thinking (a slice at a time, so the screen stays smooth).
  bool _botBusy = false;

  /// What the round looks like now, to check nothing moved while a bot
  /// was thinking.
  String get _moment => _digital
      ? '${game.dealId}|${game.pickTurn}|${game.tasks.where((t) => t.assignedPlayerIndex != null).length}|'
          '${_cards.announced.length}|${_cards.tricks.length}|${_cards.current.length}'
      : '';

  Future<void> _botStep() async {
    if (_botBusy) return;
    _botBusy = true;
    var acted = false;
    try {
      acted = await _botThink();
    } finally {
      _botBusy = false;
    }
    if (acted && mounted) _scheduleBot();
  }

  /// Returns true when a bot acted, so the next one can be scheduled.
  Future<bool> _botThink() async {
    // Traitors play for their schemes; the loyal play to stop them.
    _cards.schemes = {
      for (final seat in game.antagonists)
        if (game.schemeOf[seat] != null) seat: game.schemeOf[seat]!
    };
    if (_autoPlaying ||
        _revealing ||
        _speakPromptDue ||
        (_wantsToSpeak && _playing && _cards.current.isEmpty)) {
      return false;
    }
    if (!_digital ||
        _choosingKing ||
        _crowning != null ||
        _decreePending ||
        _dealtFor != game.dealId ||
        _dragging != null ||
        _lastTrick != null ||
        game.outcome != RoundOutcome.inProgress) {
      return false;
    }
    final view = _matchView();
    _bot.budget = botBudget;
    final before = _moment;
    final picker = game.pickTurn;
    if (picker != null) {
      if (picker == _you) return false;
      final open = [
        for (int i = 0; i < game.tasks.length; i++)
          if (game.tasks[i].assignedPlayerIndex == null) i
      ];
      if (open.isEmpty) return false;
      if (game.decree == Decree.kingsCommand) {
        // The King hands every task to whoever is best placed for it.
        final i = open.first;
        final seats = [
          for (int s = 0; s < game.players.length; s++)
            if (game.canTake(game.tasks[i], s)) s
        ];
        if (seats.isEmpty) return false;
        int best = seats.first;
        double bestScore = -1;
        for (final s in seats) {
          final assigned = {
            for (int t = 0; t < game.tasks.length; t++)
              if (game.tasks[t].assignedPlayerIndex != null)
                t: game.tasks[t].assignedPlayerIndex!,
            i: s,
          };
          final score = await _bot.scoreAsync(view, assigned, 120);
          if (score > bestScore) {
            bestScore = score;
            best = s;
          }
        }
        if (!mounted || _moment != before) return true;
        _assignTask(game.tasks[i], best);
        return true;
      } else {
        if (!open.any((i) => view.canTake(i, picker))) return false;
        // A courtier may show a card someone's task needs before picking.
        if (_botReveals(picker)) return true;
        final pick = await _bot.choosePickAsync(view, picker);
        if (!mounted || _moment != before) return true;
        // Nothing suits their hand: pass the pick on, once a round.
        if (game.canPass(picker) && _bot.lastPickScore < 0.12) {
          _quip(picker, 'I\u2019ll pass for now.');
          _showSnack('${game.players[picker].name} passes', Palette.feltDeep);
          setState(() => game.pass(picker));
          return true;
        }
        _assignTask(game.tasks[pick], picker);
        return true;
      }
    }
    if (game.tasks.any((t) => t.assignedPlayerIndex == null)) return false;
    // Numbers for the "exactly X tricks" tasks.
    for (int i = 0; i < game.tasks.length; i++) {
      final t = game.tasks[i];
      if (!needsX(t.description) ||
          _cards.announced.containsKey(t.description)) {
        continue;
      }
      if (t.assignedPlayerIndex == _you) {
        _askX(t);
        return false;
      }
      final x = await _bot.chooseXAsync(view, t.assignedPlayerIndex!, i);
      if (!mounted || _moment != before) return true;
      setState(() => _cards.announced[t.description] = x);
      return true;
    }
    // Between tricks, any bot may show a card someone needs.
    if (_cards.current.isEmpty && !game.isTutorial) {
      for (int s = 0; s < game.players.length; s++) {
        if (s != _you && _botReveals(s)) return true;
      }
    }
    final turn = _cards.turn;
    if (turn == _you) return false;
    // The tutorial's courtiers follow the lesson's script while it holds.
    if (game.isTutorial) {
      final planned =
          lessons[game.lesson].scripted(_cards.tricks.length, turn);
      if (planned != null && _cards.legalFor(turn).contains(planned)) {
        _playCard(turn, planned);
        return true;
      }
    }
    // Nothing to play (the hand is over, or a new deal is on its way).
    if (view.legalFor(turn).isEmpty) return false;
    final card = await _bot.choosePlayAsync(view, turn);
    if (!mounted || _moment != before) return true;
    _playCard(turn, card);
    return true;
  }

  /// Asks how many tricks you'll win for an "exactly X" task.
  Future<void> _askX(Task task) async {
    if (_askingX) return;
    _askingX = true;
    int x = 1;
    // The King card always wins its trick, so whoever holds it wins at
    // least one.
    final least = _cards.hands[_you].contains(PlayingCard.king) ? 1 : 0;
    final chosen = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => CourtDialog(
          title: 'How many tricks?',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SuitText(task.cardText(playerCount),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    onPressed: x > least ? () => setDialog(() => x--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text('$x',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: bodyFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 40,
                            color: Palette.gold)),
                  ),
                  IconButton.outlined(
                    onPressed: x < _cards.totalTricks
                        ? () => setDialog(() => x++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              Text(
                  least > 0
                      ? '${_cards.totalTricks} tricks in the round. You hold the King card, so you\u2019ll win at least one.'
                      : '${_cards.totalTricks} tricks in the round.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60)),
            ],
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context, x),
                child: const Text('Announce')),
          ],
        ),
      ),
    );
    _askingX = false;
    if (!mounted || !_digital) return;
    setState(() => _cards.announced[task.description] = chosen ?? x);
  }

  /// Gives a task to a seat, as dropping it there would.
  void _assignTask(Task t, int seat) {
    setState(() {
      if (game.assign(t, seat)) _play.forward(from: 0);
      _layoutOwned();
    });
  }

  // ------------------------------------------------------------ moves
  //
  // Playing and showing cards go through the table link (net/table_link
  // dart): the move is sent, and played when it comes back. On one device
  // it comes straight back; online, it would come back from the server, in
  // the same order on every device.

  /// Where moves go: this device, for now.
  TableLink get _link => _ctrl.link;
  late final StreamSubscription<MatchAction> _moves;

  /// A move coming back from the link: play it on the table.
  void _onMove(MatchAction move) {
    if (!mounted) return;
    switch (move) {
      case PlayCard(:final seat, :final card):
        _playCardNow(seat, card);
      case ShowCard(:final seat, :final card):
        _revealNow(seat, card);
      case PickTask() || Announce():
        // Tasks are still taken through the game state directly; they'll
        // move here with online play.
        break;
    }
  }

  /// Plays a card: sends the move, which plays it when it comes back.
  void _playCard(int seat, PlayingCard card) => _link.send(PlayCard(seat, card));

  /// Plays a card on the table. When it finishes a trick, the trick stays
  /// a moment, sweeps to the winner, and then the tasks are judged.
  void _playCardNow(int seat, PlayingCard card) {
    final trick = _cards.playCard(seat, card);
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
      final c = _cards;
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

  /// Marks each task done or failed from the tricks so far. Sealed tasks
  /// are judged in seal order, and one done out of order fails.
  Future<void> _judgeTasks() async {
    final c = _cards;
    final v = _roundView;
    int order(Task t) => t.seal == null ? 0 : t.seal!;
    final pending = game.tasks
        .where((t) => t.status == TaskStatus.pending && t.assignedPlayerIndex != null)
        .toList()
      ..sort((a, b) => order(a).compareTo(order(b)));
    var flipped = 0;
    for (final t in pending) {
      if (game.outcome != RoundOutcome.inProgress) break;
      final verdict = taskRules[t.description]!(
          v, t.assignedPlayerIndex!, c.announced[t.description]);
      if (verdict == Verdict.pending) continue;
      final status = verdict == Verdict.done && game.sealProblem(t) == null
          ? TaskStatus.completed
          : TaskStatus.failed;
      if (status == TaskStatus.failed) {
        _whyFailed[t] = verdict == Verdict.done
            ? 'Done out of order: ${game.sealProblem(t)}'
            : failReason(t.description, v, t.assignedPlayerIndex!,
                c.announced[t.description], [for (final p in game.players) p.name]);
      }
      if (status == TaskStatus.failed && await _offerAbsolution(t)) continue;
      if (!mounted || !game.tasks.contains(t)) continue;
      // Several done at once turn over one after another.
      if (status == TaskStatus.completed && flipped++ > 0) {
        await Future.delayed(flipStagger);
        if (!mounted || !game.tasks.contains(t)) continue;
      }
      _setTaskStatus(t, status);
    }
    // Traitors' schemes are judged by the cards too.
    if (game.outcome != RoundOutcome.inProgress && game.isDynasty) {
      setState(() {
        for (final seat in game.antagonists) {
          final scheme = game.schemeOf[seat];
          if (scheme != null) {
            game.resolveScheme(seat, schemeSucceeded(scheme, v, seat));
          }
        }
      });
    }
    // Nothing to undo when the cards decided.
    _lastMark = null;
  }

  /// Why each failed task failed this round, for the end of the round.
  final _whyFailed = <Task, String>{};

  /// The tricks so far, as the task rules see them.
  RoundView get _roundView {
    final c = _cards;
    return RoundView(
        players: c.players,
        king: game.kingIndex ?? c.king,
        tricks: c.tricks,
        totalTricks: c.totalTricks,
        inPlay: c.inPlay);
  }

  /// How far along an on-screen task is ("2/4"), for the card's corner.
  /// How [t] is going, in a sentence for its close-up (on-screen cards
  /// only, once it's been taken).
  String? _statusOf(Task t) {
    if (!_digital ||
        _cards.dealId != game.dealId ||
        t.assignedPlayerIndex == null) {
      return null;
    }
    if (t.isCompleted) return 'Done!';
    if (t.isFailed) return 'Failed this round.';
    if (_cards.tricks.isEmpty && game.pickTurn != null) {
      return 'The tricks haven’t started yet.';
    }
    return taskStatus(t.description, _roundView, t.assignedPlayerIndex!,
        _cards.announced[t.description],
        names: [for (final p in game.players) p.name]);
  }

  /// The cards [t] names that its owner has already won, to cross out.
  Set<String> _wonNamed(Task t) {
    final owner = t.assignedPlayerIndex;
    if (!_digital ||
        owner == null ||
        _cards.dealId != game.dealId ||
        t.description.startsWith("Don't")) {
      return const {};
    }
    final won = {for (final c in _roundView.won(owner)) c.label};
    return {
      for (final m in RegExp(r'[A2-9][♥♦♠♣]').allMatches(t.description))
        if (won.contains(m.group(0))) m.group(0)!
    };
  }

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
  final _trackerKey = GlobalKey<_CardTrackerState>();

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

  /// Space either side of the card tracker: it's as wide as its grid of
  /// cards (and its inlay), so on a wide screen the table shows either side.
  double _trackerInset(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cell = _CardTracker.cellFor(size);
    final dock = _CardTracker.gridWidth(cell) + 2 * _CardTracker.sidePad;
    return math.max(0.0, (size.width - dock) / 2);
  }

  /// The cards [t] is about, and what's become of each this round.
  /// The cards a task is about, marked the way the card tracker marks
  /// them: outlined in the colour of whoever played each one (with the
  /// trick it fell in), or of whoever is known to hold it.
  List<_TaskCard> _cardStates(Task t) {
    final cards = relevantCards(t.description);
    if (!_digital || _cards.dealId != game.dealId) {
      return [for (final c in cards) (card: c, edge: null, trick: null, played: false)];
    }
    final playedIn = <PlayingCard, (int, int)>{}; // trick number, seat
    for (int i = 0; i < _cards.tricks.length; i++) {
      final tr = _cards.tricks[i];
      for (int k = 0; k < tr.cards.length; k++) {
        playedIn[tr.cards[k]] = (i + 1, tr.seats[k]);
      }
    }
    for (int k = 0; k < _cards.current.length; k++) {
      playedIn[_cards.current[k]] = (_cards.tricks.length + 1, _cards.currentSeats[k]);
    }
    final holder = <PlayingCard, int>{
      if (_cards.hands.length > _you)
        for (final c in _cards.hands[_you]) c: _you,
      for (final g in guessHands(_cards, _you))
        for (final c in g.certain) c: g.seat,
    };
    return [
      for (final c in cards)
        (
          card: c,
          edge: playedIn[c] != null
              ? game.players[playedIn[c]!.$2].color
              : holder[c] != null
                  ? game.players[holder[c]!].color
                  : null,
          trick: playedIn[c]?.$1,
          played: playedIn[c] != null,
        ),
    ];
  }

  String? _progressOf(Task t) {
    if (!_digital ||
        _cards.dealId != game.dealId ||
        t.assignedPlayerIndex == null ||
        t.status != TaskStatus.pending) {
      return null;
    }
    return taskProgress(t.description, _roundView, t.assignedPlayerIndex!,
        _cards.announced[t.description]);
  }

  /// Colours of the players whose open tasks need [card] won.
  List<Color> _marksFor(PlayingCard card) => [
        for (final t in game.tasks)
          if (t.assignedPlayerIndex != null &&
              t.status == TaskStatus.pending &&
              neededCards(t.description).contains(card))
            game.players[t.assignedPlayerIndex!].color
      ];

  /// A task's wording, with the announced number filled in.
  String _cardText(Task t) {
    final text = t.boardText(playerCount);
    final x = _digital ? _cards.announced[t.description] : null;
    if (x == null) return text;
    final secret = t.description.contains('secret') && t.assignedPlayerIndex != _you;
    return text.replaceFirst('X', secret ? '?' : '$x');
  }

  /// What the table says is happening, under the cards.
  String get _cardStatus {
    if (_lastTrick != null) {
      final w = _lastTrick!.winner;
      return w == _you
          ? 'You win the trick'
          : '${game.players[w].name} wins the trick';
    }
    if (_choosingKing) return '';
    if (game.pickTurn != null) {
      if (_speakPromptDue) return 'Share a card?';
      if (game.pickTurn == _you) {
        return game.decree == Decree.kingsCommand
            ? "King's Command: hold a task to hand it out"
            : game.canPass(_you)
                ? 'Hold a task to take it, or'
                : 'Hold a task to take it';
      }
      if (_speakPromptDue) return 'Share a card?';
      return '${game.players[game.pickTurn!].name} is choosing a task…';
    }
    if (!_tasksSettled) return 'Announcing numbers…';
    if (game.outcome != RoundOutcome.inProgress) return '';
    final c = _cards;
    if (c.turn == _you) {
      if (c.current.isEmpty) return 'Your lead';
      final led = c.led!;
      return 'Your turn: follow ${switch (led.suit) {
        Suit.hearts => 'hearts',
        Suit.diamonds => 'diamonds',
        Suit.spades => 'spades',
        Suit.clubs => 'clubs',
        Suit.court => 'with a Court Card',
      }}';
    }
    return '${game.players[c.turn].name} is thinking…';
  }

  /// Your hand along the bottom, fanned to fit: cards you may play stand
  /// up, the rest dim. Tap one to play it.
  /// A small gold button in the hand's status line.
  /// How wide the hand's cards may spread on a wide screen.
  double _handLimit = double.infinity;

  /// The height the on-screen game has, table and hand together.
  double _gameHeight = 800;

  Widget _buildHand() {
    final c = _cards;
    // Once a suit is led you may choose your card early; it's played as
    // soon as your turn comes.
    final canQueue = _playing &&
        !_yourPlay &&
        c.dealId == game.dealId &&
        c.current.isNotEmpty &&
        !c.currentSeats.contains(_you) &&
        _lastTrick == null;
    if (!canQueue && !_yourPlay) _queued = null;
    // Showing a card: only those you may show stand out.
    final showing = _revealing || _speakPromptDue;
    final yourTurn = _yourPlay || showing;
    final legal = showing
        ? {
            for (final card in c.dealId == game.dealId ? c.hands[_you] : const <PlayingCard>[])
              if (c.revealFor(_you, card) != null) card
          }
        : _yourPlay
            ? c.legalFor(_you).toSet()
            : const <PlayingCard>{};
    return Container(
      width: double.infinity,
      // Room below the cards so they clear the brass trim.
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
      decoration: const BoxDecoration(
        color: Palette.feltDeep,
        border: Border(top: BorderSide(color: Color(0x66D4A63A))),
      ),
      child: Center(
        child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _handLimit),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // One height whatever it holds (two lines of words, a button), so
          // your hand never moves up or down.
          SizedBox(
            height: 56,
            child: Row(
            children: [
              Expanded(
                child: _barChoice
                    // A choice with a way out: show a card or skip, pick a
                    // task or pass. Both right in the middle, where you're
                    // looking, the button always in the same place.
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                                _speakPromptDue ? 'Show a card, or' : 'Hold a task to take it, or',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontFamily: bodyFont,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    shadows: _feltShadow,
                                    color: Palette.gold)),
                          ),
                          const SizedBox(width: 8),
                          KeyedSubtree(
                            key: _kbButtonKey,
                            child: _speakPromptDue
                                ? _GlowButton(
                                    key: const ValueKey('skip'),
                                    label: 'Skip',
                                    focused: _kbRow == 2,
                                    onPressed: _skipShowing)
                                : _GlowButton(
                                    key: const ValueKey('pass'),
                                    label: 'Pass',
                                    focused: _kbRow == 2,
                                    onPressed: _passPick),
                          ),
                        ],
                      )
                    : AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                      fontFamily: bodyFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      shadows: _feltShadow,
                      color: yourTurn || _yourPick || _revealing
                          ? Palette.gold
                          : Colors.white70),
                  child: SuitText(
                      _toast != null
                          ? _toast!
                          : _revealing
                          ? 'Tap a card to show it (highest, lowest or only of its suit)'
                          : _queued != null
                          ? 'You\u2019ll play the ${_queued!.label} on your turn (tap it again to change your mind)'
                          : _wantsToSpeak && _playing
                              ? 'You\u2019ll show a card after this trick'
                              : _cardStatus,
                      style: TextStyle(
                          color: yourTurn || _yourPick || _revealing
                              ? Palette.gold
                              : Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ),
              ),
              // The action of the moment, beside what's happening: save
              // your card for later, or pass on picking.

              // Every card: which are played, which are still to come.
              if (_cards.dealId == game.dealId && !_storyActive)
                IconButton(
                  tooltip: 'Card tracker',
                  onPressed: _showCardTracker,
                  icon: const TrackerIcon(size: 26),
                ),

              // The speech token: show one card, once a round.
              SizedBox(
                width: 44,
                // While Skip is showing beside it, this is its X: the
                // two do the same, so they look linked.
                child: IconButton(
                  tooltip: _speakPromptDue
                      ? 'Skip showing a card'
                      : _revealing
                          ? 'Don\u2019t show a card'
                          : 'Show a card (once a round)',
                  onPressed: _speakPromptDue
                      ? _skipShowing
                      : _mayAskToSpeak || _revealing
                          ? _speak
                          : null,
                  icon: _revealing || _speakPromptDue
                      ? const Icon(Icons.close_rounded, color: Palette.gold)
                      : ShowCardIcon(
                          size: 28,
                          used: game.spoke.length > _you && game.spoke[_you],
                          color: _wantsToSpeak
                              ? Colors.white
                              : _mayAskToSpeak
                                  ? Palette.gold
                                  : Colors.white24),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(height: 2),
          LayoutBuilder(builder: (context, box) {
            final hand = c.dealId == game.dealId ? c.hands[_you] : const <PlayingCard>[];
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
                      final dragging = _handDragCard == card.id;
                      final left = (width - total) / 2 + i * step;
                      if (i == 0) {
                        _handRects.clear();
                        // The card chosen with the arrow keys was played
                        // (or shown): its neighbour is chosen instead.
                        if (_kbRow == 0 &&
                            _kbLast != null &&
                            _kbCard != null &&
                            !hand.contains(_kbCard)) {
                          final area = _rectOn(_handKey);
                          final pool = hand.where(legal.contains).toList();
                          final from = pool.isEmpty ? hand : pool;
                          if (area != null) {
                            final x = _kbLast!.center.dx - area.left;
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
                          if (_cards.revealFor(_you, card) == null) {
                            _showSnack(
                                'Only your highest, lowest or only card of a suit can be shown, never a Court Card',
                                Palette.feltDeep);
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
                                Palette.feltDeep);
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
                              Palette.feltDeep);
                          return false;
                        }
                        final area = _rectOn(_handKey);
                        if (area != null) {
                          _launchFrom[card.id] = area.topLeft +
                              Offset(left + cardW / 2, top + h / 2) +
                              (dragging ? _handDrag : Offset.zero);
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
                          valueListenable: _handDragV,
                          builder: (context, drag, child) => Transform.translate(
                              offset: dragging || _handSnapCard == card.id
                                  ? drag
                                  : Offset.zero,
                              child: child),
                          child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
                          onTap: play,
                          // Or drag it up onto the table.
                          onPanStart: (_) => _ui(() {
                            _handSnap.stop();
                            _handSnapCard = null;
                            _handDragCard = card.id;
                            _handDrag = Offset.zero;
                          }),
                          onPanUpdate: (d) => _handDrag += d.delta,
                          onPanEnd: (_) {
                            final far = _handDrag.dy < -h * 0.6;
                            // Let go first, so the play below is saved.
                            _handDragCard = null;
                            if (far && play()) {
                              _ui(() => _handDrag = Offset.zero);
                            } else {
                              _snapBack(card.id);
                            }
                          },
                          onPanCancel: () {
                            _handDragCard = null;
                            _snapBack(card.id);
                          },
                          child: AnimatedScale(
                            scale: dragging ? 1.1 : 1,
                            duration: const Duration(milliseconds: 120),
                            // Dealt face down, then turned up one by one.
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey('hand-${game.dealId}-${card.id}'),
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: 420 + i * 70),
                              curve: Interval((i * 70) / (420 + i * 70), 1,
                                  curve: Curves.easeOut),
                              builder: (context, f, child) => FlipIn(
                                  t: f,
                                  front: child!,
                                  back: CardBack(width: cardW)),
                              child: Stack(clipBehavior: Clip.none, children: [
                                PlayingCardView(
                                  card: card,
                                  width: cardW,
                                  dimmed: yourTurn && !legal.contains(card),
                                  glow: (yourTurn && card == _tutorialHint) ||
                                      _queued == card ||
                                      chosen,
                                  marks: _marksFor(card),
                                ),
                                // With the shortcuts showing: the key that
                                // plays it, in the card's bottom corner.
                                if (_keysShown && i < _cardKeyLabels.length)
                                  Positioned(
                                    left: cardW * 0.08,
                                    bottom: cardW * 0.08,
                                    child: _KeyCap(_cardKeyLabels[i], size: cardW * 0.2),
                                  ),
                              ]),
                            ),
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
  final _openTaskKeys = <Task, GlobalKey>{};
  Map<Task, Rect> _openTaskRects = {};
  final _flights = <_Flight>[];
  final _flightTimers = <Timer>[];
  Map<Task, int?> _owners = {};

  /// Where your played card left your hand, by card id.
  final _launchFrom = <int, Offset>{};

  /// A hand card being dragged towards the table, and how far.
  int? _handDragCard;

  /// The card sliding back into the hand after a drag that didn't play it.
  int? _handSnapCard;
  Offset _handSnapFrom = Offset.zero;
  late final AnimationController _handSnap = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220))
    ..addListener(() => _handDrag = _handSnapFrom *
        (1 - Curves.easeOutCubic.transform(_handSnap.value)))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _ui(() {
          _handSnapCard = null;
          _handDrag = Offset.zero;
        });
      }
    });

  void _snapBack(int id) {
    _ui(() {
      _handSnapCard = id;
      _handSnapFrom = _handDrag;
    });
    _handSnap.forward(from: 0);
  }
  /// How far the dragged card has moved. Only that card listens, so a drag
  /// moves one card, not the whole page.
  final _handDragV = ValueNotifier(Offset.zero);
  Offset get _handDrag => _handDragV.value;
  set _handDrag(Offset v) => _handDragV.value = v;

  GlobalKey _seatKey(int seat) => _seatKeys.putIfAbsent(seat, GlobalKey.new);

  /// Where a widget sits on the on-screen table (from the last frame).
  Rect? _rectOn(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final table = _digiKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || table == null || !box.attached || !box.hasSize) {
      return null;
    }
    // Global positions, since your hand sits below the table itself.
    return (box.localToGlobal(Offset.zero) - table.localToGlobal(Offset.zero)) &
        box.size;
  }

  /// Tasks on their way to their owner: laid out there but not shown yet.
  final Set<Task> _landing = {};

  /// Where each task sits in front of its owner, and how it's drawn there.
  final _destKeys = <Task, GlobalKey>{};
  final _miniStyle = <Task, (double, double)>{};

  /// How the open tasks in the middle are drawn (their font size).
  double _openFontSize = 13;

  /// Sends each newly taken task flying from the middle to its owner. The
  /// task is laid out at its owner first (hidden); a frame later, once its
  /// place is known, the flight goes exactly there.
  void _launchTaskFlights() {
    if (!_digital) return;
    final owners = {for (final t in game.tasks) t: t.assignedPlayerIndex};
    final taken = <(Task, Rect)>[];
    for (final t in game.tasks) {
      final owner = owners[t];
      if (_owners[t] != null || owner == null) continue;
      // Where the card is right now on screen (last frame), not where it
      // was when the middle was last built: that may have been part way
      // through the deal, when it was still sliding in from the side.
      final key = _openTaskKeys[t];
      final from = (key == null ? null : _rectOn(key)) ?? _openTaskRects[t];
      if (from == null) continue;
      _landing.add(t);
      taken.add((t, from));
    }
    _owners = owners;
    if (taken.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final (t, from) in taken) {
        final key = _destKeys[t];
        final to = key == null ? null : _rectOn(key);
        if (to == null) {
          _landing.remove(t);
          continue;
        }
        final style = _miniStyle[t] ?? (to.width, 12.0);
        final flight = _Flight(t, from, to, _points(t), _cardText(t),
            fromFont: _openFontSize,
            toFont: style.$2,
            toColor: t.assignedPlayerIndex == null
                ? Palette.inkSoft
                : game.players[t.assignedPlayerIndex!].color);
        _flights.add(flight);
        _flightTimers.add(Timer(_Flight.duration, () {
          if (mounted) {
            setState(() {
              _flights.remove(flight);
              _landing.remove(t);
            });
          }
        }));
      }
      setState(() {});
    });
  }

  Widget _buildDigitalTable() {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: LayoutBuilder(builder: (context, c) {
        _tableSize = Size(c.maxWidth, c.maxHeight);
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
                  // Solo Dynasty: what this hand is for, in the story.
                  if (game.solo && game.currentTiding != null && !_storyActive)
                    _stakes(game.currentTiding!),
                  // As much room as the bots' tasks need, leaving enough for
                  // the trick and your own row.
                  // (The middle always keeps room for a full-size trick.)
                  _digiOpponents(
                      width,
                      clampD(
                          c.maxHeight -
                              120 -
                              PlayingCardView.heightFor(_trickCardWidth(
                                  width, game.players.length)),
                          110,
                          math.max(110.0, c.maxHeight * 0.6))),
                  Expanded(
                    child: SizedBox(
                      key: _middleKey,
                      width: double.infinity,
                      child: _storyStage() ?? _digiMiddle(width),
                    ),
                  ),
                  KeyedSubtree(key: _yourRowKey, child: _digiYou(width)),
                ],
              ),
            ),
            for (final f in _flights) f.build(),
            if (_crowning != null)
              Positioned.fill(child: IgnorePointer(child: _digiCrowning())),
            Positioned.fill(child: IgnorePointer(child: _buildPlayFlourish())),
          ],
        );
      }),
    );
  }

  Widget _buildDecreeOverlay() => ColoredBox(
        color: Colors.black38,
        child: Center(
          child: game.currentTiding != null
              ? _tidingsScroll(
                  () => setState(() => _decreeReadFor = game.dealId))
              : DecreeScroll(
                  decree: game.decree!,
                  detail: _decreeDetail,
                  onAccept: () => setState(() => _decreeReadFor = game.dealId),
                ),
        ),
      );

  bool _seatActive(int seat) =>
      !_choosingKing &&
      (game.pickTurn != null
          ? game.pickTurn == seat
          : _playing && _lastTrick == null && _cards.turn == seat);

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
        // Courtiers make their own entrance; you simply appear.
        entrance: game.isDynasty && seat != _you && seat < game.courtiers.length
            ? entranceOf(game.courtiers[seat])
            : null,
        delay: Duration(milliseconds: 150 * seat),
        phase: seat * 0.37,
        size: size,
        child: KeyedSubtree(
        key: _seatKey(seat),
        child: SeatToken(
        player: game.players[seat],
        label: labels[seat],
        isKing: game.kingIndex == seat,
        size: size,
        highlighted: _seatActive(seat),
        exiled: game.exiledSeat == seat,
        shape: game.hasRoles && seat < game.courtiers.length
            ? game.courtiers[seat].shape
            : null,
        antagonist: game.isAntagonist(seat),
        wounds: game.isDynasty && game.kingIndex == seat ? game.kingWounds : null,
        // Loyalty and powers are in each courtier's card (tap the token),
        // keeping the table clear.
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
  Widget _miniTask(Task t, double width, {double fontSize = 12}) {
    _miniStyle[t] = (width, fontSize);
    return Opacity(
        key: ValueKey('mini-${t.description}'),
        opacity: _landing.contains(t) ? 0 : 1,
        child: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: KeyedSubtree(
            key: _destKeys.putIfAbsent(t, GlobalKey.new),
            child: _TaskChip(
            task: t,
            points: _points(t),
            text: _cardText(t),
            color: t.assignedPlayerIndex == null
                ? Palette.inkSoft
                : game.players[t.assignedPlayerIndex!].color,
            width: width,
            fontSize: fontSize,
            progress: _progressOf(t),
            struck: _wonNamed(t),
            charged: game.isCharged(t),
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
    return _crowningScene(
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
  /// A traitor's scheme as a black card: what they're plotting this hand,
  /// and once the hand is over, whether you stopped them.
  Widget _schemeCard(int seat, double width, double fontSize) {
    final result = seat < game.schemeResult.length ? game.schemeResult[seat] : null;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
        decoration: BoxDecoration(
          color: const Color(0xFF120A0C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Palette.lost, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.dangerous_rounded, size: 14, color: Palette.lost),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  result == null
                      ? 'Scheme'
                      : result
                          ? 'It worked'
                          : 'Foiled',
                  style: TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: fontSize,
                      color: result == false ? Palette.won : Palette.lost)),
              ),
            ]),
            const SizedBox(height: 2),
            SuitText(schemes[game.schemeOf[seat]!],
                style: TextStyle(
                    fontSize: fontSize, height: 1.25, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  /// The scene at stake in this hand: its name, and what hangs on it.
  Widget _stakes(Tiding t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(children: [
          Text(
              _chargeLine ??
                  'Every task done, and ${t.won.text[0].toLowerCase()}${t.won.text.substring(1)}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ]),
      );

  /// Who sits across the table: the cast at play, or the whole council
  /// while the story is told. (Role, and their seat if they have one.)
  List<(Courtier?, int?)> _tableEntries() {
    final others = [for (int i = 0; i < game.players.length; i++) if (i != _you) i];
    Courtier? roleAt(int i) =>
        game.hasRoles && i < game.courtiers.length ? game.courtiers[i] : null;
    if (game.solo && _storyActive) {
      return [
        for (final c in game.court)
          (c, game.courtiers.contains(c) ? game.courtiers.indexOf(c) : null)
      ];
    }
    return [for (final i in others) (roleAt(i), i)];
  }

  /// Courtiers who just left the table, walking off before they vanish.
  final Map<Courtier, Color> _walkingOff = {};
  List<Courtier> _lastRoles = [];

  Widget _digiOpponents(double width, double maxHeight) {
    final entries = _tableEntries();
    // Anyone no longer at the table walks away.
    final roles = [for (final (r, _) in entries) if (r != null) r];
    // Only in the Dynasty story: anywhere else a new game simply seats
    // whoever is playing, with no one from the last game walking off.
    if (!game.solo) _walkingOff.clear();
    for (final r in game.solo ? _lastRoles : const <Courtier>[]) {
      if (!roles.contains(r) && !_walkingOff.containsKey(r)) {
        _walkingOff[r] = game.colorOf(r);
        _trickTimers.add(Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _walkingOff.remove(r));
        }));
      }
    }
    _walkingOff.removeWhere((r, _) => roles.contains(r));
    _lastRoles = roles;
    final count = entries.length + _walkingOff.length;
    final colWidth = width / math.max(1, count);
    final taskWidth = math.min(colWidth - 6, width > 600 ? 170.0 : 130.0);
    final c = _cards;
    Widget column(Courtier? role, int? seat) => SizedBox(
          key: ValueKey('col-${role?.name ?? seat}'),
          width: colWidth,
          child: SlideToPlace(
            key: ValueKey('slide-${role?.name ?? seat}'),
            // Courtiers walk between places only in the Dynasty story; in
            // any other game everyone sits in their place from the start,
            // so the crown lands where they are.
            enabled: game.solo,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                // A courtier's quip floats over their column rather than
                // pushing their tasks down and back up again. The column
                // fills its width so its contents stay centred.
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  fit: StackFit.passthrough,
                  children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The token, name and tally are all one big target, so
                    // a tap anywhere on them reaches the courtier.
                    MouseRegion(cursor: seat == null ? MouseCursor.defer : SystemMouseCursors.click, child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: seat == null ? null : _seatTap(seat),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (seat != null)
                      _withReveal(seat, _digiToken(seat, width > 600 ? 48 : 38, tight: true),
                          size: width > 600 ? 48 : 38)
                    else
                      // At court but not at the table this round.
                      CharacterToken(
                        key: ValueKey('person-${role!.name}'),
                        entrance: entranceOf(role),
                        size: 38,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _roleToken(role, game.colorOf(role), 38),
                        ),
                      ),
                    Text(
                        role != null ? role.short : game.players[seat!].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70, shadows: _feltShadow)),
                    // Trick counts once the tricks begin (and not in the
                    // story, where the tasks keep count). Their room is
                    // kept from the start, so nothing shifts when they
                    // appear.
                    if (seat != null && !game.solo)
                      Opacity(
                        opacity: c.dealId == game.dealId &&
                                (_playing || c.tricks.isNotEmpty)
                            ? 1
                            : 0,
                        child: Text(
                            c.dealId == game.dealId
                                ? '${c.tricksWon(seat)} won · ${c.hands[seat].length} cards'
                                : '0 won · 0 cards',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white54)),
                      ),
                      ]),
                    )),
                    // A traitor's scheme, face up: a black card the court
                    // must stop.
                    if (seat != null &&
                        game.solo &&
                        !_storyActive &&
                        game.isAntagonist(seat) &&
                        game.schemeOf[seat] != null)
                      _schemeCard(seat, taskWidth, colWidth < 80 ? 11 : 12),
                    if (seat != null)
                      for (final t in game.tasks)
                        if (!_storyActive &&
                            t.assignedPlayerIndex == seat)
                          _miniTask(t, taskWidth,
                              fontSize: colWidth < 80
                                  ? 11
                                  : width > 600
                                      ? 13.5
                                      : 12),
                  ],
                ),
                if (seat != null && _quips[seat] != null)
                  Positioned(
                    top: (width > 600 ? 48 : 38) + 22,
                    left: 0,
                    right: 0,
                    // Never in the way of a tap on the courtier.
                    child: IgnorePointer(
                      child: Center(
                        child: SpeechBubble(_quips[seat]!,
                            key: ValueKey('quip-$seat-${_quips[seat]}'),
                            tailAbove: true),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        );
    // Only as tall as the bots' tasks need (so there's room for the tasks
    // being picked), growing smoothly as tasks arrive.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (role, seat) in entries) column(role, seat),
            for (final e in _walkingOff.entries)
              SizedBox(
                key: ValueKey('col-${e.key.name}'),
                width: colWidth,
                child: Column(children: [
                  CharacterToken(
                    key: ValueKey('leaving-${e.key.name}'),
                    exit: Exit.walk,
                    size: 38,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _roleToken(e.key, e.value, 38),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  /// [token] with the card [seat] has shown tucked beside it, so showing a
  /// card never takes room from the trick.
  Widget _withReveal(int seat, Widget token, {required double size}) {
    final r = _revealedView(seat, height: size);
    // Always the same shape, card or no card: otherwise showing a card
    // would rebuild the token from scratch, and it would arrive all over
    // again.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        token,
        // Level with the token (below its crown slot), as tall as it.
        if (r != null) Positioned(right: -(size / 1.3 + 8), top: 14, child: r),
      ],
    );
  }

  /// A card shown with the speech token, while it's still in hand.
  Widget? _revealedView(int seat, {double height = 40}) {
    final c = _cards;
    final card = c.revealed[seat];
    if (card == null || c.dealId != game.dealId || !c.hands[seat].contains(card)) {
      return null;
    }
    // High contrast: framed in the player's colour with dark lines, and
    // what was said about it on a dark tag.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniCard(card: card, width: height / 1.3, edge: game.players[seat].color),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF14100A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Palette.gold, width: 1),
          ),
          // One short word: high, low or only.
          child: Text(
              switch (c.revealHint[seat]) {
                'highest' => 'high',
                'lowest' => 'low',
                final h => h ?? '',
              },
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w800, color: Palette.gold)),
        ),
      ],
    );
  }

  /// The middle of the table: the tasks to take while picking (tap one),
  /// then the trick.
  final _middleTasksKey = GlobalKey(debugLabel: 'middle tasks');

  Widget _digiMiddle(double width) {
    if (_choosingKing) return const SizedBox.expand();
    final open = [for (final t in game.tasks) if (t.assignedPlayerIndex == null) t];
    if (open.isEmpty && _landing.isEmpty && _flights.isEmpty) {
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
      _openTaskRects = {
        for (final e in _openTaskKeys.entries)
          if (e.key.assignedPlayerIndex == null)
            if (_rectOn(e.value) case final r?) e.key: r,
      };
    });
    // Bigger on a big screen, where there's room to read them easily.
    final big = width > 600;
    final w = math.min(big ? 200.0 : 130.0, (width - 16) / 3);
    _openFontSize = big ? 16 : 13;
    // Open tasks, and any still flying to their owner. Once a taken task
    // has landed the rest close up, so the middle never runs out of room.
    // (Royal charges go straight to their house.)
    final slots = [
      for (final t in game.tasks)
        if (!game.isCharged(t) &&
            (t.assignedPlayerIndex == null ||
                _landing.contains(t) ||
                _flights.any((f) => f.task == t)))
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
              if (_openTaskKeys[t] case final key?)
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
            final taken = t.assignedPlayerIndex != null;
            // Who could take it: a task only one player may take is marked
            // in their colour, so the table knows it's theirs to choose.
            // Only what everyone can see: your own hand counts for you,
            // but nobody else's cards do.
            final able = [
              for (int s = 0; s < game.players.length; s++)
                if (s == _you
                    ? game.canTake(t, s)
                    : game.whyCantTake(t, s, publicOnly: true) == null)
                  s
            ];
            final only = !taken && able.length == 1 ? able.single : null;
            final chip = IgnorePointer(
              ignoring: taken,
              child: AnimatedOpacity(
                key: _openTaskKeys.putIfAbsent(t, GlobalKey.new),
                duration: Duration.zero,
                opacity: taken
                    ? 0
                    : _yourPick && !_mayTake(t) && only == null
                        ? 0.5
                        : 1,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _TaskChip(
                    task: t,
                    points: _points(t),
                    text: _cardText(t),
                    color: only == null
                        ? Palette.inkSoft
                        : game.players[only].color,
                    width: w,
                    fontSize: big ? 16 : 13,
                    focused: _kbRow == 1 && _kbTask == t,
                    // A tap reads it; press and hold to take it, so taking
                    // a task is always meant.
                    onTap: () => _showTaskDetail(t, Offset.zero),
                    onLongPress: () => _yourPick
                        ? _takeTask(t)
                        : _showTaskDetail(t, Offset.zero),
                  ),
                  if (only != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                          only == _you
                              ? 'Only you can take this'
                              : 'Only ${game.players[only].name} can take this',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: game.players[only].color)),
                    ),
                ]),
              ),
            );
            if (!measured) return Opacity(opacity: 0, child: chip);
            final from = _dealFrom[t] ?? Offset.zero;
            // Cards lean alternately left and right as they fly.
            final side = i.isEven ? -1.0 : 1.0;
            final startMs = pileMs + i * 170;
            final total = startMs + 820;
            return TweenAnimationBuilder<double>(
              key: ValueKey('deal-${game.dealId}-${t.description}'),
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: total),
              builder: (context, raw, child) {
                final ms = raw * total;
                const apart = 0.0;
                // Then each card is dealt: it arcs out to its place,
                // straightening and turning face up as it lands.
                final d = ms < startMs
                    ? 0.0
                    : Curves.easeOutBack.transform(
                        clampD((ms - startMs) / (total - startMs), 0, 1));
                final dc = clampD(d, 0, 1);
                final lift = math.sin(dc * math.pi) * 36;
                final pile = Offset(side * apart * w * 0.6, -i * 1.6 - apart * 10);
                return Transform.translate(
                  offset: from * (1 - d) + pile * (1 - dc) + Offset(0, -lift),
                  child: Transform.rotate(
                    angle: side * apart * 0.22 + side * 0.3 * math.sin(dc * math.pi),
                    child: Transform.scale(
                      scale: 0.86 + 0.14 * dc,
                      child: FlipIn(
                        t: clampD(dc * 1.5 - 0.3, 0, 1),
                        front: child!,
                        // The back is exactly the size of the front.
                        back: Stack(children: [
                          Opacity(opacity: 0, child: child),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF7A1F2C), Color(0xFF3E0C14)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Palette.gold, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 6,
                                      offset: Offset(0, 3)),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const CrownIcon(size: 26, color: Palette.gold),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              },
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
          spacing: 6,
          minHeight: box.maxHeight.isFinite ? box.maxHeight : 0,
          children: taskChips,
        ),
      ),
    );
  }

  bool _mayTake(Task t) => game.decree == Decree.kingsCommand
      ? true
      : game.canTake(t, _you);

  /// Your pick: take a task. Under King's Command you're the King handing
  /// tasks out, so choose who gets it.
  Future<void> _takeTask(Task t) async {
    if (game.decree != Decree.kingsCommand) {
      if (!game.canTake(t, _you)) {
        _showSnack(game.whyCantTake(t, _you)!, Palette.feltDeep);
        return;
      }
      _assignTask(t, _you);
      return;
    }
    final seats = [
      for (int s = 0; s < game.players.length; s++)
        if (game.canTake(t, s)) s
    ];
    final seat = await showDialog<int>(
      context: context,
      builder: (context) => CourtDialog(
        title: "King's Command: who takes it?",
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final s in seats)
            TextButton(
              onPressed: () => Navigator.pop(context, s),
              child: Text(game.players[s].name, style: const TextStyle(fontSize: 17)),
            ),
        ]),
      ),
    );
    if (seat != null && mounted && t.assignedPlayerIndex == null) {
      _assignTask(t, seat);
    }
  }

  /// Whether your tasks have been scrolled under your token.
  final _youScrolled = ValueNotifier(false);

  /// You, with your tasks beside you.
  Widget _digiYou(double width) {
    final mine = [
      for (final t in game.tasks)
        if (t.assignedPlayerIndex == _you) t
    ];
    final c = _cards;
    const tokenW = 58.0;
    // A place kept for the card you show, as tall as your token.
    const revealW = 40 / 1.3 + 12;
    const leadW = tokenW + revealW;
    final you = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: tokenW,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _digiToken(_you, 40),
              // Room kept from the start, so nothing shifts when it appears.
              Opacity(
                opacity:
                    c.dealId == game.dealId && (_playing || c.tricks.isNotEmpty)
                        ? 1
                        : 0,
                child: Text(
                    c.dealId == game.dealId
                        ? '${c.tricksWon(_you)} trick${c.tricksWon(_you) == 1 ? '' : 's'}'
                        : '0 tricks',
                    style: const TextStyle(fontSize: 11, color: Colors.white54)),
              ),
            ],
          ),
        ),
        SizedBox(
          width: revealW,
          child: Center(child: _revealedView(_you, height: 40)),
        ),
      ],
    );
    final Widget tasks = _storyActive
        ? const SizedBox.shrink()
        : mine.isEmpty
            ? const SizedBox.shrink()
            // Your tasks scroll sideways when they don't fit, slipping under
            // your token and shown card rather than stopping short of them.
            : NotificationListener<ScrollUpdateNotification>(
                onNotification: (n) {
                  final scrolled = n.metrics.pixels > 2;
                  if (scrolled != _youScrolled.value) _youScrolled.value = scrolled;
                  return false;
                },
                // Shown on past the row's end, through the margin to the
                // brass edge.
                child: ClipRect(
                clipper: const _ReachRight(10),
                child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.only(left: leadW),
                child: Row(children: [
                  for (final t in mine)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _miniTask(
                          t, math.min(width > 600 ? 190.0 : 140.0, width / 3),
                          fontSize: width > 600 ? 15 : 13),
                    ),
                ]),
              ),
              ),
              );
    // The whole width, so you sit at its left end.
    return SizedBox(
      width: width,
      child: Stack(
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.none,
      children: [
        // Keeps the row at least as tall as you.
        const SizedBox(width: leadW, height: 80),
        tasks,
        // You, at your full size, over the start of the row.
        Positioned(
          left: 0,
          // Nothing behind you: tasks scrolled under your token and shown
          // card stay in sight, with your glow over them.
          child: you,
        ),
      ],
      ),
    );
  }

  /// How wide trick cards are for a table [width] across with [n] players.
  static double _trickCardWidth(double width, int n) =>
      clampD((width - 8 * n) / n, 34, width > 600 ? 100 : 64);

  /// The trick in the middle of the table: each card glides in from
  /// whoever played it, and once won the trick sweeps off to the winner.
  List<Widget> _trickCards(Size area) {
    if (_cards.dealId != game.dealId) return [];
    final c = _cards;
    final trick = _lastTrick;
    final seats = trick?.seats ?? c.currentSeats;
    final cards = trick?.cards ?? c.current;
    if (cards.isEmpty) return [];
    final number = trick != null ? c.tricks.length - 1 : c.tricks.length;
    final n = c.players;
    // The same size every trick: set by the table's width, shrinking only
    // if the middle is truly short of room.
    final cardW = clampD(math.min(_trickCardWidth(area.width, n),
        (area.height - 4) / 1.42), 34, 100);
    final cardH = PlayingCardView.heightFor(cardW);
    // Where the middle sits on the table, to work out where cards come
    // from; if it isn't known yet the cards simply fade in.
    final middle = _rectOn(_middleKey);
    final hand = _rectOn(_handKey);
    Offset? origin(int seat, PlayingCard card) {
      if (middle == null) return null;
      final Offset? p = seat == _you
          ? _launchFrom[card.id] ?? hand?.topCenter
          : _rectOn(_seatKey(seat))?.center;
      return p == null ? null : p - middle.topLeft;
    }

    Offset topLeft(Offset centre) => centre - Offset(cardW / 2, cardH / 2);
    return [
      for (int i = 0; i < cards.length; i++)
        () {
          final target = Offset(
              area.width / 2 + (i - (n - 1) / 2) * (cardW + 8),
              area.height / 2);
          final seat = seats[i];
          final view = PlayingCardView(
            card: cards[i],
            width: cardW,
            // Edged in the colour of whoever played it.
            edge: game.players[seat].color,
            glow: trick != null && trick.winner == seat,
          );
          if (trick != null && _collecting) {
            final to = origin(trick.winner, cards[i]) ?? target;
            return TweenAnimationBuilder<double>(
              key: ValueKey('collect-$number-${cards[i].id}'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeInCubic,
              builder: (context, t, child) {
                final p = topLeft(Offset.lerp(target, to, t)!);
                return Positioned(
                  left: p.dx,
                  top: p.dy,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: clampD(1 - t, 0, 1),
                      child: Transform.scale(scale: 1 - 0.5 * t, child: child),
                    ),
                  ),
                );
              },
              child: view,
            );
          }
          final from = origin(seat, cards[i]);
          return TweenAnimationBuilder<double>(
            key: ValueKey('play-$number-${cards[i].id}'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              final p = topLeft(Offset.lerp(from ?? target, target, t)!);
              return Positioned(
                left: p.dx,
                top: p.dy,
                child: IgnorePointer(
                  child: Opacity(
                      opacity: from == null ? clampD(t * 2, 0, 1) : 1,
                      child: child),
                ),
              );
            },
            child: view,
          );
        }(),
    ];
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
      _cards.dealId == game.dealId &&
      _cards.hands.length > _you &&
      _cards.hands[_you].isNotEmpty &&
      game.spoke.length > _you &&
      !game.spoke[_you] &&
      game.canSpeak(_you);

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
    if (_cards.current.isNotEmpty || _lastTrick != null) {
      setState(() => _wantsToSpeak = !_wantsToSpeak);
      return;
    }
    if (!_cards.hands[_you].any((c) => _cards.revealFor(_you, c) != null)) {
      _showSnack(
          'Nothing you may show: only your highest, lowest or only card of a suit',
          Palette.feltDeep);
      return;
    }
    setState(() => _revealing = true);
  }


  /// Shows [card] for [seat]: it stays in their hand, face up for all.
  /// Shows a card: sends the move, which shows it when it comes back.
  void _reveal(int seat, PlayingCard card) {
    if (_cards.revealFor(seat, card) == null) return;
    _link.send(ShowCard(seat, card));
  }

  void _revealNow(int seat, PlayingCard card) {
    final hint = _cards.revealFor(seat, card);
    if (hint == null) return;
    setState(() {
      _cards.revealed[seat] = card;
      _cards.revealHint[seat] = hint;
      if (!game.spoke[seat]) game.toggleSpoke(seat);
      if (seat == _you) _revealing = false;
    });
  }

  /// You ask a courtier to show a card. They show one a task needs if they
  /// can, else one that says the most (the only card of its suit, or the
  /// highest of their longest suit).
  void _askToSpeak(int seat) {
    final c = _cards;
    final name = game.players[seat].name;
    if (c.dealId != game.dealId || game.outcome != RoundOutcome.inProgress) return;
    String? no;
    if (game.spoke[seat]) {
      no = '$name has already shown a card this round';
    } else if (!game.canSpeak(seat)) {
      no = game.whyCantSpeak() ?? 'No cards may be shown now';
    } else if (c.current.isNotEmpty) {
      no = '$name can show a card once this trick is over';
    }
    if (no != null) {
      _showSnack(no, Palette.feltDeep);
      return;
    }
    final showable = [for (final card in c.hands[seat]) if (c.revealFor(seat, card) != null) card];
    if (showable.isEmpty) {
      _showSnack('$name has no card they may show', Palette.feltDeep);
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

  /// A bot shows a card someone's task needs, if it may, once a round.
  bool _botReveals(int seat) {
    if (game.spoke[seat] || !game.canSpeak(seat) || _cards.current.isNotEmpty) {
      return false;
    }
    for (final card in _cards.hands[seat]) {
      if (_cards.revealFor(seat, card) == null) continue;
      final needed = game.tasks.any((t) =>
          t.status == TaskStatus.pending &&
          t.assignedPlayerIndex != null &&
          t.assignedPlayerIndex != seat &&
          neededCards(t.description).contains(card));
      if (needed) {
        _reveal(seat, card);
        return true;
      }
    }
    return false;
  }

  Courtier? get _yourCourtier =>
      game.hasRoles && _you < game.courtiers.length ? game.courtiers[_you] : null;

  /// Whether your courtier's power can be used right now, on screen.
  bool get _canUsePower {
    if (powersComingSoon) return false;
    final me = _yourCourtier;
    if (me == null || !_playing || game.powerUsed[_you]) return false;
    final c = _cards;
    return switch (me) {
      // Before the first trick.
      Courtier.duke || Courtier.king => c.tricks.isEmpty &&
          c.current.isEmpty &&
          game.tasks.any((t) => t.assignedPlayerIndex == _you),
      // Waiting for a failure, which asks when it comes.
      Courtier.bishop => false,
      // At the start of a trick someone else would lead.
      Courtier.general =>
        _lastTrick == null && c.current.isEmpty && c.leader != _you,
      Courtier.spymaster => true,
      Courtier.merchant => c.hands[_you].any((x) => !x.isCourt),
      Courtier.jester => game.tasks
              .where((t) => t.status == TaskStatus.pending)
              .map((t) => t.assignedPlayerIndex)
              .toSet()
              .length >=
          2,
    };
  }

  /// Uses your courtier's power, asking whatever it needs to know.
  Future<void> _usePower() async {
    final me = _yourCourtier;
    if (me == null || !_canUsePower) return;
    final names = [for (final p in game.players) p.name];
    Future<T?> choose<T>(String title, List<(T, String)> options) =>
        showDialog<T>(
          context: context,
          builder: (context) => CourtDialog(
            title: title,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final (value, label) in options)
                TextButton(
                  onPressed: () => Navigator.pop(context, value),
                  child: SuitText(label,
                      keywords: false,
                      style: const TextStyle(fontSize: 16, color: Colors.white)),
                ),
            ]),
          ),
        );
    void used() {
      _haptic(HapticFeedback.mediumImpact);
      setState(() => game.powerUsed[_you] = true);
    }

    switch (me) {
      case Courtier.duke:
      case Courtier.king:
        final task = await choose('Command: give which task?', [
          for (final t in game.tasks)
            if (t.assignedPlayerIndex == _you) (t, t.cardText(playerCount)),
        ]);
        if (task == null || !mounted) return;
        final seat = await choose('Give it to whom?', [
          for (int s = 0; s < game.players.length; s++)
            if (s != _you && game.canTake(task, s)) (s, names[s]),
        ]);
        if (seat == null || !mounted) return;
        setState(() => task.assignedPlayerIndex = seat);
        used();
      case Courtier.bishop:
        return;
      case Courtier.general:
        setState(() => _cards.leader = _you);
        used();
        _showSnack('Vanguard: you lead this trick', Palette.feltDeep);
      case Courtier.spymaster:
        final seat = await choose('Whisper: ask whom?', [
          for (int s = 0; s < game.players.length; s++)
            if (s != _you) (s, names[s]),
        ]);
        if (seat == null || !mounted) return;
        final suit = await choose('About which suit?', [
          for (final s in [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs])
            (s, s.symbol),
        ]);
        if (suit == null || !mounted) return;
        used();
        final has = _cards.hands[seat].any((c) => c.suit == suit);
        await showDialog<void>(
          context: context,
          builder: (context) => CourtDialog(
            title: 'Whisper',
            child: SuitText(
                '${names[seat]} ${has ? 'holds' : 'holds no'} ${suit.symbol} cards.',
                style: const TextStyle(fontSize: 18, color: Colors.white)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
            ],
          ),
        );
      case Courtier.merchant:
        final n = game.players.length;
        final neighbours = {(_you + 1) % n, (_you - 1 + n) % n}
            .where((s) => _cards.hands[s].any((c) => !c.isCourt))
            .toList();
        if (neighbours.isEmpty) return;
        final mine = await choose('Trade: which card do you give?', [
          for (final c in _cards.hands[_you])
            if (!c.isCourt) (c, c.label),
        ]);
        if (mine == null || !mounted) return;
        final seat = neighbours.length == 1
            ? neighbours.first
            : await choose('Trade with whom?', [
                for (final s in neighbours) (s, names[s]),
              ]);
        if (seat == null || !mounted) return;
        // They hand back a card of their choosing: one they won't miss.
        final theirs = (List.of(_cards.hands[seat])..shuffle(_rand))
            .firstWhere((c) => !c.isCourt && !_marksFor(c).isNotEmpty,
                orElse: () => _cards.hands[seat].firstWhere((c) => !c.isCourt));
        setState(() {
          _cards.hands[_you]
            ..remove(mine)
            ..add(theirs)
            ..sort();
          _cards.hands[seat]
            ..remove(theirs)
            ..add(mine)
            ..sort();
        });
        used();
        _showSnack('Trade: you gave the ${mine.label} and got the ${theirs.label}',
            Palette.feltDeep);
      case Courtier.jester:
        final open = [
          for (final t in game.tasks)
            if (t.status == TaskStatus.pending && t.assignedPlayerIndex != null) t
        ];
        final a = await choose('Jest: swap which task?', [
          for (final t in open)
            (t, '${names[t.assignedPlayerIndex!]}: ${t.cardText(playerCount)}'),
        ]);
        if (a == null || !mounted) return;
        final b = await choose('With which?', [
          for (final t in open)
            if (t.assignedPlayerIndex != a.assignedPlayerIndex)
              (t, '${names[t.assignedPlayerIndex!]}: ${t.cardText(playerCount)}'),
        ]);
        if (b == null || !mounted) return;
        setState(() {
          final x = a.assignedPlayerIndex;
          a.assignedPlayerIndex = b.assignedPlayerIndex;
          b.assignedPlayerIndex = x;
        });
        used();
    }
  }

  /// Absolution: before a task fails, the Bishop (you) may set it aside.
  /// A penance for Absolution: a task from the deck, worth at least as
  /// much as [failed], that you can still do with the cards left.
  Task? _penanceFor(Task failed) {
    final v = _roundView;
    final c = _cards;
    // At least two tricks to go, or there's no penance worth the name.
    if (c.totalTricks - c.tricks.length < 2) return null;
    final need = _points(failed);
    final inUse = game.tasks.map((t) => t.description).toSet();
    final options = [
      for (final t in GameState.taskPool)
        if (!inUse.contains(t.description) &&
            !needsX(t.description) &&
            _points(t) >= need &&
            !game.tasks.any((o) =>
                o != failed && clash(o.description, t.description)) &&
            game.whyCantTake(t, _you) == null &&
            playableWith(t.description, c.hands, c.inPlay) &&
            taskRules[t.description]!(v, _you, null) == Verdict.pending)
          t
    ];
    if (options.isEmpty) return null;
    // The cheapest fitting penance, picked at random among equals.
    final least = options.map(_points).reduce(math.min);
    final cheapest = options.where((t) => _points(t) == least).toList();
    return cheapest[_rand.nextInt(cheapest.length)].freshCopy();
  }

  /// The Bishop's Absolution: a failed task is set aside, but the Bishop
  /// must take a penance in its place.
  Future<bool> _offerAbsolution(Task t) async {
    if (powersComingSoon ||
        _yourCourtier != Courtier.bishop ||
        game.powerUsed[_you]) {
      return false;
    }
    final penance = _penanceFor(t);
    if (penance == null) return false;
    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CourtDialog(
        title: 'Absolution?',
        child: SuitText(
            '${t.assignedPlayerIndex == _you && _digital ? 'Your' : '${game.players[t.assignedPlayerIndex!].name}’s'} task is about to fail: '
            '${t.cardText(playerCount)}\n\nAbsolve it, and you must take a penance in its place: '
            '${penance.cardText(playerCount)}',
            style: const TextStyle(fontSize: 16, height: 1.35, color: Colors.white)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Let it fail')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Take the penance')),
        ],
      ),
    );
    if (yes != true || !mounted) return false;
    setState(() {
      final i = game.tasks.indexOf(t);
      game.tasks[i] = penance..assignedPlayerIndex = _you;
      game.powerUsed[_you] = true;
    });
    return true;
  }

  /// Marks a task done, for tests.
  @visibleForTesting
  void debugComplete(Task t) => _setTaskStatus(t, TaskStatus.completed);

  /// Plays your part, for tests: picks, announces or plays the first
  /// thing allowed. Returns false when there's nothing for you to do.
  @visibleForTesting
  bool debugYourMove() {
    if (_contest != null) {
      _contestKey.currentState?.debugYourMove();
      return true;
    }
    if (_speakPromptDue) {
      _startChoosing();
      return true;
    }
    if (_yourPick) {
      final t = game.tasks.firstWhere(
          (t) => t.assignedPlayerIndex == null && game.canTake(t, _you),
          orElse: () => game.tasks.firstWhere((t) => t.assignedPlayerIndex == null));
      _assignTask(t, game.canTake(t, _you) ? _you : (_you + 1) % game.players.length);
      return true;
    }
    if (_yourPlay) {
      // The tutorial follows its own advice.
      final legal = _cards.legalFor(_you);
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
    if (chapter != null) {
      target = chronicle[chapter].points;
      _progress.startAttempt(chapter);
      _saveSettings();
    }
    setState(() {
      playerCount = count;
      targetPoints = target;
      game = GameState()
        ..mode = mode
        ..lesson = lesson
        ..chapter = chapter
        ..surprise = surprise
        ..roles = roles
        ..bestStreak = _bestStreak
        ..players = [
          for (int i = 0; i < count; i++)
            Player(names[i], color: Palette.players[i % Palette.players.length])
        ]
        ..seatCourtiers()
        ..addTasksUntilTarget(count, target);
      // The tutorial's courtiers are always the same: you, the Duke and
      // the Bishop, each with their house's token.
      if (mode == GameMode.tutorial) {
        game.courtiers = List.of(tutorialHouses);
        game.people = [for (final c in game.courtiers) c.title];
      }
      if (digital) {
        // You sit at the bottom; bots take the other seats.
        game.cards = MatchState(players: count, target: target);
        for (int i = 0; i < count; i++) {
          game.players[i].name = i == _you
              ? 'You'
              : game.isDynasty
                  ? game.personAt(i)
                  : mode == GameMode.tutorial
                      ? tutorialCourtiers[i]
                      : game.hasRoles
                          ? game.courtiers[i].title
                          : 'Bot ${i + 1}';
        }
      }
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
    final r = closing
        ? await showTutorialPages(context,
            pages: outroPages,
            heading: 'Part ${lessons.length + 1} of ${lessons.length + 1}',
            finishLabel: 'Finish')
        : await _lessonPages(i);
    if (!mounted) return;
    // Leaving, or done: out of the tutorial (if a lesson was under way).
    if (r == 'quit' || (closing && r == 'go')) {
      if (_inGame && game.isTutorial) _finishTutorial();
      return;
    }
    if (r != 'go') return;
    if (_inGame && game.isTutorial) {
      setState(() => game.lesson = i);
      _shuffleTasks();
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
        roles: true, digital: true, lesson: i);
  }

  /// On to the next section's reading, then its lesson.
  Future<void> _nextLesson() => _openSection(game.lesson + 1);

  /// Leaves the tutorial for the welcome table, and offers a real game.
  Future<void> _finishTutorial() async {
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
    final play = await showDialog<bool>(
      context: context,
      builder: (context) => CourtDialog(
        title: 'You’re ready',
        ornament: Ornament.medium,
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Play a game')),
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now')),
        ],
        child: const SuitText(
            'Set up a game of your own now? How to Play in the menu has every rule whenever you need it.',
            textAlign: TextAlign.center,
            style: DialogStyle.body),
      ),
    );
    if (play == true && mounted) _showSetupDialog();
  }

  /// The card the tutorial suggests on this trick, if it's your turn.
  PlayingCard? get _tutorialHint => game.isTutorial &&
          _digital &&
          _cards.dealId == game.dealId &&
          game.lesson < lessons.length
      ? lessons[game.lesson].hint(_cards.tricks.length)
      : null;

  /// What the tutorial's coach says right now.
  String? get _coachLine {
    if (!game.isTutorial || !_inGame || game.lesson >= lessons.length) {
      return null;
    }
    final l = lessons[game.lesson];
    if (game.outcome != RoundOutcome.inProgress) return null;
    if (_choosingKing || _crowning != null || _dealtFor != game.dealId) {
      return l.intro;
    }
    if (game.pickTurn == _you) return l.pick;
    if (game.pickTurn != null) {
      return '${game.players[game.pickTurn!].name} is choosing a task.';
    }
    final c = _cards;
    if (_lastTrick != null) {
      final done = c.tricks.length - 1;
      return l.afterTrick[done] ??
          (_lastTrick!.winner == _you
              ? 'You won the trick.'
              : '${game.players[_lastTrick!.winner].name} won the trick, and leads the next one.');
    }
    if (_yourPlay) {
      final led = c.led;
      return l.yourTurn[c.tricks.length] ??
          (led == null
              ? 'Your lead: play any card.'
              : 'Your turn: follow ${led.isCourt ? 'with a Court Card' : led.suit.symbol} if you can.');
    }
    return l.watch[c.tricks.length] ?? 'The courtiers are playing.';
  }

  /// The coach: a parchment note between the table and your hand.
  Widget _buildCoach() {
    final line = _coachLine;
    final l = lessons[math.min(game.lesson, lessons.length - 1)];
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: line == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 12),
              // On the felt, edged in gold, like the rules.
              decoration: BoxDecoration(
                color: const Color(0xF20A3622),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Palette.gold.withValues(alpha: 0.7), width: 1.4),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black45, blurRadius: 10, offset: Offset(0, 3))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const CrownIcon(size: 14, color: Palette.gold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'Lesson ${game.lesson + 1} of ${lessons.length} · ${l.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: displayFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Palette.gold,
                              shadows: _feltShadow)),
                    ),
                    // Back to this lesson's reading, or on to the next.
                    TextButton(
                      onPressed: () => _openSection(game.lesson),
                      style: TextButton.styleFrom(
                          foregroundColor: Palette.gold,
                          overlayColor: Colors.transparent,
                          visualDensity: VisualDensity.compact),
                      child: const Text('Back'),
                    ),
                    TextButton(
                      onPressed: () => _openSection(game.lesson + 1),
                      style: TextButton.styleFrom(
                          foregroundColor: Palette.gold,
                          overlayColor: Colors.transparent,
                          visualDensity: VisualDensity.compact),
                      child: const Text('Skip'),
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        key: ValueKey(line),
                        width: double.infinity,
                        // Room for three lines, so the hand below doesn't
                        // bob up and down as the advice changes.
                        constraints: const BoxConstraints(minHeight: 64),
                        alignment: Alignment.topLeft,
                        child: SuitText(line,
                            style: const TextStyle(
                                fontSize: 15.5,
                                height: 1.35,
                                color: Colors.white,
                                shadows: _feltShadow)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// The end of a lesson: what it taught, and on to the next.
  Widget _buildLessonCard(bool won, Color fg) {
    final l = lessons[math.min(game.lesson, lessons.length - 1)];
    final last = game.lesson >= lessons.length - 1;
    return OrnateCard(
      ornament: Ornament.medium,
      won: won,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.shrink(),
          const SizedBox(height: 6),
          Text('Lesson ${game.lesson + 1}: ${l.title}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: won ? Palette.ink : Palette.gold)),
          Text(
              won
                  ? (last ? 'Tutorial complete' : 'Lesson complete')
                  : 'Not quite',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  color: fg)),
          const SizedBox(height: 6),
          SuitText(won ? l.won : l.lost,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.35, color: fg)),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: _retryRound,
                style: OutlinedButton.styleFrom(
                    foregroundColor: fg,
                    side: BorderSide(color: won ? Palette.ink : Colors.white54)),
                child: Text(won ? 'Replay lesson' : 'Try again'),
              ),
              FilledButton(
                onPressed: _nextLesson,
                style: won
                    ? FilledButton.styleFrom(
                        backgroundColor: Palette.ink,
                        foregroundColor: Palette.gold)
                    : null,
                child: Text(last
                    ? 'Finish'
                    : won
                        ? 'Next lesson'
                        : 'Skip to the next lesson'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _resetTable() {
    _pos.clear();
    _tilt.clear();
    _order = [];
    _dealtFor = -1;
    _deal.reset();
    _landing.clear();
    _whyFailed.clear();
  }

  void _shuffleTasks() {
    // In a Dynasty, a finished round moves on through the dilemma instead.
    if (game.isDynasty && game.outcome != RoundOutcome.inProgress) return;
    final midRound = _inGame && game.outcome == RoundOutcome.inProgress &&
        game.kingIndex != null;
    setState(() {
      game.shuffleTasks(playerCount, targetPoints);
      if (midRound) _decreeReadFor = game.dealId; // already read this round
      _resetTable();
    });
  }

  void _retryRound() {
    setState(() {
      game.retryRound();
      _resetTable();
    });
  }

  /// A haptic tap where the device supports it.
  void _haptic(Future<void> Function() feedback) {
    try {
      feedback().catchError((Object _) {});
    } catch (_) {}
  }

  void _toggleSpoke(int seat) {
    if (!game.canSpeak(seat) && !game.spoke[seat]) {
      _showSnack(game.whyCantSpeak() ?? 'No cards may be shown now', Palette.feltDeep);
      return;
    }
    _haptic(HapticFeedback.selectionClick);
    setState(() => game.toggleSpoke(seat));
  }

  /// Crowns the King with a flourish: the crown flies from the deck to
  /// their seat and lands with a burst of gold, then the tasks are dealt.
  void _crownKing(int index) {
    if (_crowning != null) return;
    if (game.isAntagonist(index)) {
      _showSnack('A traitor to the crown cannot be crowned', Palette.lost);
      return;
    }
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
        game.setKing(index);
        _crowning = null;
        _crownFromCentre = false;
      });
    });
  }

  /// Lays the round's cards out from the deck in the middle of the table.
  void _dealCards() {
    final geo = _geo;
    final targets = geo.dealPositions(game.tasks);
    _cardWidth = geo.cardWidth;
    final rand = math.Random(game.dealId);
    _order = List.of(game.tasks);
    for (int i = 0; i < game.tasks.length; i++) {
      final t = game.tasks[i];
      _pos[t] = _toFrac(targets[i]);
      _tilt[t] = (rand.nextDouble() - 0.5) * 0.08; // a few degrees
    }
    _dealtFor = game.dealId;
    // A royal charge is dealt straight to its house.
    if (game.tasks.any((t) => t.assignedPlayerIndex != null)) _layoutOwned();
    _deal.forward(from: 0);
  }

  /// Re-stacks every player's cards after one is added or removed.
  void _layoutOwned() {
    final geo = _geo;
    geo.layoutOwned(_order).forEach((t, p) {
      _pos[t] = _toFrac(geo.clampToTable(p, geo.cardSize(t)));
    });
  }

  void _onDragStart(Task t) {
    _ui(() {
      _dragging = t;
      _order
        ..remove(t)
        ..add(t);
    });
  }

  /// Ticks as a task card is dragged; only that card listens (see
  /// [_buildCards]). The page rebuilds only when the seat under it changes.
  final _taskDragTick = ValueNotifier(0);
  final _stillTick = ValueNotifier(0);

  void _onDragUpdate(Task t, Offset delta) {
    final geo = _geo;
    final p = geo.clampToTable(_toPx(_pos[t]!) + delta, geo.cardSize(t));
    _pos[t] = _toFrac(p);
    final seat = geo.seatAt(p);
    final hover = seat != null && game.canTake(t, seat) ? seat : null;
    if (hover != _hoverSeat) {
      _ui(() => _hoverSeat = hover);
    } else {
      _taskDragTick.value++;
    }
  }

  void _onDragEnd(Task t) {
    if (_digital) {
      final p = _toPx(_pos[t]!);
      final seat = _geo.seatAt(p);
      final kingsCommand = game.decree == Decree.kingsCommand;
      final allowed = _yourPick &&
          t.assignedPlayerIndex == null &&
          seat != null &&
          (seat == _you || kingsCommand) &&
          game.canTake(t, seat);
      if (!allowed) {
        setState(() {
          _dragging = null;
          _hoverSeat = null;
          _layoutOwned();
        });
        if (seat != null) {
          _showSnack(
              !_yourPick
                  ? 'Wait for your turn to pick'
                  : t.assignedPlayerIndex != null
                      ? 'Tasks stay with whoever took them'
                      : !game.canTake(t, seat)
                          ? game.whyCantTake(t, seat)!
                          : 'Take tasks onto your own seat',
              Palette.feltDeep);
        }
        return;
      }
      setState(() {
        _dragging = null;
        _hoverSeat = null;
      });
      _assignTask(t, seat);
      return;
    }
    final charged = game.chargeSeat;
    if (game.isCharged(t) && charged != null) {
      setState(() {
        _dragging = null;
        _hoverSeat = null;
        _layoutOwned();
      });
      _showSnack(
          'A royal charge: this task stays with ${game.courtiers[charged].title}',
          Palette.feltDeep);
      return;
    }
    final p = _toPx(_pos[t]!);
    final seat = _dropSeat(p);
    final previous = t.assignedPlayerIndex;
    setState(() {
      _dragging = null;
      _hoverSeat = null;
      var startPlay = false;
      if (seat != null && game.canTake(t, seat)) {
        if (t.assignedPlayerIndex != seat) _haptic(HapticFeedback.selectionClick);
        startPlay = game.assign(t, seat);
      } else {
        game.assign(t, null);
        if (seat != null) {
          // Dropped on the King, who can't take it: leave it just inside.
          _pos[t] = _toFrac(_geo.clampToTable(
              Offset.lerp(_geo.seatCenter(seat), _geo.center, 0.45)!));
        }
      }
      if (t.assignedPlayerIndex != null || previous != null) _layoutOwned();
      if (startPlay) _play.forward(from: 0);
    });
    _save();
    if (seat != null && !game.canTake(t, seat)) {
      _haptic(HapticFeedback.heavyImpact);
      _showSnack(game.whyCantTake(t, seat)!, Palette.lost);
    }
  }

  /// Solo Dynasty: what each courtier is calling out mid-hand.
  final Map<int, String> _quips = {};

  /// A courtier at [seat] calls out, for a moment.
  void _quip(int seat, String text) {
    if (text.isEmpty) return;
    _quips[seat] = text;
    _trickTimers.add(Timer(const Duration(milliseconds: 2800), () {
      if (mounted && _quips[seat] == text) setState(() => _quips.remove(seat));
    }));
  }

  void _setTaskStatus(Task task, TaskStatus status) {
    setState(() {
      final previous = task.status;
      // Choosing the active status again resets the task.
      task.status = task.status == status ? TaskStatus.pending : status;
      final owner = task.assignedPlayerIndex;
      if (game.solo && owner != null && owner != _you && owner < game.courtiers.length) {
        final role = game.courtiers[owner];
        if (task.isCompleted) _quip(owner, taskDone[role]!);
        if (task.isFailed) _quip(owner, taskFailed[role]!);
      }
      if (task.isFailed) {
        _haptic(HapticFeedback.vibrate);
      } else if (task.isCompleted) {
        _haptic(HapticFeedback.mediumImpact);
      }
      _lastMark = (task, previous);
      if (game.recordOutcomeIfFinished()) {
        final won = game.outcome == RoundOutcome.won;
        if (won) {
          Sfx.win();
        } else {
          Sfx.lose();
        }
        if (game.mode == GameMode.chronicle && game.chapter != null && won) {
          _crownsBefore = _progress.crowns[game.chapter!];
          _crownsEarned = _progress.recordWin(game.chapter!);
          _saveSettings();
        }
        _nextTarget = game.campaign && game.outcome == RoundOutcome.won
            ? math.min(maxTarget, targetPoints + 1)
            : targetPoints;
        if (game.bestStreak > _bestStreak) _bestStreak = game.bestStreak;
        _step = _DynastyStep.result;
        // The last tasks turn over first, then the result comes up.
        _outcome.value = 0;
        _outcomeHold.duration = Duration(milliseconds: won ? 800 : 450);
        _outcomeHold.forward(from: 0).whenComplete(() {
          if (!mounted) return;
          setState(() {});
          _outcome.forward(from: 0);
        });
      }
    });
  }

  /// A short message shown in the hand's status line for a moment (on
  /// screen; a pop-up bar there would cover your cards).
  String? _toast;
  Timer? _toastTimer;

  void _showSnack(String text, Color color) {
    if (_digital && _inGame && !_storyActive) {
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

  /// Tapping a seat with roles: the courtier's house, their power (mark it
  /// used) and their card reveal (mark it used), facing the player.
  Future<void> _showCourtier(int seat) async {
    if (seat >= game.courtiers.length) return;
    final courtier = game.courtiers[seat];
    final player = game.players[seat];
    final isKing = game.kingIndex == seat;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void update(VoidCallback change) {
            setState(change);
            setDialogState(() {});
          }

          final used = game.powerUsed[seat];
          final spoke = game.spoke[seat];
          final canSpeak = game.canSpeak(seat) || spoke;
          const label = TextStyle(
              fontFamily: displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Palette.ink);
          return RotatedBox(
            quarterTurns: _geo.edge(seat),
            child: Dialog(
              backgroundColor: DialogStyle.paper,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              // Edged in the player's colour, like their tasks.
              shape: HighVisBorder(game.isAntagonist(seat) ? Palette.lost : player.color),
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HouseBanner(
                        courtier: courtier,
                        color: player.color,
                        name: isKing
                            ? game.solo
                                ? 'King ${game.reignName}'
                                : '${player.name}, the King'
                            : player.name,
                        antagonist: game.isAntagonist(seat),
                        king: isKing,
                      ),
                      // A gilt band between the banner and the card.
                      Container(
                        height: 5,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Palette.goldDeep,
                            Palette.goldLight,
                            Palette.gold,
                            Palette.goldDeep,
                          ]),
                          border: Border(
                              bottom: BorderSide(color: outlineColour, width: 1)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(courtier.story,
                                style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                    color: Palette.inkSoft)),
                            if (game.chargeSeat == seat &&
                                _chargeLine != null) ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                const Icon(Icons.workspace_premium,
                                    color: Palette.goldDeep),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(_chargeLine!,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Palette.ink)),
                                ),
                              ]),
                            ],
                            if (game.isDynasty && isKing && game.reign > 0) ...[
                              const SizedBox(height: 10),
                              Text(
                                  'If history ended today: ${player.name} ${game.epithet}.',
                                  style: const TextStyle(
                                      fontSize: 15, color: Palette.ink)),
                            ],
                            if (game.isDynasty && !isKing) ...[
                              const SizedBox(height: 12),
                              Row(children: [
                                LoyaltyCandles(loyalty: game.loyalty[seat]),
                                const SizedBox(width: 10),
                                Text(loyaltyWord(game.loyalty[seat]),
                                    style: label.copyWith(
                                        color: game.isAntagonist(seat)
                                            ? Palette.lost
                                            : Palette.ink)),
                              ]),
                            ],
                            if (game.isAntagonist(seat) &&
                                game.schemeOf[seat] != null) ...[
                              const SizedBox(height: 8),
                              SuitText(
                                  'Scheme: ${schemes[game.schemeOf[seat]!]}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                      color: Palette.lost)),
                            ],
                            if (!powersComingSoon) ...[
                            const Divider(height: 26),
                            Row(children: [
                              const Icon(Icons.bolt_rounded,
                                  color: Palette.goldDeep),
                              const SizedBox(width: 4),
                              Expanded(
                                  child: Text('Power: ${courtier.power}',
                                      style: label.copyWith(
                                          color: Palette.goldDeep))),
                            ]),
                            const SizedBox(height: 4),
                            SuitText(courtier.powerRule,
                                style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                    color: Palette.ink)),
                            ],
                            if (_digital && !_choosingKing) ...[
                              const SizedBox(height: 8),
                              if (seat == _you)
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  if (!powersComingSoon)
                                  FilledButton.icon(
                                    onPressed: _canUsePower
                                        ? () {
                                            Navigator.pop(context);
                                            _usePower();
                                          }
                                        : null,
                                    icon: const Icon(Icons.bolt_rounded),
                                    label: Text(used
                                        ? 'Power used'
                                        : courtier == Courtier.bishop
                                            ? 'Offered if a task fails'
                                            : 'Use power'),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Palette.ink,
                                        foregroundColor: Palette.gold),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _mayAskToSpeak
                                        ? () {
                                            Navigator.pop(context);
                                            _speak();
                                          }
                                        : null,
                                    icon: const Icon(Icons.record_voice_over),
                                    label: Text(spoke ? 'Card shown' : 'Show a card'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Palette.ink,
                                        disabledForegroundColor: Palette.inkSoft,
                                        side: const BorderSide(color: Palette.ink)),
                                  ),
                                ])
                              else
                                Text(
                                    '${powersComingSoon ? '' : '${used ? 'Power used' : 'Power not used yet'} this round. '}'
                                    '${spoke ? 'Has shown a card.' : 'Hasn\u2019t shown a card.'}',
                                    style: const TextStyle(
                                        fontSize: 15, color: Palette.inkSoft)),
                            ],
                            if (!_choosingKing && !_digital) ...[
                              if (!powersComingSoon) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    _haptic(HapticFeedback.mediumImpact);
                                    update(() => game.togglePower(seat));
                                  },
                                  icon: Icon(used
                                      ? Icons.undo
                                      : Icons.bolt_rounded),
                                  label: Text(used
                                      ? 'Used. Tap to undo'
                                      : 'Use power'),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Palette.ink,
                                      foregroundColor: Palette.gold),
                                ),
                              ),
                              ],
                              const Divider(height: 26),
                              Row(children: [
                                SpeakToken(
                                    used: spoke,
                                    locked: !canSpeak,
                                    size: 26),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                      !canSpeak
                                          ? 'Silence: no card reveals this round'
                                          : spoke
                                              ? 'Card reveal used'
                                              : 'Card reveal available',
                                      style: const TextStyle(
                                          fontSize: 15, color: Palette.ink)),
                                ),
                                MouseRegion(cursor: canSpeak ? SystemMouseCursors.click : MouseCursor.defer, child: GestureDetector(
                                  onTap: !canSpeak
                                      ? null
                                      : () {
                                          _haptic(
                                              HapticFeedback.selectionClick);
                                          update(() => game.toggleSpoke(seat));
                                        },
                                  child: Semantics(
                                    toggled: spoke,
                                    label: 'Card reveal used',
                                    child: GoldPip(on: spoke, enabled: canSpeak, size: 26),
                                  ),
                                )),
                              ]),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Row(
                          children: [
                            if (game.isAntagonist(seat))
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showScheme(seat);
                                },
                                style: TextButton.styleFrom(
                                    foregroundColor: Palette.lost),
                                child: const Text('Settle the scheme'),
                              ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                  foregroundColor: Palette.ink),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// An antagonist's open scheme: what they're after, and whether it worked.
  Future<void> _showScheme(int seat) async {
    final scheme = game.schemeOf[seat];
    if (scheme == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.traitorPanel,
        surfaceTintColor: Colors.transparent,
        title: Text('${game.courtiers[seat].title} schemes',
            style: const TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Openly working against the King. Their goal:',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            SuitText(schemes[scheme],
                style: const TextStyle(
                    fontSize: 19,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 10),
            const Text(
                'If the scheme succeeds, the King is wounded, even if every task is done. They take no tasks and do not pick.',
                style: TextStyle(color: Colors.white70, height: 1.35)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Foiled'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: Palette.lost, foregroundColor: Colors.white),
            child: const Text('It succeeded'),
          ),
        ],
      ),
    );
    if (result != null) setState(() => game.resolveScheme(seat, result));
  }

  /// Asks what to do about a seal completed out of order.
  Future<bool?> _confirmSealBreak(String problem, int quarterTurns) {
    return showDialog<bool>(
      context: context,
      builder: (context) => RotatedBox(
        quarterTurns: quarterTurns,
        child: AlertDialog(
          backgroundColor: DialogStyle.paper,
          shape: const HighVisBorder(null),
          title: const Text('A seal is broken', style: DialogStyle.paperTitle),
          content: Text(
              '$problem\n\nIf this task really was done out of order, the round is lost.',
              style: const TextStyle(fontSize: 16, height: 1.4, color: Palette.ink)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: Palette.ink),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Palette.lost, foregroundColor: Colors.white),
              child: const Text('It was: fail the round'),
            ),
          ],
        ),
      ),
    );
  }

  /// The close-up of a task, turned to face the player who holds it.
  /// The marks a task card carries beside its points (the same as on the
  /// table), each with what it means.
  List<(Widget, String)> _taskMarks(Task task, double size) => [
        if (task.noCourtCards)
          (NoCourtIcon(size: size), 'The trick can\u2019t have any Court Cards in it.'),
        if (task.kingCantTake)
          (Icon(Icons.block, size: size, color: Palette.inkSoft),
              'The King can\u2019t take this task.'),
        for (final n in task.notes)
          (Icon(Icons.info_outline, size: size, color: Palette.inkSoft), n),
        if (task.seal != null)
          (WaxSeal(seal: task.seal!, size: size + 3), Seals.describe(task.seal!)),
        if (game.isCharged(task))
          (Icon(Icons.workspace_premium, size: size + 1, color: Palette.goldDeep),
              'A royal charge: this house has been charged with this task.'),
      ];

  Future<void> _showTaskDetail(Task task, Offset tapGlobal) async {
    final owner = task.assignedPlayerIndex == null
        ? null
        : game.players[task.assignedPlayerIndex!];
    // An owned task's close-up turns to face its owner; a loose task's
    // stays upright.
    final quarterTurns = task.assignedPlayerIndex == null
        ? 0
        : _geo.edge(task.assignedPlayerIndex!);

    await showDialog<void>(
      context: context,
      builder: (context) => RotatedBox(
        quarterTurns: quarterTurns,
        child: AlertDialog(
        backgroundColor: task.isFailed ? Palette.failedCard : DialogStyle.paper,
        // Whose it is shows as on the table: their colour, edged in dark.
        shape: HighVisBorder(task.isFailed ? Palette.lost : owner?.color),
        scrollable: true,
        contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Laid out as the card on the table: points and crown, then
              // the words.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('${_points(task)}',
                      style: const TextStyle(
                          fontFamily: displayFont,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          height: 1,
                          color: Palette.ink)),
                  const SizedBox(width: 3),
                  const CrownIcon(size: 19, color: Palette.goldDeep),
                  // The same marks as the card on the table, each
                  // explained under the words.
                  for (final (icon, _) in _taskMarks(task, 21)) ...[
                    const SizedBox(width: 7),
                    icon,
                  ],
                  const Spacer(),
                  if (_progressOf(task) case final p? when !task.isCompleted && !task.isFailed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Palette.ink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(p,
                          style: const TextStyle(
                              fontFamily: bodyFont,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Palette.gold)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SuitText(task.fullText(playerCount),
                  struck: _wonNamed(task),
                  style: const TextStyle(
                      fontSize: 19,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: Palette.ink)),
              // What each mark by the points means.
              for (final (icon, words) in _taskMarks(task, 16))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 26,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Align(alignment: Alignment.topLeft, child: icon),
                          )),
                      Expanded(
                        child: SuitText(words,
                            style: const TextStyle(
                                fontSize: 14.5, height: 1.35, color: Palette.inkSoft)),
                      ),
                    ],
                  ),
                ),
              // Once it's settled, why: a plain line (the badge by the
              // points tells how it's going until then).
              if (_statusOf(task) case final status?
                  when task.isCompleted || task.isFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: SuitText(status,
                        style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: task.isCompleted ? Palette.won : Palette.lost)),
                  ),
                ),
              // The cards it's about, and what's become of them.
              if (relevantCards(task.description).isNotEmpty)
                _TaskCardsRow(cards: _cardStates(task)),
              // What it means, the game words it uses and any fine print,
              // behind an info button.
              _MoreAbout(
                explanation: explainTask(task.description),
                terms: termsIn(task.description),
                notes: const [],
              ),
            ],
          ),
        ),
        actions: _digital
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Palette.ink),
                  child: const Text('Close'),
                ),
                // Your pick: take it from here too.
                if (_yourPick &&
                    task.assignedPlayerIndex == null &&
                    _mayTake(task))
                  FilledButton(
                    // Ready for Enter, when chosen with the keys.
                    autofocus: true,
                    onPressed: () {
                      Navigator.pop(context);
                      _takeTask(task);
                    },
                    child: const Text('Take'),
                  ),
              ]
            : [
          OutlinedButton.icon(
            onPressed: () {
              _setTaskStatus(task, TaskStatus.failed);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close_rounded),
            label: Text(task.isFailed ? 'Not failed' : 'Failed'),
            style: OutlinedButton.styleFrom(
                foregroundColor: Palette.lost,
                side: const BorderSide(color: Palette.lost)),
          ),
          FilledButton.icon(
            onPressed: () async {
              // Completing a sealed task out of order fails the round.
              final problem = task.isCompleted ? null : game.sealProblem(task);
              if (problem != null) {
                final fail = await _confirmSealBreak(problem, quarterTurns);
                if (!context.mounted) return;
                Navigator.pop(context);
                if (fail == true) _setTaskStatus(task, TaskStatus.failed);
                return;
              }
              _setTaskStatus(task, TaskStatus.completed);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_rounded),
            label: Text(task.isCompleted ? 'Not done' : 'Done'),
            style: FilledButton.styleFrom(
                backgroundColor: Palette.won, foregroundColor: Colors.white),
          ),
        ],
        ),
      ),
    );
  }

  /// Opens the New Game panel on the table.
  Future<void> _showSetupDialog(
      {GameMode? startMode, int? startChapter, bool continuing = false}) async {
    setState(() {
      _setupArgs = (mode: startMode, chapter: startChapter);
      _setupContinuing = continuing;
    });
  }

  void _closeSetup() => setState(() => _setupArgs = null);

  /// From the menus into a game: the menu fades to the felt, the crown
  /// rises up in the middle in a burst of sparks, and as it lifts away the
  /// table is revealed beneath it.
  late final AnimationController _coronation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));

  void _startFromSetup(_SetupResult r) {
    if (MediaQuery.disableAnimationsOf(context) || !CharacterToken.alive) {
      _beginFromSetup(r);
      return;
    }
    Sfx.fanfare();
    // On screen, the crown stays to crown the King at the table.
    _crownHandedOver = false;
    _crownWaiting = r.digital &&
        r.mode != GameMode.tutorial &&
        r.mode != GameMode.dynasty;
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

  Widget _coronationOverlay() => AnimatedBuilder(
        animation: _coronation,
        builder: (context, _) {
          final t = _coronation.value;
          final waiting = _crownWaiting;
          if (t == 0 || (t == 1 && !waiting)) return const SizedBox.shrink();
          double iv(double a, double b, [Curve c = Curves.linear]) =>
              c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
          final cover = iv(0, 0.3, Curves.easeOut) * (1 - iv(0.6, 1, Curves.easeIn));
          final grow = iv(0.08, 0.42, Curves.easeOutBack);
          // A crown waiting for the King holds still, full size.
          final lift = waiting ? 0.0 : iv(0.58, 1, Curves.easeInCubic);
          final spark = iv(0.32, 0.85);
          final size = MediaQuery.sizeOf(context);
          final crown = math.min(size.width, size.height) * 0.28;
          final centre = Offset(size.width / 2, size.height / 2);
          return IgnorePointer(
            child: Stack(children: [
              Positioned.fill(
                child: Opacity(
                  opacity: cover,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                          radius: 0.9, colors: [Color(0xFF176141), Palette.feltDeep]),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: spark > 0 && spark < 1
                      ? _IntroSparks(
                          origin: centre, progress: spark, scale: crown / 70)
                      : null,
                ),
              ),
              if (!_crownHandedOver)
              Positioned(
                left: centre.dx - crown / 2,
                top: centre.dy - crown * 0.375 - lift * crown * 0.8,
                child: Opacity(
                  opacity: iv(0.05, 0.2) * (1 - lift),
                  child: Transform.scale(
                    scale: waiting && t > 0.42 ? 1 : 0.55 + 0.45 * grow + 0.15 * lift,
                    child: DecoratedBox(
                      decoration: BoxDecoration(boxShadow: [
                        BoxShadow(
                            color: Palette.gold.withValues(alpha: 0.35 * grow),
                            blurRadius: crown * 0.5,
                            spreadRadius: crown * 0.05),
                      ]),
                      child: CrownIcon(size: crown, color: Palette.gold),
                    ),
                  ),
                ),
              ),
            ]),
          );
        },
      );

  void _beginFromSetup(_SetupResult r) {
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
    return _SetupPanel(
      players: game.players,
      playerCount: playerCount,
      targetPoints: targetPoints,
      mode: args.mode ?? game.mode,
      surprise: game.surprise,
      roles: game.roles,
      chapter: args.chapter ?? _progress.nextChapter,
      progress: _progress,
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
      digital: _inGame ? game.digital : true,
      onSound: (on) {
        setState(() => Sfx.enabled = on);
        _saveSettings();
      },
    );
  }

  /// Changes the points target mid-game. Players and the King stay; the
  /// tasks are re-dealt to match the new target.
  Future<void> _showPointsDialog() async {
    int target = targetPoints;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          child: OrnateCard(
      ornament: Ornament.medium,
            won: false,
            court: true,
            margin: const EdgeInsets.only(top: 34),
            padding: const EdgeInsets.fromLTRB(32, 30, 32, 28),
            maxWidth: 380,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Points target',
                      style: TextStyle(
                          fontFamily: displayFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          color: Palette.goldOnFelt)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('$target',
                          style: const TextStyle(
                              fontFamily: displayFont,
                              fontWeight: FontWeight.w900,
                              fontSize: 52,
                              height: 1.1,
                              color: Palette.gold)),
                      const SizedBox(width: 8),
                      const CrownIcon(size: 32),
                    ],
                  ),
                  Slider(
                    value: target.clamp(1, maxTarget).toDouble(),
                    min: 1,
                    max: maxTarget.toDouble(),
                    divisions: maxTarget - 1,
                    onChanged: (v) => setDialogState(() => target = v.round()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Deal')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    targetPoints = target;
    _redeal();
  }

  /// Deals the round again from the start, cards, tasks and all, for a new
  /// points target: whoever's dealt the King card is King.
  void _redeal() {
    if (game.isDynasty) {
      _shuffleTasks();
      return;
    }
    setState(() {
      final keepDecree = game.decree;
      game.addTasksUntilTarget(playerCount, targetPoints,
          newRound: false, countRound: false);
      game.decree = keepDecree;
      _resetTable();
    });
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, if (current != null) current]),
          child: _inGame && _setupArgs == null
              ? KeyedSubtree(key: const ValueKey('game-bar'), child: _buildAppBar())
              : AppBar(
                  key: const ValueKey('plain-bar'),
                  toolbarHeight: 60,
                  actions: [
                    Padding(
                        padding: const EdgeInsets.only(top: 8), child: _buildMenu()),
                    const SizedBox(width: 18),
                  ]),
        ),
      ),
      body: SafeArea(
        top: !useTopBar,
        child: Stack(
          children: [
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
                          Expanded(child: mid(_buildDigitalTable())),
                          if (game.isTutorial) mid(_buildCoach()),
                          // The story has the table: no hand to play.
                          // (Not size-animated: that clipped the cards.)
                          if (!_storyActive) _buildHand(),
                        ]);
                        }))
                      : _centred(_buildTable(), aspect: 1.2)
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: _setupArgs == null ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Center(child: _buildWelcome()),
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
                          color: _inGame ? Palette.felt : Colors.transparent,
                          child: Center(child: _buildSetupPanel()),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
      // Tidings, decrees and the end of a round cover the whole screen.
      if (_inGame && _setupArgs == null && _decreePending && !(_onFelt && game.currentTiding != null))
        Positioned.fill(
            child: Material(
                type: MaterialType.transparency,
                child: SafeArea(child: _buildDecreeOverlay()))),
      if (_inGame &&
          _setupArgs == null &&
          !_onFelt &&
          game.outcome != RoundOutcome.inProgress &&
          !_outcomeHold.isAnimating &&
          // Once up it stays up, while a round won early plays out.
          (_lastTrick == null || _autoPlaying || _outcome.value > 0))
        Positioned.fill(
            child: Material(
                type: MaterialType.transparency,
                child: _buildOutcomeOverlay())),
      // Solo Dynasty's story takes the whole screen: the throne room.
      // It lowers in like a stage set, and lifts away for the cards.
      Positioned.fill(
        child: IgnorePointer(
          ignoring: !(_inGame && _setupArgs == null && _contest == null && _storyActive && game.solo),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, a) => SlideTransition(
              position: Tween(begin: const Offset(0, -1.05), end: Offset.zero)
                  .animate(a),
              child: child,
            ),
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
            child: (_inGame && _setupArgs == null && _contest == null
                    ? _throneRoom()
                    : null) is Widget
                ? KeyedSubtree(
                    key: const ValueKey('set'),
                    // The same set, scene after scene: the court stays put.
                    child: _throneRoom()!,
                  )
                : const SizedBox.shrink(key: ValueKey('no-set')),
          ),
        ),
      ),
      // A divided court plays its Trial of Hearts over everything.
      if (_contest case final contest? when _inGame)
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: ContestTable(
              key: _contestKey,
              contest: contest,
              you: _you,
              names: [
                for (int i = 0; i < game.players.length; i++)
                  i == _you
                      ? 'You'
                      : game.hasRoles
                          ? game.courtiers[i].short
                          : game.players[i].name
              ],
              colors: [for (final p in game.players) p.color],
              token: (seat, size) => SeatToken(
                player: game.players[seat],
                label: seatLabels(game.players)[seat],
                isKing: game.kingIndex == seat,
                size: size,
                shape: game.hasRoles ? game.courtiers[seat].shape : null,
                tight: true,
              ),
              labelA: dilemmas[_dilemma ?? 0].a.label,
              labelB: dilemmas[_dilemma ?? 0].b.label,
              botDelay: botDelay,
              trickPause: trickPause,
              onDone: () => _settleTrial(dilemmas[_dilemma ?? 0], contest.aWins),
            ),
          ),
        ),
      // The crowning between the menus and a game.
      Positioned.fill(child: _coronationOverlay()),
      // The brass inlay runs round the whole screen, the top bar included,
      // so it sits the same distance from every edge.
      const Positioned.fill(
          child: IgnorePointer(child: SafeArea(child: TableTrim()))),
      // Keyboard shortcuts, when asked for, beside the table.
      if (_keysShown && _inGame && _setupArgs == null && _digital)
        const Positioned(
          right: 22,
          bottom: 22,
          child: IgnorePointer(child: _ShortcutsCard()),
        ),
      // The card tracker: a panel in the middle of the screen over a dimmed
      // table (tap outside to put it away). Holding its eye, or the space
      // bar, hides it for a moment to see the table behind.
      if (_trackerMounted &&
          _inGame &&
          _setupArgs == null &&
          _digital &&
          _cards.dealId == game.dealId)
        Positioned.fill(
          key: const ValueKey('tracker'),
          child: IgnorePointer(
            ignoring: !_trackerOpen,
            child: AnimatedOpacity(
              opacity: _trackerOpen && !_trackerPeek ? 1 : 0,
              duration: Duration(milliseconds: _trackerPeek ? 120 : 220),
              curve: Curves.easeOut,
              child: Stack(children: [
                Positioned.fill(
                  // No dimming: the table stays in view behind it. A tap
                  // anywhere else puts it away.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeTracker,
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: AnimatedScale(
                      scale: _trackerOpen ? 1 : 0.95,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: 400,
                              maxHeight: MediaQuery.sizeOf(context).height * 0.88),
                          child: Material(
                            type: MaterialType.transparency,
                            child: _CardTracker(
                              key: _trackerKey,
                              cards: _cards,
                              you: _you,
                              players: game.players,
                              onClose: _closeTracker,
                              onPeek: (on) => _ui(() => _trackerPeek = on),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }

  /// The menu on the right: the rules, the Chronicle and sound.
  /// One line of the menu: a gold icon and a regal title.
  /// A menu entry; [on] adds a tick box for a setting.
  _MenuEntry _menuItem(String value, IconData icon, String title, {bool? on}) =>
      (value: value, icon: icon, title: title, on: on);

  bool _menuOpen = false;

  /// The menu button: its bars fold into a cross while the menu is open.
  Widget _buildMenu() => Tooltip(
        message: 'Menu',
        child: _GoldBar(
          onTap: _openMenu,
          semanticLabel: 'Menu',
          child: _OrnateMenuIcon(size: 30, open: _menuOpen),
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
      pageBuilder: (context, _, __) => _OrnateMenu(
        entries: _menuEntries,
        onToggle: (v) => _onMenuChoice(v),
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
    await _onMenuChoice(choice);
  }

  Future<void> _onMenuChoice(String choice) async {
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
                          GameMode.dynasty => 'Dynasty (Alpha)',
                          GameMode.tutorial => 'Tutorial',
                        },
                        onScreen: _digital,
                        players: game.players.length,
                        dynasty: game.isDynasty,
                        points: game.isDynasty ? null : targetPoints,
                        seals: [
                          for (final t in game.tasks)
                            if (t.seal != null) t.seal!
                        ]..sort(),
                        decree: game.decree?.title,
                        roles: game.hasRoles,
                      )
                    : null);
          case 'shuffle':
            _shuffleTasks();
          case 'tidings':
            _showTidings();
          case 'upright':
            setState(() {
              _upright = !_upright;
              if (_inGame && _dealtFor == game.dealId) _layoutOwned();
            });
            _saveSettings();
          case 'sound':
            setState(() => Sfx.enabled = !Sfx.enabled);
            _saveSettings();
          case 'keys':
            _ui(() => _showKeys = !_showKeys);
            _saveSettings();
          case 'suits':
            setState(() => Palette.fourColourSuits = !Palette.fourColourSuits);
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

  List<_MenuEntry> _menuEntries() => [
        if ((_inGame || _saves.isNotEmpty) && _setupArgs == null)
          _menuItem('new', Icons.group_add_outlined, 'New game'),
        if (_inGame &&
            _setupArgs == null &&
            !(game.isDynasty && game.outcome != RoundOutcome.inProgress))
          _menuItem('shuffle', Icons.style_outlined, 'Shuffle tasks'),
        _menuItem('rules', Icons.menu_book_outlined, 'How to Play'),
        if (_inGame && game.currentTiding != null)
          _menuItem('tidings', Icons.history_edu_outlined, 'This round\u2019s tidings'),
        // Only round a real table does the view need turning.
        if (_inGame && !_digital)
          _menuItem(
              'upright',
              _upright ? Icons.laptop_rounded : Icons.table_restaurant_outlined,
              _upright ? 'Laptop view' : 'Table view'),
        _menuItem(
            'sound',
            Sfx.enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            'Sounds',
            on: Sfx.enabled),
        // For colour-blind players: no two suits share a colour.
        _menuItem('suits', Icons.palette_outlined, 'Four-colour suits',
            on: Palette.fourColourSuits),
        // On a computer: the keyboard shortcuts, beside the table.
        if (_desktop)
          _menuItem('keys', Icons.keyboard_outlined, 'Keyboard shortcuts',
              on: _showKeys),
      ];

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 60,
      titleSpacing: 28,
      backgroundColor: Colors.transparent,
      title: Padding(
        padding: const EdgeInsets.only(top: 8),
        // The round's name, with anything in force this round beside it.
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              game.solo && game.currentTiding != null
                  ? game.currentTiding!.title
                  : game.mode == GameMode.chronicle && game.chapter != null
                  ? 'Chapter ${game.chapter! + 1}'
                  : game.isDynasty && game.reign > 0
                      ? 'Reign ${roman(game.reign)}'
                      : game.isTutorial
                          ? 'Lesson ${game.lesson + 1}'
                          : 'Round ${game.roundNumber}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: Palette.gold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 10)])),
          ),
              if (_choosingKing) ...[
                const SizedBox(width: 12),
                const Flexible(
                  child: Text('Choose the King',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                ),
              ],
              if (game.decree != null && !_choosingKing) ...[
                const SizedBox(width: 8),
                // The decree in force; tap to read it again.
                Flexible(child: InkWell(
                  onTap: _showDecree,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Palette.cardRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(game.decree!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                )),
              ],
              // Antagonists' open schemes; tap to read or settle one. (Solo,
              // they're black cards on the table instead.)
              if (!_choosingKing && !game.solo)
                for (final seat in game.antagonists) ...[
                  const SizedBox(width: 6),
                  Flexible(child: InkWell(
                    onTap: () => _showScheme(seat),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Palette.traitorPanel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Palette.lost),
                      ),
                      child: Text(
                          '${game.courtiers[seat].title.replaceFirst('The ', '')} schemes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  )),
                ],
        ],
      ),
      ),
      actions: [
        // At a real table: whoever's picking may pass, once a round.
        if (!_digital &&
            game.pickTurn != null &&
            game.canPass(game.pickTurn!))
          Tooltip(
            message: '${game.players[game.pickTurn!].name} passes the pick on (once a round)',
            child: TextButton(
              onPressed: () => setState(() => game.pass(game.pickTurn!)),
              style: TextButton.styleFrom(foregroundColor: Palette.gold),
              child: const Text('Pass'),
            ),
          ),
        // Dynasty is about the story: the points grow on their own.
        if (!game.isDynasty)
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 10),
          child: Tooltip(
            message: 'Points target',
            child: _GoldBar(
              onTap: _showPointsDialog,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$targetPoints',
                      style: const TextStyle(
                          fontFamily: displayFont,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1,
                          color: Palette.gold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)])),
                  const SizedBox(width: 5),
                  const CrownIcon(size: 18, color: Palette.gold),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _buildMenu(),
        ),
        const SizedBox(width: 18),
      ],
    );
  }

  /// The table keeps a fixed text size so its layout always fits; dialogs
  /// and the rules still follow the phone's text size setting.
  Widget _buildTable() {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: _buildTableContent(),
    );
  }

  Widget _buildTableContent() {
    return LayoutBuilder(builder: (context, c) {
      _tableSize = Size(c.maxWidth, c.maxHeight);
      if (_readyToDeal) {
        // Deal once the King is crowned, any decree has been read, and the
        // table size is known.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _readyToDeal) setState(_dealCards);
        });
      }
      final geo = _geo;
      final labels = seatLabels(game.players);

      return Stack(
        key: _tableKey,
        clipBehavior: Clip.none,
        children: [
          // The felt: press and hold to turn every card towards you.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: _choosingKing
                  ? null
                  : (d) => _ui(
                      () => _readerSeat = geo.nearestSeat(d.localPosition)),
              onLongPressEnd: (_) => _ui(() => _readerSeat = null),
              onLongPressCancel: () => _ui(() => _readerSeat = null),
            ),
          ),
          for (int i = 0; i < game.players.length; i++)
            Positioned(
              left: geo.seatCenter(i).dx,
              top: geo.seatCenter(i).dy,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Transform.rotate(
                  angle: geo.facing(i),
                  child: SeatToken(
                    player: game.players[i],
                    label: labels[i],
                    isKing: game.kingIndex == i,
                    size: geo.seatSize,
                    highlighted: _hoverSeat == i,
                    prompting: _choosingKing && _crowning == null,
                    picking: !_choosingKing &&
                        _dealtFor == game.dealId &&
                        game.pickTurn == i,
                    exiled: game.exiledSeat == i,
                    speakLocked: !game.canSpeak(i),
                    shape: game.hasRoles && i < game.courtiers.length
                        ? game.courtiers[i].shape
                        : null,
                    antagonist: game.isAntagonist(i),
                    wounds: game.isDynasty && game.kingIndex == i
                        ? game.kingWounds
                        : null,
                    powerUsed: game.hasRoles && !_choosingKing && !powersComingSoon
                        ? game.powerUsed[i]
                        : null,
                    loyalty: game.isDynasty &&
                            game.kingIndex != i &&
                            i < game.loyalty.length
                        ? game.loyalty[i]
                        : null,
                    spoke: _choosingKing || _digital ? null : game.spoke[i],
                    // While choosing the King a tap crowns. During play a
                    // tap opens the courtier's card, or with no roles just
                    // flips the card-reveal token.
                    onTap: _choosingKing
                        ? (_digital ? null : () => _crownKing(i))
                        : game.hasRoles
                            ? () => _showCourtier(i)
                            : () => _toggleSpoke(i),
                  ),
                ),
              ),
            ),
          if (_choosingKing)
            Center(
              child: AnimatedOpacity(
                opacity: _crowning == null ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: _buildKingPrompt(geo),
              ),
            )
          else if (_dealtFor == game.dealId)
            Positioned.fill(child: _buildCards(geo)),
          if (_crowning != null)
            Positioned.fill(
                child: IgnorePointer(child: _buildCrowning(geo, _crowning!))),

          // "Play!" once every task has an owner.
          Positioned.fill(child: IgnorePointer(child: _buildPlayFlourish())),

        ],
      );
    });
  }

  /// The crowning: the crown rises from the deck, arcs to the new King's
  /// seat and lands with a bounce and a ring of gold sparks, while "Long
  /// live the King" glows in the middle of the table.
  Widget _buildCrowning(_TableGeometry geo, int seat) {
    final a = geo.facing(seat);
    final up = Offset(math.sin(a), -math.cos(a));
    return _crowningScene(
      from: geo.center,
      to: geo.seatCenter(seat) + up * (geo.seatSize / 2 + 9),
      spinTo: a,
      seatSize: geo.seatSize,
      king: seat,
      seats: {
        for (int j = 0; j < game.players.length; j++) j: geo.seatCenter(j)
      },
    );
  }

  /// The crown flies from [from] to the new King at [to] and lands in a
  /// burst of gold, "Long live the King" glows, and every other seat in
  /// [seats] sounds a trumpet.
  Widget _crowningScene({
    required Offset from,
    required Offset to,
    required double spinTo,
    required double seatSize,
    required int king,
    required Map<int, Offset> seats,
    double? startSize,
  }) {
    final seat = king;
    final a = spinTo;
    return AnimatedBuilder(
      animation: _crown,
      builder: (context, _) {
        final t = _crown.value;
        final fly = Curves.easeInOutCubic
            .transform(clampD(t / 0.6, 0, 1));
        final land = clampD((t - 0.6) / 0.4, 0, 1);
        // Arc: lift the crown off the straight line mid-flight.
        final lift = math.sin(fly * math.pi) * (startSize == null ? 70 : 30);
        final p = Offset.lerp(from, to, fly)! - Offset(0, lift);
        final size = t < 0.6
            ? startSize != null
                // Shrinks from the walk-in's crown down onto the head.
                ? startSize + (28 - startSize) * fly
                : 30 + 40 * math.sin(fly * math.pi) // swells mid-air
            : 18 + 10 * (1 - Curves.elasticOut.transform(land));
        final spin = a * fly;
        final glow = math.sin(clampD(t / 0.9, 0, 1) * math.pi);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Opacity(
                opacity: glow,
                child: const Text('Long live the King',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 30,
                        color: Palette.gold,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 12),
                        ])),
              ),
            ),
            if (land > 0)
              Positioned.fill(
                child: CustomPaint(
                    painter: SparkBurst(origin: to, progress: land)),
              ),
            // The rest of the court sounds a fanfare: a trumpet at every
            // other seat, pointed at the new King, with notes floating out.
            for (final e in seats.entries)
              if (e.key != seat)
                ..._trumpet(e.value, seatSize, e.key, to, t),
            Positioned(
              left: p.dx - size / 2,
              top: p.dy - size * 0.375,
              child: Transform.rotate(
                angle: spin,
                child: CrownIcon(size: size, color: Palette.gold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// One player's trumpet in the crowning fanfare. It pops up just before
  /// the crown lands, toots (a little kick) and blows notes towards the King.
  List<Widget> _trumpet(
      Offset seat, double seatSize, int j, Offset king, double t) {
    // Each trumpet starts a moment after the last, like a ragged fanfare.
    final start = 0.45 + 0.04 * j;
    final local = clampD((t - start) / (1 - start), 0, 1);
    if (local <= 0) return const [];
    final toKing = king - seat;
    final dir = toKing / toKing.distance;
    final pos = seat + dir * (seatSize * 0.75);
    final angle = math.atan2(dir.dy, dir.dx);
    final pop = Curves.elasticOut.transform(clampD(local / 0.35, 0, 1));
    final toot = math.sin(local * math.pi * 6) * 0.12 * (1 - local);
    final fade = local < 0.8 ? 1.0 : (1 - local) / 0.2;
    final size = clampD(seatSize * 0.6, 22, 32);

    return [
      Positioned(
        left: pos.dx - size / 2,
        top: pos.dy - size / 2,
        child: Opacity(
          opacity: clampD(fade, 0, 1),
          child: Transform.rotate(
            angle: angle + toot,
            child: Transform.scale(
              // Keep the trumpet the right way up when it points left.
              scaleY: dir.dx < 0 ? -pop : pop,
              scaleX: pop,
              child: Icon(Icons.campaign_rounded,
                  size: size,
                  color: Palette.gold,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]),
            ),
          ),
        ),
      ),
      // Three notes drifting from the bell towards the King, rising as they go.
      for (int k = 0; k < 3; k++)
        () {
          final nt = clampD((local - 0.15 - k * 0.12) / 0.6, 0, 1);
          if (nt <= 0 || nt >= 1) return const SizedBox.shrink();
          final p = pos +
              dir * (size * 0.6 + nt * 60) +
              Offset(math.sin(nt * 8 + k) * 6, -nt * 26);
          return Positioned(
            left: p.dx - 7,
            top: p.dy - 10,
            child: Opacity(
              opacity: clampD(1 - nt, 0, 1),
              child: Text(k.isEven ? '♪' : '♫',
                  style: const TextStyle(
                      fontSize: 18,
                      color: Palette.gold,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
            ),
          );
        }(),
    ];
  }

  String? get _decreeDetail => game.decree == Decree.exile &&
          game.exiledSeat != null
      ? 'Seat ${seatLabels(game.players)[game.exiledSeat!]} is exiled this round.'
      : null;

  /// The round's tidings read again from the menu.
  void _showTidings() {
    if (game.currentTiding == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: _tidingsScroll(() => Navigator.pop(context)),
        ),
      ),
    );
  }

  /// What the royal charge says, for the scroll and the courtier's card.
  String? get _chargeLine {
    final seat = game.chargeSeat;
    if (seat == null || game.chargeTask == null) return null;
    final who = game.courtiers[seat].title;
    final t = game.currentTiding;
    return game.chargeByKing || t?.charge == null
        ? 'By the King\u2019s command, $who is charged with a task.'
        : t!.charge!;
  }

  /// The tidings that open a Dynasty round: the news, who is charged with
  /// what, and any decree it brings. Faces the King.
  Widget _tidingsScroll(VoidCallback onAccept) {
    final t = game.currentTiding!;
    final seat = game.chargeSeat;
    final charged = seat == null
        ? null
        : game.tasks.where(game.isCharged).firstOrNull;
    final king = game.kingIndex;
    if (_onFelt) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _tidingsColumn(t, seat, charged, onAccept),
          ),
        ),
      );
    }
    return RotatedBox(
      quarterTurns: king == null ? 0 : _geo.edge(king),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(1, clampD(v, 0.02, 1.2), 1),
          child: Opacity(opacity: clampD(v * 1.5, 0, 1), child: child),
        ),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: Palette.parchment,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Palette.goldDeep, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
          ),
          child: SingleChildScrollView(
            child: _tidingsColumn(t, seat, charged, onAccept),
          ),
        ),
      ),
    );
  }

  /// The round's news: who came and went, the tidings, any royal charge
  /// and decree, and the button to begin.
  Widget _tidingsColumn(
      Tiding t, int? seat, Task? charged, VoidCallback onAccept) {
    return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Comings and goings at court, before the news.
                if (game.courtNews.isNotEmpty) ...[
                  for (final (i, n) in game.courtNews.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        // Each comes or goes in their own way, in turn.
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: CharacterToken(
                              key: ValueKey('news-$i-${n.role.name}'),
                              size: 34,
                              entrance: n.arrived ? entranceOf(n.role) : null,
                              exit: n.exit,
                              delay: Duration(milliseconds: 600 + 900 * i),
                              child: _roleToken(n.role, Color(n.color), 34),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(n.text,
                              style: TextStyle(
                                  fontSize: 16, height: 1.35, color: _ink)),
                        ),
                      ]),
                    ),
                  const Divider(height: 18),
                ],
                const Icon(Icons.history_edu, color: Palette.goldDeep, size: 28),
                Text(t.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 25,
                        color: _storyRed)),
                const SizedBox(height: 8),
                Text(t.story,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 17, height: 1.4, color: _ink)),
                if (seat != null && _chargeLine != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _character(seat, 30, mood: CharacterMood.speaking),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(_chargeLine!,
                            style: TextStyle(
                                fontSize: 16,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: _ink)),
                      ),
                    ],
                  ),
                  if (charged != null) ...[
                    const SizedBox(height: 6),
                    SuitText('Their royal charge: ${charged.description}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: _inkSoft)),
                  ],
                ],
                if (game.decree != null) ...[
                  const Divider(height: 24),
                  Text('Royal Decree: ${game.decree!.title}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: displayFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: _storyRed)),
                  const SizedBox(height: 4),
                  Text(game.decree!.rule,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, height: 1.35, color: _ink)),
                  if (_decreeDetail != null)
                    Text(_decreeDetail!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                      backgroundColor: _btnBg,
                      foregroundColor: _btnFg),
                  child: Text('So it begins'),
                ),
              ],
            );
  }

  void _showDecree() {
    final d = game.decree;
    if (d == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: DecreeScroll(
            decree: d,
            detail: _decreeDetail,
            onAccept: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayFlourish() {
    return AnimatedBuilder(
      animation: _play,
      builder: (context, _) {
        final t = _play.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        final scale = 0.6 + 0.5 * Curves.elasticOut.transform(clampD(t / 0.5, 0, 1));
        final opacity = t < 0.75 ? 1.0 : (1 - t) / 0.25;
        return Center(
          child: Opacity(
            opacity: clampD(opacity, 0, 1),
            child: Transform.scale(
              scale: scale,
              child: const Text('Play!',
                  style: TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 56,
                      color: Palette.gold,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 16)])),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKingPrompt(_TableGeometry geo) {
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: math.max(160, geo.size.width - 2 * geo.seatExtent)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DeckStack(width: geo.cardWidth * 0.75),
          const SizedBox(height: 18),
          Text(
              !game.isDynasty
                  ? 'Who holds the King card?'
                  : game.fallenKings > 0
                      ? 'Who takes the crown?'
                      : 'Who will be King?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            _digital
                ? 'The cards are dealt. Whoever holds the King card will be crowned.'
                : game.isDynasty
                ? 'Tap a seat to crown them. The King takes the King card into their hand before every deal, and rules until they fall.'
                : playerCount == 2
                ? 'Tap their seat to crown the King and deal the tasks. If the Dummy has it, choose a King together.'
                : 'Tap their seat to crown the King and deal the tasks.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, height: 1.35, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Offset? _lastPointer;

  /// Where the finger was when a card was let go.
  Offset? _dropAt;

  /// The seat a dragged card was dropped on: under the finger if there's
  /// one there (a card near the edge is held back from the edge, but the
  /// finger isn't), otherwise under the card.
  int? _dropSeat(Offset cardCentre) {
    final box = _tableKey.currentContext?.findRenderObject() as RenderBox?;
    final at = _dropAt;
    _dropAt = null;
    if (box != null && at != null) {
      final seat = _geo.seatAt(box.globalToLocal(at));
      if (seat != null) return seat;
    }
    return _geo.seatAt(cardCentre);
  }

  Widget _buildCards(_TableGeometry geo) {
    return AnimatedBuilder(
      animation: _deal,
      builder: (context, _) {
        final n = game.tasks.length;
        final dealing = _deal.isAnimating;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final t in _order)
              ValueListenableBuilder<int>(
                // Only the card being dragged listens to the drag, so moving
                // it redraws that card alone.
                key: ObjectKey(t),
                valueListenable: _dragging == t ? _taskDragTick : _stillTick,
                builder: (context, tick, child) {
                // Each card leaves the deck a moment after the one before.
                final i = game.tasks.indexOf(t);
                final start = n <= 1 ? 0.0 : i / n * 0.55;
                final progress = Interval(start, math.min(1.0, start + 0.45),
                        curve: Curves.easeOutCubic)
                    .transform(_deal.value);
                final target = _toPx(_pos[t]!);
                final p = dealing
                    ? Offset.lerp(geo.center, target, progress)!
                    : target;
                // Cards travel face down and turn over as they land.
                final faceDown = dealing && progress < 0.98;
                final owner = t.assignedPlayerIndex;
                final lifted = _dragging == t;
                final cardSize = geo.cardSize(t);
                final cw = cardSize.width;
                final ch = cardSize.height;
                // Holding the felt turns every card towards that side of
                // the table; otherwise owned cards face their owner.
                final angle = lifted
                    ? 0.0
                    : _readerSeat != null
                        ? geo.cardFacing(_readerSeat!)
                        : owner != null
                            ? geo.cardFacing(owner)
                            : (_tilt[t] ?? 0.0);

                return AnimatedPositioned(
                  key: ObjectKey(t),
                  duration: dealing || lifted
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: p.dx - cw / 2,
                  top: p.dy - ch / 2,
                  width: cw,
                  height: ch,
                  child: Opacity(
                    opacity: dealing ? clampD(progress, 0, 1) : 1.0,
                    child: AnimatedRotation(
                      turns: angle / (2 * math.pi),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
                        // Measure the drag from where the finger went down,
                        // so the card doesn't lag behind by the touch slop.
                        dragStartBehavior: DragStartBehavior.down,
                        onTapUp: (d) => _showTaskDetail(t, d.globalPosition),
                        onPanStart: (d) {
                          _lastPointer = d.globalPosition;
                          _onDragStart(t);
                        },
                        onPanUpdate: (d) {
                          // Use screen movement, not the card's rotated
                          // local axes, so the card follows the finger.
                          final last = _lastPointer ?? d.globalPosition;
                          _lastPointer = d.globalPosition;
                          _onDragUpdate(t, d.globalPosition - last);
                        },
                        onPanEnd: (_) {
                          _dropAt = _lastPointer;
                          _lastPointer = null;
                          _onDragEnd(t);
                        },
                        child: AnimatedScale(
                          scale: lifted ? 1.08 : 1,
                          duration: const Duration(milliseconds: 120),
                          child: TableCard(
                            task: t,
                            points: _points(t),
                            text: _cardText(t),
                            width: cw,
                            height: ch,
                            owner: owner == null ? null : game.players[owner],

                            lifted: lifted,
                            faceDown: faceDown,
                            charged: game.isCharged(t),
                          ),
                        ),
                      )),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  /// The end of a round. A win rains gold crowns and confetti and the
  /// result springs up; a loss pulses red and the result drops in with a
  /// shudder. Either way you can set the points for the next round here.
  Widget _buildOutcomeOverlay() {
    final won = game.outcome == RoundOutcome.won;
    final fg = won ? Palette.ink : Colors.white;

    return AnimatedBuilder(
      animation: _outcome,
      builder: (context, child) {
        final t = _outcome.value;
        final appear = Curves.easeOut.transform(clampD(t / 0.25, 0, 1));
        final Widget card;
        if (won) {
          final pop = Curves.elasticOut.transform(clampD((t - 0.1) / 0.5, 0, 1));
          card = Opacity(
            opacity: appear,
            child: Transform.scale(scale: 0.6 + 0.4 * pop, child: child),
          );
        } else {
          final drop = Curves.bounceOut.transform(clampD(t / 0.45, 0, 1));
          card = Opacity(
            opacity: appear,
            child: Transform.translate(
              offset: Offset(0, -80 * (1 - drop)),
              child: child,
            ),
          );
        }
        // Losing: the felt flushes red once, then settles.
        final redPulse = won ? 0.0 : math.sin(clampD(t / 0.6, 0, 1) * math.pi);

        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Color.lerp(Colors.black45, const Color(0x99B3122B),
                    redPulse)!,
              ),
            ),
            if (won)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: CrownConfetti(progress: t, seed: game.dealId),
                  ),
                ),
              ),
            Center(child: card),
          ],
        );
      },
      child: game.isDynasty ? _buildDynastyCard(won) : _buildOutcomeCard(won, fg),
    );
  }

  // ------------------------------------------------------------ Dynasty

  /// The end of a Dynasty round, in steps: the result (and any schemes to
  /// settle), then either the King's dilemma and its verdict, or the death
  /// of the King.
  Widget _buildDynastyCard(bool won) {
    switch (_step) {
      case _DynastyStep.result:
        return _dynastyResult(won);
      case _DynastyStep.dilemma:
      case _DynastyStep.verdict:
        return RotatedBox(
          // The King reads the dilemma, so it faces them.
          quarterTurns: game.kingIndex == null ? 0 : _geo.edge(game.kingIndex!),
          child: _dilemmaCard(won),
        );
      case _DynastyStep.death:
        return _deathCard();
      case _DynastyStep.ending:
        return _endingCard();
    }
  }

  /// Solo Dynasty's story scenes, played out in the throne room: the
  /// round's news, its result, the matters before the throne and what
  /// came of them. Null when the cards are in play (or for the death of a
  /// King and the end, which keep their cards).
  Widget? _throneRoom() {
    if (!game.solo || !_storyActive) return null;
    final won = game.outcome == RoundOutcome.won;
    final news = _decreePending && game.currentTiding != null;
    if (!news && (_step == _DynastyStep.death || _step == _DynastyStep.ending)) {
      return null;
    }
    final rand = math.Random(game.dealId * 31 + (_dilemma ?? 0) + _mattersLeft);
    final court = List.of(game.court);
    final figures = <HallFigure>[];
    final lines = <HallLine>[];
    HallFigure add(Courtier c,
        {int enterAt = 0, int? exitAt, Color? color, bool enters = false}) {
      final f = HallFigure(c.name, c, color ?? game.colorOf(c),
          enterAt: enterAt, exitAt: exitAt, enters: enters);
      figures.add(f);
      return f;
    }

    void herald(String text) => lines.add(HallLine(text));
    // You, from the throne.
    void king(String text) => lines.add(HallLine(text, who: ThroneRoom.kingId));
    void say(Courtier c, String text,
            {CharacterMood mood = CharacterMood.speaking, int side = 0}) =>
        lines.add(HallLine(text, who: c.name, mood: mood, side: side));
    String title;
    HallChoice? left, right;

    if (news) {
      final t = game.currentTiding!;
      title = t.title;
      // Who left, and who has come.
      for (final n in game.courtNews.where((n) => !n.arrived)) {
        if (court.contains(n.role)) continue;
        add(n.role, exitAt: lines.length, color: Color(n.color));
        herald(n.text);
      }
      final arrived = {for (final n in game.courtNews) if (n.arrived) n.role};
      // At a coronation everyone makes their entrance; otherwise only
      // newcomers do.
      for (final c in court) {
        if (!arrived.contains(c)) add(c, enters: t.arc == 'crown');
      }
      for (final c in court.where(arrived.contains)) {
        add(c, enterAt: lines.length, enters: true);
        say(c, introductions[c]!);
        king(kingReplies[c]!);
      }
      if (t.arc == 'crown') {
        herald(t.story);
        // Each house introduces itself to the new King.
        for (final c in court.where((c) => !arrived.contains(c))) {
          say(c, introductions[c]!);
          king(kingReplies[c]!);
        }
      } else {
        // The council talks of the kingdom before the news comes in.
        final war = game.flags.contains('karsk_defied') ||
            game.flags.contains('karsk_war');
        final talkers = List.of(court)..shuffle(rand);
        for (final c in talkers.take(math.min(2, talkers.length))) {
          final pool = chatter[c]!;
          say(c, war && rand.nextBool() ? warChatter[c]! : pool[rand.nextInt(pool.length)]);
        }
        herald(t.story);
        // Someone has an opinion on it, as they always do.
        final others = court.where((c) => c != t.house).toList();
        if (others.isNotEmpty) {
          final c = others[rand.nextInt(others.length)];
          say(c, newsQuips[c]!);
        }
      }
      final charged = game.chargeSeat;
      if (charged != null && charged < game.courtiers.length) {
        final role = game.courtiers[charged];
        final task = game.tasks.where(game.isCharged).firstOrNull;
        herald('${_chargeLine ?? ''}${task == null ? '' : '\nTheir charge: ${task.description}'}');
        say(role, acceptances[role]!, mood: CharacterMood.pleased);
        king('See that you do.');
      }
      if (game.decree != null) {
        herald('Royal Decree: ${game.decree!.title}. ${game.decree!.rule}');
      }
      right = HallChoice('So it begins',
          () => setState(() => _decreeReadFor = game.dealId));
    } else if (_step == _DynastyStep.result) {
      for (final c in court) {
        add(c);
      }
      final t = game.currentTiding;
      title = t?.title ?? (won ? 'Victory' : 'Defeat');
      // What the hand meant: who delivered, who let the court down.
      final failed = [
        for (final task in game.tasks)
          if (task.isFailed && task.assignedPlayerIndex != null) task
      ];
      final doneBy = <Courtier, int>{};
      for (final task in game.tasks) {
        final seat = task.assignedPlayerIndex;
        if (task.isCompleted && seat != null && seat != _you && seat < game.courtiers.length) {
          doneBy[game.courtiers[seat]] = (doneBy[game.courtiers[seat]] ?? 0) + 1;
        }
      }
      herald(won
          ? 'Every task is done. ${t?.won.text ?? ''}'
          : 'The court has failed. ${t?.lost.text ?? ''}');
      if (!won && failed.isNotEmpty) {
        final seat = failed.first.assignedPlayerIndex!;
        if (seat == _you) {
          herald('It was your own task that failed, Majesty.');
          final c = court.isEmpty ? null : court[rand.nextInt(court.length)];
          if (c != null) say(c, groans[c]!, mood: CharacterMood.angry);
        } else if (seat < game.courtiers.length && court.contains(game.courtiers[seat])) {
          final c = game.courtiers[seat];
          say(c, taskFailed[c]!, mood: CharacterMood.angry);
          // Someone else blames them.
          final others = court.where((o) => o != c).toList();
          if (others.isNotEmpty) {
            final o = others[rand.nextInt(others.length)];
            say(o, retorts[o]!
                .replaceAll('{other}', c.title.replaceFirst('The', 'the'))
                .replaceAll('{Other}', c.title),
                mood: CharacterMood.angry);
          }
        }
      } else if (won) {
        final best = doneBy.entries.fold<MapEntry<Courtier, int>?>(
            null, (a, e) => a == null || e.value > a.value ? e : a);
        final c = best?.key ??
            (court.isEmpty ? null : court[rand.nextInt(court.length)]);
        if (c != null && court.contains(c)) {
          say(c, cheers[c]!, mood: CharacterMood.pleased);
        }
      }
      king(won ? 'Well done, all of you.' : 'Then we will do better.');
      for (final seat in game.antagonists) {
        final scheme = game.schemeOf[seat];
        if (scheme != null) {
          herald('${game.courtiers[seat].title} schemed: ${schemes[scheme]}');
        }
      }
      right = HallChoice(
          game.kingFallen
              ? 'Attend the King'
              : game.ending == DynastyEnding.goldenAge
                  ? 'The realm is secured'
                  : game.ending != null
                      ? 'The traitors rise'
                      : 'Hear the council',
          () => _afterResult(won),
          enabled: game.schemesSettled);
    } else {
      final d = dilemmas[_dilemma ?? 0];
      title = d.audience ? 'A Private Audience' : d.title;
      // A private audience is just the two of you.
      for (final c in court) {
        if (!d.audience || c == d.about) add(c);
      }
      final deciding = _step == _DynastyStep.dilemma;
      // Someone from beyond the court comes in to bring their matter, and
      // leaves once you've ruled.
      final visitorId = 'visitor-${d.title}';
      if (d.speaker != null && d.about == null) {
        figures.add(HallFigure(visitorId, null, const Color(0xFF7A5A3A),
            name: d.speaker!.split(',').first,
            enters: true,
            exitAt: deciding ? null : 1 << 20));
      }
      if (deciding) {
        final bringer = d.about != null && court.contains(d.about) ? d.about : null;
        if (bringer != null) {
          say(bringer, d.story);
        } else if (d.speaker != null && d.about == null) {
          herald('${d.speaker} is shown in.');
          lines.add(HallLine(d.story, who: visitorId, name: d.speaker));
        } else if (d.speaker != null) {
          herald('${d.speaker}:\n${d.story}');
        } else {
          herald(d.story);
        }
        if (!d.audience) king(kingPrompts[rand.nextInt(kingPrompts.length)]);
        final pleas = d.audience ? const <Plea>[] : _pleasFor(d);
        for (final p in pleas) {
          say(p.courtier, p.line, side: p.forA ? -1 : 1);
        }
        // Back and forth: the first voice answers the other side.
        final a = pleas.where((p) => p.forA).firstOrNull;
        final b = pleas.where((p) => !p.forA).firstOrNull;
        if (a != null && b != null) {
          final other = b.courtier.title.replaceFirst('The', 'the');
          final line = retorts[a.courtier]!
              .replaceAll('{other}', other)
              .replaceAll('{Other}', b.courtier.title);
          say(a.courtier, line, mood: CharacterMood.angry, side: -1);
          // ...who gives as good as they get.
          say(b.courtier,
              counters[b.courtier]!
                  .replaceAll('{other}', a.courtier.title.replaceFirst('The', 'the')),
              mood: CharacterMood.angry,
              side: 1);
          // And someone on the side lines can't keep quiet.
          final idle = court
              .where((c) => !pleas.any((p) => p.courtier == c))
              .toList();
          if (idle.isNotEmpty && rand.nextBool()) {
            final c = idle.contains(Courtier.jester)
                ? Courtier.jester
                : idle[rand.nextInt(idle.length)];
            final pool = asides[c]!;
            say(c, pool[rand.nextInt(pool.length)]);
          }
          king('Enough. I have heard you both.');
        }
        HallFigure? figOf(Courtier c) =>
            figures.where((f) => f.role == c).firstOrNull;
        HallChoice choice(Choice ch, bool isA) => HallChoice(
              ch.label,
              d.council ? () => _chooseSide(d, isA) : () => _decide(ch),
              backers: [
                for (final p in pleas)
                  if (p.forA == isA)
                    if (figOf(p.courtier) case final f?) f
              ],
              cost: GameState.costOf(ch),
              enabled: game.canAfford(ch),
            );
        if (d.council) {
          herald('The court is divided. Choose your side, Majesty, and the Trial of Hearts will decide.');
        }
        left = choice(d.a, true);
        right = choice(d.b, false);
      } else {
        // Your ruling, in your own words.
        final ruled = _lastChoice;
        if (ruled != null) {
          king(d.audience ? ruled.label : '${ruled.label}. That is my will.');
          // The visitor takes your answer, and goes.
          final replies = d.replies;
          if (replies != null && d.speaker != null && d.about == null) {
            final first = identical(ruled, d.a);
            lines.add(HallLine(first ? replies.$1 : replies.$2,
                who: visitorId,
                name: d.speaker,
                mood: first ? CharacterMood.pleased : CharacterMood.angry));
          }
        }
        herald(_verdictStory);
        // The council takes your ruling, each in their own words.
        for (final (role, text, mood) in _verdict) {
          if (role == null || !court.contains(role) || mood == CharacterMood.leaving) {
            herald(text);
            continue;
          }
          final spoken = mood == CharacterMood.speaking
              ? text.replaceAll('\u201c', '').replaceAll('\u201d', '')
              : text.contains('turns against')
                  ? 'Then I serve you no longer, Majesty.'
                  : text.contains('returns to your side')
                      ? 'Perhaps I misjudged you, Majesty.'
                      : text.contains('royal task')
                          ? acceptances[role]!
                          : mood == CharacterMood.pleased
                              ? 'I will remember this kindness, Majesty.'
                              : 'I will remember this, Majesty.';
          say(role, spoken, mood: mood);
        }
        right = HallChoice(
            game.kingFallen
                ? 'Attend the King'
                : game.ending != null
                    ? 'The traitors rise'
                    : _mattersLeft > 0
                        ? 'The next matter'
                        : 'To the cards',
            () => _afterVerdict(won));
      }
    }
    return ThroneRoom(
      key: const ValueKey('hall'),
      scene: 'hall-${game.dealId}-$news-${_step.name}-$_dilemma-$_mattersLeft',
      title: title,
      figures: figures,
      lines: lines,
      king: SeatToken(
        player: game.players[_you],
        label: seatLabels(game.players)[_you],
        isKing: true,
        size: 44,
        shape: TokenShape.shield,
        wounds: game.kingWounds,
        tight: true,
      ),
      kingName: 'King ${game.reignName}, Reign ${roman(game.reign)}',
      coffers: game.coffers,
      wounds: game.kingWounds,
      // Buttons only for real decisions; otherwise a tap goes on.
      left: left,
      right: left == null ? null : right,
      onContinue: left == null && right != null && right.enabled ? right.onTap : null,
      fast: botDelay.inMilliseconds < 5,
    );
  }

  /// A divided court: you take a side, the court chooses in secret, and
  /// the Trial of Hearts decides (unless everyone agrees).
  void _chooseSide(Dilemma d, bool forA) {
    _votes = {_you: forA};
    _botsTakeSides();
    final sides = _votes.values.toSet();
    if (sides.length == 1) {
      _decide(forA ? d.a : d.b,
          heeded: true, lead: const ['The court stands as one.']);
      return;
    }
    setState(() => _contest = ContestState.deal(
        players: game.players.length,
        king: game.kingIndex ?? _you,
        sideA: [for (int i = 0; i < game.players.length; i++) _votes[i] ?? forA],
        rand: math.Random()));
  }

  /// On from the King's decision: the next matter, or the next hand.
  void _afterVerdict(bool won) => setState(() {
              if (game.kingFallen) {
                _step = _DynastyStep.death;
                Sfx.lose();
              } else if (game.ending != null) {
                _step = _DynastyStep.ending;
                Sfx.lose();
              } else if (_mattersLeft > 0) {
                // The next matter before the throne.
                _mattersLeft--;
                _dilemma = game.pickDilemma();
                _votes = {};
                _sidesShown = false;
                _contest = null;
                _step = _DynastyStep.dilemma;
                _botsTakeSides();
              } else {
                _nextDynastyRound(won);
              }
            });

  void _afterResult(bool won) => setState(() {
                    // The tidings play out before anything else.
                    game.resolveTiding(won);
                    if (game.kingFallen) {
                      _step = _DynastyStep.death;
                      Sfx.lose();
                    } else if (game.ending != null) {
                      _step = _DynastyStep.ending;
                      if (game.ending == DynastyEnding.goldenAge) {
                        Sfx.fanfare();
                      } else {
                        Sfx.lose();
                      }
                    } else {
                      _dilemma = game.pickDilemmaAfter(won);
                      // Solo, the court often has more business before
                      // the next hand is dealt.
                      _mattersLeft = game.solo
                          ? const [0, 1, 1, 2][_rand.nextInt(4)]
                          : 0;
                      _votes = {};
                      _sidesShown = false;
                      _contest = null;
                      _step = _DynastyStep.dilemma;
                      _botsTakeSides();
                    }
                  });

  Widget _dynastyResult(bool won) {
    final fg = won && !_onFelt ? Palette.ink : Colors.white;
    final settled = game.schemesSettled;
    return _parchmentCard(
      color: won ? Palette.gold : Palette.feltDeep,
      border: won ? null : Palette.lost,
      children: [
        CrownIcon(size: 40, color: won ? Palette.ink : Palette.lost),
        const SizedBox(height: 4),
        Text(won ? 'Round won' : 'Round lost',
            style: TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w900,
                fontSize: 30,
                color: fg)),
        const SizedBox(height: 8),
        // What came of the round's news, and nothing more.
        Text(
            game.currentTiding != null
                ? (won ? game.currentTiding!.won.text : game.currentTiding!.lost.text)
                : won
                    ? 'Every task is done.'
                    : 'A task failed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, height: 1.4, color: fg)),
        for (final seat in game.antagonists) ...[
          const SizedBox(height: 12),
          SuitText(
              '${game.courtiers[seat].title}\u2019s scheme: ${schemes[game.schemeOf[seat]!]}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.3, color: fg)),
          const SizedBox(height: 6),
          // On screen the cards settle it.
          if (!_digital)
          SegmentedButton<bool>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(value: false, label: Text('Foiled')),
              ButtonSegment(value: true, label: Text('Succeeded')),
            ],
            selected: {
              if (game.schemeResult[seat] != null) game.schemeResult[seat]!
            },
            onSelectionChanged: (v) {
              if (v.isEmpty) return;
              setState(() => game.resolveScheme(seat, v.first));
            },
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: !settled
              ? null
              : () => _afterResult(won),
          style: won
              ? FilledButton.styleFrom(
                  backgroundColor: Palette.ink, foregroundColor: Palette.gold)
              : null,
          child: Text(!settled
              ? 'Settle the schemes first'
              : game.kingFallen
                  ? 'Attend the King'
                  : game.ending == DynastyEnding.goldenAge
                      ? 'The realm is secured'
                      : game.ending != null
                          ? 'The traitors rise'
                          : 'The King must decide'),
        ),
        if (_lastMark != null)
          TextButton(
            onPressed: _undoLastMark,
            style: TextButton.styleFrom(
                foregroundColor: won ? Palette.ink : Colors.white70),
            child: const Text('Undo last mark'),
          ),
      ],
    );
  }

  Widget _dilemmaCard(bool won) {
    final d = dilemmas[_dilemma ?? 0];
    final deciding = _step == _DynastyStep.dilemma;
    final bringer = d.about != null && game.courtRoles.contains(d.about)
        ? d.about
        : null;
    final body = TextStyle(fontSize: 17, height: 1.4, color: _ink);
    final pleas = deciding ? _pleasFor(d) : const <Plea>[];
    return _parchmentCard(
      color: Palette.parchment,
      border: Palette.goldDeep,
      children: [
        if (!_onFelt) ...[
          // Whoever brings the matter, or the crown.
          if (bringer != null)
            CharacterToken(
                key: ValueKey('bringer-${d.title}'),
                mood: CharacterMood.speaking,
                size: 44,
                child: _roleToken(bringer, game.colorOf(bringer), 44))
          else
            const CrownIcon(size: 30, color: Palette.goldDeep),
          const SizedBox(height: 6),
        ],
        Text(d.title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: _storyRed)),
        const SizedBox(height: 10),
        // At the table, whoever brings the matter says it themselves.
        if (_onFelt && deciding && (bringer != null || d.speaker != null))
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: CharacterToken(
                key: ValueKey('bringer-${d.title}'),
                entrance: bringer == null ? Entrance.march : entranceOf(bringer),
                size: 44,
                child: bringer != null
                    ? _roleToken(bringer, game.colorOf(bringer), 44)
                    : _visitorToken(44),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SpeechBubble(d.story,
                  who: d.speaker ?? bringer!.title),
            ),
          ])
        else
          Text(deciding ? d.story : _verdictStory,
              textAlign: TextAlign.center, style: body),
        // The council has its say, one after another, taking sides.
        if (deciding && _onFelt)
          for (final (i, p) in pleas.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CharacterToken(
                  key: ValueKey('plea-${d.title}-$i'),
                  mood: CharacterMood.speaking,
                  size: 36,
                  delay: Duration(milliseconds: 900 + 1100 * i),
                  child: _roleToken(p.courtier, game.colorOf(p.courtier), 36),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SpeechBubble(p.line,
                      who: p.courtier.title,
                      delay: Duration(milliseconds: 900 + 1100 * i)),
                ),
              ]),
            ),
        const SizedBox(height: 14),
        if (deciding) ...[
          if (d.council)
            ..._trial(d)
          else
            for (final (ci, choice) in [d.a, d.b].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _decide(choice),
                    style: FilledButton.styleFrom(
                        backgroundColor: _btnBg,
                        foregroundColor: _btnFg,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(child: Text(choice.label, textAlign: TextAlign.center)),
                      // Who stands behind this choice.
                      for (final p in pleas.where((p) => p.forA == (ci == 0)))
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _roleToken(p.courtier, game.colorOf(p.courtier), 22),
                        ),
                    ]),
                  ),
                ),
              ),
        ] else ...[
          for (final (i, (role, text, mood)) in _verdict.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: role == null
                  ? Text(text, textAlign: TextAlign.center, style: body)
                  : Row(children: [
                      // Each reaction plays in turn, down the list.
                      CharacterToken(
                          key: ValueKey('verdict-$i-${role.name}'),
                          mood: mood,
                          size: 34,
                          delay: Duration(milliseconds: 300 * i),
                          child: _roleToken(role, game.colorOf(role), 34)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: mood == CharacterMood.speaking && _onFelt
                              ? SpeechBubble(text, who: role.title)
                              : Text(text, style: body)),
                    ]),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _afterVerdict(won),
            style: FilledButton.styleFrom(
                backgroundColor: Palette.cardRed, foregroundColor: Colors.white),
            child: Text(game.kingFallen
                ? 'Attend the King'
                : game.ending != null
                    ? 'The traitors rise'
                    : _mattersLeft > 0
                        ? 'The next matter'
                        : 'Next round'),
          ),
        ],
      ],
    );
  }

  /// How much [r] stands to gain from [c].
  int _leanOf(Choice c, Courtier r) {
    var score = 0;
    for (final e in c.effects) {
      switch (e) {
        case Loyalty(:final courtier, :final delta) when courtier == r:
          score += delta * 2;
        case AllLoyalty(:final delta):
          score += delta;
        case Charge(:final courtier) when courtier == r:
          score += 1;
        case Say(:final courtier) when courtier == r:
          score -= 1; // they complain about it afterwards
        default:
      }
    }
    return score;
  }

  /// What the council says about [d]: its own pleas from whoever is at
  /// court, or pleas made up from who gains what, so both sides are heard
  /// when there are people to argue them.
  List<Plea> _pleasFor(Dilemma d) {
    final court = game.courtRoles.where((c) => c != Courtier.king).toList();
    final rand = math.Random(d.title.hashCode ^ game.roundNumber);
    String line(Courtier c, Choice ch) {
      final lines = pleaLines[c]!;
      final label = ch.label;
      final lower = label[0].toLowerCase() + label.substring(1);
      return lines[rand.nextInt(lines.length)]
          .replaceAll('{choice}', lower)
          .replaceAll('{Choice}', label);
    }

    final out = [for (final p in d.pleas) if (court.contains(p.courtier)) p];
    if (out.isEmpty) {
      for (final c in court) {
        final la = _leanOf(d.a, c), lb = _leanOf(d.b, c);
        if (la != lb) out.add(Plea(c, line(c, la > lb ? d.a : d.b), forA: la > lb));
      }
    }
    // Make sure each side has a voice.
    for (final forA in [true, false]) {
      if (out.any((p) => p.forA == forA)) continue;
      final quiet = court.where((c) => !out.any((p) => p.courtier == c)).toList();
      if (quiet.isEmpty) continue;
      final c = quiet[rand.nextInt(quiet.length)];
      out.add(Plea(c, line(c, forA ? d.a : d.b), forA: forA));
    }
    // At most one each from three voices, the two sides taking turns.
    final a = out.where((p) => p.forA).toList(), b = out.where((p) => !p.forA).toList();
    return [
      for (int i = 0; i < 2; i++) ...[
        if (i < a.length) a[i],
        if (i < b.length) b[i],
      ]
    ].take(3).toList();
  }

  /// How much a courtier at [seat] stands to gain from [c].
  int _lean(Choice c, int seat) {
    var score = 0;
    for (final e in c.effects) {
      switch (e) {
        case Loyalty(:final courtier, :final delta)
            when seat < game.courtiers.length && game.courtiers[seat] == courtier:
          score += delta * 2;
        case AllLoyalty(:final delta):
          score += delta;
        default:
      }
    }
    return score;
  }

  /// On screen, the bots pick their sides: the King first, then the
  /// courtiers, by what they stand to gain and how loyal they are.
  void _botsTakeSides() {
    if (!_digital || _dilemma == null) return;
    final d = dilemmas[_dilemma!];
    final king = game.kingIndex;
    if (!d.council || king == null) return;
    final rand = math.Random();
    if (king != _you) _votes[king] ??= rand.nextBool();
    final kingA = _votes[king];
    if (kingA == null) return; // you're King: the court waits for you
    for (int s = 0; s < game.players.length; s++) {
      if (s == _you || s == king || _votes.containsKey(s)) continue;
      final la = _lean(d.a, s), lb = _lean(d.b, s);
      if (game.isAntagonist(s)) {
        _votes[s] = !kingA;
      } else if (la != lb && rand.nextDouble() < 0.7) {
        _votes[s] = la > lb;
      } else {
        final loyalty = s < game.loyalty.length ? game.loyalty[s] : 3;
        _votes[s] = rand.nextDouble() < 0.3 + 0.12 * loyalty ? kingA : !kingA;
      }
    }
  }

  /// A matter that divides the court: everyone takes a side, then the
  /// sides play a Trial of Hearts and the winners have their way.
  List<Widget> _trial(Dilemma d) {
    final body = TextStyle(fontSize: 17, height: 1.4, color: _ink);
    final king = game.kingIndex;
    final seats = [
      if (king != null) king,
      for (int i = 0; i < game.players.length; i++)
        if (i != king) i
    ];
    final chosen = seats.every(_votes.containsKey);
    // Who chooses next: on screen only you; at the table, each in turn,
    // the King first.
    final int? chooser = _digital
        ? (_votes.containsKey(_you) ||
                (king != null && king != _you && !_votes.containsKey(king))
            ? null
            : _you)
        : seats.where((s) => !_votes.containsKey(s)).firstOrNull;
    final sides = _votes.values.toSet();
    Widget button(String text, VoidCallback? onPressed, {bool outlined = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: double.infinity,
            child: outlined
                ? OutlinedButton(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.ink,
                        side: BorderSide(color: _ink)),
                    child: Text(text, textAlign: TextAlign.center))
                : FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                        backgroundColor: _btnBg,
                        foregroundColor: _btnFg),
                    child: Text(text, textAlign: TextAlign.center)),
          ),
        );
    String name(int seat) => _digital && seat == _you
        ? 'You'
        : game.hasRoles
            ? game.courtiers[seat].short
            : game.players[seat].name;
    return [
      Text(
          _digital
              ? 'The court is divided. Choose your side, and the Trial of Hearts will decide.'
              : 'The court is divided. Pass the phone round: each takes a side in secret, and the Trial of Hearts will decide.',
          textAlign: TextAlign.center,
          style: body),
      if (chooser == null && !_digital)
        for (final (letter, c) in [('A', d.a), ('B', d.b)])
          Text('$letter.  ${c.label}', textAlign: TextAlign.center, style: body),
      const SizedBox(height: 8),
      // Sides are chosen in secret: you only ever see your own (on screen),
      // or the one being chosen now (passing the phone round).
      if (_sidesShown)
        for (final seat in seats)
          Text(
              '${seat == king ? '♛ ' : ''}${name(seat)}: ${_votes[seat] == true ? 'A' : 'B'}',
              style: TextStyle(fontSize: 15, color: _ink))
      else if (chooser != null) ...[
        if (!_digital)
          Text(
              'Pass the phone to ${name(chooser)}${chooser == king ? ' (the King chooses first)' : ''}.',
              textAlign: TextAlign.center,
              style: body),
        const SizedBox(height: 6),
        for (final a in [true, false])
          button('${a ? 'A' : 'B'}.  ${(a ? d.a : d.b).label}', () => setState(() {
                _votes[chooser] = a;
                if (chooser == king) _botsTakeSides();
              })),
      ] else if (_digital && _votes.containsKey(_you))
        Text(
            'You stand for \u201c${(_votes[_you]! ? d.a : d.b).label}\u201d. The court has chosen in secret.',
            textAlign: TextAlign.center,
            style: body),
      const SizedBox(height: 8),
      if (!chosen)
        const SizedBox.shrink()
      else if (sides.length == 1)
        button('The court stands as one: ${(sides.first ? d.a : d.b).label}',
            () => _decide(sides.first ? d.a : d.b,
                heeded: true, lead: const ['The court stands as one.']))
      else if (_digital)
        button('To the cards', () {
          setState(() => _contest = ContestState.deal(
              players: game.players.length,
              king: king ?? 0,
              sideA: [for (int i = 0; i < game.players.length; i++) _votes[i]!],
              rand: math.Random()));
        })
      else if (!_sidesShown) ...[
        Text(
            'The Trial of Hearts: deal out the whole deck (set any spare cards aside); the 2\u2663 leads. Here the Court Cards are just a suit of their own: only the suit led can win. No \u2665 or Q\u2660 on the first trick, and \u2665 can\u2019t be led until one has fallen. Every \u2665 you win is a mark of shame, and the Q\u2660 is five. Count your marks, then show the sides.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.35, color: _inkSoft)),
        const SizedBox(height: 8),
        button('Show the sides', () => setState(() => _sidesShown = true)),
      ] else ...[
        Text(
            'Add up each side\u2019s marks and divide by its courtiers. Fewest wins; a tie goes to the King\u2019s side.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.35, color: _inkSoft)),
        const SizedBox(height: 8),
        button('A has fewer marks', () => _settleTrial(d, true)),
        button('B has fewer marks', () => _settleTrial(d, false)),
      ],
    ];
  }

  /// The Trial of Hearts is over: its winners have their way. Losing to
  /// the King's side is remembered; beating it, the King bows to the court.
  void _settleTrial(Dilemma d, bool aWins) {
    final king = game.kingIndex;
    final kingA = king == null ? aWins : _votes[king]!;
    final losers = [
      for (final e in _votes.entries)
        if (e.value != aWins && e.key != king) e.key
    ];
    _contest = null;
    if (aWins == kingA) {
      _decide(aWins ? d.a : d.b,
          overruled: losers,
          lead: const ['The King’s side wins the trial.']);
    } else {
      _decide(aWins ? d.a : d.b,
          heeded: true,
          lead: const ['The court wins the trial. The King bows to its will.']);
    }
  }

  /// Carries out the King's choice and writes up what changed.
  /// The choice you made last, so you can be heard making it.
  Choice? _lastChoice;

  void _decide(Choice choice,
      {List<int> overruled = const [],
      bool heeded = false,
      List<String> lead = const []}) {
    _lastChoice = choice;
    final roles = List.of(game.courtRoles);
    final loyaltyBefore = {for (final c in roles) c: game.loyaltyOf(c)};
    final woundsBefore = game.kingWounds;
    final pointsBefore = game.pointsBonus;
    setState(() {
      game.applyChoice(choice);
      if (overruled.isNotEmpty) game.overruled(overruled);
      if (heeded) game.heededCouncil();
      final lines = <(Courtier?, String, CharacterMood)>[
        for (final l in lead) (null, l, CharacterMood.idle)
      ];
      void line(String text) => lines.add((null, text, CharacterMood.idle));
      // Courtiers speak their minds, then show how they took it.
      for (final e in choice.effects.whereType<Say>()) {
        if (game.courtRoles.contains(e.courtier)) {
          lines.add((e.courtier, '“${e.line}”', CharacterMood.speaking));
        }
      }
      for (final c in roles) {
        final before = loyaltyBefore[c]!, after = game.loyaltyOf(c);
        if (before == after) continue;
        if (after <= 0 && before > 0) {
          lines.add((c, '${c.title} turns against you!', CharacterMood.angry));
        } else if (after > 0 && before <= 0) {
          lines.add((c, '${c.title} returns to your side.', CharacterMood.pleased));
        } else {
          lines.add(after > before
              ? (c, '${c.title} will remember this kindness.', CharacterMood.pleased)
              : (c, '${c.title} will remember this.', CharacterMood.angry));
        }
      }
      for (final c in game.pendingArrivals) {
        lines.add((c, '${c.title} is summoned to court.', CharacterMood.speaking));
      }
      for (final c in game.pendingDepartures) {
        lines.add((c, '${c.title} will leave the court.', CharacterMood.leaving));
      }
      final wounds = game.kingWounds - woundsBefore;
      if (wounds > 0) line('You take a wound.');
      if (wounds < 0) line('A wound is healed.');
      final points = game.pointsBonus - pointsBefore;
      if (points > 0) line('The court’s burdens grow.');
      if (points < 0) line('The court’s burdens ease.');
      if (game.pendingDecree != null) {
        line('Next round brings a decree: ${game.pendingDecree!.title}');
      }
      if (game.pendingCharge != null) {
        lines.add((
          game.pendingCharge!,
          'Next round, ${game.pendingCharge!.title} is charged with a royal task.',
          CharacterMood.idle
        ));
      }
      _verdict = lines;
      _verdictStory = choice.outcome;
      _step = _DynastyStep.verdict;
    });
  }

  /// Solo Dynasty tells its story on the table itself, not in boxes.
  bool get _onFelt => _digital && game.isDynasty;
  Color get _ink => _onFelt ? Colors.white : Palette.ink;
  Color get _inkSoft => _onFelt ? Colors.white70 : Palette.inkSoft;
  Color get _storyRed => _onFelt ? Palette.gold : Palette.cardRed;
  Color get _btnBg => _onFelt ? Palette.gold : Palette.ink;
  Color get _btnFg => _onFelt ? Palette.ink : Palette.gold;

  /// Whether the story has the table right now (see [_storyStage]).
  bool get _storyActive =>
      _onFelt &&
      _inGame &&
      _setupArgs == null &&
      ((_decreePending && game.currentTiding != null) ||
          (game.outcome != RoundOutcome.inProgress && _lastTrick == null));

  /// The story at the table, in place of the cards: the round's news, its
  /// end, the King's decision. Null while the cards are in play.
  Widget? _storyStage() {
    if (!_onFelt || !_inGame || _setupArgs != null) return null;
    // Solo, the throne room has the story, except the death of a King and
    // the end, which are told here.
    if (game.solo &&
        ((_decreePending && game.currentTiding != null) ||
            (_step != _DynastyStep.death && _step != _DynastyStep.ending))) {
      return null;
    }
    final Widget? stage;
    final String key;
    if (_decreePending && game.currentTiding != null) {
      stage = _tidingsScroll(() => setState(() => _decreeReadFor = game.dealId));
      key = 'news-${game.dealId}';
    } else if (game.outcome != RoundOutcome.inProgress && _lastTrick == null) {
      stage = _buildDynastyCard(game.outcome == RoundOutcome.won);
      key = 'end-${game.dealId}-${_step.name}';
    } else {
      return null;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
            child: child),
      ),
      child: KeyedSubtree(key: ValueKey(key), child: stage),
    );
  }

  /// How the story names whoever sits in [seat]: their own name when
  /// characters come and go, otherwise their courtier title.
  String _who(int seat) =>
      game.solo ? game.personAt(seat) : game.courtiers[seat].title;

  /// Someone from beyond the court: an envoy, a petitioner.
  Widget _visitorToken(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF5A4632),
          shape: BoxShape.circle,
          border: Border.all(color: Palette.goldDeep, width: 2),
        ),
        child: Icon(Icons.person_rounded, size: size * 0.6, color: Palette.gold),
      );

  /// A token for [role] in [color], for someone who may not have a seat
  /// (yet, or any more).
  Widget _roleToken(Courtier role, Color color, double size) => ShapedToken(
        shape: role.shape,
        size: size,
        color: color,
        ring: Palette.goldDeep,
        child: OutlinedLabel(seatLabels([Player(role.title, color: color)]).first,
            fontSize: size * 0.36, strokeWidth: size * 0.07),
      );

  /// A courtier's token, alive.
  Widget _character(int seat, double size,
          {CharacterMood mood = CharacterMood.idle,
          Duration delay = Duration.zero,
          Key? key}) =>
      CharacterToken(
        key: key,
        mood: mood,
        delay: delay,
        size: size,
        phase: seat * 0.37,
        child: ShapedToken(
          shape: game.hasRoles
              ? game.courtiers[seat].shape
              : TokenShape.shield,
          size: size,
          color: game.players[seat].color,
          ring: Palette.goldDeep,
          child: OutlinedLabel(seatLabels(game.players)[seat],
              fontSize: size * 0.36, strokeWidth: size * 0.07),
        ),
      );

  void _nextDynastyRound(bool won) {
    final target = (targetPoints + (won ? 1 : 0) + game.pointsBonus)
        .clamp(1, maxTarget)
        .toInt();
    game.pointsBonus = 0;
    targetPoints = target;
    game.nextDynastyRound(playerCount, target);
    // The story may have grown or shrunk the court.
    playerCount = game.players.length;
    _resetTable();
    _lastMark = null;
    _step = _DynastyStep.result;
  }

  Widget _deathCard() {
    final seat = game.kingIndex;
    final name = game.solo
        ? 'King ${game.reignName}'
        : seat == null
            ? 'The King'
            : game.players[seat].name;
    final toughness = game.kingToughness;
    final last = game.fallenKings + 1 >= GameState.maxFallenKings;
    return _parchmentCard(
      color: Palette.traitorDeep,
      border: Palette.lost,
      children: [
        // The crown topples.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.bounceOut,
          builder: (context, t, child) => Transform.translate(
            offset: Offset(0, -30 * (1 - t)),
            child: Transform.rotate(angle: 0.6 * t, child: child),
          ),
          child: const CrownIcon(size: 46, color: Palette.goldDeep),
        ),
        const SizedBox(height: 8),
        const Text('The King is dead',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w900,
                fontSize: 30,
                color: Colors.white)),
        Text('$name ${game.epithet}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Palette.gold)),
        const SizedBox(height: 8),
        Text(
            'They could bear $toughness wound${toughness == 1 ? '' : 's'}. '
            'Reign ${roman(game.reign)} lasted ${game.reignRounds} '
            'round${game.reignRounds == 1 ? '' : 's'}.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.4, color: Colors.white70)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() {
            game.succession();
            if (last) {
              _step = _DynastyStep.ending;
            } else {
              _nextDynastyRound(false);
            }
          }),
          child: Text(last
              ? 'Close the annals'
              : game.solo
                  ? 'Your heir takes the crown'
                  : 'Crown an heir'),
        ),
      ],
    );
  }

  /// The end of the story: how the dynasty ended and the Kings who ruled.
  Widget _endingCard() {
    final ending = game.ending ?? DynastyEnding.fallen;
    final golden = ending == DynastyEnding.goldenAge;
    final king = game.kingIndex;
    final kings = [
      ...game.annals,
      if (king != null)
        Annal(game.solo ? 'King ${game.reignName}' : game.players[king].name,
            game.epithet, game.reignRounds, game.reign),
    ];
    final fg = golden && !_onFelt ? Palette.ink : Colors.white;
    return _parchmentCard(
      color: golden ? Palette.gold : Palette.traitorDeep,
      border: golden ? null : Palette.lost,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          curve: golden ? Curves.elasticOut : Curves.bounceOut,
          builder: (context, t, child) => golden
              ? Transform.scale(scale: 0.4 + 0.6 * t, child: child)
              : Transform.translate(
                  offset: Offset(0, -30 * (1 - t)),
                  child: Transform.rotate(angle: 0.6 * t, child: child)),
          child: CrownIcon(
              size: 52, color: golden ? Palette.ink : Palette.goldDeep),
        ),
        const SizedBox(height: 6),
        Text('The end of the dynasty',
            style: TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: golden ? Palette.inkSoft : Colors.white60)),
        Text(ending.title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w900,
                fontSize: 30,
                color: golden ? Palette.ink : Palette.lost)),
        const SizedBox(height: 8),
        Text(ending.story,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.4, color: fg)),
        const SizedBox(height: 14),
        Text('The annals',
            style: TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: golden ? Palette.ink : Palette.gold)),
        const SizedBox(height: 4),
        for (final a in kings)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
                '${roman(a.reign)}.  ${a.name} ${a.epithet}, '
                '${a.rounds} round${a.rounds == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: fg)),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _showSetupDialog(startMode: GameMode.dynasty),
          style: golden
              ? FilledButton.styleFrom(
                  backgroundColor: Palette.ink, foregroundColor: Palette.gold)
              : null,
          child: const Text('A new dynasty'),
        ),
      ],
    );
  }

  Widget _parchmentCard(
      {required Color color, Color? border, required List<Widget> children}) {
    if (_onFelt) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: border == null ? null : Border.all(color: border, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _buildOutcomeCard(bool won, Color fg) {
    if (game.isTutorial) return _buildLessonCard(won, fg);
    final chapter = game.mode == GameMode.chronicle ? game.chapter : null;
    final hasNext = chapter != null && chapter < chronicle.length - 1;
    return StatefulBuilder(
      builder: (context, setCardState) => OrnateCard(
      ornament: Ornament.medium,
        won: won,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.shrink(),
            const SizedBox(height: 6),
            if (chapter != null)
              Text('Chapter ${chapter + 1}: ${chronicle[chapter].title}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: won ? Palette.ink : Palette.gold)),
            Text(won ? 'Round won' : 'Round lost',
                style: TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    color: fg)),
            OrnateDivider(
                color: won ? Palette.goldInk : Palette.gold),
            Text(
              won
                  ? 'Every task is done. The court rejoices.'
                  : game.tasks.where((t) => t.isFailed).length > 1
                      ? 'These tasks failed:'
                      : 'This task failed:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: fg),
            ),
            // What went wrong: each failed task, whose it was, and why.
            if (!won)
              for (final t in game.tasks.where((t) => t.isFailed))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x55D9483B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SuitText(_cardText(t),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      SuitText(
                          [
                            if (t.assignedPlayerIndex != null)
                              t.assignedPlayerIndex == _you && _digital
                                  ? 'Your task.'
                                  : '${game.players[t.assignedPlayerIndex!].name}\u2019s task.',
                            _whyFailed[t] ?? 'Marked as failed.',
                          ].join(' '),
                          style: const TextStyle(
                              fontSize: 14.5, height: 1.3, color: Colors.white70)),
                    ],
                  ),
                ),
            if (chapter != null && won) ...[
              const SizedBox(height: 8),
              // Crowns earned: 3 first time, 2 within three attempts, else 1.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: CrownIcon(
                          size: 28,
                          color: i < _crownsEarned
                              ? Palette.ink
                              : const Color(0x33000000)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 2),
            if (chapter == null)
            Text(
                game.campaign
                    ? 'Win streak ${game.streak}, best ${game.bestStreak}'
                    : 'Won ${game.wins}, lost ${game.losses} so far',
                style: TextStyle(
                    fontSize: 15, color: won ? Palette.ink : Colors.white70)),
            const SizedBox(height: 16),
            if (chapter == null) ...[
            Row(
              children: [
                Text('Next round',
                    style: TextStyle(fontSize: 16, color: fg)),
                const Spacer(),
                Text('$_nextTarget',
                    style: TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: won ? Palette.ink : Palette.gold)),
                const SizedBox(width: 4),
                CrownIcon(size: 16, color: won ? Palette.ink : Palette.gold),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: won ? Palette.ink : Palette.gold,
                thumbColor: won ? Palette.ink : Palette.gold,
                inactiveTrackColor: won ? Colors.black26 : Colors.white24,
              ),
              child: Slider(
                value: _nextTarget.clamp(1, maxTarget).toDouble(),
                min: 1,
                max: maxTarget.toDouble(),
                divisions: maxTarget - 1,
                onChanged: (v) => setCardState(() => _nextTarget = v.round()),
              ),
            ),
            const SizedBox(height: 4),
            ],
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                if (chapter != null) ...[
                  OutlinedButton(
                    onPressed: () => _beginChapter(chapter),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: fg,
                        side: BorderSide(
                            color: won ? Palette.ink : Colors.white54)),
                    child: Text(won ? 'Replay chapter' : 'Try again'),
                  ),
                  if (won && hasNext)
                    FilledButton(
                      onPressed: () => _beginChapter(chapter + 1),
                      style: FilledButton.styleFrom(
                          backgroundColor: Palette.ink,
                          foregroundColor: Palette.gold),
                      child: const Text('Next chapter'),
                    ),
                ] else ...[
                OutlinedButton(
                  onPressed: _retryRound,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: fg,
                      side: BorderSide(
                          color: won ? Palette.ink : Colors.white54)),
                  child: const Text('Retry'),
                ),
                FilledButton(
                  onPressed: () {
                    targetPoints = _nextTarget;
                    _shuffleTasks();
                  },
                  style: won
                      ? FilledButton.styleFrom(
                          backgroundColor: Palette.ink,
                          foregroundColor: Palette.gold)
                      : null,
                  child: const Text('Deal'),
                ),
                ],
              ],
            ),
            if (_lastMark != null)
              TextButton(
                onPressed: _undoLastMark,
                style: TextButton.styleFrom(
                    foregroundColor: won ? Palette.ink : Colors.white70),
                child: const Text('Undo last mark'),
              ),
          ],
        ),
      ),
    );
  }

  /// Puts the last done/failed mark back, for a mis-tap that ended the
  /// round by mistake. The round's result is taken back off the record.
  void _undoLastMark() {
    final mark = _lastMark;
    if (mark == null) return;
    setState(() {
      final (task, previous) = mark;
      if (game.mode == GameMode.chronicle &&
          game.chapter != null &&
          game.outcome == RoundOutcome.won) {
        final c = game.chapter!;
        if (_crownsBefore == null) {
          _progress.crowns.remove(c);
        } else {
          _progress.crowns[c] = _crownsBefore!;
        }
        _saveSettings();
      }
      game.undoOutcome();
      task.status = previous;
      _lastMark = null;
    });
  }

  /// Continue on the welcome screen: the saved games, to pick one up.
  Future<void> _showContinue() async {
    try {
      // A save still waiting goes in first, so the list is up to date.
      if (_ctrl.savePending) await _ctrl.saveNow();
      final saves = await _readSaves(await SharedPreferences.getInstance());
      if (mounted) _ui(() => _saves = saves);
    } catch (_) {}
    if (!mounted) return;
    if (_saves.length == 1) {
      _continueSaved(_saves.first);
    } else if (_saves.isNotEmpty) {
      _showSetupDialog(continuing: true);
    }
  }

  /// The front of the table before a game: the four Court Cards fan out
  /// in a burst of sparks, then the name and one button, Play, which offers
  /// saved games, a new game and the tutorial.
  Widget _buildWelcome() {
    return LayoutBuilder(
      builder: (context, c) => Padding(
        padding: const EdgeInsets.all(24),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: math.max(0.0, clampD(c.maxWidth, 0, 640) - 48),
            child: _WelcomeIntro(
              crownSize: clampD(c.maxWidth * 0.42, 120, 270),
              buttons: [
                // Games in progress first: carry on where you left off.
                if (_saves.isNotEmpty)
                  FilledButton(
                    onPressed: _showContinue,
                    child: const Text('Continue'),
                  ),
                if (_saves.isEmpty)
                  FilledButton(
                      onPressed: () => _showSetupDialog(),
                      child: const Text('New game'))
                else
                  OutlinedButton(
                      onPressed: () => _showSetupDialog(),
                      child: const Text('New game')),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

enum _DynastyStep { result, dilemma, verdict, death, ending }

/// The soft shadow under words on the felt, as on the front page.
const _feltShadow = feltShadow;

/// Courtiers' powers and Dynasty are being reworked; until then they're
/// shown as coming soon.
const powersComingSoon = true;
const dynastyComingSoon = true;

/// The highest points target a round can have. The balance report shows
/// rounds above this are close to impossible.
const maxTarget = 20;
