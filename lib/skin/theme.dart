import 'package:flutter/material.dart';

import '../engine/cards.dart';
import '../game/state.dart';

/// The King's Court palette: card table felt, white card stock, card-red
/// and black suits, and brass gold reserved for the King.
class Palette {
  static const felt = Color(0xFF0F4A2E);
  static const feltDeep = Color(0xFF0A3622);

  /// The dark red table the felt is set into, the King's cloth in shadow
  /// (and the browser's bars).
  static const table = Color(0xFF4E0B18);
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
        Suit.hearts => redOnDark,
        Suit.diamonds => fourColourSuits ? diamondOnDark : redOnDark,
        Suit.clubs => fourColourSuits ? clubOnDark : text,
        Suit.spades || Suit.court => text,
      };

  /// Four-colour ♦ and ♣ on the felt.
  static const diamondOnDark = Color(0xFF8DBBFF);
  static const clubOnDark = Color(0xFF7FD99A);
  static const gold = Color(0xFFD4A63A);
  static const goldDeep = Color(0xFFA57C1B);

  /// The gold's highlights: gilt gradients run [goldLight] to [gold].
  static const goldLight = Color(0xFFF9E08C);
  static const goldPale = Color(0xFFFFF1B8);

  /// The dark rim round a gold button, and gold ink on a gold ground.
  static const goldRim = Color(0xFF7A5A12);
  static const goldInk = Color(0xFF6E4E0E);

  /// Old paper (parchment notes, scrolls) and soft card stock.
  static const parchment = Color(0xFFF6EBD2);
  static const ivory = Color(0xFFFBF5E6);

  /// Pale gold words on the dark felt (the menu).
  static const goldOnFelt = Color(0xFFF3E7C6);

  /// A failed task's card: blush pink, edged in [lost].
  static const failedCard = Color(0xFFFBE4E1);

  /// Hearts (and four-colour diamonds) on the felt, where card red is too
  /// dark to read.
  static const redOnDark = Color(0xFFFF8A94);

  /// A traitor's colours: deep blood red to near black.
  static const traitor = Color(0xFF3A0610);
  static const traitorDeep = Color(0xFF14060A);
  static const traitorPanel = Color(0xFF2A0810);
  static const won = Color(0xFF3FA66A);
  static const lost = Color(0xFFD9483B);

  /// Seat colours. Chosen to stay clear of the card red so a player's
  /// colour is never mistaken for a suit.
  /// The seats' colours (see playerColours in models.dart).
  static final players = <Color>[for (final v in playerColours) Color(v)];
}

/// A seat's colour on screen. The game keeps colours as plain numbers so it
/// has no Flutter in it; these turn them into Colors where they're drawn.
extension PlayerColour on Player {
  Color get color => Color(colorValue);
  set color(Color c) => colorValue = c.toARGB32();
}

/// Royal display face for titles and every number: Roman capitals with
/// old-style numerals.
const displayFont = 'CinzelDecorative';
const bodyFont = 'AlegreyaSans';

// ---------------------------------------------------------------- the skin
//
// Everything that decides how the court looks lives in this file: the
// palette above, the type faces, the soft shadow under words on the felt,
// and the look of every dialog and pop-up below. A new skin for the game
// changes these, and every screen follows.

/// The soft shadow under words and icons on the felt.
const feltShadow = [Shadow(color: Colors.black54, blurRadius: 10)];

/// Every dialog and pop-up's look, in one place.
class DialogStyle {
  /// The plain dialog: the felt, edged in gold.
  static const background = Palette.feltDeep;
  static const radius = 22.0;
  static const edge = Color(0xB3D4A63A);
  static const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      side: BorderSide(color: edge, width: 1.4));

  /// What dims the screen behind a dialog.
  static const barrier = Color(0x73000000);

  /// Its title: the court's display face in gold.
  static const title = TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w700,
      fontSize: 22,
      height: 1.2,
      color: Palette.gold,
      shadows: feltShadow);

  /// Its words.
  static const body = TextStyle(fontSize: 16, height: 1.45, color: Colors.white);

  /// Quieter words under them.
  static const note = TextStyle(fontSize: 14, height: 1.4, color: Colors.white70);

  /// A task's close-up is on card stock instead, like the task card itself.
  static const paper = Palette.card;
  static const paperTitle = TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w700,
      fontSize: 22,
      color: Palette.ink);
}

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
      ).copyWith(
        // A satisfying press: the button sinks (its shadow goes), darkens,
        // and its rim thickens, then springs back.
        elevation: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? 0 : s.contains(WidgetState.pressed) ? 0 : 4),
        overlayColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.pressed)
                ? const Color(0x33000000)
                : s.contains(WidgetState.hovered)
                    ? const Color(0x1AFFFFFF)
                    : null),
        side: WidgetStateProperty.resolveWith((s) => BorderSide(
            color: const Color(0xFF7A5A12),
            width: s.contains(WidgetState.pressed) ? 3 : 1.5)),
        animationDuration: const Duration(milliseconds: 90),
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
    // Every dialog, unless it says otherwise (see [DialogStyle]).
    dialogTheme: const DialogThemeData(
      backgroundColor: DialogStyle.background,
      surfaceTintColor: Colors.transparent,
      shape: DialogStyle.shape,
      barrierColor: DialogStyle.barrier,
      titleTextStyle: DialogStyle.title,
      contentTextStyle: DialogStyle.body,
    ),
    // Quiet text buttons in gold, with no grey wash when pressed.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.gold,
        overlayColor: Colors.transparent,
        textStyle: const TextStyle(
            fontFamily: bodyFont, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// A crisp dark line round every card and task card, so they stand out
/// from the felt and number cards sit as boldly as the Court Cards. A deep
/// brown rather than black (the cartoon outline's family): 13.5:1 against
/// the card stock and 6:1 against gold, well over the 3:1 an edge needs.
const outlineColour = Color(0xFF3B2A12);
const outlineWidth = 1.25;

/// Draws [child] inside a dark outline [outlineWidth] thick, the same all
/// the way round (a shadow's spread would thicken the corners). The child
/// should round its corners to [radius] - [outlineWidth].
class InkOutline extends StatelessWidget {
  const InkOutline(
      {super.key, required this.radius, required this.child, this.shadows = const []});
  final double radius;
  final List<BoxShadow> shadows;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: outlineColour,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: shadows),
        child: Padding(padding: const EdgeInsets.all(outlineWidth), child: child),
      );
}

/// The dark line just inside a coloured border [inset] wide, so the colour
/// has dark on both sides (the outer line is the card's own outline).
class InnerEdge extends CustomPainter {
  const InnerEdge({required this.radius, required this.inset});
  final double radius;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final d = inset + outlineWidth / 2;
    final r = (Offset.zero & size).deflate(d);
    if (r.isEmpty) return;
    canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(radius - d < 0 ? 0 : radius - d)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth
          ..color = outlineColour);
  }

  @override
  bool shouldRepaint(InnerEdge old) => old.radius != radius || old.inset != inset;
}
