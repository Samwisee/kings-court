/// What the on-screen table says and marks, worked out from the game:
/// the line under the tasks saying what's happening, and the cards a task
/// is about with what's become of each.
library;

import '../../engine/cards.dart';
import '../../engine/decrees.dart';
import '../../engine/inference.dart';
import '../../engine/round.dart';
import '../../engine/rules.dart';
import '../../engine/task.dart';
import '../../engine/task_help.dart';
import '../../game/state.dart';
import '../../skin/theme.dart';
import '../cards/task_chip.dart';

/// What the table says is happening, for the player at [you]: who won the
/// trick just played ([lastTrick]), whose pick or turn it is, or nothing
/// while the King is chosen. [speakPrompt] is the table asking whether
/// anyone will show a card before the first pick; [othersDeciding], the
/// others at a shared table still saying.
String tableStatus(GameState game,
    {required int you,
    Trick? lastTrick,
    required bool choosingKing,
    required bool speakPrompt,
    bool othersDeciding = false}) {
  final r = game.round!;
  if (lastTrick != null) {
    final w = lastTrick.winner;
    return w == you ? 'You win the trick' : '${game.players[w].name} wins the trick';
  }
  if (choosingKing) return '';
  if (r.pickTurn != null) {
    if (speakPrompt) return 'Share a card?';
    if (othersDeciding) return 'Waiting to see if anyone shares a card…';
    if (r.pickTurn == you) {
      return r.decree == Decree.kingsCommand
          ? "King's Command: hold a task to hand it out"
          : r.canPass(you)
              ? 'Hold a task to take it, or'
              : 'Hold a task to take it';
    }
    return '${game.players[r.pickTurn!].name} is choosing a task…';
  }
  if (!r.settled) return 'Announcing numbers…';
  if (game.outcome != RoundOutcome.inProgress) return '';
  if (r.turn == you) {
    if (r.current.isEmpty) return 'Your lead';
    return 'Your turn: follow ${switch (r.led!.suit) {
      Suit.hearts => 'hearts',
      Suit.diamonds => 'diamonds',
      Suit.spades => 'spades',
      Suit.clubs => 'clubs',
      Suit.court => 'with a Court Card',
    }}';
  }
  return '${game.players[r.turn].name} is thinking…';
}

/// The cards task [t] is about, marked the way the card tracker marks
/// them: outlined in the colour of whoever played each one (with the trick
/// it fell in), or of whoever is known to hold it, as [you] can tell.
List<MarkedCard> cardStates(RoundTask t,
    {required Round round, required List<Player> players, required int you, required bool onScreen}) {
  final cards = relevantCards(t.description);
  if (!onScreen || !round.hasCards) {
    return [for (final c in cards) (card: c, edge: null, trick: null, played: false)];
  }
  final playedIn = <PlayingCard, (int, int)>{}; // trick number, seat
  for (var i = 0; i < round.tricks.length; i++) {
    final tr = round.tricks[i];
    for (var k = 0; k < tr.cards.length; k++) {
      playedIn[tr.cards[k]] = (i + 1, tr.seats[k]);
    }
  }
  for (var k = 0; k < round.current.length; k++) {
    playedIn[round.current[k]] = (round.tricks.length + 1, round.currentSeats[k]);
  }
  final holder = <PlayingCard, int>{
    if (round.hands.length > you)
      for (final c in round.hands[you]) c: you,
    for (final g in guessHands(round, you))
      for (final c in g.certain) c: g.seat,
  };
  return [
    for (final c in cards)
      (
        card: c,
        edge: playedIn[c] != null
            ? players[playedIn[c]!.$2].color
            : holder[c] != null
                ? players[holder[c]!].color
                : null,
        trick: playedIn[c]?.$1,
        played: playedIn[c] != null,
      ),
  ];
}

/// The "exactly X" task you're to say your number for, when yours is the
/// next to be said (they're said in the order the tasks lie).
int? yourNumberDue(Round r, {required int you}) {
  if (!r.allTaken) return null;
  for (var i = 0; i < r.tasks.length; i++) {
    final t = r.tasks[i];
    if (needsX(t.description) && t.x == null) return t.owner == you ? i : null;
  }
  return null;
}

/// What [seat]'s courtier shows when asked to show a card: the card most
/// use to the tasks still to do (or the only one of its suit), or why
/// they can't, in a few words.
({String? no, PlayingCard? card}) courtierShow(GameState game, int seat) {
  final c = game.round!;
  final name = game.players[seat].name;
  if (c.spoke[seat]) return (no: '$name has already shown a card this round', card: null);
  if (!c.canSpeak(seat)) return (no: c.whyCantSpeak() ?? 'No cards may be shown now', card: null);
  if (c.current.isNotEmpty) return (no: '$name can show a card once this trick is over', card: null);
  final showable = [for (final card in c.hands[seat]) if (c.revealFor(seat, card) != null) card];
  if (showable.isEmpty) return (no: '$name has no card they may show', card: null);
  int score(PlayingCard card) {
    final needed = game.tasks
        .any((t) => t.status == TaskStatus.pending && neededCards(t.description).contains(card));
    final hint = c.revealFor(seat, card);
    final suitCount = c.hands[seat].where((x) => x.suit == card.suit).length;
    return (needed ? 100 : 0) + (hint == 'only' ? 20 : 0) + suitCount;
  }
  showable.sort((a, b) => score(b).compareTo(score(a)));
  return (no: null, card: showable.first);
}
