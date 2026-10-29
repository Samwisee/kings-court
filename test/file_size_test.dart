/// No file under lib/ is over about 600 lines: a bigger one is doing more
/// than one job and wants splitting. Generated art and the task data are
/// as long as they need to be ([data]). The code still over the line is
/// listed in [debts] with the most lines it may have; the number only goes
/// down, and a file that drops under the line comes off the list.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const limit = 600;

/// Generated art and data: not code to split.
const data = {
  'lib/skin/court/emblems.g.dart',
  'lib/skin/court/suits.g.dart',
  'lib/engine/tasks.dart',
  'lib/engine/task_help.dart',
  'lib/engine/rules.dart',
  'lib/modes/chronicle/chapters.dart',
  'lib/modes/tutorial/lessons.dart',
  'lib/modes/dynasty/data/dilemmas.dart',
  'lib/modes/dynasty/data/lines.dart',
  'lib/modes/dynasty/data/story.dart',
};

/// Code over the line today, and the most lines it may have.
const debts = {
  // The page: what's left of the one big state after the split (see
  // docs/ARCHITECTURE.md, "What's still on the page").
  'lib/ui/table_page.dart': 3866,
  // The record of a round: its JSON, picks and judging could be
  // extensions once its private helpers are shared.
  'lib/engine/round.dart': 960,
  // One stateful panel with five steps.
  'lib/ui/setup/setup_panel.dart': 870,
};

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('No file under lib/ is over $limit lines, apart from data and the debts', () {
    final over = <String>[];
    for (final f in files) {
      if (data.contains(f.path)) continue;
      final lines = f.readAsLinesSync().length;
      final allowed = debts[f.path] ?? limit;
      if (lines > allowed) over.add('${f.path}: $lines lines (allowed $allowed)');
    }
    expect(over, isEmpty, reason: 'Split the file, or (for now) list it in debts');
  });

  test('Every debt is real, and the list only shrinks', () {
    for (final e in debts.entries) {
      final f = File(e.key);
      expect(f.existsSync(), isTrue, reason: '${e.key} is gone: take it off the list');
      final lines = f.readAsLinesSync().length;
      expect(lines, greaterThan(limit),
          reason: '${e.key} is under the line now: take it off the list');
      expect(e.value, greaterThan(limit));
    }
    for (final d in data) {
      expect(File(d).existsSync(), isTrue, reason: '$d is gone: take it off the list');
    }
  });
}
