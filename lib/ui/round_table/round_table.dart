/// The round table: the seats around the edge, the deck in the middle
/// before the King is crowned, then the task cards dealt out onto the felt
/// to be read, dragged to a seat or back, with the crowning and "Play!"
/// over it. Its own state is where everything lies ([RoundTableController]);
/// what a tap or a drop means is the page's.
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../engine/round.dart';
import '../../game/state.dart';
import '../../skin/skin.dart';
import '../overlays/crowning.dart';
import '../overlays/king_prompt.dart';
import '../overlays/play_flourish.dart';
import '../widgets.dart';
import 'geometry.dart';

/// Where everything lies on the round table: each dealt task's centre (as
/// a fraction of the table, so it survives rotation and resizes) and tilt,
/// the order the cards are drawn in (the last on top), the card being
/// dragged and the seat under it, which deal has been laid out, the
/// table's size and the card width it was dealt at, and the deal.
class RoundTableController {
  RoundTableController({required TickerProvider vsync})
      : deal = AnimationController(
            vsync: vsync, duration: const Duration(milliseconds: 2200));

  /// The cards flying out from the middle.
  final AnimationController deal;

  final Map<RoundTask, Offset> pos = {};
  final Map<RoundTask, double> tilt = {};

  /// Draw order: the last card is on top.
  List<RoundTask> order = [];

  RoundTask? dragging;
  int? hoverSeat;

  /// The deal laid out on the table; -1 for none.
  int dealtFor = -1;
  Size tableSize = Size.zero;
  double cardWidth = 120;

  /// The table's stack, to turn screen positions into table ones.
  final key = GlobalKey();

  /// Ticks as a task card is dragged; only that card listens, so moving it
  /// redraws that card alone.
  final taskDragTick = ValueNotifier(0);
  final stillTick = ValueNotifier(0);

  /// Where the finger is during a drag, and where it was when the card
  /// was let go.
  Offset? lastPointer;
  Offset? dropAt;

  /// The seat a dragged card was dropped on: under the finger if there's
  /// one there (a card near the edge is held back from the edge, but the
  /// finger isn't), otherwise under the card.
  int? dropSeat(TableGeometry geo, Offset cardCentre) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final at = dropAt;
    dropAt = null;
    if (box != null && at != null) {
      final seat = geo.seatAt(box.globalToLocal(at));
      if (seat != null) return seat;
    }
    return geo.seatAt(cardCentre);
  }


  Offset toPx(Offset f) => Offset(f.dx * tableSize.width, f.dy * tableSize.height);
  Offset toFrac(Offset p) => Offset(p.dx / tableSize.width, p.dy / tableSize.height);

  /// The table's geometry for [players] seats, the cards fixed at the
  /// width they were dealt at while this deal is on the table.
  TableGeometry geometry(
          {required int players,
          required String Function(RoundTask) textOf,
          required bool upright,
          required int dealId,
          required Skin skin}) =>
      TableGeometry(tableSize, players, textOf,
          fixedCardWidth: dealtFor == dealId ? cardWidth : null,
          upright: upright,
          skin: skin);

  /// The table's layout as a save keeps it beside [game].
  Map<String, dynamic> saveData(GameState game) => {
        'cardWidth': cardWidth,
        'dealt': dealtFor == game.dealId,
        'pos': [
          for (final t in game.tasks)
            if (pos[t] != null) [pos[t]!.dx, pos[t]!.dy] else null,
        ],
        'tilt': [for (final t in game.tasks) tilt[t] ?? 0.0],
      };

  /// The layout a save kept ([saveData]) back on the table, when it's
  /// whole: then the deal is already laid out, with no deal to play.
  void restore(Map<String, dynamic> data, GameState g) {
    final pos = data['pos'] as List;
    final tilt = data['tilt'] as List;
    if (data['dealt'] != true || pos.length != g.tasks.length || pos.any((p) => p == null)) return;
    cardWidth = (data['cardWidth'] as num).toDouble();
    for (var i = 0; i < g.tasks.length; i++) {
      final p = pos[i] as List;
      this.pos[g.tasks[i]] = Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
      this.tilt[g.tasks[i]] = (tilt[i] as num).toDouble();
    }
    order = List.of(g.tasks);
    dealtFor = g.dealId;
  }

  /// Clears the table for a new deal.
  void reset() {
    pos.clear();
    tilt.clear();
    order = [];
    dealtFor = -1;
    deal.reset();
  }

  /// Deals [tasks] (deal [dealId]) out from the middle of the table, each
  /// to its place with a slight tilt; a task only one player may take goes
  /// straight to them.
  void dealCards(TableGeometry geo, List<RoundTask> tasks, int dealId) {
    final targets = geo.dealPositions(tasks);
    cardWidth = geo.cardWidth;
    final rand = math.Random(dealId);
    order = List.of(tasks);
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      pos[t] = toFrac(targets[i]);
      tilt[t] = (rand.nextDouble() - 0.5) * 0.08; // a few degrees
    }
    dealtFor = dealId;
    if (tasks.any((t) => t.owner != null)) layoutOwned(geo);
    deal.forward(from: 0);
  }

  /// Re-stacks every player's cards after one is added or removed.
  void layoutOwned(TableGeometry geo) {
    geo.layoutOwned(order).forEach((t, p) {
      pos[t] = toFrac(geo.clampToTable(p, geo.cardSize(t)));
    });
  }


  /// [t] is picked up: it comes to the top.
  void dragStart(RoundTask t) {
    dragging = t;
    order
      ..remove(t)
      ..add(t);
  }

  /// [t] moves by [delta] (screen pixels), kept on the table; gives the
  /// seat under it that [mayTake] it, if any.
  int? dragMove(RoundTask t, Offset delta, TableGeometry geo,
      bool Function(RoundTask, int) mayTake) {
    final p = geo.clampToTable(toPx(pos[t]!) + delta, geo.cardSize(t));
    pos[t] = toFrac(p);
    final seat = geo.seatAt(p);
    return seat != null && mayTake(t, seat) ? seat : null;
  }

  void dispose() {
    deal.dispose();
    taskDragTick.dispose();
    stillTick.dispose();
  }
}

class RoundTable extends StatefulWidget {
  const RoundTable({
    super.key,
    required this.table,
    required this.game,
    required this.geometry,
    required this.onScreen,
    required this.choosingKing,
    required this.crowning,
    required this.crownAnimation,
    required this.playAnimation,
    required this.readyToDeal,
    required this.onDeal,
    required this.seatTap,
    required this.cardText,
    required this.onTaskTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final RoundTableController table;
  final GameState game;

  /// The table's geometry at its current size.
  final TableGeometry Function() geometry;
  final bool onScreen;

  /// Before the King is crowned: the deck and the prompt.
  final bool choosingKing;

  /// The seat being crowned while the crown flies, if one is.
  final int? crowning;
  final Animation<double> crownAnimation;
  final Animation<double> playAnimation;

  /// The cards can be dealt: [onDeal] is called after the frame.
  final bool readyToDeal;
  final VoidCallback onDeal;

  /// What tapping a seat does right now, if anything.
  final VoidCallback? Function(int seat) seatTap;

  /// A task's wording on its card.
  final String Function(RoundTask) cardText;
  final void Function(RoundTask, Offset globalPosition) onTaskTap;
  final void Function(RoundTask) onDragStart;
  final void Function(RoundTask, Offset delta) onDragUpdate;
  final void Function(RoundTask) onDragEnd;

  @override
  State<RoundTable> createState() => _RoundTableState();
}

class _RoundTableState extends State<RoundTable> {
  /// While someone holds the felt: the seat nearest their finger. Every
  /// card turns to face that side of the table.
  int? _readerSeat;

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    final game = widget.game;
    final round = game.round!;
    return LayoutBuilder(builder: (context, c) {
      table.tableSize = Size(c.maxWidth, c.maxHeight);
      if (widget.readyToDeal) {
        // Deal once the King is crowned, any decree has been read, and the
        // table size is known.
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDeal());
      }
      final geo = widget.geometry();
      final labels = seatLabels(game.players);

      return Stack(
        key: table.key,
        clipBehavior: Clip.none,
        children: [
          // The felt: press and hold to turn every card towards you.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: widget.choosingKing
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
                    isKing: round.king == i,
                    size: geo.seatSize,
                    highlighted: table.hoverSeat == i,
                    prompting: widget.choosingKing && widget.crowning == null,
                    picking: !widget.choosingKing &&
                        table.dealtFor == game.dealId &&
                        round.pickTurn == i,
                    exiled: round.exiledSeat == i,
                    speakLocked: !round.canSpeak(i),
                    shape: game.hasRoles && i < game.courtiers.length
                        ? game.courtiers[i].shape
                        : null,
                    spoke: widget.choosingKing || widget.onScreen ? null : round.spoke[i],
                    onTap: widget.seatTap(i),
                  ),
                ),
              ),
            ),
          if (widget.choosingKing)
            Center(
              child: AnimatedOpacity(
                opacity: widget.crowning == null ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: KingPrompt(
                    maxWidth: math.max(160, geo.size.width - 2 * geo.seatExtent),
                    cardWidth: geo.cardWidth,
                    onScreen: widget.onScreen,
                    players: game.players.length),
              ),
            )
          else if (table.dealtFor == game.dealId)
            Positioned.fill(child: _buildCards(geo)),
          if (widget.crowning case final seat?)
            Positioned.fill(
                child: IgnorePointer(child: _buildCrowning(geo, seat))),

          // "Play!" once every task has an owner.
          Positioned.fill(
              child: IgnorePointer(child: PlayFlourish(animation: widget.playAnimation))),

        ],
      );
    });
  }

  /// The crowning: the crown rises from the deck, arcs to the new King's
  /// seat and lands with a bounce and a ring of gold sparks, while "Long
  /// live the King" glows in the middle of the table.
  Widget _buildCrowning(TableGeometry geo, int seat) {
    final a = geo.facing(seat);
    final up = Offset(math.sin(a), -math.cos(a));
    return CrowningScene(
      animation: widget.crownAnimation,
      from: geo.center,
      to: geo.seatCenter(seat) + up * (geo.seatSize / 2 + 9),
      spinTo: a,
      seatSize: geo.seatSize,
      king: seat,
      seats: {
        for (int j = 0; j < widget.game.players.length; j++) j: geo.seatCenter(j)
      },
    );
  }

  Widget _buildCards(TableGeometry geo) {
    final table = widget.table;
    final game = widget.game;
    return AnimatedBuilder(
      animation: table.deal,
      builder: (context, _) {
        final n = game.tasks.length;
        final dealing = table.deal.isAnimating;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final t in table.order)
              ValueListenableBuilder<int>(
                // Only the card being dragged listens to the drag, so moving
                // it redraws that card alone.
                key: ObjectKey(t),
                valueListenable: table.dragging == t ? table.taskDragTick : table.stillTick,
                builder: (context, tick, child) {
                // Each card leaves the deck a moment after the one before.
                final i = game.tasks.indexOf(t);
                final start = n <= 1 ? 0.0 : i / n * 0.55;
                final progress = Interval(start, math.min(1.0, start + 0.45),
                        curve: Curves.easeOutCubic)
                    .transform(table.deal.value);
                final target = table.toPx(table.pos[t]!);
                final p = dealing
                    ? Offset.lerp(geo.center, target, progress)!
                    : target;
                // Cards travel face down and turn over as they land.
                final faceDown = dealing && progress < 0.98;
                final owner = t.owner;
                final lifted = table.dragging == t;
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
                            : (table.tilt[t] ?? 0.0);

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
                        onTapUp: (d) => widget.onTaskTap(t, d.globalPosition),
                        onPanStart: (d) {
                          table.lastPointer = d.globalPosition;
                          widget.onDragStart(t);
                        },
                        onPanUpdate: (d) {
                          // Use screen movement, not the card's rotated
                          // local axes, so the card follows the finger.
                          final last = table.lastPointer ?? d.globalPosition;
                          table.lastPointer = d.globalPosition;
                          widget.onDragUpdate(t, d.globalPosition - last);
                        },
                        onPanEnd: (_) {
                          table.dropAt = table.lastPointer;
                          table.lastPointer = null;
                          widget.onDragEnd(t);
                        },
                        child: AnimatedScale(
                          scale: lifted ? 1.08 : 1,
                          duration: const Duration(milliseconds: 120),
                          child: TableCard(
                            task: t,
                            points: t.points(game.players.length),
                            text: widget.cardText(t),
                            width: cw,
                            height: ch,
                            owner: owner == null ? null : game.players[owner],

                            lifted: lifted,
                            faceDown: faceDown,
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
}
