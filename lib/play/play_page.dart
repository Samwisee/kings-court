import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../courtiers.dart';
import '../engine/cards.dart';
import '../engine/match.dart';
import '../engine/rules.dart';
import '../models.dart';
import '../sfx.dart';
import '../theme.dart';
import '../widgets.dart';
import 'card_view.dart';
import 'controller.dart';

/// The card game on screen: you at the bottom with your hand, the bots
/// across the top, the trick in the middle. The app deals, enforces the
/// rules and checks every task as the tricks fall.
class PlayPage extends StatefulWidget {
  const PlayPage({super.key, required this.players, required this.target});
  final int players;
  final int target;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  late final MatchController match =
      MatchController(players: widget.players, target: widget.target);

  /// Who sits where: you are a courtier too, the bots are the rest.
  late final List<Courtier> courtiers =
      (List.of(Courtier.values)..shuffle()).take(widget.players).toList();
  late final List<Player> seats = [
    for (int i = 0; i < widget.players; i++)
      Player(i == MatchController.human ? 'You' : courtiers[i].title,
          color: Palette.players[i % Palette.players.length]),
  ];

  late int _nextTarget = widget.target;

  // Everything that moves is measured against the table, so cards can
  // glide from where they are to where they're going.
  final _stackKey = GlobalKey();
  final _middleKey = GlobalKey();
  final _handKey = GlobalKey();
  final _yourTasksKey = GlobalKey();
  late final _seatKeys = [for (int i = 0; i < widget.players; i++) GlobalKey()];
  final _openTaskKeys = <int, GlobalKey>{};
  Map<int, Rect> _openTaskRects = {};

  /// Where each of your cards left your hand.
  final _launchFrom = <int, Offset>{};

  /// Task cards flying from the middle to whoever took them.
  final _flights = <_Flight>[];
  List<int?> _owners = [];
  final _flightTimers = <Timer>[];

  /// The finished trick sweeping off to its winner.
  bool _collecting = false;
  Trick? _collectFor;
  Timer? _collectTimer;
  bool _askedX = false;
  int _lastRound = 0;
  Phase? _lastPhase;

  MatchState get s => match.state;

  @override
  void initState() {
    super.initState();
    match.start();
    _lastRound = s.round;
    match.addListener(_changed);
  }

  @override
  void dispose() {
    match.removeListener(_changed);
    match.dispose();
    _collectTimer?.cancel();
    for (final t in _flightTimers) {
      t.cancel();
    }
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (s.round != _lastRound) {
      _lastRound = s.round;
      _askedX = false;
    }
    if (s.phase == Phase.roundOver && _lastPhase != Phase.roundOver) {
      if (s.won == true) {
        Sfx.win();
      } else {
        Sfx.lose();
      }
      _nextTarget = s.won == true ? math.min(30, s.target + 1) : s.target;
    }
    _lastPhase = s.phase;
    _launchTaskFlights();
    final trick = match.lastTrick;
    if (trick != null && !identical(trick, _collectFor)) {
      _collectFor = trick;
      _collecting = false;
      _collectTimer?.cancel();
      _collectTimer = Timer(MatchController.trickPause * 0.6, () {
        if (mounted) setState(() => _collecting = true);
      });
    }
    setState(() {});
    final x = match.pendingAnnouncement;
    if (x != null && !_askedX) {
      _askedX = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _announce(x));
    }
  }

  Rect? _rect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.attached || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
  }

  /// Sends each newly taken task flying from the middle to its owner.
  void _launchTaskFlights() {
    final owners = [for (final t in s.tasks) t.owner];
    if (owners.length == _owners.length) {
      for (int i = 0; i < owners.length; i++) {
        final owner = owners[i];
        final from = _openTaskRects[i];
        if (_owners[i] != null || owner == null || from == null) continue;
        final Rect to;
        if (owner == MatchController.human) {
          final area = _rect(_yourTasksKey);
          if (area == null) continue;
          to = Rect.fromLTWH(area.left + 60, area.top, from.width * 0.85,
              from.height * 0.85);
        } else {
          final seat = _rect(_seatKeys[owner]);
          if (seat == null) continue;
          final w = from.width * 0.7;
          to = Rect.fromCenter(
              center: seat.bottomCenter + Offset(0, from.height * 0.5),
              width: w,
              height: from.height * 0.7);
        }
        final flight = _Flight(s.tasks[i], from, to);
        _flights.add(flight);
        _flightTimers.add(Timer(_Flight.duration, () {
          if (mounted) setState(() => _flights.remove(flight));
        }));
      }
    }
    _owners = owners;
  }

  String _name(int seat) =>
      seat == MatchController.human ? 'You' : courtiers[seat].title;

  String _label(int seat) => seat == MatchController.human
      ? 'You'
      : courtiers[seat].short.substring(0, 1);

  /// Ask how many tricks you'll win for an "exactly X" task.
  Future<void> _announce(int task) async {
    int x = 1;
    final t = s.tasks[task];
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
              SuitText(t.task.cardText(s.players),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    onPressed: x > 0 ? () => setDialog(() => x--) : null,
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
                    onPressed: x < s.totalTricks
                        ? () => setDialog(() => x++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Your hand: ${s.hands[MatchController.human].length} cards, '
                  '${s.totalTricks} tricks in the round.',
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
    match.send(Announce(MatchController.human, task, chosen ?? x));
  }

  Future<void> _leave() async => Navigator.of(context).maybePop();

  // ----------------------------------------------------------------- views

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            toolbarHeight: 60,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Round ${s.round}',
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: Palette.gold)),
                const SizedBox(height: 4),
                TaskPips(tasks: [for (final t in s.tasks) t.task]),
              ],
            ),
            actions: [
              Tooltip(
                message: 'Points this round',
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${s.target}',
                      style: const TextStyle(
                          fontFamily: displayFont,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: Palette.gold)),
                  const SizedBox(width: 4),
                  const CrownIcon(size: 18),
                ]),
              ),
              IconButton(
                tooltip: 'Leave the table',
                icon: const Icon(Icons.close_rounded),
                onPressed: _leave,
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                key: _stackKey,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Column(
                      children: [
                        _opponents(c.maxWidth - 32, c.maxHeight * 0.36),
                        Expanded(
                          child: SizedBox(
                              key: _middleKey,
                              width: double.infinity,
                              child: _middle(c.maxWidth - 32)),
                        ),
                        _status(),
                        const SizedBox(height: 6),
                        KeyedSubtree(
                            key: _yourTasksKey,
                            child: _yourTasks(c.maxWidth - 32)),
                        const SizedBox(height: 8),
                        _hand(c.maxWidth - 32),
                      ],
                    ),
                  ),
                  // The trick, and task cards in flight, glide above it all.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ..._trickLayer(),
                          for (final f in _flights) f.build(s.players),
                        ],
                      ),
                    ),
                  ),
                  if (s.phase == Phase.roundOver && match.lastTrick == null)
                    Positioned.fill(child: _roundOver()),
                ],
              ),
            ),
          ),
        ),
        // The brass inlay runs round the whole screen.
        const Positioned.fill(
            child: IgnorePointer(child: SafeArea(child: TableTrim()))),
      ],
    );
  }

  bool _active(int seat) => switch (s.phase) {
        Phase.picking => s.pickTurn == seat,
        Phase.playing => match.lastTrick == null && s.turn == seat,
        _ => false,
      };

  Widget _token(int seat, double size) => KeyedSubtree(
      key: _seatKeys[seat],
      child: SeatToken(
        player: seats[seat],
        label: _label(seat),
        isKing: s.king == seat,
        size: size,
        highlighted: _active(seat),
        shape: courtiers[seat].shape,
      ));

  Widget _miniTask(MatchTask t, double width) => TweenAnimationBuilder<double>(
      // Fades in as the flying copy lands.
      key: ValueKey('mini-${t.description}'),
      tween: Tween(begin: 0, end: 1),
      duration: _Flight.duration + const Duration(milliseconds: 120),
      curve: const Interval(0.75, 1),
      builder: (context, o, child) => Opacity(opacity: o, child: child),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: GestureDetector(
          onTap: () => _showTask(t),
          child: TableCard(
            task: t.task,
            points: t.task.getPointsForPlayerCount(s.players),
            text: _taskText(t),
            width: width,
            height: TableCard.sizeFor(_taskText(t), width).height,
            owner: t.owner == null ? null : seats[t.owner!],
            ownerLabel: t.owner == null ? null : _label(t.owner!),
          ),
        ),
      ));

  /// The card text, with the announced number filled in.
  String _taskText(MatchTask t) {
    final text = t.task.cardText(s.players);
    if (t.x == null) return text;
    final secret = t.description.contains('secret') &&
        t.owner != MatchController.human;
    return text.replaceFirst('X', secret ? '?' : '${t.x}');
  }

  void _showTask(MatchTask t) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.card,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SuitText(_taskText(t),
                style: const TextStyle(
                    fontSize: 20, height: 1.35, color: Palette.ink)),
            for (final n in t.task.notes)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SuitText(n,
                    style: const TextStyle(
                        fontSize: 15, color: Palette.inkSoft)),
              ),
            const SizedBox(height: 10),
            Text(
                t.owner == null
                    ? 'Not taken yet'
                    : '${_name(t.owner!)}${t.owner == MatchController.human ? ' hold' : ' holds'} this task. '
                        '${switch (t.verdict) {
                        Verdict.done => 'Done!',
                        Verdict.failed => 'Failed.',
                        Verdict.pending => 'Still open.',
                      }}',
                style: const TextStyle(fontSize: 15, color: Palette.ink)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Palette.ink),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// The bots across the top, each with their tasks.
  Widget _opponents(double width, double maxHeight) {
    final others = [
      for (int i = 1; i < s.players; i++) i,
    ];
    final colWidth = width / others.length;
    final taskWidth = math.min(colWidth - 8, 116.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final seat in others)
            SizedBox(
              width: colWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: colWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _token(seat, 40),
                      Text(courtiers[seat].short,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70)),
                      Text(
                          '${s.tricksWon(seat)} trick${s.tricksWon(seat) == 1 ? '' : 's'}'
                          ' · ${s.hands[seat].length} cards',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white54)),
                      for (final t in s.tasks.where((t) => t.owner == seat))
                        _miniTask(t, taskWidth),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The middle of the table: open tasks while picking, then the trick.
  Widget _middle(double width) {
    if (s.phase == Phase.picking || s.phase == Phase.announcing) {
      // Remember where each open task sits, to fly it from there.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openTaskRects = {
          for (final e in _openTaskKeys.entries)
            if (s.tasks.length > e.key && s.tasks[e.key].owner == null)
              if (_rect(e.value) case final r?) e.key: r,
        };
      });
      final open = [
        for (int i = 0; i < s.tasks.length; i++)
          if (s.tasks[i].owner == null) i
      ];
      final w = math.min(118.0, (width - 16) / 3);
      return Center(
        child: SingleChildScrollView(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in open)
                Opacity(
                  key: _openTaskKeys.putIfAbsent(i, GlobalKey.new),
                  opacity: match.yourPick && !s.canTake(i, MatchController.human)
                      ? 0.45
                      : 1,
                  child: GestureDetector(
                    onTap: match.yourPick
                        ? () {
                            if (s.canTake(i, MatchController.human)) {
                              match.send(PickTask(MatchController.human, i));
                            } else {
                              _snack("The King can't take this task");
                            }
                          }
                        : () => _showTask(s.tasks[i]),
                    onLongPress: () => _showTask(s.tasks[i]),
                    child: TableCard(
                      task: s.tasks[i].task,
                      points: s.tasks[i].task.getPointsForPlayerCount(s.players),
                      text: _taskText(s.tasks[i]),
                      width: w,
                      height: TableCard.sizeFor(_taskText(s.tasks[i]), w).height,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    // The trick itself is drawn in the layer above (see [_trickLayer]).
    return const SizedBox.expand();
  }

  /// The cards of the trick: each glides in from whoever played it, and
  /// once the trick is won they sweep off to the winner.
  List<Widget> _trickLayer() {
    if (s.phase == Phase.picking || s.phase == Phase.announcing) return [];
    final middle = _rect(_middleKey);
    if (middle == null) return [];
    final trick = match.lastTrick;
    final seatsShown = trick?.seats ?? s.currentSeats;
    final cards = trick?.cards ?? s.current;
    final number = trick != null ? s.tricks.length - 1 : s.tricks.length;
    final n = s.players;
    final cardW = math.min(64.0, (middle.width - 10 * n) / n);
    final cardH = PlayingCardView.heightFor(cardW);
    final hand = _rect(_handKey);

    Offset origin(int seat, PlayingCard card) {
      if (seat == MatchController.human) {
        return _launchFrom[card.id] ??
            (hand?.topCenter ?? middle.bottomCenter);
      }
      return _rect(_seatKeys[seat])?.center ?? middle.topCenter;
    }

    return [
      for (int i = 0; i < cards.length; i++)
        () {
          final target = middle.center +
              Offset((i - (n - 1) / 2) * (cardW + 10), 0);
          final card = cards[i];
          final seat = seatsShown[i];
          final view = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: seats[seat].color, shape: BoxShape.circle),
                child: OutlinedLabel(_label(seat),
                    fontSize: seat == MatchController.human ? 8 : 12,
                    strokeWidth: 2),
              ),
              const SizedBox(height: 4),
              PlayingCardView(
                card: card,
                width: cardW,
                glow: trick != null && trick.winner == seat,
              ),
            ],
          );
          // Centre of the card, which sits below its 26px badge.
          Offset topLeft(Offset centre) =>
              centre - Offset(cardW / 2, cardH / 2 + 13);
          if (trick != null && _collecting) {
            final to = origin(trick.winner, card);
            return TweenAnimationBuilder<double>(
              key: ValueKey('collect-$number-${card.id}'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeInCubic,
              builder: (context, t, child) {
                final p = topLeft(Offset.lerp(target, to, t)!);
                return Positioned(
                  left: p.dx,
                  top: p.dy,
                  child: Opacity(
                    opacity: 1 - t * 0.9,
                    child: Transform.scale(scale: 1 - 0.5 * t, child: child),
                  ),
                );
              },
              child: view,
            );
          }
          final from = origin(seat, card);
          return TweenAnimationBuilder<double>(
            key: ValueKey('play-$number-${card.id}'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              final p = topLeft(Offset.lerp(from, target, t)!);
              return Positioned(left: p.dx, top: p.dy, child: child!);
            },
            child: view,
          );
        }(),
    ];
  }

  Widget _status() {
    final String text;
    final trick = match.lastTrick;
    if (trick != null) {
      text = trick.winner == MatchController.human
          ? 'You win the trick'
          : '${_name(trick.winner)} wins the trick';
    } else {
      text = switch (s.phase) {
        Phase.picking => match.yourPick
            ? 'Your pick: tap a task to take it'
            : '${_name(s.pickTurn ?? 0)} is choosing a task…',
        Phase.announcing => 'Announcing numbers…',
        Phase.playing => match.yourPlay
            ? (s.current.isEmpty
                ? 'Your lead: play any card'
                : 'Your turn: follow ${s.led!.isCourt ? 'with a Court Card' : s.led!.suit.symbol} if you can')
            : '${_name(s.turn)} is thinking…',
        Phase.roundOver => s.won == true ? 'Round won' : 'Round lost',
      };
    }
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: match.yourPick || match.yourPlay
              ? Palette.gold
              : Colors.white70),
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  Widget _yourTasks(double width) {
    final mine = s.tasks.where((t) => t.owner == MatchController.human).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _token(MatchController.human, 44),
            Text('${s.tricksWon(MatchController.human)} tricks',
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: mine.isEmpty
              ? Text(
                  s.phase == Phase.picking
                      ? 'Your tasks will appear here'
                      : 'No tasks for you this round',
                  style: const TextStyle(color: Colors.white54))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final t in mine)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _miniTask(t, math.min(116.0, width / 3.4)),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// Your hand, fanned to fit. Cards you may play stand up; tap one to
  /// play it.
  Widget _hand(double width) {
    final hand = s.hands[MatchController.human];
    if (hand.isEmpty) return const SizedBox(height: 40);
    final legal = match.yourPlay
        ? s.legalFor(MatchController.human).toSet()
        : const <PlayingCard>{};
    final cardW = clampD(width / 6.2, 46, 78);
    final h = PlayingCardView.heightFor(cardW);
    final step = hand.length == 1
        ? 0.0
        : math.min(cardW + 6, (width - cardW) / (hand.length - 1));
    final total = cardW + step * (hand.length - 1);
    return SizedBox(
      key: _handKey,
      height: h + 14,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < hand.length; i++)
            AnimatedPositioned(
              key: ValueKey(hand[i].id),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: (width - total) / 2 + i * step,
              top: legal.contains(hand[i]) ? 0 : 14,
              child: GestureDetector(
                onTap: () {
                  if (!match.yourPlay) return;
                  final why =
                      s.problem(PlayCard(MatchController.human, hand[i]));
                  if (why != null) {
                    _snack(why);
                    return;
                  }
                  final area = _rect(_handKey);
                  if (area != null) {
                    _launchFrom[hand[i].id] = area.topLeft +
                        Offset((width - total) / 2 + i * step + cardW / 2,
                            h / 2);
                  }
                  match.send(PlayCard(MatchController.human, hand[i]));
                },
                child: PlayingCardView(
                  card: hand[i],
                  width: cardW,
                  dimmed: match.yourPlay && !legal.contains(hand[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(text),
          backgroundColor: Palette.feltDeep,
          duration: const Duration(seconds: 2)));
  }

  Widget _roundOver() {
    final won = s.won == true;
    final fg = won ? Palette.ink : Colors.white;
    final failed = s.tasks.where((t) => t.verdict == Verdict.failed);
    return ColoredBox(
      color: Colors.black38,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: won ? Palette.gold : Palette.feltDeep,
            borderRadius: BorderRadius.circular(16),
            border: won ? null : Border.all(color: Palette.lost, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CrownIcon(size: 44, color: won ? Palette.ink : Palette.lost),
                Text(won ? 'Round won' : 'Round lost',
                    style: TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        color: fg)),
                const SizedBox(height: 4),
                if (won)
                  Text('Every task is done. The court rejoices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: fg))
                else
                  for (final t in failed)
                    SuitText(
                        '${_name(t.owner!)} failed: ${_taskText(t)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: fg)),
                const SizedBox(height: 6),
                Text('Won ${s.wins}, lost ${s.losses}. Streak ${s.streak}.',
                    style: TextStyle(
                        fontSize: 14, color: won ? Palette.ink : Colors.white70)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _nextTarget > 1
                          ? () => setState(() => _nextTarget--)
                          : null,
                      icon: Icon(Icons.remove_circle_outline, color: fg),
                    ),
                    Text('$_nextTarget',
                        style: TextStyle(
                            fontFamily: displayFont,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            color: fg)),
                    const SizedBox(width: 4),
                    CrownIcon(size: 18, color: fg),
                    IconButton(
                      onPressed: _nextTarget < 30
                          ? () => setState(() => _nextTarget++)
                          : null,
                      icon: Icon(Icons.add_circle_outline, color: fg),
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: () => match.nextRound(_nextTarget),
                  style: won
                      ? FilledButton.styleFrom(
                          backgroundColor: Palette.ink,
                          foregroundColor: Palette.gold)
                      : null,
                  child: const Text('Next round'),
                ),
                TextButton(
                  onPressed: _leave,
                  style: TextButton.styleFrom(
                      foregroundColor: won ? Palette.ink : Colors.white70),
                  child: const Text('Leave the table'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A task card on its way from the middle of the table to its new owner,
/// shrinking as it goes.
class _Flight {
  _Flight(this.task, this.from, this.to);
  final MatchTask task;
  final Rect from;
  final Rect to;

  static const duration = Duration(milliseconds: 480);

  Widget build(int players) => TweenAnimationBuilder<double>(
        key: ObjectKey(this),
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeInOutCubic,
        builder: (context, t, child) =>
            Positioned.fromRect(rect: Rect.lerp(from, to, t)!, child: child!),
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: from.width,
            height: from.height,
            child: TableCard(
              task: task.task,
              points: task.task.getPointsForPlayerCount(players),
              text: task.task.cardText(players),
              width: from.width,
              height: from.height,
            ),
          ),
        ),
      );
}
