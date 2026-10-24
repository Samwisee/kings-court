import 'chronicle.dart';
import 'courtiers.dart';

/// What happens when a round's tidings are won or lost.
class Outcome {
  const Outcome(this.text, [this.effects = const []]);
  final String text;
  final List<Effect> effects;
}

/// News that opens a Dynasty round and gives it a reason. A tiding may
/// charge one house with a task (dealt straight to them), bring a decree,
/// and leads to the dilemma that follows: what happens next depends on
/// whether the court succeeded.
class Tiding {
  const Tiding(
    this.title,
    this.story, {
    this.house,
    this.charge,
    this.decree,
    required this.won,
    required this.lost,
    this.followWon,
    this.followLost,
    this.arc,
    this.requires = const [],
    this.forbids = const [],
  });
  final String title;
  final String story;

  /// The house charged with a task this round, if any.
  final Courtier? house;

  /// What the charge means in the story, read out with the tidings.
  final String? charge;
  final Decree? decree;
  final Outcome won;
  final Outcome lost;

  /// Titles of the dilemmas that follow a won or lost round.
  final String? followWon;
  final String? followLost;

  /// The story this belongs to; it comes up once, when its [requires]
  /// flags are set (see Dilemma.arc).
  final String? arc;
  final List<String> requires;
  final List<String> forbids;
}

const tidings = <Tiding>[
  Tiding(
    'Bandits on the North Road',
    'Wagons bound for the capital are burning on the north road.',
    house: Courtier.duke,
    charge: 'The Duke must clear the road with his own riders.',
    won: Outcome('The road is safe. Ashcombe banners fly over the passes.',
        [Loyalty(Courtier.duke, 1)]),
    lost: Outcome('The bandits grow bold and raid the royal wagons.',
        [Points(1)]),
    followLost: 'The Bandit Lord',
  ),
  Tiding(
    'The Northern Claim',
    'An old treaty has turned up in the archives. It names Ashcombe as lords of the north.',
    house: Courtier.duke,
    charge: 'The Duke must prove the treaty true before the court.',
    won: Outcome('The treaty holds. The Duke stands taller than ever.'),
    lost: Outcome('The treaty is laughed out of the hall.',
        [Loyalty(Courtier.duke, -1)]),
    followWon: 'Lands in the North',
  ),
  Tiding(
    'Relics from the South',
    'Holy relics are travelling north to the great cathedral.',
    house: Courtier.bishop,
    charge: 'The Bishop must see the relics safely to the altar.',
    won: Outcome('The bells of Vell ring for a day and a night.',
        [Loyalty(Courtier.bishop, 1), Wound(-1)]),
    lost: Outcome('The relics are lost on the road.'),
    followLost: 'The Curse of the Relics',
  ),
  Tiding(
    'A Preacher in the Square',
    'A wild-eyed preacher draws crowds, and calls the Bishop a fraud.',
    house: Courtier.bishop,
    charge: 'The Bishop must win the crowd back to the cathedral.',
    won: Outcome('The square empties. The pews fill.'),
    lost: Outcome('The crowds grow. So does the Bishop’s anger.'),
    followLost: 'A Heretic Preacher',
  ),
  Tiding(
    'Border Skirmish',
    'Enemy banners have been seen beneath the eastern fort.',
    house: Courtier.general,
    charge: 'The General must hold the fort at any cost.',
    won: Outcome('The fort holds. Strand soldiers toast your name.',
        [Loyalty(Courtier.general, 1)]),
    lost: Outcome('The fort falls. Refugees stream towards the city.',
        [AllLoyalty(-1)]),
    followWon: 'Spoils of War',
    followLost: 'The Fallen Fort',
  ),
  Tiding(
    'War Drums',
    'A rival kingdom is gathering its armies across the river.',
    house: Courtier.general,
    charge: 'The General must drill the army day and night.',
    won: Outcome('Your army is ready, and the General is eager.'),
    lost: Outcome('The drills go badly. The soldiers mutter.',
        [Loyalty(Courtier.general, -1)]),
    followWon: 'War Drums',
  ),
  Tiding(
    'A Foreign Envoy',
    'An envoy arrives smiling, with gifts and too many questions.',
    house: Courtier.spymaster,
    charge: 'The Spymaster must learn what the envoy truly wants.',
    decree: Decree.silence,
    won: Outcome('The envoy’s secrets are yours.',
        [Loyalty(Courtier.spymaster, 1)]),
    lost: Outcome('The envoy leaves knowing more than they came with.',
        [Points(1)]),
    followWon: 'The Envoy’s Secret',
  ),
  Tiding(
    'Letters from a Dead Prince',
    'Letters signed by a prince who died years ago are passing hand to hand.',
    house: Courtier.spymaster,
    charge: 'The Spymaster must find the forger.',
    won: Outcome('The forger is found, and it is someone close.'),
    lost: Outcome('The letters spread. Some believe them.'),
    followWon: 'The Forger Found',
    followLost: 'The Pretender',
  ),
  Tiding(
    'The Harbour Fair',
    'Ships from six kingdoms crowd the harbour for the great fair.',
    house: Courtier.merchant,
    charge: 'The Merchant must make the fair turn a profit.',
    won: Outcome('Coyne coffers overflow, and some of it reaches yours.',
        [Loyalty(Courtier.merchant, 1), Points(-1)]),
    lost: Outcome('The fair is a ruin.'),
    followLost: 'The Merchant’s Debt',
  ),
  Tiding(
    'The Masque',
    'The court holds a masked ball. Under the masks, old grudges stir.',
    house: Courtier.jester,
    charge: 'The Jester must keep the masque from turning into a brawl.',
    won: Outcome('Laughter fills the hall until dawn.',
        [AllLoyalty(1), Arrive(Courtier.merchant)]),
    lost: Outcome('Masks come off, and so do the gloves.'),
    followLost: 'Who Struck First?',
  ),
  Tiding(
    'A Royal Wedding',
    'Two great families marry under your roof. Every guest must be seated just so.',
    decree: Decree.kingsCommand,
    won: Outcome('The feast is talked of for years.',
        [AllLoyalty(1), Arrive(Courtier.duke)]),
    lost: Outcome('The wedding ends in insults.', [AllLoyalty(-1)]),
    followWon: 'A Grand Tournament',
  ),
  Tiding(
    'Storm Season',
    'Storms batter the coast. The fishing boats stay in harbour.',
    won: Outcome('The granaries hold. The city eats.'),
    lost: Outcome('The city goes hungry.'),
    followLost: 'Famine',
  ),
  Tiding(
    'Fever in the Palace',
    'A fever sweeps the palace corridors. The King feels it too.',
    won: Outcome('The fever passes, and you with it.', [Wound(-1)]),
    lost: Outcome('The fever lingers in your bones.'),
    followLost: 'The Royal Physician',
  ),
  Tiding(
    'Whispers of Treason',
    'Someone at court is plotting. Every conversation stops when you enter.',
    decree: Decree.lateCounsel,
    won: Outcome('The plot is uncovered in time.'),
    lost: Outcome('The whispers grow into a plan.'),
    followWon: 'An Assassin Caught',
    followLost: 'A Poisoned Cup',
  ),
  Tiding(
    'Sickness Beyond the Walls',
    'Smoke rises from the villages. The sick are walking towards the city.',
    won: Outcome('The sickness is held at bay.'),
    lost: Outcome('The sickness reaches the gates.'),
    followLost: 'Plague in the Villages',
  ),
  Tiding(
    'The Exile’s Return',
    'A banished lord rides back to court, demanding his place.',
    decree: Decree.exile,
    won: Outcome('He bends the knee, for now.'),
    lost: Outcome('He takes his old seat, and the court takes sides.',
        [AllLoyalty(-1)]),
    followLost: 'Council of Advisors',
  ),
  // ------------------------------------------------------------- stories
  Tiding(
    'Coronation Day',
    'Bells ring across the city. Every house has come to kneel before the new King, and to take their measure.',
    won: Outcome('The feast goes on until dawn. The court leaves in good spirits.',
        [AllLoyalty(1)]),
    lost: Outcome('Whispers follow you from the feast: too young, too weak, too soon.',
        [AllLoyalty(-1)]),
    arc: 'crown',
  ),
  Tiding(
    'The Siege of Ashford',
    'Varric of Karsk has crossed the river. His army is camped beneath Ashford’s walls.',
    house: Courtier.general,
    charge: 'The General must break the siege.',
    won: Outcome('Karsk banners burn in the river. Ashford holds.',
        [Flag('ashford_held'), Loyalty(Courtier.general, 1)]),
    lost: Outcome('Ashford falls. The road to the capital lies open.',
        [Flag('ashford_burned'), Wound(1)]),
    arc: 'karsk',
    requires: ['karsk_defied', 'walls'],
    forbids: ['karsk_peace'],
  ),
  Tiding(
    'The Crown of Karsk',
    'Your army stands before Varric’s own castle. One last push.',
    house: Courtier.general,
    charge: 'The General must lead the final assault.',
    won: Outcome('Varric kneels. Karsk is yours.',
        [AllLoyalty(1), Wound(-1), Flag('karsk_conquered')]),
    lost: Outcome('The assault breaks. You are carried from the field.',
        [Wound(1), Loyalty(Courtier.general, -1)]),
    arc: 'karsk',
    requires: ['karsk_war'],
  ),
  Tiding(
    'Storm off the Cape',
    'Word comes that the Coyne fleet is caught in a storm off the southern cape.',
    house: Courtier.merchant,
    charge: 'The Merchant must bring the fleet home.',
    won: Outcome('The fleet limps home, holds full of silk and spice.',
        [Wound(-1), Loyalty(Courtier.merchant, 1), Flag('fleet_home')]),
    lost: Outcome('Wreckage washes ashore for a week.',
        [Flag('fleet_lost')]),
    arc: 'fleet',
    requires: ['fleet'],
  ),
  Tiding(
    'The Spire Rises',
    'The cathedral’s great spire is to be raised. Every mason in the realm is on the ropes.',
    house: Courtier.bishop,
    charge: 'The Bishop must see the spire raised.',
    won: Outcome('The bells of Vell ring over the city.',
        [Loyalty(Courtier.bishop, 1), Flag('cathedral_done')]),
    lost: Outcome('The scaffolding falls. Masons are buried in the rubble.',
        [AllLoyalty(-1)]),
    arc: 'cathedral',
    requires: ['cathedral'],
  ),
  Tiding(
    'Varric’s Spies',
    'Your agents in Karsk send word: Varric plans to strike at the fords on the new moon.',
    house: Courtier.spymaster,
    charge: 'The Spymaster must get the warning to the fords in time.',
    won: Outcome('The ambush is ambushed. Varric loses a thousand men.',
        [Flag('ashford_held'), Loyalty(Courtier.spymaster, 1)]),
    lost: Outcome('Your agents are caught and hanged on the bridge.',
        [Loyalty(Courtier.spymaster, -1)]),
    arc: 'karsk',
    requires: ['spies', 'karsk_defied'],
  ),
  Tiding(
    'Sickness in the Lower Town',
    'People in the lower town are falling sick. The Bishop’s monks are nursing them.',
    house: Courtier.bishop,
    charge: 'The Bishop must keep the sickness from spreading.',
    won: Outcome('The fevers break. The lower town lives.'),
    lost: Outcome('The sickness climbs the hill towards the palace.',
        [Flag('plague')]),
    arc: 'plague',
  ),
];

/// How well a task suits each house, so a royal charge feels in
/// character: the General gets the fights over Court Cards, the
/// Spymaster the tasks about holding back, and so on.
int houseAffinity(Courtier house, String task) {
  final patterns = switch (house) {
    Courtier.duke => [r'King', r'more tricks than', r'K♠'],
    Courtier.bishop => [r'first trick', r'last trick', r'in a row', r'first five'],
    Courtier.general => [r'Court Card', r'Joker', r'J♠', r'Q♠', r'with a'],
    Courtier.spymaster => [r"Don't", r'\bno\b', r'fewer', r'secret', r'exactly'],
    Courtier.merchant => [r'totalling', r'at least', r'as many', r'9s', r'even'],
    Courtier.jester => [r'mixed', r'odd', r'only', r'lower than', r'exactly one'],
  };
  return patterns.where((p) => RegExp(p).hasMatch(task)).length;
}
