/// The look of the game, as one object a widget reads from its context
/// (`context.skin`, see skin_scope.dart): the palette by name, the seat
/// and suit colours, the fonts, the shadow under words on the felt, the
/// outline round every card, the dialogs' look, and the Material theme
/// built from them. The King's Court skin (court/) is today's look; the
/// Plain skin (plain/) another. Widgets name nothing of the look
/// themselves (test/skin_test.dart holds them to it).
library;

import 'package:flutter/material.dart';

import '../engine/cards.dart';
import '../platform/settings.dart';
import 'looks.dart';
import 'parts.dart';

abstract class Skin {
  const Skin();

  /// Saved with the settings; never changes once a skin has shipped.
  String get id;

  /// What the menu calls it.
  String get name;

  // ------------------------------------------------------------ palette

  /// The card table's felt, and the deeper shade in its shadows.
  Color get felt;
  Color get feltDeep;

  /// The table the felt is set into (and the browser's bars).
  Color get table;
  Color get feltLine;

  /// Card stock, and the ink on it.
  Color get card;
  Color get ink;
  Color get inkSoft;
  Color get cardRed;

  /// Four-colour suits: ♦ and ♣ in their own colours.
  Color get diamondBlue;
  Color get clubGreen;

  /// Gold, reserved for the King: its body, deep and light shades, the
  /// palest highlight, the dark rim round a gold button, and gold ink on
  /// a gold ground.
  Color get gold;
  Color get goldDeep;
  Color get goldLight;
  Color get goldPale;
  Color get goldRim;
  Color get goldInk;

  /// Old paper and soft card stock.
  Color get parchment;
  Color get ivory;

  /// Pale gold words on the felt.
  Color get goldOnFelt;

  /// A failed task's card.
  Color get failedCard;

  /// Hearts on the felt, where card red is too dark to read.
  Color get redOnDark;

  /// A traitor's colours.
  Color get traitor;
  Color get traitorDeep;
  Color get traitorPanel;

  /// Won and lost.
  Color get won;
  Color get lost;

  /// The seats' colours.
  List<Color> get players;

  /// The colours four-colour ♦ and ♣ are printed in on the felt.
  Color get diamondOnDark;
  Color get clubOnDark;

  /// The colour a suit is printed in (with the four-colour setting).
  Color suitColour(Suit s) => switch (s) {
        Suit.hearts => cardRed,
        Suit.diamonds => Settings.fourColourSuits ? diamondBlue : cardRed,
        Suit.spades => ink,
        Suit.clubs => Settings.fourColourSuits ? clubGreen : ink,
        Suit.court => gold,
      };

  /// The colour a suit is printed in on the felt or another dark ground,
  /// where [text] is the colour of the words around it.
  Color suitColourOnDark(Suit s, Color text) => switch (s) {
        Suit.hearts => redOnDark,
        Suit.diamonds => Settings.fourColourSuits ? diamondOnDark : redOnDark,
        Suit.clubs => Settings.fourColourSuits ? clubOnDark : text,
        Suit.spades || Suit.court => text,
      };

  // -------------------------------------------------------------- type

  /// The face for titles and every number, and the face for words.
  String get displayFont;
  String get bodyFont;

  /// The soft shadow under words and icons on the felt.
  List<Shadow> get feltShadow;

  /// A task's words on its card; the card's size is measured in it.
  TextStyle get taskText;

  // -------------------------------------------------------------- cards

  /// The crisp line round every card and task card.
  Color get outlineColour;
  double get outlineWidth;

  // ------------------------------------------------------------ dialogs

  /// The plain dialog's ground, corner radius, edge and shape, and what
  /// dims the screen behind it.
  Color get dialogBackground;
  double get dialogRadius;
  Color get dialogEdge;
  ShapeBorder get dialogShape;
  Color get barrier;

  /// A dialog's title, its words, and quieter words under them.
  TextStyle get dialogTitle;
  TextStyle get dialogBody;
  TextStyle get dialogNote;

  /// A task's close-up is on card stock instead, like the card itself.
  Color get paper;
  TextStyle get paperTitle;

  // ------------------------------------------------------------- shapes

  /// How the table, panels, cards, seat tokens and buttons are built
  /// (looks.dart).
  TableLook get tableLook;
  PanelLook get panelLook;
  CardLook get cardLook;
  TokenLook get tokenLook;
  ButtonLook get buttonLook;

  /// Parts the skin draws itself (parts.dart); none by default.
  /// The light behind the crowning: the felt, lit.
  Color get feltGlow => Color.lerp(felt, const Color(0xFFFFFFFF), 0.08)!;

  SkinParts get parts => const SkinParts();

  /// The Material theme: buttons, dialogs, the app bar, in this look.
  ThemeData theme();
}
