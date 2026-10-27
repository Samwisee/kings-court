// The King's Court's tasks: what each asks, and its points for 3, 4, 5
// and 6 players (two players use the 3-player points). The points come
// from the balance report (tool/balance): how often the bots fail each
// task, at each table size. See docs/adding-tasks.md.

const List<Map<String, dynamic>> tasksData = [
  {
    'description': "Win more tricks than anyone else",
    'three': 3,
    'four': 3,
    'five': 3,
    'six': 4,
  },
  {
    'description': "Win more tricks than the rest of the court put together",
    'three': 3,
    'four': 6,
    'five': 7,
    'six': 7,
  },
  {
    'description': "Win fewer tricks than anyone else",
    'three': 3,
    'four': 2,
    'five': 3,
    'six': 6,
  },
  {
    'description': "Win more tricks than the King",
    'three': 4,
    'four': 3,
    'five': 5,
    'six': 5,
    'kingCantTake': true,
  },
  {
    'description': "Win fewer tricks than the King",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 2,
    'kingCantTake': true,
  },
  {
    'description': "Win the same number of tricks as the King",
    'three': 4,
    'four': 3,
    'five': 3,
    'six': 5,
    'kingCantTake': true,
  },
  {
    'description': "Win a trick where every card is lower than 7, with no Court Cards",
    'three': 1,
    'four': 1,
    'five': 2,
    'six': 4,
  },
  {
    'description': "Win a trick where every card is higher than 5",
    'three': 1,
    'four': 1,
    'five': 3,
    'six': 6,
  },
  {
    'description': "Win a trick with a 6",
    'three': 1,
    'four': 1,
    'five': 2,
    'six': 4,
  },
  {
    'description': "Win a trick with a 5",
    'three': 1,
    'four': 2,
    'five': 3,
    'six': 5,
  },
  {
    'description': "Win a trick with a 3",
    'three': 2,
    'four': 4,
    'five': 5,
    'six': 7,
  },
  {
    'description': "Win a 2 with a 6",
    'three': 1,
    'four': 2,
    'five': 2,
    'six': 5,
  },
  {
    'description': "Win a 9 with a 5",
    'three': 5,
    'four': 5,
    'five': 6,
    'six': 7,
  },
  {
    'description': "Win any 7 with another 7",
    'three': 5,
    'four': 5,
    'five': 4,
    'six': 7,
  },
  {
    'description': "Win a trick with a 2",
    'three': 3,
    'four': 4,
    'five': 6,
    'six': 7,
  },
  {
    'description': "Win the 3♥",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 1,
  },
  {
    'description': "Win the A♦",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 2,
  },
  {
    'description': "Win the 4♠",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 2,
  },
  {
    'description': "Win the 6♣",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 2,
  },
  {
    'description': "Win all four 2s",
    'three': 5,
    'four': 7,
    'five': 7,
    'six': 7,
  },
  {
    'description': "Win at least three 4s",
    'three': 3,
    'four': 3,
    'five': 4,
    'six': 5,
  },
  {
    'description': "Win at least three 7s",
    'three': 2,
    'four': 3,
    'five': 4,
    'six': 5,
  },
  {
    'description': "Win at least two 9s",
    'three': 1,
    'four': 2,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Win all four 8s",
    'three': 4,
    'four': 6,
    'five': 7,
    'six': 7,
  },
  {
    'description': "Win exactly three 5s",
    'three': 3,
    'four': 4,
    'five': 4,
    'six': 6,
  },
  {
    'description': "Win exactly two 3s",
    'three': 2,
    'four': 2,
    'five': 3,
    'six': 3,
  },
  {
    'description': "Win the 7♣, 8♣ and 9♣",
    'three': 3,
    'four': 3,
    'five': 4,
    'six': 5,
  },
  {
    'description': "Win the 4♥ and the 9♠",
    'three': 2,
    'four': 3,
    'five': 3,
    'six': 5,
  },
  {
    'description': "Win the 2♠ and the 8♦",
    'three': 2,
    'four': 2,
    'five': 3,
    'six': 4,
  },
  {
    'description': "Win the 6♥ and the 3♠",
    'three': 2,
    'four': 3,
    'five': 4,
    'six': 4,
  },
  {
    'description': "Win the 7♦ and the 4♣",
    'three': 2,
    'four': 3,
    'five': 4,
    'six': 4,
  },
  {
    'description': "Win the A♣ and the 5♥",
    'three': 2,
    'four': 3,
    'five': 3,
    'six': 4,
  },
  {
    'description': "Win the 9♥ and the 2♣",
    'three': 2,
    'four': 3,
    'five': 3,
    'six': 4,
  },
  {
    'description': "Win the 3♦ and the 6♠",
    'three': 2,
    'four': 3,
    'five': 3,
    'six': 4,
  },
  {
    'description': "Win the 2♦, 4♣ and 6♥",
    'three': 4,
    'four': 4,
    'five': 6,
    'six': 7,
  },
  {
    'description': "Win the A♥ in the last trick",
    'three': 4,
    'four': 5,
    'five': 5,
    'six': 5,
  },
  {
    'description': "Win exactly one ♦ and one ♠ card",
    'three': 5,
    'four': 5,
    'five': 4,
    'six': 4,
  },
  {
    'description': "Win at least six ♣ cards",
    'three': 2,
    'four': 3,
    'five': 3,
    'six': 4,
  },
  {
    'description': "Win at least five ♦ cards",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Win exactly three ♥ cards",
    'three': 2,
    'four': 3,
    'five': 4,
    'six': 3,
  },
  {
    'description': "Win exactly two ♦ cards",
    'three': 3,
    'four': 3,
    'five': 3,
    'six': 4,
  },
  {
    'description': "Win exactly one ♠ card",
    'three': 2,
    'four': 3,
    'five': 3,
    'six': 2,
  },
  {
    'description': "Win no ♠ cards",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Win a card of every suit (Court Cards don't count)",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Win all nine cards of any one suit",
    'three': 4,
    'four': 5,
    'five': 6,
    'six': 6,
  },
  {
    'description': "Win a trick of only even cards: 2s, 4s, 6s and 8s",
    'three': 2,
    'four': 3,
    'five': 7,
    'six': 7,
  },
  {
    'description': "Win a trick of only odd cards: Aces, 3s, 5s, 7s and 9s",
    'three': 1,
    'four': 2,
    'five': 4,
    'six': 7,
  },
  {
    'description': "Win a trick totalling more than 21 / 26 / 30 / 34 (2–3 / 4 / 5 / 6 players), with no Court Cards",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 2,
  },
  {
    'description': "Win a trick totalling less than 9 / 13 / 17 / 21 (2–3 / 4 / 5 / 6 players), with no Court Cards",
    'three': 1,
    'four': 2,
    'five': 3,
    'six': 4,
  },
  {
    'description': "Win a trick totalling exactly 20 or 21",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 5,
  },
  {
    'description': "Win exactly one Court Card (redeal if one player has all four)",
    'three': 2,
    'four': 3,
    'five': 3,
    'six': 5,
  },
  {
    'description': "Win the Joker and no other Court Card (redeal if one player has the Joker and King, or the Joker, Jack and Queen)",
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 7,
  },
  {
    'description': "Win the Jack and no other Court Card (redeal if one player has the Jack and King, or the Joker, Jack and Queen)",
    'three': 3,
    'four': 4,
    'five': 4,
    'six': 7,
  },
  {
    'description': "Win the Queen",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 1,
  },
  {
    'description': "Win exactly two Court Cards (redeal if one player has the Jack, Queen and King)",
    'three': 4,
    'four': 4,
    'five': 5,
    'six': 5,
  },
  {
    'description': "Win exactly three Court Cards (redeal if one player has all four)",
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 5,
  },
  {
    'description': "Win no Court Cards",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Win the 7♥ with a Court Card",
    'three': 5,
    'four': 4,
    'five': 4,
    'six': 5,
  },
  {
    'description': "Win the 8♦ with a Court Card",
    'three': 4,
    'four': 4,
    'five': 4,
    'six': 6,
  },
  {
    'description': "Don't lead a trick with a ♦, ♠ or ♣ card",
    'three': 3,
    'four': 2,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Don't lead a trick with a ♦ or ♠ card",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Don't win any ♥ cards",
    'three': 2,
    'four': 2,
    'five': 3,
    'six': 3,
  },
  {
    'description': "Don't win any ♦ cards",
    'three': 3,
    'four': 2,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Don't win any ♥ or ♣ cards",
    'three': 3,
    'four': 2,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Don't win any ♦ or ♠ cards",
    'three': 3,
    'four': 3,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Don't win any 7s or 8s",
    'three': 3,
    'four': 3,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Don't win any 6s",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Don't win any 4s",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Don't win any Aces",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Don't win any Aces or 2s",
    'three': 3,
    'four': 2,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Don't win any of the first four tricks",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 2,
  },
  {
    'description': "Don't win any of the first three tricks",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 2,
  },
  {
    'description': "Don't win any of the first five tricks",
    'three': 1,
    'four': 2,
    'five': 1,
    'six': 2,
  },
  {
    'description': "Don't win any tricks",
    'three': 2,
    'four': 3,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Don't win two tricks in a row",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Win the last trick",
    'three': 3,
    'four': 3,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Win the first three tricks",
    'three': 3,
    'four': 5,
    'five': 7,
    'six': 7,
  },
  {
    'description': "Win the first two tricks",
    'three': 1,
    'four': 2,
    'five': 2,
    'six': 4,
  },
  {
    'description': "Win the first trick",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 1,
  },
  {
    'description': "Win the first and the last trick",
    'three': 3,
    'four': 5,
    'five': 5,
    'six': 5,
  },
  {
    'description': "Win only the last trick",
    'three': 6,
    'four': 4,
    'five': 4,
    'six': 4,
  },
  {
    'description': "Win only the first trick",
    'three': 7,
    'four': 5,
    'five': 3,
    'six': 3,
  },
  {
    'description': "Win exactly one trick",
    'three': 3,
    'four': 2,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Win exactly two tricks",
    'three': 2,
    'four': 2,
    'five': 3,
    'six': 3,
  },
  {
    'description': "Win two tricks in a row",
    'three': 1,
    'four': 1,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Win three tricks in a row",
    'three': 1,
    'four': 2,
    'five': 4,
    'six': 5,
  },
  {
    'description': "Win exactly four tricks",
    'three': 4,
    'four': 3,
    'five': 4,
    'six': 7,
  },
  {
    'description': "Win exactly three tricks, and they're in a row",
    'three': 4,
    'four': 4,
    'five': 5,
    'six': 5,
  },
  {
    'description': "Win exactly two tricks, and they're in a row",
    'three': 3,
    'four': 3,
    'five': 3,
    'six': 4,
  },
  {
    'description': "Win exactly X tricks, said out loud before the first trick",
    'three': 3,
    'four': 2,
    'five': 3,
    'six': 4,
  },
  {
    'description': "Win exactly X tricks, written down in secret before the first trick",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Win as many ♠ cards as ♣ cards (at least one of each)",
    'three': 3,
    'four': 3,
    'five': 3,
    'six': 4,
  },
  {
    'description': "Win a trick with as many ♥ cards as ♣ cards (at least one of each)",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Win a trick with as many ♦ cards as ♠ cards (at least one of each)",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 3,
  },
  {
    'description': "Win more ♠ cards than ♥ cards (winning no ♥ cards is fine)",
    'three': 2,
    'four': 3,
    'five': 3,
    'six': 3,
  },
  {
    'description': "Win more ♣ cards than ♦ cards (winning no ♦ cards is fine)",
    'three': 2,
    'four': 3,
    'five': 2,
    'six': 2,
  },
  {
    'description': "Win a mixed-suit trick with no Court Cards",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 1,
  },
  // Added with the tiered deal (see lib/engine/deal_mix.dart): tasks
  // where winning more never hurts, so they mix safely.
  {
    'description': "Win a trick with a 4",
    'three': 2,
    'four': 3,
    'five': 4,
    'six': 6,
  },
  {
    'description': "Win a trick with a 7",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 3,
  },
  {
    'description': "Win the 2♦",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 1,
  },
  {
    'description': "Win the 8♣",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 1,
  },
  {
    'description': "Win the 9♠",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 2,
  },
  {
    'description': "Win the 2♥ and the 3♦",
    'three': 2,
    'four': 3,
    'five': 3,
    'six': 5,
  },
  {
    'description': "Win at least two Aces",
    'three': 1,
    'four': 2,
    'five': 1,
    'six': 2,
  },
  {
    'description': "Win at least four ♠ cards",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 2,
  },
  {
    'description': "Win a trick containing an Ace and a 9",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 1,
  },
  {
    'description': "Win a trick led with a Court Card",
    'three': 1,
    'four': 1,
    'five': 1,
    'six': 1,
  },
  {
    'description': "Win a 9 with a Court Card",
    'three': 2,
    'four': 2,
    'five': 2,
    'six': 2,
  },
];

/// Tasks that have been reworded or reworked, from their old wording to
/// the new, so games saved before the change still load.
const Map<String, String> renamedTasks = {
  "Win more tricks than everyone else together":
      "Win more tricks than the rest of the court put together",
  "Win more tricks than everyone else":
      "Win more tricks than anyone else",
  "Win fewer tricks than everyone else":
      "Win fewer tricks than anyone else",
  "Win a 5 with a 7":
      "Win a 2 with a 6",
  "Win an 8 with a 4":
      "Win a 9 with a 5",
  "Win any 6 with another 6":
      "Win any 7 with another 7",
  "Win all four 3s":
      "Win all four 2s",
  "Win all four 9s":
      "Win all four 8s",
  "Win at least three 5s":
      "Win at least three 4s",
  "Win at least three 9s":
      "Win at least three 7s",
  "Win at least two 7s":
      "Win at least two 9s",
  "Win exactly three 6s":
      "Win exactly three 5s",
  "Win exactly two 9s":
      "Win exactly two 3s",
  "Win the A♠, 2♠ and 3♠":
      "Win the 7♣, 8♣ and 9♣",
  "Win the 6♠ and the 7♦":
      "Win the 4♥ and the 9♠",
  "Win the 5♥ and the 6♦":
      "Win the 2♠ and the 8♦",
  "Win the 5♣ and the 8♠":
      "Win the 6♥ and the 3♠",
  "Win the 5♠ and the 8♥":
      "Win the 7♦ and the 4♣",
  "Win the 9♥ and the 8♦":
      "Win the A♣ and the 5♥",
  "Win the A♥ and the 7♣":
      "Win the 9♥ and the 2♣",
  "Win the 9♦ and the 7♠":
      "Win the 3♦ and the 6♠",
  "Win the 3♣, 4♦ and 5♦":
      "Win the 2♦, 4♣ and 6♥",
  "Win the 2♣ in the last trick":
      "Win the A♥ in the last trick",
  "Win exactly one ♥ and one ♣ card":
      "Win exactly one ♦ and one ♠ card",
  "Win at least seven ♦ cards":
      "Win at least six ♣ cards",
  "Win at least five ♥ cards":
      "Win at least five ♦ cards",
  "Win exactly two ♣ cards":
      "Win exactly three ♥ cards",
  "Win exactly two ♠ cards":
      "Win exactly two ♦ cards",
  "Win exactly one ♥ card":
      "Win exactly one ♠ card",
  "Win no ♥ cards":
      "Win no ♠ cards",
  "Win at least one card of each suit (Court Cards don't count)":
      "Win a card of every suit (Court Cards don't count)",
  "Win every card of at least one suit (Court Cards don't count)":
      "Win all nine cards of any one suit",
  "Win a trick of only even numbers (that means only 2s, 4s, 6s and 8s)":
      "Win a trick of only even cards: 2s, 4s, 6s and 8s",
  "Win a trick of only odd numbers (that means only Aces, 3s, 5s, 7s and 9s)":
      "Win a trick of only odd cards: Aces, 3s, 5s, 7s and 9s",
  "Win a trick totalling more than 23 / 28 / 31 / 34 (2–3 / 4 / 5 / 6 players), with no Court Cards":
      "Win a trick totalling more than 21 / 26 / 30 / 34 (2–3 / 4 / 5 / 6 players), with no Court Cards",
  "Win a trick totalling less than 8 / 12 / 16 / 20 (2–3 / 4 / 5 / 6 players), with no Court Cards":
      "Win a trick totalling less than 9 / 13 / 17 / 21 (2–3 / 4 / 5 / 6 players), with no Court Cards",
  "Win a trick totalling exactly 22 or 23":
      "Win a trick totalling exactly 20 or 21",
  "Win exactly one Court Card (redeal if one player holds all four)":
      "Win exactly one Court Card (redeal if one player has all four)",
  "Win the Joker and no other Court Card (redeal if one player holds the Joker and King, or the Joker, Jack and Queen)":
      "Win the Joker and no other Court Card (redeal if one player has the Joker and King, or the Joker, Jack and Queen)",
  "Win the Jack and no other Court Card (redeal if one player holds the Jack and King, or the Joker, Jack and Queen)":
      "Win the Jack and no other Court Card (redeal if one player has the Jack and King, or the Joker, Jack and Queen)",
  "Win exactly two Court Cards (redeal if one player holds the Jack, Queen and King)":
      "Win exactly two Court Cards (redeal if one player has the Jack, Queen and King)",
  "Win exactly three Court Cards (redeal if one player holds all four)":
      "Win exactly three Court Cards (redeal if one player has all four)",
  "Win the 9♣ with a Court Card":
      "Win the 8♦ with a Court Card",
  "Don't lead a trick with a ♥, ♦ or ♠ card":
      "Don't lead a trick with a ♦, ♠ or ♣ card",
  "Don't lead a trick with a ♥ or ♣ card":
      "Don't lead a trick with a ♦ or ♠ card",
  "Don't win any ♣ cards":
      "Don't win any ♥ cards",
  "Don't win any ♥ or ♠ cards":
      "Don't win any ♥ or ♣ cards",
  "Don't win any ♦ or ♣ cards":
      "Don't win any ♦ or ♠ cards",
  "Don't win any 8s or 9s":
      "Don't win any 7s or 8s",
  "Don't win any 9s":
      "Don't win any 6s",
  "Don't win any 5s":
      "Don't win any 4s",
  "Don't win any Aces, 2s or 3s":
      "Don't win any Aces or 2s",
  "Win exactly X tricks, announced to everyone":
      "Win exactly X tricks, said out loud before the first trick",
  "Win exactly X tricks, kept secret (write X down and keep it hidden)":
      "Win exactly X tricks, written down in secret before the first trick",
  "Win as many ♥ cards as ♦ cards (you must win at least one of each)":
      "Win as many ♠ cards as ♣ cards (at least one of each)",
  "Win a trick with as many ♣ cards as ♦ cards (you must win at least one of each)":
      "Win a trick with as many ♥ cards as ♣ cards (at least one of each)",
  "Win a trick with as many ♥ cards as ♠ cards (you must win at least one of each)":
      "Win a trick with as many ♦ cards as ♠ cards (at least one of each)",
  "Win more ♦ cards than ♠ cards (winning no ♠ cards is fine)":
      "Win more ♠ cards than ♥ cards (winning no ♥ cards is fine)",
  "Win more ♥ cards than ♣ cards (winning no ♣ cards is fine)":
      "Win more ♣ cards than ♦ cards (winning no ♦ cards is fine)",
};
