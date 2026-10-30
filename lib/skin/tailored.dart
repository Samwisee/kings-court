/// A look of the player's own: any skin (its table and everything else),
/// with the card backs and task cards they like. The backs change every
/// card back and task back, and the task cards change the tasks' faces.
///
/// Saved as the skin's id with the choices after it
/// (`midnight+b:rays+k:decree`), so [skinById] (skins.dart) wears it
/// again.
library;

import 'package:flutter/material.dart';

import '../engine/cards.dart';
import '../platform/settings.dart';
import 'looks.dart';
import 'parts.dart';
import 'skin.dart';

/// A task card's face (looks.dart: [TaskLook]), by name.
class TaskChoice {
  const TaskChoice(this.id, this.name, this.look);
  final String id;
  final String name;
  final TaskLook look;
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

const taskChoices = <TaskChoice>[
  TaskChoice(
      'stationery',
      'Court stationery',
      TaskLook(
          face: Color(0xFFF6F0E1),
          ink: Color(0xFF2A1D10),
          inkSoft: Color(0xFF6B5A44),
          frame: TaskFrame.ruled,
          frameColour: Color(0xA6A57C1B))),
  TaskChoice(
      'parchment',
      'Old parchment',
      TaskLook(
          face: Color(0xFFEBD9B4),
          ink: Color(0xFF3B2614),
          inkSoft: Color(0xFF6E5233),
          frame: TaskFrame.corners,
          frameColour: Color(0xCC8A5A2B),
          motif: BackMotif.dots,
          motifAlpha: 0.07)),
  TaskChoice(
      'decree',
      'Royal decree',
      TaskLook(
          face: Color(0xFFFBF6EA),
          ink: Color(0xFF1E1A14),
          inkSoft: Color(0xFF5E564A),
          crown: Color(0xFF8E1B2C),
          frame: TaskFrame.ribbon,
          frameColour: Color(0xFF8E1B2C))),
  TaskChoice(
      'gilt',
      'Gilt edge',
      TaskLook(
          face: Color(0xFFFFF8E7),
          ink: Color(0xFF2B2113),
          inkSoft: Color(0xFF6A5A3F),
          frame: TaskFrame.ruled,
          frameColour: Color(0xFFC99A2E))),
  TaskChoice(
      'stamp',
      'Postage stamp',
      TaskLook(
          face: Color(0xFFFFFDF7),
          ink: Color(0xFF202A36),
          inkSoft: Color(0xFF5C6B7A),
          crown: Color(0xFF3D6B8F),
          frame: TaskFrame.stamp,
          frameColour: Color(0xFF3D6B8F))),
  TaskChoice(
      'ledger',
      'Ledger',
      TaskLook(
          face: Color(0xFFF4F7EE),
          ink: Color(0xFF1F2A1F),
          inkSoft: Color(0xFF55624F),
          frame: TaskFrame.ledger,
          frameColour: Color(0xFFC0392B))),
  TaskChoice(
      'rose',
      'Rose petal',
      TaskLook(
          face: Color(0xFFF9E4DE),
          ink: Color(0xFF3A1E22),
          inkSoft: Color(0xFF7A5258),
          crown: Color(0xFFB0485A),
          motif: BackMotif.dots,
          motifAlpha: 0.1)),
  TaskChoice(
      'mint',
      'Mint julep',
      TaskLook(
          face: Color(0xFFE3F2E6),
          ink: Color(0xFF173322),
          inkSoft: Color(0xFF4C6B57),
          crown: Color(0xFF2E7D4F),
          frame: TaskFrame.corners,
          frameColour: Color(0xB32E7D4F))),
  TaskChoice(
      'letter',
      'Night letter',
      TaskLook(
          face: Color(0xFF1B2440),
          ink: Color(0xFFF1ECDF),
          inkSoft: Color(0xFFB9C0D4),
          crown: Color(0xFFE5C07B),
          frame: TaskFrame.ruled,
          frameColour: Color(0x80C9D2E3))),
  TaskChoice(
      'lacquer',
      'Black lacquer',
      TaskLook(
          face: Color(0xFF161010),
          ink: Color(0xFFF2E6C9),
          inkSoft: Color(0xFFC8B48A),
          crown: Color(0xFFDDB65E),
          frame: TaskFrame.corners,
          frameColour: Color(0xCCDDB65E))),
  TaskChoice(
      'blueprint',
      'Blueprint',
      TaskLook(
          face: Color(0xFF1E4E8C),
          ink: Color(0xFFF2F7FF),
          inkSoft: Color(0xFFBFD3EE),
          crown: Color(0xFFF2F7FF),
          frame: TaskFrame.ruled,
          frameColour: Color(0x8CFFFFFF),
          motif: BackMotif.lattice,
          motifAlpha: 0.1)),
];

/// The faces of the playing cards: the stock, the suits' inks (four-colour
/// ♦ and ♣ too), how the Court Cards are drawn, the corners, the ranks'
/// face, what's printed round the face and over it, and how a number card
/// shows its suit. Dark stock takes light inks.
class FaceChoice {
  const FaceChoice(this.id, this.name,
      {required this.card,
      required this.black,
      required this.red,
      required this.blue,
      required this.green,
      this.courtStyle = CourtCardStyle.emblems,
      this.radius,
      this.font,
      this.frame = FaceFrame.none,
      this.frameColour,
      this.motif = BackMotif.none,
      this.motifAlpha = 0.08,
      this.pips = PipStyle.large});
  final String id;
  final String name;
  final Color card;
  final Color black;
  final Color red;
  final Color blue;
  final Color green;
  final CourtCardStyle courtStyle;
  final double? radius;
  final String? font;
  final FaceFrame frame;
  final Color? frameColour;
  final BackMotif motif;
  final double motifAlpha;
  final PipStyle pips;
}

const faceChoices = <FaceChoice>[
  FaceChoice('classic', 'Classic',
      card: Color(0xFFFFFFFF),
      black: Color(0xFF111111),
      red: Color(0xFFC8102E),
      blue: Color(0xFF1A5BC8),
      green: Color(0xFF13793A)),
  FaceChoice('ivory', 'Gilt ivory',
      card: Color(0xFFFBF4E2),
      black: Color(0xFF2A2118),
      red: Color(0xFFA3242F),
      blue: Color(0xFF2A4F8F),
      green: Color(0xFF2F6B3A),
      font: 'CinzelDecorative',
      frame: FaceFrame.double,
      frameColour: Color(0xFFC99A2E)),
  FaceChoice('antique', 'Antique',
      card: Color(0xFFE8D7B4),
      black: Color(0xFF3A2A18),
      red: Color(0xFF8E2A1E),
      blue: Color(0xFF2E5A88),
      green: Color(0xFF3E6B2E),
      radius: 0.06,
      font: 'CinzelDecorative',
      frame: FaceFrame.corners,
      frameColour: Color(0xCC6E4A22),
      motif: BackMotif.dots),
  FaceChoice('noir', 'Noir',
      card: Color(0xFF17171A),
      black: Color(0xFFEDE6D6),
      red: Color(0xFFF2626A),
      blue: Color(0xFF80B4FF),
      green: Color(0xFF7FD99A),
      courtStyle: CourtCardStyle.letters,
      frame: FaceFrame.deco,
      frameColour: Color(0xFFD4A63A),
      font: 'CinzelDecorative'),
  FaceChoice('modern', 'Modern',
      card: Color(0xFFFFFFFF),
      black: Color(0xFF1B1B1F),
      red: Color(0xFFE5383B),
      blue: Color(0xFF2F6FE0),
      green: Color(0xFF16A05D),
      courtStyle: CourtCardStyle.letters,
      radius: 0.16,
      font: 'AlegreyaSans',
      pips: PipStyle.rank),
  FaceChoice('casino', 'Casino',
      card: Color(0xFFFFFFFF),
      black: Color(0xFF000000),
      red: Color(0xFFE10600),
      blue: Color(0xFF0050D8),
      green: Color(0xFF00843D),
      radius: 0.05,
      frame: FaceFrame.rule,
      frameColour: Color(0x55000000),
      pips: PipStyle.medallion),
  FaceChoice('botanical', 'Botanical',
      card: Color(0xFFF6F3E6),
      black: Color(0xFF22301F),
      red: Color(0xFFB0413E),
      blue: Color(0xFF3D6390),
      green: Color(0xFF3E7A45),
      courtStyle: CourtCardStyle.letters,
      frame: FaceFrame.leaves,
      frameColour: Color(0xFF5E8A57)),
  FaceChoice('seaside', 'Seaside',
      card: Color(0xFFEEF6F1),
      black: Color(0xFF1C2B33),
      red: Color(0xFFC0392B),
      blue: Color(0xFF2468B0),
      green: Color(0xFF1F7A5A),
      courtStyle: CourtCardStyle.letters,
      radius: 0.12,
      motif: BackMotif.waves,
      motifAlpha: 0.1,
      pips: PipStyle.medallion),
  FaceChoice('blush', 'Blush',
      card: Color(0xFFFBEDEA),
      black: Color(0xFF2B1E22),
      red: Color(0xFFB23A48),
      blue: Color(0xFF3B5DA0),
      green: Color(0xFF3A7A55),
      courtStyle: CourtCardStyle.letters,
      radius: 0.14,
      motif: BackMotif.dots,
      motifAlpha: 0.1,
      frame: FaceFrame.rule,
      frameColour: Color(0x66B23A48)),
  FaceChoice('silver', 'Moonlit',
      card: Color(0xFF1B2440),
      black: Color(0xFFE6EAF2),
      red: Color(0xFFFF7A85),
      blue: Color(0xFF8FC0FF),
      green: Color(0xFF8BE0B0),
      courtStyle: CourtCardStyle.letters,
      frame: FaceFrame.double,
      frameColour: Color(0x99C9D2E3),
      motif: BackMotif.dots,
      pips: PipStyle.medallion),
];

/// [skin] as it's worn: with its own backs, faces and task cards, if it
/// comes with any.
Skin dressed(Skin skin) => skin is TailoredSkin ? skin : TailoredSkin.of(skin);

BackChoice? backById(String? id) => backChoices.where((b) => b.id == id).firstOrNull;
TaskChoice? taskById(String? id) => taskChoices.where((k) => k.id == id).firstOrNull;
FaceChoice? faceById(String? id) => faceChoices.where((f) => f.id == id).firstOrNull;

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// [base] with [backChoice] backs and [taskChoice] task cards (the skin's
/// own for either that's null).
class TailoredSkin extends Skin {
  const TailoredSkin(this.base, {this.backChoice, this.taskChoice, this.faceChoice});

  final Skin base;
  final BackChoice? backChoice;
  final TaskChoice? taskChoice;
  final FaceChoice? faceChoice;

  /// [base] with these choices (and its own defaults for the rest); just
  /// [base] when there's nothing to choose.
  static Skin of(Skin base, {BackChoice? back, TaskChoice? task, FaceChoice? face}) =>
      back == null && task == null && face == null && !hasDefaults(base)
          ? base
          : TailoredSkin(base, backChoice: back, taskChoice: task, faceChoice: face);

  /// Whether [skin] comes with backs, faces or task cards of its own
  /// choosing ([Skin.defaultBack] and the rest).
  static bool hasDefaults(Skin skin) =>
      skin.defaultBack != null || skin.defaultFace != null || skin.defaultTask != null;

  /// What's worn: the choice, or the skin's own default.
  BackChoice? get back => backChoice ?? backById(base.defaultBack);
  TaskChoice? get task => taskChoice ?? taskById(base.defaultTask);
  FaceChoice? get face => faceChoice ?? faceById(base.defaultFace);

  /// [skin] without its choices: the skin they're made on.
  static Skin baseOf(Skin skin) => skin is TailoredSkin ? skin.base : skin;

  @override
  String get id => [
        base.id,
        if (backChoice != null) 'b:${backChoice!.id}',
        if (taskChoice != null) 'k:${taskChoice!.id}',
        if (faceChoice != null) 'f:${faceChoice!.id}',
      ].join('+');
  @override
  String get name => base.name;

  @override
  bool operator ==(Object other) => other is TailoredSkin && other.id == id;
  @override
  int get hashCode => id.hashCode;

  // The table.
  @override
  Color get felt => base.felt;
  @override
  Color get feltDeep => base.feltDeep;
  @override
  Color get feltGlow => base.feltGlow;
  @override
  Color get table => base.table;
  @override
  Color get feltLine => base.feltLine;
  @override
  TableLook get tableLook => base.tableLook;

  // The task cards.
  @override
  TaskLook get taskLook => task?.look ?? base.taskLook;

  // The backs, and the faces.
  @override
  CardLook get cardLook {
    final f = face;
    if (f == null) return _backed;
    return _backed.withFace(
        courtStyle: f.courtStyle,
        radius: f.radius,
        faceFont: f.font,
        frame: f.frame,
        frameColour: f.frameColour,
        motif: f.motif,
        motifAlpha: f.motifAlpha,
        pips: f.pips);
  }

  CardLook get _backed {
    final b = back;
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

  /// The skin's own parts, but for its card back and faces when others
  /// are chosen.
  @override
  SkinParts get parts {
    final p = base.parts;
    if (back == null && face == null) return p;
    return SkinParts(
        cardFace: face == null ? p.cardFace : null,
        cardBack: back == null ? p.cardBack : null,
        panel: p.panel,
        table: p.table);
  }

  /// The suits as the faces chosen print them.
  @override
  Color suitColour(Suit s) {
    final f = face;
    if (f == null) return base.suitColour(s);
    return switch (s) {
      Suit.hearts => f.red,
      Suit.diamonds => Settings.fourColourSuits ? f.blue : f.red,
      Suit.spades => f.black,
      Suit.clubs => Settings.fourColourSuits ? f.green : f.black,
      Suit.court => gold,
    };
  }

  @override
  ThemeData theme() => base.theme();

  // Everything else is the skin's.
  @override
  Color get card => face?.card ?? base.card;
  @override
  Color get ink => base.ink;
  @override
  Color get inkSoft => base.inkSoft;
  @override
  Color get cardRed => face?.red ?? base.cardRed;
  @override
  Color get diamondBlue => face?.blue ?? base.diamondBlue;
  @override
  Color get clubGreen => face?.green ?? base.clubGreen;
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
  PanelLook get panelLook => base.panelLook;
  @override
  TokenLook get tokenLook => base.tokenLook;
  @override
  ButtonLook get buttonLook => base.buttonLook;
  @override
  Color get sheen => base.sheen;
}
