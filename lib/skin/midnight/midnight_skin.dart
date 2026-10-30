/// Midnight: cards by candlelight in the King's own rooms. Deep navy felt
/// set in black, silver for the accent, and the court's own dress.
/// Made from a design alone (design_skin.dart).
library;

import 'package:flutter/painting.dart';

import '../design_skin.dart';
import '../looks.dart';

class MidnightSkin extends DesignSkin {
  const MidnightSkin() : super(midnightDesign);
}

const midnightDesign = SkinDesign(
  id: 'midnight',
  name: 'Midnight',
  ground: Color(0xFF07090F),
  felt: Color(0xFF17233F),
  feltDeep: Color(0xFF0E172C),
  surface: Color(0xFF121C33),
  card: Color(0xFFF6F7FA),
  ink: Color(0xFF171A22),
  inkSoft: Color(0xFF5E6574),
  accent: Color(0xFFC9D2E3),
  accentDeep: Color(0xFF8792AA),
  onAccent: Color(0xFF141A28),
  red: Color(0xFFC0283C),
  won: Color(0xFF5FBF8A),
  lost: Color(0xFFE5604C),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  corners: PanelCorners.stars,
  back: 'midnight',
  face: 'silver',
  task: 'letter',
  pattern: FeltPattern.stars,
  patternInk: Color(0x8CE8EEFF),
  finish: Finish.rich,
  cloth: [
    [Color(0xFF4E3A86), Color(0xFF1F1640)],
    [Color(0xFF1C6B5A), Color(0xFF0A2E27)],
    [Color(0xFF2E4F9E), Color(0xFF101F47)],
    [Color(0xFF8E2236), Color(0xFF360812)],
  ],
);
