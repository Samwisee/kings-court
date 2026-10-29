/// Why a move isn't allowed in a round, and the round as one seat may
/// see it.
library;


import 'cards.dart';
import 'decrees.dart';
import 'round.dart';

extension RoundChecks on Round {
  /// Why [a] isn't allowed right now, or null if it is.
  String? problem(MatchAction a) {
    switch (a) {
      case PickTask(:final seat, :final task):
        if (task < 0 || task >= tasks.length) return 'No such task';
        if (seat < 0 || seat >= players) return 'No such seat';
        if (!hasCards) {
          // A real table: the phone keeps the tasks as the players share
          // them out, and a task may move from seat to seat.
          if (outcome != RoundOutcome.inProgress) return 'The round is over';
          return whyCantTake(tasks[task], seat);
        }
        if (phase != Phase.picking) return 'Tasks are not being picked';
        if (tasks[task].owner != null) return 'That task is taken';
        // Under the King's Command the King hands every task out.
        final kingsCommand = decree == Decree.kingsCommand && pickTurn == king;
        if (seat != pickTurn && !kingsCommand) return 'Not your turn to pick';
        return whyCantTake(tasks[task], seat);
      case ReturnTask(:final task):
        if (task < 0 || task >= tasks.length) return 'No such task';
        if (hasCards) return 'Tasks stay with whoever took them';
        if (tasks[task].owner == null) return 'That task is on the table';
      case Pass(:final seat):
        if (phase != Phase.picking) return 'Tasks are not being picked';
        if (seat != pickTurn) return 'Not your turn to pick';
        if (!canPass(seat)) return 'No passing now';
      case Announce(:final seat, :final task, :final x):
        if (phase != Phase.announcing) return 'Nothing to announce';
        if (task < 0 || task >= tasks.length) return 'No such task';
        if (tasks[task].owner != seat) return 'Not your task';
        if (x < 0 || x > totalTricks) return 'Not a possible number';
      case ShowCard(:final seat, :final card):
        if (!hasCards || seat >= hands.length) return 'No cards to show';
        if (spoke[seat]) return 'That card reveal is used this round';
        if (!canSpeak(seat)) return whyCantSpeak() ?? 'No cards may be shown now';
        if (revealFor(seat, card) == null) return 'That card can’t be shown';
      case PlayCard(:final seat, :final card):
        // A won round may play itself out; a lost one stops.
        if (!settled) return 'Not playing yet';
        if (outcome == RoundOutcome.lost) return 'The round is lost';
        if (tricks.length >= totalTricks) return 'Every card is played';
        if (seat != turn) return 'Not your turn';
        if (!legalFor(seat).contains(card)) {
          return 'You must follow ${led!.isCourt ? 'with a Court Card' : led!.suit.symbol}';
        }
    }
    return null;
  }

  /// How many cards [seat] holds: counted from their hand, or, in a view
  /// where their hand is hidden, as told.
  int cardsIn(int seat) =>
      handSizes != null && hands[seat].isEmpty ? handSizes![seat] : hands[seat].length;

  /// Whether [seat] still holds [card]: seen in their hand, or, in a view
  /// where their hand is hidden, not played yet.
  bool holds(int seat, PlayingCard card) => hands[seat].isNotEmpty
      ? hands[seat].contains(card)
      : handSizes != null &&
          !current.contains(card) &&
          !tricks.any((t) => t.cards.contains(card));

  /// The round as [seat] may see it: their own hand, how many cards the
  /// others hold, and everything public. (The cards set aside stay, so
  /// every device judges the tasks alike; a server judging for everyone
  /// could withhold them.) What goes to a device at that seat.
  Round visibleTo(int seat) {
    final v = Round.fromJson(toJson())
      ..names = names
      ..handSizes = [for (final h in hands) h.length];
    for (var s = 0; s < v.hands.length; s++) {
      if (s != seat) v.hands[s] = [];
    }
    return v;
  }
}
