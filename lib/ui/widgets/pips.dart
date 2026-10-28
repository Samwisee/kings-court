/// Gold pips: a setting’s pip, a tile with one, and the glitter on a chosen pip.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../skin/skin_scope.dart';
import 'character_token.dart';

/// The court's on/off mark: a gold ring, filled with a gold jewel when on.
/// Used for every setting in place of switches and tick boxes.
class GoldPip extends StatelessWidget {
  const GoldPip({super.key, required this.on, this.size = 22, this.enabled = true});
  final bool on;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final gold = enabled ? skin.gold : skin.gold.withValues(alpha: 0.4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: gold, width: 2),
        boxShadow: on && enabled
            ? [BoxShadow(color: skin.gold.withValues(alpha: 0.45), blurRadius: 8)]
            : null,
      ),
      padding: EdgeInsets.all(size * 0.17),
      child: AnimatedScale(
        scale: on ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: [skin.goldPale, gold]),
          ),
        ),
      ),
    );
  }
}

/// A setting with a title, a line about it, and a [GoldPip] to turn it on
/// or off (the whole line is the tap target).
class PipTile extends StatelessWidget {
  const PipTile(
      {super.key,
      required this.title,
      this.subtitle,
      required this.value,
      required this.onChanged});
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        // A faint gold wash when pressed, never a white flash.
        highlightColor: skin.gold.withValues(alpha: 0.08),
        splashColor: skin.gold.withValues(alpha: 0.12),
        hoverColor: skin.gold.withValues(alpha: 0.06),
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                      child: title),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                        child: subtitle!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            GoldPip(on: value, enabled: enabled),
          ]),
        ),
      ),
    );
  }
}

/// A sheen that sweeps across a gold panel every few seconds, and small
/// four-pointed stars twinkling over it.
class Glitter extends StatefulWidget {
  const Glitter({super.key});

  @override
  State<Glitter> createState() => _GlitterState();
}

class _GlitterState extends State<Glitter> with SingleTickerProviderStateMixin {
  // One long cycle: a sheen sweeps the gold at its start, then rests,
  // while stars twinkle all the way through.
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 6500));

  /// Under the test runner nothing loops (a test waits for stillness).
  static bool get _underTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context) || !CharacterToken.alive || _underTest;
    if (_still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Its own layer: the sheen sweeps forever, and only it repaints.
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: _build(context));

  Widget _build(BuildContext context) => _still
      ? const SizedBox.shrink()
      : AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _GlitterPainter(_c.value)),
        );
}

class _GlitterPainter extends CustomPainter {
  _GlitterPainter(this.t);
  final double t;

  static const _stars = [
    (0.12, 0.18, 0.0), (0.86, 0.14, 0.35), (0.22, 0.78, 0.6), (0.78, 0.7, 0.15),
    (0.5, 0.08, 0.8), (0.93, 0.48, 0.5), (0.06, 0.5, 0.9), (0.62, 0.9, 0.25),
    (0.38, 0.3, 0.7), (0.7, 0.36, 0.05),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // The sheen: crosses in the first fifth of each cycle, then rests.
    final sweep = (t / 0.2).clamp(0.0, 1.0);
    if (sweep < 1) {
      // A soft diagonal band crossing from left to right.
      final rect = Offset.zero & size;
      final cx = -0.3 * size.width + 1.6 * size.width * Curves.easeInOut.transform(sweep);
      final band = size.width * 0.18;
      canvas.drawRect(
          rect,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(cx - band, 0),
              Offset(cx + band, size.height * 0.35),
              const [Color(0x00FFFFFF), Color(0x66FFFBE6), Color(0x00FFFFFF)],
              const [0, 0.5, 1],
            ));
    }
    // The stars, each twinkling in its own moment.
    final star = Paint()..color = const Color(0xFFFFFBEA);
    for (final (sx, sy, phase) in _stars) {
      // Each star twinkles three times a cycle, each in its own moment,
      // so there are always a few catching the light.
      final local = (((t * 3) - phase) % 1) / 0.35;
      if (local < 0 || local > 1) continue;
      final k = math.sin(local * math.pi);
      if (k <= 0) continue;
      final r = 5.0 * k;
      final c = Offset(size.width * sx, size.height * sy);
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, star..color = Color.fromRGBO(255, 251, 234, k));
    }
  }

  @override
  bool shouldRepaint(_GlitterPainter old) => old.t != t;
}
