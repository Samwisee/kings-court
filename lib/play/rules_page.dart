/// How to Play: every rule, with an index to jump straight to a section.
/// Opened during a game it starts with what's in play right now, and shows
/// only the rules that apply to it (with every rule a tap away).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../chronicle.dart';
import '../theme.dart';
import '../widgets.dart';

/// Which games a section of the rules is about.
enum RulesFor { all, onScreen, inPerson, dynasty, twoPlayer }

/// What's being played, for the rules to fit it.
class RulesContext {
  const RulesContext({
    required this.modeName,
    required this.onScreen,
    required this.players,
    required this.dynasty,
    this.points,
    this.seals = const [],
    this.decree,
    this.roles = false,
  });
  final String modeName;
  final bool onScreen;
  final int players;
  final bool dynasty;
  final int? points;
  final List<int> seals;
  final String? decree;
  final bool roles;
}

class _Section {
  const _Section(this.title, this.rules, [this.forGame = RulesFor.all]);
  final String title;
  final List<String> rules;
  final RulesFor forGame;
}

const _sections = <_Section>[
  _Section('The aim', [
    'Everyone plays together. Each round the court is dealt tasks, such as “Win the 3♥” or “Win the first trick”. Each player takes some, then everyone plays tricks to complete them.',
    'Complete every task and the round is won. If any task fails, the round is lost.',
    'The King’s Court is inspired by The Crew, the cooperative trick-taking game by Thomas Sing.',
  ]),
  _Section('The cards', [
    '40 cards: Ace (1) to 9 in ♥ ♦ ♠ ♣, plus four Court Cards: the Joker, Jack, Queen and King, from lowest to highest. Court Cards are their own suit and beat every plain card.',
    'Whoever holds the King card is the King for the round: they pick first and lead the first trick.',
  ]),
  _Section('Setting up a real deck', [
    'From an ordinary pack, keep the Ace to 9 of each suit and put the 10s and picture cards aside. Add a Joker, a Jack, a Queen and a King as the Court Cards, whatever suit is printed on them.',
    'Shuffle and deal out all 40 cards. With 3 or 6 players some players get one card more.',
    'Put the phone in the middle. Whoever holds the King card shows it and taps their seat, and the tasks are dealt onto the table.',
  ], RulesFor.inPerson),
  _Section('Choosing tasks', [
    'The tasks are shuffled and dealt face up in the middle of the table.',
    'Before anyone picks, you may show a card (see Showing a card): tap it in your hand, or tap Skip.',
    'Picking goes round from the King. When it’s your pick, press and hold a task to take it (a tap reads it, and its close-up has a Take button).',
    'Once a round you may pass instead, with Pass beside the status line: the pick moves on. Courtiers may pass too, and say so.',
    'A task outlined in a player’s colour can only be taken by them. Some tasks can’t be taken: the King can’t take a task marked with a barred circle, no one may hold two tasks that work against each other, and your own hand can rule a task out (you can’t win the 7♥ with a Court Card if you hold the 7♥).',
  ], RulesFor.onScreen),
  _Section('Choosing tasks', [
    'Look at your hand. Then, starting with the King and going clockwise, each player takes one task until all are taken: drag it onto your seat. A glowing ring shows whose pick it is.',
    'Once a round, the player picking may pass instead: tap Pass in the top bar.',
    'A task is yours alone: only the tricks you win count towards it.',
  ], RulesFor.inPerson),
  _Section('Playing a trick', [
    'The King leads the first trick with any card. Going clockwise, everyone plays one card.',
    'You must play the suit that was led if you can. If you can’t, play any card, including a Court Card. If a Court Card is led, play a Court Card if you have one.',
    'The highest card of the suit led wins, unless a Court Card was played: then the highest Court Card wins.',
    'The winner takes the trick, and every card in it, and leads the next one. Play on until every card is used.',
  ]),
  _Section('Playing on screen', [
    'You sit at the bottom; the courtiers are bots who play with you, not against you.',
    'Tap a card in your hand to play it. Cards you may play stand up. Once a suit is led you can tap your card early: it’s played as soon as your turn comes.',
    'Tasks, seals and schemes are judged by the cards as the tricks fall. A few cards may be set aside unseen so everyone holds the same number.',
    'The card tracker button \uE003 beside your hand opens the card tracker: every card, which have been played (by whom, in which trick), and what can be worked out about the others’ hands.',
    'Tap any task to see whose it is, how it’s going, the cards it’s about and what it means.',
  ], RulesFor.onScreen),
  _Section('Showing a card', [
    'You may not say what’s in your hand or suggest what anyone should play.',
    'Once a round, you may show one card: your highest, lowest or only card of a suit, saying which. It stays in your hand, face up, until played. Court Cards can’t be shown.',
    'On screen: tap the speech button \uE002, then the card. You can show a card while tasks are chosen, before a trick or between tricks; tap mid-trick and you’ll show it once the trick ends.',
    'At a real table: lay the card face up and tap your seat to flip your speech token (with courtly roles, mark it on your courtier’s card).',
  ]),
  _Section('Reading tasks', [
    'The number on a task is how hard it is, in crowns. A barred circle means the King can’t take it; an i in a circle means there’s an extra condition; a struck-out Court Card means the trick can’t hold any Court Cards. Tap a task to read its marks.',
    'On screen, many tasks keep count in the corner (“2/4”, “safe 1/3”, “6s: 3 left”), and cards a task needs are crossed out once won.',
    'At a real table: tap a task to mark it done or failed. Mark it failed as soon as it can’t be done; the round ends there. Press and hold the felt to turn every task towards you.',
  ]),
  _Section('Seals', [
    'Some tasks carry a red wax seal. Sealed tasks must be done in order: seal I before seal II before seal III.',
    'The Ω seal must be the very last task done in the round.',
    'Doing a sealed task out of order fails the round.',
  ]),
  _Section('Royal decrees', [
    'Some rounds bring a royal decree. Tap its name at the top to read it again.',
    'Silence: no showing cards. Late Counsel: no showing cards until three tricks have been played.',
    'King’s Command: the King hands out every task. Exile: one player may take no tasks this round.',
  ]),
  _Section('Ways to play', [
    'Tutorial: the rules step by step, then four short guided rounds.',
    'Free play: you choose the points target. Turn on Seals and decrees for surprises.',
    'Endless: each win adds a point to the next round; the app keeps your win streaks.',
    'The Chronicle: 24 chapters with set points, seals and decrees. Earn up to three crowns for each.',
    'Dynasty (Alpha): a solo story on screen. You are the King, with courtiers, powers and dilemmas.',
    'Courtly roles: everyone plays a courtier of a great house, with a power to use once a round. Tap a seat to read it.',
    'Your game saves as you play, one save for each way to play: tap Play to pick any of them up.',
  ]),
  _Section('Dynasty (Alpha)', [
    'You are the King. You take the King card into your hand each round, and keep the crown round after round.',
    'Every lost round wounds the King. How many wounds they can bear is secret: one, two or three. When the King falls, an heir is crowned and the dynasty goes on.',
    'Each round opens with tidings from the kingdom, and may charge one house with a task (the gold ribbon). After each round the King faces a dilemma; choices win or lose courtiers’ loyalty, heal or wound the King, and can bring decrees.',
    'Loyalty is a candle by each courtier: the taller the flame, the more loyal. A courtier whose loyalty runs out turns traitor, with a scheme shown as a black card. Stop it, or the King is wounded.',
    'Some matters divide the court: the sides play the Trial of Hearts, where every ♥ won is a mark of shame and the Q♠ is five.',
    'The story runs from the harvest to war with Karsk. Conquer Karsk or seal a lasting peace to secure the realm. If three Kings fall, or traitors outnumber the loyal, the dynasty falls.',
  ], RulesFor.dynasty),
  _Section('Two players', [
    'Deal 13 cards each. The other 14 go to a third hand, the Dummy: 7 face down, with 7 face up on top. When a face-up Dummy card is played, flip the card underneath it.',
    'The King plays the Dummy’s cards as well as their own. Only the two players take tasks, which use the 3-player difficulty.',
  ], RulesFor.twoPlayer),
];

bool _applies(_Section s, RulesContext? c) {
  if (c == null) return true;
  return switch (s.forGame) {
    RulesFor.all => true,
    RulesFor.onScreen => c.onScreen,
    RulesFor.inPerson => !c.onScreen,
    RulesFor.dynasty => c.dynasty,
    RulesFor.twoPlayer => !c.onScreen && c.players == 2,
  };
}

Future<void> showRulesPage(BuildContext context, {RulesContext? game}) =>
    Navigator.of(context).push(PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (c, a, b) => RulesPage(game: game),
        transitionsBuilder: (c, a, b, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: child)));

const _shadow = [Shadow(color: Colors.black54, blurRadius: 10)];
const _ruleStyle = TextStyle(
    fontSize: 16, height: 1.45, color: Colors.white, shadows: [Shadow(color: Colors.black38, blurRadius: 6)]);

/// The rules, on the felt like the rest of the court: gold headings, each
/// section on its own dark panel, and an index of gold tabs to jump about.
class RulesPage extends StatefulWidget {
  const RulesPage({super.key, this.game});
  final RulesContext? game;

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  bool _all = false;
  final _keys = <int, GlobalKey>{};

  /// Sections just brought in by "Show every rule", to open up as they come.
  Set<int> _revealing = {};

  /// Sections on their way out after "Show every rule" is turned off: still
  /// drawn while they close up and fade.
  Set<int> _leaving = {};
  Timer? _leaveTimer;

  @override
  void dispose() {
    _leaveTimer?.cancel();
    super.dispose();
  }

  void _jump(int i) {
    final ctx = _keys[i]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final shown = [
      for (int i = 0; i < _sections.length; i++)
        if (_all || _applies(_sections[i], g) || _leaving.contains(i)) i
    ];
    return Scaffold(
      backgroundColor: Palette.feltDeep,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.2,
            colors: [Palette.felt, Palette.feltDeep],
          ),
        ),
        child: SafeArea(
          child: Stack(children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(TableTrim.rim + 4),
              child: Column(
            children: [
              // The top bar: the title, and a gold cross to close.
              // The title in the middle with room either side, so the
              // cross never sits on it; a brass rule underneath.
              Container(
                height: 64,
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: Palette.gold.withValues(alpha: 0.8), width: 1.5)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 56),
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('How to Play',
                            style: TextStyle(
                                fontFamily: displayFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 26,
                                color: Palette.gold,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 12)
                                ])),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                            overlayColor: Colors.transparent),
                        icon: const Icon(Icons.close_rounded,
                            color: Palette.gold, size: 30, shadows: _shadow),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (g != null) _thisGame(g),
                          // The index: tap a section to jump to it.
                          // This game's sections; every other section's tabs
                          // open below them as a block, row by row.
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final i in shown)
                                if (g == null || _applies(_sections[i], g))
                                  _Tab(_sections[i].title, () => _jump(i)),
                            ],
                          ),
                          if (g != null &&
                              shown.any((i) => !_applies(_sections[i], g)))
                            _Reveal(
                              key: const ValueKey('more-tabs'),
                              animate: _revealing.isNotEmpty,
                              leaving: _leaving.isNotEmpty,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final i in shown)
                                      if (!_applies(_sections[i], g))
                                        _Tab(_sections[i].title, () => _jump(i)),
                                  ],
                                ),
                              ),
                            ),
                          if (g != null)
                            Center(
                              child: TextButton(
                                onPressed: () => setState(() {
                                  final before = {
                                    for (int i = 0; i < _sections.length; i++)
                                      if (_all || _applies(_sections[i], g)) i
                                  };
                                  _all = !_all;
                                  _leaveTimer?.cancel();
                                  if (_all) {
                                    _leaving = {};
                                    _revealing = {
                                      for (int i = 0; i < _sections.length; i++)
                                        if (!before.contains(i)) i
                                    };
                                  } else {
                                    // The extra rules close up and fade
                                    // before they go.
                                    _revealing = {};
                                    _leaving = {
                                      for (final i in before)
                                        if (!_applies(_sections[i], g)) i
                                    };
                                    _leaveTimer = Timer(
                                        const Duration(milliseconds: 450),
                                        () => mounted
                                            ? setState(() => _leaving = {})
                                            : null);
                                  }
                                }),
                                style: TextButton.styleFrom(
                                    foregroundColor: Palette.gold,
                                    overlayColor: Colors.transparent),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GoldPip(on: _all, size: 18),
                                    const SizedBox(width: 8),
                                    const Text('Show every rule',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            shadows: _shadow)),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          for (final i in shown)
                            _Reveal(
                              // Rules brought in by "Show every rule" open
                              // up and fade in; the rest are simply there.
                              key: ValueKey('reveal-$i'),
                              animate: _revealing.contains(i),
                              leaving: _leaving.contains(i),
                              child: _Panel(
                              key: _keys.putIfAbsent(i, GlobalKey.new),
                              title: _sections[i].title,
                              children: [
                                for (final rule in _sections[i].rules)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 6, right: 10),
                                          child: CrownIcon(size: 12, color: Palette.gold),
                                        ),
                                        Expanded(child: SuitText(rule, style: _ruleStyle)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            ),
                          const SizedBox(height: 10),
                          Center(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Got it'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: TableTrim())),
          ]),
        ),
      ),
    );
  }

  /// What's in play right now.
  Widget _thisGame(RulesContext g) {
    final lines = [
      '${g.modeName} · ${g.onScreen ? 'on screen' : 'with a real deck'} · ${g.players} players',
      if (g.points != null) 'Points target: ${g.points}',
      if (g.seals.isNotEmpty)
        'Seals this round: ${g.seals.map(Seals.label).join(', ')} (see Seals)',
      if (g.decree != null) 'Decree in force: ${g.decree} (see Royal decrees)',
      if (g.roles) 'Courtly roles are on: tap a seat to read its power.',
    ];
    return OrnateCard(
      won: false,
      court: true,
      maxWidth: 620,
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 18),
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
      // Full width, so every line sits in the middle of the panel.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('This game',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                  color: Palette.gold,
                  shadows: _shadow)),
          const SizedBox(height: 6),
          for (final l in lines)
            Text(l, textAlign: TextAlign.center, style: _ruleStyle.copyWith(fontSize: 15)),
        ],
      ),
    );
  }
}

/// A gold tab in the index.
class _Tab extends StatelessWidget {
  const _Tab(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0x33000000),
        shape: StadiumBorder(
            side: BorderSide(color: Palette.gold.withValues(alpha: 0.7), width: 1.4)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          splashColor: Palette.gold.withValues(alpha: 0.2),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(label,
                style: const TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Palette.gold,
                    shadows: _shadow)),
          ),
        ),
      );
}

/// One section of the rules: a dark panel with a gold rule and heading.
class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x40000000), Color(0x26000000)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.gold.withValues(alpha: 0.45), width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title,
                  style: const TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 21,
                      color: Palette.gold,
                      shadows: _shadow)),
            ),
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 12),
              height: 1.4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Palette.gold.withValues(alpha: 0.8),
                  Palette.gold.withValues(alpha: 0),
                ]),
              ),
            ),
            ...children,
          ],
        ),
      );
}

/// A section that opens up and fades in as it arrives (when [animate]).
class _Reveal extends StatefulWidget {
  const _Reveal(
      {super.key,
      required this.animate,
      required this.child,
      this.grow = true,
      this.leaving = false});
  final bool animate;

  /// On its way out: closes up and fades.
  final bool leaving;
  final Widget child;

  /// Opens up from nothing (a section); otherwise pops softly into its
  /// place (an index tab).
  final bool grow;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420), value: widget.animate ? 0 : 1);
  late final Animation<double> _ease =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void didUpdateWidget(_Reveal old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) _c.reverse();
    if (!widget.leaving && old.leaving) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !widget.grow
      ? FadeTransition(
          opacity: _ease,
          child: ScaleTransition(
              scale: Tween(begin: 0.8, end: 1.0).animate(_ease), child: widget.child),
        )
      : SizeTransition(
        sizeFactor: _ease,
        axisAlignment: -1,
        child: FadeTransition(
          opacity: _ease,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(_ease),
            child: widget.child,
          ),
        ),
      );
}
