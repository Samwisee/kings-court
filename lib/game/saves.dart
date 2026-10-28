/// The shape saves are written in, and how older ones are brought up to
/// date. A save from an older version is upgraded one step at a time by
/// [upgradeSave] before it's read, so each change to the format is one
/// migration here:
///
/// 1. before the refactor: the round's tasks, King, picks and so on
///    beside the game, and the on-screen cards apart under `cards`;
/// 2. the round is one record under `round`.
library;

import '../engine/round.dart';
import '../engine/rules.dart';
import 'state.dart';

/// The version saves are written in.
const saveVersion = 2;

/// [saved] in the current shape: each migration from its version on,
/// in turn. A save with no version is from before versions (1).
Map<String, dynamic> upgradeSave(Map<String, dynamic> saved) {
  var j = saved;
  var version = (j['version'] as int?) ?? 1;
  while (version < saveVersion) {
    j = _migrations[version]!(j);
    version++;
  }
  return j;
}

/// From each version to the next.
const _migrations = <int, Map<String, dynamic> Function(Map<String, dynamic>)>{
  1: _v1ToV2,
};

/// Version 1 kept the round's tasks, King, picks, seals and decree
/// beside the game, and the on-screen cards apart under `cards` (with
/// their own tasks, announced numbers and shown cards); the round
/// number was `round`. Version 2 has the round as one record.
Map<String, dynamic> _v1ToV2(Map<String, dynamic> j) {
  final players = (j['players'] as List?)?.length ?? 0;
  final dealId = j['dealId'] as int;
  final tutorial = j['mode'] == GameMode.tutorial.index;
  final tasks = [
    for (final t in (j['tasks'] as List<dynamic>).cast<Map<String, dynamic>>())
      RoundTask.fromJson(t).toJson()
  ];
  // The cards, if they were dealt for this very deal.
  final raw = j['cards'];
  final cards = raw is Map && raw['dealId'] == dealId
      ? Map<String, dynamic>.from(raw)
      : null;
  if (cards != null) {
    final announced = (cards['announced'] as Map?) ?? const {};
    for (final t in tasks) {
      if (announced[t['d']] case final int x) t['x'] = x;
    }
  }
  final open = tasks.any((t) => t['owner'] == null);
  final failed = tasks.any((t) => t['status'] == TaskStatus.failed.index);
  final done = tasks.every((t) => t['status'] == TaskStatus.completed.index);
  final unannounced = tasks.any((t) => needsX(t['d'] as String) && t['x'] == null);
  final phase = failed || done
      ? Phase.roundOver
      : open
          ? Phase.picking
          : unannounced
              ? Phase.announcing
              : Phase.playing;
  final round = <String, dynamic>{
    'players': players,
    'target': (j['target'] as int?) ?? 5,
    'hands': cards?['hands'] ?? const <dynamic>[],
    'setAside': cards?['setAside'] ?? const <dynamic>[],
    'king': j['king'],
    'tasks': tasks,
    'pickTurn': j['pickTurn'],
    'passed': j['passed'] ?? const <dynamic>[],
    if (j['spoke'] case final List<dynamic> spoke when spoke.length == players)
      'spoke': spoke,
    'picksMade': 0,
    'sealCount': j['sealCount'] ?? 0,
    'decree': j['decree'],
    'exiled': j['exiled'],
    'passing': !tutorial,
    'tricks': cards?['tricks'] ?? const <dynamic>[],
    'leader': cards?['leader'] ?? 0,
    'currentSeats': cards?['currentSeats'] ?? const <dynamic>[],
    'current': cards?['current'] ?? const <dynamic>[],
    'phase': phase.index,
    'dealId': dealId,
    'revealed': cards?['revealed'] ?? const <String, dynamic>{},
    'revealHint': cards?['revealHint'] ?? const <String, dynamic>{},
    'revealedAt': cards?['revealedAt'] ?? const <String, dynamic>{},
  };
  return {
    ...j,
    'version': 2,
    'digital': j['cards'] != null,
    'round': round,
    'roundNumber': j['round'],
  }
    ..remove('tasks')
    ..remove('cards')
    ..remove('king')
    ..remove('pickTurn')
    ..remove('passed')
    ..remove('spoke')
    ..remove('sealCount')
    ..remove('decree')
    ..remove('exiled');
}
