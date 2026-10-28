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
import '../engine/rules.dart';
import '../models.dart';

/// A deal fixed in advance (the tutorial's lessons), crowning [you].
typedef RiggedDeal = ({List<List<PlayingCard>> hands, List<PlayingCard> setAside});

/// Deals the round's cards when they're out of date (a new round, or a
/// saved game whose deal was never made). Returns true when it dealt.
///
/// [you] is the seat this device plays from; a [rigged] deal (a tutorial
/// lesson's) is used as it is, with you as King.
bool dealRound(GameState game, {required int you, RiggedDeal? rigged}) {
  final c = game.cards;
  if (c == null || game.tasks.isEmpty || c.dealId == game.dealId) return false;
  final rand = game.dealRandom();
  c.dealFor(
    game.dealId,
    rand,
    king: game.kingIndex,
    accept: (hands, inPlay) => game.tasks.every((t) =>
        playableWith(t.description, hands, inPlay) &&
        stillPossible(game, t, hands, inPlay, you: you)),
  );
  // A lesson deals the same cards every time, with you as King.
  if (rigged != null) {
    c.hands = rigged.hands;
    c.setAside = rigged.setAside;
    c.king = you;
    c.leader = you;
    return true;
  }
  // Any task the deal still makes impossible is swapped for one that can
  // be done.
  final n = game.players.length;
  for (var i = 0; i < game.tasks.length; i++) {
    final t = game.tasks[i];
    if (t.assignedPlayerIndex != null ||
        stillPossible(game, t, c.hands, c.inPlay, you: you)) {
      continue;
    }
    final names = game.tasks.map((x) => x.description).toSet();
    final swap = (List.of(GameState.taskPool)..shuffle(rand)).where((p) =>
        !names.contains(p.description) &&
        !needsX(p.description) &&
        p.getPointsForPlayerCount(n) <= t.getPointsForPlayerCount(n) + 1 &&
        fitsDeal([for (final o in game.tasks) if (o != t) o.description],
            p.description, max(3, n)) &&
        playableWith(p.description, c.hands, c.inPlay) &&
        stillPossible(game, p, c.hands, c.inPlay, you: you)).firstOrNull;
    if (swap != null) game.tasks[i] = swap.freshCopy()..seal = t.seal;
  }
  return true;
}

/// Whether [t] could still be done by someone allowed to take it, with
/// these cards in play: no task should be lost before the first trick.
bool stillPossible(GameState game, Task t, List<List<PlayingCard>> hands,
    Set<PlayingCard> inPlay,
    {required int you}) {
  if (needsX(t.description) || hands.isEmpty || hands.first.isEmpty) return true;
  final v = RoundView(
      players: hands.length,
      king: game.kingIndex ?? you,
      tricks: const [],
      totalTricks: hands.first.length,
      inPlay: inPlay);
  final rule = taskRules[t.description]!;
  return [
    for (var s = 0; s < hands.length; s++)
      if (t.assignedPlayerIndex == s || game.canTake(t, s)) s
  ].any((s) {
    try {
      return rule(v, s, null) != Verdict.failed;
    } catch (_) {
      return true;
    }
  });
}
