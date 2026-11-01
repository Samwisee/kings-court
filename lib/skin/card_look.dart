/// How a skin's cards are drawn: their backs, the number cards' faces and
/// the Court Cards (looks.dart exports it).
library;

import 'package:flutter/painting.dart';

import 'looks.dart';

/// A set of Court Card emblems of a room's own, in place of the court's
/// jester, sword, tiara and crown (ui/cards/emblems/).
enum EmblemSet {
  /// Midnight: a comet, a crescent moon, a moon and star, a crown of stars.
  starlight,

  /// Velvet: an opera mask, a rose, a fan, a velvet crown.
  opera,

  /// Marble hall: a lyre, a column, a laurel wreath, a mural crown.
  classical,

  /// Ballroom: a champagne coupe, a top hat, a feathered fan, a stepped crown.
  jazz,

  /// Casino: dice, a chip, a roulette wheel, a crown set with the suits.
  royale,

  /// Salon: a palette, a pen's nib, a perfume bottle, a drawn crown.
  atelier,

  /// Winter palace: a snowman, a skate, a snowflake, a crown of icicles.
  snow,

  /// Egyptian: the eye, the ankh, a lotus, the double crown.
  pharaoh,

  /// Galleon: a parrot, an anchor, a compass rose, a ship's-wheel crown.
  pirate,

  /// Scopa: the cup, the club, the coin, the crown of the Neapolitan deck.
  napoli,
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

  /// A night sky: small stars, scattered.
  stars,

  /// Damask: a small woven flower in rows, turned each row.
  damask,

  /// Marble: a few veins across, branching.
  veins,

  /// Art deco fans, row over row.
  fans,

  /// A casino back's fine diamond grid.
  diamonds,

  /// Herringbone, in fine lines.
  herringbone,

  /// Snowflakes, scattered.
  snow,

  /// Egyptian zigzag bands.
  zigzag,

  /// A sea chart's rhumb lines from a compass circle.
  chart,

  /// A plaid: crossing bands of two widths.
  plaid,

  /// Papyrus: the fibres crossing, with a reed here and there.
  papyrus,
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
    this.courtEmblems,
  });

  /// The Court Cards' own emblems, drawn in place of the court's jester,
  /// sword, tiara and crown; the court's when null.
  final EmblemSet? courtEmblems;

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
        courtEmblems: courtEmblems,
      );

  /// This look with other Court Cards: their cloths, what's woven into
  /// them, and an arch round the emblem.
  CardLook withCourt(
          {List<List<Color>>? cloth, List<FeltPattern>? patterns, Color? ink, bool arch = false, EmblemSet? emblems}) =>
      CardLook(
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
        courtEmblems: emblems,
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
        courtEmblems: courtEmblems,
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
