/// A skin made from a design: a dozen colours, two faces, a corner radius
/// and a finish. Every other colour, every look (looks.dart) and the
/// Material theme follow from those, so a new skin is a [SkinDesign] and
/// nothing else. A skin that wants more overrides any getter, or draws a
/// part itself ([Skin.parts]).
library;

import 'package:flutter/material.dart';

import 'fields.dart';
import 'looks.dart';
import 'skin.dart';

/// How dressed up a designed skin is.
enum Finish {
  /// Ornate panels with medallions, the felt set into a rimmed table, the
  /// Court Cards' emblems on their cloths, courtiers in their houses'
  /// shapes, bevelled buttons.
  rich,

  /// Flat panels, the play area to the edge, clean Court Cards, round
  /// seats, rounded buttons.
  simple,
}

class SkinDesign {
  const SkinDesign({
    required this.id,
    required this.name,
    required this.ground,
    required this.felt,
    required this.feltDeep,
    required this.surface,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.accentDeep,
    required this.red,
    required this.won,
    required this.lost,
    required this.displayFont,
    required this.bodyFont,
    this.finish = Finish.simple,
    this.radius = 12,
    this.pattern = FeltPattern.none,
    this.patternInk = const Color(0x00000000),
    this.onAccent,
    this.cloth = const [
      [Color(0xFF5A2F87), Color(0xFF241238)],
      [Color(0xFF13734A), Color(0xFF062A1B)],
      [Color(0xFF2849A8), Color(0xFF0B1A45)],
      [Color(0xFF9A1E31), Color(0xFF3A0610)],
    ],
    this.players = const [
      Color(0xFFE69F00),
      Color(0xFF56B4E9),
      Color(0xFFCC79A7),
      Color(0xFF009E73),
      Color(0xFFF0E442),
      Color(0xFF0072B2),
    ],
  });

  /// Saved with the settings, and what the menu calls it.
  final String id;
  final String name;

  /// What lies round the play area (the table), the play area itself and
  /// its shade, and the ground of panels and dialogs.
  final Color ground;
  final Color felt;
  final Color feltDeep;
  final Color surface;

  /// Card stock, the ink on it and the softer ink.
  final Color card;
  final Color ink;
  final Color inkSoft;

  /// The one accent (gold, at court): the King, what's chosen, the
  /// buttons; and a deeper shade of it.
  final Color accent;
  final Color accentDeep;

  /// What's written on the accent (the ink, when null).
  final Color? onAccent;

  /// Hearts and diamonds; and won and lost.
  final Color red;
  final Color won;
  final Color lost;

  final String displayFont;
  final String bodyFont;

  final Finish finish;

  /// What's worked into the felt (looks.dart), in [patternInk]: on the
  /// table, and faintly in the menus and pages dressed in this skin.
  final FeltPattern pattern;
  final Color patternInk;

  /// The corner radius of panels and buttons; cards keep their own.
  final double radius;

  /// The Court Cards' colours, Joker, Jack, Queen, King: light then dark.
  final List<List<Color>> cloth;

  /// The seats' colours: kept distinct for colour-blind players unless
  /// there's reason not to.
  final List<Color> players;
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

class DesignSkin extends Skin {
  const DesignSkin(this.design);

  final SkinDesign design;
  bool get _rich => design.finish == Finish.rich;

  @override
  String get id => design.id;
  @override
  String get name => design.name;

  @override
  Color get felt => design.felt;
  @override
  Color get feltDeep => design.feltDeep;
  @override
  Color get table => design.ground;
  @override
  Color get feltLine => _mix(design.felt, Colors.white, 0.12);
  @override
  Color get card => design.card;
  @override
  Color get ink => design.ink;
  @override
  Color get inkSoft => design.inkSoft;
  @override
  Color get cardRed => design.red;
  @override
  Color get diamondBlue => const Color(0xFF1A5BC8);
  @override
  Color get clubGreen => const Color(0xFF13793A);
  @override
  Color get diamondOnDark => const Color(0xFF8DBBFF);
  @override
  Color get clubOnDark => const Color(0xFF7FD99A);
  @override
  Color get gold => design.accent;
  @override
  Color get goldDeep => design.accentDeep;
  @override
  Color get goldLight => _mix(design.accent, Colors.white, 0.45);
  @override
  Color get goldPale => _mix(design.accent, Colors.white, 0.75);
  @override
  Color get goldRim => _mix(design.accentDeep, Colors.black, 0.35);
  @override
  Color get goldInk => design.onAccent ?? _mix(design.accentDeep, Colors.black, 0.55);
  @override
  Color get parchment => _mix(design.card, design.accent, 0.08);
  @override
  Color get ivory => _mix(design.card, design.accent, 0.04);
  @override
  Color get goldOnFelt => _mix(Colors.white, design.accent, 0.15);
  @override
  Color get failedCard => _mix(design.card, design.lost, 0.14);
  @override
  Color get redOnDark => _mix(design.red, Colors.white, 0.45);
  @override
  Color get traitor => const Color(0xFF3A0610);
  @override
  Color get traitorDeep => const Color(0xFF14060A);
  @override
  Color get traitorPanel => const Color(0xFF2A0810);
  @override
  Color get won => design.won;
  @override
  Color get lost => design.lost;
  @override
  List<Color> get players => design.players;

  @override
  String get displayFont => design.displayFont;
  @override
  String get bodyFont => design.bodyFont;
  @override
  List<Shadow> get feltShadow => _rich
      ? const [Shadow(color: Colors.black54, blurRadius: 10)]
      : const [Shadow(color: Colors.black38, blurRadius: 5)];
  @override
  TextStyle get taskText => TextStyle(
      fontFamily: bodyFont,
      fontSize: 13.5,
      height: 1.15,
      fontWeight: FontWeight.w500,
      color: ink);

  @override
  Color get outlineColour => _mix(design.ink, design.feltDeep, 0.25);
  @override
  double get outlineWidth => _rich ? 1.25 : 1.0;

  @override
  Color get dialogBackground => design.surface;
  @override
  double get dialogRadius => design.radius + (_rich ? 10 : 4);
  @override
  Color get dialogEdge => design.accent.withValues(alpha: _rich ? 0.7 : 0.35);
  @override
  ShapeBorder get dialogShape => RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(dialogRadius)),
      side: BorderSide(color: dialogEdge, width: _rich ? 1.4 : 1));
  @override
  Color get barrier => const Color(0x73000000);
  @override
  TextStyle get dialogTitle => TextStyle(
      fontFamily: displayFont,
      fontWeight: _rich ? FontWeight.w700 : FontWeight.w800,
      fontSize: 22,
      height: 1.2,
      color: design.accent,
      shadows: _rich ? feltShadow : null);
  @override
  TextStyle get dialogBody =>
      const TextStyle(fontSize: 16, height: 1.45, color: Colors.white);
  @override
  TextStyle get dialogNote =>
      const TextStyle(fontSize: 14, height: 1.4, color: Colors.white70);
  @override
  Color get paper => design.card;
  @override
  TextStyle get paperTitle => TextStyle(
      fontFamily: displayFont, fontWeight: FontWeight.w700, fontSize: 22, color: ink);

  @override
  TableLook get tableLook => _table.withPattern(design.pattern, design.patternInk);

  TableLook get _table => _rich
      ? TableLook(
          style: TableStyle.rimmed,
          outerRule: design.accent.withValues(alpha: 0.8),
          innerRule: design.accent.withValues(alpha: 0.4),
          panelRule: design.accent.withValues(alpha: 0.6),
          panelInnerRule: design.accent.withValues(alpha: 0.4),
          lamp: 0.06,
        )
      : TableLook(
          style: TableStyle.edged,
          rim: 0,
          radius: 0,
          sunk: false,
          panelRule: feltLine,
        );

  @override
  PanelLook get panelLook {
    final surface = design.surface;
    if (_rich) {
      return PanelLook(
        style: PanelStyle.ornate,
        court: [_mix(surface, Colors.white, 0.08), surface, _mix(surface, Colors.black, 0.35)],
        won: [goldLight, design.accent, design.accentDeep],
        lost: [_mix(design.lost, Colors.black, 0.6), _mix(design.lost, Colors.black, 0.8),
          _mix(design.lost, Colors.black, 0.88)],
        courtMedallion: [_mix(surface, Colors.white, 0.15), design.feltDeep],
        wonMedallion: [goldPale, design.accent],
        lostMedallion: [_mix(design.lost, Colors.black, 0.45), _mix(design.lost, Colors.black, 0.75)],
        radius: design.radius + 6,
      );
    }
    return PanelLook(
      style: PanelStyle.flat,
      court: [surface, surface],
      // A win is a panel in the accent, with the dark ink on it.
      won: [goldLight, design.accent],
      lost: [_mix(surface, design.lost, 0.18), _mix(surface, design.lost, 0.12)],
      courtMedallion: [design.accent, design.accent],
      wonMedallion: [design.accentDeep, design.accentDeep],
      lostMedallion: [design.lost, design.lost],
      radius: design.radius + 4,
      edgeWidth: 1,
    );
  }

  @override
  CardLook get cardLook => CardLook(
        courtStyle: _rich ? CourtCardStyle.emblems : CourtCardStyle.letters,
        cloth: design.cloth,
        courtFrame: design.accent.withValues(alpha: 0.6),
        back: _rich ? _mix(design.ground, Colors.black, 0.1) : design.accentDeep,
        backEdge: _rich ? design.accent : _mix(design.accentDeep, Colors.white, 0.3),
        radius: _rich ? 0.1 : 0.08,
        backPattern: true,
        backPatternAlpha: _rich ? 0.14 : 0.35,
        backRule: _rich ? design.accent.withValues(alpha: 0.6) : null,
        backCrown: _rich ? null : _mix(design.accentDeep, Colors.white, 0.3),
      );

  @override
  TokenLook get tokenLook => TokenLook(shaped: _rich);

  @override
  ButtonLook get buttonLook => ButtonLook(bevelled: _rich, glow: _rich);

  @override
  ThemeData theme() {
    final onAccent = design.onAccent ?? design.ink;
    final scheme = ColorScheme.fromSeed(seedColor: felt, brightness: Brightness.dark)
        .copyWith(primary: gold, onPrimary: onAccent, surface: feltDeep, onSurface: Colors.white);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: bodyFont,
      scaffoldBackgroundColor: felt,
    );
    final shape = _rich
        ? BeveledRectangleBorder(borderRadius: BorderRadius.circular(design.radius))
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(design.radius));
    final label = TextStyle(
        fontFamily: _rich ? displayFont : bodyFont,
        fontSize: _rich ? 15 : 16,
        fontWeight: _rich ? FontWeight.w700 : FontWeight.w800,
        letterSpacing: _rich ? 0.6 : 0.2);
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: felt,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: onAccent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          elevation: _rich ? 3 : 0,
          shadowColor: Colors.black,
          textStyle: label,
          side: _rich ? BorderSide(color: goldRim, width: 1.5) : BorderSide.none,
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: _rich ? const Color(0x22000000) : Colors.transparent,
          side: BorderSide(color: gold.withValues(alpha: 0.7), width: 1.5),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: label,
          shape: shape,
        ),
      ),
      inputDecorationTheme: fieldTheme(accent: gold, radius: design.radius, font: bodyFont),
      textSelectionTheme: selectionTheme(gold),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogBackground,
        surfaceTintColor: Colors.transparent,
        shape: dialogShape,
        barrierColor: barrier,
        titleTextStyle: dialogTitle,
        contentTextStyle: dialogBody,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: gold,
          overlayColor: Colors.transparent,
          textStyle: TextStyle(fontFamily: bodyFont, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
