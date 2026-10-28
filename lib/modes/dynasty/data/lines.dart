/// The old Dynasty's court lines, kept as data for the roguelike to build
/// on: how each courtier arrives, leaves, introduces themselves, chatters,
/// argues, cheers and groans, and what the King says back.
library;

import '../../../game/courtiers.dart';

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
