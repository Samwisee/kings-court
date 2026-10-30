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
import '../platform/frame_stats.dart';
import '../platform/game_log.dart';
import '../platform/service.dart';
import '../platform/settings.dart';
import '../platform/sfx.dart';
import '../skin/skin.dart';
import '../skin/skin_scope.dart';
import '../skin/skins.dart';
import '../skin/strings.dart';
import '../skin/theme.dart';
import 'bug_report.dart';
import 'cards/card_view.dart';
import 'cards/task_chip.dart';
import 'controller.dart';
import 'dialogs/courtier_card.dart';
import 'dialogs/livery_page.dart';
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
import 'setup/setup_frame.dart';
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

part 'table_keys.dart';
part 'table_turns.dart';
part 'table_moves.dart';
part 'table_hand.dart';
part 'table_board.dart';
part 'table_play.dart';
part 'table_setup.dart';
part 'table_menu.dart';

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

  /// The page's address, in place of the one open (an invite link).
  static Uri? address;
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

  /// This crowning's crown starts as the walk-in's, waiting in the middle.
  bool _crownFromCentre = false;

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
    for (final c in [_table.deal, _crown, _play, _outcome, _outcomeHold, _walkIn.animation]) {
      c.value;
    }
    _loadSaved();
    FrameStats.start();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

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

  /// Each card in your hand, where it sits (at rest) within it.
  final Map<PlayingCard, Rect> _handRects = {};

  /// The card chosen in your hand with the arrow keys.
  PlayingCard? _kbCard;

  /// The space bar is down while the tracker is up: a tap or a hold?
  Timer? _spaceTimer;

  /// What tapping each card in your hand does, for the Enter key.
  final Map<PlayingCard, bool Function()> _handPlays = {};

  /// Saves after every change, so closing the app mid-round loses nothing.
  /// Skipped while a card is being dragged; saved again when it's dropped.
  ///
  /// A change to what's on screen only (a menu, a toast, a drag, the
  /// tracker, a key press): rebuilds without saving or waking the game.
  void _ui(VoidCallback fn) => super.setState(fn);

  /// [setState], for the parts of this page (table_*.dart) to call.
  void _set(VoidCallback fn) => setState(fn);

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

  /// Starts a Chronicle chapter directly, skipping the setup dialog.
  @visibleForTesting
  void debugStartChapter(int chapter, int players) => _startGame(
      players,
      0,
      [for (int i = 0; i < players; i++) 'Player ${i + 1}'],
      GameMode.chronicle,
      chapter: chapter);

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
    _walkIn.dispose();
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

  bool get _yourPick =>
      _digital &&
      !_choosingKing &&
      !_decreePending &&
      _table.dealtFor == game.dealId &&
      _round.pickTurn == _you &&
      !_othersDeciding;

  /// Lets whichever bot is due act, after a short pause.
  /// A card you chose early, played as soon as it's your turn.
  PlayingCard? _queued;

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
      !_round.ready.contains(_you) &&
      _mayAskToSpeak;

  /// Online, before the first pick: someone else at the table is still to
  /// say whether they'll show a card first, so nobody picks yet.
  bool get _othersDeciding => _openingPick && (_room?.deciding(_round, you: _you) ?? false);

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

  // ------------------------------------------------------------ online
  // A room (ui/online/room_play.dart): every device plays the room's moves
  // in its order; the host's device does the table's work.

  RoomPlay? _room;

  /// Multiplayer setup, while it's open in place of the New Game panel:
  /// the room an invite link opened it to join, or '' for none.
  String? _online;

  /// This device moves for the table: the courtiers, the crown, the deal.
  bool get _hostsTable => _room?.hosting ?? true;

  /// Whether a person plays [seat] (online; elsewhere only you).
  bool _personAt(int seat) => seat == _you || (_room?.personAt(seat) ?? false);

  /// The round as the table shows it (see game/judge.dart): a trick still
  /// on the table doesn't count yet.
  RoundView get _shownView => shownView(_round, trickPending: _lastTrick != null);

  /// Tricks [seat] has won, as the table shows them.
  int _shownTricksWon(int seat) => shownTricksWon(_round, seat, _lastTrick);

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

  static const _trackerSlide = Duration(milliseconds: 320);

  /// Your hand along the bottom, fanned to fit: cards you may play stand
  /// up, the rest dim. Tap one to play it.
  /// A small gold button in the hand's status line.
  /// How wide the hand's cards may spread on a wide screen.
  double _handLimit = double.infinity;

  /// The height the on-screen game has, table and hand together.
  double _gameHeight = 800;

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
  final _pileKeys = <int, GlobalKey>{};
  GlobalKey _pileKey(int seat) => _pileKeys.putIfAbsent(seat, GlobalKey.new);

  /// The middle of the table: the tasks to take while picking (tap one),
  /// then the trick.
  final _middleTasksKey = GlobalKey(debugLabel: 'middle tasks');

  /// Whether your tasks have been scrolled under your token.
  final _youScrolled = ValueNotifier(false);

  // ------------------------------------------- powers and reveals on screen

  /// Tap a card in your hand to show it with the speech token.
  bool _revealing = false;

  /// You asked to speak mid-trick: the game stops for you after it.
  bool _wantsToSpeak = false;

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

  /// What each courtier is calling out mid-hand.
  final Map<int, String> _quips = {};

  /// Records each round as it's over (platform/game_log.dart).
  final _rounds = RoundLogger();

  /// A short message shown in the hand's status line for a moment (on
  /// screen; a pop-up bar there would cover your cards).
  String? _toast;
  Timer? _toastTimer;

  /// From the menus into a game: the menu fades to the felt, the crown
  /// rises up in the middle in a burst of sparks, and as it lifts away the
  /// table is revealed beneath it.
  late final _walkIn = WalkIn(vsync: this, changed: () {
    if (mounted) setState(() {});
  });

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
    FrameStats.at = _inGame ? 'table' : 'menus';
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
    // The felt runs the whole screen, behind the bar too, on every page.
    Positioned.fill(child: FeltGround(quiet: !_inGame || _setupArgs != null)),
    Scaffold(
      backgroundColor: Colors.transparent,
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
                  toolbarHeight: 60, backgroundColor: Colors.transparent,
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
                      : FeltGround(
                          key: const ValueKey('setup'), quiet: true,
                          // In a game, a fresh felt over the table, so the
                          // setup reads.
                          clear: !_inGame,
                          child: Center(
                              child: SetupSwitch(online: _online != null, child: _online != null ? _buildOnlineSetup() : _buildSetupPanel())),
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
              animation: _walkIn.animation,
              waiting: _walkIn.waiting,
              handedOver: _walkIn.handedOver,
              keepCover: _walkIn.keepCover)),
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

}
