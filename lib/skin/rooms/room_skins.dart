/// Rooms of the palace to play in, each a skin made from a design alone
/// (design_skin.dart): its table, with something worked into the felt
/// (looks.dart: [FeltPattern]), and the menus and pages dressed to match.
library;

import 'package:flutter/painting.dart';

import '../design_skin.dart';
import '../looks.dart';

/// Velvet: plum velvet woven with damask flowers, set in black, with old gold.
class VelvetSkin extends DesignSkin {
  const VelvetSkin() : super(velvetDesign);
}

const velvetDesign = SkinDesign(
  id: 'velvet',
  name: 'Velvet',
  ground: Color(0xFF140A18),
  felt: Color(0xFF3E2347),
  feltDeep: Color(0xFF28152F),
  surface: Color(0xFF2E1936),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFE5C07B),
  accentDeep: Color(0xFFA8823F),
  onAccent: Color(0xFF2A1A06),
  red: Color(0xFFB8243A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.damask,
  back: 'plum',
  face: 'brocade',
  token: 'gems',
  task: 'stationery',
  pattern: FeltPattern.damask,
  patternInk: Color(0x1AFFE6F5),
);

/// Counting house: a banker's burgundy, pinstriped, in a dark mahogany table, with brass.
class CountingSkin extends DesignSkin {
  const CountingSkin() : super(countingDesign);
}

const countingDesign = SkinDesign(
  id: 'counting',
  name: 'Counting house',
  ground: Color(0xFF1A0A0C),
  felt: Color(0xFF5A1A24),
  feltDeep: Color(0xFF3A0E16),
  surface: Color(0xFF431219),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFD4A63A),
  accentDeep: Color(0xFF9C7420),
  onAccent: Color(0xFF2A1A04),
  red: Color(0xFFB8243A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.brackets,
  back: 'crimson',
  face: 'classic',
  token: 'coins',
  task: 'ledger',
  pattern: FeltPattern.pinstripe,
  patternInk: Color(0x1CFFFFFF),
);

/// Library: tooled leather on a writing table: a gilt border, scrolls in its corners.
class LibrarySkin extends DesignSkin {
  const LibrarySkin() : super(libraryDesign);
}

const libraryDesign = SkinDesign(
  id: 'library',
  name: 'Library',
  ground: Color(0xFF1E140D),
  felt: Color(0xFF5A3E2A),
  feltDeep: Color(0xFF3C291B),
  surface: Color(0xFF45301F),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFD4A63A),
  accentDeep: Color(0xFF9C7420),
  onAccent: Color(0xFF2A1A04),
  red: Color(0xFFB8243A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.tooled,
  back: 'emerald',
  face: 'antique',
  token: 'seals',
  task: 'parchment',
  pattern: FeltPattern.tooled,
  patternInk: Color(0x80D4A63A),
);

/// Tavern: bare boards in a tavern, grain and knots and all, by lamplight.
class TavernSkin extends DesignSkin {
  const TavernSkin() : super(tavernDesign);
}

const tavernDesign = SkinDesign(
  id: 'tavern',
  name: 'Tavern',
  ground: Color(0xFF1A110A),
  felt: Color(0xFF4A3220),
  feltDeep: Color(0xFF2E1F14),
  surface: Color(0xFF3A2718),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFE0A84E),
  accentDeep: Color(0xFFA8742A),
  onAccent: Color(0xFF2A1604),
  red: Color(0xFFB8243A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'AlegreyaSans',
  bodyFont: 'AlegreyaSans',
  corners: PanelCorners.studs,
  back: 'herald',
  face: 'antique',
  token: 'coins',
  task: 'parchment',
  pattern: FeltPattern.planks,
  patternInk: Color(0x40000000),
);

/// Marble hall: green marble with its pale veins, and gilt gone soft with age.
class MarbleSkin extends DesignSkin {
  const MarbleSkin() : super(marbleDesign);
}

const marbleDesign = SkinDesign(
  id: 'marble',
  name: 'Marble hall',
  ground: Color(0xFF0D1714),
  felt: Color(0xFF1F3B33),
  feltDeep: Color(0xFF132621),
  surface: Color(0xFF1A3029),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFD9C9A0),
  accentDeep: Color(0xFF9E8E66),
  onAccent: Color(0xFF1E1A10),
  red: Color(0xFFB8243A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.lozenge,
  back: 'ivory',
  face: 'arbour',
  token: 'gems',
  task: 'gilt',
  pattern: FeltPattern.marble,
  patternInk: Color(0x4DE8F2EC),
);

/// Ballroom: black lacquer and gold fans, as in a ballroom of the twenties.
class BallroomSkin extends DesignSkin {
  const BallroomSkin() : super(ballroomDesign);
}

const ballroomDesign = SkinDesign(
  id: 'ballroom',
  name: 'Ballroom',
  ground: Color(0xFF000000),
  felt: Color(0xFF181818),
  feltDeep: Color(0xFF0C0C0C),
  surface: Color(0xFF141414),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFD4A63A),
  accentDeep: Color(0xFF9C7420),
  onAccent: Color(0xFF2A1A04),
  red: Color(0xFFB8243A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.fans,
  back: 'sunburst',
  face: 'gatsby',
  token: 'chips',
  task: 'lacquer',
  pattern: FeltPattern.deco,
  patternInk: Color(0x47D4A63A),
);

/// Courtyard: blue tiles in a palace courtyard, each with its star, and warm sand.
class CourtyardSkin extends DesignSkin {
  const CourtyardSkin() : super(courtyardDesign);
}

const courtyardDesign = SkinDesign(
  id: 'courtyard',
  name: 'Courtyard',
  ground: Color(0xFF0A1626),
  felt: Color(0xFF173A5E),
  feltDeep: Color(0xFF0E2640),
  surface: Color(0xFF132E4C),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFF2C46D),
  accentDeep: Color(0xFFB88A30),
  onAccent: Color(0xFF2A1C04),
  red: Color(0xFFB8243A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'AlegreyaSans',
  bodyFont: 'AlegreyaSans',
  corners: PanelCorners.compass,
  back: 'royal',
  face: 'modern',
  token: 'shields',
  task: 'blueprint',
  pattern: FeltPattern.tiles,
  patternInk: Color(0x24F5E6C8),
);

/// Campaign: the general’s map table: contour lines round the hills, in parchment.
class CampaignSkin extends DesignSkin {
  const CampaignSkin() : super(campaignDesign);
}

const campaignDesign = SkinDesign(
  id: 'campaign',
  name: 'Campaign',
  ground: Color(0xFF1A2012),
  felt: Color(0xFF3A4A2C),
  feltDeep: Color(0xFF253019),
  surface: Color(0xFF2E3B22),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFE8D49A),
  accentDeep: Color(0xFFA8955A),
  onAccent: Color(0xFF222010),
  red: Color(0xFFB8243A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.compass,
  back: 'emerald',
  face: 'tarot',
  token: 'shields',
  task: 'ledger',
  pattern: FeltPattern.contours,
  patternInk: Color(0x33E8DDB0),
);

/// Chequers: a chequered floor in deep claret, and gold for the King.
class ChequersSkin extends DesignSkin {
  const ChequersSkin() : super(chequersDesign);
}

const chequersDesign = SkinDesign(
  id: 'chequers',
  name: 'Chequers',
  ground: Color(0xFF120707),
  felt: Color(0xFF3A1A1E),
  feltDeep: Color(0xFF24100F),
  surface: Color(0xFF2E1517),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFD4A63A),
  accentDeep: Color(0xFF9C7420),
  onAccent: Color(0xFF2A1A04),
  red: Color(0xFFB8243A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.chequer,
  back: 'crimson',
  face: 'casino',
  token: 'chips',
  task: 'decree',
  pattern: FeltPattern.chequer,
  patternInk: Color(0x24000000),
);

/// Salon: herringbone parquet in charcoal, and pale linen for the accent.
class SalonSkin extends DesignSkin {
  const SalonSkin() : super(salonDesign);
}

const salonDesign = SkinDesign(
  id: 'salon',
  name: 'Salon',
  ground: Color(0xFF0A0A0A),
  felt: Color(0xFF262626),
  feltDeep: Color(0xFF171717),
  surface: Color(0xFF1E1E1E),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFECE4D4),
  accentDeep: Color(0xFFA8A090),
  onAccent: Color(0xFF1A1A1A),
  red: Color(0xFFB8243A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'AlegreyaSans',
  bodyFont: 'AlegreyaSans',
  corners: PanelCorners.brackets,
  back: 'graphite',
  face: 'modern',
  task: 'rose',
  pattern: FeltPattern.herringbone,
  patternInk: Color(0x14FFFFFF),
);
