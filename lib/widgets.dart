import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'chronicle.dart';
import 'engine/cards.dart';
import 'courtiers.dart';
import 'models.dart';
import 'theme.dart';

/// Clamps [v] to [lo]..[hi] as a double. Unlike num.clamp it never throws
/// when the range is inverted (e.g. on a tiny window); it returns [lo].
double clampD(double v, double lo, double hi) =>
    v > hi ? (hi < lo ? lo : hi) : (v < lo ? lo : v);

/// A small five-point crown, drawn so it looks the same on every platform.
class CrownIcon extends StatelessWidget {
  const CrownIcon({super.key, this.size = 16, this.color = Palette.gold});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size * 0.75),
        painter: _CrownPainter(color),
      );
}

class _CrownPainter extends CustomPainter {
  _CrownPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final path = Path()
      ..moveTo(0, h * 0.25)
      ..lineTo(w * 0.27, h * 0.55)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w * 0.73, h * 0.55)
      ..lineTo(w, h * 0.25)
      ..lineTo(w * 0.88, h * 0.82)
      ..lineTo(w * 0.12, h * 0.82)
      ..close()
      ..addRect(Rect.fromLTWH(w * 0.12, h * 0.88, w * 0.76, h * 0.12));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.color != color;
}

/// Game text with suits printed in their card colours (♥ ♦ in red,
/// ♠ ♣ in black) and the term "Court Cards" always capitalised and set a
/// little bolder, so it reads as a game term.
class SuitText extends StatelessWidget {
  const SuitText(this.text, {super.key, required this.style, this.textAlign});
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  static final _marked = RegExp(r'[♥♦♠♣]|\bcourt cards?\b', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _marked.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final token = m.group(0)!;
      if (token.length == 1) {
        final suit = Suit.values.firstWhere((s) => s.symbol == token);
        // On a dark background, suits are printed in lighter colours so
        // they keep their contrast.
        final dark = (style.color?.computeLuminance() ?? 0) > 0.5;
        spans.add(TextSpan(
            text: token,
            style: TextStyle(
                color: dark
                    ? Palette.suitColourOnDark(suit, style.color!)
                    : Palette.suitColour(suit))));
      } else {
        final plural = token.toLowerCase().endsWith('s');
        spans.add(TextSpan(
            text: plural ? 'Court Cards' : 'Court Card',
            style: const TextStyle(fontWeight: FontWeight.w700)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: style, children: spans),
        textAlign: textAlign);
  }
}

/// A player's seat: a coloured token with their seat number or initials.
/// The King's seat gets a gold ring and a crown. During play the token
/// also carries a trick tally and the player's speaking token, and glows
/// when it is that player's turn to pick a task.
class SeatToken extends StatelessWidget {
  const SeatToken({
    super.key,
    required this.player,
    this.label,
    this.isKing = false,
    this.size = 48,
    this.highlighted = false,
    this.prompting = false,
    this.picking = false,
    this.exiled = false,
    this.speakLocked = false,
    this.shape,
    this.antagonist = false,
    this.wounds,
    this.powerUsed,
    this.loyalty,
    this.spoke,
    this.onTap,
    this.tight = false,
  });

  /// Drop the space under the token (for a label right beneath it).
  final bool tight;

  final Player player;

  /// Seat number or initials shown on the token; see [seatLabels].
  final String? label;
  final bool isKing;
  final double size;

  /// A task card is hovering over this seat and can be dropped here.
  final bool highlighted;

  /// The table is waiting for someone to tap a seat (choosing the King).
  final bool prompting;

  /// It is this player's turn to pick a task.
  final bool picking;

  /// Banished by royal decree: takes no tasks this round.
  final bool exiled;

  /// A decree forbids card reveals right now.
  final bool speakLocked;

  /// The courtier's token outline; a plain circle when null.
  final TokenShape? shape;

  /// Dynasty: this courtier has openly turned against the King.
  final bool antagonist;

  /// Dynasty: wounds the King has taken (shown by the crown).
  final int? wounds;

  /// Dynasty: whether the courtier's power is spent this round (hidden
  /// when null).
  final bool? powerUsed;

  /// Dynasty: loyalty to the crown, shown as a candle (hidden when null).
  final int? loyalty;

  /// Whether the player has used their card reveal; hidden when null.
  final bool? spoke;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = label ??
        (player.name.trim().isEmpty ? '?' : player.name.trim()[0].toUpperCase());
    final ring = isKing || highlighted || picking
        ? Palette.gold
        : prompting
            ? Colors.white70
            : Palette.feltDeep;
    final badge = clampD(size * 0.46, 20, 26);

    final labelText = OutlinedLabel(initial,
        fontSize: size * (initial.length > 1 ? 0.36 : 0.46),
        strokeWidth: size * 0.07);
    final ringColor = antagonist ? Palette.lost : ring;
    final ringWidth = isKing || highlighted || picking || antagonist ? 3.0 : 2.0;
    final fill = antagonist
        ? Color.lerp(player.color, const Color(0xFF3A0610), 0.55)!
        : player.color;
    final Widget token = shape == null
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: ringWidth),
              boxShadow: [
                if (highlighted)
                  const BoxShadow(color: Palette.gold, blurRadius: 14)
                else
                  const BoxShadow(
                      color: Colors.black38,
                      blurRadius: 4,
                      offset: Offset(0, 2)),
              ],
            ),
            child: labelText,
          )
        : ShapedToken(
            shape: shape!,
            size: size,
            color: fill,
            ring: ringColor,
            ringWidth: ringWidth,
            glow: highlighted,
            child: labelText,
          );

    return Semantics(
      button: onTap != null,
      label: [
        isKing ? '${player.name}, the King' : player.name,
        if (spoke == true) 'card reveal used',
        if (picking) 'picking a task',
        if (exiled) 'exiled',
        if (antagonist) 'against the King',
      ].join(', '),
      excludeSemantics: true,
      child: AnimatedScale(
        scale: highlighted ? 1.18 : 1,
        duration: const Duration(milliseconds: 150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 14,
              child: isKing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CrownIcon(size: 18),
                        // Wounds taken; how many the King can bear is secret.
                        for (int w = 0; w < (wounds ?? 0); w++)
                          const Padding(
                            padding: EdgeInsets.only(left: 1),
                            child: Icon(Icons.water_drop,
                                size: 12, color: Palette.lost),
                          ),
                      ],
                    )
                  : exiled
                      ? const Icon(Icons.block, size: 14, color: Palette.lost)
                      : antagonist
                          ? const Icon(Icons.dangerous,
                              size: 15, color: Palette.lost)
                          : null,
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: size + badge,
              height: size + badge * 0.4,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  if (picking)
                    Positioned(
                      top: 0,
                      child: PulseRing(size: size),
                    ),
                  AnimatedOpacity(
                    opacity: exiled ? 0.4 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: token,
                  ),
                  if (loyalty != null)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: LoyaltyCandle(loyalty: loyalty!, size: badge),
                    ),
                  if (powerUsed != null)
                    Positioned(
                      right: 0,
                      top: -4,
                      child: _PowerBadge(used: powerUsed!, size: badge),
                    ),
                  if (spoke != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: SpeakToken(
                          used: spoke!, locked: speakLocked, size: badge),
                    ),
                  // The whole seat is one button: badges included.
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: onTap,
                      behavior: HitTestBehavior.opaque,
                    ),
                  ),
                ],
              ),
            ),
            // Matches the crown's slot so the token sits on the seat's
            // centre.
            if (!tight) SizedBox(height: 16 - badge * 0.4),
          ],
        ),
      ),
    );
  }
}

/// A gold ring that breathes around the seat whose turn it is to pick.
class PulseRing extends StatefulWidget {
  const PulseRing({super.key, required this.size});
  final double size;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  /// Pulses a few times to catch the eye, then rests; the seat's gold ring
  /// keeps showing whose turn it is.
  static const _pulses = 5;
  int _done = 0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && ++_done < _pulses) {
        _c.forward(from: 0);
      }
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_done >= _pulses) return const SizedBox.shrink();
          final t = Curves.easeOut.transform(_c.value);
          return Transform.scale(
            scale: 1 + t * 0.45,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Palette.gold.withAlpha((230 * (1 - t)).round()),
                  width: 3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A courtier's loyalty as a candle: the flame burns taller the more loyal
/// they are and gutters out at nothing. It flickers when loyalty changes,
/// so the table notices without being told a number.
class LoyaltyCandle extends StatelessWidget {
  const LoyaltyCandle(
      {super.key, required this.loyalty, required this.size, this.badge = true});
  final int loyalty;
  final double size;

  /// Drawn on a round dark badge (on the seat) or bare (in a dialog).
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final candle = TweenAnimationBuilder<double>(
      // A new key restarts the flicker every time loyalty changes.
      key: ValueKey(loyalty),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, t, _) => CustomPaint(
        size: Size.square(size),
        painter: _CandlePainter(loyalty: loyalty, flicker: t),
      ),
    );
    if (!badge) return candle;
    return Tooltip(
      message: 'Loyalty to the crown',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.ink,
          border: Border.all(
              color: loyalty <= 0 ? Palette.lost : const Color(0x88D4A63A),
              width: 1.5),
        ),
        child: candle,
      ),
    );
  }
}

/// Five candles for a courtier's loyalty, lit up to their level.
class LoyaltyCandles extends StatelessWidget {
  const LoyaltyCandles({super.key, required this.loyalty, this.size = 22});
  final int loyalty;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          CustomPaint(
            size: Size(size * 0.8, size),
            painter: _CandlePainter(loyalty: i < loyalty ? 4 : 0, flicker: 1),
          ),
      ],
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({required this.loyalty, required this.flicker});
  final int loyalty;

  /// 0 to 1 through the flicker after a change; 1 is steady.
  final double flicker;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final bodyW = w * 0.26;
    final bodyTop = h * 0.56;
    final bodyBottom = h * 0.84;
    canvas.drawRRect(
        RRect.fromLTRBR(cx - bodyW / 2, bodyTop, cx + bodyW / 2, bodyBottom,
            Radius.circular(bodyW * 0.2)),
        Paint()..color = Palette.card);
    canvas.drawLine(Offset(cx, bodyTop), Offset(cx, bodyTop - h * 0.05),
        Paint()
          ..color = Palette.inkSoft
          ..strokeWidth = math.max(1.0, w * 0.03));
    if (loyalty <= 0) {
      // Snuffed: a curl of smoke.
      final smoke = Path()
        ..moveTo(cx, bodyTop - h * 0.06)
        ..quadraticBezierTo(cx - w * 0.1, bodyTop - h * 0.18, cx, bodyTop - h * 0.28)
        ..quadraticBezierTo(cx + w * 0.1, bodyTop - h * 0.36, cx, bodyTop - h * 0.44);
      canvas.drawPath(
          smoke,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, w * 0.04)
            ..color = Colors.white38);
      return;
    }
    final level = (loyalty.clamp(1, 5)) / 5;
    final wobble = 1 + 0.3 * math.sin(flicker * math.pi * 9) * (1 - flicker);
    final flameH = h * (0.14 + 0.26 * level) * wobble;
    final flameW = w * (0.13 + 0.07 * level);
    final base = Offset(cx, bodyTop - h * 0.04);
    final color = Color.lerp(const Color(0xFFB4541C), Palette.gold, level)!;
    // Glow, brighter while flickering.
    canvas.drawCircle(
        base.translate(0, -flameH * 0.45),
        flameH * (0.7 + 0.5 * (1 - flicker)),
        Paint()
          ..color = color.withValues(alpha: 0.18 + 0.25 * (1 - flicker))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    final flame = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(base.dx - flameW, base.dy - flameH * 0.35,
          base.dx, base.dy - flameH)
      ..quadraticBezierTo(
          base.dx + flameW, base.dy - flameH * 0.35, base.dx, base.dy)
      ..close();
    canvas.drawPath(flame, Paint()..color = color);
    canvas.drawCircle(base.translate(0, -flameH * 0.25), flameW * 0.35,
        Paint()..color = Colors.white70);
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.loyalty != loyalty || old.flicker != flicker;
}

/// The once-per-round speaking token. It flips over when the player has
/// shown a card.
class SpeakToken extends StatelessWidget {
  const SpeakToken(
      {super.key, required this.used, this.locked = false, required this.size});
  final bool used;

  /// Reveals are forbidden by decree right now.
  final bool locked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: locked
          ? 'No card reveals allowed yet'
          : used
              ? 'Card reveal used'
              : 'Card reveal available',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: used ? math.pi : 0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        builder: (context, angle, _) {
          final back = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(angle),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: back || locked ? const Color(0xFF55524C) : Palette.card,
                border: Border.all(
                    color: back || locked ? Colors.white38 : Palette.gold,
                    width: 1.5),
              ),
              child: Icon(
                locked
                    ? Icons.lock_outline
                    : back
                        ? Icons.voice_over_off
                        : Icons.record_voice_over,
                size: size * 0.6,
                color: back || locked ? Colors.white54 : Palette.ink,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One pip per task: hollow while pending, green when done, red when failed.
class TaskPips extends StatelessWidget {
  const TaskPips({super.key, required this.tasks});
  final List<Task> tasks;

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
    this.charged = false,
    this.progress,
  });

  final Task task;

  /// How far along the task is, e.g. "2/4", shown in the bottom corner.
  final String? progress;

  /// Dynasty: a royal charge, dealt straight to one house.
  final bool charged;
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

  static double heightFor(double width) => width * 0.7;
  static double _indexSize(double width) => clampD(width * 0.17, 12, 18);
  static const _pad = 5.0;
  static const _badgeRoom = 14.0;
  static const _sealRoom = 17.0;

  /// Card size for [text] at [width]: the usual shape, but taller when the
  /// task needs it so its text never shrinks below [minTextScale].
  static Size sizeFor(String text, double width, {bool sealed = false}) {
    final textWidth = width - 2 * _pad - _indexSize(width) * 1.05 - 3 -
        (sealed ? _sealRoom : 0);
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textWidth / minTextScale);
    final needed = painter.height * minTextScale + 2 * _pad + _badgeRoom;
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
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: border ?? const Color(0xFFE6E0D4),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: lifted ? 14 : 4,
            offset: Offset(0, lifted ? 7 : 2),
          ),
        ],
      );

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
    final iconSize = indexSize * 0.7;
    return Container(
      width: width,
      height: _height,
      decoration: _frame(
        task.isFailed ? const Color(0xFFFBE9E7) : Palette.card,
        border: task.isFailed ? Palette.lost : owner?.color,
        borderWidth: owner == null && !task.isFailed ? 1 : 2.5,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_pad, _pad, _pad, _pad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: indexSize * 1.05,
                  child: Column(
                    children: [
                      Text('$points',
                          style: TextStyle(
                              fontFamily: displayFont,
                              fontWeight: FontWeight.w900,
                              fontSize: indexSize,
                              height: 1,
                              color: Palette.ink)),
                      const SizedBox(height: 2),
                      CrownIcon(size: indexSize * 0.5, color: Palette.goldDeep),
                      // Conditions that don't fit on the card: tap it to
                      // read them.
                      if (task.kingCantTake)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Tooltip(
                            message: "The King can't take this task",
                            child: Icon(Icons.block,
                                size: iconSize, color: Palette.inkSoft),
                          ),
                        ),
                      if (task.hasNotes)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Tooltip(
                            message: task.notes.join(' '),
                            child: Icon(Icons.info_outline,
                                size: iconSize, color: Palette.inkSoft),
                          ),
                        ),
                      if (task.isFailed)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(Icons.cancel,
                              size: iconSize + 2, color: Palette.lost),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: _badgeRoom,
                        right: task.seal == null ? 0 : _sealRoom),
                    child: LayoutBuilder(
                      builder: (context, c) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: c.maxWidth,
                          child: SuitText(text ?? task.description,
                              style: textStyle),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (progress != null && !task.isCompleted)
            Positioned(
              left: charged ? 20 : 4,
              bottom: 4,
              child: Container(
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Palette.ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(progress!,
                    style: const TextStyle(
                        fontFamily: bodyFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: Palette.gold)),
              ),
            ),
          // A royal charge: a gold ribbon in the corner by the owner badge.
          if (charged)
            const Positioned(
              left: 3,
              bottom: 2,
              child: Tooltip(
                message: 'A royal charge',
                child: Icon(Icons.workspace_premium,
                    size: 15, color: Palette.goldDeep),
              ),
            ),
          if (task.seal != null)
            Positioned(
              top: 3,
              right: 3,
              child: WaxSeal(seal: task.seal!, size: 20),
            ),
          _ownerBadge(),
        ],
      ),
    );
  }

  /// The plain deck back, as dealt.
  Widget _deckBack() {
    return Container(
      width: width,
      height: _height,
      decoration: _frame(Palette.feltDeep, border: Palette.gold, borderWidth: 1.5),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0x99D4A63A), width: 1),
        ),
        alignment: Alignment.center,
        child: CrownIcon(size: width * 0.28, color: Palette.gold),
      ),
    );
  }

  /// The back of a done task: the deck's design, a gold inlay and a seal
  /// with a check.
  Widget _back() {
    final seal = clampD(width * 0.3, 22, 34);
    return Container(
      width: width,
      height: _height,
      decoration: _frame(Palette.feltDeep,
          border: owner?.color ?? Palette.gold, borderWidth: 2.5),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0x99D4A63A), width: 1),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CrownIcon(size: 14, color: Palette.gold),
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
    );
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
                    ? const CrownIcon(size: 28, color: Palette.gold)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// A thin double brass rule set into the felt, like the inlay on a card
/// table.
class TableTrim extends StatelessWidget {
  const TableTrim({super.key});

  @override
  Widget build(BuildContext context) {
    // Two rules 3px apart, 4px in from the edge: the seats and cards sit
    // inside them (see _TableGeometry.trimInset).
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x99D4A63A), width: 1.5),
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x55D4A63A), width: 1),
        ),
      ),
    );
  }
}

/// A ring of gold and white sparks flying out from [origin] and fading as
/// [progress] runs from 0 to 1. Used when the crown lands.
class SparkBurst extends CustomPainter {
  SparkBurst({required this.origin, required this.progress});
  final Offset origin;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0).toDouble();
    for (int k = 0; k < 14; k++) {
      final a = k * 2 * math.pi / 14;
      final r = 10 + 48 * ease * (k.isEven ? 1 : 0.7);
      final p = origin + Offset(math.cos(a), math.sin(a)) * r;
      final color = k.isEven ? Palette.gold : Colors.white;
      canvas.drawCircle(
        p,
        (k.isEven ? 3.5 : 2.5) * (1 - ease * 0.5),
        Paint()..color = color.withAlpha((255 * fade).round()),
      );
    }
    // A soft gold glow under the crown.
    canvas.drawCircle(
      origin,
      18 + 20 * ease,
      Paint()
        ..color = Palette.gold.withAlpha((90 * fade).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  @override
  bool shouldRepaint(SparkBurst old) =>
      old.progress != progress || old.origin != origin;
}

/// Gold crowns and confetti tumbling down the table when a round is won.
/// [progress] runs 0 to 1; [seed] keeps the pattern steady for one win.
class CrownConfetti extends CustomPainter {
  CrownConfetti({required this.progress, required this.seed});
  final double progress;
  final int seed;

  static final _crownPath = Path()
    ..moveTo(0, 0.25)
    ..lineTo(0.27, 0.55)
    ..lineTo(0.5, 0)
    ..lineTo(0.73, 0.55)
    ..lineTo(1, 0.25)
    ..lineTo(0.88, 0.82)
    ..lineTo(0.12, 0.82)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final fade = progress < 0.75 ? 1.0 : (1 - progress) / 0.25;
    for (int i = 0; i < 46; i++) {
      final x0 = rand.nextDouble() * size.width;
      final delay = rand.nextDouble() * 0.35;
      final speed = 0.8 + rand.nextDouble() * 0.6;
      final sway = 12 + rand.nextDouble() * 22;
      final spin = (rand.nextDouble() - 0.5) * 10;
      final isCrown = i % 3 == 0;
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0).toDouble();
      if (t <= 0) continue;
      final y = -30 + t * speed * (size.height + 60);
      final x = x0 + math.sin(t * 6 + i) * sway;
      final color = switch (i % 4) {
        0 => Palette.gold,
        1 => Colors.white,
        2 => Palette.goldDeep,
        _ => Palette.cardRed,
      };
      final paint = Paint()..color = color.withAlpha((255 * fade).round());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin * t);
      if (isCrown) {
        canvas.scale(18);
        canvas.translate(-0.5, -0.4);
        canvas.drawPath(_crownPath, Paint()..color = Palette.gold.withAlpha((255 * fade).round()));
      } else {
        canvas.drawRect(const Rect.fromLTWH(-4, -2.5, 8, 5), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CrownConfetti old) =>
      old.progress != progress || old.seed != seed;
}

/// White Cinzel lettering with a solid black outline, readable on any seat
/// colour.
class OutlinedLabel extends StatelessWidget {
  const OutlinedLabel(this.text,
      {super.key, required this.fontSize, this.strokeWidth = 3});
  final String text;
  final double fontSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    // Seat numbers use the plain face: Cinzel's old-style 1 reads as a
    // Roman I, which clashes with the wax seals.
    final numeric = RegExp(r'^\d+$').hasMatch(text);
    TextStyle style(Paint? stroke) => TextStyle(
          fontFamily: numeric ? bodyFont : displayFont,
          fontWeight: numeric ? FontWeight.w700 : FontWeight.w900,
          fontSize: fontSize,
          height: 1,
          foreground: stroke,
          color: stroke == null ? Colors.white : null,
        );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text,
            style: style(Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black)),
        Text(text, style: style(null)),
      ],
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
          border: Border.all(color: const Color(0xFF7A0B1C), width: 1),
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
          color: const Color(0xFFF6EBD2), // parchment
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
    for (int i = 0; i < sides; i++) {
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
      for (int i = 0; i < 10; i++) {
        final r = i.isEven ? w * 0.55 : w * 0.38;
        final a = -math.pi / 2 + i * math.pi / 5;
        final pt = c + Offset(math.cos(a), math.sin(a)) * r + Offset(0, h * 0.04);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
  }
}

/// A seat token in its courtier's shape: filled with the seat colour, with
/// a ring, a shadow and an optional gold glow.
class ShapedToken extends StatelessWidget {
  const ShapedToken({
    super.key,
    required this.shape,
    required this.size,
    required this.color,
    required this.ring,
    this.ringWidth = 2,
    this.glow = false,
    this.child,
  });

  final TokenShape shape;
  final double size;
  final Color color;
  final Color ring;
  final double ringWidth;
  final bool glow;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TokenPainter(shape, color, ring, ringWidth, glow),
        child: Center(child: child),
      ),
    );
  }
}

class _TokenPainter extends CustomPainter {
  _TokenPainter(this.shape, this.color, this.ring, this.ringWidth, this.glow);
  final TokenShape shape;
  final Color color;
  final Color ring;
  final double ringWidth;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = tokenPath(shape, size);
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Palette.gold
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeJoin = StrokeJoin.round
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_TokenPainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.ring != ring ||
      old.ringWidth != ringWidth ||
      old.glow != glow;
}

/// A courtier's power: a gold bolt while it's ready, dimmed once used.
class _PowerBadge extends StatelessWidget {
  const _PowerBadge({required this.used, required this.size});
  final bool used;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: used ? const Color(0xFF55524C) : Palette.ink,
        border: Border.all(
            color: used ? Colors.white38 : Palette.gold, width: 1.5),
      ),
      child: Icon(Icons.bolt_rounded,
          size: size * 0.7, color: used ? Colors.white38 : Palette.gold),
    );
  }
}

/// How a character token is behaving.
enum CharacterMood {
  /// Sitting at the table: a slow, gentle breath (see [CharacterToken.alive]).
  idle,

  /// Has something to say: a little wobble and a speech bubble.
  speaking,

  /// Pleased with the King: a hop and a golden heart.
  pleased,

  /// Displeased: a shake and a red mark.
  angry,

  /// Just arrived at court: springs in, then breathes like the others.
  arriving,

  /// Leaving court: shrinks and fades.
  leaving,
}

/// Brings a courtier's token to life: [child] is the token itself.
class CharacterToken extends StatefulWidget {
  const CharacterToken({
    super.key,
    required this.child,
    this.mood = CharacterMood.idle,
    this.phase = 0,
    this.size = 40,
    this.delay = Duration.zero,
    this.entrance,
    this.exit,
  });

  final Widget child;
  final CharacterMood mood;

  /// Makes an entrance in this style, then breathes like the others.
  final Entrance? entrance;

  /// Leaves in this style (and stays gone).
  final Exit? exit;

  /// Wait this long before reacting (to take turns down a list).
  final Duration delay;

  /// Offsets the idle breath so a table of tokens doesn't move in step.
  final double phase;

  /// Roughly how big the token is, to scale the hop and the marks.
  final double size;

  /// Idle breathing on or off (off in tests, which wait for stillness).
  static bool alive = true;

  @override
  State<CharacterToken> createState() => _CharacterTokenState();
}

class _CharacterTokenState extends State<CharacterToken>
    with TickerProviderStateMixin {
  late final AnimationController _once = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: widget.entrance != null || widget.exit != null ? 1400 : 900));
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800));

  bool get _idles =>
      widget.exit == null &&
      (widget.entrance != null ||
          widget.mood == CharacterMood.idle ||
          widget.mood == CharacterMood.arriving);

  Timer? _wait;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _once.forward();
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) _once.forward();
      });
    }
    if (_idles && CharacterToken.alive) _breath.repeat();
  }

  @override
  void didUpdateWidget(CharacterToken old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _once.forward(from: 0);
      if (_idles && CharacterToken.alive) {
        if (!_breath.isAnimating) _breath.repeat();
      } else {
        _breath.stop();
      }
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _once.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_once, _breath]),
      child: widget.child,
      builder: (context, child) {
        final t = _once.value;
        final b = math.sin(2 * math.pi * (_breath.value + widget.phase));
        final s = widget.size;
        var dx = 0.0, dy = 0.0, scale = 1.0, angle = 0.0, opacity = 1.0;
        IconData? mark;
        Color markColor = Palette.gold;
        // A white wash for ghosts, a gold halo for holy arrivals.
        var wash = 0.0, halo = 0.0;
        final e = Curves.easeOutCubic.transform(t);
        final entrance = widget.entrance, exit = widget.exit;
        if (exit != null) {
          switch (exit) {
            case Exit.dash:
              dx = t < 0.15 ? -s * 0.15 * (t / 0.15) : s * 3.5 * Curves.easeIn.transform((t - 0.15) / 0.85);
              dy = -(math.sin(t * math.pi * 8)).abs() * s * 0.08;
              opacity = 1 - clampD((t - 0.5) * 2, 0, 1);
            case Exit.ghost:
              dy = -s * 1.4 * Curves.easeIn.transform(t);
              dx = math.sin(t * math.pi * 3) * s * 0.12;
              wash = 0.7 * clampD(t * 2, 0, 1);
              opacity = 1 - Curves.easeIn.transform(t);
            case Exit.banished:
              if (t < 0.4) {
                dx = math.sin(t * 60) * s * 0.1;
              } else {
                final f = Curves.easeIn.transform((t - 0.4) / 0.6);
                dy = s * 1.8 * f;
                angle = 0.8 * f;
                opacity = 1 - f;
              }
              if (t < 0.4) {
                mark = Icons.gavel_rounded;
                markColor = Palette.lost;
              }
            case Exit.walk:
              if (t < 0.3) {
                angle = 0.4 * math.sin(t / 0.3 * math.pi);
              } else {
                final f = (t - 0.3) / 0.7;
                dx = s * 2.6 * f;
                dy = -(math.sin(f * math.pi * 6)).abs() * s * 0.08;
                opacity = 1 - clampD((f - 0.5) * 2, 0, 1);
              }
            case Exit.poof:
              scale = 1 + 0.7 * t;
              opacity = 1 - Curves.easeOut.transform(t);
              mark = Icons.cloud_rounded;
              markColor = Colors.white;
          }
        } else if (entrance != null) {
          final before = t <= 0;
          switch (entrance) {
            case Entrance.march:
              dx = -s * 2.4 * (1 - e);
              dy = -(math.sin(t * math.pi * 6)).abs() * s * 0.1 * (1 - t);
            case Entrance.descend:
              dy = -s * 2.2 * (1 - e);
              scale = 0.6 + 0.4 * e;
              halo = math.sin(t * math.pi);
            case Entrance.stomp:
              dy = -s * 2.6 * (1 - Curves.bounceOut.transform(t));
              if (t > 0.35 && t < 0.9) {
                mark = Icons.cloud_rounded;
                markColor = Colors.white70;
              }
            case Entrance.shadow:
              opacity = clampD(e * (0.75 + 0.25 * math.sin(t * 40)), 0, 1);
              wash = 0;
              scale = 0.85 + 0.15 * e;
            case Entrance.roll:
              dx = s * 2.6 * (1 - e);
              angle = -math.pi * 4 * (1 - e);
            case Entrance.cartwheel:
              dx = -s * 2.8 * (1 - e);
              dy = -math.sin(e * math.pi) * s * 0.7;
              angle = math.pi * 4 * (1 - e);
          }
          if (before) opacity = 0;
          if (t >= 1) {
            dy += b * s * 0.03;
            scale *= 1 + 0.015 * b;
          }
        } else {
        switch (widget.mood) {
          case CharacterMood.idle:
            dy = b * s * 0.03;
            scale = 1 + 0.015 * b;
          case CharacterMood.arriving:
            scale = Curves.elasticOut.transform(t) + 0.015 * b;
            opacity = clampD(t * 3, 0, 1);
            dy = b * s * 0.03;
          case CharacterMood.speaking:
            angle = math.sin(t * math.pi * 6) * 0.1 * (1 - t);
            scale = 1 + 0.08 * math.sin(t * math.pi);
            mark = Icons.chat_bubble_rounded;
            markColor = Colors.white;
          case CharacterMood.pleased:
            dy = -s * 0.28 * math.sin(t * math.pi);
            scale = 1 + 0.12 * math.sin(t * math.pi);
            mark = Icons.favorite_rounded;
          case CharacterMood.angry:
            dx = math.sin(t * math.pi * 8) * s * 0.1 * (1 - t);
            mark = Icons.priority_high_rounded;
            markColor = Palette.lost;
          case CharacterMood.leaving:
            scale = 1 - 0.35 * Curves.easeIn.transform(t);
            opacity = 1 - 0.65 * t;
            dy = s * 0.1 * t;
        }
        }
        final markOpacity = mark == null ? 0.0 : math.sin(clampD(t, 0, 1) * math.pi);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (halo > 0.01)
              Container(
                width: s * 1.6,
                height: s * 1.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Palette.gold.withValues(alpha: 0.6 * halo),
                    Palette.gold.withValues(alpha: 0),
                  ]),
                ),
              ),
            Opacity(
              opacity: clampD(opacity, 0, 1),
              child: Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.rotate(
                  angle: angle,
                  child: Transform.scale(
                    scale: scale,
                    child: wash > 0.01
                        ? ColorFiltered(
                            colorFilter: ColorFilter.mode(
                                Colors.white.withValues(alpha: wash),
                                BlendMode.srcATop),
                            child: child)
                        : child,
                  ),
                ),
              ),
            ),
            if (mark != null && markOpacity > 0.01)
              Positioned(
                top: -s * 0.25 - s * 0.35 * t,
                right: -s * 0.15,
                child: Opacity(
                  opacity: markOpacity,
                  child: Icon(mark, size: s * 0.45, color: markColor, shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Words spoken at the table, in a bubble pointing back at the speaker
/// (on its left).
class SpeechBubble extends StatefulWidget {
  const SpeechBubble(this.text,
      {super.key, this.who, this.delay = Duration.zero, this.tailBelow = false});
  final String text;

  /// Point down at a speaker below, rather than left.
  final bool tailBelow;

  /// Who is speaking, shown small above the words.
  final String? who;

  /// Wait this long before speaking (to take turns).
  final Duration delay;

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // A gentle rise into place: no overshoot, no flicker.
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
        );
      },
      child: CustomPaint(
        painter: _BubbleTail(below: widget.tailBelow),
        child: Container(
          margin: widget.tailBelow
              ? const EdgeInsets.only(bottom: 9)
              : const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF5E6),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.who != null)
                Text(widget.who!,
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Palette.goldDeep)),
              Text(widget.text,
                  style: const TextStyle(
                      fontSize: 16, height: 1.4, color: Palette.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleTail extends CustomPainter {
  _BubbleTail({this.below = false});
  final bool below;

  @override
  void paint(Canvas canvas, Size size) {
    if (below) {
      final x = size.width / 2;
      canvas.drawPath(
          Path()
            ..moveTo(x - 9, size.height - 10)
            ..lineTo(x + 9, size.height - 10)
            ..lineTo(x, size.height)
            ..close(),
          Paint()..color = const Color(0xFFFBF5E6));
      return;
    }
    final y = math.min(22.0, size.height / 2);
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(10, y - 7)
      ..lineTo(10, y + 7)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFBF5E6));
  }

  @override
  bool shouldRepaint(_BubbleTail old) => old.below != below;
}

/// Glides [child] from wherever it was last laid out to where it is now,
/// so a courtier changing places walks there instead of jumping. Give it
/// a key that follows the courtier.
class SlideToPlace extends StatefulWidget {
  const SlideToPlace({super.key, required this.child});
  final Widget child;

  @override
  State<SlideToPlace> createState() => _SlideToPlaceState();
}

class _SlideToPlaceState extends State<SlideToPlace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  Offset? _last;
  Offset _from = Offset.zero;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _measure(_) {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final now = box.localToGlobal(Offset.zero);
    final last = _last;
    _last = now;
    if (last == null) return;
    final moved = last - now;
    if (moved.distance > 2) {
      // Start from where it appeared to be, mid-glide or not.
      final showing = _from * (1 - Curves.easeInOutCubic.transform(_c.value));
      _from = moved + showing;
      _c.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(_c.value);
        final off = _c.isAnimating || _c.value < 1 ? _from * (1 - t) : Offset.zero;
        // A little hop in each step as they walk.
        final hop = _c.isAnimating ? -(math.sin(t * math.pi * 4)).abs() * 4 : 0.0;
        return Transform.translate(offset: off + Offset(0, hop), child: child);
      },
    );
  }
}
