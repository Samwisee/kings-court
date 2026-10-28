/// Tasks about showing a card with the speech token, and the card a player
/// holding one would choose to show. Shared by the courtiers in the game,
/// their imagined rounds (bot.dart) and the balance tool, so all three show
/// cards the same way.
library;

import 'cards.dart';
import 'match.dart';

/// Tasks that ask their holder to show a card (and so can't be dealt in a
/// round where nobody may: the Silence decree).
const showTasks = {
  'Win the card you showed',
  "Don't win the card you showed",
  'Win the trick right after you show a card',
  "Don't win a trick before you've shown a card",
};

/// Tasks about cards anyone shows: they need someone to show a card, so
/// they're left out of a round of Silence too.
const shownCardTasks = {
  'Win a card someone else showed',
  'Win a trick led with a shown card',
};

/// Whether a task needs cards shown this round.
bool needsShowing(String d) => showTasks.contains(d) || shownCardTasks.contains(d);

/// The card [seat] would show for the tasks it holds ([mine], by
/// description), or null when none of them asks it to show. To win the
/// card it shows, or the trick after, it shows its strongest card that may
/// be shown; to keep its card from itself, its weakest; and to be free to
/// win tricks, anything at once (its weakest).
PlayingCard? intendedShow(MatchState m, int seat, Iterable<String> mine) {
  final wants = {for (final d in mine) if (showTasks.contains(d)) d};
  if (wants.isEmpty || m.revealed.containsKey(seat) || seat >= m.hands.length) return null;
  final showable = [
    for (final c in m.hands[seat])
      if (m.revealFor(seat, c) != null) c
  ];
  if (showable.isEmpty) return null;
  showable.sort((a, b) => a.rank.compareTo(b.rank));
  final strong = wants.contains('Win the card you showed') ||
      wants.contains('Win the trick right after you show a card');
  return strong ? showable.last : showable.first;
}
