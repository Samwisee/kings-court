import 'package:flutter/material.dart';

import 'engine/cards.dart';

/// The King's Court palette: card table felt, white card stock, card-red
/// and black suits, and brass gold reserved for the King.
class Palette {
  static const felt = Color(0xFF0F4A2E);
  static const feltDeep = Color(0xFF0A3622);
  static const feltLine = Color(0xFF2A6B4B);
  static const card = Color(0xFFFFFDF8);
  static const ink = Color(0xFF1D1B18);
  static const inkSoft = Color(0xFF6B655C);
  static const cardRed = Color(0xFFB3122B);

  /// Four-colour suits (a setting in the menu): ♦ blue and ♣ green, so no
  /// two suits share a colour. Easier to tell apart at a glance, for
  /// colour-blind players and anyone on a small screen. Every suit keeps
  /// its own shape either way.
  static bool fourColourSuits = false;
  static const diamondBlue = Color(0xFF1A5BC8);
  static const clubGreen = Color(0xFF13793A);

  /// The colour a suit is printed in.
  static Color suitColour(Suit s) => switch (s) {
        Suit.hearts => cardRed,
        Suit.diamonds => fourColourSuits ? diamondBlue : cardRed,
        Suit.spades => ink,
        Suit.clubs => fourColourSuits ? clubGreen : ink,
        Suit.court => gold,
      };

  /// The colour a suit is printed in on the felt or another dark
  /// background, where [text] is the colour of the words around it.
  static Color suitColourOnDark(Suit s, Color text) => switch (s) {
        Suit.hearts => const Color(0xFFFF8A94),
        Suit.diamonds =>
          fourColourSuits ? const Color(0xFF8DBBFF) : const Color(0xFFFF8A94),
        Suit.clubs => fourColourSuits ? const Color(0xFF7FD99A) : text,
        Suit.spades || Suit.court => text,
      };
  static const gold = Color(0xFFD4A63A);
  static const goldDeep = Color(0xFFA57C1B);
  static const won = Color(0xFF3FA66A);
  static const lost = Color(0xFFD9483B);

  /// Seat colours. Chosen to stay clear of the card red so a player's
  /// colour is never mistaken for a suit.
  static const players = <Color>[
    // From the Okabe–Ito set, chosen to stay distinct for colour-blind
    // players and from each other at a glance.
    Color(0xFFE69F00), // orange
    Color(0xFF56B4E9), // sky blue
    Color(0xFFCC79A7), // reddish purple
    Color(0xFF009E73), // bluish green
    Color(0xFFF0E442), // yellow
    Color(0xFF0072B2), // deep blue
  ];
}

/// Royal display face for titles and every number: Roman capitals with
/// old-style numerals.
const displayFont = 'CinzelDecorative';
const bodyFont = 'AlegreyaSans';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.felt,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Palette.gold,
    onPrimary: Palette.ink,
    surface: Palette.feltDeep,
    onSurface: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: bodyFont,
    scaffoldBackgroundColor: Palette.felt,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.felt,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    // Buttons with cut corners and a gilt edge, like plaques at court.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.gold,
        foregroundColor: Palette.ink,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        elevation: 3,
        shadowColor: Colors.black,
        textStyle: const TextStyle(
            fontFamily: displayFont,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6),
        side: const BorderSide(color: Color(0xFF7A5A12), width: 1.5),
        shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0x22000000),
        side: const BorderSide(color: Color(0xAAD4A63A), width: 1.5),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: const TextStyle(
            fontFamily: displayFont,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
        shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// A crisp dark line round every card and task card, so they stand out
/// from the felt and number cards sit as boldly as the Court Cards (the
/// same dark as the cartoon outline round the gold emblems).
const cardOutline = BoxShadow(color: Color(0xFF1D1408), spreadRadius: 1.5);
