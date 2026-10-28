/// What the courtiers do on their turns, worked out from the game alone.
///
/// The page decides *when* a bot may act (not mid-animation, not while you
/// drag, not under a dialog) and *makes* the move through the table link;
/// this file decides *what* the move is. It touches nothing on screen, so
/// the same decisions can run on a server for empty seats in online play,
/// and can be tested without widgets.
library;

import '../engine/bot.dart';
import '../engine/cards.dart';
import '../engine/conflicts.dart';
import '../engine/decrees.dart';
import '../engine/round.dart';
import '../engine/rules.dart';
import '../engine/showing.dart';
import 'state.dart';

/// A move a courtier wants to make, or what the table is waiting on.
sealed class BotDecision {
  const BotDecision();
}

/// [seat] takes task [task] (or, under the King's Command, the King hands
/// it to [seat]).
class BotPicks extends BotDecision {
  const BotPicks(this.seat, this.task);
  final int seat;
  final int task;
}

/// [seat] passes on picking.
class BotPasses extends BotDecision {
  const BotPasses(this.seat);
  final int seat;
}

/// [seat] announces [x] tricks for task [task].
class BotAnnounces extends BotDecision {
  const BotAnnounces(this.seat, this.task, this.x);
  final int seat;
  final int task;
  final int x;
}

/// [seat] shows [card] with the speech token.
class BotShows extends BotDecision {
  const BotShows(this.seat, this.card);
  final int seat;
  final PlayingCard card;
}

/// [seat] plays [card].
class BotPlays extends BotDecision {
  const BotPlays(this.seat, this.card);
  final int seat;
  final PlayingCard card;
}

/// Nothing for a courtier to do: it's your announcement for task [task].
class YourAnnouncement extends BotDecision {
  const YourAnnouncement(this.task);
  final int task;
}

/// What a mode tells the courtiers: a card to play on a trick (the
/// tutorial's lessons script every trick, while the script holds), and
/// whether they show cards between tricks (the lessons keep to the point).
class CourtierScript {
  const CourtierScript({this.play, this.showsBetweenTricks = true});

  /// The card [seat] should play on trick [trick], or null to decide freely.
  final PlayingCard? Function(int trick, int seat)? play;
  final bool showsBetweenTricks;
}

/// The next move a courtier makes in [game]'s round, or null when it's a
/// person's move or there is nothing to do. [courtier] says which seats
/// the courtiers play here: every seat but [you]'s, unless given (a host
/// plays a dropped person's seat too). [script] is the mode's say over
/// the courtiers.
Future<BotDecision?> botDecision(GameState game, Bot bot,
    {int you = -1,
    bool Function(int seat)? courtier,
    CourtierScript script = const CourtierScript()}) async {
  final plays = courtier ?? (int seat) => seat != you;
  final r = game.round!;
  final picker = r.pickTurn;
  if (picker != null) {
    if (!plays(picker)) return null;
    final open = [
      for (var i = 0; i < r.tasks.length; i++)
        if (r.tasks[i].owner == null) i
    ];
    if (open.isEmpty) return null;
    if (r.decree == Decree.kingsCommand) {
      // The King hands every task to whoever is best placed for it.
      final i = open.first;
      final seats = [
        for (var s = 0; s < r.players; s++)
          if (r.mayTake(r.tasks[i], s)) s
      ];
      if (seats.isEmpty) return null;
      var best = seats.first;
      var bestScore = -1.0;
      for (final s in seats) {
        final assigned = {
          for (var t = 0; t < r.tasks.length; t++)
            if (r.tasks[t].owner != null) t: r.tasks[t].owner!,
          i: s,
        };
        final score = await bot.scoreAsync(r, picker, assigned, 120);
        if (score > bestScore) {
          bestScore = score;
          best = s;
        }
      }
      return BotPicks(best, i);
    }
    if (!open.any((i) => r.canTake(i, picker))) return null;
    // A courtier may show a card someone's task needs before picking.
    final shown = botShows(r, picker);
    if (shown != null) return BotShows(picker, shown);
    final pick = await bot.choosePickAsync(r, picker);
    // Nothing suits their hand: pass the pick on, once a round.
    // (Fair courtiers see only their own hand, so they rate every pick
    // lower than all-seeing ones did; the bar is set to match.)
    if (r.canPass(picker) && bot.lastPickScore < (bot.omniscient ? 0.12 : 0.04)) {
      return BotPasses(picker);
    }
    return BotPicks(picker, pick);
  }
  if (!r.allTaken) return null;
  // Numbers for the "exactly X tricks" tasks.
  for (var i = 0; i < r.tasks.length; i++) {
    final t = r.tasks[i];
    if (!needsX(t.description) || t.x != null) continue;
    if (!plays(t.owner!)) return YourAnnouncement(i);
    final x = await bot.chooseXAsync(r, t.owner!, i);
    return BotAnnounces(t.owner!, i, x);
  }
  // Between tricks, any courtier may show a card someone needs.
  if (r.current.isEmpty && script.showsBetweenTricks) {
    for (var s = 0; s < r.players; s++) {
      if (!plays(s)) continue;
      final shown = botShows(r, s);
      if (shown != null) return BotShows(s, shown);
    }
  }
  final turn = r.turn;
  if (!plays(turn)) return null;
  // A scripted courtier (a lesson's) follows the script while it holds.
  if (script.play?.call(r.tricks.length, turn) case final planned?
      when r.legalFor(turn).contains(planned)) {
    return BotPlays(turn, planned);
  }
  // Nothing to play (the hand is over, or a new deal is on its way).
  if (r.legalFor(turn).isEmpty) return null;
  return BotPlays(turn, await bot.choosePlayAsync(r, turn));
}

/// The card [seat] would show now, if they may: one that someone else's
/// task needs, once a round. Null when there's nothing to show.
PlayingCard? botShows(Round r, int seat) {
  if (r.spoke[seat] || !r.canSpeak(seat) || r.current.isNotEmpty) return null;
  // A task of its own that asks it to show a card comes first.
  final own = intendedShow(r, seat, [
    for (final t in r.tasks)
      if (t.owner == seat && t.isPending) t.description
  ]);
  if (own != null) return own;
  for (final card in r.hands[seat]) {
    if (r.revealFor(seat, card) == null) continue;
    final needed = r.tasks.any((t) =>
        t.isPending &&
        t.owner != null &&
        t.owner != seat &&
        neededCards(t.description).contains(card));
    if (needed) return card;
  }
  return null;
}
