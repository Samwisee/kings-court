/// Harbour: a card game on deck at dusk. Deep sea-teal felt to the edge,
/// warm lantern amber for the accent, flat panels and clean Court Cards.
/// Made from a design alone (design_skin.dart).
library;

import 'package:flutter/painting.dart';

import '../design_skin.dart';
import '../looks.dart';

class HarbourSkin extends DesignSkin {
  const HarbourSkin() : super(harbourDesign);
}

const harbourDesign = SkinDesign(
  id: 'harbour',
  name: 'Harbour',
  ground: Color(0xFF0B1A22),
  felt: Color(0xFF14404F),
  feltDeep: Color(0xFF0C2B36),
  surface: Color(0xFF12313D),
  card: Color(0xFFFAF8F2),
  ink: Color(0xFF1A1E24),
  inkSoft: Color(0xFF5D6670),
  accent: Color(0xFFF2B950),
  accentDeep: Color(0xFFB97F1E),
  onAccent: Color(0xFF2A1A04),
  red: Color(0xFFC62839),
  won: Color(0xFF3FA66A),
  lost: Color(0xFFE0533F),
  displayFont: 'AlegreyaSans',
  bodyFont: 'AlegreyaSans',
  corners: PanelCorners.compass,
  back: 'harbour',
  face: 'seaside',
  token: 'coins',
  task: 'stamp',
  pattern: FeltPattern.chart,
  patternInk: Color(0x2EF2D49A),
  cloth: [
    [Color(0xFF6B4BA8), Color(0xFF3B2468)],
    [Color(0xFF1E8A6A), Color(0xFF0E5240)],
    [Color(0xFF2F5FB8), Color(0xFF173777)],
    [Color(0xFFC23A3A), Color(0xFF7A1A1F)],
  ],
);
