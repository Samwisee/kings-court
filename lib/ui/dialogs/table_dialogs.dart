/// The table's small dialogs: the points target, how many tricks you'll
/// win, who takes a task under the King's Command, and "You're ready"
/// after the tutorial.
library;

import 'package:flutter/material.dart';

import '../../game/state.dart';
import '../../skin/skin_scope.dart';
import '../../skin/strings.dart';
import '../widgets.dart';

/// Chooses a points target, starting from [current]; null when cancelled.
Future<int?> showPointsDialog(BuildContext context, {required int current}) async {
  final skin = context.skin;
  var target = current;
  final apply = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        child: OrnateCard(
          ornament: Ornament.medium,
          won: false,
          court: true,
          margin: const EdgeInsets.only(top: 34),
          padding: const EdgeInsets.fromLTRB(32, 30, 32, 28),
          maxWidth: 380,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Points target',
                    style: TextStyle(
                        fontFamily: skin.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        color: skin.goldOnFelt)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$target',
                        style: TextStyle(
                            fontFamily: skin.displayFont,
                            fontWeight: FontWeight.w900,
                            fontSize: 52,
                            height: 1.1,
                            color: skin.gold)),
                    const SizedBox(width: 8),
                    const CrownIcon(size: 32),
                  ],
                ),
                Slider(
                  value: target.clamp(1, maxTarget).toDouble(),
                  min: 1,
                  max: maxTarget.toDouble(),
                  divisions: maxTarget - 1,
                  onChanged: (v) => setDialogState(() => target = v.round()),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(Strings.cancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(Strings.deal)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return apply == true ? target : null;
}

/// How many tricks you'll win, for an "exactly X" task worded [text]: at
/// least [least] (one when you hold the King card), at most [totalTricks].
/// It can't be dismissed: the number is announced.
Future<int> showAnnounceDialog(BuildContext context,
    {required String text, required int least, required int totalTricks}) async {
  final skin = context.skin;
  var x = 1;
  final chosen = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) => CourtDialog(
        title: Strings.howManyTricks,
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context, x),
              child: const Text(Strings.announce)),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SuitText(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  onPressed: x > least ? () => setDialog(() => x--) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 70,
                  child: Text('$x',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: skin.bodyFont,
                          fontWeight: FontWeight.w800,
                          fontSize: 40,
                          color: skin.gold)),
                ),
                IconButton.outlined(
                  onPressed: x < totalTricks
                      ? () => setDialog(() => x++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Text(
                least > 0
                    ? '$totalTricks tricks in the round. You hold the King card, so you\u2019ll win at least one.'
                    : '$totalTricks tricks in the round.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
    ),
  );
  return chosen ?? x;
}

/// Under the King's Command: which of [seats] takes the task; null when
/// dismissed.
Future<int?> showWhoTakesDialog(BuildContext context,
    {required List<int> seats, required List<Player> players}) {
  return showDialog<int>(
    context: context,
    builder: (context) => CourtDialog(
      title: "King's Command: who takes it?",
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final s in seats)
          TextButton(
            onPressed: () => Navigator.pop(context, s),
            child: Text(players[s].name, style: const TextStyle(fontSize: 17)),
          ),
      ]),
    ),
  );
}

/// After the tutorial: play a game now (true), or not now.
Future<bool?> showReadyDialog(BuildContext context) {
  final skin = context.skin;
  return showDialog<bool>(
    context: context,
    builder: (context) => CourtDialog(
      title: 'You’re ready',
      ornament: Ornament.medium,
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Strings.playAGame)),
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Strings.notNow)),
      ],
      child: SuitText(
          'Set up a game of your own now? How to Play in the menu has every rule whenever you need it.',
          textAlign: TextAlign.center,
          style: skin.dialogBody),
    ),
  );
}
