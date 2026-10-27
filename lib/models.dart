import 'dart:math';
import 'package:flutter/material.dart';
import 'chronicle.dart';
import 'courtiers.dart';
import 'story.dart';
import 'engine/match.dart';
import 'engine/conflicts.dart';
import 'engine/deal_mix.dart';
import 'engine/rules.dart';
import 'tasks.dart';
import 'tutorial.dart';
import 'theme.dart';

enum TaskStatus { pending, completed, failed }

enum RoundOutcome { inProgress, won, lost }

/// Free play; Endless (each win adds a point); the Chronicle chapters;
/// Dynasty, where the King reigns until they fall; or the Tutorial, short
/// set-up rounds that teach the game (see tutorial.dart). New modes go on
/// the end: saved games store the index.
enum GameMode { free, endless, chronicle, dynasty, tutorial }

const minPlayers = 2;
const maxPlayers = 6;

class Task {
  final String description;
  final int threePlayerPoints;
  final int fourPlayerPoints;
  final int fivePlayerPoints;
  final int sixPlayerPoints;

  /// Tasks measured against the King (e.g. "win more tricks than the King")
  /// can't be taken by the King.
  final bool kingCantTake;

  TaskStatus status;
  int? assignedPlayerIndex;

  /// Wax seal fixing when this task must be completed (see [Seals]).
  int? seal;

  Task({
    required this.description,
    required this.threePlayerPoints,
    required this.fourPlayerPoints,
    required this.fivePlayerPoints,
    required this.sixPlayerPoints,
    this.kingCantTake = false,
    this.status = TaskStatus.pending,
    this.assignedPlayerIndex,
  });

  bool get isCompleted => status == TaskStatus.completed;
  bool get isFailed => status == TaskStatus.failed;

  /// Difficulty for [playerCount]. The 2-player variant (with the Dummy)
  /// uses the 3-player difficulty.
  int getPointsForPlayerCount(int playerCount) {
    switch (playerCount) {
      case 4:
        return fourPlayerPoints;
      case 5:
        return fivePlayerPoints;
      case 6:
        return sixPlayerPoints;
      default:
        return threePlayerPoints;
    }
  }

  static final _perPlayerCount =
      RegExp(r'(\d+) / (\d+) / (\d+) / (\d+) \(2–3 / 4 / 5 / 6 players\)');
  static final _bracketed = RegExp(r'\s*\(([^)]*)\)');

  /// Short wording for the card on the table. Tasks with a number per
  /// player count show only the number that applies, and any bracketed
  /// condition is left off (see [notes]); the card shows an info icon
  /// instead.
  String cardText(int playerCount) {
    var text = description;
    final m = _perPlayerCount.firstMatch(text);
    if (m != null) {
      final group = playerCount <= 3 ? 1 : playerCount - 2;
      text = text.replaceRange(m.start, m.end, m.group(group)!);
    }
    return text.replaceAll(_bracketed, '');
  }

  /// The trick it's about can't have any Court Cards in it: shown as an
  /// icon beside the points.
  bool get noCourtCards =>
      description.contains('with no Court Cards') ||
      description.contains('only even cards') ||
      description.contains('only odd cards');

  /// The full wording for the close-up, less "with no Court Cards", which
  /// its icon says.
  String fullText(int playerCount) =>
      cardText(playerCount).replaceAll(RegExp(r',? with no Court Cards'), '').trim();

  /// The task as short as it can go, for the card on the table: the same
  /// meaning in fewer words, with Court Cards as a crown (\uE001) and "with no
  /// Court Cards" as a struck-out crown (\uE000). The close-up keeps the full
  /// wording.
  String boardText(int playerCount) {
    var t = cardText(playerCount).trim();
    for (final (from, to) in _shorter) {
      t = t.replaceAllMapped(
          from,
          (m) => to.replaceAllMapped(
              RegExp(r'\$(\d)'), (g) => m.group(int.parse(g[1]!)) ?? ''));
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static final List<(Pattern, String)> _shorter = [
    // Shown as an icon beside the points instead.
    (RegExp(r',? with no Court Cards'), ''),
    ('Win more tricks than anyone else', 'Win the most tricks'),
    ('Win fewer tricks than anyone else', 'Win the fewest tricks'),
    ('than the rest of the court put together', 'than everyone else combined'),
    ('Win the same number of tricks as', 'Win as many tricks as'),
    (RegExp(r'Win a trick where every card is lower than (\d)'), r'Win a trick of cards below $1'),
    ('Win a trick where every card is higher than 5', 'Win a trick of cards above 5'),
    ('totalling more than', 'worth over'),
    ('totalling less than', 'worth under'),
    ('totalling exactly', 'worth'),
    (RegExp(r'only (even|odd) cards:.*$'), r'only $1 cards'),
    ('Win all nine cards of any one suit', 'Win a whole suit'),
    ('Win a card of every suit', 'Win one of every suit'),
    ("Don't win any of the first", 'Win none of the first'),
    ("Don't win any", 'Win no'),
    ("Don't win two tricks in a row", 'Never win two in a row'),
    ("Don't lead a trick with a", 'Never lead'),
    ('said out loud before the first trick', 'said aloud'),
    ('written down in secret before the first trick', 'in secret'),
    (", and they're in a row", ', in a row'),
    ('a trick containing an Ace and a 9', 'an Ace and a 9 in one trick'),
    (RegExp(r'as many ([♥♦♠♣]) cards as ([♥♦♠♣]) cards'), r'equal $1 and $2'),
    (RegExp(r'([♥♦♠♣]) cards?\b'), r'$1'),
    ('Win no Court Cards', 'Win no \uE001'),
    (RegExp(r'Court Cards?'), '\uE001'),
  ];

  /// The bracketed conditions, as sentences, for the close-up view.
  List<String> get notes {
    final text = description.replaceAll(_perPlayerCount, '');
    return [
      for (final m in _bracketed.allMatches(text))
        '${m.group(1)![0].toUpperCase()}${m.group(1)!.substring(1)}.',
    ];
  }

  bool get hasNotes => notes.isNotEmpty;

  Task freshCopy() => Task(
        description: description,
        threePlayerPoints: threePlayerPoints,
        fourPlayerPoints: fourPlayerPoints,
        fivePlayerPoints: fivePlayerPoints,
        sixPlayerPoints: sixPlayerPoints,
        kingCantTake: kingCantTake,
      )..seal = seal;
}

class Player {
  String name;
  Color color;
  Player(this.name, {required this.color});
}

class GameState {
  List<Player> players = [];
  List<Task> tasks = [];

  /// Index of the player holding the King card, or null if not chosen yet.
  int? kingIndex;

  int roundNumber = 0;
  int wins = 0;
  int losses = 0;

  /// Whether each player has used their once-per-round card reveal.
  List<bool> spoke = [];

  /// Seats that have passed on taking a task this round. Each player may
  /// pass once a round, handing the pick to the next player.
  Set<int> passed = {};

  /// Whose turn it is to pick a task, or null once every task has an owner.
  int? pickTurn;

  GameMode mode = GameMode.free;

  /// Endless mode: each win adds a point to the next round.
  bool get campaign => mode == GameMode.endless;
  set campaign(bool on) => mode = on ? GameMode.endless : GameMode.free;

  /// The Chronicle chapter being played, if any.
  int? chapter;

  /// The tutorial lesson being played (see [lessons]).
  int lesson = 0;
  bool get isTutorial => mode == GameMode.tutorial;

  /// Free play and Endless: add random seals and decrees to each round.
  bool surprise = false;

  /// Outside Dynasty: whether everyone plays a courtier, with a house and
  /// a once-per-round power. Dynasty always has roles.
  bool roles = true;
  bool get hasRoles => isDynasty || roles;

  /// On-screen cards: the round is played on the device, you in seat 0
  /// and bots in the rest. Null when playing with a real deck.
  MatchState? cards;
  bool get digital => cards != null;

  /// Seals in this round, the decree in force, and the exiled seat.
  int sealCount = 0;
  Decree? decree;
  int? exiledSeat;

  // ---------------------------------------------------------- Dynasty

  /// Which courtier sits in each seat (decides the token's shape).
  List<Courtier> courtiers = [];

  /// Loyalty to the crown per seat, 0 to 5. At 0 a courtier openly turns
  /// against the King.
  List<int> loyalty = [];

  /// The open scheme of each antagonist (index into [schemes]).
  List<int?> schemeOf = [];

  /// This round: whether each antagonist's scheme succeeded (true),
  /// was foiled (false) or is still undecided (null).
  List<bool?> schemeResult = [];

  /// Powers used this round.
  List<bool> powerUsed = [];

  /// Wounds the King has taken, and how many they can survive. The
  /// toughness is secret: rolled at the crowning, revealed at death.
  int kingWounds = 0;
  int kingToughness = 2;

  /// Which reign this is (1 for the first King) and how many have fallen.
  int reign = 0;
  int fallenKings = 0;

  /// The round the current reign began in.
  int reignStartRound = 0;

  int get reignRounds => roundNumber - reignStartRound + 1;

  /// Set by a dilemma for the next round.
  Decree? pendingDecree;
  int pointsBonus = 0;

  /// Dilemmas already faced, so they don't repeat too soon.
  List<int> facedDilemmas = [];

  /// What the story remembers: choices made and how matters turned out
  /// ("varric_defied"), and which story matters have been faced
  /// ("seen:<title>"). Lasts the whole dynasty, across reigns.
  Set<String> flags = {};

  /// Whether a story matter can come up now.
  bool storyReady(String title, String? arc, List<String> requires,
          List<String> forbids) =>
      requires.every(flags.contains) &&
      !forbids.any(flags.contains) &&
      (arc == null || !flags.contains('seen:$title'));

  /// Rounds won in this reign; enough of them brings a Golden Age.
  int reignWins = 0;

  /// What kind of ruler the King has been, from their choices; decides
  /// the name history gives them (see [epithet]).
  Map<String, int> traits = {};

  /// The Kings who have fallen, in order.
  List<Annal> annals = [];

  /// Solo Dynasty: the person in each seat ("Aldric Ashcombe"), who
  /// may leave and be replaced between rounds.
  List<String> people = [];

  /// Rounds each seat has spent as a traitor.
  List<int> traitorRounds = [];

  /// Courtiers a choice has sent away, who leave before the next round.
  List<Courtier> pendingDepartures = [];

  /// Who left and who arrived before this round, to read with the tidings:
  /// (seat, what happened, arrived).
  List<CourtNews> courtNews = [];

  /// Courtiers the story has called to court, who arrive before the next
  /// round.
  List<Courtier> pendingArrivals = [];

  /// The solo King's name this reign ("Edmund").
  String reignName = '';

  /// Solo Dynasty on screen: you are always the King, and the court
  /// changes around you.
  bool get solo => isDynasty && digital;

  /// The royal coffers, in gold. Taxes come in each round; choices spend
  /// it (or bring it in).
  int coffers = 12;

  /// Gold a choice costs (positive) or brings in (negative).
  static int costOf(Choice c) =>
      -c.effects.whereType<Gold>().fold<int>(0, (a, g) => a + g.delta);

  /// Whether the coffers can pay for [c].
  bool canAfford(Choice c) => costOf(c) <= 0 || coffers >= costOf(c);

  /// The round the main story (Karsk) last moved on.
  int mainBeatRound = -99;

  /// Solo Dynasty: everyone at court (not you), whether or not they sit at
  /// the table this round. Each scene seats only the people it needs.
  List<Courtier> court = [];

  /// Solo Dynasty: what each courtier at court thinks of you, their
  /// scheme, how long they've schemed, and their colour, by courtier name.
  Map<String, int> standing = {};
  Map<String, int> schemeBy = {};
  Map<String, int> traitorFor = {};
  Map<String, int> courtColor = {};

  /// The round whose scene has already been chosen (and its cast seated).
  int scenePicked = -1;

  /// Your own house, in solo Dynasty: the courtier in your seat.
  Courtier? get kingRole =>
      courtiers.isEmpty ? null : courtiers[kingIndex ?? 0];

  /// The colour of [c], seated or not.
  Color colorOf(Courtier c) {
    final seat = courtiers.indexOf(c);
    if (seat >= 0 && seat != kingIndex) return players[seat].color;
    return Color(courtColor[c.name] ?? Palette.players[1].toARGB32());
  }

  /// What [c] thinks of you, seated or not.
  int loyaltyOf(Courtier c) {
    final seat = courtiers.indexOf(c);
    if (seat >= 0 && seat < loyalty.length) return loyalty[seat];
    return standing[c.name] ?? startingLoyalty;
  }

  /// Everyone at court besides the King: the roster in solo Dynasty, the
  /// seats otherwise.
  List<Courtier> get courtRoles => solo
      ? court
      : [
          for (int i = 0; i < courtiers.length; i++)
            if (i != kingIndex) courtiers[i]
        ];

  /// Starts the solo court from whoever sits at the table.
  void _ensureCourt() {
    if (!solo || court.isNotEmpty) return;
    final king = kingIndex ?? 0;
    for (int s = 0; s < courtiers.length; s++) {
      if (s == king) continue;
      court.add(courtiers[s]);
      standing[courtiers[s].name] = loyalty[s];
      courtColor[courtiers[s].name] = players[s].color.toARGB32();
    }
    // The whole council is there for the coronation: every great house.
    for (final c in Courtier.houses) {
      if (court.contains(c) || court.length >= maxCourt) continue;
      final used = {
        players.first.color.toARGB32(),
        ...courtColor.values,
      };
      court.add(c);
      standing[c.name] = startingLoyalty;
      courtColor[c.name] = Palette.players
          .firstWhere((p) => !used.contains(p.toARGB32()),
              orElse: () => Palette.players[court.length % Palette.players.length])
          .toARGB32();
    }
  }

  /// Writes what the seated courtiers think back to the court.
  void _syncStanding() {
    if (!solo) return;
    for (int s = 0; s < courtiers.length && s < loyalty.length; s++) {
      if (s == kingIndex) continue;
      final c = courtiers[s];
      standing[c.name] = loyalty[s];
      final scheme = s < schemeOf.length ? schemeOf[s] : null;
      if (scheme == null) {
        schemeBy.remove(c.name);
      } else {
        schemeBy[c.name] = scheme;
      }
    }
  }

  /// Changes [c]'s loyalty, whether or not they're at the table.
  void _changeLoyaltyOf(Courtier c, int delta) {
    final seat = courtiers.indexOf(c);
    if (seat >= 0) {
      _changeLoyalty(seat, delta);
    } else if (solo && court.contains(c)) {
      final v = ((standing[c.name] ?? startingLoyalty) + delta)
          .clamp(0, maxLoyalty)
          .toInt();
      standing[c.name] = v;
      if (v <= 0) {
        schemeBy[c.name] ??= Random().nextInt(schemes.length);
      } else {
        schemeBy.remove(c.name);
      }
    }
  }

  /// This round's tidings (index into [tidings]), and whether its
  /// outcome has been carried out yet.
  int? tiding;
  bool tidingResolved = false;
  List<int> facedTidings = [];

  /// The royal charge this round: which seat, which task (by
  /// description), and whether the King gave it (rather than the tidings).
  int? chargeSeat;
  String? chargeTask;
  bool chargeByKing = false;

  /// A charge the King has decreed for next round.
  Courtier? pendingCharge;

  Tiding? get currentTiding => tiding == null ? null : tidings[tiding!];

  bool isCharged(Task t) =>
      chargeTask != null && t.description == chargeTask;

  /// How each courtier's loyalty moved with the round just finished
  /// (the courtier who did the most for a won round gains favour; one
  /// whose task failed loses it).
  List<int> roundLoyalty = [];
  List<int> _loyaltyBeforeRound = [];

  static const startingLoyalty = 3;
  static const maxLoyalty = 5;
  static const goldenAgeWins = 5;
  static const maxFallenKings = 3;

  /// The name the current King will be remembered by.
  String get epithet {
    const names = {
      'kind': 'the Kind',
      'stern': 'the Stern',
      'bold': 'the Bold',
      'wise': 'the Wise',
      'iron': 'the Iron',
      'ambitious': 'the Ambitious',
    };
    if (reignWins >= goldenAgeWins) return 'the Golden';
    final best = traits.entries.where((e) => e.value > 0).fold<MapEntry<String, int>?>(
        null, (a, e) => a == null || e.value > a.value ? e : a);
    if (best != null) return names[best.key] ?? 'the Steadfast';
    return reignRounds <= 1 ? 'the Brief' : 'the Steadfast';
  }

  /// Seats still loyal to the crown (not the King, not antagonists).
  int get loyalCount => [
        for (int i = 0; i < players.length; i++)
          if (i != kingIndex && !isAntagonist(i)) i
      ].length;

  /// How the story ends, once it does.
  DynastyEnding? get ending {
    if (!isDynasty) return null;
    // The story's end: Karsk conquered, or a peace sealed.
    if (flags.contains('karsk_conquered') ||
        flags.contains('karsk_peace_sealed')) {
      return DynastyEnding.goldenAge;
    }
    if (fallenKings >= maxFallenKings) return DynastyEnding.fallen;
    if (solo) {
      final traitors = court.where((c) => loyaltyOf(c) <= 0).length;
      if (court.length >= 2 && traitors > court.length - traitors) {
        return DynastyEnding.usurped;
      }
    } else if (players.length >= 3 && antagonists.length > loyalCount) {
      return DynastyEnding.usurped;
    }
    return null;
  }

  void _trait(String name, int amount) =>
      traits[name] = (traits[name] ?? 0) + amount;

  /// Seats each player as a courtier: a different shape for everyone.
  void seatCourtiers() {
    courtiers = (Courtier.houses..shuffle()).take(players.length).toList();
    loyalty = List.filled(players.length, startingLoyalty);
    schemeOf = List.filled(players.length, null);
    schemeResult = List.filled(players.length, null);
    powerUsed = List.filled(players.length, false);
    traitorRounds = List.filled(players.length, 0);
    people = [for (final c in courtiers) c.title];
  }

  /// Who sits in [seat]: their courtier title ("The Duke").
  String personAt(int seat) => courtiers[seat].title;

  /// The smallest and largest court in solo Dynasty (not counting you).
  static const minCourt = 1, maxCourt = 6;

  /// Solo Dynasty, between rounds: the court changes with the story.
  /// Traitors who scheme too long flee, courtiers a choice sent away
  /// leave, courtiers the story calls for arrive, and now and then
  /// someone simply moves on or turns up. When the last courtier leaves,
  /// someone new comes.
  void courtChanges([Random? random]) {
    courtNews = [];
    if (!solo) {
      pendingDepartures.clear();
      pendingArrivals.clear();
      return;
    }
    final rand = random ?? Random();
    _ensureCourt();
    _syncStanding();
    final leaving = <Courtier, (String, Exit, bool)>{};
    for (final c in court) {
      if (loyaltyOf(c) <= 0) {
        traitorFor[c.name] = (traitorFor[c.name] ?? 0) + 1;
        if (traitorFor[c.name]! >= 2) {
          leaving[c] = ('${c.title} flees the court before the guards arrive.', Exit.dash, true);
        }
      } else {
        traitorFor.remove(c.name);
      }
    }
    for (final c in pendingDepartures) {
      if (court.contains(c)) {
        leaving[c] = ('${c.title} leaves the court in disgrace.', Exit.banished, true);
      }
    }
    pendingDepartures.clear();
    final coming = [
      for (final c in pendingArrivals)
        if (!court.contains(c) && c != kingRole) c
    ];
    pendingArrivals.clear();
    List<Courtier> free() => [
          for (final c in Courtier.houses)
            if (!court.contains(c) && !coming.contains(c) && c != kingRole) c
        ];
    // The ordinary comings and goings of a court.
    if (leaving.isEmpty && coming.isEmpty && roundNumber >= 3 && rand.nextDouble() < 0.3) {
      final options = free();
      final grow = court.length <= 2 || (court.length < maxCourt && rand.nextBool());
      if (grow && options.isNotEmpty) {
        coming.add(options[rand.nextInt(options.length)]);
      } else if (court.isNotEmpty) {
        final c = court[rand.nextInt(court.length)];
        final why = departures[c]!;
        final (text, exit) = why[rand.nextInt(why.length)];
        leaving[c] = (text, exit, false);
      }
    }
    for (final e in leaving.entries) {
      final c = e.key;
      final (text, exit, _) = e.value;
      courtNews.add(CourtNews(c, colorOf(c).toARGB32(), text, exit: exit));
      court.remove(c);
      standing.remove(c.name);
      schemeBy.remove(c.name);
      traitorFor.remove(c.name);
    }
    // Nobody left at all: someone new arrives.
    if (court.isEmpty && coming.isEmpty) {
      final options = free();
      if (options.isNotEmpty) coming.add(options[rand.nextInt(options.length)]);
    }
    for (final c in coming) {
      _join(c, arrivals[c]!);
    }
  }

  /// [c] joins the court, with [news] to tell of it.
  void _join(Courtier c, String news) {
    if (court.contains(c) || c == kingRole || court.length >= maxCourt) return;
    court.add(c);
    standing[c.name] = startingLoyalty;
    schemeBy.remove(c.name);
    traitorFor.remove(c.name);
    final used = {
      players.isEmpty ? 0 : players.first.color.toARGB32(),
      for (final o in court)
        if (o != c && courtColor[o.name] != null) courtColor[o.name]!,
    };
    courtColor[c.name] = Palette.players
        .firstWhere((p) => !used.contains(p.toARGB32()),
            orElse: () => Palette.players.last)
        .toARGB32();
    courtNews.add(CourtNews(c, courtColor[c.name]!, news));
  }

  /// Who a scene puts at your table: whoever it names (summoned to court
  /// if they're away), the house it charges, or for everyday business a
  /// few of the court. A coronation seats everyone.
  List<Courtier> _castFor(Tiding? t, Random rand) {
    _ensureCourt();
    // A coronation (or a new reign) seats three of the court for the
    // first hand; the whole court watches from the hall.
    if (t == null || t.arc == 'crown') {
      return (List.of(court)..shuffle(rand)).take(3).toList();
    }
    final cast = <Courtier>[
      if (t.house != null) t.house!,
      for (final c in t.cast)
        if (c != t.house) c,
    ]..remove(kingRole);
    for (final c in cast) {
      if (!court.contains(c)) _join(c, '${c.title} is summoned to court.');
    }
    cast.removeWhere((c) => !court.contains(c));
    // Hands of two are rare: most scenes bring two or three of the court
    // to the table.
    final want = rand.nextDouble() < 0.15 ? 1 : 2 + rand.nextInt(2);
    final pool = [for (final c in court) if (!cast.contains(c)) c]..shuffle(rand);
    while (cast.length < want && pool.isNotEmpty) {
      cast.add(pool.removeLast());
    }
    return cast;
  }

  /// Seats you and [cast] at the table for this round.
  void _seatCast(List<Courtier> cast) {
    _syncStanding();
    final you = players.first;
    final mine = courtiers.first;
    final kingLoyalty = loyalty.isEmpty ? startingLoyalty : loyalty.first;
    players = [
      you,
      for (final c in cast) Player(c.title, color: colorOf(c)),
    ];
    courtiers = [mine, ...cast];
    loyalty = [kingLoyalty, for (final c in cast) loyaltyOf(c)];
    schemeOf = [null, for (final c in cast) schemeBy[c.name]];
    final n = players.length;
    schemeResult = List.filled(n, null, growable: true);
    powerUsed = List.filled(n, false, growable: true);
    spoke = List.filled(n, false, growable: true);
    traitorRounds = List.filled(n, 0, growable: true);
    people = [for (final c in courtiers) c.title];
    final m = cards;
    if (m != null && m.players != n) {
      cards = MatchState(players: n, target: m.target)
        ..round = m.round
        ..wins = m.wins
        ..losses = m.losses
        ..streak = m.streak;
    }
  }

  /// The next round of solo Dynasty: the court changes, a scene is set,
  /// and the people it needs sit down at your table.
  void _nextSoloRound(int targetPoints) {
    final king = kingIndex;
    final rand = Random();
    courtChanges(rand);
    roundNumber++;
    tiding = null;
    chargeSeat = null;
    chargeTask = null;
    if (king != null) _pickTiding(rand);
    _seatCast(_castFor(king == null ? null : currentTiding, rand));
    addTasksUntilTarget(players.length, targetPoints, countRound: false);
    kingIndex = king;
    scenePicked = roundNumber;
    if (king != null) {
      _openRoundRest();
      _chooseExile();
      _assignCharge();
      pickTurn = _nextPicker(king - 1);
    }
  }


  bool get isDynasty => mode == GameMode.dynasty;

  /// A courtier who has openly turned against the King.
  bool isAntagonist(int seat) =>
      isDynasty &&
      seat != kingIndex &&
      seat < loyalty.length &&
      loyalty[seat] <= 0;

  List<int> get antagonists =>
      [for (int i = 0; i < players.length; i++) if (isAntagonist(i)) i];

  bool get kingFallen => isDynasty && kingWounds >= kingToughness;

  /// Every antagonist's scheme has been settled for this round.
  bool get schemesSettled =>
      antagonists.every((s) => schemeResult[s] != null);

  /// Settles an antagonist's scheme. A successful scheme wounds the King.
  void resolveScheme(int seat, bool succeeded) {
    if (schemeResult[seat] == succeeded) return;
    if (schemeResult[seat] == true) kingWounds--;
    schemeResult[seat] = succeeded;
    if (succeeded) kingWounds++;
  }

  void togglePower(int seat) => powerUsed[seat] = !powerUsed[seat];

  /// Changes a seat's loyalty; turning to 0 gives them an open scheme,
  /// climbing back above 0 redeems them.
  void _changeLoyalty(int seat, int delta) {
    if (seat == kingIndex) return;
    loyalty[seat] = (loyalty[seat] + delta).clamp(0, maxLoyalty).toInt();
    if (loyalty[seat] <= 0) {
      schemeOf[seat] ??= Random().nextInt(schemes.length);
    } else {
      schemeOf[seat] = null;
    }
  }

  bool _fits(Dilemma d) => solo
      ? [...d.a.effects, ...d.b.effects]
          .whereType<Loyalty>()
          .every((e) => court.contains(e.courtier))
      : [...d.a.effects, ...d.b.effects]
      .whereType<Loyalty>()
      .every((e) => courtiers.contains(e.courtier));

  /// The dilemma after a round: the one this round's tidings lead to,
  /// if its courtiers are at the table, otherwise one at random.
  int pickDilemmaAfter(bool won, [Random? random]) {
    final t = currentTiding;
    final follow = t == null ? null : (won ? t.followWon : t.followLost);
    if (follow != null) {
      final i = dilemmas.indexWhere((d) => d.title == follow);
      // The main story always goes on, whoever is at court.
      if (i >= 0 && (dilemmas[i].arc == mainArc || _fits(dilemmas[i]))) {
        return _face(i);
      }
    }
    return pickDilemma(random);
  }

  /// Carries out the tidings once the round is over. Returns the text.
  String? resolveTiding(bool won) {
    final t = currentTiding;
    if (t == null) return null;
    final o = won ? t.won : t.lost;
    if (!tidingResolved) {
      // Fate, not the King's choice: it doesn't shape their name.
      final kept = Map.of(traits);
      _apply(o.effects);
      traits = kept;
    }
    tidingResolved = true;
    return o.text;
  }

  /// A council vote the King overruled: those who voted the other way
  /// lose faith in the crown.
  void overruled(Iterable<int> seats) {
    for (final s in seats) {
      _changeLoyalty(s, -1);
    }
    _trait('iron', 2);
  }

  /// The King followed the council.
  void heededCouncil() => _trait('kind', 1);

  bool _canBeCharged(int seat) =>
      seat >= 0 && seat != kingIndex && !isAntagonist(seat);

  /// Opens a Dynasty round: draws its tidings (which may bring a decree)
  /// and settles who carries the royal charge.
  void _openRound([Random? random]) {
    // Solo Dynasty chooses its scene before anyone sits down.
    if (!(solo && scenePicked == roundNumber && tiding != null)) {
      _pickTiding(random ?? Random());
    }
    _openRoundRest();
  }

  /// Chooses the round's tidings: the coronation, the next part of the
  /// main story, a story under way, or the everyday news of the realm.
  void _pickTiding(Random rand) {
    bool fits(Tiding t) =>
        t.arc != 'crown' &&
        storyReady(t.title, t.arc, t.requires, t.forbids) &&
        (solo
            // A house the scene needs is summoned, unless it's yours, or
            // it has turned against you. Side news needs them at court.
            ? t.house == null ||
                (t.house != kingRole &&
                    (court.contains(t.house) ? loyaltyOf(t.house!) > 0 : t.arc == mainArc))
            : t.house == null || _canBeCharged(courtiers.indexOf(t.house!)));
    // A story that has moved on comes back to the court first, most of
    // the time.
    final beats = [
      for (int i = 0; i < tidings.length; i++)
        if (tidings[i].requires.isNotEmpty && fits(tidings[i])) i
    ];
    var options = [
      for (int i = 0; i < tidings.length; i++)
        if (fits(tidings[i]) && !facedTidings.contains(i)) i
    ];
    if (options.isEmpty) {
      facedTidings.clear();
      options = [
        for (int i = 0; i < tidings.length; i++)
          if (fits(tidings[i])) i
      ];
    }
    // Solo, the main story moves on most rounds; otherwise every other.
    final mainDue = solo
        ? !(roundNumber >= 3 && rand.nextDouble() < 0.3)
        : roundNumber - mainBeatRound >= 2;
    final mainBeats = beats.where((i) => tidings[i].arc == mainArc);
    final sideBeats = beats.where((i) => tidings[i].arc != mainArc);
    final coronation = tidings.indexWhere((t) => t.arc == 'crown');
    if (roundNumber == reignStartRound && coronation >= 0) {
      // Every reign opens with its coronation.
      tiding = coronation;
    } else if (mainDue && mainBeats.isNotEmpty) {
      tiding = mainBeats.first;
      mainBeatRound = roundNumber;
    } else if (sideBeats.isNotEmpty && rand.nextDouble() < 0.7) {
      tiding = sideBeats.first;
    } else {
      tiding = options.isEmpty ? null : options[rand.nextInt(options.length)];
    }
    if (tiding != null) {
      facedTidings.add(tiding!);
      flags.add('seen:${tidings[tiding!].title}');
    }
  }

  /// The rest of opening a round: its decree and royal charge.
  void _openRoundRest() {
    chargeSeat = null;
    chargeTask = null;
    chargeByKing = false;
    tidingResolved = false;
    final t = currentTiding;
    if (t?.decree != null) {
      decree = t!.decree;
      if (decree == Decree.exile && players.length < 3) decree = null;
    }
    // The King's own charge comes first; otherwise the tidings'.
    final byKing = pendingCharge == null ? -1 : courtiers.indexOf(pendingCharge!);
    pendingCharge = null;
    if (_canBeCharged(byKing)) {
      chargeSeat = byKing;
      chargeByKing = true;
    } else if (t?.house != null) {
      final seat = courtiers.indexOf(t!.house!);
      if (_canBeCharged(seat)) chargeSeat = seat;
    }
  }

  /// Deals the charged house its task: the open task that suits them best.
  void _assignCharge() {
    final seat = chargeSeat;
    if (seat == null || seat == exiledSeat) {
      chargeSeat = null;
      return;
    }
    final open = [
      for (final t in tasks)
        if (t.assignedPlayerIndex == null && canTake(t, seat)) t
    ];
    // Leave at least one task for the others to pick.
    if (open.length < 2) {
      chargeSeat = null;
      return;
    }
    final house = courtiers[seat];
    open.sort((a, b) => houseAffinity(house, b.description)
        .compareTo(houseAffinity(house, a.description)));
    open.first.assignedPlayerIndex = seat;
    chargeTask = open.first.description;
  }

  /// A dilemma whose courtiers are all at the table, not faced recently.
  int pickDilemma([Random? random]) {
    final rand = random ?? Random();
    bool fits(Dilemma d) =>
        !d.followUp &&
        _fits(d) &&
        storyReady(d.title, d.arc, d.requires, d.forbids);
    final ready = [
      for (int i = 0; i < dilemmas.length; i++)
        if (fits(dilemmas[i])) i
    ];
    bool main(int i) => dilemmas[i].arc == mainArc;
    final mainDue = roundNumber - mainBeatRound >= 2;
    int faceMain(int i) {
      mainBeatRound = roundNumber;
      return _face(i);
    }

    // The main story opens once the reign has settled in, and moves on
    // every couple of rounds.
    final opener = ready.where((i) => main(i) && dilemmas[i].requires.isEmpty);
    if (opener.isNotEmpty && roundNumber >= 2) return faceMain(opener.first);
    final mainBeats =
        ready.where((i) => main(i) && dilemmas[i].requires.isNotEmpty);
    if (mainDue && mainBeats.isNotEmpty) return faceMain(mainBeats.first);
    // Side stories under way come next, in the order they're told.
    final sideBeats = [
      for (final i in ready)
        if (!main(i) && dilemmas[i].arc != null && dilemmas[i].requires.isNotEmpty) i
    ];
    if (sideBeats.isNotEmpty && rand.nextDouble() < 0.8) {
      return _face(sideBeats.first);
    }
    // A new side story, if fewer than two are running.
    final openers = [
      for (final i in ready)
        if (!main(i) && dilemmas[i].arc != null && dilemmas[i].requires.isEmpty) i
    ];
    if (openers.isNotEmpty && openStories < 2 && rand.nextDouble() < 0.8) {
      return _face(openers[rand.nextInt(openers.length)]);
    }
    // In solo Dynasty, often a private word with one courtier.
    final audiences = [
      for (final i in ready)
        if (dilemmas[i].audience && !facedDilemmas.contains(i)) i
    ];
    if (solo && audiences.isNotEmpty && rand.nextDouble() < 0.45) {
      return _face(audiences[rand.nextInt(audiences.length)]);
    }
    // Otherwise the everyday business of the court.
    var options = [
      for (final i in ready)
        if (dilemmas[i].arc == null && !facedDilemmas.contains(i)) i
    ];
    if (options.isEmpty) {
      facedDilemmas.removeWhere((i) => dilemmas[i].arc == null);
      options = [for (final i in ready) if (dilemmas[i].arc == null) i];
    }
    if (options.isEmpty) options = ready;
    return _face(options[rand.nextInt(options.length)]);
  }

  /// The story the whole dynasty turns on: Varric of Karsk.
  static const mainArc = 'karsk';

  /// Side stories begun that still have a part to come.
  int get openStories {
    final arcs = <String>{};
    for (final d in dilemmas) {
      final arc = d.arc;
      if (arc == null || arc == mainArc) continue;
      final begun = dilemmas.any((o) =>
          o.arc == arc && o.requires.isEmpty && flags.contains('seen:${o.title}'));
      final more = dilemmas.any((o) =>
          o.arc == arc &&
          o.requires.isNotEmpty &&
          !flags.contains('seen:${o.title}') &&
          storyReady(o.title, o.arc, o.requires, o.forbids));
      if (begun && more) arcs.add(arc);
    }
    return arcs.length;
  }

  int _face(int i) {
    facedDilemmas.add(i);
    flags.add('seen:${dilemmas[i].title}');
    return i;
  }

  /// Carries out the King's choice.
  void applyChoice(Choice choice) => _apply(choice.effects);

  void _apply(List<Effect> effects) {
    for (final e in effects) {
      switch (e) {
        case Charge(:final courtier):
          if (courtiers.contains(courtier)) pendingCharge = courtier;
          _trait('iron', 1);
        case Loyalty(:final courtier, :final delta):
          _changeLoyaltyOf(courtier, delta);
          _trait(delta > 0 ? 'kind' : 'stern', delta.abs());
        case AllLoyalty(:final delta):
          for (int i = 0; i < players.length; i++) {
            _changeLoyalty(i, delta);
          }
          if (solo) {
            for (final c in court) {
              if (!courtiers.contains(c)) _changeLoyaltyOf(c, delta);
            }
          }
          _trait(delta > 0 ? 'kind' : 'stern', 2 * delta.abs());
        case Wound(:final delta):
          kingWounds = max(0, kingWounds + delta);
          _trait(delta > 0 ? 'bold' : 'wise', 2);
        case NextDecree(:final decree):
          pendingDecree = decree;
          _trait('iron', 2);
        case Points(:final delta):
          pointsBonus += delta;
          _trait(delta > 0 ? 'ambitious' : 'wise', delta > 0 ? 2 : 1);
        case Flag(:final name):
          flags.add(name);
        case Unflag(:final name):
          flags.remove(name);
        case Say():
          break;
        case Gold(:final delta):
          coffers += delta;
        case Depart(:final courtier):
          if (courtRoles.contains(courtier)) pendingDepartures.add(courtier);
        case Arrive(:final courtier):
          if (!courtRoles.contains(courtier) && courtier != kingRole) {
            pendingArrivals.add(courtier);
          }
      }
    }
  }

  /// Crowns a new King for a new reign, with a secret toughness of 1 to 3.
  void _beginReign() {
    reign++;
    flags.add('crowned');
    reignName = regnalNames[(reign - 1) % regnalNames.length];
    reignStartRound = roundNumber;
    reignWins = 0;
    traits = {};
    kingWounds = 0;
    kingToughness = 1 + Random().nextInt(3);
    if (kingIndex != null && kingIndex! < loyalty.length) {
      loyalty[kingIndex!] = startingLoyalty;
      schemeOf[kingIndex!] = null;
    }
  }

  /// The King has fallen: the dynasty passes to an heir, crowned next.
  void succession() {
    final king = kingIndex;
    if (king != null) {
      annals.add(Annal(solo ? 'King $reignName' : players[king].name, epithet,
          reignRounds, reign));
    }
    fallenKings++;
    kingIndex = null;
    pickTurn = null;
  }

  /// The next round of a reign: the same King, new tasks.
  void nextDynastyRound(int playerCount, int targetPoints) {
    if (solo) {
      _nextSoloRound(targetPoints);
      return;
    }
    final king = kingIndex;
    courtChanges();
    addTasksUntilTarget(playerCount, targetPoints);
    kingIndex = king;
    tiding = null;
    chargeSeat = null;
    chargeTask = null;
    if (king != null) {
      _openRound();
      _chooseExile();
      _assignCharge();
      pickTurn = _nextPicker(king - 1);
    }
  }

  void _chooseExile() {
    exiledSeat = null;
    final king = kingIndex;
    if (king != null && decree == Decree.exile && players.length >= 3) {
      // Banish someone other than the King.
      final others = [
        for (int i = 0; i < players.length; i++)
          if (i != king && i != chargeSeat && !isAntagonist(i)) i
      ];
      if (others.isNotEmpty) exiledSeat = others[Random().nextInt(others.length)];
    }
  }

  /// The next seat clockwise after [from] that may pick a task.
  int? _nextPicker(int from) {
    // Skip anyone who can't take any of the tasks left.
    for (int step = 1; step <= players.length; step++) {
      final seat = (from + step) % players.length;
      if (seat != exiledSeat &&
          !isAntagonist(seat) &&
          tasks.any((t) => t.assignedPlayerIndex == null && canTake(t, seat))) {
        return seat;
      }
    }
    for (int step = 1; step <= players.length; step++) {
      final seat = (from + step) % players.length;
      if (seat != exiledSeat && !isAntagonist(seat)) return seat;
    }
    return null;
  }

  /// Rounds won in a row, and the best run (kept across games by the app).
  int streak = 0;
  int bestStreak = 0;

  /// Increases every time tasks are dealt or shuffled, so the UI can
  /// animate the change.
  int dealId = 0;
  bool _resultRecorded = false;
  int _streakBefore = 0;
  int _bestBefore = 0;

  static final List<Task> taskPool = _buildTaskPool();

  /// The King holds the King card, the highest card, so whenever they play it they
  /// win that trick and a Court Card with it. These can never be theirs.
  static const _impossibleForTheKing = [
    'Win no Court Cards',
    "Don't win any tricks",
    'Win the Joker and no other Court Card',
    'Win the Jack and no other Court Card',
  ];

  static List<Task> _buildTaskPool() {
    return tasksData
        .map((m) => Task(
              description: m['description'] as String,
              threePlayerPoints: m['three'] as int,
              fourPlayerPoints: m['four'] as int,
              fivePlayerPoints: m['five'] as int,
              sixPlayerPoints: m['six'] as int,
              kingCantTake: ((m['kingCantTake'] as bool?) ?? false) ||
                  _impossibleForTheKing.any(
                      (d) => (m['description'] as String).startsWith(d)),
            ))
        .toList();
  }

  /// A round is won when every task is completed and lost as soon as any
  /// task fails.
  RoundOutcome get outcome {
    if (tasks.isEmpty) return RoundOutcome.inProgress;
    if (tasks.any((t) => t.isFailed)) return RoundOutcome.lost;
    if (tasks.every((t) => t.isCompleted)) return RoundOutcome.won;
    return RoundOutcome.inProgress;
  }

  /// Updates the win/loss record and streak once per round. Returns true if
  /// a result was recorded by this call.
  bool recordOutcomeIfFinished() {
    final o = outcome;
    if (o == RoundOutcome.inProgress || _resultRecorded) return false;
    _streakBefore = streak;
    _bestBefore = bestStreak;
    if (o == RoundOutcome.won) {
      wins++;
      streak++;
      bestStreak = max(bestStreak, streak);
      if (isDynasty) coffers += 3; // a good season's taxes
      if (isDynasty) {
        reignWins++;
        // Five victories in one reign: a golden age, told in the story.
        if (reignWins == goldenAgeWins) flags.add('golden_age');
      }
    } else {
      losses++;
      streak = 0;
      if (isDynasty) kingWounds++;
    }
    if (isDynasty) _tasksFeedLoyalty(o == RoundOutcome.won);
    _resultRecorded = true;
    return true;
  }

  /// Dynasty: deeds win favour. After a won round the courtiers who did
  /// the most tasks gain loyalty; after a lost one, whoever's task failed
  /// loses it.
  void _tasksFeedLoyalty(bool won) {
    _loyaltyBeforeRound = List.of(loyalty);
    final done = List.filled(players.length, 0);
    final failed = List.filled(players.length, false);
    for (final t in tasks) {
      final seat = t.assignedPlayerIndex;
      if (seat == null || seat >= players.length) continue;
      if (t.isCompleted) done[seat]++;
      if (t.isFailed) failed[seat] = true;
    }
    bool counts(int seat) => seat != kingIndex && !isAntagonist(seat);
    final most = [
      for (int i = 0; i < players.length; i++)
        if (counts(i)) done[i]
    ].fold(0, max);
    for (int i = 0; i < players.length; i++) {
      if (!counts(i)) continue;
      if (won && most > 0 && done[i] == most) _changeLoyalty(i, 1);
      // A failed task shakes faith, but only the King's choices make a
      // traitor (so no scheme appears for a round already played).
      if (!won && failed[i] && loyalty[i] > 1) _changeLoyalty(i, -1);
    }
    // The royal charge: done, and the house has served the crown.
    final charge = chargeSeat;
    if (charge != null && counts(charge)) {
      final charged = tasks.where(isCharged);
      if (charged.any((t) => t.isCompleted)) _changeLoyalty(charge, 1);
      if (charged.any((t) => t.isFailed) && loyalty[charge] > 1) {
        _changeLoyalty(charge, -1);
      }
    }
    roundLoyalty = [
      for (int i = 0; i < players.length; i++)
        loyalty[i] - _loyaltyBeforeRound[i]
    ];
  }

  /// Takes the finished round's result back off the record (used when the
  /// last mark is undone).
  void undoOutcome() {
    if (!_resultRecorded) return;
    if (outcome == RoundOutcome.won) {
      wins--;
    } else if (outcome == RoundOutcome.lost) {
      losses--;
      if (isDynasty) kingWounds = max(0, kingWounds - 1);
    }
    if (isDynasty) {
      if (outcome == RoundOutcome.won) reignWins = max(0, reignWins - 1);
      for (int i = 0;
          i < _loyaltyBeforeRound.length && i < loyalty.length;
          i++) {
        _changeLoyalty(i, _loyaltyBeforeRound[i] - loyalty[i]);
      }
      roundLoyalty = [];
    }
    streak = _streakBefore;
    bestStreak = _bestBefore;
    _resultRecorded = false;
  }

  /// Whether [playerIndex] may take [task].
  bool canTake(Task task, int playerIndex) =>
      whyCantTake(task, playerIndex) == null;

  /// Why [seat] can't take [task], or null if they can.
  /// With [publicOnly], nobody's hand is consulted: only what the whole
  /// table can see.
  String? whyCantTake(Task task, int seat, {bool publicOnly = false}) {
    if (seat == exiledSeat) return 'Exiled: no tasks this round';
    if (isAntagonist(seat)) return 'A traitor takes no tasks';
    if (task.kingCantTake && seat == kingIndex) {
      return "The King can't take this task";
    }
    // Someone can't hold two tasks that work against each other.
    for (final o in tasks) {
      if (o != task &&
          o.assignedPlayerIndex == seat &&
          selfClash(o.description, task.description, players: players.length)) {
        return 'That clashes with a task they already hold';
      }
    }
    // On screen the app knows every hand: no task someone's cards make
    // impossible for them (unless nobody else could take it either).
    final m = cards;
    if (!publicOnly && m != null && m.dealId == dealId && seat < m.hands.length) {
      final why = handBlocks(task.description, m.hands[seat]);
      if (why != null) {
        final someoneElse = [
          for (int s = 0; s < players.length && s < m.hands.length; s++)
            if (s != seat &&
                s != exiledSeat &&
                !isAntagonist(s) &&
                !(task.kingCantTake && s == kingIndex) &&
                handBlocks(task.description, m.hands[s]) == null)
              s
        ].isNotEmpty;
        if (someoneElse) return why;
      }
    }
    return null;
  }

  /// Whether [seat] may reveal a card right now, given the decree.
  /// Late Counsel holds every card back until three tricks have been
  /// played (on screen, where the app sees the tricks; at a real table the
  /// players keep to it themselves).
  bool canSpeak(int seat) => switch (decree) {
        Decree.silence => false,
        Decree.lateCounsel =>
          !digital || (cards != null && cards!.dealId == dealId && cards!.tricks.length >= 3),
        _ => true,
      };

  /// Why no card may be shown now, or null if one may.
  String? whyCantSpeak() => switch (decree) {
        Decree.silence => 'Silence is decreed: no cards may be shown this round',
        Decree.lateCounsel when !canSpeak(0) =>
          'Late Counsel: no cards may be shown until three tricks have been played',
        _ => null,
      };

  /// Why completing [task] now would break the seal order, or null if it's
  /// fine. Completing a task out of order fails the round.
  String? sealProblem(Task task) {
    final seal = task.seal;
    if (seal == null) return null;
    if (seal == Seals.last) {
      final open = tasks.where((t) => t != task && !t.isCompleted);
      return open.isEmpty
          ? null
          : 'The Ω seal must be the last task done, and ${open.length} '
              'other task${open.length == 1 ? ' is' : 's are'} still open.';
    }
    final earlier = tasks.where((t) =>
        t.seal != null && t.seal != Seals.last && t.seal! < seal && !t.isCompleted);
    if (earlier.isEmpty) return null;
    final first = earlier.map((t) => t.seal!).reduce(min);
    return 'Seal ${Seals.label(first)} must be done before seal ${Seals.label(seal)}.';
  }

  /// Crowns the King, who picks the first task.
  void setKing(int? index) {
    kingIndex = index;
    // Solo Dynasty: you are the crown itself, above every house.
    if (solo && index != null) {
      _ensureCourt();
      courtiers[index] = Courtier.king;
    }
    if (index != null && isDynasty) {
      _beginReign();
      _openRound();
    }
    _chooseExile();
    if (index != null && isDynasty) _assignCharge();
    assignForced();
    // The King picks first, unless there's nothing they're allowed to take.
    final loose = tasks.where((t) => t.assignedPlayerIndex == null);
    pickTurn = loose.isEmpty || index == null
        ? null
        : loose.any((t) => canTake(t, index))
            ? index
            : _nextPicker(index);
    for (final t in tasks) {
      if (t.assignedPlayerIndex != null && !canTake(t, t.assignedPlayerIndex!)) {
        t.assignedPlayerIndex = null;
      }
    }
  }

  /// Gives [task] to [seat] (or takes it back with null). Picking moves on
  /// clockwise each time a loose task is taken. Returns true when this was
  /// the last task to be taken, so play can begin.
  bool assign(Task task, int? seat) {
    final wasLoose = task.assignedPlayerIndex == null;
    if (seat != null && wasLoose) picksMade++;
    task.assignedPlayerIndex = seat;
    if (seat != null) assignForced();
    final allTaken = tasks.every((t) => t.assignedPlayerIndex != null);
    if (allTaken) {
      final justFinished = pickTurn != null;
      pickTurn = null;
      return justFinished;
    }
    if (decree == Decree.kingsCommand) {
      pickTurn = kingIndex; // the King hands out every task
    } else if (seat != null && wasLoose && pickTurn != null) {
      pickTurn = _nextPicker(pickTurn!);
    } else if (pickTurn == null && kingIndex != null) {
      // A task was handed back after picking finished: picking resumes.
      pickTurn = seat == null ? kingIndex : pickTurn;
    }
    return false;
  }

  /// Tasks taken by a pick this round (not counting ones that went
  /// straight to the only player who could take them).
  int picksMade = 0;

  /// A task only one player can take goes straight to them.
  void assignForced() {
    if (kingIndex == null) return;
    var changed = true;
    while (changed) {
      changed = false;
      for (final t in tasks) {
        if (t.assignedPlayerIndex != null) continue;
        final able = [
          for (int s = 0; s < players.length; s++)
            if (canTake(t, s)) s
        ];
        if (able.length == 1) {
          t.assignedPlayerIndex = able.single;
          changed = true;
        }
      }
    }
    if (tasks.every((t) => t.assignedPlayerIndex != null)) pickTurn = null;
  }

  void toggleSpoke(int seat) => spoke[seat] = !spoke[seat];

  void _resetRoundCounters() {
    picksMade = 0;
    roundLoyalty = [];
    spoke = List.filled(players.length, false);
    powerUsed = List.filled(players.length, false);
    schemeResult = List.filled(players.length, null);
    pickTurn = null;
    passed = {};
  }

  /// Whether [seat] may pass on picking a task right now: it's their turn,
  /// they haven't passed this round, and someone else could pick instead.
  bool canPass(int seat) =>
      pickTurn == seat &&
      !isTutorial &&
      decree != Decree.kingsCommand &&
      !passed.contains(seat) &&
      tasks.any((t) => t.assignedPlayerIndex == null) &&
      _nextPicker(seat) != seat;

  /// [seat] passes: the pick moves on clockwise.
  void pass(int seat) {
    if (!canPass(seat)) return;
    passed.add(seat);
    pickTurn = _nextPicker(seat);
  }

  /// Replays the same tasks in a new round: clears results and assignments.
  void retryRound() {
    tasks = tasks.map((t) => t.freshCopy()).toList();
    kingIndex = null;
    exiledSeat = null;
    roundNumber++;
    dealId++;
    _resultRecorded = false;
    _resetRoundCounters();
  }

  /// Draws a new set of tasks. Starts a new round unless the current round
  /// is still in progress (shuffling mid-round replaces this round's tasks
  /// and the King picks first again).
  void shuffleTasks(int playerCount, int targetPoints) {
    final finished = tasks.isEmpty || outcome != RoundOutcome.inProgress;
    final king = kingIndex;
    final exiled = exiledSeat;
    final keepDecree = decree;
    addTasksUntilTarget(playerCount, targetPoints, newRound: finished);
    if (!finished) {
      roundNumber--; // same round, new tasks
      decree = keepDecree;
      kingIndex = king;
      exiledSeat = exiled;
      pickTurn = king;
    }
  }

  /// Draws random tasks (no repeats) whose points add up to [targetPoints]
  /// for the given player count, or as close as the pool allows.
  ///
  /// A new round also settles its seals and decree: a Chronicle chapter
  /// fixes them; with [surprise] on they're rolled at random.
  void addTasksUntilTarget(int playerCount, int targetPoints,
      {bool newRound = true, bool countRound = true}) {
    tasks.clear();
    kingIndex = null;
    exiledSeat = null;
    if (countRound) roundNumber++;
    dealId++;
    _resultRecorded = false;
    _resetRoundCounters();
    final rand = Random();
    // The tutorial sets its own tasks, with no seals or decrees.
    if (isTutorial) {
      sealCount = 0;
      decree = null;
      final lessonTasks = lessons[max(0, min(lesson, lessons.length - 1))].tasks;
      tasks.addAll([
        for (final d in lessonTasks)
          taskPool.firstWhere((t) => t.description == d).freshCopy()..seal = null
      ]);
      return;
    }
    if (newRound) {
      if (mode == GameMode.chronicle && chapter != null) {
        sealCount = chronicle[chapter!].seals;
        decree = chronicle[chapter!].decree;
      } else if (isDynasty) {
        // Seals come in twos at least: one alone has nothing to order.
        sealCount = rand.nextInt(3) == 0 ? 2 : 0;
        decree = pendingDecree;
        pendingDecree = null;
      } else if (surprise) {
        sealCount = const [0, 0, 2, 3][rand.nextInt(4)];
        decree = rand.nextBool()
            ? Decree.values[rand.nextInt(Decree.values.length)]
            : null;
      } else {
        sealCount = 0;
        decree = null;
      }
      if (decree == Decree.exile && playerCount < 3) decree = Decree.silence;
    }
    // Draw the tasks, and if the round has seals, try a few draws for
    // enough tasks a seal can sit on.
    List<Task> best = const [];
    int bestFree = -1;
    for (int attempt = 0; attempt < 12; attempt++) {
      final drawn = _drawTasks(playerCount, targetPoints, rand);
      final free = drawn.where(_sealable).length;
      if (free > bestFree) {
        best = drawn;
        bestFree = free;
      }
      if (sealCount < 2 || free >= sealCount) break;
    }
    tasks.addAll(best);
    _placeSeals(rand);
  }

  /// A seal orders tasks by when they're done, so it only goes on a task
  /// that can be done on any trick (see [TaskTiming]).
  static bool _sealable(Task t) =>
      timingOf(t.description) == TaskTiming.anyTrick;

  List<Task> _drawTasks(int playerCount, int targetPoints, Random rand) {
    final drawn = <Task>[];
    int currentTotal = 0;
    final pool = drawOrder(taskPool, rand,
        description: (t) => t.description,
        points: (t) => t.getPointsForPlayerCount(playerCount),
        target: targetPoints);
    final hands = playerCount < 3 ? 3 : playerCount;
    for (final task in pool) {
      if (currentTotal >= targetPoints) break;
      final points = task.getPointsForPlayerCount(playerCount);
      if (currentTotal + points > targetPoints) continue;
      // Never deal tasks that can't all be done (see deal_mix.dart).
      if (!fitsDeal([for (final t in drawn) t.description], task.description, hands)) {
        continue;
      }
      drawn.add(task.freshCopy()..seal = null);
      currentTotal += points;
    }
    return drawn;
  }

  /// Puts [sealCount] seals on tasks that can take them. A single seal
  /// orders nothing, so a round has two or none. The Ω seal must be the
  /// last task done, so it's only used when no other task waits for the
  /// round to end; otherwise the seals are all numbered.
  void _placeSeals(Random rand) {
    final free = tasks.where(_sealable).toList()..shuffle(rand);
    final count = min(sealCount, free.length);
    if (count < 2) return;
    final othersWait = tasks.any((t) =>
        !free.take(count).contains(t) &&
        timingOf(t.description) == TaskTiming.end);
    final seals = othersWait
        ? [for (int i = 1; i <= count; i++) i]
        : Seals.forCount(count);
    for (int i = 0; i < seals.length; i++) {
      free[i].seal = seals[i];
    }
  }

  // ------------------------------------------------------------ saving

  Map<String, dynamic> toJson() => {
        'players': [
          for (final p in players)
            {'name': p.name, 'color': p.color.toARGB32()},
        ],
        'tasks': [
          for (final t in tasks)
            {
              'description': t.description,
              'status': t.status.index,
              'owner': t.assignedPlayerIndex,
              'seal': t.seal,
            },
        ],
        'king': kingIndex,
        'round': roundNumber,
        'wins': wins,
        'losses': losses,
        'spoke': spoke,
        'passed': passed.toList(),
        'pickTurn': pickTurn,
        'mode': mode.index,
        'chapter': chapter,
        'lesson': lesson,
        'surprise': surprise,
        'roles': roles,
        'cards': cards?.toJson(),
        'reignWins': reignWins,
        'traits': traits,
        'annals': [for (final a in annals) a.toJson()],
        'tiding': tiding,
        'tidingResolved': tidingResolved,
        'facedTidings': facedTidings,
        'chargeSeat': chargeSeat,
        'chargeTask': chargeTask,
        'chargeByKing': chargeByKing,
        'pendingCharge': pendingCharge?.index,
        'sealCount': sealCount,
        'decree': decree?.index,
        'exiled': exiledSeat,
        'courtiers': [for (final c in courtiers) c.index],
        'loyalty': loyalty,
        'schemeOf': schemeOf,
        'schemeResult': schemeResult,
        'powerUsed': powerUsed,
        'kingWounds': kingWounds,
        'kingToughness': kingToughness,
        'reign': reign,
        'fallenKings': fallenKings,
        'reignStartRound': reignStartRound,
        'pendingDecree': pendingDecree?.index,
        'pointsBonus': pointsBonus,
        'facedDilemmas': facedDilemmas,
        'flags': flags.toList(),
        'people': people,
        'traitorRounds': traitorRounds,
        'pendingDepartures': [for (final c in pendingDepartures) c.name],
        'courtNews': [for (final n in courtNews) n.toJson()],
        'pendingArrivals': [for (final c in pendingArrivals) c.name],
        'reignName': reignName,
        'court': [for (final c in court) c.name],
        'standing': standing,
        'schemeBy': schemeBy,
        'traitorFor': traitorFor,
        'courtColor': courtColor,
        'scenePicked': scenePicked,
        'coffers': coffers,
        'mainBeatRound': mainBeatRound,
        'streak': streak,
        'bestStreak': bestStreak,
        'dealId': dealId,
        'resultRecorded': _resultRecorded,
      };

  /// Rebuilds a saved game. Returns null if the save can't be read (for
  /// example after the task list changed in an update).
  static GameState? fromJson(Map<String, dynamic> j) {
    try {
      final byDescription = {for (final t in taskPool) t.description: t};
      final g = GameState()
        ..players = [
          for (final p in j['players'] as List)
            Player(p['name'] as String, color: Color(p['color'] as int)),
        ]
        ..tasks = [
          for (final t in j['tasks'] as List)
            byDescription[renamedTasks[t['description']] ?? t['description']]!
                .freshCopy()
              ..status = TaskStatus.values[t['status'] as int]
              ..assignedPlayerIndex = t['owner'] as int?
              ..seal = t['seal'] as int?,
        ]
        ..kingIndex = j['king'] as int?
        ..roundNumber = j['round'] as int
        ..wins = j['wins'] as int
        ..losses = j['losses'] as int
        ..spoke = List<bool>.from(j['spoke'] as List)
        ..passed = {for (final s in (j['passed'] as List?) ?? const []) s as int}
        ..pickTurn = j['pickTurn'] as int?
        ..mode = GameMode.values[(j['mode'] as int?) ?? 0]
        ..chapter = j['chapter'] as int?
        ..lesson = (j['lesson'] as int?) ?? 0
        ..surprise = (j['surprise'] as bool?) ?? false
        ..roles = (j['roles'] as bool?) ?? true
        ..cards = j['cards'] == null
            ? null
            : MatchState.fromJson(Map<String, dynamic>.from(j['cards'] as Map))
        ..reignWins = (j['reignWins'] as int?) ?? 0
        ..traits = Map<String, int>.from((j['traits'] as Map?) ?? const {})
        ..tiding = j['tiding'] as int?
        ..tidingResolved = (j['tidingResolved'] as bool?) ?? false
        ..facedTidings =
            List<int>.from((j['facedTidings'] as List?) ?? const [])
        ..chargeSeat = j['chargeSeat'] as int?
        ..chargeTask = j['chargeTask'] as String?
        ..chargeByKing = (j['chargeByKing'] as bool?) ?? false
        ..pendingCharge = j['pendingCharge'] == null
            ? null
            : Courtier.values[j['pendingCharge'] as int]
        ..annals = [
          for (final a in (j['annals'] as List?) ?? const [])
            Annal.fromJson(Map<String, dynamic>.from(a as Map))
        ]
        ..sealCount = (j['sealCount'] as int?) ?? 0
        ..decree = j['decree'] == null ? null : Decree.values[j['decree'] as int]
        ..exiledSeat = j['exiled'] as int?
        ..courtiers = [
          for (final c in (j['courtiers'] as List?) ?? const [])
            Courtier.values[c as int]
        ]
        ..loyalty = List<int>.from((j['loyalty'] as List?) ?? const [])
        ..schemeOf = List<int?>.from((j['schemeOf'] as List?) ?? const [])
        ..schemeResult =
            List<bool?>.from((j['schemeResult'] as List?) ?? const [])
        ..powerUsed = List<bool>.from((j['powerUsed'] as List?) ?? const [])
        ..kingWounds = (j['kingWounds'] as int?) ?? 0
        ..kingToughness = (j['kingToughness'] as int?) ?? 2
        ..reign = (j['reign'] as int?) ?? 0
        ..fallenKings = (j['fallenKings'] as int?) ?? 0
        ..reignStartRound = (j['reignStartRound'] as int?) ?? 0
        ..pendingDecree = j['pendingDecree'] == null
            ? null
            : Decree.values[j['pendingDecree'] as int]
        ..pointsBonus = (j['pointsBonus'] as int?) ?? 0
        ..facedDilemmas =
            List<int>.from((j['facedDilemmas'] as List?) ?? const [])
        ..flags = Set<String>.from((j['flags'] as List?) ?? const [])
        ..people = List<String>.from((j['people'] as List?) ?? const [])
        ..traitorRounds = List<int>.from((j['traitorRounds'] as List?) ?? const [])
        ..pendingDepartures = [
          for (final n in (j['pendingDepartures'] as List?) ?? const [])
            Courtier.values.firstWhere((c) => c.name == n)
        ]
        ..courtNews = [
          for (final m in (j['courtNews'] as List?) ?? const [])
            CourtNews.fromJson(Map<String, dynamic>.from(m as Map))
        ]
        ..pendingArrivals = [
          for (final n in (j['pendingArrivals'] as List?) ?? const [])
            Courtier.values.byName(n as String)
        ]
        ..reignName = (j['reignName'] as String?) ?? ''
        ..court = [
          for (final n in (j['court'] as List?) ?? const [])
            Courtier.values.byName(n as String)
        ]
        ..standing = Map<String, int>.from((j['standing'] as Map?) ?? const {})
        ..schemeBy = Map<String, int>.from((j['schemeBy'] as Map?) ?? const {})
        ..traitorFor = Map<String, int>.from((j['traitorFor'] as Map?) ?? const {})
        ..courtColor = Map<String, int>.from((j['courtColor'] as Map?) ?? const {})
        ..scenePicked = (j['scenePicked'] as int?) ?? -1
        ..coffers = (j['coffers'] as int?) ?? 12
        ..mainBeatRound = (j['mainBeatRound'] as int?) ?? -99
        ..streak = j['streak'] as int
        ..bestStreak = j['bestStreak'] as int
        ..dealId = j['dealId'] as int;
      g._resultRecorded = j['resultRecorded'] as bool;
      if (g.players.isEmpty || g.tasks.isEmpty) return null;
      if (g.courtiers.length != g.players.length) g.seatCourtiers();
      // Saves from before people came and went.
      if (g.traitorRounds.length != g.players.length) {
        g.traitorRounds = List.filled(g.players.length, 0);
      }
      if (g.people.length != g.players.length) {
        g.people = [for (final c in g.courtiers) c.title];
      }
      if (g.tiding != null && g.tiding! >= tidings.length) g.tiding = null;
      return g;
    } catch (_) {
      return null;
    }
  }
}

/// Short labels for seat tokens and the owner badge on cards. Default
/// names ("Player 3") show the seat number; real names show initials. If
/// two players would share a label, they get the first two letters of
/// their name instead, and failing that their seat number.
List<String> seatLabels(List<Player> players) {
  final defaultName = RegExp(r'^player \d+$', caseSensitive: false);
  String initials(String name) {
    // "The General" is G: the article isn't part of the name.
    final words = name
        .replaceFirst(RegExp(r'^the\s+', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  final labels = <String>[
    for (int i = 0; i < players.length; i++)
      () {
        final name = players[i].name.trim();
        return name.isEmpty || defaultName.hasMatch(name)
            ? '${i + 1}'
            : initials(name);
      }(),
  ];

  for (int pass = 0; pass < 2; pass++) {
    final counts = <String, int>{};
    for (final l in labels) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    for (int i = 0; i < labels.length; i++) {
      if (counts[labels[i]]! < 2) continue;
      final name = players[i]
          .name
          .trim()
          .replaceFirst(RegExp(r'^the\s+', caseSensitive: false), '');
      labels[i] = pass == 0 && name.length >= 2 && !defaultName.hasMatch(name)
          ? '${name[0].toUpperCase()}${name[1].toLowerCase()}'
          : '${i + 1}';
    }
  }
  return labels;
}
