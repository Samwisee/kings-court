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
import 'choices.dart';
import 'looks.dart';
import 'parts.dart';
import 'skin.dart';

export 'choices.dart';

/// [skin] as it's worn: with its own backs, faces and task cards, if it
/// comes with any.
Skin dressed(Skin skin) => skin is TailoredSkin ? skin : TailoredSkin.of(skin);

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// [base] with [backChoice] backs and [taskChoice] task cards (the skin's
/// own for either that's null).
class TailoredSkin extends Skin {
  const TailoredSkin(this.base,
      {this.backChoice, this.taskChoice, this.faceChoice, this.tokenChoice, this.courtChoice});

  final Skin base;
  final BackChoice? backChoice;
  final TaskChoice? taskChoice;
  final FaceChoice? faceChoice;
  final TokenChoice? tokenChoice;
  final CourtChoice? courtChoice;

  /// [base] with these choices (and its own defaults for the rest); just
  /// [base] when there's nothing to choose.
  static Skin of(Skin base,
          {BackChoice? back, TaskChoice? task, FaceChoice? face, TokenChoice? token, CourtChoice? court}) =>
      back == null && task == null && face == null && token == null && court == null && !hasDefaults(base)
          ? base
          : TailoredSkin(base,
              backChoice: back, taskChoice: task, faceChoice: face, tokenChoice: token, courtChoice: court);

  /// Whether [skin] comes with backs, faces or task cards of its own
  /// choosing ([Skin.defaultBack] and the rest).
  static bool hasDefaults(Skin skin) =>
      skin.defaultBack != null || skin.defaultFace != null || skin.defaultTask != null || skin.defaultToken != null;

  /// What's worn: the choice, or the skin's own default.
  BackChoice? get back => backChoice ?? backById(base.defaultBack);
  TaskChoice? get task => taskChoice ?? taskById(base.defaultTask);
  FaceChoice? get face => faceChoice ?? faceById(base.defaultFace);
  TokenChoice? get token => tokenChoice ?? tokenById(base.defaultToken);

  /// The Court Cards: chosen, or those that come with the style's own
  /// faces.
  CourtChoice? get court => courtChoice ?? courtById(base.defaultFace);

  /// [skin] without its choices: the skin they're made on.
  static Skin baseOf(Skin skin) => skin is TailoredSkin ? skin.base : skin;

  @override
  String get id => [
        base.id,
        if (backChoice != null) 'b:${backChoice!.id}',
        if (taskChoice != null) 'k:${taskChoice!.id}',
        if (faceChoice != null) 'f:${faceChoice!.id}',
        if (tokenChoice != null) 'o:${tokenChoice!.id}',
        if (courtChoice != null) 'c:${courtChoice!.id}',
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
    final c = court;
    var look = _backed;
    if (f != null) {
      look = look.withFace(
          radius: f.radius,
          faceFont: f.font,
          frame: f.frame,
          frameColour: f.frameColour,
          motif: f.motif,
          motifAlpha: f.motifAlpha,
          pips: f.pips);
    }
    if (c != null) look = look.withCourt(cloth: c.cloth, patterns: c.patterns, ink: c.ink, arch: c.arch);
    return look;
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
    if (back == null && face == null && court == null) return p;
    return SkinParts(
        cardFace: face == null && court == null ? p.cardFace : null,
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
  TokenLook get tokenLook {
    final t = token;
    final own = base.tokenLook;
    if (t == null) return own;
    return TokenLook(shaped: own.shaped, ringWidth: own.ringWidth, style: t.style);
  }
  @override
  ButtonLook get buttonLook => base.buttonLook;
  @override
  Color get sheen => base.sheen;
}
