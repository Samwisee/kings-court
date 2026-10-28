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
        'Old blood and older land. The Ashcombes have held the northern march for nine generations, and every hill fort along it was raised by their hands. They count their wealth in acres and their loyalties in centuries, and they have outlasted every storm the realm has known.',
  ),
  bishop(
    'The Bishop',
    TokenShape.arch,
    'Absolution',
    'Once per round, when a task fails, set it aside, but take a penance: draw a task worth at least as many points that you can still do, and do it this round.',
    house: 'House Vell',
    motto: 'Light before the throne.',
    story:
        'The Vells raised the great cathedral stone by stone, and their bells still mark the hours of the realm. Their archive holds every oath ever sworn in the kingdom, and they have forgotten none of them. Even their silences are said to be prayers.',
  ),
  general(
    'The General',
    TokenShape.hexagon,
    'Vanguard',
    'Once per round, lead a trick even though you did not win the last one.',
    house: 'House Strand',
    motto: 'Steel answers.',
    story:
        'Soldiers risen from the ranks. Every Strand learns to march before they learn to read, and the family’s scars are its heraldry. They keep the realm’s peace the hard way, and remember the name of every field it cost.',
  ),
  spymaster(
    'The Spymaster',
    TokenShape.diamond,
    'Whisper',
    'Once per round, name a player and a suit. They must say truthfully whether they hold any cards of it.',
    house: 'House Morrow',
    motto: 'Every wall has ears.',
    story:
        'No one is sure where the Morrows came from, and the Morrows prefer it that way. Their letters travel in other people’s pockets, and their friends wear many faces. They know everyone’s secrets, and keep their own.',
  ),
  merchant(
    'The Merchant',
    TokenShape.octagon,
    'Trade',
    'Once per round, swap one card from your hand, face down, with a player next to you. Court Cards cannot be traded.',
    house: 'House Coyne',
    motto: 'All things have a price.',
    story:
        'The Coynes own the harbour, the mint and half the debts in the kingdom. Their ships carry wine south and silver home, and every guild hall keeps a seat for a Coyne. To them, a quarrel is only a price not yet agreed.',
  ),
  jester(
    'The Jester',
    TokenShape.star,
    'Jest',
    'Once per round, swap two open tasks between any two players.',
    house: 'House Motley',
    motto: 'Laugh, lest you weep.',
    story:
        'A house of one, with a borrowed name. The Jester tumbles through every hall of the court, says what no one else dares, and somehow keeps their head. Behind the bells, very little is missed.',
  ),

  /// You, in solo Dynasty: the King, above every house.
  king(
    'The King',
    TokenShape.shield,
    'Royal Favour',
    'Once per round, before the first trick, give one of your tasks to another player.',
    house: 'The Crown',
    motto: 'One realm, one crown.',
    story:
        'Every house kneels to the crown, and every house would wear it if it could.',
  );

  /// The six great houses (not the crown).
  static List<Courtier> get houses =>
      values.where((c) => c != Courtier.king).toList();

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
    'The Realm Secured',
    'The war with Karsk is over. Your houses prosper, your borders hold, and songs will be sung of this court for a hundred years.',
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
  'Win the trick that the King card is played in.',
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

/// A courtier leaves court before the next round (banished, ruined,
/// arrested); someone new takes the seat.
class Depart extends Effect {
  const Depart(this.courtier);
  final Courtier courtier;
}

/// A courtier urging the King towards one choice of a matter.
class Plea {
  const Plea(this.courtier, this.line, {required this.forA});
  final Courtier courtier;
  final String line;

  /// For the first choice (true) or the second.
  final bool forA;
}

/// How each courtier argues for a choice, addressing the King. {choice}
/// is the choice, in lower case.
const pleaLines = <Courtier, List<String>>{
  Courtier.duke: [
    'Majesty, {choice}. Ashcombe has guarded this realm for nine generations, and we did not do it by being timid.',
    'Old blood counsels you, Majesty: {choice}. My father would have said the same, and louder.',
  ],
  Courtier.bishop: [
    'Heaven’s will is plain, Majesty: {choice}. I have prayed on it, and I rarely pray for nothing.',
    'Think of your soul, Majesty, and {choice}. The rest of us will be judged too, but you first.',
  ],
  Courtier.general: [
    '{Choice}, Majesty. Anything else is weakness, and weakness gets men killed.',
    'A soldier’s advice, Majesty: {choice}, and be done with it. Every day we dither, someone sharpens a knife.',
  ],
  Courtier.spymaster: [
    'I hear things, Majesty. Things that tell me: {choice}. Quietly, if you can manage it.',
    'Trust me in this, Majesty, if in nothing else: {choice}. I would tell you why, but then I would have to stop trusting you.',
  ],
  Courtier.merchant: [
    'Think of the ledgers, Majesty. {Choice}. Sentiment is lovely, but it doesn’t pay for anything.',
    'Every coin I own agrees with me, Majesty: {choice}. And I own a great many coins.',
  ],
  Courtier.jester: [
    'Oh, {choice}, Majesty! What could possibly go wrong? Don’t answer that.',
    'Even a fool can see it, Majesty: {choice}. And I should know. I am the fool.',
  ],
  Courtier.king: ['{Choice}.'],
};

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
      this.forbids = const [],
      this.pleas = const [],
      this.audience = false,
      this.replies});
  final String title;
  final String story;
  final Choice a;
  final Choice b;

  /// What the council says to the King, for one side or the other. Matters
  /// without their own get pleas made up from who gains what.
  final List<Plea> pleas;

  /// A private audience: just you and the courtier it's [about], and the
  /// choices are what you say to them.
  final bool audience;

  /// What a visitor ([speaker]) says to the first choice and the second.
  final (String, String)? replies;
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
        [Gold(4), Wound(-1), Loyalty(Courtier.merchant, 1), Points(1)]),
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
        [Gold(-3), AllLoyalty(1), Points(2), Arrive(Courtier.general), Arrive(Courtier.jester)]),
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
        [Gold(-2), AllLoyalty(-1), Points(-1)]),
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
        [Gold(3), Points(-1), Loyalty(Courtier.general, -1)]),
    council: true,
    followUp: true,
  ),
  Dilemma(
    'The Fallen Fort',
    'Refugees from the lost fort crowd the city gates. The General wants another army.',
    Choice('Raise the army', 'The General marches again, at your command.',
        [Gold(-3), Loyalty(Courtier.general, 1), Charge(Courtier.general), Points(1)]),
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
        [Gold(-4), Loyalty(Courtier.merchant, 2), Points(1)]),
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
  // --------------------------------------------------------------- visitors
  // Petitioners who come before the throne with a matter of their own.
  Dilemma(
    'The Farmers of the Vale',
    'Majesty, the Duke’s deer eat our crops, and we may not touch them on pain of hanging. Let us hunt them, or our children starve this winter.',
    Choice('Let them hunt', 'The Vale eats venison all winter. The Duke counts his deer, and frowns.',
        [Loyalty(Courtier.duke, -1), AllLoyalty(1)]),
    Choice('The deer are the Duke’s', 'The farmers trudge home. The Duke sends you a haunch, with thanks.',
        [Loyalty(Courtier.duke, 1), Wound(1)]),
    speaker: 'Old Tam, a farmer of the Vale',
    pleas: [
      Plea(Courtier.bishop, 'Hungry children are heaven’s business, Majesty, and so they are yours.', forA: true),
      Plea(Courtier.duke, 'Those deer are older than his farm, Majesty. Ashcombe has kept that forest for three hundred years.', forA: false),
    ],
    replies: ('Bless you, Majesty! The Vale won’t forget this.', 'Then we’ll eat grass, Majesty. As we always have.'),
  ),
  Dilemma(
    'A Scholar from the South',
    'I have built a machine that tells the hour without the sun, Majesty. Fund my workshop, and your kingdom will be the wonder of the age.',
    Choice('Fund the workshop', 'Within a month, a great clock ticks above the palace gate. Everyone is late for everything anyway.',
        [Gold(-3), AllLoyalty(1)]),
    Choice('Send him on his way', 'The scholar packs his gears and heads for Karsk, where Varric is said to pay well.',
        [Gold(0)]),
    speaker: 'Master Orrin, a travelling scholar',
    pleas: [
      Plea(Courtier.merchant, 'Clocks sell, Majesty. Everyone wants to know exactly how late they are.', forA: true),
      Plea(Courtier.bishop, 'Only heaven should keep the hours, Majesty. And the bells do it perfectly well.', forA: false),
    ],
    replies: ('You won’t regret it, Majesty! Well, not for a while.', 'Karsk, then. I hear their king is more... curious.'),
  ),
  Dilemma(
    'The Masons’ Guild',
    'My masons have not been paid in three months, Majesty. Pay them, or every chisel in the city goes down tomorrow.',
    Choice('Pay the masons', 'The hammers ring again across the city.',
        [Gold(-3), AllLoyalty(1)]),
    Choice('Arrest the ringleaders', 'The guards march. The masons go back to work, and remember.',
        [Loyalty(Courtier.general, 1), AllLoyalty(-1)]),
    speaker: 'Gilda, master of the Masons’ Guild',
    pleas: [
      Plea(Courtier.bishop, 'The cathedral is half-built, Majesty. Without masons it stays that way.', forA: true),
      Plea(Courtier.merchant, 'Pay one guild, Majesty, and every guild in the city will be at your door by Friday.', forA: false),
    ],
    replies: ('The guild thanks you, Majesty. The walls will stand.', 'You can lock up masons, Majesty. You can’t make them build.'),
  ),
  Dilemma(
    'A Deserter from Karsk',
    'I ran from Varric’s army, Majesty. I know where his supply camps are. All I ask in return is a roof and a new name.',
    Choice('Take him in', 'He draws maps all night. Some of them are even accurate.',
        [Flag('spies'), Loyalty(Courtier.spymaster, 1)]),
    Choice('Send him back over the river', 'He is marched to the ford at dawn. Nobody watches him cross.',
        [Loyalty(Courtier.general, 1)]),
    speaker: 'Bran, a deserter from Karsk',
    pleas: [
      Plea(Courtier.spymaster, 'A gift horse, Majesty. I shall check its teeth myself.', forA: true),
      Plea(Courtier.general, 'A man who deserts once, Majesty, deserts twice.', forA: false),
    ],
    replies: ('Thank you, Majesty. You won’t see me in a Karsk coat again.', 'Then I am a dead man, Majesty. Remember that I came.'),
  ),
  Dilemma(
    'The Widow’s Claim',
    'My husband died holding your border, Majesty. His lands were given to a cousin I have never met. I ask only for my home.',
    Choice('Restore her lands', 'She goes home. The cousin goes to court, and loses.',
        [Loyalty(Courtier.duke, -1), Loyalty(Courtier.general, 1)]),
    Choice('The law is the law', 'She leaves without a word, and the court is quiet for a while.',
        [Loyalty(Courtier.duke, 1), Loyalty(Courtier.general, -1)]),
    speaker: 'Lady Wenna, a widow of the border',
    pleas: [
      Plea(Courtier.general, 'Her husband held the line, Majesty. The least we owe him is his roof.', forA: true),
      Plea(Courtier.duke, 'Inheritance is the bedrock of every house, Majesty. Mine included.', forA: false),
    ],
    replies: ('Thank you, Majesty. He would have been proud to serve you.', 'Then the border has cost me twice.'),
  ),
  Dilemma(
    'A Troupe of Players',
    'We’ve written a play about Your Majesty’s coronation! Some say it’s a little... satirical. May we perform it in the square?',
    Choice('Let them perform', 'The square roars with laughter. Some of it is even with you.',
        [Loyalty(Courtier.jester, 2), AllLoyalty(1)]),
    Choice('Burn the script', 'The script burns. Copies are somehow everywhere by morning.',
        [Loyalty(Courtier.jester, -1), NextDecree(Decree.silence)]),
    speaker: 'Fennick, a travelling player',
    pleas: [
      Plea(Courtier.jester, 'Let them, Majesty! I wrote the second act.', forA: true),
      Plea(Courtier.bishop, 'Mockery of the crown is a sin, Majesty. Or it ought to be.', forA: false),
    ],
    replies: ('Your Majesty is a patron of the arts! We’ll make you look... taller.', 'Burn the script, Majesty, and they’ll only learn it by heart.'),
  ),

  // ------------------------------------------------------ private audiences
  // One courtier, alone with the King. The choices are your answers.
  Dilemma(
    'The Duke’s Doubts',
    'A word, Majesty, alone. The other houses laugh behind my back. Ashcombe is old, they say, and tired. Tell me they are wrong.',
    Choice('Ashcombe is the rock this realm stands on.',
        'The Duke stands a little straighter on his way out.',
        [Loyalty(Courtier.duke, 2)]),
    Choice('Then prove them wrong yourself.',
        'The Duke bows stiffly. He will prove it, or die trying.',
        [Loyalty(Courtier.duke, -1), Charge(Courtier.duke)]),
    about: Courtier.duke,
    audience: true,
  ),
  Dilemma(
    'A Confession',
    'Majesty, I have kept some of the cathedral’s alms for... safekeeping. Rather a lot of them. I thought you should hear it from me.',
    Choice('Return every coin, and we’ll say no more.',
        'The coins come back in a heavy chest. The Bishop is quiet for a week.',
        [Gold(3), Loyalty(Courtier.bishop, -1)]),
    Choice('Keep them. Heaven knows you’ve earned it.',
        'The Bishop blesses you twice on the way out.',
        [Loyalty(Courtier.bishop, 2), Flag('bishop_owes')]),
    about: Courtier.bishop,
    audience: true,
  ),
  Dilemma(
    'Old Wounds',
    'I lost three hundred men at the river ford, Majesty. Some nights I still hear them. Forgive me. I don’t know why I’m telling you this.',
    Choice('Their names will be carved in the great hall.',
        'Masons cut three hundred names in stone. The General reads every one.',
        [Gold(-2), Loyalty(Courtier.general, 2)]),
    Choice('Grief is for later, General. Drill the living.',
        'The General salutes, and says nothing more about it. Ever.',
        [Loyalty(Courtier.general, -1), Charge(Courtier.general)]),
    about: Courtier.general,
    audience: true,
  ),
  Dilemma(
    'A Gift of Secrets',
    'A gift, Majesty: the name of someone at this court who has been writing to Karsk. Shall I tell you?',
    Choice('Tell me.',
        'The Spymaster whispers a name. You will never look at that courtier the same way.',
        [Loyalty(Courtier.spymaster, 1), AllLoyalty(-1), Flag('ledger')]),
    Choice('Keep it. I would rather trust my court.',
        'The Spymaster smiles. "As you wish, Majesty." The name stays in the dark.',
        [Loyalty(Courtier.spymaster, -1), AllLoyalty(1)]),
    about: Courtier.spymaster,
    audience: true,
  ),
  Dilemma(
    'A Private Loan',
    'Between friends, Majesty: the crown is short, and I am long. Ten gold, at a very friendly rate. Barely any interest at all.',
    Choice('Done. Bring the gold.',
        'The gold arrives within the hour. So does the paperwork.',
        [Gold(6), Loyalty(Courtier.merchant, 1), Points(1)]),
    Choice('The crown is not for sale, Merchant.',
        'The Merchant laughs, a little too loudly, and leaves.',
        [Loyalty(Courtier.merchant, -1)]),
    about: Courtier.merchant,
    audience: true,
  ),
  Dilemma(
    'The Fool’s Truth',
    'Majesty, everyone laughs at my jokes but you. Am I losing my touch, or are you losing your sense of humour?',
    Choice('Tell me another, fool.',
        'The Jester tells you one about a bishop and a goat. You laugh until you cry.',
        [Loyalty(Courtier.jester, 2), Wound(-1)]),
    Choice('I am the King. I laugh when I choose.',
        'The Jester bows very low, and doesn’t joke for a week.',
        [Loyalty(Courtier.jester, -2)]),
    about: Courtier.jester,
    audience: true,
  ),

  // ------------------------------------------------------------- stories
  // Each story opens with a matter anyone may face; what the King chose
  // is remembered (a Flag), and the next part comes back rounds later.

  // The Shadow of Karsk: King Varric across the river.
  Dilemma(
    'An Envoy from Karsk',
    'Lord Hask kneels, barely. "King Varric of Karsk offers friendship, for a yearly gift of gold. He would hate for your harvests to burn."',
    Choice('Pay the gift', 'Hask smiles and counts the coins twice.',
        [Gold(-4), Points(1), Flag('karsk_paid'), Arrive(Courtier.merchant), Say(Courtier.general, 'We pay a goatherd king not to visit? Shameful.')]),
    Choice('Send him home', 'Hask leaves with his beard shaved and his purse empty.',
        [Loyalty(Courtier.general, 1), Flag('karsk_defied'), Arrive(Courtier.general), Say(Courtier.merchant, 'There goes the eastern trade. And perhaps the eastern villages.')]),
    arc: 'karsk',
    speaker: 'Lord Hask, envoy of King Varric',
    followUp: true,
    pleas: [
      Plea(Courtier.merchant, 'Gold is cheaper than war, Majesty. Pay, and the river stays quiet.', forA: true),
      Plea(Courtier.general, 'Send Hask back to his goatherd king, Majesty, and let Varric come if he dares.', forA: false),
      Plea(Courtier.spymaster, 'A king who pays once pays forever, Majesty.', forA: false),
    ],
  ),
  Dilemma(
    'Tribute Doubled',
    'Lord Hask is back, and fatter. "King Varric finds last year’s gift... modest. He asks for twice as much."',
    Choice('Pay again', 'The treasury empties into Karsk wagons.',
        [Gold(-6), Points(2), Loyalty(Courtier.merchant, -1), Flag('karsk_vassal'), Say(Courtier.duke, 'My grandfather would have died first.')]),
    Choice('Enough', 'You throw the purse back at him. The court roars.',
        [AllLoyalty(1), Unflag('karsk_paid'), Flag('karsk_defied')]),
    arc: 'karsk',
    speaker: 'Lord Hask, envoy of King Varric',
    followUp: true,
    pleas: [
      Plea(Courtier.merchant, 'Twice the gold is still cheaper than one war, Majesty.', forA: true),
      Plea(Courtier.duke, 'Enough, Majesty! Ashcombe will not pay twice.', forA: false),
    ],
  ),
  Dilemma(
    'Scouts on the River',
    'Karsk scouts have been seen at the fords. The General wants walls around Ashford; the Spymaster wants agents in Varric’s camp.',
    Choice('Build the walls', 'Stone by stone, Ashford becomes a fortress.',
        [Gold(-3), Points(1), Charge(Courtier.general), Flag('walls'), Say(Courtier.general, 'Let them come.')]),
    Choice('Send the agents', 'Three of your best cross the river at night.',
        [Loyalty(Courtier.spymaster, 2), Flag('spies'), Say(Courtier.spymaster, 'Varric will not sneeze without my hearing it.')]),
    arc: 'karsk',
    followUp: true,
    pleas: [
      Plea(Courtier.general, 'Walls, Majesty. Stone does not change sides.', forA: true),
      Plea(Courtier.spymaster, 'Walls only tell Varric where to dig, Majesty. Let me send my people.', forA: false),
    ],
  ),
  Dilemma(
    'Varric Sues for Peace',
    'Broken at Ashford, King Varric sends his own son to beg for peace, and offers the river lands.',
    Choice('Accept the peace', 'The war is over. The bells ring in both kingdoms.',
        [AllLoyalty(1), Wound(-1), Flag('karsk_peace'), Unflag('karsk_defied')]),
    Choice('March on Karsk', 'You will finish this. The army turns east.',
        [Gold(-3), Loyalty(Courtier.general, 2), Points(2), Charge(Courtier.general), Flag('karsk_war'), Say(Courtier.bishop, 'Pride is a poor general.')]),
    arc: 'karsk',
    speaker: 'Prince Edric of Karsk',
    followUp: true,
    pleas: [
      Plea(Courtier.bishop, 'Take the peace, Majesty. There are widows enough.', forA: true),
      Plea(Courtier.merchant, 'Peace opens the river to trade again, Majesty.', forA: true),
      Plea(Courtier.general, 'He is on his knees, Majesty. Finish it.', forA: false),
    ],
  ),
  Dilemma(
    'The Ashes of Ashford',
    'Ashford has fallen. Thousands are at your gates, and among them Varric’s spies.',
    Choice('Open the city', 'The streets are full of the hungry. And of strangers.',
        [AllLoyalty(1), Points(1), Flag('refugees'), Arrive(Courtier.bishop)]),
    Choice('Close the gates', 'The city is safe. The cries outside go on for days.',
        [AllLoyalty(-1), Loyalty(Courtier.spymaster, 1)]),
    arc: 'karsk',
    followUp: true,
    pleas: [
      Plea(Courtier.bishop, 'They are your people, Majesty. Open the gates.', forA: true),
      Plea(Courtier.spymaster, 'Half of Varric\u2019s spies are in that crowd, Majesty.', forA: false),
    ],
  ),
  Dilemma(
    'The Price of Peace',
    'Karsk soldiers still hold Ashford. Varric will leave, he says, for your heir’s hand in marriage to his son.',
    Choice('Agree', 'A wedding to end a war. Nobody dances.',
        [Flag('karsk_peace'), Unflag('karsk_defied'), Loyalty(Courtier.duke, -1)]),
    Choice('Take Ashford back by force', 'The General is ready. The court is not.',
        [Charge(Courtier.general), Wound(1), Flag('karsk_war')]),
    arc: 'karsk',
    speaker: 'Lord Hask, envoy of King Varric',
    requires: ['ashford_burned'],
    forbids: ['karsk_peace', 'karsk_war'],
    pleas: [
      Plea(Courtier.bishop, 'A wedding is better than a funeral, Majesty.', forA: true),
      Plea(Courtier.duke, 'Never wed our blood to Karsk, Majesty!', forA: false),
      Plea(Courtier.general, 'Give me the order and Ashford is ours by spring.', forA: false),
    ],
  ),

  Dilemma(
    'The Vassal King',
    'Lord Hask brings a summons: King Varric expects you at his court in Karsk, to kneel before his throne as a loyal vassal should.',
    Choice('Go, and kneel', 'The realm is safe, and shamed.',
        [AllLoyalty(-2), Unflag('karsk_vassal'), Flag('karsk_peace'), Say(Courtier.duke, 'I will not kneel to the man you knelt to.')]),
    Choice('Tear up the summons', 'Hask goes white. The General goes to sharpen his sword.',
        [Loyalty(Courtier.general, 2), Unflag('karsk_vassal'), Flag('karsk_defied')]),
    arc: 'karsk',
    speaker: 'Lord Hask, envoy of King Varric',
    requires: ['karsk_vassal'],
    pleas: [
      Plea(Courtier.merchant, 'Kneel, Majesty. Knees heal. Burned cities do not.', forA: true),
      Plea(Courtier.duke, 'If you kneel to Varric, Majesty, do not expect the houses to kneel to you.', forA: false),
    ],
  ),
  Dilemma(
    'A Feast for Two Kingdoms',
    'Peace with Karsk holds. The court wants a great feast to seal it, with King Varric himself at your table.',
    Choice('Invite Varric', 'Two kings drink from one cup. Nobody is poisoned.',
        [Gold(-2), AllLoyalty(1), Wound(-1), Flag('karsk_peace_sealed'), Say(Courtier.spymaster, 'I counted his guards. Twice.')]),
    Choice('Feast without him', 'The court celebrates. Karsk hears of it, and sulks.',
        [Loyalty(Courtier.general, 1), Flag('karsk_peace_sealed')]),
    arc: 'karsk',
    followUp: true,
    pleas: [
      Plea(Courtier.jester, 'A feast with Varric! I\u2019ll bring the poison tasters.', forA: true),
      Plea(Courtier.spymaster, 'Invite Varric to dinner? I would sooner invite a snake.', forA: false),
    ],
  ),
  Dilemma(
    'Surplus Grain',
    'The Merchant has a buyer for the spare grain: King Varric of Karsk, across the river, who pays in gold and asks no questions.',
    Choice('Sell to Karsk', 'Karsk wagons roll west, heavy with your bread.',
        [Gold(5), Points(-1), Loyalty(Courtier.merchant, 2), Say(Courtier.general, 'Feeding the wolf, Majesty?')]),
    Choice('Keep it for winter', 'The granaries stay full. The Merchant sulks.',
        [AllLoyalty(1), Loyalty(Courtier.merchant, -1)]),
    arc: 'karsk',
    about: Courtier.merchant,
    followUp: true,
    pleas: [
      Plea(Courtier.merchant, 'Varric pays in gold, Majesty, and gold does not ask where bread goes.', forA: true),
      Plea(Courtier.general, 'Feed Karsk and you feed its army, Majesty.', forA: false),
      Plea(Courtier.bishop, 'Our own people will be hungry by midwinter.', forA: false),
    ],
  ),
  Dilemma(
    'A Long War',
    'Your army is stuck before Varric\u2019s walls, and winter is coming. The General wants one more assault; the court wants to go home.',
    Choice('One more assault', 'The army digs in for another try.',
        [Loyalty(Courtier.general, 1), Unflag('seen:The Crown of Karsk')]),
    Choice('Make peace', 'Varric accepts, and smiles too widely.',
        [Unflag('karsk_war'), Flag('karsk_peace'), AllLoyalty(1)]),
    arc: 'karsk',
    followUp: true,
    council: true,
    pleas: [
      Plea(Courtier.general, 'One more push, Majesty. The walls are cracking.', forA: true),
      Plea(Courtier.bishop, 'Bring them home, Majesty, while there is still someone to bring.', forA: false),
    ],
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
    pleas: [
      Plea(Courtier.duke, 'Keep her close, Majesty. Ashcombe blood stays in this realm.', forA: true),
      Plea(Courtier.merchant, 'A Karsk prince, Majesty, and peace on the river for a generation.', forA: false),
    ],
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
        [Gold(-3), Points(1), Loyalty(Courtier.duke, 2), AllLoyalty(1)]),
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
        [Gold(-4), Points(1), Loyalty(Courtier.merchant, 2), Flag('fleet')]),
    Choice('Too great a risk', 'The Merchant rolls up the map very slowly.',
        [Loyalty(Courtier.merchant, -1)]),
    arc: 'fleet',
    about: Courtier.merchant,
    pleas: [
      Plea(Courtier.merchant, 'Twelve ships, Majesty, and a fortune in every hold.', forA: true),
      Plea(Courtier.duke, 'Gambling the treasury on the weather, Majesty?', forA: false),
    ],
  ),
  Dilemma(
    'Spice and Envy',
    'The fleet’s return has made House Coyne richer than Ashcombe. The Duke wants the Merchant taxed; the Merchant wants a title.',
    Choice('Tax the Merchant', '"A shopkeeper should pay like one," says the Duke.',
        [Gold(3), Loyalty(Courtier.merchant, -2), Loyalty(Courtier.duke, 1), Points(-1)]),
    Choice('Grant him a title', 'Lord Coyne. The Duke leaves before the ceremony.',
        [Loyalty(Courtier.merchant, 2), Loyalty(Courtier.duke, -2), Say(Courtier.duke, 'A crest on a shop sign.')]),
    arc: 'fleet',
    requires: ['fleet_home'],
  ),
  Dilemma(
    'The Lost Fleet',
    'Coyne is ruined, and the Merchant’s creditors are at the palace gate. He asks you to stand surety.',
    Choice('Stand surety', 'You save House Coyne, and inherit its debts.',
        [Gold(-5), Points(2), Loyalty(Courtier.merchant, 3)]),
    Choice('Let Coyne fall', 'The Merchant sells his house, then his name.',
        [Loyalty(Courtier.merchant, -3), Say(Courtier.merchant, 'I will not forget who watched me drown.'), Depart(Courtier.merchant)]),
    arc: 'fleet',
    requires: ['fleet_lost'],
  ),

  // The Bishop's cathedral.
  Dilemma(
    'The Cathedral of Vell',
    'The Bishop dreams of a cathedral taller than any in the world. "Heaven will look kindly on the King who builds it."',
    Choice('Build it', 'Masons arrive from six kingdoms.',
        [Gold(-4), Points(1), Loyalty(Courtier.bishop, 2), Flag('cathedral')]),
    Choice('Heaven can wait', 'The Bishop prays for you, loudly.',
        [Loyalty(Courtier.bishop, -1)]),
    arc: 'cathedral',
    about: Courtier.bishop,
    pleas: [
      Plea(Courtier.bishop, 'Build it, Majesty, and heaven will remember your name.', forA: true),
      Plea(Courtier.merchant, 'Stone is expensive, Majesty, and heaven does not pay taxes.', forA: false),
    ],
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
        [Loyalty(Courtier.jester, -3), Loyalty(Courtier.spymaster, 1), Depart(Courtier.jester)]),
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
        [Gold(-2), Points(1), Say(Courtier.spymaster, 'Paying only teaches them the price.')]),
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
    Choice('Banish him', 'The Jester leaves the hall in silence.',
        [Loyalty(Courtier.jester, -3), Depart(Courtier.jester)]),
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
    pleas: [
      Plea(Courtier.bishop, 'Mercy to the poor is never wasted, Majesty.', forA: true),
      Plea(Courtier.duke, 'The mill sits on Ashcombe land, Majesty. The law is the law.', forA: false),
    ],
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

/// How a courtier makes their entrance at court.
enum Entrance {
  /// Marches in from the side, step by step.
  march,

  /// Descends from above in a glow.
  descend,

  /// Lands with a stomp from on high.
  stomp,

  /// Steps out of the shadows.
  shadow,

  /// Rolls in like a coin.
  roll,

  /// Cartwheels in.
  cartwheel,
}

/// How a courtier leaves.
enum Exit {
  /// Runs for it.
  dash,

  /// Dies: rises away, pale.
  ghost,

  /// Thrown out: shaken, then dropped.
  banished,

  /// Bows and walks away.
  walk,

  /// Vanishes in a puff.
  poof,
}

/// Each courtier's signature entrance.
Entrance entranceOf(Courtier c) => switch (c) {
      Courtier.king => Entrance.descend,
      Courtier.duke => Entrance.march,
      Courtier.bishop => Entrance.descend,
      Courtier.general => Entrance.stomp,
      Courtier.spymaster => Entrance.shadow,
      Courtier.merchant => Entrance.roll,
      Courtier.jester => Entrance.cartwheel,
    };

/// How each courtier arrives at court.
const arrivals = <Courtier, String>{
  Courtier.duke: 'The Duke rides in from the north with a hundred retainers.',
  Courtier.bishop: 'The Bishop arrives in a cloud of incense and hymns.',
  Courtier.general: 'The General marches in, boots still muddy from the border.',
  Courtier.spymaster: 'The Spymaster is simply there one morning, as if always there.',
  Courtier.merchant: 'The Merchant arrives with a wagon of gifts and a ledger of debts.',
  Courtier.jester: 'The Jester cartwheels into the hall, bells jangling.',
};

/// Why each courtier might leave court of their own accord, and how.
const departures = <Courtier, List<(String, Exit)>>{
  Courtier.duke: [
    ('The Duke rides north to the family estates, and stays there.', Exit.walk),
    ('The Duke falls from his horse in the hunt.', Exit.ghost),
  ],
  Courtier.bishop: [
    ('The Bishop leaves on pilgrimage to the south.', Exit.walk),
    ('The Bishop is called to the Holy See, and goes gladly.', Exit.poof),
  ],
  Courtier.general: [
    ('The General retires to the coast, nursing old wounds.', Exit.walk),
    ('The General falls in a border skirmish.', Exit.ghost),
  ],
  Courtier.spymaster: [
    ('The Spymaster vanishes one night. Nobody is surprised.', Exit.poof),
    ('The Spymaster is found at the foot of the tower.', Exit.ghost),
  ],
  Courtier.merchant: [
    ('The Merchant sails south to chase a fortune.', Exit.dash),
    ('The Merchant retires rich, and smug.', Exit.walk),
  ],
  Courtier.jester: [
    ('The Jester runs off with a troupe of players.', Exit.dash),
    ('The Jester tells one joke too many and is thrown out.', Exit.banished),
  ],
};

/// A coming or going at court, told with the next round's news.
class CourtNews {
  const CourtNews(this.role, this.color, this.text, {this.exit});
  final Courtier role;
  final int color;
  final String text;

  /// How they left; null for an arrival.
  final Exit? exit;
  bool get arrived => exit == null;

  Map<String, dynamic> toJson() =>
      {'role': role.name, 'color': color, 'text': text, 'exit': exit?.name};

  static CourtNews fromJson(Map<String, dynamic> j) => CourtNews(
        Courtier.values.byName(j['role'] as String),
        j['color'] as int,
        j['text'] as String,
        exit: j['exit'] == null ? null : Exit.values.byName(j['exit'] as String),
      );
}

/// A courtier joins the court before the next round, if there's room.
class Arrive extends Effect {
  const Arrive(this.courtier);
  final Courtier courtier;
}

/// Gold in or out of the royal coffers.
class Gold extends Effect {
  const Gold(this.delta);
  final int delta;
}

/// How each courtier introduces themselves to a new King.
const introductions = <Courtier, String>{
  Courtier.duke: 'The Duke of Ashcombe, Majesty. My family has knelt to six kings. I hope you will be the first worth it.',
  Courtier.bishop: 'I anointed your father, Majesty, and today I anoint you. Heaven is watching. So am I.',
  Courtier.general: 'The army is yours, Majesty. Keep it fed and paid, and it will keep you crowned.',
  Courtier.spymaster: 'You won’t remember meeting me, Majesty. That is rather the point.',
  Courtier.merchant: 'Congratulations, Majesty! House Coyne brings a small gift. And a small invoice.',
  Courtier.jester: 'Long live the King! Well. As long as possible.',
  Courtier.king: '',
};

/// The everyday talk of the council between matters.
const chatter = <Courtier, List<String>>{
  Courtier.duke: [
    'The northern harvest is in, Majesty. Ashcombe’s barns are full, for once.',
    'My tenants grumble about the new tolls. My tenants grumble about everything.',
  ],
  Courtier.bishop: [
    'The bells ring for you every morning, Majesty. I hope you hear them.',
    'The cathedral roof leaks again. Heaven tests us in small ways too.',
  ],
  Courtier.general: [
    'The border is quiet, Majesty. Too quiet, if you ask me.',
    'The recruits can march. Mostly in the same direction.',
  ],
  Courtier.spymaster: [
    'Three letters from Karsk this week, Majesty. None of them addressed to me. I read them anyway.',
    'Someone in this room talks in their sleep. I won’t say who.',
  ],
  Courtier.merchant: [
    'Prices are up, Majesty. Mine especially.',
    'The harbour is full of ships. Every one of them owes me money.',
  ],
  Courtier.jester: [
    'Has anyone noticed the throne squeaks? No? Just me, then.',
    'I’ve written a song about the council. Nobody comes out of it well.',
  ],
  Courtier.king: [''],
};

/// What the council says when Karsk is on everyone's mind.
const warChatter = <Courtier, String>{
  Courtier.duke: 'Varric’s banners on the far bank again, Majesty. My riders count more every week.',
  Courtier.bishop: 'I pray for peace, Majesty. I also pray for good walls.',
  Courtier.general: 'If Varric wants a war, Majesty, he can have one. I’ve been saving it.',
  Courtier.spymaster: 'Karsk is buying horses, Majesty. Lots of horses.',
  Courtier.merchant: 'War is terrible for trade, Majesty. Unless one is selling swords.',
  Courtier.jester: 'Good news! Karsk hates us all equally.',
  Courtier.king: '',
};

/// A courtier taking up a royal charge.
const acceptances = <Courtier, String>{
  Courtier.duke: 'Ashcombe will see it done, Majesty.',
  Courtier.bishop: 'With heaven’s help, Majesty, and mine.',
  Courtier.general: 'Consider it done, Majesty.',
  Courtier.spymaster: 'It is already in hand, Majesty.',
  Courtier.merchant: 'For a modest fee, Majesty. I jest. Mostly.',
  Courtier.jester: 'Me? Well, somebody has to.',
  Courtier.king: '',
};

/// A courtier answering someone who argued the other way. {other} is
/// who they're answering ("the Duke").
const retorts = <Courtier, String>{
  Courtier.duke: 'With respect, Majesty, {other} has never held land worth defending.',
  Courtier.bishop: '{Other} speaks for the purse, Majesty. I speak for your soul.',
  Courtier.general: 'Talk, talk. {Other} has never stood in a shield wall.',
  Courtier.spymaster: 'Interesting advice, {other}. I wonder who taught you to give it.',
  Courtier.merchant: '{Other} forgets who pays for all this, Majesty.',
  Courtier.jester: '{Other} is right, of course. That is what worries me.',
  Courtier.king: '',
};

/// How courtiers take a round's outcome.
const cheers = <Courtier, String>{
  Courtier.duke: 'Well done, Majesty. Ashcombe is pleased.',
  Courtier.bishop: 'Heaven smiles on this court today.',
  Courtier.general: 'That’s how it’s done!',
  Courtier.spymaster: 'Exactly as I foresaw. Naturally.',
  Courtier.merchant: 'Profitable. My favourite word.',
  Courtier.jester: 'Huzzah! Someone write that down before we forget how.',
  Courtier.king: '',
};
const groans = <Courtier, String>{
  Courtier.duke: 'My grandfather would never have let that happen.',
  Courtier.bishop: 'We must all pray harder. Some of us much harder.',
  Courtier.general: 'Sloppy. We’ll drill until it isn’t.',
  Courtier.spymaster: 'Someone talked. I’ll find out who.',
  Courtier.merchant: 'That will cost us, Majesty. It always does.',
  Courtier.jester: 'Well, it could have been worse. I can’t think how.',
  Courtier.king: '',
};

/// Regnal names for the solo King, one per reign.
const regnalNames = [
  'Edmund', 'Matilda', 'Leofric', 'Eleanor', 'Aldous', 'Isabeau', 'Cedric', 'Rowena',
];

/// Roman numerals for reigns: I, II, III ...
String roman(int n) {
  const values = [10, 9, 5, 4, 1];
  const symbols = ['X', 'IX', 'V', 'IV', 'I'];
  final out = StringBuffer();
  var rest = n;
  for (var i = 0; i < values.length; i++) {
    while (rest >= values[i]) {
      out.write(symbols[i]);
      rest -= values[i];
    }
  }
  return out.toString();
}

/// What a courtier calls out mid-hand when their task is done.
const taskDone = <Courtier, String>{
  Courtier.duke: 'Ashcombe delivers, Majesty!',
  Courtier.bishop: 'A small miracle!',
  Courtier.general: 'Objective taken!',
  Courtier.spymaster: 'All according to plan.',
  Courtier.merchant: 'Paid in full!',
  Courtier.jester: 'Ta-da!',
  Courtier.king: '',
};

/// ...and when it fails.
const taskFailed = <Courtier, String>{
  Courtier.duke: 'Curse it!',
  Courtier.bishop: 'Forgive me, Majesty.',
  Courtier.general: 'Fall back! Regroup!',
  Courtier.spymaster: 'That was not the plan.',
  Courtier.merchant: 'A total loss!',
  Courtier.jester: 'Oops.',
  Courtier.king: '',
};


/// What you say back when each courtier first introduces themselves.
const kingReplies = <Courtier, String>{
  Courtier.duke: 'Then let us not disappoint your ancestors, Duke.',
  Courtier.bishop: 'Keep watching, Bishop. I intend to give you something to see.',
  Courtier.general: 'Fed, paid and loyal. I will hold you to all three.',
  Courtier.spymaster: 'I will remember you, Spymaster. That is rather the point too.',
  Courtier.merchant: 'Put the invoice with the others.',
  Courtier.jester: 'Make it long enough for a good joke or two.',
  Courtier.king: '',
};

/// What you say when someone brings a matter before you.
const kingPrompts = [
  'Go on.',
  'Speak plainly.',
  'And what would you have me do?',
  'I’m listening.',
];


/// A courtier answering back when someone turns on them. {other} is who
/// attacked them ("the Duke").
const counters = <Courtier, String>{
  Courtier.duke: 'And you, {other}, have never held anything you didn’t buy or steal.',
  Courtier.bishop: 'I will pray for you, {other}. Clearly somebody must.',
  Courtier.general: 'Say that to me on a battlefield, {other}.',
  Courtier.spymaster: 'Careful, {other}. I keep notes. Very thorough notes.',
  Courtier.merchant: 'Sticks and stones, {other}. Gold pays for both.',
  Courtier.jester: 'Oh, {other}, you wound me. Truly. Somewhere.',
  Courtier.king: '',
};

/// Asides from whoever isn't arguing.
const asides = <Courtier, List<String>>{
  Courtier.duke: ['In my father’s day we settled this with a duel.'],
  Courtier.bishop: ['Must every council end in shouting?'],
  Courtier.general: ['Wake me when you’ve decided.'],
  Courtier.spymaster: ['Fascinating. Do go on, both of you.'],
  Courtier.merchant: ['Could we settle this before supper? I have a dinner booked.'],
  Courtier.jester: [
    'Can we vote on lunch next? I feel strongly about lunch.',
    'I’m writing all of this down for the play.',
  ],
  Courtier.king: [''],
};

/// What each courtier makes of the news when the herald reads it.
const newsQuips = <Courtier, String>{
  Courtier.duke: 'In my father’s day, Majesty, we’d have hanged someone by now.',
  Courtier.bishop: 'We must pray on it, Majesty. And then, perhaps, do something.',
  Courtier.general: 'If it needs a sword, Majesty, you know where I am.',
  Courtier.spymaster: 'I heard about this yesterday, Majesty. I was waiting to see who else would.',
  Courtier.merchant: 'And how much is this going to cost us, Majesty?',
  Courtier.jester: 'Wonderful. More meetings.',
  Courtier.king: '',
};
