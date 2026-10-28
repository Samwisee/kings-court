/// Loyalty candles: kept for the roguelike, though nothing lights them now.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';

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
    final skin = context.skin;
    final candle = TweenAnimationBuilder<double>(
      // A new key restarts the flicker every time loyalty changes.
      key: ValueKey(loyalty),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, t, _) => CustomPaint(
        size: Size.square(size),
        painter: _CandlePainter(skin: context.skin, loyalty: loyalty, flicker: t),
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
          color: skin.ink,
          border: Border.all(
              color: loyalty <= 0 ? skin.lost : const Color(0x88D4A63A),
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
            painter: _CandlePainter(skin: context.skin, loyalty: i < loyalty ? 4 : 0, flicker: 1),
          ),
      ],
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({required this.skin, required this.loyalty, required this.flicker});
  final Skin skin;
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
        Paint()..color = skin.card);
    canvas.drawLine(Offset(cx, bodyTop), Offset(cx, bodyTop - h * 0.05),
        Paint()
          ..color = skin.inkSoft
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
    final color = Color.lerp(const Color(0xFFB4541C), skin.gold, level)!;
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
      old.loyalty != loyalty || old.flicker != flicker || old.skin != skin;
}
