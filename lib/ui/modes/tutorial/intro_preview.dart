/// A task's close-up from the tutorial's pages, as in a game.
library;

import 'package:flutter/material.dart';

import '../../../engine/task.dart';
import '../../../engine/task_help.dart';
import '../../../skin/skin_scope.dart';
import '../../widgets.dart';

/// A task's close-up, as in a game: its points and marks, its words, what
/// each mark means, and what the task means in plain words.
void showIntroTaskPreview(BuildContext context, Task task) {
  final marks = <(Widget, String)>[
    if (task.noCourtCards)
      (const NoCourtIcon(size: 16), 'The trick can\u2019t have any Court Cards in it.'),
    if (task.kingCantTake)
      (Icon(Icons.block, size: 16, color: context.skin.inkSoft),
          'The King can\u2019t take this task.'),
    for (final n in task.notes)
      (Icon(Icons.info_outline, size: 16, color: context.skin.inkSoft), n),
  ];
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: context.skin.paper,
      shape: HighVisBorder(null, context.skin),
      scrollable: true,
      contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('${task.getPointsForPlayerCount(3)}',
                  style: TextStyle(
                      fontFamily: context.skin.displayFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      height: 1,
                      color: context.skin.ink)),
              const SizedBox(width: 3),
              CrownIcon(size: 19, color: context.skin.goldDeep),
              for (final (icon, _) in marks) ...[
                const SizedBox(width: 7),
                icon,
              ],
            ]),
            const SizedBox(height: 6),
            SuitText(task.fullText(3),
                style: TextStyle(
                    fontSize: 19,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: context.skin.ink)),
            for (final (icon, words) in marks)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 26, child: Align(alignment: Alignment.topLeft, child: icon)),
                  Expanded(
                    child: SuitText(words,
                        style: TextStyle(
                            fontSize: 14.5, height: 1.35, color: context.skin.inkSoft)),
                  ),
                ]),
              ),
            const SizedBox(height: 12),
            SuitText(explainTask(task.description),
                style: TextStyle(fontSize: 15, height: 1.4, color: context.skin.ink)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: context.skin.ink),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
