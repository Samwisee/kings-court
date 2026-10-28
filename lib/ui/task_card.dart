// Task cards on a real table, the deck, wax seals and decree scrolls.
part of '../widgets.dart';

/// One pip per task: hollow while pending, green when done, red when failed.
class TaskPips extends StatelessWidget {
  const TaskPips({super.key, required this.tasks});
  final List<RoundTask> tasks;

  @override
  Widget build(BuildContext context) {
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
                TaskStatus.completed => Palette.won,
                TaskStatus.failed => Palette.lost,
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

  static const textStyle = TextStyle(
    fontFamily: bodyFont,
    fontSize: 13.5,
    height: 1.15,
    fontWeight: FontWeight.w500,
    color: Palette.ink,
  );

  /// Smallest size the task text may shrink to, relative to [textStyle].
  static const minTextScale = 12 / 13.5;

  // The same look as the task cards in on-screen games: points and
  // conditions along the top, the tracker top right, the words beneath.
  static double heightFor(double width) => width * 0.6;
  static double _indexSize(double width) => clampD(width * 0.15, 13, 18);
  static const _pad = 6.0;
  static const _badgeRoom = 14.0;

  /// Card size for [text] at [width]: the usual shape, but taller when the
  /// task needs it so its text never shrinks below [minTextScale].
  static Size sizeFor(String text, double width, {bool sealed = false}) {
    final textWidth = width - 2 * _pad;
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
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
                  child: task.isCompleted && !faceDown ? _back() : _deckBack(),
                )
              : _front(),
        );
      },
    );
  }

  BoxDecoration _frame(Color color, {Color? border, double borderWidth = 1}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: border ?? const Color(0xFFE6E0D4),
          width: borderWidth + 2 * outlineWidth,
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
  static final _edge = BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: outlineColour, width: outlineWidth),
  );

  /// A dark line just inside the coloured border, so the colour has dark
  /// on both sides.
  static Widget _innerEdged(Widget child) => CustomPaint(
      foregroundPainter: const InnerEdge(radius: 8, inset: 2.5 + outlineWidth),
      child: child);

  Widget _ownerBadge() {
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

  Widget _front() {
    final indexSize = _indexSize(width);
    final iconSize = indexSize * 0.8;
    final failed = task.isFailed;
    final top = Row(
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
                      fontSize: indexSize,
                      height: 1,
                      color: Palette.ink)),
              const SizedBox(width: 2),
              CrownIcon(size: indexSize * 0.7, color: Palette.goldDeep),
              // Conditions that don't fit in words: tap the card to read.
              if (task.kingCantTake) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: "The King can't take this task",
                  child: Icon(Icons.block, size: iconSize, color: Palette.inkSoft),
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
                      size: iconSize, color: Palette.inkSoft),
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
          Icon(Icons.cancel, size: iconSize + 2, color: Palette.lost)
        else if (progress != null && !task.isCompleted)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width * 0.55),
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
                    style: const TextStyle(
                        fontFamily: bodyFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: Palette.gold)),
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
      foregroundDecoration: _edge,
      decoration: _frame(
        failed ? Palette.failedCard : Palette.card,
        border: failed ? Palette.lost : owner?.color ?? Palette.card,
        borderWidth: 2.5,
      ),
      child: Stack(
        children: [
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
                              style: textStyle.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _ownerBadge(),
        ],
      ),
    );
    return neutral ? card : _innerEdged(card);
  }

  /// The plain deck back, as dealt.
  Widget _deckBack() {
    return Container(
      width: width,
      height: _height,
      foregroundDecoration: _edge,
      decoration: _frame(Palette.feltDeep, border: Palette.gold, borderWidth: 1.5),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0x99D4A63A)),
        ),
        alignment: Alignment.center,
        child: CrownIcon(size: width * 0.28),
      ),
    );
  }

  /// The back of a done task: the deck's design, a gold inlay and a seal
  /// with a check.
  Widget _back() {
    final seal = clampD(width * 0.3, 22, 34);
    return _innerEdged(Container(
      width: width,
      height: _height,
      foregroundDecoration: _edge,
      decoration: _frame(Palette.feltDeep,
          border: owner?.color ?? Palette.gold, borderWidth: 2.5),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0x99D4A63A)),
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
                    color: Palette.won,
                    border: Border.all(color: Palette.gold, width: 2),
                  ),
                  child: Icon(Icons.check_rounded,
                      size: seal * 0.7, color: Colors.white),
                ),
              ],
            ),
          ),
          _ownerBadge(),
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
                  color: Palette.feltDeep,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Palette.gold, width: 1.5),
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

/// A red wax seal pressed with its order: I, II, III or Ω for last.
class WaxSeal extends StatelessWidget {
  const WaxSeal({super.key, required this.seal, this.size = 20});
  final int seal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = Seals.label(seal);
    return Tooltip(
      message: Seals.describe(seal),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFFD23A4C), Palette.cardRed, Color(0xFF7A0B1C)],
            stops: [0, 0.55, 1],
          ),
          border: Border.all(color: const Color(0xFF7A0B1C)),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w900,
                fontSize: size * (label.length > 2 ? 0.38 : 0.5),
                height: 1,
                color: const Color(0xFFFFE9C9))),
      ),
    );
  }
}

/// A royal decree, unrolled like a scroll before the deal.
class DecreeScroll extends StatelessWidget {
  const DecreeScroll(
      {super.key, required this.decree, this.detail, this.onAccept});
  final Decree decree;

  /// Extra line, e.g. who has been exiled.
  final String? detail;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(1, clampD(t, 0.02, 1.2), 1),
        child: Opacity(opacity: clampD(t * 1.5, 0, 1), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: Palette.parchment, // parchment
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Palette.goldDeep, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CrownIcon(size: 26, color: Palette.goldDeep),
            const SizedBox(height: 4),
            const Text('Royal Decree',
                style: TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Palette.inkSoft)),
            Text(decree.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    color: Palette.cardRed)),
            const SizedBox(height: 8),
            Text(decree.rule,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17, height: 1.35, color: Palette.ink)),
            if (detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(detail!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Palette.ink)),
              ),
            const SizedBox(height: 12),
            if (onAccept != null)
              FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                    backgroundColor: Palette.cardRed,
                    foregroundColor: Colors.white),
                child: const Text('So be it'),
              ),
            if (onAccept == null)
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

/// The outline of a courtier's token, fitted to a [size] square.
Path tokenPath(TokenShape shape, Size size) {
  final w = size.width, h = size.height;
  final c = Offset(w / 2, h / 2);
  Path polygon(int sides, double rotation, [double scale = 0.5]) {
    final p = Path();
    for (var i = 0; i < sides; i++) {
      final a = rotation + i * 2 * math.pi / sides;
      final pt = c + Offset(math.cos(a), math.sin(a)) * (w * scale);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  switch (shape) {
    case TokenShape.shield:
      return Path()
        ..moveTo(w * 0.08, h * 0.06)
        ..lineTo(w * 0.92, h * 0.06)
        ..lineTo(w * 0.92, h * 0.45)
        ..quadraticBezierTo(w * 0.9, h * 0.82, w * 0.5, h * 0.98)
        ..quadraticBezierTo(w * 0.1, h * 0.82, w * 0.08, h * 0.45)
        ..close();
    case TokenShape.arch:
      return Path()
        ..moveTo(w * 0.1, h * 0.98)
        ..lineTo(w * 0.1, h * 0.45)
        ..arcToPoint(Offset(w * 0.9, h * 0.45),
            radius: Radius.circular(w * 0.4))
        ..lineTo(w * 0.9, h * 0.98)
        ..close();
    case TokenShape.hexagon:
      return polygon(6, -math.pi / 2, 0.52);
    case TokenShape.diamond:
      return polygon(4, -math.pi / 2, 0.56);
    case TokenShape.octagon:
      return polygon(8, math.pi / 8, 0.52);
    case TokenShape.star:
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? w * 0.55 : w * 0.38;
        final a = -math.pi / 2 + i * math.pi / 5;
        final pt = c + Offset(math.cos(a), math.sin(a)) * r + Offset(0, h * 0.04);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
  }
}
