/// The seats on the on-screen table: the courtiers across the top, each
/// with their tasks under them, and you at the foot with yours; and a card
/// shown with the speech token, tucked beside its player.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/round.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../cards/card_back.dart';
import '../cards/card_view.dart';
import '../cards/mini_card.dart';
import '../welcome/welcome.dart';
import '../widgets.dart';

/// A task in front of its owner, at a width and type size.
typedef TaskBuilder = Widget Function(RoundTask task, double width, {double fontSize});

/// The courtiers across the top, each with their tasks under them.
class OpponentsRow extends StatelessWidget {
  const OpponentsRow({
    super.key,
    required this.seats,
    required this.width,
    required this.maxHeight,
    required this.name,
    required this.token,
    required this.onTap,
    required this.tallyShown,
    required this.won,
    required this.tally,
    required this.tasks,
    required this.task,
    required this.quip,
    required this.tokenSize,
    required this.taskWidth,
  });

  final List<int> seats;
  final double width;
  final double maxHeight;

  /// What a seat is called under its token.
  final String Function(int seat) name;

  /// A seat's token at a size, with any card they've shown beside it.
  final Widget Function(int seat, double size) token;

  /// What tapping a seat does.
  final VoidCallback? Function(int seat) onTap;

  /// Whether the tricks won show yet (their room is kept regardless): a
  /// pile of them face down under each token ([won]), and a word under
  /// that ([tally]: the cards left).
  final bool tallyShown;
  final int Function(int seat) won;
  final String Function(int seat) tally;

  final List<RoundTask> Function(int seat) tasks;
  final TaskBuilder task;

  /// What a courtier is saying, if anything.
  final String? Function(int seat) quip;

  final double tokenSize;

  /// The widest a courtier's task may be.
  final double taskWidth;

  @override
  Widget build(BuildContext context) {
    final colWidth = width / math.max(1, seats.length);
    final taskW = math.min(colWidth - 6, taskWidth);
    Widget column(int seat) {
      final says = quip(seat);
      return SizedBox(
        key: ValueKey('col-$seat'),
        width: colWidth,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            // A courtier's quip floats over their column rather than
            // pushing their tasks down and back up again. The column
            // fills its width so its contents stay centred.
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              fit: StackFit.passthrough,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The token, name and tally are all one big target, so
                    // a tap anywhere on them reaches the courtier.
                    MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onTap(seat),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            token(seat, tokenSize),
                            Text(name(seat),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    shadows: context.skin.feltShadow)),
                            Opacity(
                              opacity: tallyShown ? 1 : 0,
                              child: TrickPile(won: tallyShown ? won(seat) : 0),
                            ),
                            Opacity(
                              opacity: tallyShown ? 1 : 0,
                              child: Text(tally(seat),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
                            ),
                          ]),
                        )),
                    for (final t in tasks(seat))
                      task(t, taskW,
                          fontSize: colWidth < 80
                              ? 11
                              : width > 600
                                  ? 13.5
                                  : 12),
                  ],
                ),
                if (says != null)
                  Positioned(
                    top: tokenSize + 22,
                    left: 0,
                    right: 0,
                    // Never in the way of a tap on the courtier.
                    child: IgnorePointer(
                      child: Center(
                        child: SpeechBubble(says,
                            key: ValueKey('quip-$seat-$says'), tailAbove: true),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Only as tall as the bots' tasks need (so there's room for the tasks
    // being picked), growing smoothly as tasks arrive.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [for (final seat in seats) column(seat)],
        ),
      ),
    );
  }
}

/// You at the foot of the table: your token and tally, the card you've
/// shown, and your tasks in a row that scrolls under you when it's full.
class YourSeat extends StatelessWidget {
  const YourSeat({
    super.key,
    required this.width,
    required this.token,
    required this.shown,
    required this.tallyShown,
    required this.won,
    required this.tasks,
    required this.task,
    required this.scrolled,
  });

  final double width;
  final Widget token;
  final Widget? shown;

  /// Whether the tricks you've won show yet (their room is kept
  /// regardless): a pile of them face down under your token.
  final bool tallyShown;
  final int won;
  final List<RoundTask> tasks;
  final TaskBuilder task;

  /// Whether your tasks are scrolled along (set here as they scroll).
  final ValueNotifier<bool> scrolled;

  static const _tokenW = 58.0;

  /// A place kept for the card you show, as tall as your token.
  static const _revealW = 40 / 1.3 + 12;
  static const _leadW = _tokenW + _revealW;

  @override
  Widget build(BuildContext context) {
    final you = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _tokenW,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              token,
              // Room kept from the start, so nothing shifts when it appears.
              Opacity(opacity: tallyShown ? 1 : 0, child: TrickPile(won: tallyShown ? won : 0)),
            ],
          ),
        ),
        SizedBox(width: _revealW, child: Center(child: shown)),
      ],
    );
    final row = tasks.isEmpty
        ? const SizedBox.shrink()
        // Your tasks scroll sideways when they don't fit, slipping under
        // your token and shown card rather than stopping short of them.
        : NotificationListener<ScrollUpdateNotification>(
            onNotification: (n) {
              final now = n.metrics.pixels > 2;
              if (now != scrolled.value) scrolled.value = now;
              return false;
            },
            // Shown on past the row's end, through the margin to the
            // brass edge.
            child: ClipRect(
              clipper: const ReachRight(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.only(left: _leadW),
                child: Row(children: [
                  for (final t in tasks)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: task(t, math.min(width > 600 ? 190.0 : 140.0, width / 3),
                          fontSize: width > 600 ? 15 : 13),
                    ),
                ]),
              ),
            ),
          );
    // The whole width, so you sit at its left end.
    return SizedBox(
      width: width,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          // Keeps the row at least as tall as you.
          const SizedBox(width: _leadW, height: 80),
          row,
          // You, at your full size, over the start of the row. Nothing
          // behind you: tasks scrolled under your token and shown card
          // stay in sight, with your glow over them.
          Positioned(left: 0, child: you),
        ],
      ),
    );
  }
}

/// The tricks a player has won, face down in a little pile in front of
/// them (in the card backs worn), with how many beside it. Room is kept
/// for it with none.
class TrickPile extends StatelessWidget {
  const TrickPile({super.key, required this.won, this.cardWidth = 13});
  final int won;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final h = PlayingCardView.heightFor(cardWidth);
    final shown = math.min(won, 6);
    final step = cardWidth * 0.3;
    return SizedBox(
      height: h + 6,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (shown > 0)
          // Drawn once, then left: it changes only when a trick is won.
          RepaintBoundary(
            child: SizedBox(
              width: cardWidth + step * (shown - 1) + 3,
              height: h + 6,
              child: Stack(clipBehavior: Clip.none, children: [
                for (var k = 0; k < shown; k++)
                  Positioned(
                    left: k * step,
                    top: 3 + (k.isOdd ? 1.0 : 0),
                    child: Transform.rotate(
                        angle: (k.isEven ? -1 : 1) * 0.07, child: CardBack(width: cardWidth)),
                  ),
              ]),
            ),
          ),
        if (won > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('$won',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    shadows: context.skin.feltShadow)),
          ),
      ]),
    );
  }
}

/// [token] with [shown] (a card its player has shown) tucked beside it, so
/// showing a card never takes room from the trick. Always the same shape,
/// card or no card: otherwise showing a card would rebuild the token from
/// scratch, and it would arrive all over again.
Widget withShownCard(Widget token, Widget? shown, {required double size}) => Stack(
      clipBehavior: Clip.none,
      children: [
        token,
        // Level with the token (below its crown slot), as tall as it.
        if (shown != null) Positioned(right: -(size / 1.3 + 8), top: 14, child: shown),
      ],
    );

/// The card [seat] has shown with the speech token, while it's still in
/// hand; null if none. High contrast: framed in the player's [colour] with
/// dark lines, and what was said about it on a dark tag.
Widget? shownCard(Skin skin, Round round, int seat, Color colour, {double height = 40}) {
  final card = round.revealed[seat];
  if (card == null || !round.hasCards || !round.holds(seat, card)) return null;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      MiniCard(card: card, width: height / 1.3, edge: colour),
      const SizedBox(height: 3),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF14100A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: skin.gold),
        ),
        // One short word: high, low or only.
        child: Text(
            switch (round.revealHint[seat]) {
              'highest' => 'high',
              'lowest' => 'low',
              final h => h ?? '',
            },
            maxLines: 1,
            softWrap: false,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: skin.gold)),
      ),
    ],
  );
}
