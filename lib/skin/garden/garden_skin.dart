/// Garden: the court at play in its walled garden. Sage felt set in a
/// dark yew table, rose gold for the accent, and the court's own dress:
/// ornate panels, the Court Cards on their cloths, the houses' shapes.
/// Made from a design alone (design_skin.dart).
library;

import 'package:flutter/painting.dart';

import '../design_skin.dart';
import '../looks.dart';

class GardenSkin extends DesignSkin {
  const GardenSkin() : super(gardenDesign);
}

const gardenDesign = SkinDesign(
  id: 'garden',
  name: 'Garden',
  ground: Color(0xFF1B2418),
  felt: Color(0xFF3F5E45),
  feltDeep: Color(0xFF29402E),
  surface: Color(0xFF2C3F2F),
  card: Color(0xFFFBF7EE),
  ink: Color(0xFF22201B),
  inkSoft: Color(0xFF6A645A),
  accent: Color(0xFFE5A88E),
  accentDeep: Color(0xFFB0705A),
  onAccent: Color(0xFF3A1A10),
  red: Color(0xFFB5243A),
  won: Color(0xFF6FBF73),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  corners: PanelCorners.leaves,
  back: 'rose',
  face: 'blush',
  task: 'mint',
  pattern: FeltPattern.trellis,
  patternInk: Color(0x24E5F0D8),
  finish: Finish.rich,
  cloth: [
    [Color(0xFF6A4C8C), Color(0xFF2E1F42)],
    [Color(0xFF2F6B4A), Color(0xFF12301F)],
    [Color(0xFF3C5D9A), Color(0xFF16264A)],
    [Color(0xFFA33B4A), Color(0xFF45121C)],
  ],
);
