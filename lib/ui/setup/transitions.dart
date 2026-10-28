/// How one setup page turns to the next.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/theme.dart';

/// The ways a setup page can turn to the next. [fade] is the one in use:
/// the old page fades out, then the new one fades in. The others were
/// tried:
/// * [deal]: slides in with a slight tilt that settles flat, like a card
///   dealt onto the table, with a faint glint of gold.
/// * [fadeThrough]: the old page fades away, then the new one fades in,
///   growing very slightly into place.
/// * [slide]: old and new glide sideways together, crossfading.
/// * [curtain]: the new page is uncovered from left to right behind a thin
///   gold edge, like a curtain drawn aside.
/// * [sealPress]: the new page settles down onto the table from just above,
///   like a wax seal being pressed.
enum TurnStyle { fade, deal, fadeThrough, slide, curtain, sealPress }

class PageTurn extends StatelessWidget {
  const PageTurn(
      {super.key,
      required this.animation,
      required this.incoming,
      required this.forward,
      this.style = TurnStyle.deal,
      required this.child});
  final Animation<double> animation;
  final bool incoming;
  final bool forward;
  final TurnStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0); // 0 hidden, 1 in place
        // Forward: the old page leaves to the left and the new one comes
        // from the right; back is the other way round.
        final side = (incoming ? 1 : -1) * (forward ? 1 : -1);
        final away = 1 - t;
        switch (style) {
          case TurnStyle.fade:
            return Opacity(opacity: t, child: child);
          case TurnStyle.fadeThrough:
            return Opacity(
              opacity: t,
              child: Transform.scale(
                  scale: incoming ? 0.94 + 0.06 * t : 1, child: child),
            );
          case TurnStyle.slide:
            return Opacity(
              opacity: t,
              child: Transform.translate(
                  offset: Offset(side * 60 * away, 0), child: child),
            );
          case TurnStyle.sealPress:
            return Opacity(
              opacity: t,
              child: Transform.scale(
                  scale: incoming ? 1 + 0.07 * away : 1 - 0.03 * away,
                  child: child),
            );
          case TurnStyle.curtain:
            if (!incoming) return Opacity(opacity: t, child: child);
            final dir = forward ? 1.0 : -1.0;
            return LayoutBuilder(builder: (context, box) {
              final edge = box.maxWidth * t;
              return Stack(clipBehavior: Clip.none, children: [
                ClipRect(
                  clipper: _RevealClipper(t, fromLeft: dir > 0),
                  child: child,
                ),
                if (t > 0.01 && t < 0.99)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: dir > 0 ? edge - 1 : box.maxWidth - edge - 1,
                    width: 2,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Palette.gold,
                        boxShadow: [BoxShadow(color: Color(0xAAD4A63A), blurRadius: 10)],
                      ),
                    ),
                  ),
              ]);
            });
          case TurnStyle.deal:
            final glint = incoming ? math.sin(t * math.pi) : 0.0;
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(side * 36 * away, 6 * away),
                child: Transform.rotate(
                  angle: side * 0.035 * away,
                  child: Stack(children: [
                    child!,
                    if (glint > 0.01)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1.6 + 3.2 * t, -1),
                                end: Alignment(-0.9 + 3.2 * t, 1),
                                colors: [
                                  Palette.gold.withValues(alpha: 0),
                                  Palette.gold.withValues(alpha: 0.12 * glint),
                                  Palette.gold.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            );
        }
      },
    );
  }
}

/// Shows the part of a page uncovered so far, [t] of the way across.
class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.t, {required this.fromLeft});
  final double t;
  final bool fromLeft;

  @override
  Rect getClip(Size size) => fromLeft
      ? Rect.fromLTWH(0, -40, size.width * t, size.height + 80)
      : Rect.fromLTWH(size.width * (1 - t), -40, size.width * t, size.height + 80);

  @override
  bool shouldReclip(_RevealClipper old) => old.t != t || old.fromLeft != fromLeft;
}
