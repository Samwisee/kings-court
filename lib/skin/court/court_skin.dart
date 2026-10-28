/// The King's Court skin: card table felt, white card stock, card-red and
/// black suits, and brass gold for the King. Its values are the constants
/// in theme.dart, which the code not yet reading the skin from its context
/// still names.
library;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../skin.dart';
import '../theme.dart' as court;

class CourtSkin extends Skin {
  const CourtSkin();

  @override
  String get id => 'court';
  @override
  String get name => "The King's Court";

  @override
  Color get felt => court.Palette.felt;
  @override
  Color get feltDeep => court.Palette.feltDeep;
  @override
  Color get table => court.Palette.table;
  @override
  Color get feltLine => court.Palette.feltLine;
  @override
  Color get card => court.Palette.card;
  @override
  Color get ink => court.Palette.ink;
  @override
  Color get inkSoft => court.Palette.inkSoft;
  @override
  Color get cardRed => court.Palette.cardRed;
  @override
  Color get diamondBlue => court.Palette.diamondBlue;
  @override
  Color get clubGreen => court.Palette.clubGreen;
  @override
  Color get gold => court.Palette.gold;
  @override
  Color get goldDeep => court.Palette.goldDeep;
  @override
  Color get goldLight => court.Palette.goldLight;
  @override
  Color get goldPale => court.Palette.goldPale;
  @override
  Color get goldRim => court.Palette.goldRim;
  @override
  Color get goldInk => court.Palette.goldInk;
  @override
  Color get parchment => court.Palette.parchment;
  @override
  Color get ivory => court.Palette.ivory;
  @override
  Color get goldOnFelt => court.Palette.goldOnFelt;
  @override
  Color get failedCard => court.Palette.failedCard;
  @override
  Color get redOnDark => court.Palette.redOnDark;
  @override
  Color get traitor => court.Palette.traitor;
  @override
  Color get traitorDeep => court.Palette.traitorDeep;
  @override
  Color get traitorPanel => court.Palette.traitorPanel;
  @override
  Color get won => court.Palette.won;
  @override
  Color get lost => court.Palette.lost;
  @override
  List<Color> get players => court.Palette.players;

  @override
  Color suitColour(Suit s, {required bool fourColour}) => switch (s) {
        Suit.hearts => cardRed,
        Suit.diamonds => fourColour ? diamondBlue : cardRed,
        Suit.spades => ink,
        Suit.clubs => fourColour ? clubGreen : ink,
        Suit.court => gold,
      };

  @override
  Color suitColourOnDark(Suit s, Color text, {required bool fourColour}) =>
      switch (s) {
        Suit.hearts => redOnDark,
        Suit.diamonds => fourColour ? court.Palette.diamondOnDark : redOnDark,
        Suit.clubs => fourColour ? court.Palette.clubOnDark : text,
        Suit.spades || Suit.court => text,
      };

  @override
  String get displayFont => court.displayFont;
  @override
  String get bodyFont => court.bodyFont;
  @override
  List<Shadow> get feltShadow => court.feltShadow;

  @override
  Color get outlineColour => court.outlineColour;
  @override
  double get outlineWidth => court.outlineWidth;

  @override
  Color get dialogBackground => court.DialogStyle.background;
  @override
  double get dialogRadius => court.DialogStyle.radius;
  @override
  Color get dialogEdge => court.DialogStyle.edge;
  @override
  ShapeBorder get dialogShape => court.DialogStyle.shape;
  @override
  Color get barrier => court.DialogStyle.barrier;
  @override
  TextStyle get dialogTitle => court.DialogStyle.title;
  @override
  TextStyle get dialogBody => court.DialogStyle.body;
  @override
  TextStyle get dialogNote => court.DialogStyle.note;
  @override
  Color get paper => court.DialogStyle.paper;
  @override
  TextStyle get paperTitle => court.DialogStyle.paperTitle;

  @override
  ThemeData theme() => court.buildTheme();
}
