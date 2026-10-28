/// Seat tokens and the courtiers’ living tokens: breathing, arriving, speaking, walking.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/courtiers.dart';
import '../../game/state.dart';
import '../../skin/theme.dart';
import 'clamp.dart';
import 'icons.dart';
import 'table.dart';
import 'token_shapes.dart';

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
    final ringColor = ring;
    final ringWidth = isKing || highlighted || picking ? 3.0 : 2.0;
    final fill = player.color;
    final token = shape == null
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
            // A thin dark line inside the ring.
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: outlineColour, width: 1.3),
              ),
              child: labelText,
            ),
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
                  ? const CrownIcon(size: 18)
                  : exiled
                      ? const Icon(Icons.block, size: 14, color: Palette.lost)
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
                  if (spoke != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: SpeakToken(
                          used: spoke!, locked: speakLocked, size: badge),
                    ),
                  // The whole seat is one button: badges included.
                  Positioned.fill(
                    child: MouseRegion(cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click, child: GestureDetector(
                      onTap: onTap,
                      behavior: HitTestBehavior.opaque,
                    )),
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
      child: RepaintBoundary(child: AnimatedBuilder(
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
      )),
    );
  }
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
    // A thin dark line just inside the ring, between it and the token's
    // colour, so a gold (or white) ring stands out from both.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth + 2.6
        ..strokeJoin = StrokeJoin.round
        ..color = outlineColour,
    );
    canvas.restore();
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

