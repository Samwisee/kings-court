/// The Plain skin: a quiet look beside the court's. Slate instead of felt,
/// one teal accent instead of gold, the body face for titles too, flat
/// dialogs and flat buttons. The Court Card art and the table's ornament
/// stay as they are (they're the court skin's art, drawn the same in
/// both); everything named in the palette follows.
library;

import 'package:flutter/material.dart';

import '../skin.dart';

class PlainSkin extends Skin {
  const PlainSkin();

  @override
  String get id => 'plain';
  @override
  String get name => 'Plain';

  @override
  Color get felt => const Color(0xFF26324A);
  @override
  Color get feltDeep => const Color(0xFF1B2438);
  @override
  Color get table => const Color(0xFF111827);
  @override
  Color get feltLine => const Color(0xFF3A4A68);
  @override
  Color get card => const Color(0xFFFFFFFF);
  @override
  Color get ink => const Color(0xFF1A1D23);
  @override
  Color get inkSoft => const Color(0xFF5F6673);
  @override
  Color get cardRed => const Color(0xFFC62839);
  @override
  Color get diamondBlue => const Color(0xFF1A5BC8);
  @override
  Color get clubGreen => const Color(0xFF13793A);
  @override
  Color get diamondOnDark => const Color(0xFF8DBBFF);
  @override
  Color get clubOnDark => const Color(0xFF7FD99A);
  @override
  Color get gold => const Color(0xFF4FB3C9);
  @override
  Color get goldDeep => const Color(0xFF2B8197);
  @override
  Color get goldLight => const Color(0xFFA6E1EE);
  @override
  Color get goldPale => const Color(0xFFD5F2F8);
  @override
  Color get goldRim => const Color(0xFF1D5C6C);
  @override
  Color get goldInk => const Color(0xFF15434F);
  @override
  Color get parchment => const Color(0xFFF1F3F6);
  @override
  Color get ivory => const Color(0xFFF7F8FA);
  @override
  Color get goldOnFelt => const Color(0xFFE3EAF2);
  @override
  Color get failedCard => const Color(0xFFFBE4E1);
  @override
  Color get redOnDark => const Color(0xFFFF8A94);
  @override
  Color get traitor => const Color(0xFF3A0610);
  @override
  Color get traitorDeep => const Color(0xFF14060A);
  @override
  Color get traitorPanel => const Color(0xFF2A0810);
  @override
  Color get won => const Color(0xFF3FA66A);
  @override
  Color get lost => const Color(0xFFD9483B);
  @override
  List<Color> get players => const [
        Color(0xFFE69F00),
        Color(0xFF56B4E9),
        Color(0xFFCC79A7),
        Color(0xFF009E73),
        Color(0xFFF0E442),
        Color(0xFF0072B2),
      ];

  @override
  String get displayFont => 'AlegreyaSans';
  @override
  String get bodyFont => 'AlegreyaSans';
  @override
  List<Shadow> get feltShadow => const [Shadow(color: Colors.black38, blurRadius: 6)];
  @override
  TextStyle get taskText => const TextStyle(
      fontFamily: 'AlegreyaSans',
      fontSize: 13.5,
      height: 1.15,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1A1D23));

  @override
  Color get outlineColour => const Color(0xFF2A2F38);
  @override
  double get outlineWidth => 1.0;

  @override
  Color get dialogBackground => feltDeep;
  @override
  double get dialogRadius => 12;
  @override
  Color get dialogEdge => const Color(0x664FB3C9);
  @override
  ShapeBorder get dialogShape => RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(dialogRadius)),
      side: BorderSide(color: dialogEdge));
  @override
  Color get barrier => const Color(0x73000000);
  @override
  TextStyle get dialogTitle => TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w800,
      fontSize: 22,
      height: 1.2,
      color: gold);
  @override
  TextStyle get dialogBody =>
      const TextStyle(fontSize: 16, height: 1.45, color: Colors.white);
  @override
  TextStyle get dialogNote =>
      const TextStyle(fontSize: 14, height: 1.4, color: Colors.white70);
  @override
  Color get paper => card;
  @override
  TextStyle get paperTitle => TextStyle(
      fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 22, color: ink);

  @override
  ThemeData theme() {
    final scheme = ColorScheme.fromSeed(seedColor: felt, brightness: Brightness.dark)
        .copyWith(primary: gold, onPrimary: ink, surface: feltDeep, onSurface: Colors.white);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: bodyFont,
      scaffoldBackgroundColor: felt,
    );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
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
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: TextStyle(fontFamily: bodyFont, fontSize: 16, fontWeight: FontWeight.w800),
          shape: rounded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: gold.withValues(alpha: 0.7), width: 1.5),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: TextStyle(fontFamily: bodyFont, fontSize: 16, fontWeight: FontWeight.w800),
          shape: rounded,
        ),
      ),
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
