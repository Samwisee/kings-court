/// A task card dealt onto the table at the start of a round: from the
/// pile in the middle it arcs out to its place, leaning to one side,
/// straightening and turning face up as it lands.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/skin_scope.dart';
import '../cards/card_view.dart';
import '../widgets.dart';

class DealtTask extends StatelessWidget {
  const DealtTask({
    super.key,
    required this.index,
    required this.from,
    required this.startMs,
    required this.child,
  });

  /// Its place in the deal: cards lean alternately left and right.
  final int index;

  /// Where it starts, from its place: the middle of the table.
  final Offset from;

  /// When it leaves the pile, from the start of the deal.
  final int startMs;

  /// The task, face up.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final side = index.isEven ? -1.0 : 1.0;
    final total = startMs + 820;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, raw, child) {
        final ms = raw * total;
        final d = ms < startMs
            ? 0.0
            : Curves.easeOutBack.transform(clampD((ms - startMs) / (total - startMs), 0, 1));
        final dc = clampD(d, 0, 1);
        final lift = math.sin(dc * math.pi) * 36;
        // Stacked a little in the pile.
        final pile = Offset(0, -index * 1.6);
        return Transform.translate(
          offset: from * (1 - d) + pile * (1 - dc) + Offset(0, -lift),
          child: Transform.rotate(
            angle: side * 0.3 * math.sin(dc * math.pi),
            child: Transform.scale(
              scale: 0.86 + 0.14 * dc,
              child: FlipIn(
                t: clampD(dc * 1.5 - 0.3, 0, 1),
                front: child!,
                // The back is exactly the size of the front.
                back: Stack(children: [
                  Opacity(opacity: 0, child: child),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: skin.cardLook.taskBack ??
                              [
                                skin.cardLook.back,
                                Color.lerp(skin.cardLook.back, Colors.black, 0.5)!
                              ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: skin.gold, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const CrownIcon(size: 26),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
