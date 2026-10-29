/// Plain: the game without the court's dress. A slate card room, white
/// cards with their letters on the Court Cards, round seats, flat panels
/// with a band of colour for an occasion, and one cornflower accent where
/// the court has gold. Made from a design alone (design_skin.dart).
library;

import 'package:flutter/painting.dart';

import '../design_skin.dart';

class PlainSkin extends DesignSkin {
  const PlainSkin() : super(plainDesign);
}

const plainDesign = SkinDesign(
  id: 'plain',
  name: 'Plain',
  ground: Color(0xFF151B24),
  felt: Color(0xFF253041),
  feltDeep: Color(0xFF1A2230),
  surface: Color(0xFF1E2735),
  card: Color(0xFFFCFBF8),
  ink: Color(0xFF1B1F27),
  inkSoft: Color(0xFF5E6673),
  accent: Color(0xFF8DB4FF),
  accentDeep: Color(0xFF4F7FD9),
  onAccent: Color(0xFF0F1A33),
  red: Color(0xFFC62839),
  won: Color(0xFF3FA66A),
  lost: Color(0xFFE0533F),
  displayFont: 'AlegreyaSans',
  bodyFont: 'AlegreyaSans',
  radius: 10,
  // The Court Cards' colours, a touch brighter on white card stock.
  cloth: [
    [Color(0xFF7448B8), Color(0xFF4A2670)],
    [Color(0xFF1F8A5B), Color(0xFF0F5B3A)],
    [Color(0xFF3563D1), Color(0xFF203C8C)],
    [Color(0xFFC0313F), Color(0xFF7E1828)],
  ],
);
