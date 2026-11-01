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
  back: 'opera',
  face: 'opera',
  token: 'tufted',
  task: 'opera',
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
  ground: Color(0xFF0A1311),
  felt: Color(0xFF24493F),
  feltDeep: Color(0xFF132B25),
  surface: Color(0xFF183630),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFE3D3A8),
  accentDeep: Color(0xFFA6956A),
  onAccent: Color(0xFF1E1A10),
  red: Color(0xFFB8243A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.lozenge,
  back: 'classical',
  face: 'classical',
  token: 'cameos',
  task: 'classical',
  pattern: FeltPattern.marble,
  patternInk: Color(0x66EFF4EE),
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
  back: 'jazz',
  face: 'jazz',
  token: 'sunbursts',
  task: 'jazz',
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

/// Casino: green baize inside a gilt rail, the suits worked faintly into
/// the cloth, chips for the seats, and gold and red. (It was Chequers:
/// saved looks still find it, see skins.dart.)
class CasinoSkin extends DesignSkin {
  const CasinoSkin() : super(casinoDesign);
}

const casinoDesign = SkinDesign(
  id: 'casino',
  name: 'Casino',
  ground: Color(0xFF07140D),
  felt: Color(0xFF0F5A3A),
  feltDeep: Color(0xFF083823),
  surface: Color(0xFF0C2E1F),
  card: Color(0xFFFAF7F0),
  ink: Color(0xFF1F1B16),
  inkSoft: Color(0xFF655D52),
  accent: Color(0xFFD9B044),
  accentDeep: Color(0xFF9C7A20),
  onAccent: Color(0xFF2A1A04),
  red: Color(0xFFC21E2E),
  won: Color(0xFF6FD08A),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.studs,
  back: 'royale',
  face: 'royale',
  token: 'dice',
  task: 'royale',
  pattern: FeltPattern.baize,
  patternInk: Color(0x33E9D9A6),
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
  back: 'atelier',
  face: 'atelier',
  token: 'enamel',
  task: 'atelier',
  pattern: FeltPattern.herringbone,
  patternInk: Color(0x14FFFFFF),
);

/// Riviera: a seaside summer under a cabana's striped awning, in sea-glass
/// blue and coral.
class RivieraSkin extends DesignSkin {
  const RivieraSkin() : super(rivieraDesign);
}

const rivieraDesign = SkinDesign(
  id: 'riviera',
  name: 'Riviera',
  ground: Color(0xFF0B2A33),
  felt: Color(0xFF2B7480),
  feltDeep: Color(0xFF1A525C),
  surface: Color(0xFF15434C),
  card: Color(0xFFFCF8EF),
  ink: Color(0xFF1F2A2E),
  inkSoft: Color(0xFF5E6C70),
  accent: Color(0xFFF4906C),
  accentDeep: Color(0xFFC25F3E),
  onAccent: Color(0xFF3A1408),
  red: Color(0xFFD0384A),
  won: Color(0xFF6FD3A0),
  lost: Color(0xFFF07B5A),
  displayFont: 'AlegreyaSans',
  bodyFont: 'AlegreyaSans',
  corners: PanelCorners.brackets,
  back: 'rose',
  face: 'seaside',
  token: 'gems',
  task: 'mint',
  pattern: FeltPattern.awning,
  patternInk: Color(0x2EFFF6E8),
);

/// Winter palace: ice and silver, snowflakes on a frosted cloth, and ferns
/// of frost grown in at the corners.
class WinterSkin extends DesignSkin {
  const WinterSkin() : super(winterDesign);
}

const winterDesign = SkinDesign(
  id: 'winter',
  name: 'Winter palace',
  ground: Color(0xFF0A121D),
  felt: Color(0xFF34536F),
  feltDeep: Color(0xFF1F354B),
  surface: Color(0xFF1B2D42),
  card: Color(0xFFFAFCFF),
  ink: Color(0xFF17202B),
  inkSoft: Color(0xFF5A6675),
  accent: Color(0xFFDDE9F5),
  accentDeep: Color(0xFF93A9C2),
  onAccent: Color(0xFF14202E),
  red: Color(0xFFB8243A),
  won: Color(0xFF7FD6B0),
  lost: Color(0xFFE77A66),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.stars,
  back: 'snow',
  face: 'snow',
  token: 'ice',
  task: 'snow',
  pattern: FeltPattern.frost,
  patternInk: Color(0x38E8F4FF),
);

/// Egyptian: lapis and gold, rows of lotus and papyrus between zigzag
/// bands, as painted on a tomb's wall.
class EgyptianSkin extends DesignSkin {
  const EgyptianSkin() : super(egyptianDesign);
}

const egyptianDesign = SkinDesign(
  id: 'egyptian',
  name: 'Egyptian',
  ground: Color(0xFF0A0E22),
  felt: Color(0xFF1F3A78),
  feltDeep: Color(0xFF12224B),
  surface: Color(0xFF172B5A),
  card: Color(0xFFF7EFDC),
  ink: Color(0xFF241A10),
  inkSoft: Color(0xFF6B5A44),
  accent: Color(0xFFE2B53E),
  accentDeep: Color(0xFFA47C1E),
  onAccent: Color(0xFF2A1C04),
  red: Color(0xFFB5352A),
  won: Color(0xFF5FBF7A),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.tooled,
  back: 'pharaoh',
  face: 'pharaoh',
  token: 'scarabs',
  task: 'pharaoh',
  pattern: FeltPattern.lotus,
  patternInk: Color(0x28E2B53E),
);

/// Galleon: a captain's treasure map on the table, brass fittings, and
/// doubloons for the seats.
class GalleonSkin extends DesignSkin {
  const GalleonSkin() : super(galleonDesign);
}

const galleonDesign = SkinDesign(
  id: 'galleon',
  name: 'Galleon',
  ground: Color(0xFF150E08),
  felt: Color(0xFF5A4530),
  feltDeep: Color(0xFF3A2C1D),
  surface: Color(0xFF30241A),
  card: Color(0xFFF6EEDB),
  ink: Color(0xFF2A1C10),
  inkSoft: Color(0xFF6E5A44),
  accent: Color(0xFFCDA65C),
  accentDeep: Color(0xFF8E6E30),
  onAccent: Color(0xFF24180A),
  red: Color(0xFFA8302A),
  won: Color(0xFF6CC28A),
  lost: Color(0xFFE0614B),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  corners: PanelCorners.studs,
  back: 'pirate',
  face: 'pirate',
  token: 'doubloons',
  task: 'pirate',
  pattern: FeltPattern.map,
  patternInk: Color(0x4CF0DEB4),
);

/// Scopa: a trattoria's red-and-white gingham, cream and gold, olive
/// sprigs in the corners, and coins for the seats.
class ScopaSkin extends DesignSkin {
  const ScopaSkin() : super(scopaDesign);
}

const scopaDesign = SkinDesign(
  id: 'scopa',
  name: 'Scopa',
  ground: Color(0xFF1C0907),
  felt: Color(0xFF8E2A22),
  feltDeep: Color(0xFF611A15),
  surface: Color(0xFF461511),
  card: Color(0xFFFCF8EE),
  ink: Color(0xFF231A12),
  inkSoft: Color(0xFF6A5C4C),
  accent: Color(0xFFF0D48A),
  accentDeep: Color(0xFFB8973E),
  onAccent: Color(0xFF2A1C04),
  red: Color(0xFFC0242E),
  won: Color(0xFF8BCF6A),
  lost: Color(0xFFF2A36B),
  displayFont: 'AlegreyaSans',
  bodyFont: 'AlegreyaSans',
  corners: PanelCorners.leaves,
  back: 'napoli',
  face: 'napoli',
  token: 'caps',
  task: 'napoli',
  pattern: FeltPattern.gingham,
  patternInk: Color(0x24FFF4E2),
);
