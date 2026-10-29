/// The crowning: the crown flies from the deck (or down from the walk-in's
/// crown on screen) to the new King's seat and lands in a burst of gold,
/// "Long live the King" glows, and the rest of the court sounds a fanfare.
/// The coronation overlay is the walk-in's own crown, growing in the
/// middle of the screen before it is handed over.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../widgets.dart';

/// The crown flies from [from] to the new King at [to] and lands in a
/// burst of gold, "Long live the King" glows, and every other seat in
/// [seats] sounds a trumpet. [animation] runs from 0 to 1.
class CrowningScene extends StatelessWidget {
  const CrowningScene({
    super.key,
    required this.animation,
    required this.from,
    required this.to,
    required this.spinTo,
    required this.seatSize,
    required this.king,
    required this.seats,
    this.startSize,
  });

  final Animation<double> animation;
  final Offset from;
  final Offset to;

  /// How far the crown turns on the way, to face the seat.
  final double spinTo;
  final double seatSize;
  final int king;

  /// Where every seat is, for the trumpets.
  final Map<int, Offset> seats;

  /// The crown's size at the start, when it comes down from the walk-in's
  /// crown; null for the deck's.
  final double? startSize;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final startSize = this.startSize;
        final fly = Curves.easeInOutCubic
            .transform(clampD(t / 0.6, 0, 1));
        final land = clampD((t - 0.6) / 0.4, 0, 1);
        // Arc: lift the crown off the straight line mid-flight.
        final lift = math.sin(fly * math.pi) * (startSize == null ? 70 : 30);
        final p = Offset.lerp(from, to, fly)! - Offset(0, lift);
        final size = t < 0.6
            ? startSize != null
                // Shrinks from the walk-in's crown down onto the head.
                ? startSize + (28 - startSize) * fly
                : 30 + 40 * math.sin(fly * math.pi) // swells mid-air
            : 18 + 10 * (1 - Curves.elasticOut.transform(land));
        final spin = spinTo * fly;
        final glow = math.sin(clampD(t / 0.9, 0, 1) * math.pi);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Opacity(
                opacity: glow,
                child: Text('Long live the King',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: skin.displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 30,
                        color: skin.gold,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 12),
                        ])),
              ),
            ),
            if (land > 0)
              Positioned.fill(
                child: CustomPaint(
                    painter: SparkBurst(skin: context.skin, origin: to, progress: land)),
              ),
            // The rest of the court sounds a fanfare: a trumpet at every
            // other seat, pointed at the new King, with notes floating out.
            for (final e in seats.entries)
              if (e.key != king)
                ..._trumpet(e.value, seatSize, e.key, to, t, skin.gold),
            Positioned(
              left: p.dx - size / 2,
              top: p.dy - size * 0.375,
              child: Transform.rotate(
                angle: spin,
                child: CrownIcon(size: size),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One player's trumpet in the crowning fanfare. It pops up just before
/// the crown lands, toots (a little kick) and blows notes towards the King.
List<Widget> _trumpet(
    Offset seat, double seatSize, int j, Offset king, double t, Color gold) {
  // Each trumpet starts a moment after the last, like a ragged fanfare.
  final start = 0.45 + 0.04 * j;
  final local = clampD((t - start) / (1 - start), 0, 1);
  if (local <= 0) return const [];
  final toKing = king - seat;
  final dir = toKing / toKing.distance;
  final pos = seat + dir * (seatSize * 0.75);
  final angle = math.atan2(dir.dy, dir.dx);
  final pop = Curves.elasticOut.transform(clampD(local / 0.35, 0, 1));
  final toot = math.sin(local * math.pi * 6) * 0.12 * (1 - local);
  final fade = local < 0.8 ? 1.0 : (1 - local) / 0.2;
  final size = clampD(seatSize * 0.6, 22, 32);

  return [
    Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Opacity(
        opacity: clampD(fade, 0, 1),
        child: Transform.rotate(
          angle: angle + toot,
          child: Transform.scale(
            // Keep the trumpet the right way up when it points left.
            scaleY: dir.dx < 0 ? -pop : pop,
            scaleX: pop,
            child: Icon(Icons.campaign_rounded,
                size: size,
                color: gold,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]),
          ),
        ),
      ),
    ),
    // Three notes drifting from the bell towards the King, rising as they go.
    for (int k = 0; k < 3; k++)
      () {
        final nt = clampD((local - 0.15 - k * 0.12) / 0.6, 0, 1);
        if (nt <= 0 || nt >= 1) return const SizedBox.shrink();
        final p = pos +
            dir * (size * 0.6 + nt * 60) +
            Offset(math.sin(nt * 8 + k) * 6, -nt * 26);
        return Positioned(
          left: p.dx - 7,
          top: p.dy - 10,
          child: Opacity(
            opacity: clampD(1 - nt, 0, 1),
            child: Text(k.isEven ? '♪' : '♫',
                style: TextStyle(
                    fontSize: 18,
                    color: gold,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 4)])),
          ),
        );
      }(),
  ];
}

/// The walk-in's crown: the felt darkens, sparks fly and the crown grows
/// in the middle of the screen, then lifts away, or waits (full size) for
/// the King to be chosen. [animation] runs from 0 to 1; with [waiting] it
/// holds at the end; [handedOver] once the crowning scene has taken the
/// crown.
class CoronationOverlay extends StatelessWidget {
  const CoronationOverlay(
      {super.key,
      required this.animation,
      required this.waiting,
      required this.handedOver});

  final Animation<double> animation;
  final bool waiting;
  final bool handedOver;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          if (t == 0 || (t == 1 && !waiting)) return const SizedBox.shrink();
          double iv(double a, double b, [Curve c = Curves.linear]) =>
              c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
          final cover = iv(0, 0.3, Curves.easeOut) * (1 - iv(0.6, 1, Curves.easeIn));
          final grow = iv(0.08, 0.42, Curves.easeOutBack);
          // A crown waiting for the King holds still, full size.
          final lift = waiting ? 0.0 : iv(0.58, 1, Curves.easeInCubic);
          final spark = iv(0.32, 0.85);
          final size = MediaQuery.sizeOf(context);
          final crown = math.min(size.width, size.height) * 0.28;
          final centre = Offset(size.width / 2, size.height / 2);
          return IgnorePointer(
            child: Stack(children: [
              // (The fade is in the gradient's own colours: fading the whole
              // screen as a layer is costly, on the web above all.)
              if (cover > 0)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(radius: 0.9, colors: [
                        context.skin.feltGlow.withValues(alpha: cover),
                        context.skin.feltDeep.withValues(alpha: cover),
                      ]),
                    ),
                  ),
                ),
              Positioned.fill(
                child: CustomPaint(
                  painter: spark > 0 && spark < 1
                      ? IntroSparks(skin: context.skin, 
                          origin: centre, progress: spark, scale: crown / 70)
                      : null,
                ),
              ),
              if (!handedOver)
                Positioned(
                  left: centre.dx - crown / 2,
                  top: centre.dy - crown * 0.375 - lift * crown * 0.8,
                  child: Opacity(
                    opacity: iv(0.05, 0.2) * (1 - lift),
                    child: Transform.scale(
                      scale: waiting && t > 0.42 ? 1 : 0.55 + 0.45 * grow + 0.15 * lift,
                      // Drawn once, glow and all, then only moved, scaled and
                      // faded.
                      // A round glow behind it (a gradient: no blur to work out).
                      child: RepaintBoundary(
                        child: Stack(clipBehavior: Clip.none, children: [
                          Positioned(
                            left: -crown * 0.4,
                            right: -crown * 0.4,
                            top: -crown * 0.525,
                            bottom: -crown * 0.525,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(colors: [
                                  context.skin.gold.withValues(alpha: 0.4),
                                  context.skin.gold.withValues(alpha: 0),
                                ]),
                              ),
                            ),
                          ),
                          CrownIcon(size: crown),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          );
        },
      );
}

/// A ring of gold and white sparks, sized to the crown.
class IntroSparks extends CustomPainter {
  IntroSparks(
      {required this.skin, required this.origin, required this.progress, required this.scale});
  final Skin skin;
  final Offset origin;
  final double progress;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);
    for (var k = 0; k < 18; k++) {
      final a = k * 2 * math.pi / 18 + 0.2;
      final r = (30 + 70 * ease * (k.isEven ? 1 : 0.65)) * scale;
      final p = origin + Offset(math.cos(a), math.sin(a)) * r;
      final color = (k.isEven ? skin.gold : Colors.white).withValues(alpha: fade);
      canvas.drawCircle(p, (k.isEven ? 3.2 : 2.2) * scale, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(IntroSparks old) => old.progress != progress || old.skin != skin;
}

/// The walk into a game from the menus ([CoronationOverlay]): its crown,
/// whether it's waiting to be the King's, and handing it over to the
/// crowning at the table, only once the walk-in is done (until then it
/// covers the table, where the crowning plays).
class WalkIn {
  WalkIn({required TickerProvider vsync, required this.changed})
      : animation = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 1500));

  final AnimationController animation;

  /// Something to draw changed.
  final VoidCallback changed;

  /// The crown waits in the middle of the screen to be the King's crown
  /// (so there is only ever one crown).
  bool waiting = false;

  /// The crown has gone to the King: the walk-in no longer draws it, even
  /// while the rest of it plays out.
  bool handedOver = false;

  /// Walks in; with [crowning], the crown stays for the King, while
  /// [stillDue] says the King's still to be chosen (a slow phone may still
  /// be setting out), and goes once it isn't.
  void start({required bool crowning, required bool Function() stillDue}) {
    handedOver = false;
    waiting = crowning;
    animation.forward(from: 0).whenComplete(() {
      void letGo() {
        if (!waiting) return;
        if (stillDue()) {
          Timer(const Duration(milliseconds: 500), letGo);
          return;
        }
        waiting = false;
        changed();
      }
      Timer(const Duration(milliseconds: 1500), letGo);
    });
  }

  /// The crowning takes the crown: [fly] runs once the walk-in is done.
  void handOver(VoidCallback fly) {
    void go() {
      handedOver = handedOver || waiting;
      waiting = false;
      fly();
    }
    if (!animation.isAnimating) return go();
    void done(AnimationStatus s) {
      if (s != AnimationStatus.completed) return;
      animation.removeStatusListener(done);
      go();
    }
    animation.addStatusListener(done);
  }

  void dispose() => animation.dispose();
}
