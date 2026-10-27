import 'dart:async';
import 'dart:math' as math;

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
    _HomePageState.botBudget = 30;
    CharacterToken.alive = false;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Where everything sits on the table for a given screen size. The phone
/// lies in the middle of the table, so seats are spread evenly around its
/// edge and turned to face the player sitting there.
class _TableGeometry {
  _TableGeometry(this.size, this.players, this.textOf,
      {double? fixedCardWidth, this.upright = false})
      : seatSize = clampD(math.min(size.width, size.height) * 0.13, 36, 64) {
    seatExtent = seatSize + 32; // token, with room for the crown
    rx = size.width / 2 - seatExtent / 2 - trimInset;
    ry = size.height / 2 - seatExtent / 2 - trimInset;
    cardWidth = fixedCardWidth ??
        // Bigger on a big screen, so the table is easy to read from a
        // distance.
        clampD(math.min(size.width, size.height) * 0.27, 92, 172);
  }

  final Size size;
  final int players;

  /// Laptop view: nothing turns to face its seat; everything reads the
  /// right way up for one screen.
  final bool upright;

  /// Seats and cards stay inside the brass inlay round the table edge.
  static const trimInset = 14.0;

  /// The part of the table inside the inlay.
  Rect get playArea => (Offset.zero & size).deflate(trimInset);

  /// The wording printed on each task's card, which decides its height.
  final String Function(Task) textOf;
  final double seatSize;
  late final double seatExtent;
  late final double rx;
  late final double ry;
  late double cardWidth;

  Offset get center => size.center(Offset.zero);
  double get cardHeight => TableCard.heightFor(cardWidth);

  static final _sizeCache = <String, Size>{};

  /// A task card's upright size: usual width, taller for long tasks.
  Size cardSize(Task t) {
    final text = textOf(t);
    final sealed = t.seal != null;
    return _sizeCache.putIfAbsent('$cardWidth|$sealed|$text',
        () => TableCard.sizeFor(text, cardWidth, sealed: sealed));
  }

  /// Seat 0 sits at the bottom edge (whoever is holding the phone); the
  /// rest follow clockwise at equal angles.
  double seatAngle(int i) => math.pi / 2 + i * 2 * math.pi / players;

  Offset seatCenter(int i) {
    final a = seatAngle(i);
    return center + Offset(rx * math.cos(a), ry * math.sin(a));
  }

  double _turn(int i) => seatAngle(i) - math.pi / 2;

  /// The seat's frame snapped to the nearest table edge. Cards are laid
  /// out in this frame (their "up" points into the table) even when the
  /// view is upright.
  double _frame(int i) =>
      (_turn(i) / (math.pi / 2)).roundToDouble() * (math.pi / 2);

  /// Rotation that turns a widget's bottom edge towards seat [i].
  double facing(int i) => upright ? 0 : _turn(i);

  /// [facing] snapped to the nearest table edge, so a player's cards are
  /// always square to them and easy to read.
  double cardFacing(int i) => upright ? 0 : _frame(i);

  /// Which table edge seat [i] faces: 0 bottom, 1 left, 2 top, 3 right.
  int edge(int i) =>
      upright ? 0 : ((_frame(i) / (math.pi / 2)).round() % 4 + 4) % 4;

  /// Screen size of [t] when owned by seat [i] (side seats turn it
  /// sideways).
  Size ownedCardSize(int i, Task t) {
    final s = cardSize(t);
    return edge(i).isOdd ? Size(s.height, s.width) : s;
  }

  /// Lays out every owned card so that no two cards overlap each other, a
  /// seat, or the table edge.
  ///
  /// Each card goes in the free spot nearest its owner: first in front of
  /// the seat, then beside it along the table edge, then further in. Spots
  /// are worked out in the owner's frame (their right, and "up" towards
  /// the middle), so every card sits square to the person who holds it.
  Map<Task, Offset> layoutOwned(List<Task> order,
      {List<Rect> obstacles = const []}) {
    // Keep clear of the loose cards too, unless that leaves no room.
    final first = _layoutOwned(order, obstacles);
    if (!first.crowded || obstacles.isEmpty) return first.spots;
    return _layoutOwned(order, const []).spots;
  }

  ({Map<Task, Offset> spots, bool crowded}) _layoutOwned(
      List<Task> order, List<Rect> obstacles) {
    var crowded = false;
    final table = playArea;
    final placed = <Rect>[
      // Cards still waiting to be taken: owned cards keep clear of them.
      ...obstacles,
      for (int i = 0; i < players; i++)
        // The whole seat: crown above the token, name below it. Seats can
        // be turned at any angle, so keep a square clear around them.
        Rect.fromCenter(
            center: seatCenter(i),
            width: seatSize + 34,
            height: seatSize + 34),
    ];
    const gap = 6.0;
    final result = <Task, Offset>{};
    // Whose card each placed rect is (null for seats and loose cards), so
    // a crowded stack may squeeze onto itself but never a neighbour's.
    final placedBy = <int?>[for (final _ in placed) null];

    for (int i = 0; i < players; i++) {
      final owned = order.where((t) => t.assignedPlayerIndex == i).toList();
      if (owned.isEmpty) continue;
      final a = _frame(i);
      final right = Offset(math.cos(a), math.sin(a));
      final up = Offset(math.sin(a), -math.cos(a));
      final seat = seatCenter(i);
      // Half the seat's footprint in the owner's frame: the token, plus
      // the crown above it.
      final tokenHalfW = seatSize / 2 + 8;
      final tokenHalfH = seatSize / 2 + 17;

      // Rows as tall as this seat's tallest card, so a stack of long tasks
      // still has room.
      final rowH = owned
          .map((t) => ownedCardSize(i, t).height)
          .fold<double>(cardHeight, math.max);
      // Candidate spots in the owner's frame, nearest first.
      final spots = <Offset>[];
      for (int row = 0; row < 6; row++) {
        for (int col = -4; col <= 4; col++) {
          final dx = col * (cardWidth + gap);
          final dy = row == 0
              ? 0.0
              : tokenHalfH + rowH / 2 + gap + (row - 1) * (rowH + gap);
          // The row level with the seat can't use the seat's own spot.
          if (row == 0 && col.abs() * (cardWidth + gap) < tokenHalfW + cardWidth / 2) {
            continue;
          }
          spots.add(Offset(dx, dy));
        }
      }
      spots.sort((p, q) => p.distance.compareTo(q.distance));

      for (final t in owned) {
        final size = ownedCardSize(i, t);
        Offset? chosen;
        Rect? chosenRect;
        for (final s in spots) {
          final p = seat + right * s.dx + up * s.dy;
          final rect = Rect.fromCenter(
              center: p, width: size.width, height: size.height);
          final onTable = table.contains(rect.topLeft) &&
              table.contains(rect.bottomRight - const Offset(1, 1));
          if (onTable && !placed.any((r) => r.deflate(1).overlaps(rect))) {
            chosen = p;
            chosenRect = rect;
            break;
          }
        }
        if (chosen == null) {
          crowded = true;
          // No clear spot: overlap this seat's own cards rather than a
          // neighbour's.
          for (final s in spots) {
            final p = seat + right * s.dx + up * s.dy;
            final rect = Rect.fromCenter(
                center: p, width: size.width, height: size.height);
            final onTable = table.contains(rect.topLeft) &&
                table.contains(rect.bottomRight - const Offset(1, 1));
            var clear = onTable;
            for (int k = 0; clear && k < placed.length; k++) {
              if (placedBy[k] != i && placed[k].deflate(1).overlaps(rect)) {
                clear = false;
              }
            }
            if (clear) {
              chosen = p;
              chosenRect = rect;
              break;
            }
          }
        }
        // Table completely full: fan this card over the seat's own last
        // card, so it never lands on a neighbour's.
        final mine = [
          for (int k = 0; k < placed.length; k++)
            if (placedBy[k] == i) placed[k]
        ];
        if (chosen == null && mine.isNotEmpty) {
          chosen = mine.last.center + right * 10 + up * 10;
        }
        chosen ??= clampToTable(seat + up * (tokenHalfH + cardHeight / 2));
        chosenRect ??= Rect.fromCenter(
            center: chosen, width: size.width, height: size.height);
        result[t] = chosen;
        placed.add(chosenRect);
        placedBy.add(i);
      }
    }
    return (spots: result, crowded: crowded);
  }

  /// Positions for freshly dealt cards: a neat grid in the open middle of
  /// the table, shrinking the cards if needed so they all fit. Each row is
  /// as tall as its tallest card.
  List<Offset> dealPositions(List<Task> tasks) {
    final count = tasks.length;
    final innerW = math.max(size.width - 2 * (seatExtent + 6), cardWidth);
    final innerH = math.max(size.height - 2 * (seatExtent + 6), cardHeight);
    const gap = 8.0;

    int cols = 1;
    List<double> rowHeights = [];
    while (true) {
      cols = math.max(1, ((innerW + gap) / (cardWidth + gap)).floor());
      rowHeights = [
        for (int r = 0; r * cols < count; r++)
          tasks
              .skip(r * cols)
              .take(cols)
              .map((t) => cardSize(t).height)
              .reduce(math.max),
      ];
      final gridH = rowHeights.fold(0.0, (a, h) => a + h) +
          gap * (rowHeights.length - 1);
      if (gridH <= innerH || cardWidth <= 72) break;
      cardWidth -= 4;
    }

    final gridH =
        rowHeights.fold(0.0, (a, h) => a + h) + gap * (rowHeights.length - 1);
    final result = <Offset>[];
    var top = center.dy - gridH / 2;
    for (int r = 0; r < rowHeights.length; r++) {
      final inRow = math.min(cols, count - r * cols);
      final rowW = inRow * (cardWidth + gap) - gap;
      for (int c = 0; c < inRow; c++) {
        result.add(Offset(
          center.dx - rowW / 2 + c * (cardWidth + gap) + cardWidth / 2,
          top + rowHeights[r] / 2,
        ));
      }
      top += rowHeights[r] + gap;
    }
    return result;
  }

  /// The seat closest to [p]: the side of the table someone is touching.
  int nearestSeat(Offset p) {
    var best = 0;
    for (int i = 1; i < players; i++) {
      if ((seatCenter(i) - p).distance < (seatCenter(best) - p).distance) {
        best = i;
      }
    }
    return best;
  }

  /// The seat a card centred at [p] is being dropped on, if any.
  int? seatAt(Offset p) {
    for (int i = 0; i < players; i++) {
      if ((seatCenter(i) - p).distance < seatSize / 2 + 34) return i;
    }
    return null;
  }

  /// Keeps a card on the table whichever way it is turned.
  Offset clampToTable(Offset p, [Size? card]) {
    final c = card ?? Size(cardWidth, cardHeight);
    final half = math.max(c.width, c.height) / 2;
    final area = playArea;
    return Offset(
      clampD(p.dx, area.left + half, area.right - half),
      clampD(p.dy, area.top + half, area.bottom - half),
    );
  }
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin {
  GameState game = GameState();
  int playerCount = 4;
  int targetPoints = 10;

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

  /// Seat being crowned while the crown animation plays.
  int? _crowning;

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
  static String _slotKey(GameMode mode) => 'kingsCourt.game.${mode.name}';
  static const _bestKey = 'kingsCourt.bestStreak';
  static const _chronicleKey = 'kingsCourt.chronicle';
  static const _soundKey = 'kingsCourt.sound';
  static const _uprightKey = 'kingsCourt.upright';
  static const _suitsKey = 'kingsCourt.fourColourSuits';

  /// Laptop view: everything upright instead of turned to each seat.
  bool _upright = false;

  /// The New Game panel, while it's open.
  _SetupArgs? _setupArgs;

  /// Chronicle progress on this device.
  ChronicleProgress _progress = ChronicleProgress();

  @override
  void initState() {
    super.initState();
    // Create the animation controllers now, so dispose never makes one.
    for (final c in [_deal, _crown, _play, _outcome]) {
      c.value;
    }
    _loadSaved();
  }

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

  Future<void> _save() async {
    // The tutorial is never saved, so it can't replace a game in progress.
    if (game.isTutorial) return;
    try {
      final data = {
        'game': game.toJson(),
        'playerCount': playerCount,
        'targetPoints': targetPoints,
        'cardWidth': _cardWidth,
        'dealt': _dealtFor == game.dealId,
        'pos': [
          for (final t in game.tasks)
            if (_pos[t] != null) [_pos[t]!.dx, _pos[t]!.dy] else null,
        ],
        'tilt': [for (final t in game.tasks) _tilt[t] ?? 0.0],
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_slotKey(game.mode), jsonEncode(data));
      final best = math.max(_bestStreak, game.bestStreak);
      if (best > (prefs.getInt(_bestKey) ?? 0)) await prefs.setInt(_bestKey, best);
    } catch (_) {
      // Saving is best-effort.
    }
  }

  /// Saves Chronicle progress and the sound setting.
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chronicleKey, jsonEncode(_progress.toJson()));
      await prefs.setBool(_soundKey, Sfx.enabled);
      await prefs.setBool(_uprightKey, _upright);
      await prefs.setBool(_suitsKey, Palette.fourColourSuits);
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
    _toastTimer?.cancel();
    _trackerTimer?.cancel();
    _deal.dispose();
    _crown.dispose();
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
      _tableSize, game.players.length, (t) => t.cardText(playerCount),
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

  bool get _yourPlay => _playing && _lastTrick == null && _cards.turn == _you;

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
    if (_revealing ||
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
        builder: (context, setDialog) => AlertDialog(
          backgroundColor: Palette.feltDeep,
          title: const Text('How many tricks?',
              style: TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 24)),
          content: Column(
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

  /// Plays a card. When it finishes a trick, the trick stays a moment,
  /// sweeps to the winner, and then the tasks are judged.
  void _playCard(int seat, PlayingCard card) {
    final trick = _cards.playCard(seat, card);
    if (trick == null) {
      setState(() {});
      return;
    }
    setState(() {
      _lastTrick = trick;
      _collecting = false;
    });
    // The tutorial holds each trick longer, so the coach can explain it.
    final pause = game.isTutorial ? trickPause * 3 : trickPause;
    _trickTimers.add(Timer(pause * 0.6, () {
      if (mounted) setState(() => _collecting = true);
    }));
    _trickTimers.add(Timer(pause, () {
      if (!mounted || !_digital) return;
      setState(() {
        _lastTrick = null;
        _collecting = false;
      });
      _judgeTasks();
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

  void _showCardTracker() {
    if (_trackerOpen) {
      _closeTracker();
      return;
    }
    _trackerTimer?.cancel();
    // First drawn just below the screen (the slow frame, if there is one),
    // and only then slid up, so the slide itself runs at full speed.
    setState(() {
      _trackerMounted = true;
      _trackerSliding = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _trackerSliding) setState(() => _trackerOpen = true);
      });
    });
  }

  void _closeTracker() {
    setState(() {
      _trackerOpen = false;
      _trackerSliding = true;
    });
    _trackerTimer?.cancel();
    _trackerTimer = Timer(_trackerSlide + const Duration(milliseconds: 40), () {
      if (mounted && !_trackerOpen) setState(() => _trackerSliding = false);
    });
  }

  static const _trackerSlide = Duration(milliseconds: 320);

  /// The cards [t] is about, and what's become of each this round.
  List<(PlayingCard, _CardFate)> _cardStates(Task t) {
    final cards = relevantCards(t.description);
    if (!_digital || _cards.dealId != game.dealId) {
      return [for (final c in cards) (c, _CardFate.unknown)];
    }
    final owner = t.assignedPlayerIndex;
    final wants = wantsToWin(t.description);
    final named = RegExp(r'[A2-9][♥♦♠♣]|Queen|Joker|Jack').hasMatch(t.description);
    _CardFate fate(PlayingCard c) {
      for (final trick in _cards.tricks) {
        if (!trick.cards.contains(c)) continue;
        if (owner == null) return _CardFate.played;
        if (trick.winner == owner) return wants ? _CardFate.good : _CardFate.bad;
        return wants && named ? _CardFate.bad : _CardFate.played;
      }
      if (_cards.current.contains(c)) return _CardFate.onTable;
      if (_cards.hands.length > _you && _cards.hands[_you].contains(c)) {
        return _CardFate.yours;
      }
      return _CardFate.unknown;
    }

    return [for (final c in cards) (c, fate(c))];
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
    final text = t.cardText(playerCount);
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
            ? "King's Command: tap a task to hand it out"
            : game.canPass(_you)
                ? 'Your pick: tap a task'
                : 'Your pick: tap a task to take it';
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
  Widget _barAction(String label, IconData icon, VoidCallback onPressed) =>
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: Palette.gold,
            side: const BorderSide(color: Palette.gold),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 40),
          ),
        ),
      );

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
          Row(
            children: [
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                      fontFamily: bodyFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: yourTurn || _yourPick || _revealing
                          ? Palette.gold
                          : Colors.white70),
                  child: Text(
                      _toast != null
                          ? _toast!
                          : _revealing
                          ? 'Tap a card to show it (highest, lowest or only of its suit)'
                          : _queued != null
                          ? 'You\u2019ll play the ${_queued!.label} on your turn (tap it again to change your mind)'
                          : _wantsToSpeak && _playing
                              ? 'You\u2019ll show a card after this trick'
                              : _cardStatus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ),
              ),
              // The action of the moment, beside what's happening: save
              // your card for later, or pass on picking.
              if (_speakPromptDue)
                _GlowButton(label: 'Skip', onPressed: _startChoosing)
              else if (game.canPass(_you))
                _barAction('Pass', Icons.redo_rounded,
                    () => setState(() => game.pass(_you))),
              // Every card: which are played, which are still to come.
              if (_cards.dealId == game.dealId && !_storyActive)
                IconButton(
                  tooltip: 'Cards played and still to come',
                  onPressed: _showCardTracker,
                  icon: const Icon(Icons.grid_view_rounded, color: Palette.gold),
                ),

              // The speech token: show one card, once a round.
              SizedBox(
                width: 44,
                child: IconButton(
                  tooltip: 'Show a card (once a round)',
                  onPressed: _mayAskToSpeak || _revealing ? _speak : null,
                  icon: Icon(
                      _revealing
                          ? Icons.close_rounded
                          : game.spoke.length > _you && game.spoke[_you]
                              ? Icons.voice_over_off
                              : Icons.record_voice_over,
                      color: _wantsToSpeak
                          ? Colors.white
                          : _mayAskToSpeak || _revealing
                              ? Palette.gold
                              : Colors.white24),
                ),
              ),
            ],
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
                      final top = legal.contains(card) || _queued == card
                          ? 0.0
                          : 12.0;
                      void play() {
                        if (_revealing || _speakPromptDue) {
                          if (_cards.revealFor(_you, card) == null) {
                            _showSnack(
                                'Only your highest, lowest or only card of a suit can be shown, never a Court Card',
                                Palette.feltDeep);
                            return;
                          }
                          final opening = _speakPromptDue;
                          _reveal(_you, card);
                          if (opening) _startChoosing();
                          return;
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
                            return;
                          }
                          setState(() => _queued = _queued == card ? null : card);
                          return;
                        }
                        if (!_yourPlay) return;
                        if (!legal.contains(card)) {
                          final led = c.led!;
                          _showSnack(
                              led.isCourt
                                  ? 'You must follow with a Court Card'
                                  : 'You must follow ${led.suit.name}',
                              Palette.feltDeep);
                          return;
                        }
                        final area = _rectOn(_handKey);
                        if (area != null) {
                          _launchFrom[card.id] = area.topLeft +
                              Offset(left + cardW / 2, top + h / 2) +
                              (dragging ? _handDrag : Offset.zero);
                        }
                        _playCard(_you, card);
                      }

                      return AnimatedPositioned(
                        key: ValueKey(card.id),
                        duration: dragging
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        left: left + (dragging ? _handDrag.dx : 0),
                        top: top + (dragging ? _handDrag.dy : 0),
                        child: GestureDetector(
                          onTap: play,
                          // Or drag it up onto the table.
                          onPanStart: (_) => setState(() {
                            _handDragCard = card.id;
                            _handDrag = Offset.zero;
                          }),
                          onPanUpdate: (d) =>
                              setState(() => _handDrag += d.delta),
                          onPanEnd: (_) {
                            final far = _handDrag.dy < -h * 0.6;
                            if (far) play();
                            setState(() {
                              _handDragCard = null;
                              _handDrag = Offset.zero;
                            });
                          },
                          onPanCancel: () => setState(() {
                            _handDragCard = null;
                            _handDrag = Offset.zero;
                          }),
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
                              child: PlayingCardView(
                                card: card,
                                width: cardW,
                                dimmed: yourTurn && !legal.contains(card),
                                glow: (yourTurn && card == _tutorialHint) ||
                                    _queued == card,
                                marks: _marksFor(card),
                              ),
                            ),
                          ),
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
  Offset _handDrag = Offset.zero;

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
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
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
        onTap: game.hasRoles && !_choosingKing ? () => _showCourtier(seat) : null,
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
  Widget _digiCrowning() {
    final king = _crowning!;
    final middle = _rectOn(_middleKey);
    final seat = _rectOn(_seatKey(king));
    if (middle == null || seat == null) return const SizedBox.shrink();
    return _crowningScene(
      from: middle.center,
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
    for (final r in _lastRoles) {
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
                            fontSize: 13, color: Colors.white70)),
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
                    child: Center(
                      child: SpeechBubble(_quips[seat]!,
                          key: ValueKey('quip-$seat-${_quips[seat]}'),
                          tailAbove: true),
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
    if (r == null) return token;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        token,
        // Level with the token (below its crown slot), as tall as it.
        Positioned(right: -(size / 1.3 + 8), top: 14, child: r),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniCard(card: card, width: height / 1.3),
        Text(c.revealHint[seat] ?? '',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Palette.gold)),
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
    // shuffled as a pile in the middle and dealt out to those places.
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
    const shuffleMs = 1000;
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
                    onTap: () => _yourPick
                        ? _takeTask(t)
                        : _showTaskDetail(t, Offset.zero),
                    onLongPress: () => _showTaskDetail(t, Offset.zero),
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
            // Halves of the pile alternate, so the riffle interleaves.
            final side = i.isEven ? -1.0 : 1.0;
            final startMs = shuffleMs + i * 120;
            final total = startMs + 620;
            return TweenAnimationBuilder<double>(
              key: ValueKey('deal-${game.dealId}-${t.description}'),
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: total),
              builder: (context, raw, child) {
                final ms = raw * total;
                // The shuffle: the pile splits into two halves that swing
                // apart and riffle back together, twice.
                final p = clampD(ms / shuffleMs, 0, 1);
                final apart = ms < shuffleMs
                    ? math.sin(p * math.pi * 2).abs() * (1 - p * 0.3)
                    : 0.0;
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
      builder: (context) => SimpleDialog(
        backgroundColor: Palette.feltDeep,
        title: const Text("King's Command: who takes it?"),
        children: [
          for (final s in seats)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Text(game.players[s].name, style: const TextStyle(fontSize: 17)),
            ),
        ],
      ),
    );
    if (seat != null && mounted && t.assignedPlayerIndex == null) {
      _assignTask(t, seat);
    }
  }

  /// You, with your tasks beside you.
  Widget _digiYou(double width) {
    final mine = [
      for (final t in game.tasks)
        if (t.assignedPlayerIndex == _you) t
    ];
    final c = _cards;
    return Row(
      children: [
        Column(
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
        // A place kept for the card you show, as tall as your token, so it
        // never covers your tasks.
        SizedBox(
          width: 40 / 1.3 + 12,
          child: Center(child: _revealedView(_you, height: 40)),
        ),
        Expanded(
          child: _storyActive
              ? const SizedBox.shrink()
              : mine.isEmpty
              ? Text(
                  game.pickTurn != null ? 'Your tasks will appear here' : 'No tasks for you this round',
                  style: const TextStyle(color: Colors.white54))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
      ],
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
  void _reveal(int seat, PlayingCard card) {
    final hint = _cards.revealFor(seat, card);
    if (hint == null) return;
    setState(() {
      _cards.revealed[seat] = card;
      _cards.revealHint[seat] = hint;
      if (!game.spoke[seat]) game.toggleSpoke(seat);
      if (seat == _you) _revealing = false;
    });
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
          builder: (context) => SimpleDialog(
            backgroundColor: Palette.feltDeep,
            title: Text(title),
            children: [
              for (final (value, label) in options)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, value),
                  child: SuitText(label,
                      style: const TextStyle(fontSize: 16, color: Colors.white)),
                ),
            ],
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
          builder: (context) => AlertDialog(
            backgroundColor: Palette.feltDeep,
            title: const Text('Whisper'),
            content: SuitText(
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
      builder: (context) => AlertDialog(
        backgroundColor: Palette.feltDeep,
        title: const Text('Absolution?'),
        content: SuitText(
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

  /// The tutorial: its opening pages (the story, the goal, tricks and
  /// tasks), then the first lesson.
  Future<void> _startTutorial() async {
    final go = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const TutorialIntro()));
    if (go == true && mounted) _beginLesson(0);
  }

  /// Starts tutorial lesson [i] (see tutorial.dart): three seats, you as
  /// King, cards on screen.
  void _beginLesson(int i) {
    setState(() => _setupArgs = null);
    _startGame(3, 1, tutorialCourtiers, GameMode.tutorial,
        roles: true, digital: true, lesson: i);
  }

  void _nextLesson() {
    if (game.lesson >= lessons.length - 1) {
      _finishTutorial();
      return;
    }
    setState(() => game.lesson++);
    _shuffleTasks();
  }

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
      builder: (context) => AlertDialog(
        backgroundColor: Palette.feltDeep,
        surfaceTintColor: Colors.transparent,
        title: const Row(children: [
          CrownIcon(size: 26),
          SizedBox(width: 10),
          Flexible(
            child: Text('You’re ready',
                style: TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 24)),
          ),
        ]),
        content: const Text(
            'That’s the heart of King’s Court. Real rounds have more tasks, and some bring seals and royal decrees: How to Play in the menu explains them all.\n\nFree play is a good place to start. Dynasty tells a story of kings.',
            style: TextStyle(fontSize: 16, height: 1.4, color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Play a game')),
        ],
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
              decoration: BoxDecoration(
                color: Palette.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Palette.gold, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black38, blurRadius: 10, offset: Offset(0, 3))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const CrownIcon(size: 14, color: Palette.goldDeep),
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
                              color: Palette.goldDeep)),
                    ),
                    TextButton(
                      onPressed: _finishTutorial,
                      style: TextButton.styleFrom(
                          foregroundColor: Palette.goldDeep,
                          visualDensity: VisualDensity.compact),
                      child: const Text('Skip tutorial'),
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
                                fontSize: 15.5, height: 1.35, color: Palette.ink)),
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
      _showSnack('Silence: no card reveals this round', Palette.feltDeep);
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
    setState(() => _crowning = index);
    Sfx.fanfare();
    _crown.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _haptic(HapticFeedback.heavyImpact);
      setState(() {
        game.setKing(index);
        _crowning = null;
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
    setState(() {
      _dragging = t;
      _order
        ..remove(t)
        ..add(t);
    });
  }

  void _onDragUpdate(Task t, Offset delta) {
    setState(() {
      final geo = _geo;
      final p = geo.clampToTable(_toPx(_pos[t]!) + delta, geo.cardSize(t));
      _pos[t] = _toFrac(p);
      final seat = _geo.seatAt(p);
      _hoverSeat = seat != null && game.canTake(t, seat) ? seat : null;
    });
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
        _outcome.forward(from: 0);
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
      setState(() => _toast = text);
      _toastTimer = Timer(const Duration(milliseconds: 2600), () {
        if (mounted && _toast == text) setState(() => _toast = null);
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
              backgroundColor: Palette.card,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
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
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
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
                                Switch(
                                  value: spoke,
                                  activeThumbColor: Palette.ink,
                                  onChanged: !canSpeak
                                      ? null
                                      : (_) {
                                          _haptic(
                                              HapticFeedback.selectionClick);
                                          update(() => game.toggleSpoke(seat));
                                        },
                                ),
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
        backgroundColor: const Color(0xFF2A0810),
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
          backgroundColor: Palette.card,
          surfaceTintColor: Colors.transparent,
          title: const Text('A seal is broken',
              style: TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: Palette.ink)),
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
        backgroundColor: Palette.card,
        surfaceTintColor: Colors.transparent,
        scrollable: true,
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(children: [
                    Text('${_points(task)}',
                        style: const TextStyle(
                            fontFamily: displayFont,
                            fontWeight: FontWeight.w900,
                            fontSize: 36,
                            height: 1,
                            color: Palette.ink)),
                    const SizedBox(height: 4),
                    const CrownIcon(size: 18, color: Palette.goldDeep),
                  ]),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SuitText(task.cardText(playerCount),
                        struck: _wonNamed(task),
                        style: const TextStyle(
                            fontSize: 21,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: Palette.ink)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                owner == null
                    ? 'Not taken yet. Drag the card onto a seat to give it to a player.'
                    : _digital && task.assignedPlayerIndex == _you
                        ? 'Your task.'
                        : game.hasRoles
                            ? '${game.courtiers[task.assignedPlayerIndex!].title}\u2019s task.'
                            : '${owner.name} has this task.',
                style: const TextStyle(fontSize: 15, color: Palette.inkSoft),
              ),
              // How it's going, for every task, once the cards are dealt.
              if (_statusOf(task) case final status?)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3ECDD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2D6BC)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1, right: 8),
                        child: Icon(
                            task.isCompleted
                                ? Icons.check_circle_rounded
                                : task.isFailed
                                    ? Icons.cancel_rounded
                                    : Icons.timelapse_rounded,
                            size: 18,
                            color: task.isCompleted
                                ? Palette.won
                                : task.isFailed
                                    ? Palette.lost
                                    : Palette.goldDeep),
                      ),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: SuitText(status,
                              style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                  color: Palette.ink)),
                        ),
                      ),
                    ],
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
                notes: [
                  ...task.notes,
                  if (task.kingCantTake) "The King can't take this task.",
                ],
              ),
              if (task.seal != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: WaxSeal(seal: task.seal!, size: 18),
                      ),
                      Expanded(
                        child: Text(Seals.describe(task.seal!),
                            style: const TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                color: Palette.ink)),
                      ),
                    ],
                  ),
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
  Future<void> _showSetupDialog({GameMode? startMode, int? startChapter}) async {
    setState(() => _setupArgs = (mode: startMode, chapter: startChapter));
  }

  void _closeSetup() => setState(() => _setupArgs = null);

  void _startFromSetup(_SetupResult r) {
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
      // On-screen cards unless the game being replaced used a real deck.
      digital: _inGame ? game.digital : true,
    );
  }

  /// Changes the points target mid-game. Players and the King stay; the
  /// tasks are re-dealt to match the new target.
  Future<void> _showPointsDialog() async {
    int target = targetPoints;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Palette.feltDeep,
          surfaceTintColor: Colors.transparent,
          title: const Text('Points target',
              style: TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 26)),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$target points',
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 40,
                        color: Palette.gold)),
                Slider(
                  value: target.clamp(1, maxTarget).toDouble(),
                  min: 1,
                  max: maxTarget.toDouble(),
                  divisions: maxTarget - 1,
                  onChanged: (v) => setDialogState(() => target = v.round()),
                ),
                const Text(
                    'The tasks are re-dealt to add up to the new target. Players and the King stay the same.',
                    style: TextStyle(color: Colors.white70, height: 1.35)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Re-deal tasks')),
          ],
        ),
      ),
    );
    if (apply != true) return;
    targetPoints = target;
    _shuffleTasks();
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
    final useTopBar = _setupArgs != null ||
        _inGame &&
            _digital &&
            screen.width - math.max(480.0, screen.height) >= 560;
    return Stack(children: [
    Scaffold(
      extendBodyBehindAppBar: useTopBar,
      appBar: _inGame && _setupArgs == null
          ? _buildAppBar()
          : AppBar(actions: [_buildMenu(), const SizedBox(width: 4)]),
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
            if (_setupArgs != null)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, t, child) =>
                      Opacity(opacity: t, child: child),
                  child: ColoredBox(
                    // In a game, wash the table out so the setup reads.
                    color: _inGame ? Palette.felt : Colors.transparent,
                    child: Center(child: _buildSetupPanel()),
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
          _lastTrick == null)
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
      // The brass inlay runs round the whole screen, the top bar included,
      // so it sits the same distance from every edge.
      const Positioned.fill(
          child: IgnorePointer(child: SafeArea(child: TableTrim()))),
      // While the tracker is up, a tap anywhere else on the table puts it
      // away.
      if (_trackerOpen)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeTracker,
          ),
        ),
      // The card tracker, docked over the lower half, above the inlay. It
      // slides up and down; it's only built while it's showing.
      if (_trackerMounted &&
          _inGame &&
          _setupArgs == null &&
          _digital &&
          _cards.dealId == game.dealId)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: Offstage(
            offstage: !_trackerOpen && !_trackerSliding,
            child: AnimatedSlide(
            offset: _trackerOpen ? Offset.zero : const Offset(0, 1.05),
            duration: _trackerSlide,
            curve: Curves.easeInOutCubic,
            child: RepaintBoundary(
              // No shadow or rounded clipping: both are slow to draw on
              // the web on every frame of the slide.
              child: Material(
                color: Palette.feltDeep,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(children: [
                  Positioned.fill(
                    child: SafeArea(
                      top: false,
                      child: _CardTracker(
                        cards: _cards,
                        you: _you,
                        players: game.players,
                        onClose: _closeTracker,
                      ),
                    ),
                  ),
                  // Its own brass inlay, like the table's, down the sides and
                  // across the top (it runs on past the bottom edge).
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: -40,
                    child: IgnorePointer(child: TableTrim()),
                  ),
                ]),
              ),
            ),
          ),
          ),
        ),
    ]);
  }

  /// The menu on the right: the rules, the Chronicle and sound.
  /// One line of the menu: a gold icon and a regal title.
  /// A menu entry; [on] adds a tick box for a setting.
  PopupMenuItem<String> _menuItem(String value, IconData icon, String title,
          {bool? on}) =>
      PopupMenuItem(
        value: value,
        height: 52,
        child: Semantics(
          toggled: on,
          child: Row(
            children: [
              Icon(icon, color: Palette.gold, size: 22),
              const SizedBox(width: 14),
              Flexible(
                child: Text(title,
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.3,
                        color: Color(0xFFF3E7C6))),
              ),
              if (on != null) ...[
                const SizedBox(width: 10),
                Icon(
                    on
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: Palette.gold,
                    size: 22),
              ],
            ],
          ),
        ),
      );

  Widget _buildMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      icon: const Icon(Icons.menu_rounded, color: Palette.gold, size: 30),
      color: Palette.feltDeep,
      elevation: 12,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Palette.gold, width: 1.5),
      ),
      onSelected: (choice) async {
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
      },
      itemBuilder: (context) => [
        // A crest at the top of the menu.
        const PopupMenuItem<String>(
          enabled: false,
          height: 40,
          child: Center(child: CrownIcon(size: 26, color: Palette.gold)),
        ),
        if ((_inGame || _saves.isNotEmpty) && _setupArgs == null)
          _menuItem('new', Icons.group_add_outlined, 'New game'),
        if (_inGame &&
            _setupArgs == null &&
            !(game.isDynasty && game.outcome != RoundOutcome.inProgress))
          _menuItem('shuffle', Icons.style_outlined, 'Shuffle tasks'),
        _menuItem('rules', Icons.menu_book_outlined, 'How to Play'),
        if (_inGame && game.currentTiding != null)
          _menuItem('tidings', Icons.history_edu_outlined, 'This round\u2019s tidings'),
        _menuItem(
            'upright',
            _upright ? Icons.laptop_rounded : Icons.table_restaurant_outlined,
            _upright ? 'Laptop view' : 'Table view'),
        _menuItem(
            'sound',
            Sfx.enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            Sfx.enabled ? 'Fanfares on' : 'Fanfares off'),
        // For colour-blind players: no two suits share a colour.
        _menuItem('suits', Icons.palette_outlined, 'Four-colour suits',
            on: Palette.fourColourSuits),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 46,
      titleSpacing: 22,
      backgroundColor: Colors.transparent,
      title: Padding(
        padding: const EdgeInsets.only(top: 2),
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
                  color: Palette.gold)),
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
                        color: const Color(0xFF2A0810),
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
        Tooltip(
          message: 'Points target',
          child: TextButton(
            onPressed: _showPointsDialog,
            style: TextButton.styleFrom(foregroundColor: Palette.gold),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$targetPoints',
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        height: 1,
                        color: Palette.gold)),
                const SizedBox(width: 4),
                const CrownIcon(size: 18, color: Palette.gold),
              ],
            ),
          ),
        ),
        _buildMenu(),
        const SizedBox(width: 4),
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
                  : (d) => setState(
                      () => _readerSeat = geo.nearestSeat(d.localPosition)),
              onLongPressEnd: (_) => setState(() => _readerSeat = null),
              onLongPressCancel: () => setState(() => _readerSeat = null),
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
        final lift = math.sin(fly * math.pi) * 70;
        final p = Offset.lerp(from, to, fly)! - Offset(0, lift);
        final size = t < 0.6
            ? 30 + 40 * math.sin(fly * math.pi) // swells mid-air
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
            color: const Color(0xFFF6EBD2),
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
              () {
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
                      child: GestureDetector(
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
                      ),
                    ),
                  ),
                );
              }(),
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
          final shake = t > 0.4 && t < 0.75
              ? math.sin((t - 0.4) * 60) * 10 * (0.75 - t) / 0.35
              : 0.0;
          card = Opacity(
            opacity: appear,
            child: Transform.translate(
              offset: Offset(shake, -80 * (1 - drop)),
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
      color: const Color(0xFFF6EBD2),
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
      color: const Color(0xFF14060A),
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
      color: golden ? Palette.gold : const Color(0xFF14060A),
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
                color: won ? const Color(0xFF6E4E0E) : Palette.gold),
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

  /// Play on the welcome screen: carry on with a saved game, start a new
  /// one, or learn with the tutorial.
  Future<void> _showPlayMenu() async {
    try {
      final saves = await _readSaves(await SharedPreferences.getInstance());
      if (mounted) setState(() => _saves = saves);
    } catch (_) {}
    if (!mounted) return;
    final choice = await showDialog<Object>(
      context: context,
      builder: (context) => _PlayMenu(saves: _saves),
    );
    if (!mounted || choice == null) return;
    if (choice is _SavedGame) {
      _continueSaved(choice);
    } else if (choice == 'new') {
      _showSetupDialog();
    } else if (choice == 'tutorial') {
      _startTutorial();
    }
  }

  /// The front of the table before a game: a hand of cards fans out, the
  /// crown drops onto it in a burst of sparks, then the name and one
  /// button, Play, which offers saved games, a new game and the tutorial.
  Widget _buildWelcome() {
    return LayoutBuilder(
      builder: (context, c) => Padding(
        padding: const EdgeInsets.all(24),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: math.max(0.0, clampD(c.maxWidth, 0, 520) - 48),
            child: _WelcomeIntro(
              crownSize: clampD(c.maxWidth * 0.42, 120, 200),
              button: SizedBox(
                width: 240,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                        onPressed: _showPlayMenu,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}

/// The opening flourish on the front page. It plays once (about two and a
/// half seconds) and then holds still.
class _WelcomeIntro extends StatelessWidget {
  const _WelcomeIntro({required this.crownSize, required this.button});
  final double crownSize;
  final Widget button;

  /// The four Court Cards, lowest to highest.
  static const _cards = [
    PlayingCard.joker,
    PlayingCard.jack,
    PlayingCard.queen,
    PlayingCard.king,
  ];

  static double _iv(double t, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0).toDouble());

  @override
  Widget build(BuildContext context) {
    final cardW = crownSize * 0.4;
    final cardH = PlayingCardView.heightFor(cardW);
    // The crown sits above the hand, its band just touching the cards.
    final handTop = crownSize * 0.8;
    final stageH = handTop + cardH + 8;
    // With reduced motion asked for, the flourish is skipped.
    final still = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 2600),
      builder: (context, t, _) {
        final fan = _iv(t, 0.05, 0.4, Curves.easeOutBack);
        final rise = _iv(t, 0.0, 0.25, Curves.easeOutCubic);
        final drop = _iv(t, 0.3, 0.62, Curves.bounceOut);
        final crownIn = _iv(t, 0.3, 0.4);
        final spark = _iv(t, 0.5, 0.85);
        final title = _iv(t, 0.6, 0.8, Curves.easeOutCubic);
        final sub = _iv(t, 0.7, 0.88, Curves.easeOutCubic);
        final btn = _iv(t, 0.8, 1.0, Curves.easeOutCubic);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: crownSize * 2,
              height: stageH,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // The hand, fanning out behind the crown.
                  for (int i = 0; i < _cards.length; i++)
                    Positioned(
                      left: crownSize - cardW / 2,
                      top: handTop + (1 - rise) * 40,
                      child: Opacity(
                        opacity: rise,
                        child: Transform.rotate(
                          // Fanned from a point below the hand, like cards
                          // held in a hand.
                          angle: (i - (_cards.length - 1) / 2) * 0.24 * fan,
                          alignment: const Alignment(0, 2.6),
                          child: PlayingCardView(card: _cards[i], width: cardW),
                        ),
                      ),
                    ),
                  // Sparks where the crown lands.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: spark > 0 && spark < 1
                            ? _IntroSparks(
                                origin: Offset(crownSize, handTop),
                                progress: spark,
                                scale: crownSize / 120)
                            : null,
                      ),
                    ),
                  ),
                  // The crown, dropping onto the hand.
                  Positioned(
                    left: crownSize / 2,
                    top: handTop - crownSize * 0.75 - 6 - (1 - drop) * stageH,
                    child: Opacity(
                      opacity: crownIn,
                      child: CrownIcon(size: crownSize, color: Palette.gold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: title,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - title)),
                child: const Text("The King's Court",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 44,
                        height: 1.05,
                        color: Palette.gold,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 12)
                        ])),
              ),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: sub,
              child: const Text(
                  'A cooperative trick-taking game for 2 to 6 players. Inspired by The Crew.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.white70)),
            ),
            const SizedBox(height: 32),
            IgnorePointer(
              ignoring: btn < 0.5,
              child: Opacity(
                opacity: btn,
                child: Transform.scale(scale: 0.9 + 0.1 * btn, child: button),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A ring of gold and white sparks, sized to the crown.
class _IntroSparks extends CustomPainter {
  _IntroSparks(
      {required this.origin, required this.progress, required this.scale});
  final Offset origin;
  final double progress;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0).toDouble();
    for (int k = 0; k < 18; k++) {
      final a = k * 2 * math.pi / 18 + 0.2;
      final r = (30 + 70 * ease * (k.isEven ? 1 : 0.65)) * scale;
      final p = origin + Offset(math.cos(a), math.sin(a)) * r;
      final color = (k.isEven ? Palette.gold : Colors.white).withValues(alpha: fade);
      canvas.drawCircle(p, (k.isEven ? 3.2 : 2.2) * scale, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_IntroSparks old) => old.progress != progress;
}

/// The rules, available from the welcome screen and during a game.
/// Chooses a Chronicle chapter in the setup dialog: any chapter up to the
/// first one not yet beaten.
class _ChapterPicker extends StatelessWidget {
  const _ChapterPicker(
      {required this.progress, required this.chapter, required this.onChanged});
  final ChronicleProgress progress;
  final int chapter;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = chronicle[chapter];
    final crowns = progress.crowns[chapter] ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.feltLine),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous chapter',
            onPressed: chapter > 0 ? () => onChanged(chapter - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text('Chapter ${chapter + 1}',
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Palette.gold)),
                Text(c.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 20)),
                const SizedBox(height: 4),
                Text(chapterSummary(c),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                CrownRating(crowns: crowns, size: 16),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next chapter',
            onPressed: chapter < chronicle.length - 1 &&
                    progress.isUnlocked(chapter + 1)
                ? () => onChanged(chapter + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// "6 points, 2 seals, decree: Silence"
String chapterSummary(Chapter c) => [
      '${c.points} points',
      if (c.seals > 0) '${c.seals} seal${c.seals == 1 ? '' : 's'}',
      if (c.decree != null) 'decree: ${c.decree!.title}',
    ].join(', ');

/// Three crowns, gold for each one earned.
class CrownRating extends StatelessWidget {
  const CrownRating({super.key, required this.crowns, this.size = 16});
  final int crowns;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: CrownIcon(
                size: size,
                color: i < crowns ? Palette.gold : const Color(0x44FFFFFF)),
          ),
      ],
    );
  }
}

/// The Chronicle: every chapter, its crowns, and which are still locked.
/// Returns the chapter the players chose to begin, if any.
Future<int?> showChronicleDialog(
    BuildContext context, ChronicleProgress progress) {
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Palette.feltDeep,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          const Expanded(
            child: Text('The Chronicle',
                style: TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: Palette.gold)),
          ),
          const CrownIcon(size: 16),
          const SizedBox(width: 4),
          Text('${progress.totalCrowns}/${chronicle.length * 3}',
              style: const TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Palette.gold)),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 460,
        child: ListView.separated(
          itemCount: chronicle.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Palette.feltLine),
          itemBuilder: (context, i) {
            final c = chronicle[i];
            final unlocked = progress.isUnlocked(i);
            return ListTile(
              enabled: unlocked,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: SizedBox(
                width: 34,
                child: Text('${i + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: unlocked ? Palette.gold : Colors.white24)),
              ),
              title: Text(c.title,
                  style: const TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              subtitle: Text(chapterSummary(c),
                  style: const TextStyle(color: Colors.white60)),
              trailing: unlocked
                  ? CrownRating(crowns: progress.crowns[i] ?? 0, size: 13)
                  : const Icon(Icons.lock_outline, color: Colors.white24),
              onTap: unlocked ? () => Navigator.pop(context, i) : null,
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    ),
  );
}

/// What the New Game panel starts with.
typedef _SetupArgs = ({GameMode? mode, int? chapter});

/// The settings a New Game panel hands back.
/// Dynasty doesn't ask for points: the story sets them, starting here
/// and growing with each win.
const dynastyStartingPoints = 5;

typedef _SetupResult = ({
  int count,
  int target,
  List<String> names,
  GameMode mode,
  bool surprise,
  bool roles,
  bool digital,
  int? chapter,
});

/// New game setup, laid straight onto the felt one step at a time: how to
/// play, how many players, who they are, then the points (or chapter, or
/// the start of the story). Each step fades in as the last fades away, so
/// the table never needs to scroll.
class _SetupPanel extends StatefulWidget {
  const _SetupPanel({
    required this.players,
    required this.playerCount,
    required this.targetPoints,
    required this.mode,
    required this.surprise,
    required this.roles,
    required this.chapter,
    required this.progress,
    required this.canCancel,
    required this.onCancel,
    required this.onStart,
    required this.digital,
  });

  final List<Player> players;
  final int playerCount;
  final int targetPoints;
  final GameMode mode;
  final bool surprise;
  final bool roles;
  final int chapter;
  final ChronicleProgress progress;
  final bool canCancel;
  final VoidCallback onCancel;
  final ValueChanged<_SetupResult> onStart;

  /// Start with on-screen cards switched on.
  final bool digital;

  @override
  State<_SetupPanel> createState() => _SetupPanelState();
}

/// What each way to play is about, shown on the first step.
const _modeInfo = {
  GameMode.free: (
    'Free play',
    'Choose a points target; add surprise seals and decrees if you like.'
  ),
  GameMode.endless: (
    'Endless',
    'Each win adds a point to the next round. How long can your streak last?'
  ),
  GameMode.chronicle: (
    'The Chronicle',
    '24 chapters of rising difficulty. Earn up to three crowns for each.'
  ),
  GameMode.dynasty: (
    'Dynasty',
    'A story of kings. Rule until wounds bring you down; face dilemmas, keep your courtiers loyal, watch for traitors.'
  ),
  GameMode.tutorial: (
    'Tutorial',
    'New to the court? Four short, guided rounds teach you to lead, follow, use Court Cards and help each other.'
  ),
};

class _SetupPanelState extends State<_SetupPanel> {
  late int count =
      widget.digital && widget.playerCount < 3 ? 3 : widget.playerCount;
  late int target = widget.targetPoints.clamp(1, maxTarget);

  /// Which way the last step went, so pages turn the right way.
  int _shownStep = 0;
  bool _forward = true;
  late GameMode mode = widget.mode;
  late bool surprise = widget.surprise;
  late bool roles = widget.roles;
  late int chapter = widget.chapter;
  int step = 0;

  /// Play the cards on screen against bots, instead of using the app at a
  /// real table.
  late bool digital = widget.digital;
  late final controllers = [
    for (int i = 0; i < maxPlayers; i++)
      TextEditingController(
          text: i < widget.players.length ? widget.players[i].name : ''),
  ];

  /// Dynasty is always played solo with on-screen cards, so it goes
  /// straight from the way to play to the story.
  bool get _solo => mode == GameMode.dynasty;

  /// The steps, in order: how you'll play, which game, then the table and
  /// the details. The first two go on as soon as you tap a choice.
  List<String> get _flow => [
        'how',
        'mode',
        if (!_solo) 'count',
        if (!_solo && !digital) 'names',
        'final',
      ];
  int get _steps => _flow.length;

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _start() {
    widget.onStart((
      // Solo Dynasty: the story decides who sits at the table; it opens
      // with three courtiers at the coronation.
      count: _solo ? 4 : count,
      target: mode == GameMode.dynasty ? dynastyStartingPoints : target,
      names: [
        for (int i = 0; i < count; i++)
          controllers[i].text.trim().isEmpty
              ? 'Player ${i + 1}'
              : controllers[i].text.trim(),
      ],
      mode: mode,
      surprise: surprise,
      roles: roles,
      digital: _solo || digital,
      chapter: mode == GameMode.chronicle ? chapter : null,
    ));
  }

  Future<void> _browseChapters() async {
    final chosen = await showChronicleDialog(context, widget.progress);
    if (chosen != null && mounted) setState(() => chapter = chosen);
  }

  void _next() => step == _steps - 1 || mode == GameMode.tutorial
      ? _start()
      : setState(() => step++);
  void _back() => step == 0 ? widget.onCancel() : setState(() => step--);

  static const _heading = TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w700,
      fontSize: 26,
      color: Palette.gold);

  Widget _modeStep() {
    return Column(
      key: const ValueKey('mode'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Which game?', textAlign: TextAlign.center, style: _heading),
        const SizedBox(height: 12),
        for (final m in [
          GameMode.free,
          GameMode.endless,
          GameMode.chronicle,
          if (digital) GameMode.dynasty,
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Opacity(
              opacity: m == GameMode.dynasty && dynastyComingSoon ? 0.55 : 1,
              child: _ModeTile(
                title: _modeInfo[m]!.$1,
                badge: m == GameMode.dynasty
                    ? dynastyComingSoon
                        ? '(Coming soon)'
                        : '(Alpha)'
                    : null,
                description: _modeInfo[m]!.$2,
                selected: false,
                onTap: m == GameMode.dynasty && dynastyComingSoon
                    ? () {}
                    : () => setState(() {
                          mode = m;
                          step++;
                        }),
              ),
            ),
          ),
      ],
    );
  }

  /// The first choice: how you'll play. Tap one to go on.
  Widget _howStep() {
    Widget tile(String title, String description, IconData icon,
            VoidCallback? onTap, {String? badge}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Opacity(
            opacity: onTap == null ? 0.55 : 1,
            child: _ModeTile(
              title: title,
              badge: badge,
              icon: icon,
              description: description,
              selected: false,
              onTap: onTap ?? () {},
            ),
          ),
        );
    return Column(
      key: const ValueKey('how'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('How will you play?',
            textAlign: TextAlign.center, style: _heading),
        const SizedBox(height: 12),
        tile('Tutorial', 'New to the court? Learn the rules step by step.',
            Icons.school_rounded, () {
          mode = GameMode.tutorial;
          _start();
        }),
        tile('Single player',
            'Just you, with the cards on screen and courtiers who play with you.',
            Icons.person_rounded, () => setState(() {
                  digital = true;
                  if (count < 3) count = 3;
                  if (mode == GameMode.tutorial) mode = GameMode.free;
                  step++;
                })),
        tile('Multiplayer', 'Play with friends online, each on your own phone.',
            Icons.groups_rounded, null,
            badge: '(Coming soon)'),
        tile('In person',
            'Round a real table with a real deck; the app keeps the tasks.',
            Icons.table_restaurant_rounded, () => setState(() {
                  digital = false;
                  if (mode == GameMode.dynasty || mode == GameMode.tutorial) {
                    mode = GameMode.free;
                  }
                  step++;
                })),
      ],
    );
  }

  Widget _countStep() {
    return Column(
      key: const ValueKey('count'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
            mode == GameMode.dynasty && digital
                ? 'You will be King'
                : 'How many at the table?',
            textAlign: TextAlign.center,
            style: _heading),
        const SizedBox(height: 18),
        if (mode == GameMode.dynasty && digital)
          const Text(
              'The story decides who sits at your table: one courtier for a quiet matter, the whole court for a crisis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4, color: Colors.white))
        else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int n = digital ? 3 : minPlayers; n <= maxPlayers; n++)
                _CountChip(
                    n: n, selected: count == n, onTap: () => setState(() => count = n)),
            ],
          ),
        const SizedBox(height: 8),
        if (!digital)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0x22000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Setting up the deck',
                    style: TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Palette.gold)),
                SizedBox(height: 6),
                SuitText(
                    '1. From an ordinary pack, keep the Ace to 9 of ♥ ♦ ♠ ♣ (Aces count as 1). Put the 10s and picture cards aside.\n'
                    '2. Add four Court Cards: a Joker, a Jack, a Queen and a King. They are their own suit and beat every other card, Joker lowest, King highest.\n'
                    '3. That makes 40 cards. Shuffle and deal them all out; some players may get one more card than others.\n'
                    '4. Whoever has the King card is the King: tap their seat and the tasks are dealt.',
                    style: TextStyle(
                        fontSize: 14.5, height: 1.4, color: Colors.white)),
              ],
            ),
          ),
        // Room is kept for the hint so nothing jumps when it appears (only
        // at a real table, where there's one to give).
        if (!digital) const SizedBox(height: 6),
        if (!digital)
        SizedBox(
          height: 66,
          child: Text(
            digital && mode == GameMode.dynasty
                ? ''
                : digital
                ? 'You take the bottom seat. Bots play the rest, with you, not against you.'
                : count == 2
                ? 'Two players add a third hand, the Dummy, which the King plays. Tasks use the 3-player difficulty.'
                : mode == GameMode.dynasty && count == 3
                    ? 'Dynasty is richest with four or more.'
                    : '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _namesStep() {
    return Column(
      key: const ValueKey('names'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Who sits at the table?',
            textAlign: TextAlign.center, style: _heading),
        const SizedBox(height: 6),
        const Text('Optional. Names give each seat its initials.',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 14),
        for (int i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: controllers[i],
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Player ${i + 1}',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child:
                      CircleAvatar(radius: 8, backgroundColor: Palette.players[i]),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
      ],
    );
  }

  /// Courtly roles: houses, shapes and powers. Always on in Dynasty.
  /// Courtiers keep their houses; their powers are still to come.
  Widget _rolesSwitch() => powersComingSoon
      ? const Opacity(
          opacity: 0.55,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: false,
            onChanged: null,
            title: Text.rich(TextSpan(children: [
              TextSpan(text: 'Powers', style: TextStyle(fontSize: 16)),
              TextSpan(
                  text: '  (Coming soon)',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70)),
            ])),
            subtitle: Text(
                'Each courtier gets a power to use once a round.',
                style: TextStyle(color: Colors.white70)),
          ),
        )
      : SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: roles,
          activeThumbColor: Palette.gold,
          onChanged: (v) => setState(() => roles = v),
          title: const Text('Powers', style: TextStyle(fontSize: 16)),
          subtitle: const Text(
              'Each courtier gets a power to use once a round.',
              style: TextStyle(color: Colors.white70)),
        );

  Widget _finalStep() {
    switch (mode) {
      case GameMode.chronicle:
        return Column(
          key: const ValueKey('chapter'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Which chapter?', style: _heading),
            const SizedBox(height: 14),
            _ChapterPicker(
              progress: widget.progress,
              chapter: chapter,
              onChanged: (c) => setState(() => chapter = c),
            ),
            TextButton.icon(
              onPressed: _browseChapters,
              icon: const CrownIcon(size: 14),
              label: Text('All chapters (${widget.progress.totalCrowns} crowns)'),
              style: TextButton.styleFrom(foregroundColor: Palette.gold),
            ),
            _rolesSwitch(),
          ],
        );
      case GameMode.dynasty:
        return const Column(
          key: ValueKey('story'),
          mainAxisSize: MainAxisSize.min,
          children: [
            CrownIcon(size: 48),
            SizedBox(height: 10),
            Text('A crown awaits', style: _heading),
            SizedBox(height: 10),
            Text(
              'The old King is dead, and the great houses gather in the throne hall: the Duke and the Bishop, the General and the Spymaster, the Merchant and the Jester, each with a sigil, a secret and a sworn power.\n\nYou will wear the crown, and your courtiers play their own cards beside you. How long you keep it is up to you. Win glory together, keep the houses loyal, and watch for the knife in the dark.\n\nDynasty is still taking shape (alpha), so expect rough edges.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4, color: Colors.white70),
            ),
          ],
        );
      case GameMode.tutorial:
        return const SizedBox.shrink();
      case GameMode.free:
      case GameMode.endless:
        return Column(
          key: const ValueKey('points'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text('Setup', style: _heading)),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Points target', style: TextStyle(fontSize: 16)),
                const Spacer(),
                Text('$target',
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        color: Palette.gold)),
                const SizedBox(width: 4),
                const CrownIcon(size: 18),
              ],
            ),
            Slider(
              value: target.clamp(1, maxTarget).toDouble(),
              min: 1,
              max: maxTarget.toDouble(),
              divisions: maxTarget - 1,
              onChanged: (v) => setState(() => target = v.round()),
            ),
            const Text('Higher targets mean more or harder tasks.',
                style: TextStyle(color: Colors.white70)),
            ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: surprise,
                activeThumbColor: Palette.gold,
                onChanged: (v) => setState(() => surprise = v),
                title: const Text('Seals and decrees',
                    style: TextStyle(fontSize: 16)),
                subtitle: const Text(
                    'Surprise me: rounds may bring order seals and royal decrees.',
                    style: TextStyle(color: Colors.white70)),
              ),
              _rolesSwitch(),
            ],
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_flow[math.min(step, _steps - 1)]) {
      'how' => _howStep(),
      'mode' => _modeStep(),
      'count' => _countStep(),
      'names' => _namesStep(),
      _ => _finalStep(),
    };
    final choosing = step < 2;
    final last = step == _steps - 1;
    if (step != _shownStep) {
      _forward = step > _shownStep;
      _shownStep = step;
    }
    final still = MediaQuery.of(context).disableAnimations;

    // Fills the screen: progress at the top, the step in the middle, and
    // the buttons fixed in the bottom corners so they never move.
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
        child: Column(
          children: [
            // Progress: one pip per step, with a way back on the first
            // two (which go on as soon as you choose).
            Row(
              children: [
                SizedBox(
                  width: 48,
                  child: choosing && step == 0 && widget.canCancel
                      ? IconButton(
                          tooltip: step == 0 ? 'Cancel' : 'Back',
                          onPressed: _back,
                          icon: Icon(step == 0
                              ? Icons.close_rounded
                              : Icons.arrow_back_rounded),
                        )
                      : null,
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    // A crown for each step: gold once reached, and the
                    // current one larger, springing up as you arrive.
                    children: [
                      for (int i = 0; i < _steps; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedScale(
                            scale: i == step ? 1.5 : 1,
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.elasticOut,
                            child: CrownIcon(
                                size: 14,
                                color: i <= step ? Palette.gold : Colors.white24),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: still ? 200 : 620),
                // The old page turns away first, then the new one turns in.
                switchInCurve: still
                    ? Curves.easeOut
                    : const Interval(0.45, 1, curve: Curves.easeOutBack),
                switchOutCurve: still
                    ? Curves.easeIn
                    : const Interval(0.45, 1, curve: Curves.easeInCubic),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.center,
                  children: [...previous, if (current != null) current],
                ),
                transitionBuilder: (child, a) => still
                    ? FadeTransition(opacity: a, child: child)
                    : _PageTurn(
                        animation: a,
                        incoming: child.key == ValueKey(step),
                        forward: _forward,
                        child: child),
                child: Center(
                  key: ValueKey(step),
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: body,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!choosing || step > 0) const SizedBox(height: 12),
            // Kept near the step on a wide screen, not out in the corners.
            if (!choosing || step > 0)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(
              children: [
                if (step > 0 || widget.canCancel)
                  TextButton(
                    onPressed: _back,
                    child: Text(step == 0 ? 'Cancel' : 'Back'),
                  ),
                const SizedBox(width: 8),
                if (!choosing)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    // Shrinks rather than cutting the words off.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: FilledButton(
                    onPressed: _next,
                    child: Text(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        mode == GameMode.tutorial
                            ? 'Start the tutorial'
                            : !last
                                ? 'Next'
                                : mode == GameMode.dynasty
                                    ? 'Begin the reign'
                                    : 'Start'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One way to play on the first setup step.
class _ModeTile extends StatelessWidget {
  const _ModeTile(
      {required this.title,
      this.badge,
      this.icon,
      required this.description,
      required this.selected,
      required this.onTap});
  final String title;

  /// A gold icon at the start of the tile.
  final IconData? icon;

  /// A note beside the title, such as "(Alpha)" for a mode still taking
  /// shape.
  final String? badge;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
      color: selected ? const Color(0x33D4A63A) : const Color(0x22000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: selected ? Palette.gold : Colors.white24,
            // Selection shows in the border's weight as well as its colour.
            width: selected ? 3 : 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 12, 10),
          child: Row(children: [
            if (icon != null) ...[
              Icon(icon, color: Palette.gold, size: 28),
              const SizedBox(width: 14),
            ],
            Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(title,
                        style: TextStyle(
                            fontFamily: displayFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: selected ? Palette.gold : Colors.white)),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Text(badge!,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70)),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(description,
                  style: const TextStyle(
                      fontSize: 14, height: 1.3, color: Colors.white70)),
            ],
          ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ]),
        ),
      ),
    ),
    );
  }
}

/// A big number to tap for the player count.
class _CountChip extends StatelessWidget {
  const _CountChip(
      {required this.n, required this.selected, required this.onTap});
  final int n;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$n players',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? Palette.gold : const Color(0x22000000),
            border: Border.all(
                color: selected ? Palette.gold : Colors.white38, width: 2),
          ),
          child: Text('$n',
              style: TextStyle(
                  fontFamily: bodyFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  color: selected ? Palette.ink : Colors.white)),
        ),
      ),
    );
  }
}


/// The top of a courtier's card: a wash of their colour with their sigil
/// large behind the house name and motto.
class _HouseBanner extends StatelessWidget {
  const _HouseBanner(
      {required this.courtier,
      required this.color,
      required this.name,
      required this.antagonist});
  final Courtier courtier;
  final Color color;
  final String name;
  final bool antagonist;

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(color, const Color(0xFF0A0A0A), 0.55)!;
    return Container(
      constraints: const BoxConstraints(minHeight: 128),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: antagonist
              ? [const Color(0xFF5A0C18), const Color(0xFF14060A)]
              : [color, deep],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // The sigil, big and faint, like a banner on the wall.
          Positioned(
            right: -26,
            top: -14,
            child: Opacity(
              opacity: 0.22,
              child: ShapedToken(
                  shape: courtier.shape,
                  size: 160,
                  color: Colors.white,
                  ring: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              children: [
                ShapedToken(
                    shape: courtier.shape,
                    size: 52,
                    color: antagonist ? const Color(0xFF3A0610) : color,
                    ring: Palette.gold,
                    ringWidth: 2.5),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white70)),
                      Text(courtier.title,
                          style: const TextStyle(
                              fontFamily: displayFont,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              height: 1.1,
                              color: Colors.white)),
                      Text(courtier.house,
                          style: const TextStyle(
                              fontFamily: displayFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Palette.gold)),
                      const SizedBox(height: 2),
                      Text('“${courtier.motto}”',
                          style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _DynastyStep { result, dilemma, verdict, death, ending }

/// A task card on its way from the middle of the table to whoever took it,
/// shrinking as it goes.
class _Flight {
  _Flight(this.task, this.from, this.to, this.points, this.text,
      {this.fromFont = 13, this.toFont = 12, this.toColor = Palette.inkSoft});
  final Task task;
  final Rect from;
  final Rect to;
  final int points;
  final String text;
  final double fromFont;
  final double toFont;
  final Color toColor;

  static const duration = Duration(milliseconds: 520);

  /// The chip as it looks at one end of the flight, scaled to fit [rect].
  Widget _look(Rect size, double font, Color color) => FittedBox(
        fit: BoxFit.fill,
        // Its own natural height at that width, stretched to the flight.
        child: SizedBox(
          width: size.width,
          child: _TaskChip(
            task: task,
            points: points,
            text: text,
            color: color,
            width: size.width,
            fontSize: font,
          ),
        ),
      );

  Widget build() {
    return TweenAnimationBuilder<double>(
      key: ObjectKey(this),
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final rect = Rect.lerp(from, to, t)!;
        // A gentle arc, and the open card's look fading into the owner's.
        final lift = math.sin(t * math.pi) * 18;
        return Positioned.fromRect(
          rect: rect.translate(0, -lift),
          child: IgnorePointer(
            child: Stack(fit: StackFit.expand, children: [
              Opacity(opacity: 1 - t, child: _look(from, fromFont, Palette.inkSoft)),
              Opacity(opacity: t, child: _look(to, toFont, toColor)),
            ]),
          ),
        );
      },
    );
  }
}

/// A task on the on-screen table, sized to be read rather than to look
/// like a card: points, wording, and how far along it is.
class _TaskChip extends StatelessWidget {
  const _TaskChip({
    required this.task,
    required this.points,
    required this.text,
    required this.color,
    required this.width,
    this.fontSize = 12,
    this.progress,
    this.charged = false,
    this.onTap,
    this.onLongPress,
    this.struck = const {},
  });

  final Task task;
  final int points;
  final String text;
  final Color color;
  final double width;
  final double fontSize;
  final String? progress;

  /// Cards the task names that its owner has already won.
  final Set<String> struck;
  final bool charged;
  final VoidCallback? onTap;

  /// Always opens the task's close-up, even while tapping would take it.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final done = task.isCompleted, failed = task.isFailed;
    // Along the top: points, conditions, and the tracker on the right. On
    // a very narrow chip the small condition icons give way (they're in
    // the task's close-up).
    final narrow = width < 72;
    final top = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$points',
            style: TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w900,
                fontSize: fontSize + 3,
                height: 1,
                color: Palette.ink)),
        const SizedBox(width: 2),
        CrownIcon(size: fontSize * 0.85, color: Palette.goldDeep),
        if (task.kingCantTake && !narrow) ...[
          const SizedBox(width: 4),
          Tooltip(
              message: "The King can't take this task",
              child: Icon(Icons.block, size: fontSize + 1, color: Palette.inkSoft)),
        ],
        if (task.hasNotes && !narrow) ...[
          const SizedBox(width: 3),
          Tooltip(
              message: task.notes.join(' '),
              child: Icon(Icons.info_outline,
                  size: fontSize + 1, color: Palette.inkSoft)),
        ],
        if (task.seal != null) ...[
          const SizedBox(width: 3),
          WaxSeal(seal: task.seal!, size: fontSize + 4),
        ],
        if (charged && !narrow) ...[
          const SizedBox(width: 2),
          Icon(Icons.workspace_premium, size: fontSize + 2, color: Palette.goldDeep),
        ],
            ]),
          ),
        ),
        if (failed)
          Icon(Icons.cancel, size: fontSize + 3, color: Palette.lost)
        else if (progress != null)
          // Tucked into the top right corner; shrinks to fit a narrow chip
          // rather than overflowing.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.max(20, (width - 12) * 0.6)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Palette.ink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(progress!,
                style: TextStyle(
                    fontFamily: bodyFont,
                    fontSize: fontSize - 1,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: Palette.gold)),
          ),
            ),
          ),
      ],
    );
    final front = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      decoration: BoxDecoration(
        color: failed ? const Color(0xFFFBE4E1) : Palette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: failed ? Palette.lost : color, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          top,
          const SizedBox(height: 3),
          SuitText(text,
              struck: struck,
              style: TextStyle(
                  fontSize: fontSize,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: Palette.ink)),
        ],
      ),
    );
    // Done: the chip turns over to show a seal of completion.
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: done ? 1 : 0),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
        builder: (context, d, _) => FlipIn(
          t: 1 - d,
          front: front,
          back: Stack(children: [
            Opacity(opacity: 0, child: front),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Palette.feltDeep,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: 2.5),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Done: just what it was worth.
                    Text('$points',
                        style: TextStyle(
                            fontFamily: displayFont,
                            fontWeight: FontWeight.w900,
                            fontSize: fontSize * 2.2,
                            color: Palette.gold)),
                    const SizedBox(width: 4),
                    CrownIcon(size: fontSize * 1.5, color: Palette.gold),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


/// A game saved on this device: its state, the table layout that goes with
/// it, and when it was last saved.
class _SavedGame {
  _SavedGame(this.game, this.data, this.at);
  final GameState game;
  final Map<String, dynamic> data;
  final DateTime at;

  String get title => switch (game.mode) {
        GameMode.free => 'Free play',
        GameMode.endless => 'Endless',
        GameMode.chronicle => 'The Chronicle',
        GameMode.dynasty => 'Dynasty (Alpha)',
        GameMode.tutorial => 'Tutorial',
      };

  /// Where the game had got to, in a few words.
  String get detail {
    final g = game;
    final seats = g.digital
        ? 'on-screen cards'
        : '${g.players.length} at the table';
    return switch (g.mode) {
      GameMode.dynasty => [
          'Reign ${roman(math.max(1, g.reign))}',
          if (g.reignName.isNotEmpty) g.reignName,
        ].join(' · '),
      GameMode.chronicle =>
        'Chapter ${(g.chapter ?? 0) + 1} · $seats',
      GameMode.endless => 'Streak ${g.streak} · $seats',
      _ => 'Round ${math.max(1, g.roundNumber)} · $seats',
    };
  }

  String get ago {
    final d = DateTime.now().difference(at);
    if (at.millisecondsSinceEpoch == 0) return '';
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    if (d.inDays == 1) return 'yesterday';
    return '${d.inDays} days ago';
  }
}

/// What Play offers: every saved game to continue, then a new game and the
/// tutorial. Pops with the chosen [_SavedGame], 'new' or 'tutorial'.
class _PlayMenu extends StatelessWidget {
  const _PlayMenu({required this.saves});
  final List<_SavedGame> saves;

  @override
  Widget build(BuildContext context) {
    Widget option({
      required Widget icon,
      required String title,
      required String subtitle,
      required Object result,
      bool primary = false,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: primary ? const Color(0x33D4A63A) : const Color(0x22000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: primary ? Palette.gold : Colors.white24,
                  width: primary ? 2 : 1.5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(context, result),
              child: ConstrainedBox(
                // Comfortably above the 48 pt minimum tap target.
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                  child: Row(
                    children: [
                      IconTheme(
                          data: const IconThemeData(
                              color: Palette.gold, size: 28),
                          child: icon),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontFamily: displayFont,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                    color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    height: 1.3,
                                    color: Colors.white70)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    return Dialog(
      backgroundColor: Palette.feltDeep,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: CrownIcon(size: 30)),
              const SizedBox(height: 6),
              const Text('Play',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 26,
                      color: Palette.gold)),
              const SizedBox(height: 14),
              if (saves.isNotEmpty) ...[
                Semantics(
                  header: true,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('CONTINUE',
                        style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70)),
                  ),
                ),
                for (final (i, s) in saves.indexed)
                  option(
                    icon: const Icon(Icons.play_arrow_rounded),
                    title: s.title,
                    subtitle: [s.detail, if (s.ago.isNotEmpty) s.ago].join(' · '),
                    result: s,
                    primary: i == 0,
                  ),
                const SizedBox(height: 6),
              ],
              option(
                icon: const Icon(Icons.add_rounded),
                title: 'New game',
                subtitle: saves.isEmpty
                    ? 'Choose how to play: Free play, Endless, the Chronicle or Dynasty.'
                    : 'Starting one keeps your other saves; only a save of the same kind is replaced.',
                result: 'new',
                primary: saves.isEmpty,
              ),
              option(
                icon: const Icon(Icons.school_rounded),
                title: 'Tutorial',
                subtitle:
                    'New to the court, or to card games? Learn to play, step by step.',
                result: 'tutorial',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// The game words a task uses, each opening to say what it means: for
/// anyone new to trick-taking games.
class _TermsList extends StatefulWidget {
  const _TermsList({required this.terms});
  final List<String> terms;

  @override
  State<_TermsList> createState() => _TermsListState();
}

class _TermsListState extends State<_TermsList> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    if (widget.terms.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New to these words? Tap one:',
              style: TextStyle(fontSize: 13.5, color: Palette.inkSoft)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in widget.terms)
                Semantics(
                  button: true,
                  expanded: _open == t,
                  child: ChoiceChip(
                    label: Text(t),
                    selected: _open == t,
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _open == t ? Colors.white : Palette.ink),
                    selectedColor: Palette.goldDeep,
                    backgroundColor: const Color(0xFFF3ECDD),
                    side: const BorderSide(color: Color(0xFFD9C9A3)),
                    onSelected: (on) => setState(() => _open = on ? t : null),
                  ),
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _open == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: SuitText('$_open: ${glossary[_open]}',
                          style: const TextStyle(
                              fontSize: 15, height: 1.4, color: Palette.ink)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}


/// What has become of a card a task is about.
enum _CardFate {
  /// Not played yet, and not in your hand.
  unknown,

  /// In your hand.
  yours,

  /// In the trick being played now.
  onTable,

  /// Played, and went the way the task wants.
  good,

  /// Played, and went the way the task doesn't want.
  bad,

  /// Played, and doesn't decide anything by itself.
  played,
}

/// The cards a task is about, each marked with what's become of it.
class _TaskCardsRow extends StatelessWidget {
  const _TaskCardsRow({required this.cards});
  final List<(PlayingCard, _CardFate)> cards;

  @override
  Widget build(BuildContext context) {
    Widget mark(_CardFate f) => switch (f) {
          _CardFate.good => const Icon(Icons.check_circle, size: 16, color: Palette.won),
          _CardFate.bad => const Icon(Icons.cancel, size: 16, color: Palette.lost),
          _CardFate.played => const Icon(Icons.remove_circle, size: 16, color: Palette.inkSoft),
          _CardFate.onTable => const Icon(Icons.play_circle, size: 16, color: Palette.goldDeep),
          _CardFate.yours => const Icon(Icons.pan_tool_alt_rounded, size: 15, color: Palette.goldDeep),
          _CardFate.unknown => const SizedBox(width: 16, height: 16),
        };
    final tracked = cards.any((c) => c.$2 != _CardFate.unknown);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (card, fate) in cards)
                Semantics(
                  label: '${card.spoken}: ${switch (fate) {
                    _CardFate.good => 'won as needed',
                    _CardFate.bad => 'went the wrong way',
                    _CardFate.played => 'played',
                    _CardFate.onTable => 'on the table now',
                    _CardFate.yours => 'in your hand',
                    _CardFate.unknown => 'not played yet',
                  }}',
                  excludeSemantics: true,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _MiniCard(
                        card: card,
                        width: 30,
                        dimmed: fate == _CardFate.good ||
                            fate == _CardFate.bad ||
                            fate == _CardFate.played),
                    const SizedBox(height: 2),
                    mark(fate),
                  ]),
                ),
            ],
          ),
          if (tracked)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                  '✓ won as needed   ✗ went the wrong way   – played   ✋ in your hand',
                  style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
            ),
        ],
      ),
    );
  }
}

/// A task's explanation, game words and fine print, behind an info button.
class _MoreAbout extends StatefulWidget {
  const _MoreAbout(
      {required this.explanation, required this.terms, required this.notes});
  final String explanation;
  final List<String> terms;
  final List<String> notes;

  @override
  State<_MoreAbout> createState() => _MoreAboutState();
}

class _MoreAboutState extends State<_MoreAbout> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () => setState(() => _open = !_open),
          style: TextButton.styleFrom(
              foregroundColor: Palette.goldDeep,
              padding: const EdgeInsets.symmetric(horizontal: 4)),
          icon: Icon(_open ? Icons.expand_less_rounded : Icons.info_outline_rounded,
              size: 20),
          label: Text(_open ? 'Less' : 'What this task means'),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SuitText(widget.explanation,
                        style: const TextStyle(
                            fontSize: 15, height: 1.4, color: Palette.ink)),
                    for (final n in widget.notes)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: SuitText(n,
                            style: const TextStyle(
                                fontSize: 14.5, height: 1.35, color: Palette.inkSoft)),
                      ),
                    _TermsList(terms: widget.terms),
                  ],
                ),
        ),
      ],
    );
  }
}


/// Every card in the deck, row by suit, outlined in the colour of whoever
/// played it (with its trick number), or of whoever holds it if that's
/// known; then what can be worked out about each other player's hand. For
/// keeping count on the harder rounds.
class _CardTracker extends StatelessWidget {
  const _CardTracker(
      {required this.cards,
      required this.you,
      required this.players,
      this.onClose});
  final VoidCallback? onClose;
  final MatchState cards;
  final int you;
  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final playedIn = <PlayingCard, (int, int)>{}; // trick number, seat
    for (int i = 0; i < cards.tricks.length; i++) {
      final t = cards.tricks[i];
      for (int k = 0; k < t.cards.length; k++) {
        playedIn[t.cards[k]] = (i + 1, t.seats[k]);
      }
    }
    for (int k = 0; k < cards.current.length; k++) {
      playedIn[cards.current[k]] = (cards.tricks.length + 1, cards.currentSeats[k]);
    }
    final mine = cards.hands.length > you ? cards.hands[you].toSet() : <PlayingCard>{};
    final guesses = guessHands(cards, you);
    // Who's known to hold each unplayed card: you, someone who showed it,
    // or someone it must belong to.
    final holder = <PlayingCard, int>{
      for (final c in mine) c: you,
      for (final g in guesses)
        for (final c in g.certain) c: g.seat,
    };
    final deck = fullDeck();
    final toCome = deck
        .where((c) => !playedIn.containsKey(c) && !mine.contains(c))
        .length;
    const suits = [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs, Suit.court];

    Widget cell(PlayingCard c, double w) {
      final p = playedIn[c];
      final h = holder[c];
      final edge = p != null
          ? players[p.$2].color
          : h != null
              ? players[h].color
              : null;
      final where = p != null
          ? 'played in trick ${p.$1} by ${players[p.$2].name}'
          : h == you
              ? 'in your hand'
              : h != null
                  ? 'held by ${players[h].name}'
                  : 'still to come';
      return Semantics(
        label: '${c.spoken}: $where',
        excludeSemantics: true,
        child: _MiniCard(
            card: c, width: w, dimmed: p != null, edge: edge, trick: p?.$1),
      );
    }

    Widget swatch(Player p, {double size = 14}) => Container(
          width: size * 0.72,
          height: size,
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: p.color, width: 3),
            // Ringed in black so the colour stands out on the felt.
            boxShadow: const [
              BoxShadow(color: Colors.black, spreadRadius: 1.2),
            ],
          ),
        );

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(text,
              style: const TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                  color: Palette.gold)),
        );

    Widget suitLabel(Suit suit) => SizedBox(
          width: 22,
          child: suit == Suit.court
              ? const CrownIcon(size: 14)
              : SuitText(suit.symbol,
                  style: const TextStyle(fontSize: 16, color: Colors.white)),
        );

    Widget guessBox(HandGuess g, double small) {
      Widget suitRow(Suit suit) {
        final cs = [
          for (final c in deck)
            if (c.suit == suit && g.possible.contains(c)) c
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            suitLabel(suit),
            Expanded(
              child: g.voids.contains(suit) || cs.isEmpty
                  ? Text(g.voids.contains(suit) ? 'none' : 'none left',
                      style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.white54))
                  : Wrap(spacing: 3, runSpacing: 3, children: [
                      for (final c in cs)
                        _MiniCard(
                            card: c,
                            width: small,
                            faint: !g.certain.contains(c),
                            edge: g.certain.contains(c)
                                ? players[g.seat].color
                                : null),
                    ]),
            ),
          ]),
        );
      }

      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0x22000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: players[g.seat].color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              swatch(players[g.seat], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${players[g.seat].name} · ${g.size} card${g.size == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 6),
            for (final suit in suits) suitRow(suit),
          ],
        ),
      );
    }

    return RepaintBoundary(
      child: LayoutBuilder(builder: (context, box) {
        final width = math.min(box.maxWidth, 720.0) - 24;
        const header = 40.0; // the legend above the grid
        // The whole deck fits in view at once: five rows across the full
        // width, as tall as the panel allows.
        final byWidth = (width - 8 * 4) / 9;
        final byHeight = ((box.maxHeight - header - 8) / 5 - 4) / 1.3;
        final w = math.max(16.0, math.min(byWidth, byHeight)) - 0.5;
        final small = clampD(w * 0.7, 20, 34);
        Widget centred(Widget child) =>
            Center(child: SizedBox(width: width, child: child));
        // A list, so only what's in view is built and drawn, and the legend
        // scrolls away with the rest.
        return ListView(
          padding: const EdgeInsets.only(top: 14, bottom: 16),
          children: [
            centred(Row(children: [
              for (final p in players) ...[
                swatch(p),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(p.name.replaceFirst('The ', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: Colors.white70)),
                ),
                const SizedBox(width: 10),
              ],
            ])),
            const SizedBox(height: 10),
            for (final suit in suits)
              centred(Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final c in deck)
                      if (c.suit == suit) cell(c, w)
                  ],
                ),
              )),
            centred(heading('What the others may hold')),
            centred(Text(
                '$toCome cards still to come in other hands'
                '${cards.setAside.isNotEmpty ? ' (one set aside, unseen)' : ''}. '
                'Bright cards are certain; faint ones are possible.',
                style: const TextStyle(
                    fontSize: 14, height: 1.35, color: Colors.white70))),
            for (final g in guesses) centred(guessBox(g, small)),
          ],
        );
      }),
    );
  }
}

/// Courtiers' powers and Dynasty are being reworked; until then they're
/// shown as coming soon.
const powersComingSoon = true;
const dynastyComingSoon = true;

/// A setup page turning like a card on the King's table: it swings on its
/// edge (away to one side, in from the other), and a glint of gold runs
/// across it as it lands face up.
class _PageTurn extends StatelessWidget {
  const _PageTurn(
      {required this.animation,
      required this.incoming,
      required this.forward,
      required this.child});
  final Animation<double> animation;
  final bool incoming;
  final bool forward;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value; // 0 hidden, 1 face up
        // Forward: the old page turns off to the left, the new one comes
        // in from the right; back is the other way round.
        final side = (incoming ? 1 : -1) * (forward ? 1 : -1);
        final angle = (1 - t) * side * math.pi / 2;
        final glint = incoming ? math.sin(t.clamp(0.0, 1.0) * math.pi) : 0.0;
        return Opacity(
          opacity: t.clamp(0.0, 1.0) < 0.02 ? 0 : 1,
          child: Transform(
            alignment: side > 0 ? Alignment.centerRight : Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle)
              ..multiply(Matrix4.diagonal3Values(0.9 + 0.1 * t, 0.9 + 0.1 * t, 1)),
            child: Stack(children: [
              child!,
              if (glint > 0.01)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1.6 + 3.2 * t, -1),
                          end: Alignment(-0.6 + 3.2 * t, 1),
                          colors: [
                            Palette.gold.withValues(alpha: 0),
                            Palette.gold.withValues(alpha: 0.28 * glint),
                            Palette.gold.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}

/// The highest points target a round can have. The balance report shows
/// rounds above this are close to impossible.
const maxTarget = 20;

/// A plain card face for the card tracker: just its number and suit (or
/// the Court Card's letter) and an outline, cheap enough to show dozens.
class _MiniCard extends StatelessWidget {
  const _MiniCard(
      {required this.card,
      required this.width,
      this.dimmed = false,
      this.edge,
      this.trick,
      this.faint = false,
      this.centred = true});

  /// Only possibly there: drawn in faded colours (cheaper than making it
  /// see-through).
  final bool faint;
  final PlayingCard card;
  final double width;

  /// Played: greyed inside, but its outline stays bright.
  final bool dimmed;
  final Color? edge;

  /// The trick it was played in, shown in its corner.
  final int? trick;

  /// Rank over suit, large in the middle (the only layout now; kept so
  /// callers can say so).
  final bool centred;

  static const _cloth = [
    Color(0xFF4A2670),
    Color(0xFF0F5B3A),
    Color(0xFF203C8C),
    Color(0xFF7E1828),
  ];

  @override
  Widget build(BuildContext context) {
    final court = card.isCourt;
    const felt = Palette.feltDeep;
    final fade = faint ? 0.55 : 0.0;
    final ink = Color.lerp(
        court ? Palette.gold : Palette.suitColour(card.suit), felt, fade)!;
    final face = Color.lerp(
        court
            ? Color.lerp(_cloth[card.rank - 1], Colors.black, dimmed ? 0.5 : 0)!
            : dimmed
                ? const Color(0xFFB4AFA4)
                : Palette.card,
        felt,
        fade)!;
    final r = width * 0.14;
    final edgeW = edge != null ? math.max(2.5, width * 0.08) : 1.0;
    final label = Center(
      child: Padding(
        padding: EdgeInsets.all(width * 0.06),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: card.rankLabel,
                  style: TextStyle(
                      fontFamily: court ? displayFont : bodyFont,
                      fontWeight: FontWeight.w900,
                      fontSize: width * 0.5)),
              if (!court)
                TextSpan(
                    text: '\n${card.suit.symbol}',
                    style: TextStyle(fontSize: width * 0.46)),
            ]),
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.0, color: ink),
          ),
        ),
      ),
    );
    // A coloured outline is edged in black on both sides, so it stands out
    // from the felt and from the card face alike.
    return Container(
      width: width,
      height: width * 1.3,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(r),
      ),
      padding: EdgeInsets.all(edge != null ? 1.2 : 0),
      child: Container(
        decoration: BoxDecoration(
          color: face,
          borderRadius: BorderRadius.circular(r - 1),
          border: Border.all(
              color: edge ??
                  Color.lerp(court ? Palette.gold : const Color(0xFFD9D2C3),
                      felt, fade)!,
              width: edgeW),
        ),
        child: Container(
          decoration: edge != null
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(math.max(0, r - edgeW)),
                  border: Border.all(color: Colors.black87, width: 1),
                )
              : null,
          child: Stack(children: [
            Positioned.fill(child: label),
            if (trick != null)
              Positioned(
                right: width * 0.04,
                bottom: 0,
                child: _OutlinedNumber('$trick',
                    size: width * 0.28, color: edge ?? Colors.white),
              ),
          ]),
        ),
      ),
    );
  }
}

/// A small number in a colour, ringed in black so it reads on anything.
class _OutlinedNumber extends StatelessWidget {
  const _OutlinedNumber(this.text, {required this.size, required this.color});
  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontSize: size, fontWeight: FontWeight.w900, height: 1.05);
    return Stack(children: [
      Text(text,
          style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = math.max(2.5, size * 0.22)
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.black)),
      Text(text, style: style.copyWith(color: color)),
    ]);
  }
}

/// A button that softly pulses with a gold glow, to draw the eye.
class _GlowButton extends StatefulWidget {
  const _GlowButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No pulsing for reduced motion (or in tests, where it would never
    // settle).
    final still = MediaQuery.of(context).disableAnimations ||
        !CharacterToken.alive;
    if (still) {
      _pulse.stop();
      _pulse.value = 0.6;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Palette.gold.withValues(alpha: 0.25 + 0.45 * _pulse.value),
                  blurRadius: 8 + 10 * _pulse.value,
                  spreadRadius: 1),
            ],
          ),
          child: child,
        ),
        child: FilledButton(
          onPressed: widget.onPressed,
          style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 18)),
          child: Text(widget.label),
        ),
      ),
    );
  }
}
