/// A task in the middle of the table, waiting to be taken: faded when you
/// can't take it on your pick, and marked in a player's colour when only
/// they can.
library;

import 'package:flutter/material.dart';

import '../../engine/round.dart';
import '../../skin/skin_scope.dart';
import '../cards/task_chip.dart';

class OpenTask extends StatelessWidget {
  const OpenTask({
    super.key,
    required this.placeKey,
    required this.task,
    required this.taken,
    required this.faded,
    required this.points,
    required this.text,
    required this.width,
    required this.fontSize,
    required this.focused,
    required this.only,
    required this.onTap,
    required this.onLongPress,
  });

  /// On its place, to measure where it flies from when it's taken.
  final GlobalKey placeKey;
  final RoundTask task;

  /// Taken, and flying to its owner: its place is kept, unseen.
  final bool taken;

  /// You can't take it on your pick.
  final bool faded;
  final int points;
  final String text;
  final double width;
  final double fontSize;

  /// Chosen with the arrow keys.
  final bool focused;

  /// Who alone may take it (a line saying so, in their colour), or null.
  final (String, Color)? only;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final only = this.only;
    return IgnorePointer(
      ignoring: taken,
      child: AnimatedOpacity(
        key: placeKey,
        duration: Duration.zero,
        opacity: taken
            ? 0
            : faded
                ? 0.5
                : 1,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TaskChip(
            task: task,
            points: points,
            text: text,
            color: only?.$2 ?? context.skin.inkSoft,
            width: width,
            fontSize: fontSize,
            focused: focused,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
          if (only != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(only.$1,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: only.$2)),
            ),
        ]),
      ),
    );
  }
}
