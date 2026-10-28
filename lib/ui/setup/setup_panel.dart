/// Setting up a new game: how to play, the way to play, players, names and the last choices.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../modes/chronicle/chapters.dart';
import '../../sfx.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../menu/menu.dart';
import 'chapter_picker.dart';
import 'saves.dart';
import 'transitions.dart';

/// What the New Game panel starts with.
typedef SetupArgs = ({GameMode? mode, int? chapter});

/// The settings a New Game panel hands back.
typedef SetupResult = ({
  int count,
  int target,
  List<String> names,
  GameMode mode,
  bool surprise,
  bool roles,
  bool digital,
  int? chapter,
});

/// New game setup, laid straight onto the felt one step at a time: how to
/// play, how many players, who they are, then the points (or chapter, or
/// the start of the story). Each step fades in as the last fades away, so
/// the table never needs to scroll.
class SetupPanel extends StatefulWidget {
  const SetupPanel({
    super.key,
    required this.players,
    required this.playerCount,
    required this.targetPoints,
    required this.mode,
    required this.surprise,
    required this.roles,
    required this.chapter,
    required this.progress,
    required this.canCancel,
    required this.onCancel,
    required this.onStart,
    required this.digital,
    this.saves = const [],
    this.onContinue,
    this.onSound,
    this.newPlayer = false,
  });

  /// Sounds switched on or off on the last step (the same setting as in
  /// the menu).
  final ValueChanged<bool>? onSound;

  /// Hasn't done the tutorial yet: it's marked as the place to start.
  final bool newPlayer;

  final List<SavedGame> saves;
  final ValueChanged<SavedGame>? onContinue;
  final List<Player> players;
  final int playerCount;
  final int targetPoints;
  final GameMode mode;
  final bool surprise;
  final bool roles;
  final int chapter;
  final ChronicleProgress progress;
  final bool canCancel;
  final VoidCallback onCancel;
  final ValueChanged<SetupResult> onStart;

  /// Start with on-screen cards switched on.
  final bool digital;

  @override
  State<SetupPanel> createState() => _SetupPanelState();
}

/// What each way to play is about, shown on the first step.
const _modeInfo = {
  GameMode.free: (
    'Free play',
    'Choose a points target; add surprise seals and decrees if you like.'
  ),
  GameMode.endless: (
    'Endless',
    'Each win adds a point to the next round. How long can your streak last?'
  ),
  GameMode.chronicle: (
    'The Chronicle',
    '24 chapters of rising difficulty. Earn up to three crowns for each.'
  ),
  GameMode.dynasty: (
    'Dynasty',
    'A story of kings. Rule until wounds bring you down; face dilemmas, keep your courtiers loyal, watch for traitors.'
  ),
  GameMode.tutorial: (
    'Tutorial',
    'New to the court? Four short, guided rounds teach you to lead, follow, use Court Cards and help each other.'
  ),
};

class _SetupPanelState extends State<SetupPanel> {
  late int count =
      widget.digital && widget.playerCount < 3 ? 3 : widget.playerCount;
  late int target = widget.targetPoints.clamp(1, maxTarget);

  /// Which way the last step went, so pages turn the right way.
  int _shownStep = 0;
  bool _forward = true;
  late GameMode mode = widget.mode;
  late bool surprise = widget.surprise;
  late bool roles = widget.roles;
  late int chapter = widget.chapter;
  int step = 0;

  /// Play the cards on screen against bots, instead of using the app at a
  /// real table.
  late bool digital = widget.digital;
  late final controllers = [
    for (int i = 0; i < maxPlayers; i++)
      TextEditingController(
          text: i < widget.players.length ? widget.players[i].name : ''),
  ];

  /// The steps, in order: how you'll play, which game, then the table and
  /// the details. The first two go on as soon as you tap a choice.
  List<String> get _flow => [
        'how',
        'mode',
        // On screen the number of players is chosen on the last step; at a
        // real table it comes first, for the names.
        if (!digital) 'count',
        if (!digital) 'names',
        'final',
      ];
  int get _steps => _flow.length;

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _start() {
    widget.onStart((
      count: count,
      target: target,
      names: [
        for (int i = 0; i < count; i++)
          controllers[i].text.trim().isEmpty
              ? 'Player ${i + 1}'
              : controllers[i].text.trim(),
      ],
      mode: mode,
      surprise: surprise,
      roles: roles,
      digital: digital,
      chapter: mode == GameMode.chronicle ? chapter : null,
    ));
  }

  Future<void> _browseChapters() async {
    final chosen = await showChronicleDialog(context, widget.progress);
    if (chosen != null && mounted) setState(() => chapter = chosen);
  }

  void _next() => step == _steps - 1 || mode == GameMode.tutorial
      ? _start()
      : setState(() => step++);
  void _back() => step == 0 ? widget.onCancel() : setState(() => step--);

  static const _heading = TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w700,
      fontSize: 26,
      color: Palette.gold,
      // The same soft shadow as the title on the front page.
      shadows: [Shadow(color: Colors.black54, blurRadius: 12)]);

  Widget _modeStep() {
    return Column(
      key: const ValueKey('mode'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Which game?', textAlign: TextAlign.center, style: _heading),
        const SizedBox(height: 12),
        for (final m in [
          GameMode.free,
          GameMode.endless,
          GameMode.chronicle,
          if (digital) GameMode.dynasty,
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            // Dynasty is being remade as a story mode; its tile waits.
            child: Opacity(
              opacity: m == GameMode.dynasty ? 0.55 : 1,
              child: _ModeTile(
                title: _modeInfo[m]!.$1,
                badge: m == GameMode.dynasty ? '(Coming soon)' : null,
                description: _modeInfo[m]!.$2,
                selected: false,
                onTap: m == GameMode.dynasty
                    ? () {}
                    : () => setState(() {
                          mode = m;
                          step++;
                        }),
              ),
            ),
          ),
      ],
    );
  }

  /// The first choice: how you'll play. Tap one to go on.
  Widget _howStep() {
    Widget tile(String title, String description, IconData icon,
            VoidCallback? onTap, {String? badge, bool highlight = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Opacity(
            opacity: onTap == null ? 0.55 : 1,
            child: _ModeTile(
              title: title,
              badge: badge,
              badgeGold: highlight,
              icon: icon,
              description: description,
              selected: false,
              onTap: onTap ?? () {},
            ),
          ),
        );
    return Column(
      key: const ValueKey('how'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.saves.isNotEmpty) ...[
          const Text('Your games', textAlign: TextAlign.center, style: _heading),
          const SizedBox(height: 12),
          for (final s in widget.saves)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ModeTile(
                title: s.title,
                icon: Icons.play_arrow_rounded,
                description: [s.detail, if (s.ago.isNotEmpty) s.ago].join(' · '),
                selected: false,
                onTap: () => widget.onContinue?.call(s),
              ),
            ),
        ] else ...[
        const Text('How will you play?',
            textAlign: TextAlign.center, style: _heading),
        const SizedBox(height: 12),
        // A first-timer is pointed here first.
        tile('Tutorial', 'New to the court? Learn the rules step by step.',
            Icons.school_rounded, () {
          mode = GameMode.tutorial;
          _start();
        }, badge: widget.newPlayer ? 'Start here' : null, highlight: widget.newPlayer),
        tile('Single player',
            'Just you, with the cards on screen and courtiers who play with you.',
            Icons.person_rounded, () => setState(() {
                  digital = true;
                  if (count < 3) count = 3;
                  if (mode == GameMode.tutorial) mode = GameMode.free;
                  step++;
                })),
        tile('Multiplayer', 'Play with friends online, each on your own phone.',
            Icons.groups_rounded, null,
            badge: '(Coming soon)'),
        tile('In person',
            'Round a real table with a real deck; the app keeps the tasks.',
            Icons.table_restaurant_rounded, () => setState(() {
                  digital = false;
                  if (mode == GameMode.tutorial) mode = GameMode.free;
                  step++;
                })),
        ],
      ],
    );
  }

  Widget _countStep() {
    return Column(
      key: const ValueKey('count'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('How many players?',
            textAlign: TextAlign.center, style: _heading),
        const SizedBox(height: 18),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int n = digital ? 3 : minPlayers; n <= maxPlayers; n++)
                _CountChip(
                    n: n, selected: count == n, onTap: () => setState(() => count = n)),
            ],
          ),
        const SizedBox(height: 8),
        if (!digital)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0x22000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Setting up the deck',
                    style: TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Palette.gold)),
                SizedBox(height: 6),
                SuitText(
                    '1. From an ordinary pack, keep the Ace to 9 of ♥ ♦ ♠ ♣ (Aces count as 1). Put the 10s and picture cards aside.\n'
                    '2. Add four Court Cards: a Joker, a Jack, a Queen and a King. They are their own suit and beat every other card, Joker lowest, King highest.\n'
                    '3. That makes 40 cards. Shuffle and deal them all out; some players may get one more card than others.\n'
                    '4. Whoever has the King card is the King: tap their seat and the tasks are dealt.',
                    style: TextStyle(
                        fontSize: 14.5, height: 1.4, color: Colors.white)),
              ],
            ),
          ),
        // Room is kept for the hint so nothing jumps when it appears (only
        // at a real table, where there's one to give).
        if (!digital) const SizedBox(height: 6),
        if (!digital)
        SizedBox(
          height: 66,
          child: Text(
            digital
                ? 'You take the bottom seat. Bots play the rest, with you, not against you.'
                : count == 2
                ? 'Two players add a third hand, the Dummy, which the King plays. Tasks use the 3-player difficulty.'
                : '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _namesStep() {
    return Column(
      key: const ValueKey('names'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Who sits at the table?',
            textAlign: TextAlign.center, style: _heading),
        const SizedBox(height: 6),
        const Text('Optional. Names give each seat its initials.',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 14),
        for (int i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: controllers[i],
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Player ${i + 1}',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child:
                      CircleAvatar(radius: 8, backgroundColor: Palette.players[i]),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
      ],
    );
  }

  /// Sounds, asked every time before a game starts, set as last time.
  Widget _soundSwitch() => PipTile(
        value: Sfx.enabled,
        onChanged: (v) {
          widget.onSound?.call(v);
          setState(() {});
        },
        title: const Text('Sounds', style: TextStyle(fontSize: 16)),
        subtitle: const Text('Fanfares and the sounds of the cards.',
            style: TextStyle(color: Colors.white70)),
      );

  /// The last step's choices, with room to breathe between them and in
  /// from the sides.
  Widget _settingsPanel(List<Widget> rows) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, r) in rows.indexed) ...[
              // A faint gold rule between choices, fading at the ends.
              if (i > 0)
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Palette.gold.withValues(alpha: 0),
                      Palette.gold.withValues(alpha: 0.35),
                      Palette.gold.withValues(alpha: 0),
                    ]),
                  ),
                ),
              r,
            ],
          ],
        ),
      );

  /// On screen: how many sit at the table (you and the courtiers).
  Widget _playersRow() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Text('Players', style: TextStyle(fontSize: 16)),
            SizedBox(width: 12),
            Expanded(
              child: Text('You and your courtiers',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Colors.white70)),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int n = 3; n <= maxPlayers; n++)
                _CountChip(
                    n: n, selected: count == n, onTap: () => setState(() => count = n)),
            ],
          ),
        ],
      );

  Widget _finalStep() {
    switch (mode) {
      case GameMode.chronicle:
        return Column(
          key: const ValueKey('chapter'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Which chapter?', style: _heading),
            const SizedBox(height: 14),
            ChapterPicker(
              progress: widget.progress,
              chapter: chapter,
              onChanged: (c) => setState(() => chapter = c),
            ),
            TextButton.icon(
              onPressed: _browseChapters,
              icon: const CrownIcon(size: 14),
              label: Text('All chapters (${widget.progress.totalCrowns} crowns)'),
              style: TextButton.styleFrom(foregroundColor: Palette.gold),
            ),
            _settingsPanel([if (digital) _playersRow(), _soundSwitch()]),
          ],
        );
      case GameMode.dynasty:
      case GameMode.tutorial:
        return const SizedBox.shrink();
      case GameMode.free:
      case GameMode.endless:
        return Column(
          key: const ValueKey('points'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text('Setup', style: _heading)),
            const SizedBox(height: 4),
            _settingsPanel([
            if (digital) _playersRow(),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(
              children: [
                const Text('Points target', style: TextStyle(fontSize: 16)),
                const Spacer(),
                Text('$target',
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        color: Palette.gold)),
                const SizedBox(width: 4),
                const CrownIcon(size: 18),
              ],
            ),
            Slider(
              value: target.clamp(1, maxTarget).toDouble(),
              min: 1,
              max: maxTarget.toDouble(),
              divisions: maxTarget - 1,
              onChanged: (v) => setState(() => target = v.round()),
            ),
            const Text('Higher targets mean more or harder tasks.',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            ]),
              PipTile(
                value: surprise,
                onChanged: (v) => setState(() => surprise = v),
                title: const Text('Seals and decrees',
                    style: TextStyle(fontSize: 16)),
                subtitle: const Text(
                    'Surprise me: rounds may bring order seals and royal decrees.',
                    style: TextStyle(color: Colors.white70)),
              ),
              _soundSwitch(),
            ]),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_flow[math.min(step, _steps - 1)]) {
      'how' => _howStep(),
      'mode' => _modeStep(),
      'count' => _countStep(),
      'names' => _namesStep(),
      _ => _finalStep(),
    };
    final choosing = step < 2;
    final last = step == _steps - 1;
    if (step != _shownStep) {
      _forward = step > _shownStep;
      _shownStep = step;
    }
    final still = MediaQuery.disableAnimationsOf(context);

    // Fills the screen: progress at the top, the step in the middle, and
    // the buttons fixed in the bottom corners so they never move. Every
    // word on the felt has the front page's soft shadow.
    return DefaultTextStyle.merge(
      style: const TextStyle(shadows: feltShadow),
      child: SizedBox.expand(
      child: Padding(
        // Clear of the table's edge and brass inlay all round.
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
        child: Column(
          children: [
            // Progress: one pip per step, with a way back on the first
            // two (which go on as soon as you choose).
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: AnimatedOpacity(
                    opacity: choosing && step == 0 && widget.canCancel ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !(choosing && step == 0 && widget.canCancel),
                      child: IconButton(
                        tooltip: 'Cancel',
                        onPressed: _back,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    // A crown for each step: gold once reached, and the
                    // current one larger, springing up as you arrive.
                    children: [
                      for (int i = 0; i < _steps; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedScale(
                            scale: i == step ? 1.5 : 1,
                            duration: const Duration(milliseconds: 360),
                            curve: Curves.easeOutCubic,
                            child: TweenAnimationBuilder<Color?>(
                              tween: ColorTween(
                                  end: i <= step ? Palette.gold : Colors.white24),
                              duration: const Duration(milliseconds: 360),
                              builder: (context, c, _) =>
                                  CrownIcon(size: 14, color: c ?? Colors.white24),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: still ? 200 : 460),
                // The old step goes first, then the new one is dealt in.
                // Fade out, then fade in.
                switchInCurve: still
                    ? Curves.easeOut
                    : const Interval(0.5, 1, curve: Curves.easeOut),
                switchOutCurve: still
                    ? Curves.easeIn
                    : const Interval(0.5, 1, curve: Curves.easeIn),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.center,
                  children: [...previous, if (current != null) current],
                ),
                transitionBuilder: (child, a) => still
                    ? FadeTransition(opacity: a, child: child)
                    : PageTurn(
                        animation: a,
                        incoming: child.key == ValueKey(step),
                        forward: _forward,
                        style: TurnStyle.fade,
                        child: child),
                child: Center(
                  key: ValueKey(step),
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: body,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Always there, so the step above never shifts: the buttons
            // fade in and out instead.
            const SizedBox(height: 12),
            // Kept near the step on a wide screen, not out in the corners.
            // The first step has a way back to where you came from.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, minHeight: 56, maxHeight: 56),
              child: Row(
              children: [
                AnimatedOpacity(
                  opacity: step > 0 || widget.canCancel ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !(step > 0 || widget.canCancel),
                    child: TextButton(
                      onPressed: _back,
                      child: const Text('Back'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedOpacity(
                  opacity: choosing ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                  ignoring: choosing,
                  child: Align(
                    alignment: Alignment.centerRight,
                    // Shrinks rather than cutting the words off.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: FilledButton(
                    onPressed: _next,
                    child: Text(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        mode == GameMode.tutorial
                            ? 'Start the tutorial'
                            : !last
                                ? 'Next'
                                : 'Start'),
                      ),
                    ),
                  ),
                  ),
                  ),
                ),
              ],
            ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

/// One way to play on the first setup step.
class _ModeTile extends StatelessWidget {
  const _ModeTile(
      {required this.title,
      this.badge,
      this.badgeGold = false,
      this.icon,
      required this.description,
      required this.selected,
      required this.onTap});
  final String title;

  /// A gold icon at the start of the tile.
  final IconData? icon;

  /// A note beside the title, such as "(Alpha)" for a mode still taking
  /// shape.
  final String? badge;

  /// The badge in gold, for one that invites rather than warns.
  final bool badgeGold;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
      color: selected ? const Color(0x33D4A63A) : const Color(0x22000000),
      // Gold double rule with a jewel in each corner, like the menus.
      shape: const OrnateBorder(radius: 12, gems: false),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 12, 10),
          child: Row(children: [
            if (icon != null) ...[
              Icon(icon, color: Palette.gold, size: 28),
              const SizedBox(width: 14),
            ],
            Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(title,
                        style: TextStyle(
                            fontFamily: displayFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: selected ? Palette.gold : Colors.white)),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Text(badge!,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: badgeGold ? Palette.gold : Colors.white70)),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(description,
                  style: const TextStyle(
                      fontSize: 14, height: 1.3, color: Colors.white70)),
            ],
          ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Palette.gold),
          ]),
        ),
      ),
    ),
    );
  }
}

/// A big number to tap for the player count.
class _CountChip extends StatelessWidget {
  const _CountChip(
      {required this.n, required this.selected, required this.onTap});
  final int n;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$n players',
      excludeSemantics: true,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
        onTap: onTap,
        // A large gold pip: a gold ring, filled with a glowing jewel
        // when chosen, the number in its middle.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x22000000),
            border: Border.all(color: Palette.gold, width: 2.5),
            boxShadow: selected
                ? [BoxShadow(color: Palette.gold.withValues(alpha: 0.45), blurRadius: 12)]
                : null,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: selected
                  ? const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      colors: [Palette.goldPale, Palette.gold])
                  : null,
            ),
            child: Text('$n',
                textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
                style: TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    height: 1,
                    color: selected ? Palette.ink : Colors.white,
                    shadows: selected
                        ? null
                        : const [Shadow(color: Colors.black54, blurRadius: 8)])),
          ),
        ),
      )),
    );
  }
}
