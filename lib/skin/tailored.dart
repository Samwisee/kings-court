/// A look of the player's own: any skin, on a table of their choosing,
/// with the card backs they like. The skin gives everything else; the
/// table changes the felt (its shades and the light on it) and the table
/// round it, and the backs change every card back and task back.
///
/// Saved as the skin's id with the choices after it
/// (`court+t:navy+b:rays`), so [skinById] (skins.dart) wears it again.
library;

import 'package:flutter/material.dart';

import 'looks.dart';
import 'parts.dart';
import 'skin.dart';

/// A table to play on: the felt, its shadow, the light over it, and the
/// table it's set into (the colour round the edge, and the browser's bars).
class TableChoice {
  const TableChoice(this.id, this.name,
      {required this.felt, required this.feltDeep, required this.glow, required this.table});
  final String id;
  final String name;
  final Color felt;
  final Color feltDeep;
  final Color glow;
  final Color table;
}

/// A card back: its colour, its edge (and the motif in it), what's over
/// it, how strongly, a rule inside the edge, and the crown's colour (the
/// skin's gilt when null).
class BackChoice {
  const BackChoice(this.id, this.name,
      {required this.back,
      required this.edge,
      required this.motif,
      this.alpha = 0.18,
      this.rule = true,
      this.crown});
  final String id;
  final String name;
  final Color back;
  final Color edge;
  final BackMotif motif;
  final double alpha;
  final bool rule;
  final Color? crown;
}

const tableChoices = <TableChoice>[
  TableChoice('green', 'Card room',
      felt: Color(0xFF0F4A2E), feltDeep: Color(0xFF0A3622), glow: Color(0xFF176141), table: Color(0xFF4E0B18)),
  TableChoice('billiard', 'Billiard hall',
      felt: Color(0xFF1F6B3A), feltDeep: Color(0xFF134628), glow: Color(0xFF2C8A4F), table: Color(0xFF3B2416)),
  TableChoice('sage', 'Walled garden',
      felt: Color(0xFF3F5E45), feltDeep: Color(0xFF29402E), glow: Color(0xFF52755A), table: Color(0xFF1B2418)),
  TableChoice('teal', 'Harbour',
      felt: Color(0xFF14404F), feltDeep: Color(0xFF0C2B36), glow: Color(0xFF1D5768), table: Color(0xFF0B1A22)),
  TableChoice('navy', 'Night sky',
      felt: Color(0xFF17233F), feltDeep: Color(0xFF0E172C), glow: Color(0xFF24345A), table: Color(0xFF07090F)),
  TableChoice('plum', 'Plum velvet',
      felt: Color(0xFF3E2347), feltDeep: Color(0xFF28152F), glow: Color(0xFF563463), table: Color(0xFF140A18)),
  TableChoice('burgundy', 'Burgundy',
      felt: Color(0xFF5A1A24), feltDeep: Color(0xFF3A0E16), glow: Color(0xFF75293A), table: Color(0xFF1A0A0C)),
  TableChoice('walnut', 'Leather',
      felt: Color(0xFF5A3E2A), feltDeep: Color(0xFF3C291B), glow: Color(0xFF735239), table: Color(0xFF1E140D)),
  TableChoice('slate', 'Slate',
      felt: Color(0xFF2F3A45), feltDeep: Color(0xFF1E262E), glow: Color(0xFF425062), table: Color(0xFF121519)),
  TableChoice('charcoal', 'Charcoal',
      felt: Color(0xFF262626), feltDeep: Color(0xFF171717), glow: Color(0xFF363636), table: Color(0xFF0A0A0A)),
];

const backChoices = <BackChoice>[
  BackChoice('crimson', 'Crimson lattice',
      back: Color(0xFF5A1620), edge: Color(0xFFD4A63A), motif: BackMotif.lattice, alpha: 0.14),
  BackChoice('royal', 'Royal blue',
      back: Color(0xFF1C3270), edge: Color(0xFFD4A63A), motif: BackMotif.lattice),
  BackChoice('emerald', 'Emerald stripes',
      back: Color(0xFF0F4A2E), edge: Color(0xFFD4A63A), motif: BackMotif.stripes, alpha: 0.16),
  BackChoice('sunburst', 'Black sunburst',
      back: Color(0xFF141414), edge: Color(0xFFD4A63A), motif: BackMotif.rays, alpha: 0.22),
  BackChoice('herald', 'Herald’s rays',
      back: Color(0xFF8E1B2C), edge: Color(0xFFF2D27A), motif: BackMotif.rays),
  BackChoice('ivory', 'Ivory dots',
      back: Color(0xFFEFE6D2),
      edge: Color(0xFF8A6A2A),
      motif: BackMotif.dots,
      alpha: 0.4,
      crown: Color(0xFF8A6A2A)),
  BackChoice('harbour', 'Harbour lights',
      back: Color(0xFF14404F), edge: Color(0xFFF2B950), motif: BackMotif.dots, alpha: 0.3, crown: Color(0xFFF2B950)),
  BackChoice('plum', 'Plum waves',
      back: Color(0xFF3E2347), edge: Color(0xFFE5C07B), motif: BackMotif.waves, alpha: 0.22),
  BackChoice('rose', 'Rose tide',
      back: Color(0xFFB0705A),
      edge: Color(0xFFFBE3D6),
      motif: BackMotif.waves,
      alpha: 0.3,
      rule: false,
      crown: Color(0xFFFBE3D6)),
  BackChoice('midnight', 'Midnight lattice',
      back: Color(0xFF0E172C), edge: Color(0xFFC9D2E3), motif: BackMotif.lattice, alpha: 0.2, crown: Color(0xFFC9D2E3)),
  BackChoice('silver', 'Plain navy',
      back: Color(0xFF17233F), edge: Color(0xFFC9D2E3), motif: BackMotif.none, crown: Color(0xFFC9D2E3)),
  BackChoice('graphite', 'Graphite stripes',
      back: Color(0xFF2A2A2A),
      edge: Color(0xFFB0B0B0),
      motif: BackMotif.stripes,
      alpha: 0.2,
      rule: false,
      crown: Color(0xFFB0B0B0)),
];

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// [base] on the [tableChoice] table with [backChoice] backs (the skin's
/// own for either when null).
class TailoredSkin extends Skin {
  const TailoredSkin(this.base, {this.tableChoice, this.backChoice});

  final Skin base;
  final TableChoice? tableChoice;
  final BackChoice? backChoice;

  /// [skin] without its choices: the skin they're made on.
  static Skin baseOf(Skin skin) => skin is TailoredSkin ? skin.base : skin;

  @override
  String get id => [
        base.id,
        if (tableChoice != null) 't:${tableChoice!.id}',
        if (backChoice != null) 'b:${backChoice!.id}',
      ].join('+');
  @override
  String get name => base.name;

  @override
  bool operator ==(Object other) => other is TailoredSkin && other.id == id;
  @override
  int get hashCode => id.hashCode;

  // The table.
  @override
  Color get felt => tableChoice?.felt ?? base.felt;
  @override
  Color get feltDeep => tableChoice?.feltDeep ?? base.feltDeep;
  @override
  Color get feltGlow => tableChoice?.glow ?? base.feltGlow;
  @override
  Color get table => tableChoice?.table ?? base.table;
  @override
  Color get feltLine => tableChoice == null ? base.feltLine : _mix(tableChoice!.felt, Colors.white, 0.12);

  // The backs.
  @override
  CardLook get cardLook {
    final b = backChoice;
    if (b == null) return base.cardLook;
    return base.cardLook.withBack(
      back: b.back,
      backEdge: b.edge,
      motif: b.motif,
      patternAlpha: b.alpha,
      backRule: b.rule ? b.edge.withValues(alpha: 0.6) : null,
      backCrown: b.crown,
      taskBack: [_mix(b.back, Colors.white, 0.1), _mix(b.back, Colors.black, 0.45)],
    );
  }

  /// The skin's own parts, but for its card back when other backs are
  /// chosen.
  @override
  SkinParts get parts {
    final p = base.parts;
    if (backChoice == null) return p;
    return SkinParts(cardFace: p.cardFace, panel: p.panel, table: p.table);
  }

  @override
  ThemeData theme() {
    final t = base.theme();
    if (tableChoice == null) return t;
    return t.copyWith(
        scaffoldBackgroundColor: felt, appBarTheme: t.appBarTheme.copyWith(backgroundColor: felt));
  }

  // Everything else is the skin's.
  @override
  Color get card => base.card;
  @override
  Color get ink => base.ink;
  @override
  Color get inkSoft => base.inkSoft;
  @override
  Color get cardRed => base.cardRed;
  @override
  Color get diamondBlue => base.diamondBlue;
  @override
  Color get clubGreen => base.clubGreen;
  @override
  Color get gold => base.gold;
  @override
  Color get goldDeep => base.goldDeep;
  @override
  Color get goldLight => base.goldLight;
  @override
  Color get goldPale => base.goldPale;
  @override
  Color get goldRim => base.goldRim;
  @override
  Color get goldInk => base.goldInk;
  @override
  Color get parchment => base.parchment;
  @override
  Color get ivory => base.ivory;
  @override
  Color get goldOnFelt => base.goldOnFelt;
  @override
  Color get failedCard => base.failedCard;
  @override
  Color get redOnDark => base.redOnDark;
  @override
  Color get traitor => base.traitor;
  @override
  Color get traitorDeep => base.traitorDeep;
  @override
  Color get traitorPanel => base.traitorPanel;
  @override
  Color get won => base.won;
  @override
  Color get lost => base.lost;
  @override
  List<Color> get players => base.players;
  @override
  Color get diamondOnDark => base.diamondOnDark;
  @override
  Color get clubOnDark => base.clubOnDark;
  @override
  String get displayFont => base.displayFont;
  @override
  String get bodyFont => base.bodyFont;
  @override
  List<Shadow> get feltShadow => base.feltShadow;
  @override
  TextStyle get taskText => base.taskText;
  @override
  Color get outlineColour => base.outlineColour;
  @override
  double get outlineWidth => base.outlineWidth;
  @override
  Color get dialogBackground => base.dialogBackground;
  @override
  double get dialogRadius => base.dialogRadius;
  @override
  Color get dialogEdge => base.dialogEdge;
  @override
  ShapeBorder get dialogShape => base.dialogShape;
  @override
  Color get barrier => base.barrier;
  @override
  TextStyle get dialogTitle => base.dialogTitle;
  @override
  TextStyle get dialogBody => base.dialogBody;
  @override
  TextStyle get dialogNote => base.dialogNote;
  @override
  Color get paper => base.paper;
  @override
  TextStyle get paperTitle => base.paperTitle;
  @override
  TableLook get tableLook => base.tableLook;
  @override
  PanelLook get panelLook => base.panelLook;
  @override
  TokenLook get tokenLook => base.tokenLook;
  @override
  ButtonLook get buttonLook => base.buttonLook;
  @override
  Color get sheen => base.sheen;
}
