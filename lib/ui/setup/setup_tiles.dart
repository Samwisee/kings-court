/// The setup panel's choices: a way to play, and a number of players.
library;

import 'package:flutter/material.dart';

import '../../skin/skin_scope.dart';
import '../menu/menu.dart';

/// One way to play on the first setup step.
class ModeTile extends StatelessWidget {
  const ModeTile(
      {super.key, required this.title,
      this.badge,
      this.badgeGold = false,
      this.icon,
      required this.description,
      required this.selected,
      required this.onTap});
  final String title;

  /// A gold icon at the start of the tile.
  final IconData? icon;

  /// A note beside the title, such as "(Alpha)" for a mode still taking
  /// shape.
  final String? badge;

  /// The badge in gold, for one that invites rather than warns.
  final bool badgeGold;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
      color: selected ? skin.gold.withValues(alpha: 0x33 / 255) : const Color(0x22000000),
      // Gold double rule with a jewel in each corner, like the menus.
      shape: OrnateBorder(skin: context.skin, radius: 12, gems: false),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 12, 10),
          child: Row(children: [
            if (icon != null) ...[
              Icon(icon, color: skin.gold, size: 28),
              const SizedBox(width: 14),
            ],
            Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(title,
                        style: TextStyle(
                            fontFamily: skin.displayFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: selected ? skin.gold : Colors.white)),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Text(badge!,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: badgeGold ? skin.gold : Colors.white70)),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(description,
                  style: const TextStyle(
                      fontSize: 14, height: 1.3, color: Colors.white70)),
            ],
          ),
            ),
            Icon(Icons.chevron_right_rounded, color: skin.gold),
          ]),
        ),
      ),
    ),
    );
  }
}

/// A big number to tap for the player count.
class CountChip extends StatelessWidget {
  const CountChip(
      {super.key, required this.n, required this.selected, required this.onTap});
  final int n;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      button: true,
      selected: selected,
      label: '$n players',
      excludeSemantics: true,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
        onTap: onTap,
        // A large gold pip: a gold ring, filled with a glowing jewel
        // when chosen, the number in its middle.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x22000000),
            border: Border.all(color: skin.gold, width: 2.5),
            boxShadow: selected
                ? [BoxShadow(color: skin.gold.withValues(alpha: 0.45), blurRadius: 12)]
                : null,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: selected
                  ? RadialGradient(
                      center: const Alignment(-0.3, -0.4),
                      colors: [skin.goldPale, skin.gold])
                  : null,
            ),
            child: Text('$n',
                textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
                style: TextStyle(
                    fontFamily: skin.displayFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    height: 1,
                    color: selected ? skin.ink : Colors.white,
                    shadows: selected
                        ? null
                        : const [Shadow(color: Colors.black54, blurRadius: 8)])),
          ),
        ),
      )),
    );
  }
}
