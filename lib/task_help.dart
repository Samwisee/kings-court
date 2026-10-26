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
  'seven': 7,
};

String _rankName(String r) => r == 'A' ? 'Ace' : r;

/// What [d] asks for, in plain words, with anything easy to miss spelled
/// out. Every task in the game has an explanation.
String explainTask(String d) {
  final special = _special[d];
  if (special != null) return special;

  // "Win the 3♥", "Win the 6♠ and the 7♦", "Win the A♠, 2♠ and 3♠".
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
        'If the $card is won any other way, the task fails.';
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
        'The deal is redone if one player holds too many of them for this to be fair.';
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
  'Win more tricks than everyone else':
      'At the end of the round, count everyone’s tricks: you must have more than any other single player. A tie doesn’t count.',
  'Win more tricks than everyone else together':
      'You must win more tricks than all the other players put together: more than half of all the tricks.',
  'Win fewer tricks than everyone else':
      'At the end of the round, every other player must have won more tricks than you. A tie fails.',
  'Win more tricks than the King':
      'By the end of the round you must have won more tricks than the King (whoever holds the King card). The King can’t take this task.',
  'Win fewer tricks than the King':
      'By the end of the round the King must have won more tricks than you.',
  'Win the same number of tricks as the King':
      'By the end of the round you and the King must have won exactly the same number of tricks (none each counts).',
  'Win a trick where every card is lower than 7, with no Court Cards':
      'Win one trick in which every card is a 6 or lower (Aces to 6s), and nobody played a Court Card.',
  'Win a trick where every card is higher than 5':
      'Win one trick in which every plain card is a 6 or higher. Court Cards are allowed in it.',
  'Win a 5 with a 7':
      'Win a trick with a 7 as your winning card, in a trick that also has a 5 in it (any suit).',
  'Win an 8 with a 4':
      'Win a trick with a 4 as your winning card, in a trick that also has an 8 in it. The 8 must be of another suit, or your 4 couldn’t win.',
  'Win any 6 with another 6':
      'Win a trick with a 6 as your winning card, in a trick that holds at least one other 6.',
  'Win a trick with a 2':
      'Win a trick where your winning card is a 2. Everyone else must play a card of another suit (and no Court Cards), so the 2 is the highest of the suit led.',
  'Win the 2♣ in the last trick':
      'The 2♣ must be played in the very last trick of the round, and you must win that trick. If the 2♣ comes out earlier, or someone else wins it, the task fails.',
  'Win exactly one ♥ and one ♣ card':
      'By the end of the round, your tricks must hold exactly one ♥ card and exactly one ♣ card.',
  'Win no ♥ cards':
      'None of the tricks you win may contain a ♥ card, whoever played it.',
  "Win at least one card of each suit (Court Cards don't count)":
      'Your tricks must include at least one ♥, one ♦, one ♠ and one ♣ card by the end of the round.',
  "Win every card of at least one suit (Court Cards don't count)":
      'Pick a suit and win all of it: every card of that suit dealt this round must end up in your tricks.',
  'Win a trick of only even numbers (that means only 2s, 4s, 6s and 8s)':
      'Win one trick in which every card is a 2, 4, 6 or 8, with no Court Cards.',
  'Win a trick of only odd numbers (that means only Aces, 3s, 5s, 7s and 9s)':
      'Win one trick in which every card is an Ace, 3, 5, 7 or 9, with no Court Cards.',
  'Win a trick totalling more than 23 / 28 / 31 / 34 (2–3 / 4 / 5 / 6 players), with no Court Cards':
      'Win one trick whose cards add up to more than the target for your table size (23 for two or three players, 28 for four, 31 for five, 34 for six). Aces count as 1. No Court Cards may be in it.',
  'Win a trick totalling less than 8 / 12 / 16 / 20 (2–3 / 4 / 5 / 6 players), with no Court Cards':
      'Win one trick whose cards add up to less than the target for your table size (8 for two or three players, 12 for four, 16 for five, 20 for six). Aces count as 1. No Court Cards may be in it.',
  'Win a trick totalling exactly 22 or 23':
      'Win one trick whose cards add up to exactly 22 or 23. Aces count as 1, and a trick with a Court Card in it doesn’t count.',
  'Win exactly one Court Card (redeal if one player holds all four)':
      'Your tricks must hold exactly one Court Card (Joker, Jack, Queen or King) by the end of the round.',
  'Win the Joker and no other Court Card (redeal if one player holds the Joker and King, or the Joker, Jack and Queen)':
      'Win the Joker, and make sure the Jack, Queen and King all end up in other players’ tricks.',
  'Win the Jack and no other Court Card (redeal if one player holds the Jack and King, or the Joker, Jack and Queen)':
      'Win the Jack, and make sure the Joker, Queen and King all end up in other players’ tricks.',
  'Win the Queen':
      'The Queen must end up in a trick you win. Only the King card beats her, so whoever holds the King card matters.',
  'Win no Court Cards':
      'None of the tricks you win may contain a Court Card (Joker, Jack, Queen or King), whoever played it.',
  "Don't lead a trick with a ♥, ♦ or ♠ card":
      'Whenever you lead a trick (play its first card), it must be a ♣ card or a Court Card. Following someone else’s lead is fine with any card.',
  "Don't lead a trick with a ♥ or ♣ card":
      'Whenever you lead a trick, it must be a ♦ or ♠ card, or a Court Card. Following someone else’s lead is fine with any card.',
  "Don't win any tricks":
      'Get through the whole round without winning a single trick. Play low, and keep your Court Cards for when you can’t follow suit and someone else is sure to win anyway.',
  "Don't win two tricks in a row":
      'You may win tricks, but never two one straight after the other.',
  'Win the last trick':
      'Win the final trick of the round. Keep a strong card back for the end.',
  'Win the first trick':
      'Win trick one. The King leads it, so if you’re not the King you’ll need the highest card of the suit led, or a Court Card when you can’t follow.',
  'Win the first and the last trick':
      'Win trick one and the final trick of the round. What happens in between doesn’t matter.',
  'Win only the last trick':
      'Lose every trick except the very last one, which you must win.',
  'Win only the first trick':
      'Win trick one, then lose every trick after it.',
  'Win two tricks in a row': 'At some point, win two tricks one straight after the other.',
  'Win three tricks in a row':
      'At some point, win three tricks one straight after another.',
  "Win exactly three tricks, and they're in a row":
      'Win three tricks in the round, no more and no fewer, and they must come one straight after another.',
  "Win exactly two tricks, and they're in a row":
      'Win two tricks in the round, no more and no fewer, one straight after the other.',
  'Win exactly X tricks, announced to everyone':
      'Before the first trick, choose a number (X) and tell everyone. You must then win exactly that many tricks.',
  'Win exactly X tricks, kept secret (write X down and keep it hidden)':
      'Before the first trick, choose a number (X) and keep it to yourself. You must then win exactly that many tricks.',
  'Win as many ♥ cards as ♦ cards (you must win at least one of each)':
      'By the end of the round, your tricks must hold the same number of ♥ cards as ♦ cards, and at least one of each.',
  'Win a trick with as many ♣ cards as ♦ cards (you must win at least one of each)':
      'Win one trick that has the same number of ♣ cards as ♦ cards in it, with at least one of each.',
  'Win a trick with as many ♥ cards as ♠ cards (you must win at least one of each)':
      'Win one trick that has the same number of ♥ cards as ♠ cards in it, with at least one of each.',
  'Win more ♦ cards than ♠ cards (winning no ♠ cards is fine)':
      'By the end of the round, your tricks must hold more ♦ cards than ♠ cards.',
  'Win more ♥ cards than ♣ cards (winning no ♣ cards is fine)':
      'By the end of the round, your tricks must hold more ♥ cards than ♣ cards.',
  'Win a mixed-suit trick with no Court Cards':
      'Win one trick that has cards from at least two suits in it, and no Court Cards. It happens when someone can’t follow suit.',
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
  if (d == 'Win the 2♣ in the last trick') {
    return 'The 2♣ is still in someone’s hand. Keep it back for trick ${v.totalTricks}; $toGo.';
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
  if (d == 'Win any 6 with another 6') {
    return '6s played: ${playedOf((c) => rank(c, 6))}. Still to come: ${unplayed((c) => rank(c, 6))}. Two of them must fall in one trick, won with a 6.';
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
  if (d.startsWith('Win at least one card of each suit')) {
    final mine = v.won(owner);
    final need = [
      for (final s in const [Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs])
        if (!mine.any((c) => c.suit == s)) s.symbol
    ];
    return 'Still to win: ${need.join(' ')}. $toGo.';
  }
  if (d.startsWith('Win every card of at least one suit')) {
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
  if (d.contains('than everyone') || d.contains('fewer tricks than everyone')) {
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
      final upTo = RoundView(
          players: v.players,
          king: v.king,
          tricks: v.tricks.sublist(0, i + 1),
          totalTricks: v.totalTricks,
          inPlay: v.inPlay);
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
  if (d == "Don't win two tricks in a row") {
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
        final upTo = v.tricks.sublist(0, i + 1);
        if (taskRules[d]!(
                RoundView(
                    players: v.players,
                    king: v.king,
                    tricks: upTo,
                    totalTricks: v.totalTricks,
                    inPlay: v.inPlay),
                owner,
                x) ==
            Verdict.failed) {
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
  if (d.contains('than everyone')) {
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
