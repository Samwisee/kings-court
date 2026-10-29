/// The King's Court skin: card table felt, white card stock, card-red and
/// black suits, and brass gold for the King. Its values are the constants
/// in theme.dart, which the code not yet reading the skin from its context
/// still names.
library;

import 'package:flutter/material.dart';

import '../looks.dart';
import '../skin.dart';
import '../theme.dart' as court;

class CourtSkin extends Skin {
  const CourtSkin();

  @override
  String get id => 'court';
  @override
  String get name => 'Court';

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
  Color get diamondOnDark => court.Palette.diamondOnDark;
  @override
  Color get clubOnDark => court.Palette.clubOnDark;

  @override
  String get displayFont => court.displayFont;
  @override
  String get bodyFont => court.bodyFont;
  @override
  List<Shadow> get feltShadow => court.feltShadow;
  @override
  TextStyle get taskText => court.taskTextStyle;

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
  TableLook get tableLook => const TableLook(
        style: TableStyle.rimmed,
        outerRule: Color(0xCCD4A63A),
        innerRule: Color(0x66D4A63A),
        panelRule: Color(0x99D4A63A),
        panelInnerRule: Color(0x66D4A63A),
      );

  @override
  PanelLook get panelLook => PanelLook(
        style: PanelStyle.ornate,
        court: const [Color(0xFF15583A), Color(0xFF0C3A25), Color(0xFF07291A)],
        won: [goldLight, gold, const Color(0xFFB98A24)],
        lost: const [Color(0xFF3A1218), Color(0xFF1C0A0E), Color(0xFF12080A)],
        courtMedallion: [const Color(0xFF1E6B47), feltDeep],
        wonMedallion: [goldPale, gold],
        lostMedallion: const [Color(0xFF5A1A22), Color(0xFF2A0E12)],
      );

  @override
  CardLook get cardLook => const CardLook(
        courtStyle: CourtCardStyle.emblems,
        cloth: [
          [Color(0xFF5A2F87), Color(0xFF241238)],
          [Color(0xFF13734A), Color(0xFF062A1B)],
          [Color(0xFF2849A8), Color(0xFF0B1A45)],
          [Color(0xFF9A1E31), Color(0xFF3A0610)],
        ],
        courtFrame: Color(0x99D4A63A),
        back: Color(0xFF5A1620),
        backEdge: Color(0xFFD4A63A),
        small: [Color(0xFF4A2670), Color(0xFF0F5B3A), Color(0xFF203C8C), Color(0xFF7E1828)],
        taskBack: [Color(0xFF7A1F2C), Color(0xFF3E0C14)],
      );

  @override
  Color get feltGlow => const Color(0xFF176141);

  @override
  TokenLook get tokenLook => const TokenLook();

  @override
  ButtonLook get buttonLook => const ButtonLook();

  @override
  ThemeData theme() => court.buildTheme();
}
