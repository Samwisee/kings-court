import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/engine/inference.dart';
import 'package:kings_court/engine/round.dart';

void main() {
  PlayingCard c(String l) => PlayingCard.parse(l)!;

  test('Not following suit shows a player has none of it', () {
    final m = Round(players: 3, target: 1)
      ..hands = [
        [c('2♠'), c('3♠')],
        [c('4♥'), c('5♥')],
        [c('6♠'), c('7♠')],
      ]
      ..tricks = [Trick(0, const [0, 1, 2], [c('9♠'), c('2♥'), c('8♠')], 0)]
      ..setAside = [];
    final g = guessHands(m, 0);
    final duke = g.firstWhere((h) => h.seat == 1);
    expect(duke.voids, contains(Suit.spades));
    expect(duke.possible.where((x) => x.suit == Suit.spades), isEmpty);
  });

  test('A shown card and its mark narrow a hand down', () {
    final m = Round(players: 3, target: 1)
      ..hands = [
        [c('2♠')],
        [c('7♥'), c('3♥')],
        [c('9♥')],
      ]
      ..revealed = {1: c('7♥')}
      ..revealHint = {1: 'highest'}
      ..setAside = [];
    final duke = guessHands(m, 0).firstWhere((h) => h.seat == 1);
    expect(duke.certain, contains(c('7♥')));
    expect(duke.possible, isNot(contains(c('9♥'))));
    expect(duke.possible, isNot(contains(c('8♥'))));
  });

  test('Everyone knows who holds the King', () {
    final m = Round(players: 3, target: 1)
      ..hands = [
        [c('2♠')],
        [c('3♠')],
        [PlayingCard.king],
      ]
      ..king = 2
      ..setAside = [c('4♠')];
    final g = guessHands(m, 0);
    expect(g.firstWhere((h) => h.seat == 2).certain, contains(PlayingCard.king));
    expect(g.firstWhere((h) => h.seat == 1).possible,
        isNot(contains(PlayingCard.king)));
  });
}
