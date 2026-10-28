/// The end of a round: the card that comes up over the table (won or
/// lost, what failed and why, the Chronicle's crowns, the next round's
/// target and the buttons on from here), the tutorial's lesson card, and
/// how either arrives (a pop for a win, a drop and a red flush for a
/// loss).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/round.dart';
import '../../game/state.dart';
import '../../modes/chronicle/chapters.dart';
import '../../modes/tutorial/lessons.dart';
import '../../skin/skin_scope.dart';
import '../widgets.dart';

/// The outcome card's arrival over the table: [animation] runs from 0 to
/// 1 as it comes up; [child] is the card.
class OutcomeOverlay extends StatelessWidget {
  const OutcomeOverlay(
      {super.key,
      required this.animation,
      required this.won,
      required this.dealId,
      required this.child});

  final Animation<double> animation;
  final bool won;

  /// Seeds the confetti, so it falls the same way each time it's drawn.
  final int dealId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final appear = Curves.easeOut.transform(clampD(t / 0.25, 0, 1));
        final Widget card;
        if (won) {
          final pop = Curves.elasticOut.transform(clampD((t - 0.1) / 0.5, 0, 1));
          card = Opacity(
            opacity: appear,
            child: Transform.scale(scale: 0.6 + 0.4 * pop, child: child),
          );
        } else {
          final drop = Curves.bounceOut.transform(clampD(t / 0.45, 0, 1));
          card = Opacity(
            opacity: appear,
            child: Transform.translate(
              offset: Offset(0, -80 * (1 - drop)),
              child: child,
            ),
          );
        }
        // Losing: the felt flushes red once, then settles.
        final redPulse = won ? 0.0 : math.sin(clampD(t / 0.6, 0, 1) * math.pi);

        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Color.lerp(Colors.black45, const Color(0x99B3122B),
                    redPulse)!,
              ),
            ),
            if (won)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: CrownConfetti(skin: context.skin, progress: t, seed: dealId),
                  ),
                ),
              ),
            Center(child: card),
          ],
        );
      },
      child: child,
    );
  }
}

/// The end of a round, with the buttons on from here. [wording] is each
/// task's words as the table shows them (the announced number filled in).
class OutcomeCard extends StatefulWidget {
  const OutcomeCard(
      {super.key,
      required this.game,
      required this.won,
      required this.you,
      required this.onScreen,
      required this.crowns,
      required this.nextTarget,
      required this.canUndo,
      required this.wording,
      required this.onRetry,
      required this.onDeal,
      required this.onChapter,
      required this.onUndo});

  final GameState game;
  final bool won;
  final int you;
  final bool onScreen;

  /// Crowns earned (the Chronicle), 0 otherwise.
  final int crowns;

  /// The points the next round starts at on the slider.
  final int nextTarget;
  final bool canUndo;
  final String Function(RoundTask task) wording;
  final VoidCallback onRetry;

  /// Deal the next round to this many points.
  final void Function(int target) onDeal;

  /// Replay or go on to a Chronicle chapter.
  final void Function(int chapter) onChapter;
  final VoidCallback onUndo;

  @override
  State<OutcomeCard> createState() => _OutcomeCardState();
}

class _OutcomeCardState extends State<OutcomeCard> {
  late int nextTarget = widget.nextTarget;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final game = widget.game;
    final won = widget.won;
    final fg = won ? skin.ink : Colors.white;
    final you = widget.you;
    final onScreen = widget.onScreen;
    final crowns = widget.crowns;
    final wording = widget.wording;
    final failed = game.tasks.where((t) => t.isFailed).toList();
    final chapter = game.mode == GameMode.chronicle ? game.chapter : null;
    final hasNext = chapter != null && chapter < chronicle.length - 1;
    return OrnateCard(
      ornament: Ornament.medium,
      won: won,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.shrink(),
          const SizedBox(height: 6),
          if (chapter != null)
            Text('Chapter ${chapter + 1}: ${chronicle[chapter].title}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: skin.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: won ? skin.ink : skin.gold)),
          Text(won ? 'Round won' : 'Round lost',
              style: TextStyle(
                  fontFamily: skin.displayFont,
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  color: fg)),
          OrnateDivider(
              color: won ? skin.goldInk : skin.gold),
          Text(
            won
                ? 'Every task is done. The court rejoices.'
                : failed.length > 1
                    ? 'These tasks failed:'
                    : 'This task failed:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, color: fg),
          ),
          // What went wrong: each failed task, whose it was, and why.
          if (!won)
            for (final t in failed)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x55D9483B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SuitText(wording(t),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    SuitText(
                        [
                          if (t.owner != null)
                            t.owner == you && onScreen
                                ? 'Your task.'
                                : '${game.players[t.owner!].name}\u2019s task.',
                          t.whyFailed ?? 'Marked as failed.',
                        ].join(' '),
                        style: const TextStyle(
                            fontSize: 14.5, height: 1.3, color: Colors.white70)),
                  ],
                ),
              ),
          if (chapter != null && won) ...[
            const SizedBox(height: 8),
            // Crowns earned: 3 first time, 2 within three attempts, else 1.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: CrownIcon(
                        size: 28,
                        color: i < crowns
                            ? skin.ink
                            : const Color(0x33000000)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 2),
          if (chapter == null)
          Text(
              game.campaign
                  ? 'Win streak ${game.streak}, best ${game.bestStreak}'
                  : 'Won ${game.wins}, lost ${game.losses} so far',
              style: TextStyle(
                  fontSize: 15, color: won ? skin.ink : Colors.white70)),
          const SizedBox(height: 16),
          if (chapter == null) ...[
          Row(
            children: [
              Text('Next round',
                  style: TextStyle(fontSize: 16, color: fg)),
              const Spacer(),
              Text('$nextTarget',
                  style: TextStyle(
                      fontFamily: skin.displayFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: won ? skin.ink : skin.gold)),
              const SizedBox(width: 4),
              CrownIcon(color: won ? skin.ink : skin.gold),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: won ? skin.ink : skin.gold,
              thumbColor: won ? skin.ink : skin.gold,
              inactiveTrackColor: won ? Colors.black26 : Colors.white24,
            ),
            child: Slider(
              value: nextTarget.clamp(1, maxTarget).toDouble(),
              min: 1,
              max: maxTarget.toDouble(),
              divisions: maxTarget - 1,
              onChanged: (v) => setState(() => nextTarget = v.round()),
            ),
          ),
          const SizedBox(height: 4),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (chapter != null) ...[
                OutlinedButton(
                  onPressed: () => widget.onChapter(chapter),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: fg,
                      side: BorderSide(
                          color: won ? skin.ink : Colors.white54)),
                  child: Text(won ? 'Replay chapter' : 'Try again'),
                ),
                if (won && hasNext)
                  FilledButton(
                    onPressed: () => widget.onChapter(chapter + 1),
                    style: FilledButton.styleFrom(
                        backgroundColor: skin.ink,
                        foregroundColor: skin.gold),
                    child: const Text('Next chapter'),
                  ),
              ] else ...[
              OutlinedButton(
                onPressed: widget.onRetry,
                style: OutlinedButton.styleFrom(
                    foregroundColor: fg,
                    side: BorderSide(
                        color: won ? skin.ink : Colors.white54)),
                child: const Text('Retry'),
              ),
              FilledButton(
                onPressed: () => widget.onDeal(nextTarget),
                style: won
                    ? FilledButton.styleFrom(
                        backgroundColor: skin.ink,
                        foregroundColor: skin.gold)
                    : null,
                child: const Text('Deal'),
              ),
              ],
            ],
          ),
          if (widget.canUndo)
            TextButton(
              onPressed: widget.onUndo,
              style: TextButton.styleFrom(
                  foregroundColor: won ? skin.ink : Colors.white70),
              child: const Text('Undo last mark'),
            ),
        ],
      ),
    );
  }
}

/// The end of a lesson: what it taught, and on to the next.
class LessonCard extends StatelessWidget {
  const LessonCard(
      {super.key,
      required this.lesson,
      required this.won,
      required this.onRetry,
      required this.onNext});

  /// The lesson just played, by index.
  final int lesson;
  final bool won;
  final VoidCallback onRetry;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final fg = won ? skin.ink : Colors.white;
    final l = lessons[math.min(lesson, lessons.length - 1)];
    final last = lesson >= lessons.length - 1;
    return OrnateCard(
      ornament: Ornament.medium,
      won: won,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.shrink(),
          const SizedBox(height: 6),
          Text('Lesson ${lesson + 1}: ${l.title}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: skin.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: won ? skin.ink : skin.gold)),
          Text(
              won
                  ? (last ? 'Tutorial complete' : 'Lesson complete')
                  : 'Not quite',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: skin.displayFont,
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  color: fg)),
          const SizedBox(height: 6),
          SuitText(won ? l.won : l.lost,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.35, color: fg)),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                    foregroundColor: fg,
                    side: BorderSide(color: won ? skin.ink : Colors.white54)),
                child: Text(won ? 'Replay lesson' : 'Try again'),
              ),
              FilledButton(
                onPressed: onNext,
                style: won
                    ? FilledButton.styleFrom(
                        backgroundColor: skin.ink,
                        foregroundColor: skin.gold)
                    : null,
                child: Text(last
                    ? 'Finish'
                    : won
                        ? 'Next lesson'
                        : 'Skip to the next lesson'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
