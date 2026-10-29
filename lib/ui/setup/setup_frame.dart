/// The setup panel's frame: a crown for each step at the top, the step in
/// the middle turning like a page, and Back and Next fixed at the bottom.
library;

import 'package:flutter/material.dart';

import '../../skin/skin_scope.dart';
import '../widgets.dart';
import 'transitions.dart';

class SetupFrame extends StatelessWidget {
  const SetupFrame({
    super.key,
    required this.step,
    required this.steps,
    required this.forward,
    required this.canCancel,
    required this.nextLabel,
    required this.onBack,
    required this.onNext,
    required this.body,
    this.choosing,
  });

  final int step;
  final int steps;

  /// Whether the last step went forward, so the page turns the right way.
  final bool forward;

  /// Whether the first step has a way back to where setup was opened from.
  final bool canCancel;
  final String nextLabel;
  final VoidCallback onBack;
  /// Disabled when null.
  final VoidCallback? onNext;
  final Widget body;

  /// A step that goes on as soon as you choose, with no Next (the first
  /// two, unless said otherwise).
  final bool? choosing;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // The first two steps go on as soon as you choose.
    final choosing = this.choosing ?? step < 2;
    final still = MediaQuery.disableAnimationsOf(context);

    // Fills the screen: progress at the top, the step in the middle, and
    // the buttons fixed in the bottom corners so they never move. Every
    // word on the felt has the front page's soft shadow.
    return DefaultTextStyle.merge(
      style: TextStyle(shadows: skin.feltShadow),
      child: SizedBox.expand(
      child: Padding(
        // Clear of the table's edge and brass inlay all round.
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
        child: Column(
          children: [
            // Progress: one pip per step, with a way back on the first
            // two (which go on as soon as you choose).
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: AnimatedOpacity(
                    opacity: choosing && step == 0 && canCancel ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !(choosing && step == 0 && canCancel),
                      child: IconButton(
                        tooltip: 'Cancel',
                        onPressed: onBack,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    // A crown for each step: gold once reached, and the
                    // current one larger, springing up as you arrive.
                    children: [
                      for (int i = 0; i < steps; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedScale(
                            scale: i == step ? 1.5 : 1,
                            duration: const Duration(milliseconds: 360),
                            curve: Curves.easeOutCubic,
                            child: TweenAnimationBuilder<Color?>(
                              tween: ColorTween(
                                  end: i <= step ? skin.gold : Colors.white24),
                              duration: const Duration(milliseconds: 360),
                              builder: (context, c, _) =>
                                  CrownIcon(size: 14, color: c ?? Colors.white24),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: still ? 200 : 460),
                // The old step goes first, then the new one is dealt in.
                // Fade out, then fade in.
                switchInCurve: still
                    ? Curves.easeOut
                    : const Interval(0.5, 1, curve: Curves.easeOut),
                switchOutCurve: still
                    ? Curves.easeIn
                    : const Interval(0.5, 1, curve: Curves.easeIn),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.center,
                  children: [...previous, if (current != null) current],
                ),
                transitionBuilder: (child, a) => still
                    ? FadeTransition(opacity: a, child: child)
                    : PageTurn(
                        animation: a,
                        incoming: child.key == ValueKey(step),
                        forward: forward,
                        style: TurnStyle.fade,
                        child: child),
                child: Center(
                  key: ValueKey(step),
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: body,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Always there, so the step above never shifts: the buttons
            // fade in and out instead.
            const SizedBox(height: 12),
            // Kept near the step on a wide screen, not out in the corners.
            // The first step has a way back to where you came from.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, minHeight: 56, maxHeight: 56),
              child: Row(
              children: [
                AnimatedOpacity(
                  opacity: step > 0 || canCancel ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !(step > 0 || canCancel),
                    child: TextButton(
                      onPressed: onBack,
                      child: const Text('Back'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedOpacity(
                  opacity: choosing ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                  ignoring: choosing,
                  child: Align(
                    alignment: Alignment.centerRight,
                    // Shrinks rather than cutting the words off.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: FilledButton(
                    onPressed: onNext,
                    child: Text(nextLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                  ),
                  ),
                ),
              ],
            ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
