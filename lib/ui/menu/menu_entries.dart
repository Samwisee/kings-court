/// What the menu offers, by where the player is.
library;

import 'package:flutter/material.dart';

import '../../platform/settings.dart';
import '../../platform/sfx.dart';
import '../../skin/strings.dart';
import 'menu.dart';

MenuEntry _item(String value, IconData icon, String title, {bool? on}) =>
    (value: value, icon: icon, title: title, on: on);

/// The menu's rows: back to the main menu (in a game) and a bug report
/// first; a reshuffle when it makes sense, the rules, the view at a real
/// table ([upright], or null on screen), the [look] worn (its dialog);
/// then the switches: sounds, four-colour suits, the keyboard shortcuts on
/// a computer ([keys], or null elsewhere), sharing play data; and in an
/// online game, inviting someone to its room ([room], its code) and
/// leaving it.
List<MenuEntry> menuEntries({
  String? room,
  required bool mainMenu,
  required bool shuffle,
  required bool? upright,
  required String look,
  required bool? keys,
  required bool share,
}) =>
    [
      if (mainMenu) _item('main', Icons.home_outlined, Strings.mainMenu),
      _item('bug', Icons.bug_report_outlined, Strings.reportBug),
      if (shuffle) _item('shuffle', Icons.style_outlined, Strings.shuffleTasks),
      _item('rules', Icons.menu_book_outlined, Strings.howToPlay),
      if (upright != null)
        _item('upright', upright ? Icons.laptop_rounded : Icons.table_restaurant_outlined,
            upright ? Strings.laptopView : Strings.tableView),
      // The look worn; tapped, the Look dialog.
      _item('skin', Icons.brush_outlined, Strings.look(look)),
      _item('sound', Sfx.enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          Strings.sounds,
          on: Sfx.enabled),
      // For colour-blind players: no two suits share a colour.
      _item('suits', Icons.palette_outlined, Strings.fourColourSuits,
          on: Settings.fourColourSuits),
      if (keys != null)
        _item('keys', Icons.keyboard_outlined, Strings.keyboardShortcuts, on: keys),
      // Rounds sent anonymously to help balance the game (How to Play says).
      _item('share', Icons.insights_outlined, Strings.sharePlayData, on: share),
      if (room != null) _item('invite', Icons.ios_share_rounded, Strings.inviteTo(room)),
      if (room != null) _item('leave', Icons.logout_rounded, Strings.leaveRoom),
    ];
