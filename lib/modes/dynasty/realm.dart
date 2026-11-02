/// Dynasty's pieces, as data: the realm's meters, the projects the King sets
/// the court to, and the petitions (dilemmas) courtiers bring between hands.
/// The run that plays them is run.dart; what's in the realm is data/.
library;

import '../../game/courtiers.dart';

/// The realm's measures, each a suit. Coffers (♦) are the King's gold, kept
/// apart: points are money.
enum Meter {
  people('♥', 'The people'),
  army('♣', 'The army'),
  stores('♠', 'The stores');

  const Meter(this.suit, this.label);
  final String suit;
  final String label;
}

/// What a choice, a project's completion or its failure does to the realm.
class Effect {
  const Effect({
    this.meters = const {},
    this.coffers = 0,
    this.loyalty = const {},
    this.sits = const [],
    this.away = const [],
    this.project,
    this.joins,
    this.leaves,
  });

  /// Changes to the realm's meters.
  final Map<Meter, int> meters;

  /// Gold gained (or, below zero, spent).
  final int coffers;

  /// Changes to courtiers' loyalty.
  final Map<Courtier, int> loyalty;

  /// Courtiers who sit at the next hand's table, and those kept from it.
  final List<Courtier> sits;
  final List<Courtier> away;

  /// A project added to the pool (by id).
  final String? project;

  /// A courtier who comes to court, or leaves it.
  final Courtier? joins;
  final Courtier? leaves;

  bool get isEmpty =>
      meters.isEmpty &&
      coffers == 0 &&
      loyalty.isEmpty &&
      sits.isEmpty &&
      away.isEmpty &&
      project == null &&
      joins == null &&
      leaves == null;
}

/// A work the King sets the court to: done in [stages], one a hand when
/// it's picked, each stage a task card dealt into that hand. Done: its
/// [reward]. A stage's task failed: its [failure].
class Project {
  const Project(
    this.id,
    this.title,
    this.meter, {
    required this.stages,
    required this.reward,
    required this.failure,
    required this.done,
    required this.failed,
    this.keystone = false,
    this.suit,
  });

  final String id;
  final String title;

  /// The meter it serves (its suit), or null for the coffers' (♦).
  final Meter? meter;

  /// The suit shown on it: the meter's, or ♦.
  final String? suit;
  String get mark => suit ?? meter?.suit ?? '♦';

  /// Each stage's task, by its words in the task library.
  final List<String> stages;
  final Effect reward;
  final Effect failure;

  /// What the herald says when it's finished, and when a stage fails.
  final String done;
  final String failed;

  /// Finishing it wins the act.
  final bool keystone;
}

/// One choice in a petition: what it's called, what it costs in gold
/// (unaffordable, it can't be chosen), what follows, and what's said.
class Choice {
  const Choice(this.label, this.effect, {this.cost = 0, this.said = ''});
  final String label;
  final Effect effect;
  final int cost;
  final String said;
}

/// A line of a petition: said by a courtier, or by the herald (null).
typedef Line = ({Courtier? who, String text});

/// A matter a courtier brings to the throne between hands, and the King's
/// two answers.
class Petition {
  const Petition(this.id, this.bringer, this.lines, this.choices,
      {this.visitor = false, this.when});
  final String id;

  /// Who brings it. A [visitor] brings it from outside the court.
  final Courtier bringer;
  final bool visitor;
  final List<Line> lines;
  final List<Choice> choices;

  /// Only brought when this holds (and, unless a visitor's, while the
  /// bringer is at court).
  final bool Function(Map<Meter, int> meters, int coffers)? when;
}

/// What each house leans to: their suit. A courtier at the table when a
/// project of their suit moves on is pleased (+1 loyalty).
const leans = <Courtier, String>{
  Courtier.duke: '♠',
  Courtier.bishop: '♥',
  Courtier.general: '♣',
  Courtier.merchant: '♦',
};
