import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'chronicle.dart';
import 'courtiers.dart';
import 'story.dart';
import 'models.dart';
import 'play/play_page.dart';
import 'sfx.dart';
import 'theme.dart';
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
      : seatSize = clampD(math.min(size.width, size.height) * 0.13, 36, 54) {
    seatExtent = seatSize + 32; // token, with room for the crown
    rx = size.width / 2 - seatExtent / 2 - trimInset;
    ry = size.height / 2 - seatExtent / 2 - trimInset;
    cardWidth = fixedCardWidth ??
        clampD(math.min(size.width, size.height) * 0.27, 92, 128);
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
  Map<Task, Offset> layoutOwned(List<Task> order) {
    final table = playArea;
    final placed = <Rect>[
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

      // Candidate spots in the owner's frame, nearest first.
      final spots = <Offset>[];
      for (int row = 0; row < 6; row++) {
        for (int col = -4; col <= 4; col++) {
          final dx = col * (cardWidth + gap);
          final dy = row == 0
              ? 0.0
              : tokenHalfH + cardHeight / 2 + gap + (row - 1) * (cardHeight + gap);
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
        // Table completely full: fall back to just in front of the seat.
        chosen ??= clampToTable(seat + up * (tokenHalfH + cardHeight / 2));
        chosenRect ??= Rect.fromCenter(
            center: chosen, width: size.width, height: size.height);
        result[t] = chosen;
        placed.add(chosenRect);
      }
    }
    return result;
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

  /// Council votes on the current dilemma: seat to "chose A".
  Map<int, bool> _votes = {};
  List<String> _verdict = const [];
  String _verdictStory = '';

  /// The last done/failed mark, so it can be undone from the round result.
  (Task, TaskStatus)? _lastMark;

  final _tableKey = GlobalKey();

  /// A game saved from last time, offered on the welcome screen, with the
  /// table layout that goes with it.
  (GameState, Map<String, dynamic>)? _saved;

  /// Best win streak across every game on this device.
  int _bestStreak = 0;

  static const _saveKey = 'kingsCourt.game';
  static const _bestKey = 'kingsCourt.bestStreak';
  static const _chronicleKey = 'kingsCourt.chronicle';
  static const _soundKey = 'kingsCourt.sound';
  static const _uprightKey = 'kingsCourt.upright';

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
      final raw = prefs.getString(_saveKey);
      final data = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
      final saved = data == null
          ? null
          : GameState.fromJson(data['game'] as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        _bestStreak = best;
        _progress = progress;
        if (saved != null && saved.outcome == RoundOutcome.inProgress) {
          _saved = (saved, data!);
        }
      });
    } catch (_) {
      // No saved game (or storage unavailable): start fresh.
    }
  }

  /// Saves after every change, so closing the app mid-round loses nothing.
  /// Skipped while a card is being dragged; saved again when it's dropped.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (_dragging == null && _inGame) _save();
  }

  Future<void> _save() async {
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
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_saveKey, jsonEncode(data));
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

  /// Picks up the saved game exactly where it was left.
  void _continueSaved() {
    final saved = _saved;
    if (saved == null) return;
    final (g, data) = saved;
    setState(() {
      game = g;
      playerCount = data['playerCount'] as int;
      targetPoints = data['targetPoints'] as int;
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
      _saved = null;
    });
    _keepAwake(true);
  }

  @override
  void dispose() {
    _deal.dispose();
    _crown.dispose();
    _play.dispose();
    _outcome.dispose();
    _keepAwake(false);
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
      upright: _upright);

  Offset _toPx(Offset f) =>
      Offset(f.dx * _tableSize.width, f.dy * _tableSize.height);
  Offset _toFrac(Offset p) =>
      Offset(p.dx / _tableSize.width, p.dy / _tableSize.height);

  // ---------------------------------------------------------------- actions

  void _startGame(int count, int target, List<String> names, GameMode mode,
      {bool surprise = false, bool roles = true, int? chapter}) {
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
      _resetTable();
      _saved = null;
    });
    _keepAwake(true);
  }

  void _resetTable() {
    _pos.clear();
    _tilt.clear();
    _order = [];
    _dealtFor = -1;
    _deal.reset();
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
    debugPrint('DRAGSTART ${t.description}');
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
    final seat = _geo.seatAt(p);
    final previous = t.assignedPlayerIndex;
    debugPrint('DRAGEND p=$p seat=$seat table=$_tableSize '
        'seats=${[for (int i = 0; i < game.players.length; i++) _geo.seatCenter(i)]}');
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
      _showSnack("The King can't take this task", Palette.lost);
    }
  }

  void _setTaskStatus(Task task, TaskStatus status) {
    setState(() {
      final previous = task.status;
      // Choosing the active status again resets the task.
      task.status = task.status == status ? TaskStatus.pending : status;
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
            ? math.min(30, targetPoints + 1)
            : targetPoints;
        if (game.bestStreak > _bestStreak) _bestStreak = game.bestStreak;
        _step = _DynastyStep.result;
        _outcome.forward(from: 0);
      }
    });
  }

  void _showSnack(String text, Color color) {
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
                            ? '${player.name}, the King'
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
                            if (!_choosingKing) ...[
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
        content: SizedBox(
          width: 340,
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
                    : '${owner.name} has this task.',
                style: const TextStyle(fontSize: 15, color: Palette.inkSoft),
              ),
              if (RegExp(r'court card', caseSensitive: false)
                  .hasMatch(task.description))
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 3, right: 6),
                        child: CrownIcon(size: 14, color: Palette.goldDeep),
                      ),
                      Expanded(
                        child: SuitText(
                            'Court Cards are the four trumps: the Joker, J♠, Q♠ and K♠, from lowest to highest.',
                            style: TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                color: Palette.ink)),
                      ),
                    ],
                  ),
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
              for (final note in task.notes)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 6),
                        child: Icon(Icons.info_outline,
                            size: 16, color: Palette.inkSoft),
                      ),
                      Expanded(
                        child: SuitText(note,
                            style: const TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                color: Palette.ink)),
                      ),
                    ],
                  ),
                ),
              if (task.kingCantTake)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text("The King can't take this task.",
                      style: TextStyle(fontSize: 15, color: Palette.inkSoft)),
                ),
            ],
          ),
        ),
        actions: [
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
    _startGame(r.count, r.target, r.names, r.mode,
        surprise: r.surprise, roles: r.roles, chapter: r.chapter);
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
      onPlayCards: (players, target) {
        _closeSetup();
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => PlayPage(players: players, target: target)));
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
                  value: target.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '$target',
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

  @override
  Widget build(BuildContext context) {
    // One page: the felt is always there. Before a game it shows the
    // crown and the main buttons; New Game opens its panel on the table.
    return Stack(children: [
    Scaffold(
      appBar: _inGame
          ? _buildAppBar()
          : AppBar(actions: [_buildMenu(), const SizedBox(width: 4)]),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _inGame
                  ? _buildTable()
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
                    color: _inGame ? const Color(0xF00F4A2E) : Colors.transparent,
                    child: Center(child: _buildSetupPanel()),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
      // The brass inlay runs round the whole screen, the top bar included,
      // so it sits the same distance from every edge.
      const Positioned.fill(
          child: IgnorePointer(child: SafeArea(child: TableTrim()))),
    ]);
  }

  /// The menu on the right: the rules, the Chronicle and sound.
  Widget _buildMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      icon: const Icon(Icons.menu_rounded),
      color: Palette.feltDeep,
      onSelected: (choice) async {
        switch (choice) {
          case 'new':
            _showSetupDialog();
          case 'rules':
            showRulesDialog(context);
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
        }
      },
      itemBuilder: (context) => [
        if ((_inGame || _saved != null) && _setupArgs == null)
          const PopupMenuItem(
            value: 'new',
            child: ListTile(
              leading: Icon(Icons.group_add_outlined),
              title: Text('New game'),
            ),
          ),
        if (_inGame &&
            _setupArgs == null &&
            !(game.isDynasty && game.outcome != RoundOutcome.inProgress))
          const PopupMenuItem(
            value: 'shuffle',
            child: ListTile(
              leading: Icon(Icons.style_outlined),
              title: Text('Shuffle tasks'),
            ),
          ),
        const PopupMenuItem(
          value: 'rules',
          child: ListTile(
            leading: Icon(Icons.menu_book_outlined),
            title: Text('How to Play'),
          ),
        ),
        if (_inGame && game.currentTiding != null)
          const PopupMenuItem(
            value: 'tidings',
            child: ListTile(
              leading: Icon(Icons.history_edu_outlined),
              title: Text('This round\u2019s tidings'),
            ),
          ),
        PopupMenuItem(
          value: 'upright',
          child: ListTile(
            leading: Icon(_upright
                ? Icons.laptop_rounded
                : Icons.table_restaurant_outlined),
            title: Text(_upright ? 'Laptop view: upright' : 'Table view: facing seats'),
          ),
        ),
        PopupMenuItem(
          value: 'sound',
          child: ListTile(
            leading: Icon(Sfx.enabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded),
            title: Text(Sfx.enabled ? 'Fanfares on' : 'Fanfares off'),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 60,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              game.mode == GameMode.chronicle && game.chapter != null
                  ? 'Chapter ${game.chapter! + 1}'
                  : game.isDynasty && game.reign > 0
                      ? 'Reign ${roman(game.reign)}'
                      : 'Round ${game.roundNumber}',
              style: const TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: Palette.gold)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_choosingKing)
                const Text('Choose the King',
                    style: TextStyle(fontSize: 13, color: Colors.white70))
              else
                Flexible(child: TaskPips(tasks: game.tasks)),
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
              // Antagonists' open schemes; tap to read or settle one.
              if (!_choosingKing)
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
        ],
      ),
      actions: [
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
                    powerUsed: game.hasRoles && !_choosingKing
                        ? game.powerUsed[i]
                        : null,
                    loyalty: game.isDynasty &&
                            game.kingIndex != i &&
                            i < game.loyalty.length
                        ? game.loyalty[i]
                        : null,
                    spoke: _choosingKing ? null : game.spoke[i],
                    // While choosing the King a tap crowns. During play a
                    // tap opens the courtier's card, or with no roles just
                    // flips the card-reveal token.
                    onTap: _choosingKing
                        ? () => _crownKing(i)
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
          if (_decreePending)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: game.currentTiding != null
                      ? _tidingsScroll(
                          () => setState(() => _decreeReadFor = game.dealId))
                      : DecreeScroll(
                          decree: game.decree!,
                          detail: _decreeDetail,
                          onAccept: () =>
                              setState(() => _decreeReadFor = game.dealId),
                        ),
                ),
              ),
            ),
          // "Play!" once every task has an owner.
          Positioned.fill(child: IgnorePointer(child: _buildPlayFlourish())),
          if (game.outcome != RoundOutcome.inProgress)
            Positioned.fill(child: _buildOutcomeOverlay()),
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
    final from = geo.center;
    final to = geo.seatCenter(seat) + up * (geo.seatSize / 2 + 9);

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
            for (int j = 0; j < game.players.length; j++)
              if (j != seat) ..._trumpet(geo, j, to, t),
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
  List<Widget> _trumpet(_TableGeometry geo, int j, Offset king, double t) {
    // Each trumpet starts a moment after the last, like a ragged fanfare.
    final start = 0.45 + 0.04 * j;
    final local = clampD((t - start) / (1 - start), 0, 1);
    if (local <= 0) return const [];
    final seat = geo.seatCenter(j);
    final toKing = king - seat;
    final dir = toKing / toKing.distance;
    final pos = seat + dir * (geo.seatSize * 0.75);
    final angle = math.atan2(dir.dy, dir.dx);
    final pop = Curves.elasticOut.transform(clampD(local / 0.35, 0, 1));
    final toot = math.sin(local * math.pi * 6) * 0.12 * (1 - local);
    final fade = local < 0.8 ? 1.0 : (1 - local) / 0.2;
    final size = clampD(geo.seatSize * 0.6, 22, 32);

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_edu, color: Palette.goldDeep, size: 28),
                const Text('Tidings',
                    style: TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Palette.inkSoft)),
                Text(t.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 25,
                        color: Palette.cardRed)),
                const SizedBox(height: 8),
                Text(t.story,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, height: 1.4, color: Palette.ink)),
                if (seat != null && _chargeLine != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShapedToken(
                          shape: game.courtiers[seat].shape,
                          size: 30,
                          color: game.players[seat].color,
                          ring: Palette.goldDeep),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(_chargeLine!,
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: Palette.ink)),
                      ),
                    ],
                  ),
                  if (charged != null) ...[
                    const SizedBox(height: 6),
                    SuitText('Their royal charge: ${charged.description}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: Palette.inkSoft)),
                  ],
                ],
                if (game.decree != null) ...[
                  const Divider(height: 24),
                  Text('Royal Decree: ${game.decree!.title}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: displayFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Palette.cardRed)),
                  const SizedBox(height: 4),
                  Text(game.decree!.rule,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, height: 1.35, color: Palette.ink)),
                  if (_decreeDetail != null)
                    Text(_decreeDetail!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Palette.ink)),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                      backgroundColor: Palette.ink,
                      foregroundColor: Palette.gold),
                  child: const Text('So it begins'),
                ),
              ],
            ),
          ),
        ),
      ),
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
                  ? 'Who holds the K♠?'
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
            game.isDynasty
                ? 'Tap a seat to crown them. The King takes the K♠ into their hand before every deal, and rules until they fall.'
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

  Widget _buildCards(_TableGeometry geo) {
    return AnimatedBuilder(
      animation: _deal,
      builder: (context, _) {
        final n = game.tasks.length;
        final dealing = _deal.isAnimating;
        final labels = seatLabels(game.players);

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
                          _lastPointer = null;
                          _onDragEnd(t);
                        },
                        child: AnimatedScale(
                          scale: lifted ? 1.08 : 1,
                          duration: const Duration(milliseconds: 120),
                          child: TableCard(
                            task: t,
                            points: _points(t),
                            text: t.cardText(playerCount),
                            width: cw,
                            height: ch,
                            owner: owner == null ? null : game.players[owner],
                            ownerLabel: owner == null ? null : labels[owner],
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

  /// Quiet hints at how the round moved each courtier's loyalty.
  List<String> _loyaltyHints() => [
        for (int i = 0; i < game.roundLoyalty.length; i++)
          if (game.roundLoyalty[i] > 0)
            '${game.courtiers[i].title}\u2019s candle burns brighter.'
          else if (game.roundLoyalty[i] < 0)
            '${game.courtiers[i].title}\u2019s faith is shaken.',
      ];

  Widget _dynastyResult(bool won) {
    final fg = won ? Palette.ink : Colors.white;
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
        const SizedBox(height: 4),
        Text(
            won
                ? 'Every task is done. The court rejoices.'
                : 'A task failed. The King is wounded.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: fg)),
        if (game.currentTiding != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                won
                    ? game.currentTiding!.won.text
                    : game.currentTiding!.lost.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: fg)),
          ),
        for (final hint in _loyaltyHints())
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, fontStyle: FontStyle.italic, color: fg)),
          ),
        if (won && game.ending == null) ...[
          const SizedBox(height: 10),
          // How close this reign is to a Golden Age.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < GameState.goldenAgeWins; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: CrownIcon(
                      size: 16,
                      color: i < game.reignWins
                          ? Palette.ink
                          : const Color(0x33000000)),
                ),
            ],
          ),
          Text('Victories this reign. Five bring a Golden Age.',
              style: TextStyle(fontSize: 13, color: fg)),
        ],
        for (final seat in game.antagonists) ...[
          const SizedBox(height: 12),
          SuitText(
              '${game.courtiers[seat].title}\u2019s scheme: ${schemes[game.schemeOf[seat]!]}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.3, color: fg)),
          const SizedBox(height: 6),
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
              : () => setState(() {
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
                      _votes = {};
                      _step = _DynastyStep.dilemma;
                    }
                  }),
          style: won
              ? FilledButton.styleFrom(
                  backgroundColor: Palette.ink, foregroundColor: Palette.gold)
              : null,
          child: Text(!settled
              ? 'Settle the schemes first'
              : game.kingFallen
                  ? 'Attend the King'
                  : game.ending == DynastyEnding.goldenAge
                      ? 'Enter the Golden Age'
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
    final king = game.kingIndex == null ? null : game.players[game.kingIndex!];
    final deciding = _step == _DynastyStep.dilemma;
    return _parchmentCard(
      color: const Color(0xFFF6EBD2),
      border: Palette.goldDeep,
      children: [
        const CrownIcon(size: 26, color: Palette.goldDeep),
        Text(deciding ? 'The King\u2019s Dilemma' : 'So it is decided',
            style: const TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Palette.inkSoft)),
        Text(d.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                color: Palette.cardRed)),
        const SizedBox(height: 8),
        Text(deciding ? d.story : _verdictStory,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, height: 1.4, color: Palette.ink)),
        const SizedBox(height: 12),
        if (deciding) ...[
          if (king != null)
            Text('${king.name}, what is your will?',
                style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: Palette.inkSoft)),
          const SizedBox(height: 10),
          if (d.council && _voters.isNotEmpty)
            ..._council(d)
          else
            for (final choice in [d.a, d.b])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _decide(choice),
                    style: FilledButton.styleFrom(
                        backgroundColor: Palette.ink,
                        foregroundColor: Palette.gold),
                    child: Text(choice.label),
                  ),
                ),
              ),
        ] else ...[
          for (final line in _verdict)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Palette.ink)),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => setState(() {
              if (game.kingFallen) {
                _step = _DynastyStep.death;
                Sfx.lose();
              } else if (game.ending != null) {
                _step = _DynastyStep.ending;
                Sfx.lose();
              } else {
                _nextDynastyRound(won);
              }
            }),
            style: FilledButton.styleFrom(
                backgroundColor: Palette.cardRed, foregroundColor: Colors.white),
            child: Text(game.kingFallen
                ? 'Attend the King'
                : game.ending != null
                    ? 'The traitors rise'
                    : 'Next round'),
          ),
        ],
      ],
    );
  }

  /// Courtiers with a vote in council: everyone loyal except the King.
  List<int> get _voters => [
        for (int i = 0; i < game.players.length; i++)
          if (i != game.kingIndex && !game.isAntagonist(i)) i
      ];

  /// A council matter: each courtier votes, then the King heeds the court
  /// or overrules it (and those who were overruled remember).
  List<Widget> _council(Dilemma d) {
    final voters = _voters;
    final forA = voters.where((s) => _votes[s] == true).toList();
    final forB = voters.where((s) => _votes[s] == false).toList();
    final allVoted = forA.length + forB.length == voters.length;
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
                        side: const BorderSide(color: Palette.ink)),
                    child: Text(text, textAlign: TextAlign.center))
                : FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                        backgroundColor: Palette.ink,
                        foregroundColor: Palette.gold),
                    child: Text(text, textAlign: TextAlign.center)),
          ),
        );
    final majorityA = forA.length > forB.length;
    final tie = forA.length == forB.length;
    final major = majorityA ? d.a : d.b;
    final minor = majorityA ? d.b : d.a;
    final majorVoters = majorityA ? forA : forB;
    return [
      const Text('The court is called to vote',
          style: TextStyle(
              fontFamily: displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Palette.cardRed)),
      const SizedBox(height: 6),
      for (final (letter, c) in [('A', d.a), ('B', d.b)])
        Text('$letter.  ${c.label}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink)),
      const SizedBox(height: 8),
      for (final seat in voters)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              ShapedToken(
                  shape: game.courtiers[seat].shape,
                  size: 24,
                  color: game.players[seat].color,
                  ring: Palette.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(game.courtiers[seat].short,
                    style: const TextStyle(fontSize: 15, color: Palette.ink)),
              ),
              for (final a in [true, false])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _VoteChip(
                    label: a ? 'A' : 'B',
                    selected: _votes[seat] == a,
                    onTap: () => setState(() => _votes[seat] = a),
                  ),
                ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      if (!allVoted)
        button('Every courtier must vote', null)
      else if (tie) ...[
        const Text('The court is split. The King decides.',
            style: TextStyle(
                fontSize: 14, fontStyle: FontStyle.italic, color: Palette.inkSoft)),
        const SizedBox(height: 6),
        button(d.a.label, () => _decide(d.a)),
        button(d.b.label, () => _decide(d.b)),
      ] else ...[
        button('Heed the court: ${major.label}',
            () => _decide(major, heeded: true)),
        button('Overrule: ${minor.label}',
            () => _decide(minor, overruled: majorVoters),
            outlined: true),
      ],
    ];
  }

  /// Carries out the King's choice and writes up what changed.
  void _decide(Choice choice,
      {List<int> overruled = const [], bool heeded = false}) {
    final loyaltyBefore = List.of(game.loyalty);
    final antagonistsBefore = game.antagonists.toSet();
    final woundsBefore = game.kingWounds;
    final pointsBefore = game.pointsBonus;
    setState(() {
      game.applyChoice(choice);
      if (overruled.isNotEmpty) game.overruled(overruled);
      if (heeded) game.heededCouncil();
      final lines = <String>[
        if (overruled.isNotEmpty) 'The King overrules the court.',
        if (heeded) 'The King heeds the court.',
      ];
      for (int i = 0; i < game.players.length; i++) {
        final delta = game.loyalty[i] - loyaltyBefore[i];
        if (delta == 0) continue;
        final who = game.courtiers[i].title;
        if (game.isAntagonist(i) && !antagonistsBefore.contains(i)) {
          lines.add('$who turns against the King!');
        } else if (!game.isAntagonist(i) && antagonistsBefore.contains(i)) {
          lines.add('$who returns to the King\u2019s side.');
        } else {
          // No numbers: the candles on the seats tell the rest.
          lines.add(delta > 0
              ? '$who will remember this kindness.'
              : '$who will remember this.');
        }
      }
      final wounds = game.kingWounds - woundsBefore;
      if (wounds > 0) lines.add('The King takes a wound.');
      if (wounds < 0) lines.add('A wound is healed.');
      final points = game.pointsBonus - pointsBefore;
      if (points > 0) lines.add('The court\u2019s burdens grow.');
      if (points < 0) lines.add('The court\u2019s burdens ease.');
      if (game.pendingDecree != null) {
        lines.add('Next round brings a decree: ${game.pendingDecree!.title}');
      }
      if (game.pendingCharge != null) {
        lines.add(
            'Next round, ${game.pendingCharge!.title} is charged with a royal task.');
      }
      _verdict = lines;
      _verdictStory = choice.outcome;
      _step = _DynastyStep.verdict;
    });
  }

  void _nextDynastyRound(bool won) {
    final target = (targetPoints + (won ? 1 : 0) + game.pointsBonus)
        .clamp(1, 30)
        .toInt();
    game.pointsBonus = 0;
    targetPoints = target;
    game.nextDynastyRound(playerCount, target);
    _resetTable();
    _lastMark = null;
    _step = _DynastyStep.result;
  }

  Widget _deathCard() {
    final seat = game.kingIndex;
    final name = seat == null ? 'The King' : game.players[seat].name;
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
          child: Text(last ? 'Close the annals' : 'Crown an heir'),
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
        Annal(game.players[king].name, game.epithet, game.reignRounds,
            game.reign),
    ];
    final fg = golden ? Palette.ink : Colors.white;
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
    final chapter = game.mode == GameMode.chronicle ? game.chapter : null;
    final hasNext = chapter != null && chapter < chronicle.length - 1;
    return StatefulBuilder(
      builder: (context, setCardState) => Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: won ? Palette.gold : Palette.feltDeep,
          borderRadius: BorderRadius.circular(16),
          border: won ? null : Border.all(color: Palette.lost, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CrownIcon(size: 44, color: won ? Palette.ink : Palette.lost),
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
            const SizedBox(height: 4),
            Text(
              won ? 'Every task is done. The court rejoices.' : 'A task failed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: fg),
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
                value: _nextTarget.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                label: '$_nextTarget',
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
                  child: const Text('Retry these tasks'),
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
                  child: Text('Deal $_nextTarget points'),
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

  /// The front of the table before a game: a hand of cards fans out, the
  /// crown drops onto it in a burst of sparks, then the name and one
  /// button: Play, or Continue when a game is saved.
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
                child: _saved == null
                    ? FilledButton.icon(
                        onPressed: _showSetupDialog,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'))
                    : FilledButton.icon(
                        onPressed: _continueSaved,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Continue')),
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

  static const _cards = ['7♦', 'J♠', 'K♠', 'Q♠', 'A♥'];

  static double _iv(double t, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0).toDouble());

  @override
  Widget build(BuildContext context) {
    final cardW = crownSize * 0.42;
    final cardH = cardW * 1.45;
    final stageH = crownSize * 1.35;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
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
                      top: stageH - cardH - 4 + (1 - rise) * 40,
                      child: Opacity(
                        opacity: rise,
                        child: Transform.rotate(
                          angle: (i - 2) * 0.32 * fan,
                          alignment: const Alignment(0, 1.6),
                          child: _IntroCard(
                              label: _cards[i], width: cardW, height: cardH),
                        ),
                      ),
                    ),
                  // Sparks where the crown lands.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: spark > 0 && spark < 1
                            ? _IntroSparks(
                                origin: Offset(crownSize, stageH * 0.42),
                                progress: spark,
                                scale: crownSize / 120)
                            : null,
                      ),
                    ),
                  ),
                  // The crown, dropping onto the hand.
                  Positioned(
                    left: crownSize / 2,
                    top: stageH * 0.42 - crownSize / 2 - (1 - drop) * stageH,
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
                  'A cooperative trick-taking game for 2 to 6 players.',
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

/// A playing card in the front-page hand.
class _IntroCard extends StatelessWidget {
  const _IntroCard(
      {required this.label, required this.width, required this.height});
  final String label;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final red = label.contains('♥') || label.contains('♦');
    final court = label.contains('♠') && !label.startsWith('7');
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(width * 0.08),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(
            color: court ? Palette.gold : const Color(0x33000000),
            width: court ? 2 : 1),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      alignment: Alignment.topLeft,
      child: Text(label,
          style: TextStyle(
              fontFamily: bodyFont,
              fontWeight: FontWeight.w800,
              fontSize: width * 0.3,
              height: 1,
              color: red ? Palette.cardRed : Palette.ink)),
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
Future<void> showRulesDialog(BuildContext context) {
  const rules = <(String, List<String>)>[
    (
      'The aim',
      [
        "Everyone plays together. Each round you deal tasks such as 'Win a trick with a 6', share them out, then play tricks to complete them all.",
        'Complete every task and the round is won. If any task fails, the round is lost.',
      ]
    ),
    (
      'The deck',
      [
        'Use 40 cards: Ace to 9 in all four suits, with the Ace counting as 1. Remove the 10s and the face cards.',
        'Add the four Court Cards: the Joker, J♠, Q♠ and K♠. Court Cards are trumps. From lowest to highest: Joker, J♠, Q♠, K♠.',
        'Shuffle and deal out every card. With 3 or 6 players, some players get one extra card.',
      ]
    ),
    (
      'Choosing tasks',
      [
        'Whoever holds the K♠ shows it and becomes the King. Tap their seat in the app and the tasks are dealt onto the table.',
        'Look at your hand. Then, starting with the King and going clockwise, each player takes one task until all are taken. Drag a task onto your seat to take it. A glowing gold ring shows whose turn it is to pick.',
        'A task is yours alone: only the tricks you win count towards it.',
      ]
    ),
    (
      'Playing a trick',
      [
        'The King leads the first trick by playing any card face up.',
        'Going clockwise, everyone plays one card. You must play the suit that was led if you can. If you can\'t, play any card, including a Court Card.',
        'The highest card of the suit led wins the trick, unless a Court Card was played. Then the highest Court Card wins.',
        'The winner takes the trick, keeps it in front of them and leads the next one. Keep playing until every card is used.',
      ]
    ),
    (
      'Talking',
      [
        "Don't talk about the cards in your hand or suggest what anyone should play.",
        'Once per round, before you play a card, you may lay one card from your hand face up and say whether it is your highest, your lowest or your only card of that suit. Court Cards can\'t be shown.',
        'When you do, tap your seat to flip your speech token over. With courtly roles on, tapping your seat opens your courtier\'s card, where you mark it.',
      ]
    ),
    (
      'Tracking tasks',
      [
        'Tap a task to read it up close and mark it done or failed. Done tasks flip face down.',
        'Mark a task failed as soon as it can no longer be completed. The round ends there.',
        'Press and hold the felt in front of you to turn every task towards you. Let go and they turn back to their owners.',
        'Each player\'s seat shows their seat number or initials, and the same badge appears on every task they hold.',
        'Some tasks show icons under their points. 🚫 means the King can\'t take it. ⓘ means there is an extra condition: tap the task to read it.',
      ]
    ),
    (
      'Seals',
      [
        'Some tasks carry a red wax seal. Sealed tasks must be completed in order: seal I before seal II before seal III.',
        'The Ω seal must be the very last task completed in the round.',
        'Completing a sealed task out of order fails the round. The app checks when you mark it done.',
      ]
    ),
    (
      'Royal decrees',
      [
        'Some rounds bring a royal decree, read out after the King is crowned. Tap the red decree name at the top to read it again.',
        'Silence: no card reveals. Late Counsel: no reveals until three tricks have been played.',
        "King's Command: the King hands out every task. Exile: one player, chosen at random, may take no tasks this round.",
      ]
    ),
    (
      'Ways to play',
      [
        'Free play: you choose the points. Turn on Seals and decrees for surprises.',
        'Courtly roles (any mode): everyone plays a courtier of a great house, with a token shape and a power to use once per round. Tap your seat to read your house and power and to mark it used.',
        'Dynasty: a King who reigns until they fall, with courtiers, powers and dilemmas (see below).',
        'Endless: each win adds a point to the next round, and the app keeps your current and best win streaks.',
        'The Chronicle: 24 chapters with set points, seals and decrees. Beat a chapter to unlock the next and earn crowns: 3 on your first attempt, 2 within three attempts, 1 after that.',
        'Your game saves as you play. Close the app and pick up where you left off with Continue. New game, Shuffle tasks, the laptop view (everything upright, no turning to each seat) and sound are in the menu at the top right.',
      ]
    ),
    (
      'Dynasty',
      [
        'Choose the first King. Before every deal the King takes the K♠ into their hand, and keeps the crown round after round.',
        'Every lost round wounds the King (the drops by the crown). How many wounds they can bear is secret: one, two or three. When the King falls, crown an heir and the dynasty goes on.',
        'Every seat is a courtier of a great house, with a token shape and a power used once per round. Tap your seat to read your house and power.',
        'After each round the King faces a dilemma and chooses. Choices win or lose courtiers\' loyalty, heal or wound the King, and can bring decrees.',
        'Loyalty is a candle by each courtier\'s seat: the taller the flame, the more loyal. It flickers when loyalty changes. Deeds count too: after a won round, whoever did the most tasks gains favour, and a failed task shakes its owner\'s faith.',
        'The King earns a name from their choices: the Kind, the Stern, the Bold and more.',
        'Each round opens with tidings: news from the kingdom that may bring a decree and charge one house with a task. A royal charge (the gold ribbon) is dealt straight to that house and stays with them. Do it and they gain favour; fail and they lose it. Some dilemmas then follow from how the round went.',
        'Some matters go to council: every loyal courtier votes, then the King heeds the court or overrules it. Overruled courtiers remember.',
        'How it ends: if one King wins five rounds in their reign, the court enters a Golden Age and you win. If three Kings fall, the dynasty falls. If traitors ever outnumber the loyal, they seize the throne.',
        'A courtier whose loyalty falls to nothing openly turns against the King. Their token turns blood-red and they gain a scheme, shown at the top. They take no tasks and don\'t pick. If their scheme succeeds, the King is wounded. A later dilemma can win them back.',
      ]
    ),
    (
      'Playing the cards on screen',
      [
        'Choose Play the cards to play without a deck: you take one seat and bot courtiers take the rest. They play with you, not against you.',
        'The app deals, finds the King (whoever holds the K♠), and enforces the rules: you can only play cards you are allowed to. Cards you may play stand up in your hand.',
        'Tap a task in the middle to take it when it\'s your pick. Tasks mark themselves done or failed as the tricks fall.',
        'With 3, 5 or 6 players, a few cards are set aside unseen so everyone has the same number. Tasks that need a set-aside card are never dealt.',
        'The bots know where every card is, like a table of friends who talk too much. Card reveals, seals and decrees aren\'t in the on-screen game yet.',
      ]
    ),
    (
      'Two players',
      [
        'Deal 13 cards to each player. The other 14 go to a third hand, the Dummy: 7 face down, with 7 face up on top.',
        'When a face-up Dummy card is played, flip the card underneath it.',
        'The King plays the Dummy\'s cards as well as their own. If the K♠ is in the Dummy, choose a King together.',
        'Only the two players take tasks. Tasks use the 3-player difficulty.',
      ]
    ),
  ];

  // One scrolling sheet: the title, every rule and the button all move
  // together, so nothing is pinned on a small screen.
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Palette.card,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How to Play',
                  style: TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 26,
                      color: Palette.ink)),
              const SizedBox(height: 10),
              for (final (heading, items) in rules) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 6),
                  child: Text(heading,
                      style: const TextStyle(
                          fontFamily: displayFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 19,
                          color: Palette.goldDeep)),
                ),
                for (final rule in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5, right: 10),
                          child: CrownIcon(size: 11, color: Palette.goldDeep),
                        ),
                        Expanded(
                          child: SuitText(rule,
                              style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.4,
                                  color: Palette.ink)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                      backgroundColor: Palette.ink,
                      foregroundColor: Palette.gold),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

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
    required this.onPlayCards,
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

  /// Starts a card game on screen against bots: players, points.
  final void Function(int players, int target) onPlayCards;

  @override
  State<_SetupPanel> createState() => _SetupPanelState();
}

/// What each way to play is about, shown on the first step.
const _modeInfo = {
  GameMode.free: (
    'Free play',
    'Pick a points target and play round after round. Add surprise seals and decrees if you like.'
  ),
  GameMode.endless: (
    'Endless',
    'Every win adds a point to the next round. How long a winning streak can your court keep?'
  ),
  GameMode.chronicle: (
    'The Chronicle',
    '24 chapters with set points, seals and decrees that build in difficulty. Earn up to three crowns for each.'
  ),
  GameMode.dynasty: (
    'Dynasty',
    'A story of kings. The King rules until wounds bring them down. Face dilemmas, keep your courtiers loyal, and watch for traitors.'
  ),
};

class _SetupPanelState extends State<_SetupPanel> {
  late int count = widget.playerCount;
  late int target = widget.targetPoints;
  late GameMode mode = widget.mode;
  late bool surprise = widget.surprise;
  late bool roles = widget.roles;
  late int chapter = widget.chapter;
  int step = 0;

  /// Play the cards on screen against bots, instead of using the app at a
  /// real table.
  bool digital = false;
  late final controllers = [
    for (int i = 0; i < maxPlayers; i++)
      TextEditingController(
          text: i < widget.players.length ? widget.players[i].name : ''),
  ];

  int get _steps => digital ? 3 : 4;

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _start() {
    if (digital) {
      widget.onPlayCards(count, target);
      return;
    }
    widget.onStart((
      count: count,
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
      chapter: mode == GameMode.chronicle ? chapter : null,
    ));
  }

  Future<void> _browseChapters() async {
    final chosen = await showChronicleDialog(context, widget.progress);
    if (chosen != null && mounted) setState(() => chapter = chosen);
  }

  void _next() => step == _steps - 1 ? _start() : setState(() => step++);
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
        const Text('How will you play?',
            textAlign: TextAlign.center, style: _heading),
        const SizedBox(height: 14),
        for (final m in GameMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ModeTile(
              title: _modeInfo[m]!.$1,
              description: _modeInfo[m]!.$2,
              selected: !digital && mode == m,
              onTap: () => setState(() {
                mode = m;
                digital = false;
              }),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ModeTile(
            title: 'Play the cards',
            description:
                'No deck needed: play on screen with bot courtiers. The app deals, keeps the rules and checks every task as the tricks fall.',
            selected: digital,
            onTap: () => setState(() {
              digital = true;
              if (count < 3) count = 3;
            }),
          ),
        ),
      ],
    );
  }

  Widget _countStep() {
    return Column(
      key: const ValueKey('count'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('How many at the table?',
            textAlign: TextAlign.center, style: _heading),
        const SizedBox(height: 18),
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
        const SizedBox(height: 14),
        // Room is kept for the hint so nothing jumps when it appears.
        SizedBox(
          height: 66,
          child: Text(
            digital
                ? 'You take one seat. Bots play the rest, and play with you, not against you.'
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
  Widget _rolesSwitch() => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: roles,
        activeThumbColor: Palette.gold,
        onChanged: (v) => setState(() => roles = v),
        title: const Text('Courtly roles', style: TextStyle(fontSize: 16)),
        subtitle: const Text(
            'Everyone plays a courtier of a great house, with a power to use once a round.',
            style: TextStyle(color: Colors.white70)),
      );

  Widget _finalStep() {
    switch (digital ? GameMode.free : mode) {
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
            Text('The story begins', style: _heading),
            SizedBox(height: 10),
            Text(
              'Each of you is a courtier of a great house, with a token of your own shape and a power to use once a round. One of you will be crowned. The tasks will grow with the story, so there are no points to choose.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4, color: Colors.white70),
            ),
          ],
        );
      case GameMode.free:
      case GameMode.endless:
        return Column(
          key: const ValueKey('points'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text('How hard?', style: _heading)),
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
              value: target.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              label: '$target',
              onChanged: (v) => setState(() => target = v.round()),
            ),
            const Text('Higher targets mean more or harder tasks.',
                style: TextStyle(color: Colors.white70)),
            // On-screen games keep to plain rounds for now.
            if (!digital) ...[
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
    final body = switch (step) {
      0 => _modeStep(),
      1 => _countStep(),
      2 when !digital => _namesStep(),
      _ => _finalStep(),
    };
    final last = step == _steps - 1;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress: one pip per step.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _steps; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == step ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i <= step ? Palette.gold : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Flexible(
              child: SingleChildScrollView(
                child: AnimatedSize(
                  // Each step grows or shrinks smoothly into the next.
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                              begin: const Offset(0, 0.06), end: Offset.zero)
                          .animate(a),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
                  child: body,
                ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (step > 0 || widget.canCancel)
                  TextButton(
                    onPressed: _back,
                    child: Text(step == 0 ? 'Cancel' : 'Back'),
                  ),
                const Spacer(),
                Flexible(
                  child: FilledButton(
                  onPressed: _next,
                  child: Text(maxLines: 1, overflow: TextOverflow.ellipsis, !last
                      ? 'Next'
                      : digital
                          ? 'Deal the cards'
                          : mode == GameMode.dynasty
                              ? 'Begin the reign'
                              : 'Deal tasks'),
                  ),
                ),
              ],
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
      required this.description,
      required this.selected,
      required this.onTap});
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0x33D4A63A) : const Color(0x22000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: selected ? Palette.gold : Colors.white24,
            width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: selected ? Palette.gold : Colors.white)),
              const SizedBox(height: 4),
              Text(description,
                  style: const TextStyle(
                      fontSize: 14.5, height: 1.35, color: Colors.white70)),
            ],
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

/// One vote in council.
class _VoteChip extends StatelessWidget {
  const _VoteChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Vote $label',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Palette.ink, width: 1.5),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: bodyFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: selected ? Palette.gold : Palette.ink)),
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
