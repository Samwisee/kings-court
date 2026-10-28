/// What the courtiers do on their turns, worked out from the game alone.
///
/// The page decides *when* a bot may act (not mid-animation, not while you
/// drag, not under a dialog) and *makes* the move through the table link;
/// this file decides *what* the move is. It touches nothing on screen, so
/// the same decisions can run on a server for empty seats in online play,
/// and can be tested without widgets.
library;

import '../chronicle.dart';
import '../engine/bot.dart';
import '../engine/cards.dart';
import '../engine/match.dart';
import '../engine/conflicts.dart';
import '../engine/rules.dart';
import '../engine/showing.dart';
import '../models.dart';
import '../tutorial.dart';

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

/// The next move a courtier makes in [game], seen through [view] (the
/// cards with this table's tasks and rules), or null when it's your move
/// or there is nothing to do. [you] is the seat the player sits in.
Future<BotDecision?> botDecision(GameState game, MatchState view, Bot bot,
    {required int you}) async {
  final picker = game.pickTurn;
  if (picker != null) {
    if (picker == you) return null;
    final open = [
      for (int i = 0; i < game.tasks.length; i++)
        if (game.tasks[i].assignedPlayerIndex == null) i
    ];
    if (open.isEmpty) return null;
    if (game.decree == Decree.kingsCommand) {
      // The King hands every task to whoever is best placed for it.
      final i = open.first;
      final seats = [
        for (int s = 0; s < game.players.length; s++)
          if (game.canTake(game.tasks[i], s)) s
      ];
      if (seats.isEmpty) return null;
      int best = seats.first;
      double bestScore = -1;
      for (final s in seats) {
        final assigned = {
          for (int t = 0; t < game.tasks.length; t++)
            if (game.tasks[t].assignedPlayerIndex != null)
              t: game.tasks[t].assignedPlayerIndex!,
          i: s,
        };
        final score = await bot.scoreAsync(view, picker, assigned, 120);
        if (score > bestScore) {
          bestScore = score;
          best = s;
        }
      }
      return BotPicks(best, i);
    }
    if (!open.any((i) => view.canTake(i, picker))) return null;
    // A courtier may show a card someone's task needs before picking.
    final shown = botShows(game, view, picker);
    if (shown != null) return BotShows(picker, shown);
    final pick = await bot.choosePickAsync(view, picker);
    // Nothing suits their hand: pass the pick on, once a round.
    if (game.canPass(picker) && bot.lastPickScore < 0.12) {
      return BotPasses(picker);
    }
    return BotPicks(picker, pick);
  }
  if (game.tasks.any((t) => t.assignedPlayerIndex == null)) return null;
  // Numbers for the "exactly X tricks" tasks.
  for (int i = 0; i < game.tasks.length; i++) {
    final t = game.tasks[i];
    if (!needsX(t.description) || view.announced.containsKey(t.description)) {
      continue;
    }
    if (t.assignedPlayerIndex == you) return YourAnnouncement(i);
    final x = await bot.chooseXAsync(view, t.assignedPlayerIndex!, i);
    return BotAnnounces(t.assignedPlayerIndex!, i, x);
  }
  // Between tricks, any courtier may show a card someone needs.
  if (view.current.isEmpty && !game.isTutorial) {
    for (int s = 0; s < game.players.length; s++) {
      if (s == you) continue;
      final shown = botShows(game, view, s);
      if (shown != null) return BotShows(s, shown);
    }
  }
  final turn = view.turn;
  if (turn == you) return null;
  // The tutorial's courtiers follow the lesson's script while it holds.
  if (game.isTutorial) {
    final planned = lessons[game.lesson].scripted(view.tricks.length, turn);
    if (planned != null && view.legalFor(turn).contains(planned)) {
      return BotPlays(turn, planned);
    }
  }
  // Nothing to play (the hand is over, or a new deal is on its way).
  if (view.legalFor(turn).isEmpty) return null;
  return BotPlays(turn, await bot.choosePlayAsync(view, turn));
}

/// The card [seat] would show now, if they may: one that someone else's
/// task needs, once a round. Null when there's nothing to show.
PlayingCard? botShows(GameState game, MatchState view, int seat) {
  if (game.spoke[seat] || !game.canSpeak(seat) || view.current.isNotEmpty) {
    return null;
  }
  // A task of its own that asks it to show a card comes first.
  final own = intendedShow(view, seat, [
    for (final t in game.tasks)
      if (t.assignedPlayerIndex == seat && t.status == TaskStatus.pending) t.description
  ]);
  if (own != null) return own;
  for (final card in view.hands[seat]) {
    if (view.revealFor(seat, card) == null) continue;
    final needed = game.tasks.any((t) =>
        t.status == TaskStatus.pending &&
        t.assignedPlayerIndex != null &&
        t.assignedPlayerIndex != seat &&
        neededCards(t.description).contains(card));
    if (needed) return card;
  }
  return null;
}
