/// The look comes from the skin (lib/skin): a widget reads it from its
/// context (`context.skin`) and names no colour, font, shadow or dialog
/// style of its own. Files not swept yet are listed in [unswept]; the list
/// only shrinks. The skins themselves agree on what they define.
library;

import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/skin/court/court_skin.dart';
import 'package:kings_court/skin/looks.dart';
import 'package:kings_court/skin/skin.dart';
import 'package:kings_court/skin/skins.dart';
import 'package:kings_court/skin/tailored.dart';

/// What a widget must not name: the Court skin's constants in theme.dart.
final named = RegExp(
    r'Palette\.|(?<![\w.])(displayFont|bodyFont|feltShadow|outlineColour|outlineWidth)\b|DialogStyle\.|buildTheme\(');

/// Files under lib/ui still naming the look, to be swept (step 7 of the
/// refactor); the list only shrinks.
const unswept = <String>{};

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

  test('The web loading screen knows every skin’s colours', () {
    // web/index.html draws the loading screen before the game runs, in the
    // look saved last time; its colours have to be the skins' own.
    final html = File('web/index.html').readAsStringSync();
    String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    for (final skin in skins) {
      final entry = RegExp('${skin.id}: \\{([^}]*)\\}').firstMatch(html);
      expect(entry, isNotNull, reason: 'add ${skin.id} to the looks in web/index.html');
      final values = entry!.group(1)!;
      expect(values, contains("table: '${hex(skin.table)}'"), reason: skin.id);
      expect(values, contains("glow: '${hex(skin.feltGlow)}'"), reason: skin.id);
      expect(values, contains("deep: '${hex(skin.feltDeep)}'"), reason: skin.id);
      expect(values, contains("gold: '${hex(skin.gold)}'"), reason: skin.id);
      expect(values, contains('rim: ${skin.tableLook.style == TableStyle.rimmed ? 1 : 0}'), reason: skin.id);
    }
  });
}
