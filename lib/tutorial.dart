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

/// The names the two courtiers go by in the tutorial.
const tutorialCourtiers = ['You', 'The Duke', 'The Bishop'];

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
