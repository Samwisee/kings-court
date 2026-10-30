/// A little life on the felt of the premium rooms, over what's worked into
/// it (felt_patterns.dart): stars twinkle and one shoots across the night
/// sky, fireflies drift over the garden trellis, a lighthouse's beam turns
/// over the harbour chart, and the tavern's lamp flickers. Faint, slow and
/// cheap: a handful of shapes in a layer of their own. Still when motion
/// is turned down, and under the test runner.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/looks.dart';
import '../../skin/skin_scope.dart';
import 'character_token.dart';

/// The motion for the worn skin's felt; nothing for an even felt.
class FeltMotion extends StatefulWidget {
  const FeltMotion({super.key});

  /// Whether [pattern] has any motion.
  static bool moves(FeltPattern pattern) => _kind(pattern) != null;

  static _Kind? _kind(FeltPattern p) => switch (p) {
        FeltPattern.stars => _Kind.stars,
        FeltPattern.trellis => _Kind.fireflies,
        FeltPattern.chart => _Kind.beam,
        FeltPattern.planks => _Kind.lamp,
        _ => null,
      };

  @override
  State<FeltMotion> createState() => _FeltMotionState();
}

enum _Kind { stars, fireflies, beam, lamp }

class _FeltMotionState extends State<FeltMotion> with SingleTickerProviderStateMixin {
  // One long cycle; each motion takes its own time within it.
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  bool _still = true;

  static bool get _underTest => WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final moves = FeltMotion._kind(context.skin.tableLook.pattern) != null;
    _still = !moves || MediaQuery.disableAnimationsOf(context) || !CharacterToken.alive || _underTest;
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

  @override
  Widget build(BuildContext context) {
    if (_still) return const SizedBox.expand();
    final look = context.skin.tableLook;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _MotionPainter(FeltMotion._kind(look.pattern)!, look.patternColour, _c),
        ),
      ),
    );
  }
}

class _MotionPainter extends CustomPainter {
  _MotionPainter(this.kind, this.ink, this.time) : super(repaint: time);
  final _Kind kind;
  final Color ink;
  final Animation<double> time;

  Color _ink(double alpha) => ink.withValues(alpha: alpha.clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    switch (kind) {
      case _Kind.stars:
        _stars(canvas, size, t);
      case _Kind.fireflies:
        _fireflies(canvas, size, t);
      case _Kind.beam:
        _beam(canvas, size, t);
      case _Kind.lamp:
        _lamp(canvas, size, t);
    }
  }

  /// A score of stars brightening and fading in turn, and once a cycle a
  /// star shooting across the top of the sky.
  void _stars(Canvas canvas, Size s, double t) {
    final rand = math.Random(21);
    for (var k = 0; k < 20; k++) {
      final p = Offset(rand.nextDouble() * s.width, rand.nextDouble() * s.height);
      final phase = rand.nextDouble();
      final glow = math.max(0.0, math.sin((t * 3 + phase) * 2 * math.pi));
      if (glow < 0.05) continue;
      final r = 1.2 + glow * 2.2;
      canvas.drawCircle(p, r * 2.4, Paint()..color = _ink(0.12 * glow));
      canvas.drawCircle(p, r * 0.6, Paint()..color = Colors.white.withValues(alpha: 0.7 * glow));
    }
    // The shooting star: a tenth of the cycle, then gone.
    const start = 0.55, length = 0.07;
    if (t > start && t < start + length) {
      final u = (t - start) / length;
      final from = Offset(s.width * 0.15, s.height * 0.08);
      final to = Offset(s.width * 0.75, s.height * 0.28);
      final head = Offset.lerp(from, to, u)!;
      final tail = Offset.lerp(from, to, math.max(0, u - 0.3))!;
      final fade = math.sin(u * math.pi);
      canvas.drawLine(
          tail,
          head,
          Paint()
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..shader = LinearGradient(colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.8 * fade),
            ]).createShader(Rect.fromPoints(tail, head)));
      canvas.drawCircle(head, 1.8, Paint()..color = Colors.white.withValues(alpha: 0.9 * fade));
    }
  }

  /// A few fireflies wandering slowly, each glowing and dimming.
  void _fireflies(Canvas canvas, Size s, double t) {
    final rand = math.Random(9);
    const warm = Color(0xFFF6E79A);
    for (var k = 0; k < 8; k++) {
      final x0 = rand.nextDouble(), y0 = rand.nextDouble();
      final phase = rand.nextDouble() * 2 * math.pi;
      final a = t * 2 * math.pi;
      final p = Offset(
        (x0 + 0.06 * math.sin(a + phase) + 0.03 * math.sin(a * 3 + phase)) * s.width,
        (y0 + 0.05 * math.cos(a * 2 + phase)) * s.height,
      );
      final glow = 0.5 + 0.5 * math.sin(a * 4 + phase * 2);
      canvas.drawCircle(p, 7, Paint()..color = warm.withValues(alpha: 0.08 * glow));
      canvas.drawCircle(p, 1.7, Paint()..color = warm.withValues(alpha: 0.55 * glow));
    }
  }

  /// A lighthouse's beam turning slowly from the chart's compass rose.
  void _beam(Canvas canvas, Size s, double t) {
    final c = Offset(s.width / 2, s.height * 0.45);
    final reach = math.sqrt(s.width * s.width + s.height * s.height);
    final a = t * 2 * math.pi;
    const spread = 0.16;
    final path = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + math.cos(a - spread) * reach, c.dy + math.sin(a - spread) * reach)
      ..lineTo(c.dx + math.cos(a + spread) * reach, c.dy + math.sin(a + spread) * reach)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(colors: [_ink(0.35), _ink(0)])
              .createShader(Rect.fromCircle(center: c, radius: reach * 0.7)));
    canvas.drawCircle(c, 6, Paint()..color = _ink(0.6));
  }

  /// The tavern's lamp, flickering over the boards.
  void _lamp(Canvas canvas, Size s, double t) {
    final a = t * 2 * math.pi;
    final flicker = 0.75 + 0.12 * math.sin(a * 17) + 0.08 * math.sin(a * 41 + 1) + 0.05 * math.sin(a * 73 + 2);
    final c = Offset(s.width / 2, s.height * 0.4);
    final r = math.max(s.width, s.height) * 0.6;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFC46B).withValues(alpha: 0.09 * flicker),
            const Color(0x00FFC46B),
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
  }

  @override
  bool shouldRepaint(_MotionPainter old) => old.kind != kind || old.ink != ink || old.time != time;
}
