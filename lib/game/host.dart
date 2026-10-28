/// The courtiers' side of an on-screen table, with no screen in it: when
/// the game is ready for one of them to move, what they do, and sending
/// it through the table link.
///
/// What a courtier does comes from bot_turn.dart; the page keeps only its
/// own pauses (an animation, a drag, a dialog) and the timers between
/// moves. Online, a server runs this for the empty seats.
library;

import '../engine/bot.dart';
import '../engine/conflicts.dart';
import '../engine/round.dart';
import '../models.dart';
import 'bot_turn.dart';

/// What came of giving the courtiers a turn: [decision] is what the
/// courtier (or you, for an announcement) decided, null when there was
/// nothing to do; [stale] when the game moved while a courtier thought, so
/// the next turn should think again.
typedef HostTurn = ({BotDecision? decision, bool stale});

class Host {
  Host(
      {required this.bot,
      required this.you,
      required this.send,
      this.script = const CourtierScript()});

  /// The courtiers' brain, shared between the seats.
  final Bot bot;

  /// The seat this device plays from: never a courtier's.
  final int you;

  /// Where a courtier's move goes (the table link).
  final void Function(MatchAction move) send;

  /// The mode's say over the courtiers (a lesson's script).
  CourtierScript script;

  /// A courtier is thinking (a slice at a time, so the screen stays smooth).
  bool busy = false;

  /// Whether the game itself is ready for a courtier to move: cards on
  /// screen, the King crowned, the deal shown ([dealtFor] is the deal the
  /// table has laid out) and the round still going. The screen adds its
  /// own pauses.
  static bool ready(GameState g, {required int dealtFor}) =>
      g.digital &&
      g.round != null &&
      g.round!.hasCards &&
      g.round!.king != null &&
      dealtFor == g.dealId &&
      g.outcome == RoundOutcome.inProgress;

  /// What the round looks like now, to check nothing moved while a
  /// courtier was thinking.
  static String moment(GameState g) {
    final r = g.round;
    if (r == null) return '';
    return '${g.dealId}|${r.pickTurn}|'
        '${r.tasks.where((t) => t.owner != null).length}|'
        '${r.announced.length}|${r.tricks.length}|${r.current.length}';
  }

  /// Gives the courtier whose turn it is their move, and sends it. [still]
  /// says whether the table is still there once the courtier has thought.
  Future<HostTurn> act(GameState g, {bool Function()? still}) async {
    busy = true;
    try {
      final before = moment(g);
      final decision = await botDecision(g, bot, you: you, script: script);
      if (!(still?.call() ?? true) || moment(g) != before) {
        return (decision: null, stale: true);
      }
      switch (decision) {
        case null:
        case YourAnnouncement():
          break;
        case BotPicks(:final seat, :final task):
          send(PickTask(seat, task));
        case BotPasses(:final seat):
          send(Pass(seat));
        case BotAnnounces(:final seat, :final task, :final x):
          send(Announce(seat, task, x));
        case BotShows(:final seat, :final card):
          send(ShowCard(seat, card));
        case BotPlays(:final seat, :final card):
          send(PlayCard(seat, card));
      }
      return (decision: decision, stale: false);
    } finally {
      busy = false;
    }
  }

  /// Picking begins: the cards courtiers show first, one each, when a task
  /// on the table needs a card they may show.
  List<ShowCard> openingShows(GameState g) {
    final r = g.round!;
    final open = [for (final t in r.tasks) if (t.owner == null) t];
    final shows = <ShowCard>[];
    for (var seat = 0; seat < r.players; seat++) {
      if (seat == you || r.spoke[seat] || !r.canSpeak(seat)) continue;
      for (final card in r.hands[seat]) {
        if (r.revealFor(seat, card) == null) continue;
        if (open.any((t) => neededCards(t.description).contains(card))) {
          shows.add(ShowCard(seat, card));
          break;
        }
      }
    }
    return shows;
  }

  /// The next card when a won round plays itself out: whoever's turn it
  /// is plays their first legal card. Null once every card is played.
  PlayCard? playOutStep(GameState g) {
    final r = g.round!;
    if (r.tricks.length >= r.totalTricks) return null;
    final seat = r.turn;
    final legal = r.legalFor(seat);
    return legal.isEmpty ? null : PlayCard(seat, legal.first);
  }
}
