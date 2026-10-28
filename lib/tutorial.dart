/// The tutorial: short, set-up rounds that teach King's Court one idea at a
/// time. Each lesson fixes the tasks, everyone's cards and what the
/// courtiers play, so it always unfolds the same way, while a coach line
/// under the table says what to do and why.
///
/// You sit in seat 0 and hold the King card, so you are the King and lead
/// the first trick. The two courtiers (seats 1 and 2) follow a script for
/// the tricks that matter; if you go off the script, the bots play as
/// normal and the lesson can be tried again.
library;

import 'courtiers.dart';
import 'engine/cards.dart';

class Lesson {
  const Lesson({
    required this.title,
    required this.intro,
    required this.tasks,
    required this.pick,
    required this.cards,
    this.avoid = const {},
    this.plays = const {},
    this.hints = const {},
    this.yourTurn = const {},
    this.watch = const {},
    this.afterTrick = const {},
    required this.won,
    required this.lost,
    this.pages = const [],
  });

  final String title;

  /// The pages read just before this lesson: the rules it plays out.
  final List<IntroPage> pages;

  /// Shown while the round is being set up.
  final String intro;

  /// The tasks on the table, by description (see tasks.dart).
  final List<String> tasks;

  /// What to do when it's your turn to take a task.
  final String pick;

  /// Cards each seat must hold, by label ("9♠", "King").
  final List<List<String>> cards;

  /// Suits a seat must not be dealt beyond its listed cards, so the lesson
  /// plays out as planned (say, the courtier's only ♥).
  final Map<int, Set<Suit>> avoid;

  /// The courtiers' script: trick number to seat to the card they play.
  final Map<int, Map<int, String>> plays;

  /// The card to suggest to you on each trick (it glows in your hand).
  final Map<int, String> hints;

  /// What the coach says on your turn, on the courtiers' turns, and once
  /// each trick is won, by trick number.
  final Map<int, String> yourTurn;
  final Map<int, String> watch;
  final Map<int, String> afterTrick;

  /// The lesson's last word, after a win or a loss.
  final String won;
  final String lost;

  PlayingCard? hint(int trick) =>
      hints[trick] == null ? null : PlayingCard.parse(hints[trick]!);

  PlayingCard? scripted(int trick, int seat) {
    final label = plays[trick]?[seat];
    return label == null ? null : PlayingCard.parse(label);
  }

  /// Everyone's hand for this lesson: the listed cards, then the rest of
  /// the deck shared out in order, skipping any suit a seat must avoid.
  /// One card is set aside, as in any three-player round.
  ({List<List<PlayingCard>> hands, List<PlayingCard> setAside}) deal() {
    const players = 3;
    final each = handSize(players);
    final hands = [
      for (final seat in cards) [for (final l in seat) PlayingCard.parse(l)!]
    ];
    final used = hands.expand((h) => h).toSet();
    final rest = [for (final c in fullDeck()) if (!used.contains(c)) c];
    // Set aside a plain card nobody needs: the last of the deck.
    final setAside = [rest.removeLast()];
    int seat = 0;
    for (final card in rest) {
      for (int tries = 0; tries < players; tries++) {
        final s = (seat + tries) % players;
        if (hands[s].length < each && !(avoid[s]?.contains(card.suit) ?? false)) {
          hands[s].add(card);
          seat = (s + 1) % players;
          break;
        }
      }
    }
    for (final h in hands) {
      h.sort();
    }
    return (hands: hands, setAside: setAside);
  }
}

/// The pictures that go with the tutorial's pages (drawn in
/// play/tutorial_intro.dart).
enum IntroArt {
  court,
  goal,
  cards,
  trick,
  firstRound,
  follow,
  winCards,
  tasks,
  courtCards,
  lead,
  choosing,
  speak,
  tracker,
  help,
  table,
  ready,
}

/// One page of the tutorial: read at your own pace, each waits for
/// Continue. Task cards on a page can be tapped, as in a game.
class IntroPage {
  const IntroPage(this.title, this.paragraphs, this.art);
  final String title;
  final List<String> paragraphs;
  final IntroArt art;
}

/// Before lesson 1: the story, the goal, the cards and what a trick is.
const _beforeLead = <IntroPage>[
  IntroPage('Welcome to the court', [
    'The old King is gone, and the great houses gather in the throne hall. In King’s Court, you and your courtiers play cards together to keep the realm in order.',
    'Everyone is on the same side. You win together or lose together, round by round.',
    'It’s a trick-taking card game, like Hearts, Spades or Bridge, inspired by The Crew. Never played one? That’s fine. The tutorial teaches a few rules at a time, and after each part you play a short round that uses them.',
  ], IntroArt.court),
  IntroPage('The goal', [
    'Every round, the court is dealt tasks, such as “Win the 3♥” or “Win the first trick”.',
    'Each task is taken by one player, and that player has to make it happen before the round ends.',
    'If every task is done, the round is won. If any task fails, the whole court loses the round. So the real game is helping each other: playing your cards so the right person wins the right thing.',
    'Tap either task to read it, just as you can in a game.',
  ], IntroArt.goal),
  IntroPage('The cards', [
    'There are 40 cards. Most belong to one of four suits: ♥ hearts, ♦ diamonds, ♠ spades and ♣ clubs. Each suit runs from the Ace (1, the lowest) up to 9.',
    'Four more cards belong to no suit: the Court Cards. From lowest to highest they are the Joker, the Jack, the Queen and the King. You’ll meet them properly in lesson 3.',
    'Whoever is dealt the King card is the King for the round: they choose the first task and play the first card. In the tutorial that’s always you.',
  ], IntroArt.cards),
  IntroPage('Tricks', [
    'Cards are played in tricks. One player leads: they put any card from their hand in the middle. Then each other player, in turn, plays one card on top.',
    'When everyone has played, the highest card of the suit that was led wins the trick. Its player takes the trick and leads the next one.',
    'For example: the Duke leads the 4♠, you play the 9♠ and the Bishop plays the 2♠. All three are ♠, and your 9♠ is the highest, so the trick is yours and you lead next.',
    'A round goes on, trick after trick, until every hand is empty.',
  ], IntroArt.trick),
  IntroPage('Lesson 1: lead and win', [
    'Your first round: one task, “Win the first trick”. As the King you take it (press and hold a task to take it; a tap just reads it), then lead the first trick.',
    'You hold the 9♠, the highest ♠ there is. Lead it, and whatever ♠ the courtiers play, yours wins.',
    'A note under the table guides you, and the card it suggests glows in your hand.',
  ], IntroArt.firstRound),
];

/// Before lesson 2: following suit, and winning the cards in a trick.
const _beforeCard = <IntroPage>[
  IntroPage('Follow suit', [
    'If you hold a card of the suit that was led, you must play one. This is called following suit. You choose which one.',
    'If you hold none of that suit, you may play any card. A card of another suit can’t win the trick (unless it’s a Court Card, in lesson 3).',
    'For example: ♥ is led and you hold the 2♥ and 8♥. You must play one of them. Your other cards are shaded, and the game won’t let you play them.',
  ], IntroArt.follow),
  IntroPage('Winning cards', [
    'Winning a trick means winning every card in it, whoever played them. That’s how tasks like “Win the 3♥” get done.',
    'For example: you lead the 8♥. The Duke’s only ♥ is the 3♥, so he has to follow with it, and the Bishop plays the 5♥. Your 8♥ is highest, so the trick, and the 3♥ in it, is yours.',
    'That’s lesson 2: lead the suit of the card you want, and make whoever holds it follow suit.',
  ], IntroArt.winCards),
  IntroPage('Reading a task', [
    'The number by the crown is how hard a task is. Marks beside it add rules: a barred circle means the King can’t take it, an i in a circle means there’s small print, and a struck-out Court Card means the trick can’t hold any Court Cards.',
    '“Win” means the card or trick must end up with you. “Win no …” or “Win none …” means it must go to someone else.',
    'During a round, many tasks count up in the corner, like “1/3” or “safe 2/5”, and cards a task needs are crossed out once won.',
    'Tap any of these tasks to see its close-up: what it means, its marks explained and the cards it’s about.',
  ], IntroArt.tasks),
];

/// Before lesson 3: Court Cards, and passing the lead.
const _beforeCourt = <IntroPage>[
  IntroPage('Court Cards', [
    'The Joker, Jack, Queen and King beat every plain card, whatever suit was led. If more than one is played, the highest wins: King over Queen over Jack over Joker.',
    'You may play one when you lead, or when you can’t follow suit. If a Court Card is led, everyone must play a Court Card if they have one.',
    'For example: the 9♦ is led and the 3♦ follows. You have no ♦ left, so you play the Joker, and the lowest Court Card still beats the 9♦.',
  ], IntroArt.courtCards),
  IntroPage('Handing over the lead', [
    'Whoever wins a trick leads the next. Sometimes the card you need will only be led by someone else, so you play low on purpose to let them win.',
    'In lesson 3 your task is “Win the 7♥ with a Court Card”, but you have no ♥. Play your 2♣ under the Duke’s 9♣: he wins and leads next. When he leads the 7♥, you can’t follow, so you take it with your Jack.',
  ], IntroArt.lead),
];

/// Before lesson 4: choosing tasks together, showing a card, keeping count.
const _beforeHelp = <IntroPage>[
  IntroPage('Choosing tasks', [
    'Before the first trick, everyone takes tasks one at a time, starting with the King and going round the table. Take the tasks your cards can do: high cards win tricks, low cards lose them.',
    'Once a round, if nothing suits you, you may pass and let the next player choose. A task only one player can take is marked in their colour.',
    'You may not say what’s in your hand or what anyone should play. Watch what the others take and play instead.',
  ], IntroArt.choosing),
  IntroPage('Showing a card', [
    'Once a round, each player may show one card to everyone: their highest, lowest or only card of a suit, saying which. It stays in their hand, face up, until it’s played. Court Cards can never be shown.',
    'For example: the Duke shows the 7♠ as his highest ♠. Now everyone knows the 8♠ and 9♠ are with someone else.',
    'To show a card, tap the speech button at the right of your hand, then the card. The table pauses for this before the first pick, and you can also do it before or between tricks.',
  ], IntroArt.speak),
  IntroPage('Keeping count', [
    'The card tracker button beside your hand shows every card in the deck in rows by suit. A card that’s been played is shaded and outlined in the colour of whoever played it, with the number of the trick it fell in. Cards in your hand are outlined in your colour.',
    'Tap a player in the key at the top to see what they may still hold, worked out from what they’ve played and shown: bright cards they certainly hold, faint ones they may.',
    'Hold the eye at the top (or the space bar) to see the table behind it for a moment.',
  ], IntroArt.tracker),
  IntroPage('Lesson 4: help each other', [
    'Two tasks this time. You take “Win the A♦”; the Duke takes “Win the 6♣”.',
    'First lead your 9♦ to draw out the A♦. Then help the Duke: he holds the 8♣, so lead your 6♣ low and let him win it.',
  ], IntroArt.help),
];

/// After the last lesson: playing with a real deck, and what's next.
const outroPages = <IntroPage>[
  IntroPage('At a real table', [
    'You can also play with friends and a real pack, 2 to 6 players. Keep the Ace to 9 of each suit, put the 10s and picture cards aside, and add a Joker, a Jack, a Queen and a King as the Court Cards, whatever suits are printed on them.',
    'Choose In person when you set up a game and put the phone in the middle. Whoever holds the King card taps their seat, the tasks are dealt, and each player drags the tasks they take onto their seat. Tap a task to mark it done or failed.',
    'With two players, the King also plays a third hand, the Dummy.',
  ], IntroArt.table),
  IntroPage('You’re ready', [
    'Real rounds have more tasks, and some bring wax seals (tasks to be done in order) and royal decrees (a rule for the round). How to Play in the menu explains them all.',
    'Free play is a good place to start. Dynasty tells a story of kings.',
  ], IntroArt.ready),
];

/// Every page of the tutorial, in the order they're read.
List<IntroPage> get introPages => [
      for (final l in lessons) ...l.pages,
      ...outroPages,
    ];

/// The names the two courtiers go by in the tutorial.
const tutorialCourtiers = ['You', 'The Duke', 'The Bishop'];

/// Their houses, for their tokens (yours is the General's).
const tutorialHouses = [Courtier.general, Courtier.duke, Courtier.bishop];

const lessons = <Lesson>[
  Lesson(
    title: 'Lead and win',
    pages: _beforeLead,
    intro:
        'King’s Court is played together: every round has tasks, and the court wins when every task is done.',
    tasks: ['Win the first trick'],
    pick: 'You hold the King card, so you are the King and choose first. Tap a task to read it; press and hold it to take it.',
    cards: [
      ['King', '9♠'],
      ['3♠'],
      ['5♠'],
    ],
    plays: {
      0: {1: '3♠', 2: '5♠'},
    },
    hints: {0: '9♠'},
    yourTurn: {
      0: 'The King leads the first trick. The highest card of the suit led wins, so lead your 9♠ (it’s glowing).',
    },
    watch: {0: 'Everyone must play the suit that was led if they can.'},
    afterTrick: {
      0: 'Both courtiers had ♠, so they had to follow with ♠. Your 9♠ was the highest, so the trick is yours.',
    },
    won: 'Your task is done, so the round is won. Next: winning a particular card.',
    lost: 'The first trick got away. Lead your highest ♠, the 9♠, and nobody can beat it.',
  ),
  Lesson(
    title: 'Win a card',
    pages: _beforeCard,
    intro:
        'Many tasks ask you to win a certain card. A card is yours when it lands in a trick you win, whoever played it.',
    tasks: ['Win the 3♥'],
    pick: 'Press and hold “Win the 3♥” to take it.',
    cards: [
      ['King', '8♥'],
      ['3♥'],
      ['5♥'],
    ],
    avoid: {
      1: {Suit.hearts},
    },
    plays: {
      0: {1: '3♥', 2: '5♥'},
    },
    hints: {0: '8♥'},
    yourTurn: {
      0: 'The Duke has the 3♥. Lead a high ♥ and anyone holding ♥ has to follow. Play your 8♥.',
    },
    watch: {0: 'Watch: the courtiers must follow with a ♥.'},
    afterTrick: {
      0: 'The 3♥ was the Duke’s only ♥, so he had to play it. Your 8♥ took the trick, and the 3♥ with it.',
    },
    won: 'You drew the card out by leading its suit. Next: the Court Cards.',
    lost: 'Lead your 8♥: the courtiers must follow with ♥, and the 3♥ falls into your trick.',
  ),
  Lesson(
    title: 'Court Cards',
    pages: _beforeCourt,
    intro:
        'The Joker, Jack, Queen and King are the Court Cards. They beat every suit, from the Joker (lowest) to the King (highest).',
    tasks: ['Win the 7♥ with a Court Card'],
    pick: 'Press and hold the task to take it. You have no ♥ of your own, so someone else will have to lead one.',
    cards: [
      ['King', 'Jack', '2♣'],
      ['9♣', '7♥'],
      ['4♣', '2♥'],
    ],
    avoid: {
      0: {Suit.hearts},
    },
    plays: {
      0: {1: '9♣', 2: '4♣'},
      1: {1: '7♥', 2: '2♥'},
    },
    hints: {0: '2♣', 1: 'Jack'},
    yourTurn: {
      0: 'First, hand over the lead. Play your 2♣: the Duke will win the trick and lead the next one.',
      1: 'You have no ♥, so you don’t have to follow. When you can’t follow, you may play anything, so play a Court Card. Try the Jack.',
    },
    watch: {
      0: 'The Duke’s 9♣ is the highest ♣.',
      1: 'The Duke leads the 7♥.',
    },
    afterTrick: {
      0: 'The Duke won, so the Duke leads next.',
      1: 'A Court Card beats any suit, so your Jack took the 7♥. If a Court Card is led, everyone must follow with one if they can.',
    },
    won: 'Court Cards are your trump cards, and the King card is the highest card of all. Next: helping each other.',
    lost: 'Give the lead away with your 2♣, then beat the 7♥ with your Jack when you can’t follow ♥.',
  ),
  Lesson(
    title: 'Help each other',
    pages: _beforeHelp,
    intro:
        'Everyone wins or loses together. Your courtiers have tasks too, and a good King helps them.',
    tasks: ['Win the A♦', 'Win the 6♣'],
    pick: 'There are two tasks. Press and hold “Win the A♦” to take it; the Duke will take the other.',
    cards: [
      ['King', '9♦', '6♣'],
      ['A♦', '8♣'],
      ['7♦', '2♣'],
    ],
    avoid: {
      1: {Suit.diamonds},
    },
    plays: {
      0: {1: 'A♦', 2: '7♦'},
      1: {1: '8♣', 2: '2♣'},
    },
    hints: {0: '9♦', 1: '6♣'},
    yourTurn: {
      0: 'Your task first: lead the 9♦ to draw out the A♦.',
      1: 'Now help the Duke: he needs the 6♣ and holds a higher ♣. Lead your 6♣ so he can win it.',
    },
    watch: {
      0: 'The Duke must follow with his only ♦.',
      1: 'The Duke takes it with his 8♣.',
    },
    afterTrick: {
      0: 'The A♦ is yours. One task left: the Duke’s.',
      1: 'The Duke won the 6♣, so every task is done.',
    },
    won: 'That’s the heart of the game: plan together and help each other. You’re ready for the court.',
    lost: 'Lead the 9♦ for your A♦, then lead the 6♣ so the Duke can win it with his 8♣.',
  ),
];
