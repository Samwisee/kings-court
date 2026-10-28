/// Everything a new game is started with, and what its mode tells the game
/// about each round.
///
/// [GameSetup] is the setup panel's choices, the players and the seed, as
/// plain data with JSON: with the game's moves it starts the same game
/// again anywhere (a replay, a bug report, a room). [ModeRules] is the
/// mode's say, handed to the game as functions, because the modes
/// themselves live above the game (modes/).
library;

import 'dart:math';

import '../models.dart';
import 'bot_turn.dart';
import 'courtiers.dart';
import 'dealer.dart';

/// What a mode tells the game about a round: how it's set up, a deal fixed
/// in advance, what the courtiers are told.
class ModeRules {
  const ModeRules({required this.roundSetup, this.riggedDeal, this.script});

  /// The round's tasks, target, seals, decree and rules; a [redeal] keeps
  /// the round's.
  final RoundSetup Function(GameState g, Random rand, {bool redeal}) roundSetup;

  /// A deal fixed in advance for the round (a lesson's), or null.
  final RiggedDeal? Function(GameState g)? riggedDeal;

  /// What the courtiers are told this round.
  final CourtierScript Function(GameState g)? script;

  /// A round drawn to the target with no seals, decree or script.
  static const plain = ModeRules(roundSetup: _plainSetup);

  static RoundSetup _plainSetup(GameState g, Random rand, {bool redeal = false}) =>
      redeal ? RoundSetup.keep(g.round) : const RoundSetup();
}

class GameSetup {
  const GameSetup({
    required this.mode,
    required this.names,
    required this.target,
    required this.seed,
    this.digital = false,
    this.surprise = false,
    this.roles = true,
    this.chapter,
    this.lesson = 0,
    this.courtiers,
    this.botNames,
  });

  final GameMode mode;

  /// The players' names, seat by seat.
  final List<String> names;
  final int target;
  final int seed;

  /// On-screen cards, with courtiers in every seat but yours.
  final bool digital;
  final bool surprise;
  final bool roles;
  final int? chapter;
  final int lesson;

  /// The houses in each seat, when the mode fixes them (the tutorial's);
  /// otherwise they're seated from the seed.
  final List<Courtier>? courtiers;

  /// The courtiers' names on screen, when the mode fixes them (the
  /// tutorial's); otherwise their houses' titles, or "Bot 2" without roles.
  final List<String>? botNames;

  int get players => names.length;

  /// The game, with its first round drawn. [you] is the seat this device
  /// plays from (named "You" on screen).
  GameState start(ModeRules rules, {int you = 0}) {
    final g = GameState()
      ..setup = this
      ..mode = mode
      ..target = target
      ..lesson = lesson
      ..seed = seed
      ..chapter = chapter
      ..surprise = surprise
      ..roles = roles
      ..players = [
        for (var i = 0; i < names.length; i++)
          Player(names[i], colorValue: playerColours[i % playerColours.length])
      ]
      ..seatCourtiers();
    if (courtiers != null) g.courtiers = List.of(courtiers!);
    if (digital) {
      // You sit at the bottom; courtiers take the other seats.
      g.digital = true;
      for (var i = 0; i < names.length; i++) {
        g.players[i].name = i == you
            ? 'You'
            : botNames != null
                ? botNames![i]
                : g.hasRoles
                    ? g.courtiers[i].title
                    : 'Bot ${i + 1}';
      }
    }
    // The first round, named after the players as seated.
    g.startRound(names.length, target,
        setup: (rand) => rules.roundSetup(g, rand));
    return g;
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.index,
        'names': names,
        'target': target,
        'seed': seed,
        'digital': digital,
        'surprise': surprise,
        'roles': roles,
        'chapter': chapter,
        'lesson': lesson,
        if (courtiers != null) 'courtiers': [for (final c in courtiers!) c.index],
        if (botNames != null) 'botNames': botNames,
      };

  static GameSetup fromJson(Map<String, dynamic> j) => GameSetup(
        mode: GameMode.values[j['mode'] as int],
        names: List<String>.from(j['names'] as List),
        target: j['target'] as int,
        seed: j['seed'] as int,
        digital: (j['digital'] as bool?) ?? false,
        surprise: (j['surprise'] as bool?) ?? false,
        roles: (j['roles'] as bool?) ?? true,
        chapter: j['chapter'] as int?,
        lesson: (j['lesson'] as int?) ?? 0,
        courtiers: j['courtiers'] == null
            ? null
            : [for (final c in j['courtiers'] as List) Courtier.values[c as int]],
        botNames: j['botNames'] == null ? null : List<String>.from(j['botNames'] as List),
      );
}
