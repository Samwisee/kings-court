/// The tutorial's coach: what it says at each moment of a lesson, and the
/// note it says it on.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../engine/cards.dart';
import '../../../models.dart';
import '../../../modes/tutorial/lessons.dart';
import '../../../theme.dart';
import '../../../widgets.dart';

/// What the tutorial's coach says right now: nothing outside a tutorial
/// round in progress; the lesson's intro while the table is [settingUp]
/// (the King unchosen, the crowning or the deal under way); whose pick it
/// is; what the [lastTrick] still on the table meant; what to do on
/// [yourPlay]; else what to watch.
String? coachLine(GameState game,
    {required int you,
    required bool settingUp,
    required Trick? lastTrick,
    required bool yourPlay}) {
  if (!game.isTutorial || game.lesson >= lessons.length) return null;
  final l = lessons[game.lesson];
  if (game.outcome != RoundOutcome.inProgress) return null;
  if (settingUp) return l.intro;
  final c = game.round!;
  if (c.pickTurn == you) return l.pick;
  if (c.pickTurn != null) {
    return '${game.players[c.pickTurn!].name} is choosing a task.';
  }
  if (lastTrick != null) {
    final done = c.tricks.length - 1;
    return l.afterTrick[done] ??
        (lastTrick.winner == you
            ? 'You won the trick.'
            : '${game.players[lastTrick.winner].name} won the trick, and leads the next one.');
  }
  if (yourPlay) {
    final led = c.led;
    return l.yourTurn[c.tricks.length] ??
        (led == null
            ? 'Your lead: play any card.'
            : 'Your turn: follow ${led.isCourt ? 'with a Court Card' : led.suit.symbol} if you can.');
  }
  return l.watch[c.tricks.length] ?? 'The courtiers are playing.';
}

/// The coach: a parchment note between the table and your hand, with the
/// lesson's title, a way back to its pages or on to the next, and [line]
/// (nothing: the note folds away).
class Coach extends StatelessWidget {
  const Coach(
      {super.key,
      required this.lesson,
      required this.line,
      required this.onBack,
      required this.onSkip});

  /// The lesson under way, by index.
  final int lesson;
  final String? line;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = lessons[math.min(lesson, lessons.length - 1)];
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: line == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 12),
              // On the felt, edged in gold, like the rules.
              decoration: BoxDecoration(
                color: const Color(0xF20A3622),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Palette.gold.withValues(alpha: 0.7), width: 1.4),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black45, blurRadius: 10, offset: Offset(0, 3))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const CrownIcon(size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'Lesson ${lesson + 1} of ${lessons.length} · ${l.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: displayFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Palette.gold,
                              shadows: feltShadow)),
                    ),
                    // Back to this lesson's reading, or on to the next.
                    TextButton(
                      onPressed: onBack,
                      style: TextButton.styleFrom(
                          foregroundColor: Palette.gold,
                          overlayColor: Colors.transparent,
                          visualDensity: VisualDensity.compact),
                      child: const Text('Back'),
                    ),
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                          foregroundColor: Palette.gold,
                          overlayColor: Colors.transparent,
                          visualDensity: VisualDensity.compact),
                      child: const Text('Skip'),
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        key: ValueKey(line),
                        width: double.infinity,
                        // Room for three lines, so the hand below doesn't
                        // bob up and down as the advice changes.
                        constraints: const BoxConstraints(minHeight: 64),
                        alignment: Alignment.topLeft,
                        child: SuitText(line,
                            style: const TextStyle(
                                fontSize: 15.5,
                                height: 1.35,
                                color: Colors.white,
                                shadows: feltShadow)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
