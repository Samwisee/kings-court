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
    this.pattern = FeltPattern.none,
    this.patternColour = const Color(0x00000000),
  });

  /// This look with [pattern] worked into the felt in [colour].
  TableLook withPattern(FeltPattern pattern, Color colour) => TableLook(
        style: style,
        rim: rim,
        radius: radius,
        outerRule: outerRule,
        innerRule: innerRule,
        sunk: sunk,
        panelRule: panelRule,
        panelInnerRule: panelInnerRule,
        lamp: lamp,
        pattern: pattern,
        patternColour: colour,
      );

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

  /// The light of a lamp over the middle of the table: how much white is
  /// in the felt at its brightest (0 for an even felt, about 0.07 for a
  /// card room's). It fades to the felt's own colour at the edges.
  final double lamp;

  /// What's worked into the felt, faintly, in [patternColour]
  /// (ui/widgets/felt_patterns.dart).
  final FeltPattern pattern;
  final Color patternColour;
}

/// What's worked into a table's felt, under everything on it.
enum FeltPattern {
  /// An even felt.
  none,

  /// A garden trellis: a diamond lattice with a leaf at each crossing.
  trellis,

  /// A sea chart: a compass rose in the middle and rhumb lines out from it.
  chart,

  /// A night sky: scattered stars, a few bright, and a constellation.
  stars,

  /// Damask: rows of a woven flower, turned each row.
  damask,

  /// Fine pinstripes, in pairs.
  pinstripe,

  /// Tooled leather: a gilt rule inside the edge with a flourish in each
  /// corner.
  tooled,

  /// A chequer, the squares a shade apart.
  chequer,

  /// The boards of a tavern table, with their grain.
  planks,

  /// Marble's veins.
  marble,

  /// Art deco: rows of fans, one over the next.
  deco,

  /// Tiles, each with a four-leaved star.
  tiles,

  /// A campaign map's contour lines round a few hills.
  contours,

  /// Herringbone parquet.
  herringbone,
}

/// The frame printed on a task card's face, inside its edge.
enum TaskFrame {
  /// Just the card.
  plain,

  /// A fine double rule inside the edge.
  ruled,

  /// A bracket in each corner.
  corners,

  /// A band across the top, under the points.
  ribbon,

  /// A dotted rule, like a stamp's perforations.
  stamp,

  /// A rule down the left, like a ledger's margin.
  ledger,
}

/// How a task card's face is drawn: its stock, the ink on it, the points'
/// crown, the frame printed on it, and anything faint over the stock.
class TaskLook {
  const TaskLook({
    required this.face,
    required this.ink,
    required this.inkSoft,
    this.crown,
    this.frame = TaskFrame.plain,
    this.frameColour,
    this.motif = BackMotif.none,
    this.motifAlpha = 0.08,
  });

  final Color face;
  final Color ink;
  final Color inkSoft;

  /// The crown by the points; the skin's deep gold when null.
  final Color? crown;
  final TaskFrame frame;

  /// The frame's colour; the soft ink, faintly, when null.
  final Color? frameColour;

  /// A motif over the stock, in the ink at [motifAlpha].
  final BackMotif motif;
  final double motifAlpha;

  /// The frame's colour as drawn.
  Color get rule => frameColour ?? inkSoft.withValues(alpha: 0.45);

  /// The words on a pill of [ink] (how far along a task is): [gold] on
  /// dark ink, the stock on light.
  Color pillInk(Color gold) => ink.computeLuminance() > 0.4 ? face : gold;
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
    this.corners = PanelCorners.scrolls,
  });

  final PanelStyle style;

  /// What's in a panel's corners, inside its rule.
  final PanelCorners corners;

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

/// What's set in a panel's corners (and along its rule), the room's own
/// mark on every menu and dialog.
enum PanelCorners {
  /// Nothing: just the panel (and its rule, if it has one).
  none,

  /// A curl of filigree: the court's.
  scrolls,

  /// Art deco fans, the rule stepped in at each corner.
  fans,

  /// A gilt leaf in each corner and a tooled line of dots along the rule.
  tooled,

  /// A small star in each corner, with a pair of fainter ones.
  stars,

  /// A compass point in each corner.
  compass,

  /// Brass studs along the rule.
  studs,

  /// A sprig of leaves in each corner.
  leaves,

  /// A fine bracket in each corner.
  brackets,

  /// A woven flower in each corner.
  damask,

  /// A little chequer in each corner.
  chequer,

  /// A lozenge in each corner, as on a marble floor's border.
  lozenge,
}

/// What's printed round a playing card's face, inside its edge.
enum FaceFrame {
  /// Just the stock.
  none,

  /// A fine rule.
  rule,

  /// A double rule.
  double,

  /// Ornate brackets in the corners.
  corners,

  /// Art deco: stepped corners.
  deco,

  /// A sprig of leaves in two corners.
  leaves,
}

/// How a number card's suit is shown in its middle.
enum PipStyle {
  /// One large pip.
  large,

  /// The pip on a roundel of its colour.
  medallion,

  /// The rank itself, large, with a small pip under it.
  rank,
}

/// What's printed over a card's back, in its edge colour, faintly.
enum BackMotif {
  /// Nothing: the back's colour, its crown and any rule.
  none,

  /// A fine diagonal lattice.
  lattice,

  /// Fine diagonal stripes, one way.
  stripes,

  /// A grid of small dots.
  dots,

  /// Rays out from the crown.
  rays,

  /// Rows of gentle waves.
  waves,
}

class CardLook {
  const CardLook({
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
    this.motif,
    this.faceFont,
    this.faceFrame = FaceFrame.none,
    this.faceFrameColour,
    this.faceMotif = BackMotif.none,
    this.faceMotifAlpha = 0.08,
    this.pips = PipStyle.large,
    this.courtPatterns,
    this.courtInk,
    this.courtArch = false,
    this.courtRadius,
  });

  /// The Court Cards' corners, kept when the number cards' faces change
  /// theirs ([radius] when null).
  final double? courtRadius;

  /// The Court Cards' full art: a pattern woven into each cloth (in
  /// [courtInk]), one for each of the Joker, Jack, Queen and King, instead
  /// of their own; and an arched frame round the emblem instead of the
  /// straight one.
  final List<FeltPattern>? courtPatterns;
  final Color? courtInk;
  final bool courtArch;

  /// What's printed on a card's face: a frame round it (in
  /// [faceFrameColour], or the ink faintly), a faint motif over the stock,
  /// and how a number card shows its suit.
  final FaceFrame faceFrame;
  final Color? faceFrameColour;
  final BackMotif faceMotif;
  final double faceMotifAlpha;
  final PipStyle pips;

  /// The face the ranks are printed in; the skin's own when null (its
  /// display face for Court Cards, its body face for the rest).
  final String? faceFont;

  /// This look with other faces: how the Court Cards are drawn, the
  /// corners' rounding and the ranks' face.
  CardLook withFace(
          {double? radius,
          String? faceFont,
          FaceFrame frame = FaceFrame.none,
          Color? frameColour,
          BackMotif motif = BackMotif.none,
          double motifAlpha = 0.08,
          PipStyle pips = PipStyle.large}) =>
      CardLook(
        cloth: cloth,
        courtFrame: courtFrame,
        back: back,
        backEdge: backEdge,
        radius: radius ?? this.radius,
        backPattern: backPattern,
        motif: this.motif,
        backPatternAlpha: backPatternAlpha,
        backRule: backRule,
        backCrown: backCrown,
        small: small,
        taskBack: taskBack,
        faceFont: faceFont,
        faceFrame: frame,
        faceFrameColour: frameColour,
        faceMotif: motif,
        faceMotifAlpha: motifAlpha,
        pips: pips,
        courtPatterns: courtPatterns,
        courtInk: courtInk,
        courtArch: courtArch,
        courtRadius: courtRadius ?? this.radius,
      );

  /// This look with other Court Cards: their cloths, what's woven into
  /// them, and an arch round the emblem.
  CardLook withCourt({List<List<Color>>? cloth, List<FeltPattern>? patterns, Color? ink, bool arch = false}) => CardLook(
        cloth: cloth ?? this.cloth,
        courtFrame: courtFrame,
        back: back,
        backEdge: backEdge,
        radius: radius,
        backPattern: backPattern,
        motif: motif,
        backPatternAlpha: backPatternAlpha,
        backRule: backRule,
        backCrown: backCrown,
        small: small,
        taskBack: taskBack,
        faceFont: faceFont,
        faceFrame: faceFrame,
        faceFrameColour: faceFrameColour,
        faceMotif: faceMotif,
        faceMotifAlpha: faceMotifAlpha,
        pips: pips,
        courtPatterns: patterns,
        courtInk: ink,
        courtArch: arch,
        courtRadius: courtRadius,
      );


  /// Each Court Card's colours, Joker, Jack, Queen, King: light then dark.
  final List<List<Color>> cloth;

  /// The fine frame inside a Court Card's edge.
  final Color courtFrame;

  /// A card's back, and the edge round it.
  final Color back;
  final Color backEdge;

  /// Corner radius, as a share of the card's width.
  final double radius;

  /// A fine lattice over the back, in [backEdge] at [backPatternAlpha]
  /// (or another [motif]).
  final bool backPattern;
  final double backPatternAlpha;

  /// What's over the back; the lattice, or nothing, as [backPattern] says,
  /// when null.
  final BackMotif? motif;

  /// The motif over the back, as drawn.
  BackMotif get backMotif => motif ?? (backPattern ? BackMotif.lattice : BackMotif.none);

  /// This look with another back.
  CardLook withBack({
    required Color back,
    required Color backEdge,
    required BackMotif motif,
    double? patternAlpha,
    Color? backRule,
    Color? backCrown,
    List<Color>? taskBack,
  }) =>
      CardLook(
        cloth: cloth,
        courtFrame: courtFrame,
        back: back,
        backEdge: backEdge,
        radius: radius,
        backPattern: motif != BackMotif.none,
        motif: motif,
        backPatternAlpha: patternAlpha ?? backPatternAlpha,
        backRule: backRule,
        backCrown: backCrown,
        small: small,
        taskBack: taskBack,
        faceFont: faceFont,
        faceFrame: faceFrame,
        faceFrameColour: faceFrameColour,
        faceMotif: faceMotif,
        faceMotifAlpha: faceMotifAlpha,
        pips: pips,
        courtPatterns: courtPatterns,
        courtInk: courtInk,
        courtArch: courtArch,
        courtRadius: courtRadius,
      );

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

/// What a seat's token is made as.
enum TokenStyle {
  /// Each courtier's house shape (or a disc): the skin's own.
  houses,

  /// A coin, its edge milled.
  coins,

  /// A cut gem, its facets catching the light.
  gems,

  /// A wax seal, pressed.
  seals,

  /// A casino chip, striped round its edge.
  chips,

  /// A heraldic shield with a bend across it.
  shields,
}

class TokenLook {
  const TokenLook({this.shaped = true, this.ringWidth = 2, this.style = TokenStyle.houses});

  /// What the tokens are made as; [shaped] says how [TokenStyle.houses]
  /// draws them.
  final TokenStyle style;

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
