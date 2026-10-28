/// "Play!" bursting over the table as the last task is taken.
library;

import 'package:flutter/material.dart';

import '../../skin/theme.dart';
import '../widgets.dart';

class PlayFlourish extends StatelessWidget {
  const PlayFlourish({super.key, required this.animation});

  /// Runs from 0 to 1 as the word pops and fades.
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        final scale = 0.6 + 0.5 * Curves.elasticOut.transform(clampD(t / 0.5, 0, 1));
        final opacity = t < 0.75 ? 1.0 : (1 - t) / 0.25;
        return Center(
          child: Opacity(
            opacity: clampD(opacity, 0, 1),
            child: Transform.scale(
              scale: scale,
              child: const Text('Play!',
                  style: TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 56,
                      color: Palette.gold,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 16)])),
            ),
          ),
        );
      },
    );
  }
}
