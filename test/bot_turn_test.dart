import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/bot.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/decrees.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/engine/rules.dart';
import 'package:kings_court/engine/task.dart';
import 'package:kings_court/game/bot_turn.dart';
import 'package:kings_court/game/dealer.dart';
import 'package:kings_court/game/state.dart';

/// An on-screen 4-player game, dealt and crowned.
GameState table({int seed = 7}) {
  final g = GameState()
    ..seed = seed
    ..digital = true
    ..players = [for (int i = 0; i < 4; i++) Player('P$i', colorValue: 0xff000000)]
    ..seatCourtiers()
    ..startRound(4, 6);
  dealRound(g);
  g.crown(g.round!.kingCardHolder);
  return g;
}

const exactly = 'Win exactly X tricks, named before the first trick';

/// [g]'s round with these tasks, already taken by these seats.
Round withTasks(GameState g, Map<String, int> owned) {
  final r = g.round!
    ..tasks = [for (final e in owned.entries) RoundTask(taskByDescription(e.key), owner: e.value)]
    ..pickTurn = null;
  return r;
}

void main() {
  final bot = Bot()..budget = 40;

  test('A courtier picks a task they may take; you are left to pick yours', () async {
    final g = table();
    final r = g.round!;
    // Whoever picks first.
    final picker = r.pickTurn!;
    final d = await botDecision(g, bot, you: picker == 0 ? 1 : 0);
    expect(d, isA<BotPicks>());
    final pick = d! as BotPicks;
    expect(pick.seat, picker);
    expect(r.canTake(pick.task, picker), isTrue);
    // With you to pick, nothing happens.
    expect(await botDecision(g, bot, you: picker), isNull);
  });

  test('Once every task is taken, a courtier plays a legal card on their turn', () async {
    final g = table();
    final r = g.round!;
    // Hand the tasks round.
    while (r.pickTurn != null) {
      final seat = r.pickTurn!;
      final t = r.tasks.firstWhere((t) => t.owner == null && r.mayTake(t, seat),
          orElse: () => r.tasks.firstWhere((t) => t.owner == null));
      r.assign(t, r.mayTake(t, seat) ? seat : (seat + 1) % 4);
    }
    for (var i = 0; i < r.tasks.length; i++) {
      if (needsX(r.tasks[i].description)) r.announce(i, 1);
    }
    final turn = r.turn;
    final d = await botDecision(g, bot, you: (turn + 1) % 4);
    expect(d, anyOf(isA<BotPlays>(), isA<BotShows>()));
    if (d is BotPlays) {
      expect(d.seat, turn);
      expect(r.legalFor(turn), contains(d.card));
    }
    // On your turn, the table waits for you (a courtier may still show a
    // card between tricks).
    expect(await botDecision(g, bot, you: turn), anyOf(isNull, isA<BotShows>()));
  });

  test('A courtier names a number for their "exactly X" task; yours waits for you', () async {
    final g = table();
    final r = withTasks(g, {exactly: 1, 'Win the 6♣': 2});
    final d = await botDecision(g, bot, you: 0);
    expect(d, isA<BotAnnounces>());
    final a = d! as BotAnnounces;
    expect((a.seat, a.task), (1, 0));
    expect(a.x, inInclusiveRange(r.hands[1].contains(PlayingCard.king) ? 1 : 0, r.totalTricks));
    withTasks(g, {exactly: 0, 'Win the 6♣': 2});
    final yours = await botDecision(g, bot, you: 0);
    expect(yours, isA<YourAnnouncement>());
    expect((yours! as YourAnnouncement).task, 0);
  });

  test('Under the King’s Command a courtier King hands each task to someone who may hold it',
      () async {
    final g = table();
    final r = g.round!..decree = Decree.kingsCommand;
    final king = r.king!;
    r.pickTurn = king;
    for (final t in r.tasks) {
      t.owner = null;
    }
    final d = await botDecision(g, bot, you: (king + 1) % 4);
    expect(d, isA<BotPicks>());
    final pick = d! as BotPicks;
    expect(pick.task, 0, reason: 'the first open task');
    expect(r.mayTake(r.tasks[0], pick.seat), isTrue);
  });

  test('A lesson’s courtier plays the scripted card while it’s legal, and decides otherwise',
      () async {
    final g = table();
    final r = withTasks(g, {'Win the 6♣': 1});
    final turn = r.turn;
    final legal = r.legalFor(turn);
    final scripted = await botDecision(g, bot,
        you: (turn + 1) % 4,
        script: CourtierScript(play: (_, __) => legal.last, showsBetweenTricks: false));
    expect(scripted, isA<BotPlays>());
    expect((scripted! as BotPlays).card, legal.last);
    // A card it can't play (off suit, or not in hand) is ignored.
    final notHeld = PlayingCard.fromId(
        List.generate(40, (i) => i).firstWhere((i) => !r.hands[turn].contains(PlayingCard.fromId(i))));
    final free = await botDecision(g, bot,
        you: (turn + 1) % 4,
        script: CourtierScript(play: (_, __) => notHeld, showsBetweenTricks: false));
    expect(free, isA<BotPlays>());
    expect(legal, contains((free! as BotPlays).card));
  });

  test('Bots announce, pick and play legally with even thinking as with focused', () async {
    final even = Bot()
      ..budget = 40
      ..focus = false;
    final g = table(seed: 11);
    final r = g.round!;
    final picker = r.pickTurn!;
    final i = await even.choosePickAsync(r, picker);
    expect(r.canTake(i, picker), isTrue);
    expect(even.choosePick(r, picker), predicate<int>((j) => r.canTake(j, picker)));
    withTasks(g, {exactly: 1});
    final x = even.chooseX(r, 1, 0);
    expect(x, inInclusiveRange(r.hands[1].contains(PlayingCard.king) ? 1 : 0, r.totalTricks));
    expect(await even.chooseXAsync(r, 1, 0), inInclusiveRange(0, r.totalTricks));
    r.tasks[0].x = x;
    expect(r.legalFor(r.turn), contains(even.choosePlay(r, r.turn)));
  });

  test('Sealed tasks are planned in their order', () async {
    final g = table(seed: 5);
    final r = withTasks(g, {'Win the 6♣': 1, 'Win the first trick': 2});
    r.tasks[0].seal = 1;
    r.tasks[1].seal = Seals.last;
    final d = await botDecision(g, bot,
        you: (r.turn + 1) % 4, script: const CourtierScript(showsBetweenTricks: false));
    expect(d, anyOf(isNull, isA<BotPlays>()));
    if (d is BotPlays) expect(r.legalFor(r.turn), contains(d.card));
  });
}
