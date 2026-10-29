/// Parts a skin can draw itself, when its looks (looks.dart) can't say
/// what it wants: a card's face or back, a panel, the table's edge. Each
/// is handed what to draw, a few of the game's own pieces to draw it with
/// (the suit marks, the crown), and the standard part, to wrap or to fall
/// back on. A skin that leaves a part null gets the standard one, built
/// from its looks.
library;

import 'package:flutter/widgets.dart';

import '../engine/cards.dart';
import 'looks.dart';

/// The game's own pieces a part may draw with.
class PartKit {
  const PartKit({required this.suitMark, required this.crown});

  /// A suit's mark at a size, in a colour.
  final Widget Function(Suit suit, double size, Color colour) suitMark;

  /// The crown at a size (in the skin's gold when [colour] is null).
  final Widget Function(double size, {Color? colour}) crown;
}

class CardFaceSpec {
  const CardFaceSpec({
    required this.card,
    required this.width,
    required this.dimmed,
    required this.glow,
    required this.edge,
    required this.marks,
    required this.kit,
    required this.standard,
  });

  final PlayingCard card;
  final double width;

  /// Not playable right now; the trick's winner; a player's colour round
  /// it; colours of the players whose tasks need it.
  final bool dimmed;
  final bool glow;
  final Color? edge;
  final List<Color> marks;
  final PartKit kit;

  /// The face the skin's looks give.
  final Widget Function() standard;
}

class CardBackSpec {
  const CardBackSpec({required this.width, required this.kit, required this.standard});
  final double width;
  final PartKit kit;
  final Widget Function() standard;
}

class PanelSpec {
  const PanelSpec({
    required this.won,
    required this.court,
    required this.ornament,
    required this.edge,
    required this.margin,
    required this.padding,
    required this.maxWidth,
    required this.child,
    required this.kit,
    required this.standard,
  });

  final bool won;
  final bool court;
  final Ornament ornament;
  final Color? edge;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final double maxWidth;
  final Widget child;
  final PartKit kit;
  final Widget Function() standard;
}

class TableSpec {
  const TableSpec({required this.table, required this.standard});

  /// The whole table round the screen, or just the rules round a panel.
  final bool table;
  final Widget Function() standard;
}

/// The parts a skin draws itself; null for the standard one.
class SkinParts {
  const SkinParts({this.cardFace, this.cardBack, this.panel, this.table});

  final Widget Function(BuildContext context, CardFaceSpec spec)? cardFace;
  final Widget Function(BuildContext context, CardBackSpec spec)? cardBack;
  final Widget Function(BuildContext context, PanelSpec spec)? panel;
  final Widget Function(BuildContext context, TableSpec spec)? table;
}
