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
    this.cast = const [],
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

  /// Solo Dynasty: who sits at your table for this scene (as well as the
  /// house charged). Empty means a few of the court.
  final List<Courtier> cast;
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

  // The main story, in the order it's told. It begins with the harvest
  // and ends in war (or peace) with King Varric of Karsk.
  //
  // Act I: the harvest.
  Tiding(
    'The Harvest Count',
    'Before winter, every granary in the realm must be counted. The Merchant has the ledgers; you have the keys.',
    house: Courtier.merchant,
    charge: 'The Merchant must make the numbers add up.',
    won: Outcome('The granaries are full. There is grain to spare.',
        [Flag('grain_surplus'), Gold(2)]),
    lost: Outcome('The count comes up short. It will be a hungry winter.',
        [Flag('grain_short')]),
    followWon: 'Surplus Grain',
    followLost: 'Famine',
    arc: 'karsk',
    requires: ['crowned'],
  ),
  Tiding(
    'Roads to Market',
    'The harvest must reach the markets before it rots, but the north road is in ruins and the Duke’s tolls are steep.',
    house: Courtier.duke,
    cast: [Courtier.merchant],
    charge: 'The Duke must get the wagons through.',
    won: Outcome('The wagons roll. The markets are full and noisy.',
        [Loyalty(Courtier.duke, 1)]),
    lost: Outcome('Wagons sink in the mud. Bandits pick over what is left.',
        [Flag('bandits')]),
    followWon: 'Mira of Ashford',
    followLost: 'The Bandit Lord',
    arc: 'karsk',
    requires: ['seen:The Harvest Count'],
  ),
  // Act II: the envoy.
  Tiding(
    'Riders from Karsk',
    'Riders under the black boar of Karsk have crossed the river. They say they bring an envoy, and come in peace.',
    house: Courtier.spymaster,
    charge: 'The Spymaster must learn what Varric wants before his envoy speaks.',
    won: Outcome('You know Varric’s price before his envoy names it.',
        [Loyalty(Courtier.spymaster, 1)]),
    lost: Outcome('The envoy arrives knowing more about your court than you do.'),
    followWon: 'An Envoy from Karsk',
    followLost: 'An Envoy from Karsk',
    arc: 'karsk',
    requires: ['seen:Roads to Market'],
  ),
  Tiding(
    'The Tribute Wagons',
    'The first tribute must reach Karsk by the new moon, and the treasury is thin.',
    house: Courtier.merchant,
    cast: [Courtier.duke],
    charge: 'The Merchant must find the gold.',
    won: Outcome('The gold reaches Varric. For now, Karsk is quiet.', [Gold(-4)]),
    lost: Outcome('The wagons are late, and Varric’s patience is short.',
        [Points(1)]),
    followWon: 'Tribute Doubled',
    followLost: 'Tribute Doubled',
    arc: 'karsk',
    requires: ['karsk_paid'],
  ),
  Tiding(
    'Watch on the River',
    'Karsk scouts swim the fords at night. Every crossing must be watched.',
    house: Courtier.general,
    cast: [Courtier.spymaster],
    charge: 'The General must hold the river line.',
    won: Outcome('Your patrols catch three scouts. Varric is blind.',
        [Loyalty(Courtier.general, 1)]),
    lost: Outcome('The scouts come and go as they please.'),
    followWon: 'Scouts on the River',
    followLost: 'Scouts on the River',
    arc: 'karsk',
    requires: ['karsk_defied'],
    forbids: ['karsk_peace', 'ashford_held', 'ashford_burned'],
  ),
  // Act III: war.
  Tiding(
    'The Siege of Ashford',
    'Varric of Karsk has crossed the river. His army is camped beneath Ashford’s new walls.',
    house: Courtier.general,
    cast: [Courtier.duke],
    charge: 'The General must break the siege.',
    won: Outcome('Karsk banners burn in the river. Ashford holds.',
        [Flag('ashford_held'), Loyalty(Courtier.general, 1)]),
    lost: Outcome('Ashford falls. The road to the capital lies open.',
        [Flag('ashford_burned'), Wound(1)]),
    followWon: 'Spoils of War',
    arc: 'karsk',
    requires: ['karsk_defied', 'walls'],
    forbids: ['karsk_peace', 'ashford_held', 'ashford_burned'],
  ),
  Tiding(
    'Varric’s Spies',
    'Your agents in Karsk send word: Varric will strike at the fords on the new moon.',
    house: Courtier.spymaster,
    cast: [Courtier.general],
    charge: 'The Spymaster must get the warning to the fords in time.',
    won: Outcome('The ambush is ambushed. Varric loses a thousand men.',
        [Flag('ashford_held'), Loyalty(Courtier.spymaster, 1)]),
    lost: Outcome('Your agents are caught and hanged on the bridge, and Ashford burns.',
        [Flag('ashford_burned'), Loyalty(Courtier.spymaster, -1)]),
    arc: 'karsk',
    requires: ['spies', 'karsk_defied'],
    forbids: ['karsk_peace', 'ashford_held', 'ashford_burned'],
  ),
  Tiding(
    'The War Council',
    'Varric’s army is broken, but not beaten. Your captains gather around the map table.',
    house: Courtier.general,
    cast: [Courtier.duke, Courtier.spymaster],
    charge: 'The General must make the plan.',
    won: Outcome('The plan is sound. Karsk trembles.', [Points(-1)]),
    lost: Outcome('The council argues until dawn, and agrees on nothing.'),
    followWon: 'Varric Sues for Peace',
    followLost: 'Varric Sues for Peace',
    arc: 'karsk',
    requires: ['ashford_held'],
    forbids: ['karsk_peace', 'karsk_war'],
  ),
  Tiding(
    'Refugees on the Road',
    'Thousands flee the ashes of Ashford towards the capital, with Karsk riders behind them.',
    house: Courtier.bishop,
    cast: [Courtier.duke],
    charge: 'The Bishop must shelter the refugees.',
    won: Outcome('The refugees are fed and housed in the cathedral close.',
        [Flag('refugees')]),
    lost: Outcome('Sickness spreads through the camps.', [Flag('plague')]),
    followWon: 'The Ashes of Ashford',
    followLost: 'The Price of Peace',
    arc: 'karsk',
    requires: ['ashford_burned'],
    forbids: ['karsk_peace', 'karsk_war'],
  ),
  Tiding(
    'The Peace Treaty',
    'Two kingdoms must agree on every word of the treaty, and neither trusts the other with the pen.',
    house: Courtier.duke,
    cast: [Courtier.spymaster, Courtier.merchant],
    charge: 'The Duke must see the treaty signed.',
    won: Outcome('The treaty is signed. Bells ring on both banks of the river.',
        [Flag('treaty_signed')]),
    lost: Outcome('The talks collapse in insults, and the armies march again.',
        [Unflag('karsk_peace'), Flag('karsk_war')]),
    followWon: 'A Feast for Two Kingdoms',
    arc: 'karsk',
    requires: ['karsk_peace'],
  ),
  Tiding(
    'The Crown of Karsk',
    'Your army stands before Varric’s own castle. One last push.',
    house: Courtier.general,
    cast: [Courtier.duke, Courtier.spymaster, Courtier.merchant],
    charge: 'The General must lead the final assault.',
    won: Outcome('Varric kneels in the snow. Karsk is yours.',
        [AllLoyalty(1), Wound(-1), Flag('karsk_conquered')]),
    lost: Outcome('The assault breaks. You are carried from the field.',
        [Wound(1), Loyalty(Courtier.general, -1)]),
    followLost: 'A Long War',
    arc: 'karsk',
    requires: ['karsk_war'],
  ),

  // Side stories.
  Tiding(
    'A Golden Age',
    'Five victories in one reign. Poets are already at work on your name.',
    won: Outcome('Every house drinks to you. Your wounds feel lighter.',
        [AllLoyalty(1), Wound(-1)]),
    lost: Outcome('Even a golden age has its bad days.'),
    arc: 'golden',
    requires: ['golden_age'],
  ),
  Tiding(
    'Storm off the Cape',
    'Word comes that the Coyne fleet is caught in a storm off the southern cape.',
    house: Courtier.merchant,
    charge: 'The Merchant must bring the fleet home.',
    won: Outcome('The fleet limps home, holds full of silk and spice.',
        [Wound(-1), Loyalty(Courtier.merchant, 1), Flag('fleet_home'), Gold(8)]),
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
    Courtier.duke => ['King', 'more tricks than', 'King card'],
    Courtier.bishop => ['first trick', 'last trick', 'in a row', 'first five'],
    Courtier.general => ['Court Card', 'Joker', 'Jack', 'Queen', 'with a'],
    Courtier.spymaster => ["Don't", r'\bno\b', 'fewer', 'secret', 'exactly'],
    Courtier.merchant => ['totalling', 'at least', 'as many', '9s', 'even'],
    Courtier.jester => ['mixed', 'odd', 'only', 'lower than', 'exactly one'],
    Courtier.king => const <String>[],
  };
  return patterns.where((p) => RegExp(p).hasMatch(task)).length;
}
