/// Help for reading tasks: what each one means in plain words, the game
/// words it uses, and how it's going in the current round. Written for
/// someone who has never played a trick-taking game.
///
/// Pure Dart, like the engine, so it can be tested without a screen.
library;

import 'engine/cards.dart';
import 'engine/rules.dart';

/// Game words, with what they mean. Shown in a task's close-up when the
/// task uses them, and in the tutorial.
const glossary = <String, String>{
  'Trick':
      'One round of play: someone leads a card, then everyone else plays one card in turn. The best card wins the trick, and its winner takes every card in it.',
  'Win a trick':
      'Play the card that takes the trick. Every card in that trick counts as won by you, whoever played it.',
  'Win a card':
      'A card is yours when it lands in a trick you win. It doesn’t matter who played it.',
  'Lead':
      'Play the first card of a trick. The King leads the first trick; after that, whoever won the last trick leads.',
  'Follow suit':
      'Play a card of the suit that was led. You must if you can; if you can’t, you may play anything.',
  'Suit':
      'The four kinds of plain card: ♥ hearts, ♦ diamonds, ♠ spades and ♣ clubs. Each runs from the Ace (1, lowest) to 9.',
  'Court Cards':
      'The Joker, Jack, Queen and King, from lowest to highest. They aren’t in any suit and beat every plain card.',
  'Ace': 'The 1 of a suit, its lowest card.',
  'The King':
      'Whoever holds the King card this round. The King chooses the first task and leads the first trick.',
  'In a row': 'One straight after another, with no trick in between won by anyone else.',
  'Total':
      'Add up the numbers on the cards in the trick (an Ace counts as 1).',
  'Pass':
      'Once a round, when it’s your turn to choose a task, you may let the next player choose instead.',
  'Show a card':
      'Once a round, show everyone your highest, lowest or only card of a suit, saying which. It stays in your hand, face up, until you play it. Court Cards can’t be shown.',
  'Seal':
      'A wax seal on a task: sealed tasks must be done in order, I before II before III, and Ω last of all.',
  'Royal decree':
      'A rule for one round, read out at its start, such as Silence (no showing cards).',
};

/// Which [glossary] words a task uses, in the order they're worth reading.
List<String> termsIn(String d) {
  final words = <String>[];
  final lower = d.toLowerCase();
  if (lower.contains('trick')) words.add('Trick');
  final aboutCards = !lower.startsWith("don't lead") &&
      !lower.startsWith('win a trick') &&
      RegExp(r'card|[a2-9][♥♦♠♣]|\ds\b|aces|queen|joker|jack').hasMatch(lower);
  if (aboutCards) {
    if (!words.contains('Trick')) words.add('Trick');
    words.add('Win a card');
  } else if (lower.contains('trick')) {
    words.add('Win a trick');
  }
  if (lower.contains('lead')) words.add('Lead');
  if (RegExp(r'[♥♦♠♣]|suit').hasMatch(d)) words.add('Suit');
  if (lower.contains('court card') ||
      lower.contains('queen') ||
      lower.contains('joker') ||
      lower.contains('jack')) {
    words.add('Court Cards');
  }
  if (lower.contains('ace') || RegExp(r'A[♥♦♠♣]').hasMatch(d)) words.add('Ace');
  if (d.contains('the King')) words.add('The King');
  if (lower.contains('show')) words.add('Show a card');
  if (lower.contains('in a row')) words.add('In a row');
  if (lower.contains('total')) words.add('Total');
  return words;
}

const _numbers = {
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
};

String _rankName(String r) => r == 'A' ? 'Ace' : r;

/// What [d] asks for, in plain words, with anything easy to miss spelled
/// out. Every task in the game has an explanation.
String explainTask(String d) {
  final special = _special[d];
  if (special != null) return special;

  // "Win the 3♥", "Win the 4♥ and the 9♠", "Win the 7♣, 8♣ and 9♣".
  final named = RegExp(r'([A2-9])([♥♦♠♣])').allMatches(d).toList();
  if (d.startsWith('Win the ') &&
      named.isNotEmpty &&
      !d.contains(' with ') &&
      !d.contains('last trick')) {
    final cards = [for (final m in named) m.group(0)!];
    final list = cards.length == 1
        ? 'the ${cards.single}'
        : 'the ${cards.sublist(0, cards.length - 1).join(', ')} and ${cards.last}';
    final them = cards.length == 1 ? 'it' : 'every one of them';
    return 'You must end the round having won $list: $them has to be in a trick you win. '
        'It doesn’t matter who plays ${cards.length == 1 ? 'it' : 'them'}. '
        'If anyone else wins ${cards.length == 1 ? 'it' : 'one'}, the task fails. '
        'Tip: lead the suit when you hold a higher card, or let its holder play it into a trick you’ll win.';
  }
  final withCourt = RegExp(r'^Win the (.+) with a Court Card$').firstMatch(d);
  if (withCourt != null) {
    final card = withCourt.group(1)!;
    return 'The $card must fall in a trick that you win by playing a Court Card. '
        'Usually someone leads the ${card.substring(card.length - 1)} suit when you have none, so you can play a Court Card on it. '
        'If the $card is won any other way, the task fails. '
        'You can’t do this if you hold the $card yourself (you can’t play it and a Court Card in the same trick), and you need a Court Card in your hand.';
  }
  final winWith = RegExp(r'^Win a trick with a (\d)$').firstMatch(d);
  if (winWith != null) {
    final r = winWith.group(1)!;
    return 'Win a trick where your winning card is a $r. '
        'That means the $r has to be the highest card of the suit led, and no Court Card is played. '
        'A $r that someone else played doesn’t count: the winning card itself must be the $r.';
  }
  final allFour = RegExp(r'^Win all four (\d)s$').firstMatch(d);
  if (allFour != null) {
    final r = allFour.group(1)!;
    return 'Win every $r: the $r♥, $r♦, $r♠ and $r♣ must all end up in tricks you win. If anyone else wins one, the task fails.';
  }
  final ranks = RegExp(r'^Win (at least|exactly) (two|three) (\d)s$').firstMatch(d);
  if (ranks != null) {
    final n = ranks.group(2)!;
    final r = ranks.group(3)!;
    return ranks.group(1) == 'exactly'
        ? 'By the end of the round, the tricks you win must hold exactly $n ${r}s: no more, no fewer. Any suit counts.'
        : 'Win $n or more ${r}s, of any suit, in the tricks you win.';
  }
  final suits = RegExp(r'^Win (at least|exactly) (\w+) ([♥♦♠♣]) cards?$').firstMatch(d);
  if (suits != null) {
    final n = suits.group(2)!;
    final s = suits.group(3)!;
    return suits.group(1) == 'exactly'
        ? 'Count the $s cards in the tricks you win: by the end of the round there must be exactly $n. Winning a ${_numbers[n]! + 1}th fails the task.'
        : 'Win $n or more $s cards in your tricks. Each trick led in $s can bring you several at once.';
  }
  final noneOf = RegExp(r'^(?:Don’t|Don.t) win any (.+)$').firstMatch(d);
  if (noneOf != null && !d.contains('trick')) {
    final what = noneOf.group(1)!;
    return 'None of the tricks you win may contain $what, whoever played them. '
        'The task is done if you get through the whole round without winning one; it fails the moment you do. '
        'Tip: when one is on the table, play low so someone else takes the trick.';
  }
  final notFirst = RegExp(r'^Don.t win any of the first (\w+) tricks$').firstMatch(d);
  if (notFirst != null) {
    final n = notFirst.group(1)!;
    return 'Lose each of the first $n tricks: someone else must win every one of them. '
        'After trick ${_numbers[n] ?? n}, you’re free to win as many as you like. '
        'Tip: play low cards early, and don’t play a Court Card unless you have to.';
  }
  final courts = RegExp(r'^Win exactly (\w+) Court Cards?').firstMatch(d);
  if (courts != null) {
    final n = courts.group(1)!;
    return 'Count the Court Cards (Joker, Jack, Queen and King) in the tricks you win: by the end of the round there must be exactly $n. '
        'A Court Card goes to whoever plays the highest one in its trick, so plan which of yours to play, and when.';
  }
  final exact = RegExp(r'^Win exactly (\w+) tricks?$').firstMatch(d);
  if (exact != null) {
    final n = exact.group(1)!;
    return 'By the end of the round you must have won exactly $n ${n == 'one' ? 'trick' : 'tricks'}: one more or one fewer fails the task.';
  }
  final first = RegExp(r'^Win the first (two|three) tricks$').firstMatch(d);
  if (first != null) {
    return 'Win every one of the first ${first.group(1)} tricks. You need strong cards: the King leads the first trick, and after that the winner leads.';
  }
  return d;
}

const _special = <String, String>{
  'Win all four Aces':
      'Win every Ace: the A♥, A♦, A♠ and A♣ must all end up in tricks you win. Aces are the lowest cards, so they fall when their suit is led and their holder has nothing else, or are thrown on tricks their holder can’t follow. If anyone else wins one, the task fails.',
  'Win more tricks than anyone else':
      'At the end of the round, count everyone’s tricks: you must have more than any other single player. A tie doesn’t count.',
  'Win more tricks than the rest of the court put together':
      'Win more tricks than all the other players put together: more than half of all the tricks in the round.',
  'Win fewer tricks than anyone else':
      'At the end of the round, every other player must have won more tricks than you. A tie fails.',
  'Win more tricks than the King':
      'By the end of the round you must have won more tricks than the King (whoever holds the King card). The King can’t take this task.',
  'Win fewer tricks than the King':
      'By the end of the round the King must have won more tricks than you.',
  'Win the same number of tricks as the King':
      'By the end of the round you and the King must have won exactly the same number of tricks (none each counts).',
  'Win exactly as many tricks as the player on your left':
      'At the end of the round, you and the player on your left (the next to play after you) must have won the same number of tricks. Zero each is fine.',
  'Win a trick with the Joker':
      'Play the Joker and take the trick with it. The Joker beats every plain card but loses to the Jack, Queen and King, so play it when no higher Court Card is coming. You need the Joker in your hand.',
  'Win a trick with the Jack':
      'Play the Jack and take the trick with it. Only the Queen and the King can beat it. You need the Jack in your hand.',
  'Win the Queen with the King':
      'The Queen must fall in a trick that you take by playing the King card. Hold the King back until the Queen is played, or until a Court Card is led. If the Queen is won any other way, the task fails. You need the King card, and not the Queen, in your hand.',
  'Win a 9 with a Court Card':
      'Win a trick with a Court Card as your winning card, in a trick that also has a 9 in it (any suit). Usually someone leads a suit you have none of, so you can play a Court Card on their 9. You need a Court Card in your hand.',
  'Win a trick led with a Court Card':
      'Win one trick whose first card was a Court Card (Joker, Jack, Queen or King). Everyone must answer a Court Card lead with a Court Card if they can, so the highest Court Card played takes it. You need a Court Card in your hand.',
  'Win a trick containing an Ace and a 9':
      'Win one trick that has both an Ace and a 9 in it, of any suits. Whoever plays them doesn’t matter, as long as you win the trick.',
  'Win a trick with exactly two Court Cards in it':
      'Take a trick that holds two Court Cards and no more: one beats the other, and the trick is yours. You win both Court Cards with it.',
  'Win a trick with three different suits in it':
      'Take a trick holding cards of at least three different suits. Court Cards count as a suit of their own. That means at least two players couldn’t follow suit, so it tends to happen late in the round, or when a Court Card is led.',
  'Win a trick where no one followed suit':
      'Take a trick where the card led was a plain card and nobody else played its suit: everyone was out of it, or played a Court Card. The lead can be yours or anyone’s. Lead a suit the others have run out of.',
  'Win a trick with a card just one above the card led':
      'Win a trick by a whisker: your winning card is the same suit as the card led and exactly one higher than it, with no Court Card played. You can’t do it on a trick you lead.',
  'Win two tricks with cards of the same rank':
      'Win two tricks whose winning cards have the same number: a 7♥ one trick and a 7♣ another, say. Court Cards don’t count. The two tricks needn’t be in a row.',
  'Win a trick you led':
      'Lead a trick and win it. You lead when you won the trick before, or if you are the King, the first trick. Lead your strongest card of a suit nobody can beat.',
  'Win a trick as the last to play':
      'Be the last player to put a card on a trick, and win it. You play last when the player on your right led. By then you can see every card, so you can choose the smallest that takes it.',
  'Win a trick the King leads':
      'Win a trick that the King led: the first trick, or any trick after the King wins one. The King can’t take this task.',
  'Win the trick right after the King wins one':
      'Whenever the King wins a trick, the King leads the next one: win that next trick. Any time in the round will do. The King can’t take this task.',
  'Win the trick after the Queen is played':
      'Watch for the Queen. The trick played straight after the one she falls in must be yours. If she falls in the last trick, there is no trick after it and the task fails.',
  'Win the first trick':
      'Win trick one. The King leads it, so if you’re not the King you’ll need the highest card of the suit led, or a Court Card when you can’t follow.',
  'Win the first trick with a Court Card':
      'Take the very first trick of the round by playing a Court Card on it. The King leads the first trick, so unless you are the King you’ll need to beat whatever is led. You need a Court Card in your hand.',
  'Win the last trick':
      'Win the final trick of the round. Keep a strong card back for the end.',
  'Win the last trick with a Court Card':
      'Take the final trick of the round by playing a Court Card on it. Keep a Court Card back to the very end. You need one in your hand.',
  'Win the second-to-last trick':
      'Win the trick before the last one, so that you lead the final trick. Save a strong card for it.',
  'Win the first and the last trick':
      'Win trick one and the final trick of the round. What happens in between doesn’t matter.',
  'Win only the last trick':
      'Lose every trick except the very last one, which you must win.',
  'Win two tricks in a row':
      'At some point, win two tricks one straight after the other.',
  'Win three tricks in a row':
      'At some point, win three tricks one straight after another.',
  'Win exactly X tricks, named before the first trick':
      'Before the first trick, choose a number (X) and tell everyone. You must then win exactly that many tricks.',
  'Win the Queen':
      'The Queen must end up in a trick you win. Only the King card beats her, so whoever holds the King card matters.',
  'Win the Joker':
      'The Joker must end up in a trick you win. If you hold it, play it where only a higher Court Card could beat it; if someone else does, be ready with the Jack, Queen or King when it falls.',
  'Win the Jack':
      'The Jack must end up in a trick you win. Only the Queen and the King beat it, so if you hold it, it is nearly yours already.',
  'Win the Jack and the Queen':
      'Both the Jack and the Queen must end up in tricks you win, in one trick or two. Whoever plays them, the tricks they fall in must be yours.',
  'Win the Joker, the Jack and the Queen':
      'Every Court Card but the King must end up in tricks you win. Only the King card can take any of them from you.',
  'Win at least two Aces':
      'Win two or more Aces, of any suit, in the tricks you win. Aces are the lowest card of each suit, so they usually fall to whoever wins the trick they’re played in.',
  'Win two tricks led with a ♥':
      'Win two tricks in which the first card played was a ♥, whoever led it. Lead hearts yourself when you can win them, or take the hearts others lead.',
  'Win no ♠ cards':
      'None of the tricks you win may contain a ♠ card, whoever played it.',
  'Win no Court Cards':
      'None of the tricks you win may contain a Court Card (Joker, Jack, Queen or King), whoever played it.',
  'Win exactly one Court Card':
      'Your tricks must hold exactly one Court Card (Joker, Jack, Queen or King) by the end of the round.',
  "Don't win any tricks":
      'Get through the whole round without winning a single trick. Play low, and keep your Court Cards for when you can’t follow suit and someone else is sure to win anyway.',
  "Don't lead a trick with a Court Card":
      'Whenever you lead a trick, lead a plain card, never the Joker, Jack, Queen or King. Play your Court Cards on other people’s leads instead. If Court Cards are all you have left when you lead, the task fails.',
  'Win no tricks until the King has won one':
      'Win nothing until the King has taken a trick; after that you’re free. The King leads the first trick, so it may be over quickly, or the King may be ducking. The King can’t take this task.',
  'Win the card you showed':
      'Show a card with the speech token (your highest, lowest or only card of a suit), then make sure it ends up in a trick you win. Show a strong card and it nearly wins itself; show a weak one and you’ll need to win the trick it falls in.',
  'Win a card someone else showed':
      'Another player must show a card with the speech token, and that card must end up in a trick you win. Once a card is shown everyone knows where it is, so plan to take the trick it falls in.',
  'Win a trick led with a shown card':
      'Someone, you or anyone, leads a trick with the card they showed with the speech token, and you win that trick.',
  'Win the trick right after you show a card':
      'Show a card with the speech token between tricks, then win the very next trick. Show it when you’re holding the card that will take that trick.',
  "Don't win the card you showed":
      'Show a card with the speech token, then make sure someone else wins the trick it falls in. Show a low card and play it under a higher one. You must show a card for this task to be done.',
  "Don't win a trick before you've shown a card":
      'Every trick you win must come after you’ve shown a card with the speech token. Show one early, before the first trick if you can, and you’re free. Winning nothing at all is fine too.',
  'Win the Joker with the Jack':
      'The Joker must fall in a trick you take by playing the Jack, with no Queen or King in it. You need the Jack, and not the Joker, in your hand.',
  'Win the Jack with the Queen':
      'The Jack must fall in a trick you take by playing the Queen, with the King nowhere in it. You need the Queen, and not the Jack, in your hand.',
  'Win two tricks that each hold a Court Card':
      'Win two different tricks with at least one Court Card in each. There are only four Court Cards, so watch where they fall.',
  'Win the trick before the King card is played':
      'The King card always wins the trick it’s played in. Win the trick just before that one. If the King card comes out in the first trick, the task fails, so ask the King to wait.',
  'Win the first trick a Court Card falls in':
      'Watch for the first Court Card (Joker, Jack, Queen or King) to be played. The trick it falls in must be yours.',
  'Win the last trick a Court Card falls in':
      'Of all the tricks with a Court Card in them, the last one must be yours. Count the Court Cards as they fall: once the fourth has been played, it’s settled.',
  "Don't win any trick the King leads":
      'Whenever the King leads, someone other than you must win the trick. The King leads the first trick, and again after every trick the King wins. The King can’t take this task.',
  'Win a trick where everyone followed suit':
      'Take a trick in which every card is of the suit led: nobody was out of it, and no Court Card was played. Easiest early in the round, when everyone still has every suit.',
  'Win two tricks in a row led with the same suit':
      'Win two tricks one straight after the other, both led with the same suit. Win the first and you lead the second: lead the same suit again.',
  'Win tricks led with three different suits':
      'Among the tricks you win, the cards led must cover at least three of the four suits (♥ ♦ ♠ ♣). A trick led with a Court Card doesn’t count toward this.',
  'Win the trick right after you lose one with a Court Card':
      'Play a Court Card and have it beaten by a higher one, then win the very next trick. Your Joker under someone’s Queen, say, then take the trick after.',
  'Win the last trick with a plain card':
      'Take the final trick of the round with an ordinary card: no Court Card may win it. Keep a high card of a suit back to the end, and hope no Court Card is left.',
  'Win no ♦ cards':
      'None of the tricks you win may contain a ♦ card, whoever played it.',
  'Win only the first trick':
      'Win the first trick of the round, and no other. The King leads the first trick; after it, play low and let everyone else take the rest.',
  'Win at least one card of each suit':
      'The tricks you win must hold at least one ♥, one ♦, one ♠ and one ♣, whoever played them. Court Cards don’t count as any suit.',
  'Never win two tricks in a row':
      'You may win as many tricks as you like, but never two one straight after the other. When you win a trick you lead the next, so lead something you’ll lose.',
  'Win more ♠ cards than anyone else':
      'At the end of the round, count the ♠ cards in everyone’s tricks: you must have more than any other single player. A tie fails.',
  'Win your first trick with a Court Card':
      'The first trick you win in the round must be won by your Court Card. Until then, lose every trick you play in, or play a Court Card to take it.',
  'Win a trick that holds a 2 and a 9':
      'Take a trick with a 2 and a 9 in it, of any suits. Lead a 9 when someone can throw a 2 on it, or the other way round.',
  'Win exactly half as many tricks as the King':
      'At the end of the round the King must have won exactly twice as many tricks as you: one to the King’s two, two to four. Zero each counts too. The King can’t take this task.',
  'Win the trick in which someone first runs out of a suit':
      'Watch for the first trick where someone can’t follow the suit led and plays something else. That trick must be yours.',
};

String _tricks(int n) => n == 1 ? '1 trick' : '$n tricks';

/// How [d] is going this round, as a sentence for its close-up, or null
/// before the cards are dealt. Covers every task: counts where there is
/// something to count, otherwise what has happened and what's left.
String taskStatus(String d, RoundView v, int owner, int? x,
    {List<String> names = const []}) {
  String who(int seat) => seat < names.length ? names[seat] : 'Player ${seat + 1}';
  final me = names.isEmpty ? 'You' : who(owner);
  final rule = taskRules[d];
  // Nothing is decided before the first trick (and some rules look at the
  // last trick played, so they need one).
  final verdict = v.tricks.isEmpty
      ? Verdict.pending
      : rule?.call(v, owner, x) ?? Verdict.pending;
  final played = v.tricks.length;
  final left = v.totalTricks - played;
  final won = v.tricksWon(owner);
  if (verdict == Verdict.done) return 'Done!';
  if (verdict == Verdict.failed) return 'Failed this round.';

  final notFirst = RegExp(r'^Don.t win any of the first (\w+) tricks$').firstMatch(d);
  if (notFirst != null) {
    final n = _numbers[notFirst.group(1)]!;
    final safe = played.clamp(0, n);
    return safe == 0
        ? 'None of the first $n tricks played yet. Lose all $n.'
        : '$safe of the first $n tricks lost safely; ${n - safe} still to lose.';
  }
  if (d.startsWith("Don't") || d.startsWith('Win no ')) {
    if (played == 0) return 'Nothing played yet. Keep it up for all ${_tricks(v.totalTricks)}.';
    return 'Safe so far, $played of ${v.totalTricks} tricks in. ${_tricks(left)} to go.';
  }
  final progress = taskProgress(d, v, owner, x);
  final toGo = left == 1 ? '1 trick to go' : '$left tricks to go';
  final playedCards = v.tricks.expand((t) => t.cards).toSet();
  String unplayed(bool Function(PlayingCard) test) {
    final out = [
      for (final c in fullDeck())
        if (test(c) && !playedCards.contains(c)) c.label
    ];
    return out.isEmpty ? 'none' : out.join(', ');
  }

  String playedOf(bool Function(PlayingCard) test) {
    final out = <String>[];
    for (int i = 0; i < v.tricks.length; i++) {
      for (final c in v.tricks[i].cards) {
        if (test(c)) out.add('${c.label} (trick ${i + 1})');
      }
    }
    return out.isEmpty ? 'none yet' : out.join(', ');
  }

  bool rank(PlayingCard c, int r) => !c.isCourt && c.rank == r;

  final named = [
    for (final m in RegExp(r'([A2-9])([♥♦♠♣])').allMatches(d))
      PlayingCard.parse(m.group(0)!)!
  ];
  if (named.isNotEmpty && d.startsWith('Win the ') && !d.contains('last trick')) {
    if (named.length == 1) {
      return 'The ${named.single.label} hasn’t been played yet. $toGo.';
    }
    final mine = v.won(owner).toSet();
    final need = [for (final c in named) if (!mine.contains(c)) c.label];
    return 'Won ${named.length - need.length} of ${named.length}. Still to win: ${need.join(', ')}.';
  }
  if (d == 'Win the A♥ in the last trick') {
    return 'The A♥ is still in someone’s hand. Keep it back for trick ${v.totalTricks}; $toGo.';
  }
  final withRank = RegExp(r'^Win a trick with a (\d)$').firstMatch(d);
  if (withRank != null) {
    final r = int.parse(withRank.group(1)!);
    return '$me hasn’t won a trick with a $r yet. ${r}s played: ${playedOf((c) => rank(c, r))}. Still to come: ${unplayed((c) => rank(c, r))}.'
        .replaceFirst('You hasn’t', 'You haven’t');
  }
  final pair = RegExp(r'^Win (?:a|an) (\d) with a (\d)$').firstMatch(d);
  if (pair != null) {
    final target = int.parse(pair.group(1)!), by = int.parse(pair.group(2)!);
    return '${by}s still to come: ${unplayed((c) => rank(c, by))}. ${target}s still to come: ${unplayed((c) => rank(c, target))}. $toGo.';
  }
  if (d == 'Win any 7 with another 7') {
    return '7s played: ${playedOf((c) => rank(c, 7))}. Still to come: ${unplayed((c) => rank(c, 7))}. Two of them must fall in one trick, won with a 7.';
  }
  if (d == 'Win the Queen') {
    return 'The Queen hasn’t been played yet. Only the King card beats her. $toGo.';
  }
  final courtOnly = RegExp(r'^Win the (Joker|Jack) and no other').firstMatch(d);
  if (courtOnly != null) {
    final name = courtOnly.group(1)!;
    final card = name == 'Joker' ? PlayingCard.joker : PlayingCard.jack;
    final mine = v.won(owner).toSet();
    final others = [
      for (final c in const [PlayingCard.joker, PlayingCard.jack, PlayingCard.queen, PlayingCard.king])
        if (c != card && !playedCards.contains(c)) c.label
    ];
    return '${mine.contains(card) ? 'The $name is won.' : 'The $name isn’t won yet.'} Court Cards still to come, which must go to others: ${others.isEmpty ? 'none' : others.join(', ')}.';
  }
  if (d.startsWith('Win a card of every suit')) {
    final mine = v.won(owner);
    final need = [
      for (final s in const [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs])
        if (!mine.any((c) => c.suit == s)) s.symbol
    ];
    return 'Still to win: ${need.join(' ')}. $toGo.';
  }
  if (d.startsWith('Win all nine cards of any one suit')) {
    final others = v.wonByOthers(owner);
    final mine = v.won(owner);
    final open = [
      for (final s in const [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs])
        if (!others.any((c) => c.suit == s))
          '${s.symbol} (${mine.where((c) => c.suit == s).length} won)'
    ];
    return 'Suits still possible: ${open.join(', ')}. $toGo.';
  }
  if (d.contains('totalling')) {
    final best = [
      for (final t in v.tricks)
        if (t.winner == owner && !t.cards.any((c) => c.isCourt))
          t.cards.fold<int>(0, (a, c) => a + c.rank)
    ];
    return best.isEmpty
        ? 'No trick won without a Court Card yet. $toGo.'
        : 'Totals of the tricks won so far: ${best.join(', ')}. $toGo.';
  }
  if (d.contains('than anyone') || d.contains('rest of the court')) {
    if (names.isNotEmpty) {
      return 'Tricks so far: ${[for (int s = 0; s < v.players; s++) '${who(s)} ${v.tricksWon(s)}'].join(', ')}. $toGo.';
    }
  }
  if (progress != null) {
    return '${_describeProgress(d, progress, won, me)} $toGo.';
  }
  if (RegExp(r'^Win (the|only the) first').hasMatch(d)) {
    return played == 0
        ? 'Decided by the first trick, which the King leads.'
        : '$toGo.';
  }
  if (d.contains('last trick')) {
    return 'Decided by the last trick, trick ${v.totalTricks}. $toGo.';
  }
  if (timingOf(d) == TaskTiming.anyTrick) {
    return played == 0
        ? 'It can happen on any trick. All ${_tricks(v.totalTricks)} to play.'
        : 'No trick like that won yet. $toGo.';
  }
  return 'Decided at the end of the round. $toGo.';
}

String _describeProgress(String d, String progress, int won, String me) {
  final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(progress);
  if (frac != null) return 'So far ${frac.group(1)} of ${frac.group(2)}.';
  if (progress.startsWith('run ')) {
    return 'Longest run so far: ${progress.substring(4)} in a row.';
  }
  if (progress.contains(' v ')) {
    final p = progress.split(' v ');
    return '$me ${p[0]}, the King ${p[1]}.';
  }
  if (progress.endsWith('tricks')) return '$me: ${_tricks(won)} won so far.';
  return 'So far: $progress.';
}

/// Why [d] failed, in a sentence, judged from the tricks played. [names]
/// gives each seat's name ("You", "The Duke"); [owner] held the task.
String failReason(String d, RoundView v, int owner, int? x, List<String> names) {
  String who(int seat) => seat < names.length ? names[seat] : 'Player ${seat + 1}';
  final me = who(owner);
  final over = v.over;
  int? trickOf(PlayingCard c) {
    for (int i = 0; i < v.tricks.length; i++) {
      if (v.tricks[i].cards.contains(c)) return i;
    }
    return null;
  }

  final named = [
    for (final m in RegExp(r'([A2-9])([♥♦♠♣])').allMatches(d))
      PlayingCard.parse(m.group(0)!)!
  ];
  // A named card went the wrong way.
  if (named.isNotEmpty && d.startsWith('Win')) {
    for (final c in named) {
      final i = trickOf(c);
      if (i == null) continue;
      final t = v.tricks[i];
      if (d.contains('with a Court Card') && t.winner == owner) {
        return '$me won the ${c.label} in trick ${i + 1}, but not with a Court Card.';
      }
      if (d.contains('last trick') && i != v.totalTricks - 1) {
        return 'The ${c.label} was played in trick ${i + 1}, not the last trick.';
      }
      if (t.winner != owner) {
        return '${who(t.winner)} won the ${c.label} in trick ${i + 1}.';
      }
    }
  }
  if (RegExp(r"^(Don't win any|Win no)").hasMatch(d) && !d.contains('trick')) {
    for (int i = 0; i < v.tricks.length; i++) {
      final t = v.tricks[i];
      if (t.winner != owner) continue;
      final rule = taskRules[d];
      // The first trick after which the task had failed.
      final upTo = v.upTo(i + 1);
      if (rule != null && rule(upTo, owner, x) == Verdict.failed) {
        return '$me won trick ${i + 1}, and it held ${t.cards.map((c) => c.label).join(', ')}.';
      }
    }
  }
  final notFirst = RegExp(r"^Don't win any of the first (\w+) tricks$").firstMatch(d);
  if (notFirst != null || d == "Don't win any tricks") {
    final mine = v.wonIndexes(owner);
    if (mine.isNotEmpty) return '$me won trick ${mine.first + 1}.';
  }
  if (d == 'Never win two tricks in a row') {
    final mine = v.wonIndexes(owner);
    for (int k = 1; k < mine.length; k++) {
      if (mine[k] == mine[k - 1] + 1) {
        return '$me won tricks ${mine[k - 1] + 1} and ${mine[k] + 1}, one after the other.';
      }
    }
  }
  if (d.startsWith("Don't lead")) {
    for (int i = 0; i < v.tricks.length; i++) {
      final t = v.tricks[i];
      if (t.leader == owner) {
        if (taskRules[d]!(v.upTo(i + 1), owner, x) == Verdict.failed) {
          return '$me led the ${t.led.label} in trick ${i + 1}.';
        }
      }
    }
  }
  if (RegExp(r'^Win the first|^Win only the first').hasMatch(d) && v.tricks.isNotEmpty) {
    for (int i = 0; i < v.tricks.length; i++) {
      if (v.tricks[i].winner != owner) {
        return '${who(v.tricks[i].winner)} won trick ${i + 1}.';
      }
      if (d.startsWith('Win only the first') && i > 0) {
        return '$me won trick ${i + 1} as well.';
      }
    }
  }
  final won = v.tricksWon(owner);
  if (d.contains('than the King') || d.contains('as the King')) {
    return '$me won ${_tricks(won)}; the King won ${_tricks(v.tricksWon(v.king))}.';
  }
  if (d.contains('than anyone') || d.contains('rest of the court')) {
    final counts = [
      for (int s = 0; s < v.players; s++) '${who(s)} ${v.tricksWon(s)}'
    ];
    return 'Tricks won: ${counts.join(', ')}.';
  }
  final exact = RegExp(r'^Win exactly (\w+|X) tricks?').firstMatch(d);
  if (exact != null) {
    final n = exact.group(1) == 'X' ? x : _numbers[exact.group(1)];
    if (n != null) {
      if (won > n) return '$me won ${_tricks(won)}, more than $n.';
      return over
          ? '$me finished with ${_tricks(won)}, not $n.'
          : 'Too few tricks were left for $me to reach $n.';
    }
  }
  if (d.contains('in the last trick') || d.endsWith('last trick')) {
    if (over) {
      final last = v.tricks.last;
      if (last.winner != owner) return '${who(last.winner)} won the last trick.';
    }
    final extra = v.wonIndexes(owner).where((i) => i != v.totalTricks - 1);
    if (extra.isNotEmpty && d.startsWith('Win only')) {
      return '$me won trick ${extra.first + 1}, not only the last.';
    }
  }
  if (over && timingOf(d) == TaskTiming.anyTrick) {
    return 'The round ended before $me won a trick like that.';
  }
  if (!over) {
    return 'It could no longer be done: the cards it needed were gone.';
  }
  return 'It wasn’t done by the end of the round.';
}

/// The cards a task is about, to show in its close-up with whether
/// they've been played: the cards it names, every card of a number or
/// suit it counts, or the Court Cards. Empty for tasks about tricks.
List<PlayingCard> relevantCards(String d) {
  final out = <PlayingCard>[];
  void add(Iterable<PlayingCard> cs) {
    for (final c in cs) {
      if (!out.contains(c)) out.add(c);
    }
  }

  final deck = fullDeck();
  add([
    for (final m in RegExp(r'([A2-9])([♥♦♠♣])').allMatches(d))
      PlayingCard.parse(m.group(0)!)!
  ]);
  final lower = d.toLowerCase();
  if (lower.contains('court card') ||
      d.contains('Queen') ||
      d.contains('Joker') ||
      d.contains('Jack')) {
    add(const [PlayingCard.joker, PlayingCard.jack, PlayingCard.queen, PlayingCard.king]);
  }
  // Numbers: "a 6", "6s", "Aces", "8s or 9s".
  if (!lower.contains('total') && !lower.contains('every card is')) {
    final ranks = <int>{
      for (final m in RegExp(r'\b(\d)s\b').allMatches(d)) int.parse(m.group(1)!),
      for (final m in RegExp(r'\b(?:a|an|another) (\d)\b').allMatches(d))
        int.parse(m.group(1)!),
      if (d.contains('Aces') || d.contains('an Ace')) 1,
    };
    if (!lower.contains('even') && !lower.contains('odd')) {
      add([for (final c in deck) if (!c.isCourt && ranks.contains(c.rank)) c]);
    }
  }
  // Suits it counts: "five ♥ cards", "no ♥ cards", "any ♦ or ♣ cards".
  if (RegExp(r'[♥♦♠♣] (or [♥♦♠♣] )?cards?').hasMatch(d) &&
      !d.startsWith("Don't lead") &&
      !d.contains('as many')) {
    final suits = {
      for (final m in RegExp(r'([♥♦♠♣])(?! *[A2-9])').allMatches(d)) m.group(1)!
    };
    add([for (final c in deck) if (suits.contains(c.suit.symbol)) c]);
  }
  return out;
}

/// Whether winning a card is what [d]'s owner wants (false for "Don't
/// win…" and "Win no…" tasks).
bool wantsToWin(String d) => !(d.startsWith("Don't") || d.startsWith('Win no'));
