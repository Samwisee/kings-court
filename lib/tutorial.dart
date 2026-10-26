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
  });

  final String title;

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

/// The pictures that go with the tutorial's opening pages (drawn in
/// play/tutorial_intro.dart).
enum IntroArt { court, goal, cards, trick, follow, courtCards, tasks, together, speak, table, lessons }

/// One page of the tutorial's opening: read at your own pace, each waits
/// for Continue.
class IntroPage {
  const IntroPage(this.title, this.paragraphs, this.art);
  final String title;
  final List<String> paragraphs;
  final IntroArt art;
}

/// Before the lessons: the story, the goal, and how cards, tricks and
/// tasks work, for someone who has never played a trick-taking game.
const introPages = <IntroPage>[
  IntroPage('Welcome to the court', [
    'The old King is gone, and the great houses gather in the throne hall. In King’s Court, you and your courtiers play cards together to keep the realm in order.',
    'Everyone is on the same side. You win together or lose together, round by round.',
    'It’s a trick-taking card game, the same family as Hearts, Spades and Bridge, and it’s inspired by The Crew. Never played one? That’s fine: these pages explain everything, then four short lessons let you try each idea.',
  ], IntroArt.court),
  IntroPage('The goal', [
    'Every round, the court is given tasks, such as “Win the 3♥” or “Win the first trick”.',
    'Each task is taken by one player, and that player has to make it happen during the round.',
    'If every task is done, the round is won. If any task fails, the whole court loses the round. So the real game is helping each other: playing your cards so the right person wins the right thing.',
  ], IntroArt.goal),
  IntroPage('The cards', [
    'There are 40 cards. Most belong to one of four suits: ♥ hearts, ♦ diamonds, ♠ spades and ♣ clubs. Each suit runs from the Ace (1, the lowest) up to 9.',
    'Four more cards aren’t in any suit: the Court Cards. From lowest to highest they are the Joker, the Jack, the Queen and the King. They beat every plain card.',
    'Whoever is dealt the King card is the King for the round: they take the first task and play first. In the tutorial, that’s always you.',
  ], IntroArt.cards),
  IntroPage('What is a trick?', [
    'Cards are played in tricks. One player leads: they put any card from their hand in the middle. Then, in turn, everyone else plays one card.',
    'Once everyone has played, the highest card of the suit that was led wins the trick. Its player takes all the cards in it, and leads the next trick.',
    'Winning a trick also means winning every card in it, whoever played them. That matters for tasks like “Win the 3♥”.',
    'A round goes on until everyone’s hand is empty.',
  ], IntroArt.trick),
  IntroPage('Follow the suit led', [
    'If you have a card of the suit that was led, you must play one. This is called following suit. You choose which one.',
    'If you have none of that suit, you may play any card. A card of a different suit can’t win the trick, unless it’s a Court Card.',
    'Don’t worry about breaking the rules: the app only lets you play cards you’re allowed to, and shades the others.',
  ], IntroArt.follow),
  IntroPage('Court Cards win', [
    'A Court Card beats any plain card of any suit. If more than one is played, the highest wins: the King beats the Queen, the Queen beats the Jack, the Jack beats the Joker.',
    'You can play a Court Card when you lead, or when you can’t follow suit. If a Court Card is led, everyone must play a Court Card if they have one.',
    'Other games call cards like these trumps.',
  ], IntroArt.courtCards),
  IntroPage('Reading a task', [
    'A task card says what its owner must do. The number in the corner is how hard it is, in crowns.',
    '“Win” means the card or trick ends up with you. “Don’t win” means it must go to someone else. A task about the first tricks is settled once they’re played; most others are decided by the end of the round.',
    'During a round, tap any task to see whose it is, what it means in plain words, the game words it uses, and how it’s going. Many tasks count their progress in the corner, like “2/4” or “safe 1/3”.',
  ], IntroArt.tasks),
  IntroPage('Playing together', [
    'Before the first trick, everyone takes tasks one at a time, starting with the King. Take the tasks your cards can do: high cards win tricks, low cards lose them.',
    'You can’t say what’s in your hand. Watch what the others play instead, and once a round you may show one card (next page).',
    'If no task suits your cards when it’s your turn to pick, you may pass once a round and let the next player choose.',
    'Lost count? The grid button beside your hand shows every card: which have been played, in which trick and by whom, and which are still to come.',
    'Your courtiers on screen play with you, not against you. They’ll try to help you with your tasks, and you can help them with theirs.',
  ], IntroArt.together),
  IntroPage('Showing a card', [
    'Once a round, each player may show one card to everyone. It stays in their hand, face up, until it’s played.',
    'You can only show your highest, lowest or only card of a suit, and everyone sees which. A 7♠ marked “highest” tells the table you have no ♠ above it, so the 8♠ and 9♠ are with someone else (or set aside). Court Cards can never be shown.',
    'To show a card, tap the speech button at the right of your hand, then tap the card. You can do it while the tasks are being chosen (the table pauses for a moment before the first pick), before a trick starts, or between tricks. Tap it mid-trick and you’ll show your card as soon as the trick ends.',
    'Use it to help: show a card someone’s task needs, or warn that you can’t take a suit.',
  ], IntroArt.speak),
  IntroPage('At a real table', [
    'You can also play King’s Court with friends and a real pack of cards, 2 to 6 players around a table.',
    'Take an ordinary pack and keep the Ace to 9 of each suit (the Ace counts as 1). Put the 10s and picture cards aside, then add four Court Cards: a Joker, a Jack, a Queen and a King. They play as their own suit, whatever suit is printed on them.',
    'When you set up a game, choose In person, and put the phone in the middle. Whoever holds the King card taps their seat, the app deals the tasks, and each player drags the tasks they take onto their seat. Tap a task to mark it done or failed.',
    'With two players, the King also plays a third hand, the Dummy. How to Play in the menu has all the details.',
  ], IntroArt.table),
  IntroPage('Now try it', [
    'Four short lessons, each with one idea. The cards are set up so each lesson always plays out the same way, and a note under the table tells you what to do. Your best card glows.',
    'Take your time: the courtiers wait for you.',
  ], IntroArt.lessons),
];

/// The names the two courtiers go by in the tutorial.
const tutorialCourtiers = ['You', 'The Duke', 'The Bishop'];

/// Their houses, for their tokens (yours is the General's).
const tutorialHouses = [Courtier.general, Courtier.duke, Courtier.bishop];

const lessons = <Lesson>[
  Lesson(
    title: 'Lead and win',
    intro:
        'King’s Court is played together: every round has tasks, and the court wins when every task is done.',
    tasks: ['Win the first trick'],
    pick: 'You hold the King card, so you are the King and choose first. Tap the task to take it.',
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
    intro:
        'Many tasks ask you to win a certain card. A card is yours when it lands in a trick you win, whoever played it.',
    tasks: ['Win the 3♥'],
    pick: 'Tap “Win the 3♥” to take it.',
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
    intro:
        'The Joker, Jack, Queen and King are the Court Cards. They beat every suit, from the Joker (lowest) to the King (highest).',
    tasks: ['Win the 7♥ with a Court Card'],
    pick: 'Tap the task to take it. You have no ♥ of your own, so someone else will have to lead one.',
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
    intro:
        'Everyone wins or loses together. Your courtiers have tasks too, and a good King helps them.',
    tasks: ['Win the A♦', 'Win the 6♣'],
    pick: 'There are two tasks. Tap “Win the A♦” to take it; the Duke will take the other.',
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
