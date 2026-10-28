/// The code is in layers, and dependencies only point down:
///
///   engine → game → net → modes → platform → skin → ui → main.dart
///
/// Each folder under lib/ may import only itself and the layers before it
/// in that list. The first four are plain Dart: no Flutter, no plugins, so
/// the rules, the game and the moves can run on a server as they are.
///
/// Files that haven't moved into a layer folder yet are mapped to the
/// layer they belong to in [legacy]; the map shrinks as they move. Imports
/// that point the wrong way today are listed in [knownDebts] with the fix
/// planned; the list only shrinks, and a new one fails this test.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const layers = ['engine', 'game', 'net', 'modes', 'platform', 'skin', 'ui'];

/// Layers with no Flutter in them.
const pure = {'engine', 'game', 'net', 'modes'};

/// Files not yet in their layer's folder.
const legacy = {
  'lib/tasks.dart': 'engine',
  'lib/task_help.dart': 'engine',
  'lib/models.dart': 'game',
  'lib/chronicle.dart': 'modes',
  'lib/courtiers.dart': 'modes',
  'lib/story.dart': 'modes',
  'lib/tutorial.dart': 'modes',
  'lib/sfx.dart': 'platform',
  'lib/analytics.dart': 'platform',
  'lib/crash_reports.dart': 'platform',
  'lib/build_info.dart': 'platform',
  'lib/theme.dart': 'skin',
  'lib/bug_report.dart': 'ui',
  'lib/widgets.dart': 'ui',
  'lib/main.dart': 'ui',
};

/// Old folders that are all UI.
const legacyFolders = {'home': 'ui', 'play': 'ui'};

/// Imports pointing the wrong way today, and the step that fixes them.
const knownDebts = {
  // Decrees and seals become engine rules; courtiers' roles move to game;
  // the tutorial's scripts reach the bots through an interface (step 4).
  'lib/models.dart → lib/chronicle.dart',
  'lib/models.dart → lib/courtiers.dart',
  'lib/models.dart → lib/tutorial.dart',
  'lib/game/bot_turn.dart → lib/chronicle.dart',
  'lib/game/bot_turn.dart → lib/tutorial.dart',
  // The controller is Flutter and belongs in ui/ (step 3).
  'lib/game/controller.dart → package:flutter/foundation.dart',
  'lib/game/controller.dart → package:shared_preferences/shared_preferences.dart',
  'lib/game/controller.dart → lib/net/table_link.dart',
};

/// Packages that mean Flutter or a plugin.
const flutterPackages = [
  'package:flutter',
  'package:sentry',
  'package:shared_preferences',
  'package:audioplayers',
  'package:wakelock',
  'package:http',
  'dart:ui',
];

String? layerOf(String path) {
  if (legacy.containsKey(path)) return legacy[path];
  final parts = path.split('/');
  if (parts.length > 2) {
    if (layers.contains(parts[1])) return parts[1];
    if (legacyFolders.containsKey(parts[1])) return legacyFolders[parts[1]];
  }
  return null;
}

final directive = RegExp(r"^\s*(?:import|export|part)\s+'([^']+)'");

/// What's wrong with [from] importing [target], or null if nothing.
String? problemWith(String from, String target) {
  if (target.startsWith('dart:') || target.startsWith('package:')) {
    if (pure.contains(from) && flutterPackages.any(target.startsWith)) {
      return '$from is plain Dart, but imports $target';
    }
    return null;
  }
  final to = layerOf(target);
  if (to == null) return '$target is in no layer';
  if (layers.indexOf(to) > layers.indexOf(from)) {
    return '$from may not import $to';
  }
  return null;
}

/// The imported path as lib/..., or the package as written.
String resolved(File from, String target) {
  if (target.startsWith('dart:') || target.startsWith('package:')) return target;
  final path = Uri.directory(from.parent.path).resolve(target).toFilePath();
  return path.substring(path.indexOf('lib/'));
}

Iterable<File> get libFiles => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('Every file under lib/ belongs to a layer', () {
    final unmapped = [for (final f in libFiles) if (layerOf(f.path) == null) f.path];
    expect(unmapped, isEmpty, reason: 'Put the file in a layer folder, or map it in legacy');
  });

  test('Dependencies only point down the layers, and the lower ones are plain Dart', () {
    final wrong = <String>[];
    final seenDebts = <String>{};
    for (final f in libFiles) {
      final from = layerOf(f.path);
      if (from == null) continue;
      for (final line in f.readAsLinesSync()) {
        final m = directive.firstMatch(line);
        if (m == null) continue;
        final target = resolved(f, m.group(1)!);
        final problem = problemWith(from, target);
        if (problem == null) continue;
        final key = '${f.path} → $target';
        if (knownDebts.contains(key)) {
          seenDebts.add(key);
        } else {
          wrong.add('$key ($problem)');
        }
      }
    }
    expect(wrong, isEmpty, reason: 'An import points the wrong way');
    expect(knownDebts.difference(seenDebts), isEmpty,
        reason: 'A debt was paid: take it off the list');
  });
}
