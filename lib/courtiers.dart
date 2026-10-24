import 'chronicle.dart';

/// Token outlines, so every seat can be told apart by shape as well as
/// colour.
enum TokenShape { shield, arch, hexagon, diamond, octagon, star }

/// The courtiers who sit at the King's table. With roles on (always in
/// Dynasty) each seat is one of them: a house with a sigil (the token's
/// shape), a motto, a little history and a once-per-round power.
enum Courtier {
  duke(
    'The Duke',
    TokenShape.shield,
    'Command',
    'Once per round, before the first trick, give one of your tasks to another player.',
    house: 'House Ashcombe',
    motto: 'What we hold, we keep.',
    story:
        'Old blood and older land. The Ashcombes have guarded the northern march for nine generations, and never let a King forget it.',
  ),
  bishop(
    'The Bishop',
    TokenShape.arch,
    'Absolution',
    'Once per round, when a task fails, set it aside, but take a penance: draw a task worth at least as many points that you can still do, and do it this round.',
    house: 'House Vell',
    motto: 'Light before the throne.',
    story:
        'The Vells raised the great cathedral and ring its bells. They anoint every King, and remind each one whose hand held the oil.',
  ),
  general(
    'The General',
    TokenShape.hexagon,
    'Vanguard',
    'Once per round, lead a trick even though you did not win the last one.',
    house: 'House Strand',
    motto: 'Steel answers.',
    story:
        'Soldiers risen from the ranks. Every Strand has bled for the crown, and every Strand expects the crown to remember.',
  ),
  spymaster(
    'The Spymaster',
    TokenShape.diamond,
    'Whisper',
    'Once per round, name a player and a suit. They must say truthfully whether they hold any cards of it.',
    house: 'House Morrow',
    motto: 'Every wall has ears.',
    story:
        'No one is sure where the Morrows came from. They know everyone\'s secrets, and keep their own.',
  ),
  merchant(
    'The Merchant',
    TokenShape.octagon,
    'Trade',
    'Once per round, swap one card from your hand, face down, with a player next to you. Court Cards cannot be traded.',
    house: 'House Coyne',
    motto: 'All things have a price.',
    story:
        'The Coynes own the harbour, the mint and half the debts in the kingdom, some of them the King\'s.',
  ),
  jester(
    'The Jester',
    TokenShape.star,
    'Jest',
    'Once per round, swap two open tasks between any two players.',
    house: 'House Motley',
    motto: 'Laugh, lest you weep.',
    story:
        'A house of one, with a borrowed name. The Jester says what no one else dares, and somehow keeps their head.',
  );

  const Courtier(this.title, this.shape, this.power, this.powerRule,
      {required this.house, required this.motto, required this.story});
  final String title;
  final TokenShape shape;
  final String power;
  final String powerRule;
  final String house;
  final String motto;
  final String story;

  /// "Duke", for short lines like "the Duke will remember this".
  String get short => title.replaceFirst('The ', '');
}

/// How loyal a courtier is, in a word rather than a number.
String loyaltyWord(int loyalty) => switch (loyalty) {
      <= 0 => 'Traitor',
      1 => 'Restless',
      2 => 'Wavering',
      3 => 'Steady',
      4 => 'Loyal',
      _ => 'Devoted',
    };

/// How a Dynasty can end.
enum DynastyEnding {
  goldenAge(
    'A Golden Age',
    'One King has ruled long and well. Songs will be sung of this court for a hundred years.',
  ),
  fallen(
    'The Dynasty Falls',
    'Too many Kings have died. The crown passes to strangers, and your houses scatter.',
  ),
  usurped(
    'Usurped',
    'The traitors now outnumber the loyal. They storm the hall and take the throne for themselves.',
  );

  const DynastyEnding(this.title, this.story);
  final String title;
  final String story;
}

/// A King remembered in the annals of the dynasty.
class Annal {
  const Annal(this.name, this.epithet, this.rounds, this.reign);
  final String name;
  final String epithet;
  final int rounds;
  final int reign;

  Map<String, dynamic> toJson() =>
      {'name': name, 'epithet': epithet, 'rounds': rounds, 'reign': reign};
  static Annal fromJson(Map<String, dynamic> j) => Annal(j['name'] as String,
      j['epithet'] as String, j['rounds'] as int, j['reign'] as int);
}

/// A scheme an antagonist works towards, openly, against the court. If it
/// succeeds the King takes a wound, even if every task is done.
const schemes = <String>[
  'Win the trick that the K♠ is played in.',
  'The King must win no tricks at all.',
  'Win the last trick of the round.',
  'Win more tricks than the King.',
  'Win at least two Court Cards.',
  'Win the first trick and the last trick.',
  'The King must win exactly one trick.',
  'Win three tricks in a row.',
];

/// Something a dilemma choice does to the court.
sealed class Effect {
  const Effect();
}

/// Raises or lowers a courtier's loyalty. At 0 they turn against the King.
class Loyalty extends Effect {
  const Loyalty(this.courtier, this.delta);
  final Courtier courtier;
  final int delta;
}

/// Changes every courtier's loyalty at once.
class AllLoyalty extends Effect {
  const AllLoyalty(this.delta);
  final int delta;
}

/// Heals (negative) or inflicts (positive) wounds on the King.
class Wound extends Effect {
  const Wound(this.delta);
  final int delta;
}

/// Puts a decree in force for the next round.
class NextDecree extends Effect {
  const NextDecree(this.decree);
  final Decree decree;
}

/// Changes the next round's points target.
class Points extends Effect {
  const Points(this.delta);
  final int delta;
}

/// A royal charge: next round this house is handed a task by the King
/// and must see it done. Success wins favour, failure loses it.
class Charge extends Effect {
  const Charge(this.courtier);
  final Courtier courtier;
}

/// Remembers something for the story to come back to ("walls_built").
class Flag extends Effect {
  const Flag(this.name);
  final String name;
}

/// Forgets a story flag.
class Unflag extends Effect {
  const Unflag(this.name);
  final String name;
}

/// A courtier speaks up about the King's choice (if they're at the table).
class Say extends Effect {
  const Say(this.courtier, this.line);
  final Courtier courtier;
  final String line;
}

class Choice {
  const Choice(this.label, this.outcome, this.effects);
  final String label;

  /// What happens, read aloud after choosing.
  final String outcome;
  final List<Effect> effects;
}

/// A decision the King must make between rounds. [about] is the courtier
/// the story is about; dilemmas about courtiers not at the table are
/// skipped.
class Dilemma {
  const Dilemma(this.title, this.story, this.a, this.b,
      {this.about,
      this.council = false,
      this.followUp = false,
      this.arc,
      this.speaker,
      this.requires = const [],
      this.forbids = const []});
  final String title;
  final String story;
  final Choice a;
  final Choice b;
  final Courtier? about;

  /// A matter for the whole court: every loyal courtier votes, and the
  /// King follows the court or overrules it.
  final bool council;

  /// Only comes up after the tidings that lead to it, never at random.
  final bool followUp;

  /// The story this belongs to, if any. A story's matters come up once
  /// each, in order, as its [requires] flags are earned.
  final String? arc;

  /// Who brings the matter before the throne, if not a courtier.
  final String? speaker;

  /// Story flags that must all be set, and any that rule it out.
  final List<String> requires;
  final List<String> forbids;
}

const dilemmas = <Dilemma>[
  Dilemma(
    'Lands in the North',
    'The Duke demands the northern estates as reward for his service.',
    Choice('Grant the lands', 'The Duke bows low. The treasury groans.',
        [Loyalty(Courtier.duke, 2), Points(1), Charge(Courtier.duke)]),
    Choice('Refuse him', 'The Duke leaves the hall without a word.',
        [Loyalty(Courtier.duke, -2)]),
    about: Courtier.duke,
  ),
  Dilemma(
    'A Heretic Preacher',
    'A preacher in the square mocks the Bishop. The Bishop wants him silenced.',
    Choice('Silence him', 'The square falls quiet. So does your court.',
        [Loyalty(Courtier.bishop, 1), NextDecree(Decree.silence)]),
    Choice('Let him speak', 'The crowd cheers you. The Bishop does not.',
        [Loyalty(Courtier.bishop, -2), AllLoyalty(1)]),
    about: Courtier.bishop,
  ),
  Dilemma(
    'War Drums',
    'The General begs leave to march on a rival kingdom.',
    Choice('March to war', 'Victory, at a cost. You are wounded on the field.',
        [Loyalty(Courtier.general, 2), Wound(1), Charge(Courtier.general)]),
    Choice('Keep the peace', 'The General sulks in the barracks.',
        [Loyalty(Courtier.general, -1)]),
    about: Courtier.general,
  ),
  Dilemma(
    'Whispers of Treason',
    'The Spymaster claims a plot is brewing, and names no one.',
    Choice('Trust the Spymaster', 'Arrests in the night. The court grows nervous.',
        [Loyalty(Courtier.spymaster, 2), AllLoyalty(-1)]),
    Choice('Dismiss the rumour', 'The Spymaster smiles thinly.',
        [Loyalty(Courtier.spymaster, -2)]),
    about: Courtier.spymaster,
  ),
  Dilemma(
    'The Merchant’s Loan',
    'The Merchant offers gold for the royal coffers, at a steep interest.',
    Choice('Take the gold', 'A feast is held. Your physicians are paid.',
        [Wound(-1), Loyalty(Courtier.merchant, 1), Points(1)]),
    Choice('Refuse the loan', 'The Merchant closes his ledger with a snap.',
        [Loyalty(Courtier.merchant, -2)]),
    about: Courtier.merchant,
  ),
  Dilemma(
    'A Jest Too Far',
    'The Jester mocked you before the ambassadors. The court waits for your verdict.',
    Choice('Laugh it off', 'The court laughs with you. The Jester bows.',
        [Loyalty(Courtier.jester, 2), Loyalty(Courtier.duke, -1)]),
    Choice('Banish the Jester for a day', 'The hall is quieter, and colder.',
        [Loyalty(Courtier.jester, -3), NextDecree(Decree.exile)]),
    about: Courtier.jester,
  ),
  Dilemma(
    'Plague in the Villages',
    'Sickness spreads through the villages beyond the walls.',
    Choice('Open the gates to the sick',
        'Your people bless you, but you fall ill yourself.',
        [AllLoyalty(1), Wound(1)]),
    Choice('Close the gates', 'The court is safe. The people remember.',
        [AllLoyalty(-1)]),
    council: true,
  ),
  Dilemma(
    'A Poisoned Cup',
    'A taster collapses at the feast. The cup was meant for you.',
    Choice('Hunt the poisoner', 'The search turns the court against itself.',
        [AllLoyalty(-1), NextDecree(Decree.silence)]),
    Choice('Say nothing, trust no one', 'You eat little and sleep less.',
        [Wound(1)]),
  ),
  Dilemma(
    'The Royal Physician',
    'A healer from the east offers a strange remedy for your wounds.',
    Choice('Take the remedy', 'Your wounds close. The Bishop calls it witchcraft.',
        [Wound(-1), Loyalty(Courtier.bishop, -1)]),
    Choice('Send the healer away', 'The Bishop nods approvingly.',
        [Loyalty(Courtier.bishop, 1)]),
  ),
  Dilemma(
    'A Grand Tournament',
    'The court begs for a tournament to celebrate your reign.',
    Choice('Hold the tournament', 'Glory! The lists are hard fought.',
        [AllLoyalty(1), Points(2)]),
    Choice('Save the gold', 'The banners stay furled.',
        [AllLoyalty(-1), Points(-1)]),
    council: true,
  ),
  Dilemma(
    'The Pretender',
    'A stranger claims to be your long-lost elder sibling, and rightful heir.',
    Choice('Imprison the pretender', 'Order is kept, firmly.',
        [NextDecree(Decree.kingsCommand)]),
    Choice('Hear their claim', 'The court whispers about who should rule.',
        [AllLoyalty(-1), Wound(-1)]),
    council: true,
  ),
  Dilemma(
    'Council of Advisors',
    'Your courtiers ask for a voice in matters of state.',
    Choice('Grant them a council', 'They argue long into the night.',
        [AllLoyalty(1), NextDecree(Decree.lateCounsel)]),
    Choice('Rule alone', 'Your word is law, and you alone carry it.',
        [AllLoyalty(-1), NextDecree(Decree.kingsCommand)]),
    council: true,
  ),
  Dilemma(
    'Famine',
    'The harvest has failed. The granaries are nearly empty.',
    Choice('Open the royal granary', 'Your people eat. Your court goes hungry.',
        [AllLoyalty(-1), Points(-1)]),
    Choice('Ration the people', 'The court feasts while the city starves.',
        [AllLoyalty(1), Wound(1)]),
    council: true,
  ),
  Dilemma(
    'An Assassin Caught',
    'Guards catch an assassin on the palace roof.',
    Choice('Show mercy', 'Mercy is remembered, by friends and foes alike.',
        [AllLoyalty(1)]),
    Choice('Make an example', 'Fear keeps the court in line, for now.',
        [AllLoyalty(-1), Wound(-1)]),
    council: true,
  ),
  Dilemma(
    'The Duke and the Jester',
    'The Duke wants the Jester whipped for an insult.',
    Choice('Side with the Duke', 'The Jester stops smiling.',
        [Loyalty(Courtier.duke, 1), Loyalty(Courtier.jester, -2)]),
    Choice('Side with the Jester', 'The Duke goes red with fury.',
        [Loyalty(Courtier.jester, 1), Loyalty(Courtier.duke, -2)]),
  ),
  Dilemma(
    'Spies Among Merchants',
    'The Spymaster suspects the Merchant of selling secrets abroad.',
    Choice('Search the Merchant’s house', 'Nothing is found. The Merchant is furious.',
        [Loyalty(Courtier.spymaster, 1), Loyalty(Courtier.merchant, -2),
         Charge(Courtier.spymaster)]),
    Choice('Trust the Merchant', 'The Spymaster makes a note of your answer.',
        [Loyalty(Courtier.merchant, 1), Loyalty(Courtier.spymaster, -2)]),
  ),
  // ---------------------------------------------- follow-ups to tidings
  Dilemma(
    'The Bandit Lord',
    'The bandit chief who beat the Duke\u2019s riders offers to serve you, in exchange for a pardon.',
    Choice('Pardon him', 'A dangerous friend. The Duke will not forget it.',
        [Loyalty(Courtier.duke, -2), Wound(-1)]),
    Choice('Hang him', 'The roads go quiet. The Duke rides out again.',
        [Loyalty(Courtier.duke, 1), Charge(Courtier.duke)]),
    about: Courtier.duke,
    followUp: true,
  ),
  Dilemma(
    'The Curse of the Relics',
    'The Bishop says the lost relics have cursed your reign, and demands a royal penance.',
    Choice('Do penance', 'You walk barefoot to the cathedral. It costs you.',
        [Wound(1), Loyalty(Courtier.bishop, 2)]),
    Choice('Refuse', 'The bells of Vell fall silent.',
        [Loyalty(Courtier.bishop, -2), NextDecree(Decree.silence)]),
    about: Courtier.bishop,
    followUp: true,
  ),
  Dilemma(
    'Spoils of War',
    'The General\u2019s soldiers return from the fort with a chest of enemy gold.',
    Choice('Share it with the court', 'Every house drinks to the General.',
        [AllLoyalty(1)]),
    Choice('Fill the treasury', 'The crown grows richer. The soldiers grumble.',
        [Points(-1), Loyalty(Courtier.general, -1)]),
    council: true,
    followUp: true,
  ),
  Dilemma(
    'The Fallen Fort',
    'Refugees from the lost fort crowd the city gates. The General wants another army.',
    Choice('Raise the army', 'The General marches again, at your command.',
        [Loyalty(Courtier.general, 1), Charge(Courtier.general), Points(1)]),
    Choice('Shelter the refugees', 'The city is crowded but grateful.',
        [Loyalty(Courtier.general, -1), AllLoyalty(1)]),
    about: Courtier.general,
    followUp: true,
  ),
  Dilemma(
    'The Envoy\u2019s Secret',
    'The Spymaster learns that a neighbouring king wants to marry into your house.',
    Choice('Accept the match', 'A wedding is planned. The court is delighted, and busy.',
        [AllLoyalty(1), Points(1)]),
    Choice('Refuse the match', 'An insult. Their spies arrive within the week.',
        [Loyalty(Courtier.spymaster, 1), NextDecree(Decree.exile)]),
    council: true,
    followUp: true,
  ),
  Dilemma(
    'The Merchant\u2019s Debt',
    'After the failed fair the Merchant begs the crown to cover his debts, or he will sell to your rivals.',
    Choice('Pay his debts', 'House Coyne is in your pocket now. So is its debt.',
        [Loyalty(Courtier.merchant, 2), Points(1)]),
    Choice('Let him sell', 'Your rivals grow rich on Coyne silk.',
        [Loyalty(Courtier.merchant, -2)]),
    about: Courtier.merchant,
    followUp: true,
  ),
  Dilemma(
    'Who Struck First?',
    'At the masque someone struck a royal guard. The court wants a culprit.',
    Choice('Blame the Jester', 'An easy answer. The Jester stops laughing.',
        [Loyalty(Courtier.jester, -2), AllLoyalty(1)]),
    Choice('Blame no one', 'Every house suspects every other.',
        [AllLoyalty(-1)]),
    council: true,
    followUp: true,
  ),
  Dilemma(
    'The Forger Found',
    'The Spymaster has caught the forger writing in a dead prince\u2019s name. It is a cousin of the Duke.',
    Choice('Spare the Duke\u2019s cousin', 'The Duke is grateful. The Spymaster is not.',
        [Loyalty(Courtier.duke, 2), Loyalty(Courtier.spymaster, -1)]),
    Choice('Punish the forger', 'Justice is done. The Duke wears black.',
        [Loyalty(Courtier.duke, -2), Loyalty(Courtier.spymaster, 1)]),
    followUp: true,
  ),
  // ------------------------------------------------------------- stories
  // Each story opens with a matter anyone may face; what the King chose
  // is remembered (a Flag), and the next part comes back rounds later.

  // The Shadow of Karsk: King Varric across the river.
  Dilemma(
    'An Envoy from Karsk',
    'Lord Hask kneels, barely. "King Varric of Karsk offers friendship, for a yearly gift of gold. He would hate for your harvests to burn."',
    Choice('Pay the gift', 'Hask smiles and counts the coins twice.',
        [Points(1), Flag('karsk_paid'), Say(Courtier.general, 'We pay a goatherd king not to visit? Shameful.')]),
    Choice('Send him home', 'Hask leaves with his beard shaved and his purse empty.',
        [Loyalty(Courtier.general, 1), Flag('karsk_defied'), Say(Courtier.merchant, 'There goes the eastern trade. And perhaps the eastern villages.')]),
    arc: 'karsk',
    speaker: 'Lord Hask, envoy of King Varric',
  ),
  Dilemma(
    'Tribute Doubled',
    'Lord Hask is back, and fatter. "King Varric finds last year’s gift... modest. He asks for twice as much."',
    Choice('Pay again', 'The treasury empties into Karsk wagons.',
        [Points(2), Loyalty(Courtier.merchant, -1), Flag('karsk_vassal'), Say(Courtier.duke, 'My grandfather would have died first.')]),
    Choice('Enough', 'You throw the purse back at him. The court roars.',
        [AllLoyalty(1), Unflag('karsk_paid'), Flag('karsk_defied')]),
    arc: 'karsk',
    speaker: 'Lord Hask, envoy of King Varric',
    requires: ['karsk_paid'],
  ),
  Dilemma(
    'Scouts on the River',
    'Karsk scouts have been seen at the fords. The General wants walls around Ashford; the Spymaster wants agents in Varric’s camp.',
    Choice('Build the walls', 'Stone by stone, Ashford becomes a fortress.',
        [Points(1), Charge(Courtier.general), Flag('walls'), Say(Courtier.general, 'Let them come.')]),
    Choice('Send the agents', 'Three of your best cross the river at night.',
        [Loyalty(Courtier.spymaster, 2), Flag('spies'), Say(Courtier.spymaster, 'Varric will not sneeze without my hearing it.')]),
    arc: 'karsk',
    requires: ['karsk_defied'],
  ),
  Dilemma(
    'Varric Sues for Peace',
    'Broken at Ashford, King Varric sends his own son to beg for peace, and offers the river lands.',
    Choice('Accept the peace', 'The war is over. The bells ring in both kingdoms.',
        [AllLoyalty(1), Wound(-1), Flag('karsk_peace'), Unflag('karsk_defied')]),
    Choice('March on Karsk', 'You will finish this. The army turns east.',
        [Loyalty(Courtier.general, 2), Points(2), Charge(Courtier.general), Flag('karsk_war'), Say(Courtier.bishop, 'Pride is a poor general.')]),
    arc: 'karsk',
    speaker: 'Prince Edric of Karsk',
    requires: ['ashford_held'],
  ),
  Dilemma(
    'The Ashes of Ashford',
    'Ashford has fallen. Thousands are at your gates, and among them Varric’s spies.',
    Choice('Open the city', 'The streets are full of the hungry. And of strangers.',
        [AllLoyalty(1), Points(1), Flag('refugees')]),
    Choice('Close the gates', 'The city is safe. The cries outside go on for days.',
        [AllLoyalty(-1), Loyalty(Courtier.spymaster, 1)]),
    arc: 'karsk',
    requires: ['ashford_burned'],
  ),
  Dilemma(
    'The Price of Peace',
    'Karsk soldiers still hold Ashford. Varric will leave, he says, for your heir’s hand in marriage to his son.',
    Choice('Agree', 'A wedding to end a war. Nobody dances.',
        [Flag('karsk_peace'), Unflag('karsk_defied'), Loyalty(Courtier.duke, -1)]),
    Choice('Take Ashford back by force', 'The General is ready. The court is not.',
        [Charge(Courtier.general), Wound(1), Flag('ashford_retaken')]),
    arc: 'karsk',
    speaker: 'Lord Hask, envoy of King Varric',
    requires: ['ashford_burned'],
    forbids: ['karsk_peace'],
  ),

  // Lady Elara, the Duke's daughter.
  Dilemma(
    'A Match for Elara',
    'The Duke brings his daughter Elara before you. "She is of age, Majesty. Choose her husband, and House Ashcombe will honour it."',
    Choice('A lord of your own court', 'Elara curtsies. The Duke beams.',
        [Loyalty(Courtier.duke, 2), Flag('elara_home')]),
    Choice('Prince Edric of Karsk', 'Peace bought with a daughter. The Duke goes white.',
        [Loyalty(Courtier.duke, -2), Flag('elara_karsk'), Flag('karsk_peace'), Unflag('karsk_defied')]),
    arc: 'elara',
    about: Courtier.duke,
  ),
  Dilemma(
    'A Letter from Elara',
    'A letter, smuggled out of Karsk. Elara writes that Varric is gathering an army, and that her husband frightens her.',
    Choice('Bring her home', 'Your riders steal her away. The treaty burns with the bridge.',
        [Loyalty(Courtier.duke, 3), Unflag('karsk_peace'), Flag('karsk_defied')]),
    Choice('She must endure', 'The Duke reads the letter, and says nothing at all.',
        [Loyalty(Courtier.duke, -2), Say(Courtier.duke, 'I will remember who left her there.')]),
    arc: 'elara',
    requires: ['elara_karsk'],
  ),
  Dilemma(
    'Elara’s Wedding Feast',
    'Elara marries Sir Tomas of the household guard. The Duke asks you to pay for a feast fit for a princess.',
    Choice('Spare nothing', 'Six hundred guests. Elara dances with you.',
        [Points(1), Loyalty(Courtier.duke, 2), AllLoyalty(1)]),
    Choice('A modest feast', 'The wine is thin. So is the Duke’s smile.',
        [Loyalty(Courtier.duke, -1)]),
    arc: 'elara',
    requires: ['elara_home'],
  ),

  // House Coyne's fleet.
  Dilemma(
    'The Merchant’s Fleet',
    'The Merchant unrolls a map of the southern seas. "Twelve ships, Majesty. Silk, spice and a fortune. All I need is the crown’s backing."',
    Choice('Back the fleet', 'Twelve ships sail on the morning tide.',
        [Points(1), Loyalty(Courtier.merchant, 2), Flag('fleet')]),
    Choice('Too great a risk', 'The Merchant rolls up the map very slowly.',
        [Loyalty(Courtier.merchant, -1)]),
    arc: 'fleet',
    about: Courtier.merchant,
  ),
  Dilemma(
    'Spice and Envy',
    'The fleet’s return has made House Coyne richer than Ashcombe. The Duke wants the Merchant taxed; the Merchant wants a title.',
    Choice('Tax the Merchant', '"A shopkeeper should pay like one," says the Duke.',
        [Loyalty(Courtier.merchant, -2), Loyalty(Courtier.duke, 1), Points(-1)]),
    Choice('Grant him a title', 'Lord Coyne. The Duke leaves before the ceremony.',
        [Loyalty(Courtier.merchant, 2), Loyalty(Courtier.duke, -2), Say(Courtier.duke, 'A crest on a shop sign.')]),
    arc: 'fleet',
    requires: ['fleet_home'],
  ),
  Dilemma(
    'The Lost Fleet',
    'Coyne is ruined, and the Merchant’s creditors are at the palace gate. He asks you to stand surety.',
    Choice('Stand surety', 'You save House Coyne, and inherit its debts.',
        [Points(2), Loyalty(Courtier.merchant, 3)]),
    Choice('Let Coyne fall', 'The Merchant sells his house, then his name.',
        [Loyalty(Courtier.merchant, -3), Say(Courtier.merchant, 'I will not forget who watched me drown.')]),
    arc: 'fleet',
    requires: ['fleet_lost'],
  ),

  // The Bishop's cathedral.
  Dilemma(
    'The Cathedral of Vell',
    'The Bishop dreams of a cathedral taller than any in the world. "Heaven will look kindly on the King who builds it."',
    Choice('Build it', 'Masons arrive from six kingdoms.',
        [Points(1), Loyalty(Courtier.bishop, 2), Flag('cathedral')]),
    Choice('Heaven can wait', 'The Bishop prays for you, loudly.',
        [Loyalty(Courtier.bishop, -1)]),
    arc: 'cathedral',
    about: Courtier.bishop,
  ),
  Dilemma(
    'The Second Anointing',
    'The cathedral stands. The Bishop wishes to anoint you again beneath its spire, so all will know the crown is held by heaven’s grace.',
    Choice('Kneel before the Bishop', 'The oil is cold. The crowd is vast.',
        [Loyalty(Courtier.bishop, 2), Wound(-1), Loyalty(Courtier.general, -1), Say(Courtier.general, 'Kings kneel to no one.')]),
    Choice('Crown yourself', 'You take the oil and do it yourself. Gasps.',
        [Loyalty(Courtier.bishop, -3), Loyalty(Courtier.general, 1), Say(Courtier.bishop, 'Heaven saw that, Majesty.')]),
    arc: 'cathedral',
    requires: ['cathedral_done'],
  ),

  // The Spymaster's ledger.
  Dilemma(
    'The Spymaster’s Ledger',
    'The Spymaster places a black ledger before you. "Every secret of this court, Majesty. Read it, and you will never trust anyone again."',
    Choice('Read it', 'You read until dawn.',
        [Loyalty(Courtier.spymaster, 1), AllLoyalty(-1), Flag('ledger')]),
    Choice('Burn it unread', 'The court breathes easier. The Spymaster does not.',
        [Loyalty(Courtier.spymaster, -2), AllLoyalty(1)]),
    arc: 'ledger',
    about: Courtier.spymaster,
  ),
  Dilemma(
    'A Name in the Ledger',
    'One page in the ledger is about the Jester: he meets a Karsk agent every new moon.',
    Choice('Arrest the Jester', 'The bells on his cap are silent in the cell.',
        [Loyalty(Courtier.jester, -3), Loyalty(Courtier.spymaster, 1)]),
    Choice('Use him to feed Varric lies', 'The Jester grins. "I always wanted to be a spy."',
        [Loyalty(Courtier.jester, 1), Flag('spies'), Charge(Courtier.spymaster)]),
    arc: 'ledger',
    requires: ['ledger'],
  ),

  // The Jester's secret.
  Dilemma(
    'The Jester’s Confession',
    'Late at night the Jester takes off his cap. "Your father was my father too, Majesty. I thought you should hear it from me."',
    Choice('Keep his secret', 'He puts the cap back on. Nobody else will know.',
        [Loyalty(Courtier.jester, 2), Flag('jester_secret')]),
    Choice('Proclaim him your brother', 'The court is astonished. Some are counting heirs.',
        [Loyalty(Courtier.jester, 1), AllLoyalty(-1), Flag('jester_known')]),
    arc: 'jester',
    about: Courtier.jester,
  ),
  Dilemma(
    'Blackmail',
    'A note under your door: the writer knows what the Jester is, and wants gold to keep quiet.',
    Choice('Pay', 'The note writer stays silent, for now.',
        [Points(1), Say(Courtier.spymaster, 'Paying only teaches them the price.')]),
    Choice('Let the truth out', 'The secret is out. The Jester laughs it off, badly.',
        [Loyalty(Courtier.jester, -1), Flag('jester_known')]),
    arc: 'jester',
    requires: ['jester_secret'],
  ),
  Dilemma(
    'The Bastard’s Faction',
    'Lords who dislike you now toast the Jester as the rightful heir. He swears he wants none of it.',
    Choice('Name him your heir', 'The faction falls silent. The Duke does not.',
        [Loyalty(Courtier.jester, 2), Loyalty(Courtier.duke, -2), Say(Courtier.duke, 'A fool on the throne. How fitting.')]),
    Choice('Banish him for a season', 'The Jester leaves the hall in silence.',
        [Loyalty(Courtier.jester, -3), NextDecree(Decree.exile)]),
    arc: 'jester',
    requires: ['jester_known'],
    council: true,
  ),

  // Mira of Ashford, a miller's daughter.
  Dilemma(
    'Mira of Ashford',
    'A young miller kneels in the dust of the road. "Majesty, the Duke’s men are taking my father’s mill. We have nothing else."',
    Choice('Protect her mill', 'Mira kisses your ring. The Duke’s steward glares.',
        [Loyalty(Courtier.duke, -1), Flag('mira_helped')]),
    Choice('The Duke has the right', 'Mira walks away without a word.',
        [Loyalty(Courtier.duke, 1), Flag('mira_wronged')]),
    arc: 'mira',
    speaker: 'Mira, a miller’s daughter',
  ),
  Dilemma(
    'Grain from Ashford',
    'In the lean months, wagons of flour arrive from Ashford. A note: "For the King who saved my mill. Mira."',
    Choice('Feed the court', 'The court feasts on Mira’s bread.',
        [AllLoyalty(1)]),
    Choice('Feed the poor', 'The city blesses your name, and you sleep well.',
        [Wound(-1), Loyalty(Courtier.merchant, -1)]),
    arc: 'mira',
    requires: ['mira_helped'],
  ),
  Dilemma(
    'The Miller’s Rising',
    'Mira has raised the villages of the north road against the Duke’s stewards. She says she will only lay down arms for you.',
    Choice('Crush the rising', 'The General rides north. It is not quick.',
        [Charge(Courtier.general), AllLoyalty(-1), Loyalty(Courtier.duke, 1)]),
    Choice('Hear her out', 'You ride north alone and give back the mills.',
        [Loyalty(Courtier.duke, -2), AllLoyalty(1), Flag('mira_helped')]),
    arc: 'mira',
    requires: ['mira_wronged'],
    speaker: 'Mira, rebel of the north road',
  ),
  Dilemma(
    'Mira at the Gates',
    'Among the refugees from Ashford is Mira. She asks to serve in the palace kitchens, and says she has seen Karsk captains in the crowd.',
    Choice('Take her in', 'Mira points out three spies before supper.',
        [Loyalty(Courtier.spymaster, 1), Wound(-1)]),
    Choice('Send her away', 'She is lost in the crowd.',
        [AllLoyalty(-1)]),
    arc: 'mira',
    requires: ['refugees', 'mira_helped'],
  ),

  // The sickness.
  Dilemma(
    'The Plague Spreads',
    'The sickness from the lower town has reached the palace kitchens. The Bishop wants prayer; the General wants the lower town burned.',
    Choice('Burn the lower town', 'It works. Nobody will ever forgive you.',
        [AllLoyalty(-2), Unflag('plague'), Say(Courtier.general, 'Hard choices are still choices.')]),
    Choice('Pray', 'The cathedral fills with the faithful, and the coughing.',
        [Loyalty(Courtier.bishop, 2), Wound(1), Unflag('plague')]),
    arc: 'plague',
    requires: ['plague'],
    council: true,
  ),
];

/// Roman numerals for reigns: I, II, III ...
String roman(int n) {
  const values = [10, 9, 5, 4, 1];
  const symbols = ['X', 'IX', 'V', 'IV', 'I'];
  final out = StringBuffer();
  var rest = n;
  for (int i = 0; i < values.length; i++) {
    while (rest >= values[i]) {
      out.write(symbols[i]);
      rest -= values[i];
    }
  }
  return out.toString();
}
