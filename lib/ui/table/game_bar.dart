/// The bar over a game: the round's name with anything in force beside it,
/// a way to pass the pick at a real table, the points target and the menu.
library;

import 'package:flutter/material.dart';

import '../../engine/decrees.dart';
import '../../engine/round.dart';
import '../../game/state.dart';
import '../../skin/skin_scope.dart';
import '../../skin/strings.dart';
import '../menu/menu.dart';
import '../widgets.dart';

class GameBar extends StatelessWidget implements PreferredSizeWidget {
  const GameBar({
    super.key,
    required this.title,
    required this.choosingKing,
    required this.decree,
    required this.onDecree,
    required this.passer,
    required this.onPass,
    required this.target,
    required this.onPoints,
    required this.menu,
  });

  /// The round, chapter or lesson.
  final String title;
  final bool choosingKing;

  /// The decree in force; tap it to read it again.
  final Decree? decree;
  final VoidCallback onDecree;

  /// Who may pass the pick on (at a real table), or null for nobody.
  final String? passer;
  final VoidCallback onPass;

  final int target;
  final VoidCallback onPoints;
  final Widget menu;

  /// What the bar calls [game]: the chapter, the lesson or the round.
  static String titleOf(GameState game) => game.mode == GameMode.chronicle && game.chapter != null
      ? 'Chapter ${game.chapter! + 1}'
      : game.isTutorial
          ? 'Lesson ${game.lesson + 1}'
          : 'Round ${game.roundNumber}';

  /// At a real table, whoever's picking may pass, once a round: their name.
  static String? passerOf(GameState game) {
    final r = game.round!;
    final picker = r.pickTurn;
    return !game.digital && picker != null && r.canPass(picker) ? game.players[picker].name : null;
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final decree = this.decree;
    return AppBar(
      toolbarHeight: 60,
      titleSpacing: 28,
      backgroundColor: Colors.transparent,
      title: Padding(
        padding: const EdgeInsets.only(top: 8),
        // The round's name, with anything in force this round beside it.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              flex: 3,
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: skin.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: skin.gold,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 10)])),
            ),
            if (choosingKing) ...[
              const SizedBox(width: 12),
              const Flexible(
                child: Text('Choose the King',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
              ),
            ],
            if (decree != null && !choosingKing) ...[
              const SizedBox(width: 8),
              Flexible(
                  child: InkWell(
                onTap: onDecree,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: skin.cardRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(decree.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              )),
            ],
          ],
        ),
      ),
      actions: [
        if (passer case final name?)
          Tooltip(
            message: '$name passes the pick on (once a round)',
            child: TextButton(
              onPressed: onPass,
              style: TextButton.styleFrom(foregroundColor: skin.gold),
              child: const Text(Strings.pass),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 10),
          child: Tooltip(
            message: Strings.pointsTarget,
            child: GoldBar(
              onTap: onPoints,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$target',
                      style: TextStyle(
                          fontFamily: skin.displayFont,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1,
                          color: skin.gold,
                          shadows: const [Shadow(blurRadius: 6)])),
                  const SizedBox(width: 5),
                  const CrownIcon(size: 18),
                ],
              ),
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.only(top: 8), child: menu),
        const SizedBox(width: 18),
      ],
    );
  }
}
