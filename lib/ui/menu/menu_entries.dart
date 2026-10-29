/// What the menu offers, by where the player is.
library;

import 'package:flutter/material.dart';

import '../../platform/settings.dart';
import '../../platform/sfx.dart';
import '../../skin/strings.dart';
import 'menu.dart';

MenuEntry _item(String value, IconData icon, String title, {bool? on}) =>
    (value: value, icon: icon, title: title, on: on);

/// The menu's rows: a new game and a reshuffle when they make sense, the
/// rules, the view at a real table ([upright], or null on screen), sounds,
/// four-colour suits, the [look] worn, the keyboard shortcuts on a
/// computer ([keys], or null elsewhere), sharing play data, a bug
/// report, and in an online game, inviting someone to its room ([room],
/// its code) and leaving it.
List<MenuEntry> menuEntries({
  String? room,
  required bool newGame,
  required bool shuffle,
  required bool? upright,
  required String look,
  required bool? keys,
  required bool share,
}) =>
    [
      if (newGame) _item('new', Icons.group_add_outlined, Strings.newGame),
      if (shuffle) _item('shuffle', Icons.style_outlined, Strings.shuffleTasks),
      _item('rules', Icons.menu_book_outlined, Strings.howToPlay),
      if (upright != null)
        _item('upright', upright ? Icons.laptop_rounded : Icons.table_restaurant_outlined,
            upright ? Strings.laptopView : Strings.tableView),
      _item('sound', Sfx.enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          Strings.sounds,
          on: Sfx.enabled),
      // For colour-blind players: no two suits share a colour.
      _item('suits', Icons.palette_outlined, Strings.fourColourSuits,
          on: Settings.fourColourSuits),
      // The look worn; tapped, the next one owned.
      _item('skin', Icons.brush_outlined, Strings.look(look)),
      if (keys != null)
        _item('keys', Icons.keyboard_outlined, Strings.keyboardShortcuts, on: keys),
      // Rounds sent anonymously to help balance the game (How to Play says).
      _item('share', Icons.insights_outlined, Strings.sharePlayData, on: share),
      _item('bug', Icons.bug_report_outlined, Strings.reportBug),
      if (room != null) _item('invite', Icons.ios_share_rounded, Strings.inviteTo(room)),
      if (room != null) _item('leave', Icons.logout_rounded, Strings.leaveRoom),
    ];
