/// A task's close-up: the card as on the table, what each mark means,
/// how it's going, the cards it's about, and what to do with it: take it
/// (your pick, on screen) or mark it done or failed (at a real table).
library;

import 'package:flutter/material.dart';

import '../../engine/decrees.dart';
import '../../engine/round.dart';
import '../../engine/task_help.dart';
import '../../game/state.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../../skin/theme.dart';
import '../cards/task_chip.dart';
import '../widgets.dart';

/// The marks a task card carries beside its points (the same as on the
/// table), each with what it means.
List<(Widget, String)> taskMarks(Skin skin, RoundTask task, double size) => [
      if (task.noCourtCards)
        (NoCourtIcon(size: size), 'The trick can\u2019t have any Court Cards in it.'),
      if (task.kingCantTake)
        (Icon(Icons.block, size: size, color: skin.inkSoft),
            'The King can\u2019t take this task.'),
      for (final n in task.notes)
        (Icon(Icons.info_outline, size: size, color: skin.inkSoft), n),
      if (task.seal != null)
        (WaxSeal(seal: task.seal!, size: size + 3), Seals.describe(task.seal!)),
    ];

/// Opens [TaskCloseUp] as a dialog.
Future<void> showTaskCloseUp(BuildContext context, TaskCloseUp closeUp) =>
    showDialog<void>(context: context, builder: (_) => closeUp);

class TaskCloseUp extends StatelessWidget {
  const TaskCloseUp({
    super.key,
    required this.task,
    required this.round,
    required this.players,
    required this.quarterTurns,
    required this.onScreen,
    this.progress,
    this.struck = const {},
    this.status,
    this.cards = const [],
    this.onTake,
    this.onMark,
  });

  final RoundTask task;
  final Round round;
  final List<Player> players;

  /// Turned to face whoever holds it at a real table.
  final int quarterTurns;
  final bool onScreen;

  /// How far along it is ("2/4"), while it's open on screen.
  final String? progress;

  /// Cards it names that its owner has already won, crossed out.
  final Set<String> struck;

  /// Why it's settled, once it is.
  final String? status;

  /// The cards it's about, marked as in the tracker.
  final List<MarkedCard> cards;

  /// On screen, your pick: take it from here. Null when you can't.
  final VoidCallback? onTake;

  /// At a real table: mark it done or failed (or not).
  final void Function(TaskStatus)? onMark;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final owner = task.owner == null ? null : players[task.owner!];
    return RotatedBox(
        quarterTurns: quarterTurns,
        child: AlertDialog(
        backgroundColor: task.isFailed ? skin.failedCard : skin.paper,
        // Whose it is shows as on the table: their colour, edged in dark.
        shape: HighVisBorder(task.isFailed ? skin.lost : owner?.color, context.skin),
        scrollable: true,
        contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Laid out as the card on the table: points and crown, then
              // the words.
              Row(
                children: [
                  Text('${task.points(players.length)}',
                      style: TextStyle(
                          fontFamily: skin.displayFont,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          height: 1,
                          color: skin.ink)),
                  const SizedBox(width: 3),
                  CrownIcon(size: 19, color: skin.goldDeep),
                  // The same marks as the card on the table, each
                  // explained under the words.
                  for (final (icon, _) in taskMarks(skin, task, 21)) ...[
                    const SizedBox(width: 7),
                    icon,
                  ],
                  const Spacer(),
                  if (progress case final p? when !task.isCompleted && !task.isFailed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: skin.ink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(p,
                          style: TextStyle(
                              fontFamily: skin.bodyFont,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: skin.gold)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SuitText(task.fullText(players.length),
                  struck: struck,
                  style: TextStyle(
                      fontSize: 19,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: skin.ink)),
              // What each mark by the points means.
              for (final (icon, words) in taskMarks(skin, task, 16))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 26,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Align(alignment: Alignment.topLeft, child: icon),
                          )),
                      Expanded(
                        child: SuitText(words,
                            style: TextStyle(
                                fontSize: 14.5, height: 1.35, color: skin.inkSoft)),
                      ),
                    ],
                  ),
                ),
              // Once it's settled, why: a plain line (the badge by the
              // points tells how it's going until then).
              if (status case final status?
                  when task.isCompleted || task.isFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: SuitText(status,
                        style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: task.isCompleted ? skin.won : skin.lost)),
                  ),
                ),
              // The cards it's about, and what's become of them.
              if (relevantCards(task.description).isNotEmpty)
                TaskCardsRow(cards: cards),
              // What it means, the game words it uses and any fine print,
              // behind an info button.
              MoreAbout(
                explanation: explainTask(task.description),
                terms: termsIn(task.description),
                notes: const [],
              ),
            ],
          ),
        ),
        actions: onScreen
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: skin.ink),
                  child: const Text('Close'),
                ),
                // Your pick: take it from here too.
                if (onTake case final take?)
                  FilledButton(
                    // Ready for Enter, when chosen with the keys.
                    autofocus: true,
                    onPressed: () {
                      Navigator.pop(context);
                      take();
                    },
                    child: const Text('Take'),
                  ),
              ]
            : [
          OutlinedButton.icon(
            onPressed: () {
              onMark!(TaskStatus.failed);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close_rounded),
            label: Text(task.isFailed ? 'Not failed' : 'Failed'),
            style: OutlinedButton.styleFrom(
                foregroundColor: skin.lost,
                side: BorderSide(color: skin.lost)),
          ),
          FilledButton.icon(
            onPressed: () async {
              // Completing a sealed task out of order fails the round.
              final problem = task.isCompleted ? null : round.sealProblem(task);
              if (problem != null) {
                final fail = await confirmSealBreak(context, problem, quarterTurns);
                if (!context.mounted) return;
                Navigator.pop(context);
                if (fail == true) onMark!(TaskStatus.failed);
                return;
              }
              onMark!(TaskStatus.completed);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_rounded),
            label: Text(task.isCompleted ? 'Not done' : 'Done'),
            style: FilledButton.styleFrom(
                backgroundColor: skin.won, foregroundColor: Colors.white),
          ),
        ],
        ),
      );
  }
}

/// Asks what to do about a seal completed out of order: null or false to
/// go back, true to fail the round.
Future<bool?> confirmSealBreak(BuildContext context, String problem, int quarterTurns) {
  final skin = context.skin;
  return showDialog<bool>(
    context: context,
    builder: (context) => RotatedBox(
      quarterTurns: quarterTurns,
      child: AlertDialog(
        backgroundColor: skin.paper,
        shape: HighVisBorder(null, context.skin),
        title: Text('A seal is broken', style: skin.paperTitle),
        content: Text(
            '$problem\n\nIf this task really was done out of order, the round is lost.',
            style: TextStyle(fontSize: 16, height: 1.4, color: skin.ink)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: skin.ink),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: skin.lost, foregroundColor: Colors.white),
            child: const Text('It was: fail the round'),
          ),
        ],
      ),
    ),
  );
}
