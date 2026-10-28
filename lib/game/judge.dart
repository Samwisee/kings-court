/// What the table shows of a round's tricks, with no screen in it.
///
/// The round judges itself (engine/round.dart: [Round.judge]); these are
/// the views the table draws from while a trick still lies on the table,
/// before it's swept to its winner.
library;

import '../engine/cards.dart';
import '../engine/round.dart';
import '../engine/rules.dart';

/// The round as the table shows it: with [trickPending], a trick still
/// lying on the table doesn't count yet, so the tasks' tallies and
/// crossed-out cards change as the cards arrive.
RoundView shownView(Round r, {required bool trickPending}) {
  final pending = trickPending && r.tricks.isNotEmpty;
  return RoundView(
      players: r.players,
      king: r.king ?? r.leader,
      tricks: pending ? r.tricks.sublist(0, r.tricks.length - 1) : r.tricks,
      totalTricks: r.totalTricks,
      inPlay: r.inPlay,
      shown: r.revealed,
      shownAt: r.revealedAt);
}

/// The cards [t] names that its owner has already won, to cross out.
Set<String> wonNamed(Round r, RoundTask t, {required bool trickPending}) {
  final owner = t.owner;
  if (owner == null || t.description.startsWith("Don't")) return const {};
  final won = {
    for (final c in shownView(r, trickPending: trickPending).won(owner)) c.label
  };
  return {
    for (final m in RegExp('[A2-9][♥♦♠♣]').allMatches(t.description))
      if (won.contains(m.group(0))) m.group(0)!
  };
}

/// Tricks [seat] has won as the table shows them: a trick still on the
/// table ([lastTrick]) isn't counted yet.
int shownTricksWon(Round r, int seat, Trick? lastTrick) {
  final n = r.tricksWon(seat);
  return lastTrick != null && lastTrick.winner == seat ? n - 1 : n;
}
