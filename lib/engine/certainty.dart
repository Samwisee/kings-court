/// Whether a round is already won, whatever is played from here: every
/// task still open would be done however the remaining cards fall. Then
/// the table can play the rest out on its own.
library;

import 'cards.dart';
import 'rules.dart';

/// A task still to be decided: its wording, who holds it, and the number
/// announced for "exactly X" tasks.
typedef OpenTask = ({String description, int owner, int? x});

/// True when every way of playing out the round, from the start of a trick,
/// leaves every task in [open] done. Searches every legal play, giving up
/// (false) after [budget] plays: false means "not known to be certain".
bool roundCertain({
  required List<List<PlayingCard>> hands,
  required List<Trick> tricks,
  required int leader,
  required int players,
  required int king,
  required int totalTricks,
  required Set<PlayingCard> inPlay,
  required List<OpenTask> open,
  int budget = 60000,
}) {
  if (open.isEmpty || tricks.length >= totalTricks) return false;
  var spent = 0;
  final played = [...tricks];

  /// null when the budget ran out.
  bool? settled() {
    final v = RoundView(
        players: players,
        king: king,
        tricks: played,
        totalTricks: totalTricks,
        inPlay: inPlay);
    var allDone = true;
    for (final t in open) {
      final rule = taskRules[t.description];
      if (rule == null) return false;
      final verdict = rule(v, t.owner, t.x);
      if (verdict == Verdict.failed) return false;
      if (verdict != Verdict.done) allDone = false;
    }
    if (allDone) return true;
    if (v.over) return false;
    return null; // still open: play on
  }

  // Plays out the trick led by [lead], seat by seat; true if every way
  // through it (and on to the end) leaves every task done.
  bool? trick(int lead) {
    final seats = <int>[];
    final cards = <PlayingCard>[];
    bool? seat(int i) {
      if (i == players) {
        final w = seats[winningPlay(cards)];
        played.add(Trick(lead, [...seats], [...cards], w));
        final s = settled();
        final result = s ?? trick(w);
        played.removeLast();
        return result;
      }
      final who = (lead + i) % players;
      final hand = hands[who];
      for (final c in legalPlays(hand, cards.isEmpty ? null : cards.first)) {
        if (++spent > budget) return false;
        hand.remove(c);
        seats.add(who);
        cards.add(c);
        final r = seat(i + 1);
        cards.removeLast();
        seats.removeLast();
        hand.add(c);
        if (r != true) return false;
      }
      return true;
    }

    return seat(0);
  }

  // Work on copies: the search moves cards in and out of hands.
  final saved = [for (final h in hands) [...h]];
  try {
    return trick(leader) ?? false;
  } finally {
    for (int i = 0; i < hands.length; i++) {
      hands[i]
        ..clear()
        ..addAll(saved[i]);
    }
  }
}
