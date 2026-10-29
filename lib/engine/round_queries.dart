/// What a round allows: who may take a task, show a card, or pass, and
/// whose pick is next. Asked of a [Round]; changes nothing.
library;

import 'dart:math';

import 'cards.dart';
import 'conflicts.dart';
import 'decrees.dart';
import 'round.dart';

extension RoundQueries on Round {
  /// What may be said about [card] in [seat]'s hand, or null if it can't
  /// be shown (Court Cards, or a card in the middle of its suit).
  String? revealFor(int seat, PlayingCard card) {
    if (card.isCourt || !hands[seat].contains(card)) return null;
    final suit = hands[seat].where((c) => c.suit == card.suit).toList();
    if (suit.length == 1) return 'only';
    final ranks = suit.map((c) => c.rank);
    if (card.rank == ranks.reduce((a, b) => a > b ? a : b)) return 'highest';
    if (card.rank == ranks.reduce((a, b) => a < b ? a : b)) return 'lowest';
    return null;
  }

  /// Whether [seat] may take task [i], which nobody holds yet.
  bool canTake(int i, int seat) =>
      tasks[i].owner == null && whyCantTake(tasks[i], seat) == null;

  /// Whether [seat] may hold [t] (taken or not).
  bool mayTake(RoundTask t, int seat) => whyCantTake(t, seat) == null;

  /// Why [seat] can't hold [t], or null if they can. With [publicOnly],
  /// nobody's hand is consulted: only what the whole table can see.
  String? whyCantTake(RoundTask t, int seat, {bool publicOnly = false}) {
    if (seat == exiledSeat) return 'Exiled: no tasks this round';
    if (t.task.kingCantTake && seat == king) {
      return "The King can't take this task";
    }
    // Someone can't hold two tasks that work against each other.
    for (final o in tasks) {
      if (o != t &&
          o.owner == seat &&
          selfClash(o.description, t.description, players: players)) {
        return 'That clashes with a task they already hold';
      }
    }
    // On screen the app knows every hand: no task someone's cards make
    // impossible for them (unless nobody else could take it either).
    if (!publicOnly && hasCards && seat < hands.length) {
      final why = handBlocks(t.description, hands[seat]);
      if (why != null) {
        final someoneElse = [
          for (var s = 0; s < players && s < hands.length; s++)
            if (s != seat &&
                s != exiledSeat &&
                !(t.task.kingCantTake && s == king) &&
                handBlocks(t.description, hands[s]) == null)
              s
        ].isNotEmpty;
        if (someoneElse) return why;
      }
    }
    return null;
  }

  /// Whether [seat] may reveal a card right now, given the decree. Late
  /// Counsel holds every card back until three tricks have been played
  /// (on screen, where the app sees the tricks; at a real table the
  /// players keep to it themselves).
  bool canSpeak(int seat) => switch (decree) {
        Decree.silence => false,
        Decree.lateCounsel => !hasCards || tricks.length >= 3,
        _ => true,
      };

  /// Why no card may be shown now, or null if one may.
  String? whyCantSpeak() => switch (decree) {
        Decree.silence => 'Silence is decreed: no cards may be shown this round',
        Decree.lateCounsel when !canSpeak(0) =>
          'Late Counsel: no cards may be shown until three tricks have been played',
        _ => null,
      };

  /// Why completing [t] now would break the seal order, or null if it's
  /// fine. Completing a task out of order fails the round.
  String? sealProblem(RoundTask t) {
    final seal = t.seal;
    if (seal == null) return null;
    if (seal == Seals.last) {
      final open = tasks.where((o) => o != t && !o.isCompleted);
      return open.isEmpty
          ? null
          : 'The Ω seal must be the last task done, and ${open.length} '
              'other task${open.length == 1 ? ' is' : 's are'} still open.';
    }
    final earlier = tasks.where((o) =>
        o.seal != null && o.seal != Seals.last && o.seal! < seal && !o.isCompleted);
    if (earlier.isEmpty) return null;
    final first = earlier.map((o) => o.seal!).reduce(min);
    return 'Seal ${Seals.label(first)} must be done before seal ${Seals.label(seal)}.';
  }

  /// Whether [seat] may pass on picking a task right now: the round allows
  /// it, it's their turn, they haven't passed this round, and someone else
  /// could pick instead.
  bool canPass(int seat) =>
      passing &&
      pickTurn == seat &&
      decree != Decree.kingsCommand &&
      !passed.contains(seat) &&
      tasks.any((t) => t.owner == null) &&
      nextPicker(seat) != seat;

  /// The next seat clockwise after [from] that may pick a task: skipping
  /// anyone who can't take any of the tasks left, then anyone exiled.
  int? nextPicker(int from) {
    for (var step = 1; step <= players; step++) {
      final seat = (from + step) % players;
      if (seat != exiledSeat &&
          tasks.any((t) => t.owner == null && whyCantTake(t, seat) == null)) {
        return seat;
      }
    }
    for (var step = 1; step <= players; step++) {
      final seat = (from + step) % players;
      if (seat != exiledSeat) return seat;
    }
    return null;
  }
}
