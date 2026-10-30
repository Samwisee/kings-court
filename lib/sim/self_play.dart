/// Rounds played by the courtiers alone, with no screen: for the balance
/// report and the bot benchmarks (test/tool/) and the headless runner
/// (bin/selfplay.dart), which plays as many as a laptop can.
///
/// Each round is dealt from a seed, as the game deals, so a seed always
/// deals the same round; and the courtiers' dice come from it too, so it
/// plays out the same way. The same seed played at each rung of the
/// [ladder] gives the same deal at every strength: what differs between
/// them is how well the courtiers play, not the cards.
///
/// Pure Dart: no Flutter, so it runs anywhere Dart does.
library;

import 'dart:math';

import '../engine/bot.dart';
import '../engine/cards.dart';
import '../engine/conflicts.dart';
import '../engine/round.dart';
import '../engine/rules.dart';
import '../engine/showing.dart';
import '../game/state.dart';

/// How well a table of courtiers plays: their thinking budget, how many
/// imagined deals they think across, whether they see every hand, and
/// whether their thinking stops when a decision is decided.
class Rung {
  const Rung(this.name, {required this.budget, this.samples = 8, this.seeing = false, this.adaptive = true});

  final String name;
  final int budget;
  final int samples;
  final bool seeing;
  final bool adaptive;

  /// A bot that plays at this rung, rolling [rand].
  Bot bot(Random rand) => Bot(rand)
    ..budget = budget
    ..samples = samples
    ..omniscient = seeing
    ..adaptive = adaptive;

  Map<String, Object> toJson() =>
      {'rung': name, 'budget': budget, 'samples': samples, 'seeing': seeing, 'adaptive': adaptive};
}

/// The rungs, weakest first: 'usual' is the courtiers in the game; 'fixed'
/// is them without adaptive thinking (to see what it's worth); 'seeing'
/// sees every hand (the best case, and the teacher for the fair bots).
const ladder = [
  Rung('weak', budget: 60, samples: 2),
  Rung('casual', budget: 250, samples: 4),
  Rung('usual', budget: 900),
  Rung('fixed', budget: 900, adaptive: false),
  Rung('strong', budget: 2400, samples: 12),
  Rung('seeing', budget: 900, seeing: true),
];

Rung rungNamed(String name) => ladder.firstWhere((r) => r.name == name,
    orElse: () => throw ArgumentError('No rung "$name": ${ladder.map((r) => r.name).join(', ')}'));

/// A round the courtiers played.
class PlayedRound {
  PlayedRound(this.round, this.dealt, this.moves, this.won, this.failed);

  final Round round;
  final List<String> dealt;
  final List<MatchAction> moves;
  final bool won;

  /// The tasks that weren't done (or why the round couldn't be played).
  final List<String> failed;

  /// Decisions the courtiers made, how many were close calls, how many
  /// clear, and the thinking spent against the usual budget, summed.
  int decisions = 0, close = 0, clear = 0;
  double effort = 0;

  /// Where the courtiers and an all-seeing courtier chose differently.
  final disagreements = <Map<String, Object?>>[];
}

/// Plays one round: [players] at [target] points, dealt from [rand] as the
/// game deals, played by [bot].
///
/// Courtiers show cards as they do in the game: before the first pick, and
/// between tricks, a seat that hasn't shown one yet shows a card that a
/// task on the table needs (and that it may show). [onPlay] sees every
/// card about to be played. With a [teacher] (an all-seeing courtier),
/// every card play is also put to it, and where it would play another
/// card, that's kept in [PlayedRound.disagreements].
PlayedRound playRound(int players, int target, Random rand, Bot bot,
    {void Function(Round s, int seat, PlayingCard card)? onPlay, bool showing = true, Bot? teacher}) {
  // The seed from [rand], so a seeded run deals the same tasks every time.
  final g = GameState()
    ..seed = rand.nextInt(1 << 30)
    ..startRound(players, target);
  final s = Round(players: players, target: target);
  s.dealFor(1, rand,
      accept: (hands, inPlay) => g.tasks.every((t) => playableWith(t.description, hands, inPlay)));
  s.tasks = [for (final t in g.tasks) RoundTask(t.task)];
  final dealt = [for (final t in s.tasks) t.description];
  final moves = <MatchAction>[];
  void apply(MatchAction a) {
    s.apply(a);
    moves.add(a);
  }

  // The King card's holder is King, and picks first.
  s.king = s.kingCardHolder;
  s.pickTurn = s.king;
  s.phase = Phase.picking;
  // A card someone's task needs, shown once a round, as a courtier would.
  void showCards() {
    if (!showing || s.current.isNotEmpty) return;
    for (var seat = 0; seat < players; seat++) {
      if (s.revealed.containsKey(seat)) continue;
      // A task of its own that asks it to show a card comes first.
      final own = intendedShow(s, seat, [
        for (final t in s.tasks)
          if (t.owner == seat && t.isPending) t.description
      ]);
      if (own != null) {
        apply(ShowCard(seat, own));
        continue;
      }
      for (final card in s.hands[seat]) {
        if (s.revealFor(seat, card) == null) continue;
        final needed = s.tasks.any((t) =>
            t.isPending && (t.owner == null || t.owner != seat) && neededCards(t.description).contains(card));
        if (needed) {
          apply(ShowCard(seat, card));
          break;
        }
      }
    }
  }

  var decisions = 0, close = 0, clear = 0;
  var effort = 0.0;
  void thought() {
    final t = bot.lastThought;
    if (t.isForced) return;
    decisions++;
    if (t.close) close++;
    if (t.clear) clear++;
    effort += t.effort;
  }

  final disagreements = <Map<String, Object?>>[];
  var guard = 0;
  while (s.phase != Phase.roundOver && guard++ < 400) {
    switch (s.phase) {
      case Phase.picking:
        if (s.tasks.every((t) => t.owner == null)) showCards();
        final seat = s.pickTurn!;
        if (!s.tasks.indexed.any((e) => s.canTake(e.$1, seat))) {
          // Stuck: nobody may take what's left. Counts as a loss.
          return PlayedRound(s, dealt, moves, false, ['(no one could take a task)']);
        }
        apply(PickTask(seat, bot.choosePick(s, seat)));
        thought();
      case Phase.announcing:
        final i = s.tasks.indexWhere((t) => needsX(t.description) && t.x == null);
        apply(Announce(s.tasks[i].owner!, i, bot.chooseX(s, s.tasks[i].owner!, i)));
      case Phase.playing:
        if (s.current.isEmpty) showCards();
        final seat = s.turn;
        final card = bot.choosePlay(s, seat);
        thought();
        if (teacher != null && s.legalFor(seat).length > 1) {
          final fair = bot.lastThought;
          final seen = teacher.choosePlay(s, seat);
          if (seen != card) {
            disagreements.add({
              'ply': moves.length,
              'trick': s.tricks.length,
              'seat': seat,
              'fair': card.id,
              'seeing': seen.id,
              'close': fair.close,
              'clear': fair.clear,
              'effort': double.parse(fair.effort.toStringAsFixed(2)),
            });
          }
        }
        onPlay?.call(s, seat, card);
        apply(PlayCard(seat, card));
      case Phase.roundOver:
        break;
    }
  }
  final v = s.view;
  final failed = [
    for (final t in s.tasks)
      if (t.owner != null && taskRules[t.description]!(v, t.owner!, t.x) != Verdict.done) t.description
  ];
  return PlayedRound(s, dealt, moves, s.won ?? false, failed)
    ..decisions = decisions
    ..close = close
    ..clear = clear
    ..effort = effort
    ..disagreements.addAll(disagreements);
}

/// One seed's round at one [rung]: the deal comes from [seed] alone, and
/// so do the courtiers' dice, so every rung plays the same deal. Returns
/// the round's record (the shape the game sends, game_log.dart, with the
/// run's own details under 'selfplay') and its disagreements with an
/// all-seeing courtier, when [teach]ing.
(Map<String, Object?>, List<Map<String, Object?>>) selfPlay(int seed, int players, int target, Rung rung,
    {bool teach = false}) {
  final clock = Stopwatch()..start();
  final bot = rung.bot(Random(seed * 31 + 7));
  final teacher = teach && !rung.seeing ? rungNamed('seeing').bot(Random(seed * 31 + 11)) : null;
  final played = playRound(players, target, Random(seed), bot, teacher: teacher);
  final r = played.round;
  final record = <String, Object?>{
    'v': 1,
    'build': 'selfplay',
    'at': DateTime.now().toUtc().toIso8601String(),
    'platform': 'selfplay',
    'mode': 'free',
    'onScreen': false,
    'players': players,
    'people': const <int>[],
    'roundNumber': 1,
    'outcome': played.won ? 'won' : 'lost',
    'round': r.toJson(),
    'moves': [for (final m in played.moves) m.toJson()],
    'selfplay': {
      'seed': seed,
      'target': target,
      ...rung.toJson(),
      'tasks': [
        for (final t in r.tasks)
          {'d': t.description, 'owner': t.owner, 'x': t.x, 'seal': t.seal, 'done': !played.failed.contains(t.description)}
      ],
      if (played.failed.isNotEmpty && played.failed.first.startsWith('(')) 'stuck': true,
      'decisions': played.decisions,
      'close': played.close,
      'clear': played.clear,
      'effort': double.parse(played.effort.toStringAsFixed(2)),
      'ms': clock.elapsedMilliseconds,
    },
  };
  final disagreements = [
    for (final d in played.disagreements) {'seed': seed, 'players': players, 'target': target, 'rung': rung.name, ...d}
  ];
  return (record, disagreements);
}
