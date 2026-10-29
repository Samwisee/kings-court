/// The shapes of a skin, beside its colours: how its table, panels, cards,
/// seat tokens and buttons are built. Each is a small value a skin sets
/// (the King's Court sets today's look; a designed skin derives them from
/// its design). The widgets read them and draw accordingly, so a new skin
/// changes the look without touching a widget. For anything these can't
/// say, a skin can draw a part itself (parts.dart).
library;

import 'package:flutter/painting.dart';

/// How dressed up a panel or dialog is. Everything is [low] unless it's an
/// occasion:
/// * [low]: the ground and its edge.
/// * [medium]: an occasion's mark over the top (the menu, a lesson or
///   round's result, You're ready): the court's crown medallion.
/// * [high]: a win's sheen as well.
enum Ornament { low, medium, high }

/// How the screen's edge looks round the play area.
enum TableStyle {
  /// The felt set into a table: the table's colour round the edge, the
  /// felt sunk a little into it, and rules where they meet.
  rimmed,

  /// No rim: the play area runs to the edge, with a fine line inside it.
  edged,
}

class TableLook {
  const TableLook({
    required this.style,
    this.rim = 7,
    this.radius = 16,
    this.outerRule,
    this.innerRule,
    this.sunk = true,
    this.panelRule,
    this.panelInnerRule,
    this.lamp = 0,
  });

  final TableStyle style;

  /// How much of the table shows round the felt, and the felt's corners.
  final double rim;
  final double radius;

  /// The rule where the felt meets the table, and a fainter one inside it;
  /// null for none.
  final Color? outerRule;
  final Color? innerRule;

  /// A soft shadow just inside the felt's edge, as if sunk into the table.
  final bool sunk;

  /// The rules round a panel set on the felt (the card tracker).
  final Color? panelRule;
  final Color? panelInnerRule;

  /// How far the felt darkens towards its corners, as if lit by a lamp
  /// over the middle of the table: 0 for an even felt, about 0.3 for a
  /// card room's.
  final double lamp;
}

/// How menus, results and dialogs are framed.
enum PanelStyle {
  /// A gradient card with a patterned ground, rules and corner scrolls,
  /// a medallion over the top on occasions, and a sheen for a win.
  ornate,

  /// A flat card with a clean edge and a soft shadow; occasions get a
  /// coloured band along the top instead of a medallion.
  flat,
}

class PanelLook {
  const PanelLook({
    required this.style,
    required this.court,
    required this.won,
    required this.lost,
    required this.courtMedallion,
    required this.wonMedallion,
    required this.lostMedallion,
    this.radius = 18,
    this.edgeWidth = 2.5,
  });

  final PanelStyle style;

  /// The ground (top left to bottom right) of a panel in the court's own
  /// colours (menus, settings), of a won result, and of a lost one.
  final List<Color> court;
  final List<Color> won;
  final List<Color> lost;

  /// The medallion's ground for each (ornate), or its band (flat).
  final List<Color> courtMedallion;
  final List<Color> wonMedallion;
  final List<Color> lostMedallion;

  final double radius;
  final double edgeWidth;
}

/// How the Court Cards' faces are drawn.
enum CourtCardStyle {
  /// Each on its own patterned cloth with its emblem, framed in gold: the
  /// printed deck's art.
  emblems,

  /// A clean face: the card's letter large, its emblem small, on the card
  /// stock with a coloured band.
  letters,
}

class CardLook {
  const CardLook({
    required this.courtStyle,
    required this.cloth,
    required this.courtFrame,
    required this.back,
    required this.backEdge,
    this.radius = 0.1,
    this.backPattern = false,
    this.small,
    this.taskBack,
    this.backRule,
    this.backCrown,
    this.backPatternAlpha = 0.35,
  });

  final CourtCardStyle courtStyle;

  /// Each Court Card's colours, Joker, Jack, Queen, King: light then dark.
  final List<List<Color>> cloth;

  /// The fine frame inside a Court Card's edge.
  final Color courtFrame;

  /// A card's back, and the edge round it.
  final Color back;
  final Color backEdge;

  /// Corner radius, as a share of the card's width.
  final double radius;

  /// A fine lattice over the back, in [backEdge] at [backPatternAlpha].
  final bool backPattern;
  final double backPatternAlpha;

  /// A fine rule inside the back's edge; null for none.
  final Color? backRule;

  /// The crown on the back in one colour; null for the skin's gilt crown.
  final Color? backCrown;

  /// Each Court Card's one colour on a small card (a played card, the
  /// tracker); between its cloth's two when null.
  final List<Color>? small;

  /// A task card's back as the tasks are shuffled (top left to bottom
  /// right); the card back's colour, shaded, when null.
  final List<Color>? taskBack;
}

class TokenLook {
  const TokenLook({this.shaped = true, this.ringWidth = 2});

  /// Each courtier in the shape of their house (a shield, a hexagon…);
  /// otherwise every seat is a disc.
  final bool shaped;

  /// The ring round a seat (thicker for the King and whoever's turn it is).
  final double ringWidth;
}

class ButtonLook {
  const ButtonLook({this.bevelled = true, this.glow = true});

  /// Cut corners, like plaques at court; otherwise rounded.
  final bool bevelled;

  /// The pulsing light round the button that's waiting to be pressed.
  final bool glow;
}
