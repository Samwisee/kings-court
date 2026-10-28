/// Plays a bug report again from its setup and moves, and says whether
/// that reaches the state the report carried:
///
///     REPORT=path/to/report.json flutter test test/tool/replay_report_test.dart
///
/// The report is what the game's bug dialog sends (or copies): a JSON
/// object with `setup`, `moves` and `state`.
@Tags(['tool'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/modes/modes.dart';
import 'package:kings_court/net/replay.dart';

void main() {
  test('The report plays again to the state it carried', () {
    final path = Platform.environment['REPORT'];
    if (path == null) {
      // Tool run: nothing to replay.
      // ignore: avoid_print
      print('Set REPORT=path/to/report.json');
      return;
    }
    final report = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final result = replayReport(report, rulesFor: (m) => modeOf(m).rules);
    expect(result, isNotNull, reason: 'the report has no setup to start from');
    // The verdict, for the person running the tool.
    // ignore: avoid_print
    print('${result!.verdict}; ${result.skipped.length} moves skipped');
    expect(result.matches, isTrue, reason: result.verdict);
  });
}
