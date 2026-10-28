/// The look comes from the skin (lib/skin): a widget reads it from its
/// context (`context.skin`) and names no colour, font, shadow or dialog
/// style of its own. Files not swept yet are listed in [unswept]; the list
/// only shrinks. The skins themselves agree on what they define.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/skin/court/court_skin.dart';
import 'package:kings_court/skin/skin.dart';

/// What a widget must not name: the Court skin's constants in theme.dart.
final named = RegExp(
    r'Palette\.|(?<![\w.])(displayFont|bodyFont|feltShadow|outlineColour|outlineWidth)\b|DialogStyle\.|buildTheme\(');

/// Files under lib/ui still naming the look, to be swept (step 7 of the
/// refactor); the list only shrinks.
const unswept = {
  'lib/ui/cards/card_view.dart',
  'lib/ui/cards/mini_card.dart',
  'lib/ui/cards/task_chip.dart',
  'lib/ui/dialogs/courtier_card.dart',
  'lib/ui/dialogs/table_dialogs.dart',
  'lib/ui/dialogs/task_close_up.dart',
  'lib/ui/dynasty/contest_table.dart',
  'lib/ui/dynasty/hall_pieces.dart',
  'lib/ui/dynasty/throne_room.dart',
  'lib/ui/menu/menu.dart',
  'lib/ui/modes/tutorial/coach.dart',
  'lib/ui/modes/tutorial/tutorial_intro.dart',
  'lib/ui/overlays/crowning.dart',
  'lib/ui/overlays/king_prompt.dart',
  'lib/ui/overlays/outcome_card.dart',
  'lib/ui/overlays/play_flourish.dart',
  'lib/ui/rules/rules_page.dart',
  'lib/ui/setup/chapter_picker.dart',
  'lib/ui/setup/setup_panel.dart',
  'lib/ui/setup/transitions.dart',
  'lib/ui/table_page.dart',
  'lib/ui/tracker/card_tracker.dart',
  'lib/ui/welcome/welcome.dart',
  'lib/ui/widgets/buttons.dart',
  'lib/ui/widgets/candles.dart',
  'lib/ui/widgets/character_token.dart',
  'lib/ui/widgets/court_dialog.dart',
  'lib/ui/widgets/house_banner.dart',
  'lib/ui/widgets/icons.dart',
  'lib/ui/widgets/panels.dart',
  'lib/ui/widgets/pips.dart',
  'lib/ui/widgets/seals.dart',
  'lib/ui/widgets/suit_text.dart',
  'lib/ui/widgets/table.dart',
  'lib/ui/widgets/task_card.dart',
  'lib/ui/widgets/tokens.dart',
};

void main() {
  final files = Directory('lib/ui')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('No swept file under lib/ui names the look', () {
    final naming = <String>[];
    for (final f in files) {
      if (unswept.contains(f.path)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final m = named.firstMatch(lines[i]);
        if (m != null) naming.add('${f.path}:${i + 1}: ${m.group(0)}');
      }
    }
    expect(naming, isEmpty, reason: 'Read it from context.skin instead');
  });

  test('Every unswept file still names the look (else take it off the list)', () {
    for (final path in unswept) {
      final f = File(path);
      expect(f.existsSync(), isTrue, reason: '$path is gone: take it off the list');
      expect(named.hasMatch(f.readAsStringSync()), isTrue,
          reason: '$path is swept: take it off the list');
    }
  });

  test('A skin defines the whole look', () {
    const Skin skin = CourtSkin();
    expect(skin.id, 'court');
    expect(skin.players, hasLength(6));
    expect(skin.theme().colorScheme.primary, skin.gold);
    expect(skin.dialogTitle.fontFamily, skin.displayFont);
    expect(skin.theme().textTheme.bodyMedium?.fontFamily ?? skin.bodyFont, skin.bodyFont);
  });
}
