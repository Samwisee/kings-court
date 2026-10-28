// Task cards on the on-screen table, their flights to their owners, and the close-up’s parts.
part of '../main.dart';

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
    this.onTap,
    this.onLongPress,
    this.struck = const {},
    this.focused = false,
  });

  /// Chosen with the arrow keys: it glows gold.
  final bool focused;

  final Task task;
  final int points;
  final String text;
  final Color color;
  final double width;
  final double fontSize;
  final String? progress;

  /// Cards the task names that its owner has already won.
  final Set<String> struck;
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
        // Always shown: the words leave "with no Court Cards" to it.
        if (task.noCourtCards) ...[
          const SizedBox(width: 4),
          Tooltip(
              message: 'No Court Cards in the trick',
              child: NoCourtIcon(size: fontSize + 2)),
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
    // Nobody's yet: just the card in its dark outline (the band is there,
    // in the card's own colour, so nothing shifts once it's taken). A
    // player's colour gets dark lines on both sides.
    final neutral = !failed && color == Palette.inkSoft;
    final front = CustomPaint(
      foregroundPainter:
          neutral ? null : const InnerEdge(radius: 8, inset: 2.5 + outlineWidth),
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      decoration: BoxDecoration(
        color: failed ? Palette.failedCard : Palette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: failed ? Palette.lost : neutral ? Palette.card : color,
            width: 2.5 + 2 * outlineWidth),
        boxShadow: [
          const BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1)),
          if (focused)
            BoxShadow(
                color: Palette.gold.withValues(alpha: 0.9), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: outlineColour, width: outlineWidth),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          top,
          const SizedBox(height: 3),
          SuitText(text,
              struck: struck,
              keywords: false,
              style: TextStyle(
                  fontSize: fontSize,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: Palette.ink)),
        ],
      ),
    ),
    );
    // Done: the chip turns over to show a seal of completion. Chosen with
    // the arrow keys: ringed and lifted a little, so it's plain to see.
    return AnimatedScale(
      scale: focused ? 1.05 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: KeyFocusRing(
      on: focused,
      radius: 8,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
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
              child: CustomPaint(
              foregroundPainter: const InnerEdge(radius: 8, inset: 2.5 + outlineWidth),
              child: Container(
                decoration: BoxDecoration(
                  color: Palette.feltDeep,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: 2.5 + 2 * outlineWidth),
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: outlineColour, width: outlineWidth),
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
                    CrownIcon(size: fontSize * 1.5),
                  ],
                ),
              ),
              ),
            ),
          ]),
        ),
      ),
      )),
      ),
    );
  }
}

/// A card a task is about, marked as in the card tracker.
typedef _TaskCard = ({PlayingCard card, Color? edge, int? trick, bool played});

/// The cards a task is about, each marked the way the card tracker marks
/// it: who played it and in which trick, or who holds it.
class _TaskCardsRow extends StatelessWidget {
  const _TaskCardsRow({required this.cards});
  final List<_TaskCard> cards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in cards)
            Semantics(
              label: '${c.card.spoken}: ${c.played ? 'played in trick ${c.trick}' : c.edge != null ? 'held' : 'still to come'}',
              excludeSemantics: true,
              child: _MiniCard(
                  card: c.card,
                  width: 32,
                  dimmed: c.played,
                  edge: c.edge,
                  trick: c.trick),
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
          icon: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20),
          label: Text(_open ? 'Less' : 'What does this task mean?'),
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
                  ],
                ),
        ),
      ],
    );
  }
}
