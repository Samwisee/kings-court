/// Task cards on a real table, the deck, wax seals and decree scrolls.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/round.dart';
import '../../game/state.dart';
import '../../skin/looks.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../../skin/theme.dart';
import 'back_motifs.dart';
import 'clamp.dart';
import 'icons.dart';
import 'seals.dart';
import 'suit_text.dart';
import 'table.dart';
import 'task_faces.dart';

/// One pip per task: hollow while pending, green when done, red when failed.
class TaskPips extends StatelessWidget {
  const TaskPips({super.key, required this.tasks});
  final List<RoundTask> tasks;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final t in tasks)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: switch (t.status) {
                TaskStatus.completed => skin.won,
                TaskStatus.failed => skin.lost,
                TaskStatus.pending => const Color(0x33FFFFFF),
              },
              border: Border.all(
                color: t.status == TaskStatus.pending
                    ? Colors.white
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
      ],
    );
  }
}

/// A small task card lying on the table. Points sit in the corner where a
/// playing card's rank would be, with icons for extra conditions under
/// them; the owner's colour edges the card and their seat label sits in a
/// badge. When the task is done the card flips over to show its back.
class TableCard extends StatelessWidget {
  const TableCard({
    super.key,
    required this.task,
    required this.points,
    required this.width,
    this.height,
    this.text,
    this.owner,
    this.ownerLabel,
    this.lifted = false,
    this.faceDown = false,
    this.progress,
  });

  final RoundTask task;

  /// How far along the task is, e.g. "2/4", shown in the bottom corner.
  final String? progress;

  /// Dynasty: a royal charge, dealt straight to one house.
  final int points;
  final double width;

  /// Defaults to [heightFor]; use [sizeFor] to fit long tasks.
  final double? height;

  /// The wording to print; defaults to the full description.
  final String? text;
  final Player? owner;
  final String? ownerLabel;
  final bool lifted;

  /// Shows the deck back, e.g. while the card is being dealt.
  final bool faceDown;

  /// Smallest size the task text may shrink to, relative to the skin's
  /// task text.
  static const minTextScale = 12 / 13.5;

  // The same look as the task cards in on-screen games: points and
  // conditions along the top, the tracker top right, the words beneath.
  static double heightFor(double width) => width * 0.6;
  static double _indexSize(double width) => clampD(width * 0.15, 13, 18);
  static const _pad = 6.0;
  static const _badgeRoom = 14.0;

  /// Card size for [text] at [width]: the usual shape, but taller when the
  /// task needs it so its text never shrinks below [minTextScale].
  static Size sizeFor(Skin skin, String text, double width, {bool sealed = false}) {
    final textWidth = width - 2 * _pad;
    final painter = TextPainter(
      text: TextSpan(text: text, style: skin.taskText),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textWidth / minTextScale);
    final needed = painter.height * minTextScale +
        _indexSize(width) +
        3 +
        2 * _pad +
        _badgeRoom;
    painter.dispose();
    return Size(width, math.min(math.max(heightFor(width), needed), width * 1.3));
  }

  double get _height => height ?? heightFor(width);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: faceDown || task.isCompleted ? math.pi : 0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      builder: (context, angle, _) {
        final showBack = angle > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015) // perspective
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  // Only a done task shows the seal; anything else (e.g. a
                  // card turning over as it's dealt) shows the deck back.
                  child: task.isCompleted && !faceDown ? _back(skin) : _deckBack(skin),
                )
              : _front(skin),
        );
      },
    );
  }

  BoxDecoration _frame(Skin skin, Color color, {Color? border, double borderWidth = 1}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: border ?? const Color(0xFFE6E0D4),
          width: borderWidth + 2 * skin.outlineWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: lifted ? 14 : 4,
            offset: Offset(0, lifted ? 7 : 2),
          ),
        ],
      );

  /// The dark outline, drawn over the outer edge of the frame so it's the
  /// same width all the way round.
  static BoxDecoration _edge(Skin skin) => BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: skin.outlineColour, width: skin.outlineWidth),
  );

  /// A dark line just inside the coloured border, so the colour has dark
  /// on both sides.
  static Widget _innerEdged(Skin skin, Widget child) => CustomPaint(
      foregroundPainter: InnerEdge(radius: 8, inset: 2.5 + skin.outlineWidth),
      child: child);

  Widget _ownerBadge(Skin skin) {
    final o = owner;
    if (o == null || ownerLabel == null) return const SizedBox.shrink();
    return Positioned(
      right: 4,
      bottom: 4,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: o.color,
          borderRadius: BorderRadius.circular(9),
        ),
        child: OutlinedLabel(ownerLabel!, fontSize: 12, strokeWidth: 2.2),
      ),
    );
  }

  Widget _front(Skin skin) {
    final indexSize = _indexSize(width);
    final iconSize = indexSize * 0.8;
    final failed = task.isFailed;
    // A failed task is on the failed card, in the skin's own ink.
    final look = failed ? TaskLook(face: skin.failedCard, ink: skin.ink, inkSoft: skin.inkSoft) : skin.taskLook;
    final top = Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$points',
                  style: TextStyle(
                      fontFamily: skin.displayFont,
                      fontWeight: FontWeight.w900,
                      fontSize: indexSize,
                      height: 1,
                      color: look.ink)),
              const SizedBox(width: 2),
              CrownIcon(size: indexSize * 0.7, color: look.crown ?? skin.goldDeep),
              // Conditions that don't fit in words: tap the card to read.
              if (task.kingCantTake) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: "The King can't take this task",
                  child: Icon(Icons.block, size: iconSize, color: look.inkSoft),
                ),
              ],
              if (task.noCourtCards) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'No Court Cards in the trick',
                  child: NoCourtIcon(size: iconSize * 1.05),
                ),
              ],
              if (task.hasNotes) ...[
                const SizedBox(width: 3),
                Tooltip(
                  message: task.notes.join(' '),
                  child: Icon(Icons.info_outline,
                      size: iconSize, color: look.inkSoft),
                ),
              ],
              if (task.seal != null) ...[
                const SizedBox(width: 3),
                WaxSeal(seal: task.seal!, size: indexSize + 3),
              ],
            ]),
          ),
        ),
        if (failed)
          Icon(Icons.cancel, size: iconSize + 2, color: skin.lost)
        else if (progress != null && !task.isCompleted)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width * 0.55),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: look.ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(progress!,
                    style: TextStyle(
                        fontFamily: skin.bodyFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: look.pillInk(skin.gold))),
              ),
            ),
          ),
      ],
    );
    // Nobody's yet: just the card and its dark outline. A player's (or a
    // failed task's) colour gets dark lines on both sides.
    final neutral = !failed && owner == null;
    final card = Container(
      width: width,
      height: _height,
      foregroundDecoration: _edge(skin),
      decoration: _frame(skin, 
        failed ? skin.failedCard : look.face,
        border: failed ? skin.lost : owner?.color ?? look.face,
        borderWidth: 2.5,
      ),
      child: Stack(
        children: [
          if (!failed && TaskFacePainter.prints(look))
            Positioned.fill(child: CustomPaint(painter: TaskFacePainter(look, reach: EdgeInsets.zero))),
          Padding(
            padding: const EdgeInsets.fromLTRB(_pad, _pad - 2, _pad, _pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                top,
                const SizedBox(height: 3),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: owner == null ? 0 : _badgeRoom),
                    child: LayoutBuilder(
                      builder: (context, c) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: c.maxWidth,
                          child: SuitText(text ?? task.description,
                              keywords: false,
                              style: skin.taskText.copyWith(fontWeight: FontWeight.w600, color: look.ink)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _ownerBadge(skin),
        ],
      ),
    );
    return neutral ? card : _innerEdged(skin, card);
  }

  /// The plain deck back, as dealt.
  Widget _deckBack(Skin skin) {
    return Container(
      width: width,
      height: _height,
      foregroundDecoration: _edge(skin),
      decoration: _frame(skin, skin.cardLook.back, border: skin.gold, borderWidth: 1.5),
      child: BackGround(radius: 6, child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: skin.gold.withValues(alpha: 0x99 / 255)),
        ),
        alignment: Alignment.center,
        child: CrownIcon(size: width * 0.28),
      )),
    );
  }

  /// The back of a done task: the deck's design, a gold inlay and a seal
  /// with a check.
  Widget _back(Skin skin) {
    final seal = clampD(width * 0.3, 22, 34);
    return _innerEdged(skin, Container(
      width: width,
      height: _height,
      foregroundDecoration: _edge(skin),
      decoration: _frame(skin, skin.cardLook.back,
          border: owner?.color ?? skin.gold, borderWidth: 2.5),
      child: Stack(
        children: [
          // The card backs worn.
          const Positioned.fill(child: BackGround(radius: 6)),
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: skin.gold.withValues(alpha: 0x99 / 255)),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CrownIcon(size: 14),
                const SizedBox(height: 2),
                Container(
                  width: seal,
                  height: seal,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: skin.won,
                    border: Border.all(color: skin.gold, width: 2),
                  ),
                  child: Icon(Icons.check_rounded,
                      size: seal * 0.7, color: Colors.white),
                ),
              ],
            ),
          ),
          _ownerBadge(skin),
        ],
      ),
    ));
  }
}

/// The face-down deck in the middle of the table, shown before dealing.
class DeckStack extends StatelessWidget {
  const DeckStack({super.key, this.width = 90});
  final double width;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final h = TableCard.heightFor(width);
    return SizedBox(
      width: width + 12,
      height: h + 12,
      child: Stack(
        children: [
          for (int i = 0; i < 3; i++)
            Positioned(
              left: i * 4.0,
              top: (2 - i) * 4.0,
              child: Container(
                width: width,
                height: h,
                decoration: BoxDecoration(
                  color: skin.feltDeep,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: skin.gold, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
                alignment: Alignment.center,
                child: i == 2
                    ? const CrownIcon(size: 28)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
