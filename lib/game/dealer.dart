/// Dealing the cards of an on-screen round, with no screen in it.
///
/// The same game and round always deal the same cards (see
/// [GameState.seed]), so a round from a bug report can be dealt again, and
/// a server could deal the same hands. A deal that makes a task impossible
/// is tried again, and any task still impossible after that is swapped for
/// one that can be done.
library;

import 'dart:math';

import '../engine/cards.dart';
import '../engine/deal_mix.dart';
import '../engine/round.dart';
import '../engine/rules.dart';
import '../models.dart';

/// A deal fixed in advance (the tutorial's lessons), crowning [you].
typedef RiggedDeal = ({List<List<PlayingCard>> hands, List<PlayingCard> setAside});

/// Deals the round's cards when it has none yet (a new round, or a saved
/// game whose deal was never made). Returns true when it dealt. The table
/// then crowns whoever holds the King card ([Round.kingCardHolder]), unless
/// a King reigns already (a re-deal mid-round).
///
/// [you] is the seat this device plays from; a [rigged] deal (a tutorial
/// lesson's) is used as it is, with the King card in your hand.
bool dealRound(GameState game, {required int you, RiggedDeal? rigged}) {
  final r = game.round;
  if (!game.digital || r == null || r.tasks.isEmpty || r.hasCards) return false;
  final rand = game.dealRandom();
  r.dealFor(
    game.dealId,
    rand,
    king: r.king,
    accept: (hands, inPlay) => r.tasks.every((t) =>
        playableWith(t.description, hands, inPlay) &&
        stillPossible(r, t, hands, inPlay, you: you)),
  );
  // A lesson deals the same cards every time, with you as King.
  if (rigged != null) {
    r.hands = rigged.hands;
    r.setAside = rigged.setAside;
    r.leader = you;
    return true;
  }
  // Any task the deal still makes impossible is swapped for one that can
  // be done.
  final n = r.players;
  for (var i = 0; i < r.tasks.length; i++) {
    final t = r.tasks[i];
    if (t.owner != null || stillPossible(r, t, r.hands, r.inPlay, you: you)) {
      continue;
    }
    final names = r.tasks.map((x) => x.description).toSet();
    final swap = (List.of(GameState.taskPool)..shuffle(rand)).where((p) =>
        !names.contains(p.description) &&
        !needsX(p.description) &&
        p.getPointsForPlayerCount(n) <= t.points(n) + 1 &&
        fitsDeal([for (final o in r.tasks) if (o != t) o.description],
            p.description, max(3, n)) &&
        playableWith(p.description, r.hands, r.inPlay) &&
        stillPossible(r, RoundTask(p), r.hands, r.inPlay, you: you)).firstOrNull;
    if (swap != null) r.tasks[i] = RoundTask(swap, seal: t.seal);
  }
  return true;
}

/// Whether [t] could still be done by someone allowed to take it, with
/// these cards in play: no task should be lost before the first trick.
bool stillPossible(Round r, RoundTask t, List<List<PlayingCard>> hands,
    Set<PlayingCard> inPlay,
    {required int you}) {
  if (needsX(t.description) || hands.isEmpty || hands.first.isEmpty) return true;
  final v = RoundView(
      players: hands.length,
      king: r.king ?? you,
      tricks: const [],
      totalTricks: hands.first.length,
      inPlay: inPlay);
  final rule = taskRules[t.description]!;
  return [
    for (var s = 0; s < hands.length; s++)
      if (t.owner == s || r.mayTake(t, s)) s
  ].any((s) {
    try {
      return rule(v, s, null) != Verdict.failed;
    } catch (_) {
      return true;
    }
  });
}
