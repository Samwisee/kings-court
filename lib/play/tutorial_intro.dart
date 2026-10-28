/// The tutorial's reading pages, a few before each lesson: the rules that
/// lesson plays out, each with an example drawn in the game's own cards and
/// tasks (tap a task to read it, as in a game). Every page waits for
/// Continue, so newcomers read at their own pace.
///
/// Pops with 'go' to play on, 'back' to step back out, or 'quit' to leave
/// the tutorial.
library;

import 'package:flutter/material.dart';

import '../courtiers.dart';
import '../engine/cards.dart';
import '../models.dart';
import '../task_help.dart';
import '../theme.dart';
import '../tutorial.dart';
import '../widgets.dart';
import 'card_view.dart';

const _shadow = [Shadow(color: Colors.black54, blurRadius: 10)];

/// Opens a part of the tutorial: [pages], then [finishLabel] to go on.
Future<String?> showTutorialPages(BuildContext context,
        {required List<IntroPage> pages,
        required String heading,
        required String finishLabel}) =>
    Navigator.of(context).push<String>(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (c, a, b) =>
            TutorialIntro(pages: pages, heading: heading, finishLabel: finishLabel),
        transitionsBuilder: (c, a, b, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child)));

class TutorialIntro extends StatefulWidget {
  const TutorialIntro(
      {super.key, required this.pages, required this.heading, required this.finishLabel});
  final List<IntroPage> pages;

  /// Which part of the tutorial this is, at the top.
  final String heading;

  /// The last page's button: the lesson that follows.
  final String finishLabel;

  @override
  State<TutorialIntro> createState() => _TutorialIntroState();
}

class _TutorialIntroState extends State<TutorialIntro> {
  int page = 0;

  List<IntroPage> get pages => widget.pages;
  bool get _last => page == pages.length - 1;

  void _continue() => _last ? Navigator.pop(context, 'go') : setState(() => page++);
  void _back() => page == 0 ? Navigator.pop(context, 'back') : setState(() => page--);

  @override
  Widget build(BuildContext context) {
    final p = pages[page];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
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
                    // The part's name in the middle, a cross to leave the
                    // tutorial, and a brass rule underneath.
                    Container(
                      padding: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Palette.gold.withValues(alpha: 0.8), width: 1.5)),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(height: 56, child: Row(children: [
                        const SizedBox(width: 56),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(widget.heading,
                                style: const TextStyle(
                                    fontFamily: displayFont,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                    color: Palette.gold,
                                    shadows: _shadow)),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: IconButton(
                            tooltip: 'Leave the tutorial',
                            onPressed: () => Navigator.pop(context, 'quit'),
                            style: IconButton.styleFrom(overlayColor: Colors.transparent),
                            icon: const Icon(Icons.close_rounded,
                                color: Palette.gold, size: 28, shadows: _shadow),
                          ),
                        ),
                      ])),
                      // A crown for each page: gold once reached.
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Semantics(
                        label: 'Page ${page + 1} of ${pages.length}',
                        excludeSemantics: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (int i = 0; i < pages.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: AnimatedScale(
                                  scale: i == page ? 1.4 : 1,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  child: TweenAnimationBuilder<Color?>(
                                    tween: ColorTween(
                                        end: i <= page ? Palette.gold : Colors.white24),
                                    duration: const Duration(milliseconds: 300),
                                    builder: (context, c, _) =>
                                        CrownIcon(size: 13, color: c ?? Colors.white24),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                      ]),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: reduceMotion ? 0 : 320),
                        switchInCurve: const Interval(0.4, 1, curve: Curves.easeOut),
                        switchOutCurve: const Interval(0.4, 1, curve: Curves.easeIn),
                        layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.topCenter,
                            children: [...previous, if (current != null) current]),
                        transitionBuilder: (child, a) =>
                            FadeTransition(opacity: a, child: child),
                        child: SingleChildScrollView(
                          key: ValueKey(page),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(p.title,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontFamily: displayFont,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 27,
                                            color: Palette.gold,
                                            shadows: [
                                              Shadow(color: Colors.black54, blurRadius: 12)
                                            ])),
                                  ),
                                  const SizedBox(height: 18),
                                  Center(child: _art(p.art)),
                                  const SizedBox(height: 20),
                                  for (final para in p.paragraphs)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: SuitText(para,
                                          style: const TextStyle(
                                              fontSize: 17,
                                              height: 1.45,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(color: Colors.black38, blurRadius: 6)
                                              ])),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Back and on, fixed at the bottom.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _back,
                                style: TextButton.styleFrom(
                                    foregroundColor: Palette.gold,
                                    overlayColor: Colors.transparent),
                                child: const Text('Back',
                                    style: TextStyle(fontSize: 16, shadows: _shadow)),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: _continue,
                                    child: Text(_last ? widget.finishLabel : 'Continue'),
                                  ),
                                ),
                              ),
                            ],
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

  /// A task's close-up, as in a game: its points and marks, its words, what
  /// each mark means, and what the task means in plain words.
  void _preview(Task task) {
    final marks = <(Widget, String)>[
      if (task.noCourtCards)
        (const NoCourtIcon(size: 16), 'The trick can\u2019t have any Court Cards in it.'),
      if (task.kingCantTake)
        (const Icon(Icons.block, size: 16, color: Palette.inkSoft),
            'The King can\u2019t take this task.'),
      for (final n in task.notes)
        (const Icon(Icons.info_outline, size: 16, color: Palette.inkSoft), n),
    ];
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DialogStyle.paper,
        shape: const HighVisBorder(null),
        scrollable: true,
        contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('${task.getPointsForPlayerCount(3)}',
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        height: 1,
                        color: Palette.ink)),
                const SizedBox(width: 3),
                const CrownIcon(size: 19, color: Palette.goldDeep),
                for (final (icon, _) in marks) ...[
                  const SizedBox(width: 7),
                  icon,
                ],
              ]),
              const SizedBox(height: 6),
              SuitText(task.fullText(3),
                  style: const TextStyle(
                      fontSize: 19,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: Palette.ink)),
              for (final (icon, words) in marks)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 26, child: Align(alignment: Alignment.topLeft, child: icon)),
                    Expanded(
                      child: SuitText(words,
                          style: const TextStyle(
                              fontSize: 14.5, height: 1.35, color: Palette.inkSoft)),
                    ),
                  ]),
                ),
              const SizedBox(height: 12),
              SuitText(explainTask(task.description),
                  style: const TextStyle(fontSize: 15, height: 1.4, color: Palette.ink)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Palette.ink),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static PlayingCard _c(String label) => PlayingCard.parse(label)!;

  Widget _card(String label, {double width = 58, bool glow = false, bool dimmed = false, Color? edge}) =>
      PlayingCardView(
          card: _c(label), width: width, glow: glow, dimmed: dimmed, edge: edge);

  Widget _caption(String text, {Color color = Colors.white70}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: SuitText(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.25, color: color)),
      );

  /// A card with a caption under it.
  Widget _labelled(Widget card, String text, {Color color = Colors.white70}) =>
      SizedBox(
        width: 92,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          card,
          _caption(text, color: color),
        ]),
      );

  /// A task card as on the table; tap it for its close-up.
  Widget _task(String description, {double width = 150, int? owner}) {
    final task = GameState.taskPool
        .firstWhere((t) => t.description == description)
        .freshCopy();
    final text = task.boardText(3);
    final size = TableCard.sizeFor(text, width);
    return Semantics(
      button: true,
      label: 'Task: ${task.fullText(3)}. Tap to read it.',
      child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
        onTap: () => _preview(task),
        child: TableCard(
            task: task,
            text: text,
            points: task.getPointsForPlayerCount(3),
            owner: owner == null
                ? null
                : Player(tutorialCourtiers[owner], colorValue: Palette.players[owner].toARGB32()),
            width: size.width,
            height: size.height),
      )),
    );
  }

  /// A seat token as at the table: the house's shape in the player's
  /// colour. Seat 0 is you (the General), 1 the Duke, 2 the Bishop.
  Widget _token(int seat, String label, double size, {TokenShape? shape}) =>
      IgnorePointer(
        child: SeatToken(
          player: Player(label, colorValue: Palette.players[seat].toARGB32()),
          label: label,
          size: size,
          shape: shape ?? tutorialHouses[seat].shape,
        ),
      );

  Widget _art(IntroArt art) {
    switch (art) {
      case IntroArt.court:
        return Column(children: [
          const CrownIcon(size: 64),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final c in ['Joker', 'Jack', 'Queen', 'King']) _card(c, width: 54),
          ]),
        ]);
      case IntroArt.goal:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _task('Win the 3♥'),
            _task('Win the first trick'),
          ],
        );
      case IntroArt.cards:
        return Column(children: [
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (final c in ['A♥', '4♦', '7♠', '9♣']) _card(c, width: 54),
          ]),
          _caption('Four suits, Ace (1) to 9'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (final c in ['Joker', 'Jack', 'Queen', 'King']) _card(c, width: 54),
          ]),
          _caption('Court Cards, lowest to highest →'),
        ]);
      case IntroArt.trick:
        return _trick([
          ('4♠', 1, 'The Duke leads the 4♠', false),
          ('9♠', 0, 'Your 9♠ is highest: you win', true),
          ('2♠', 2, 'The Bishop plays the 2♠', false),
        ]);
      case IntroArt.firstRound:
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            _task('Win the first trick', owner: 0),
            _labelled(_card('9♠', glow: true), 'Lead your 9♠', color: Palette.gold),
          ],
        );
      case IntroArt.follow:
        return Column(children: [
          _labelled(_card('6♥', edge: Palette.players[1]), '♥ was led'),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
            _card('2♥', width: 50),
            _card('8♥', width: 50),
            _card('5♣', width: 50, dimmed: true),
            _card('7♠', width: 50, dimmed: true),
            _card('Jack', width: 50, dimmed: true),
          ]),
          _caption('Your hand: you hold ♥, so you must play the 2♥ or the 8♥. The others are shaded.'),
        ]);
      case IntroArt.winCards:
        return Column(children: [
          _trick([
            ('8♥', 0, 'You lead the 8♥', true),
            ('3♥', 1, 'The Duke must follow: his only ♥', false),
            ('5♥', 2, 'The Bishop plays the 5♥', false),
          ]),
          const SizedBox(height: 12),
          _task('Win the 3♥', owner: 0),
          _caption('Your trick holds the 3♥: the task is done.', color: Palette.gold),
        ]);
      case IntroArt.tasks:
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _task('Win the 3♥', width: 150),
            _task('Win fewer tricks than the King', width: 150),
            _task("Don't win any ♥ cards", width: 150),
            _task('Win the trick after the Queen is played', width: 150),
          ],
        );
      case IntroArt.courtCards:
        return _trick([
          ('9♦', 1, '9♦ led', false),
          ('3♦', 2, '3♦ follows', false),
          ('Joker', 0, 'No ♦ left: your Joker wins', true),
        ]);
      case IntroArt.lead:
        return Column(children: [
          _trick([
            ('2♣', 0, 'You play low', false),
            ('9♣', 1, 'The Duke wins and leads next', true),
            ('4♣', 2, 'The Bishop follows', false),
          ]),
          const SizedBox(height: 10),
          _trick([
            ('7♥', 1, 'The Duke leads the 7♥', false),
            ('Jack', 0, 'No ♥: your Jack takes it', true),
            ('2♥', 2, 'The Bishop follows', false),
          ]),
        ]);
      case IntroArt.choosing:
        return FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (i, name, n) in const [(0, 'You, the King', '1st'), (1, 'Duke', '2nd'), (2, 'Bishop', '3rd')])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(children: [
                if (i == 0) const CrownIcon(size: 20) else const SizedBox(height: 15),
                _token(i, name[0] == 'Y' ? 'Y' : name[0], 46),
                _caption(name),
                _caption('picks $n', color: Palette.gold),
              ]),
            ),
        ]));
      case IntroArt.speak:
        return FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
          _token(1, 'D', 52),
          const SizedBox(width: 10),
          Column(mainAxisSize: MainAxisSize.min, children: [
            _card('7♠', width: 40, edge: Palette.players[1]),
            _caption('highest', color: Palette.gold),
          ]),
          const SizedBox(width: 22),
          const ShowCardIcon(size: 44),
        ]));
      case IntroArt.tracker:
        return Column(children: [
          const TrackerIcon(size: 48),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
            for (final (c, seat, played) in const [
              ('A♠', null, false),
              ('2♠', 2, true),
              ('3♠', null, false),
              ('4♠', 1, true),
              ('6♠', 0, false),
              ('9♠', 0, true),
            ])
              _card(c,
                  width: 40,
                  dimmed: played,
                  edge: seat == null ? null : Palette.players[seat]),
          ]),
          _caption('Played: shaded, in the player’s colour. In your hand: bright, in your colour. Still to come: plain.'),
        ]);
      case IntroArt.help:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _task('Win the A♦', owner: 0),
            _task('Win the 6♣', owner: 1),
          ],
        );
      case IntroArt.table:
        // A phone in the middle of a real table, players around it.
        Widget seat(int i, String label) => _token(i, label, 36,
            shape: Courtier.houses[i].shape);
        return SizedBox(
          width: 240,
          height: 170,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 220,
              height: 140,
              decoration: BoxDecoration(
                color: Palette.feltDeep,
                borderRadius: BorderRadius.circular(70),
                border: Border.all(color: Palette.gold, width: 2),
              ),
            ),
            Container(
              width: 46,
              height: 78,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white54, width: 2),
              ),
              alignment: Alignment.center,
              child: const CrownIcon(size: 22),
            ),
            Positioned(top: 0, child: seat(2, '3')),
            Positioned(bottom: 0, child: seat(0, '1')),
            Positioned(left: 0, child: seat(1, '2')),
            Positioned(right: 0, child: seat(3, '4')),
            Positioned(
              bottom: 30,
              right: 64,
              child: Transform.rotate(angle: 0.2, child: _card('7♠', width: 26)),
            ),
            Positioned(
              top: 30,
              left: 66,
              child: Transform.rotate(angle: -0.3, child: _card('3♥', width: 26)),
            ),
          ]),
        );
      case IntroArt.ready:
        return Column(children: [
          const CrownIcon(size: 64),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            const WaxSeal(seal: 1, size: 34),
            const Icon(Icons.history_edu_rounded, size: 34, color: Palette.gold),
          ]),
        ]);
    }
  }

  /// A trick as it lands: each card outlined in its player's colour, with
  /// what happened under it; the winner glows.
  Widget _trick(List<(String, int, String, bool)> plays) => Wrap(
        spacing: 4,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final (card, seat, words, wins) in plays)
            _labelled(_card(card, glow: wins, edge: Palette.players[seat]), words,
                color: wins ? Palette.gold : Colors.white70),
        ],
      );
}
