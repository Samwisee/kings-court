/// A Dynasty run: one King's reign, hand by hand. Between hands the court
/// brings a petition, and the King's answer decides who sits at the next
/// table and what it costs; then the King picks projects from the pool,
/// each dealing a task card into the hand. A finished project rewards the
/// realm; a failed stage hurts it. If a meter runs out, the King dies or
/// is driven out; a courtier whose loyalty runs out turns traitor.
/// Surviving the act, or raising its keystone, wins it.
///
/// Plain Dart and seeded: the same seed and the same choices play the same
/// run (a server could run it).
library;

import 'dart:math';

import '../../engine/deal_mix.dart';
import '../../engine/task.dart';
import '../../game/courtiers.dart';
import 'data/works.dart';
import 'realm.dart';

/// How a run ended.
enum Ending {
  /// The people rose (♥ ran out).
  revolt('The people storm the palace. The reign ends in the street.', died: true),

  /// The army is gone (♣): a rival marches in, and the King flees.
  invaded('With no army left, a rival’s banners fill the road. You flee by night.'),

  /// The stores are empty (♠): the houses depose a King who can’t feed them.
  famine('The granaries are bare. The great houses send you into exile.'),

  /// A traitor's knife.
  treason('A traitor’s knife finds you in the dark.', died: true),

  /// The act survived.
  survived('The year turns, and you still wear the crown.', won: true),

  /// The keystone raised.
  triumph('The cathedral bells ring for a reign that will be remembered.', won: true);

  const Ending(this.words, {this.died = false, this.won = false});
  final String words;
  final bool died;
  final bool won;
}

/// A project in the pool, and how far along it is.
class Work {
  Work(this.project, [this.stage = 0]);
  final Project project;
  int stage;
  bool get finished => stage >= project.stages.length;

  /// The task its next stage deals.
  String get task => project.stages[min(stage, project.stages.length - 1)];
}

/// What a hand did: each picked project's fate, the gold earned, and the
/// herald's account.
class HandReport {
  HandReport(this.lines, this.gold);
  final List<String> lines;
  final int gold;
}

class DynastyRun {
  DynastyRun(this.seed) : _rand = Random(seed) {
    final starters = projects.where((p) => !p.keystone && const {'temple', 'levy', 'granaries', 'bandits', 'tax'}.contains(p.id)).toList()
      ..shuffle(_rand);
    pool = [Work(cathedral), for (final p in starters.take(3)) Work(p)];
    _seat(const [], const []);
  }

  final int seed;
  final Random _rand;

  /// Hands in the act.
  static const handsInAct = 8;

  /// The most a meter holds.
  static const most = 10;

  final meters = <Meter, int>{Meter.people: 5, Meter.army: 5, Meter.stores: 5};
  int coffers = 6;

  /// Hands played.
  int hand = 0;

  /// The court: who may sit at the table, and how loyal each is (0 to 5).
  final court = <Courtier>[Courtier.duke, Courtier.bishop, Courtier.general, Courtier.merchant];
  final loyalty = <Courtier, int>{
    for (final c in Courtier.houses) c: 3,
  };

  /// Who sits with you at the next hand, in seat order after you.
  List<Courtier> table = [];

  /// The projects the King may pick from.
  List<Work> pool = [];

  /// The projects picked for the hand under way, in task order.
  List<Work> picked = [];

  /// The petition waiting for the King's answer, if any.
  Petition? petition;

  /// A courtier turned traitor, waiting to be dealt with.
  Courtier? traitor;

  /// How it ended, once it has.
  Ending? ending;
  bool get over => ending != null;

  /// The petitions brought so far (each once an act).
  final _brought = <String>{};

  /// Players at the next hand: you and your table.
  int get players => table.length + 1;

  /// How many projects the King may pick for a hand: one a seat, at most
  /// four.
  int get picks => min(players, 4);

  /// Whether [w] may join [chosen] for the next hand: unfinished, and its
  /// task dealt beside theirs without a clash.
  bool canPick(Work w, List<Work> chosen) =>
      !w.finished &&
      !chosen.contains(w) &&
      chosen.length < picks &&
      fitsDeal([for (final c in chosen) c.task], w.task, max(3, players));

  /// The King's pick for the next hand.
  void pick(List<Work> works) {
    assert(works.isNotEmpty && works.every((w) => pool.contains(w)));
    picked = List.of(works);
  }

  /// The tasks the hand deals: one a picked project, in order.
  List<Task> get tasks => [for (final w in picked) taskByDescription(w.task)];

  /// After a hand: [done] says, for each picked project in order, whether
  /// its task was done (true), failed (false) or never settled (null).
  /// Moves the projects on, pays the gold, takes the upkeep, and checks
  /// the realm; then brings the next petition.
  HandReport afterHand(List<bool?> done) {
    final lines = <String>[];
    var gold = 0;
    for (var i = 0; i < picked.length && i < done.length; i++) {
      final w = picked[i];
      final p = w.project;
      if (done[i] == true) {
        final points = taskByDescription(w.task).getPointsForPlayerCount(players);
        gold += points;
        w.stage++;
        for (final c in table) {
          if (leans[c] == p.mark) _loyal(c, 1);
        }
        if (w.finished) {
          lines.add(p.done);
          _apply(p.reward);
          pool.remove(w);
          if (p.keystone) ending = Ending.triumph;
        } else {
          lines.add('${p.title}: ${w.stage} of ${p.stages.length} done.');
        }
      } else if (done[i] == false) {
        lines.add(p.failed);
        _apply(p.failure);
      }
    }
    coffers += gold;
    if (gold > 0) lines.add('The court earns $gold gold.');
    // The court eats.
    _meter(Meter.stores, -1);
    lines.add('The court eats into the stores.');
    hand++;
    picked = [];
    _check();
    if (!over && hand >= handsInAct) ending = Ending.survived;
    if (!over) _bring();
    return HandReport(lines, gold);
  }

  /// Whether [c] can be chosen: its gold is there.
  bool affords(Choice c) => coffers >= c.cost;

  /// The King's answer to the petition (or the traitor).
  String choose(int choice) {
    final p = petition!;
    final c = p.choices[choice];
    assert(affords(c));
    coffers -= c.cost;
    _apply(c.effect);
    petition = null;
    if (p.id == 'treason') {
      final t = traitor!;
      traitor = null;
      // Let go, the traitor may come back for you.
      if (choice == 1 && _rand.nextBool()) ending = Ending.treason;
      court.remove(t);
    }
    _check();
    if (!over) _seat(c.effect.sits, c.effect.away);
    return c.said;
  }

  // ------------------------------------------------------------ inside

  void _apply(Effect e) {
    e.meters.forEach(_meter);
    coffers = max(0, coffers + e.coffers);
    e.loyalty.forEach(_loyal);
    if (e.project case final id?) {
      if (!pool.any((w) => w.project.id == id)) pool.add(Work(projectById(id)));
    }
    if (e.joins case final c? when !court.contains(c)) court.add(c);
    if (e.leaves case final c?) court.remove(c);
  }

  void _meter(Meter m, int by) => meters[m] = (meters[m]! + by).clamp(0, most);

  void _loyal(Courtier c, int by) {
    loyalty[c] = (loyalty[c]! + by).clamp(0, 5);
    // Out of loyalty: a traitor, dealt with before anything else.
    if (loyalty[c] == 0 && court.contains(c) && traitor == null) traitor = c;
  }

  void _check() {
    if (over) return;
    if (meters[Meter.people]! <= 0) {
      ending = Ending.revolt;
    } else if (meters[Meter.army]! <= 0) {
      ending = Ending.invaded;
    } else if (meters[Meter.stores]! <= 0) {
      ending = Ending.famine;
    }
  }

  /// The next petition: a traitor first, then one at random of those that
  /// may come now.
  void _bring() {
    if (traitor case final t?) {
      petition = Petition('treason', Courtier.spymaster, visitor: true, [
        (who: null, text: '${t.title} has turned against the crown, and fled the hall.'),
        (who: null, text: 'They have friends still, and a knife.'),
      ], [
        Choice('Hunt them down', const Effect(meters: {Meter.army: -2}),
            cost: 3, said: '${t.title} is taken at the coast, in chains.'),
        Choice('Let them go', Effect(leaves: t), said: 'They are gone. For now.'),
      ]);
      return;
    }
    final open = [
      for (final p in petitions)
        if (!_brought.contains(p.id) &&
            (p.visitor ? !court.contains(p.bringer) : court.contains(p.bringer)) &&
            (p.when?.call(meters, coffers) ?? true))
          p
    ];
    if (open.isEmpty) {
      _seat(const [], const []);
      return;
    }
    final p = open[_rand.nextInt(open.length)];
    _brought.add(p.id);
    petition = p;
  }

  /// Seats the next table: those [sits] asks for, then the most loyal of
  /// the court, three in all (four if more asked to sit), never [away].
  void _seat(List<Courtier> sits, List<Courtier> away) {
    final seated = <Courtier>[
      for (final c in sits)
        if (court.contains(c) && !away.contains(c)) c
    ];
    final rest = [
      for (final c in court)
        if (!seated.contains(c) && !away.contains(c)) c
    ]..shuffle(_rand);
    rest.sort((a, b) => loyalty[b]!.compareTo(loyalty[a]!));
    final size = max(2, min(4, max(3, seated.length)));
    for (final c in rest) {
      if (seated.length >= size) break;
      seated.add(c);
    }
    table = seated.take(4).toList();
  }
}
