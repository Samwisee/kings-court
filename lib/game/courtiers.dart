/// The courtiers who sit at the King's table: the great houses, each with
/// a sigil (the token's shape), a motto, a little history and the power
/// its courtier once held (kept with the house for the roguelike to come),
/// and how they come and go.
library;

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
