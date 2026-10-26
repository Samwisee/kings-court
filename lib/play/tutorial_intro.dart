/// The tutorial's opening pages: the story, the goal, the cards, tricks,
/// following suit, Court Cards, reading tasks and playing together, each
/// with a picture. Every page waits for Continue, so newcomers can read at
/// their own pace. Pops with true to start the lessons.
library;

import 'package:flutter/material.dart';

import '../engine/cards.dart';
import '../models.dart';
import '../theme.dart';
import '../tutorial.dart';
import '../widgets.dart';
import 'card_view.dart';

class TutorialIntro extends StatefulWidget {
  const TutorialIntro({super.key});

  @override
  State<TutorialIntro> createState() => _TutorialIntroState();
}

class _TutorialIntroState extends State<TutorialIntro> {
  int page = 0;

  bool get _last => page == introPages.length - 1;

  void _continue() =>
      _last ? Navigator.pop(context, true) : setState(() => page++);
  void _back() =>
      page == 0 ? Navigator.pop(context, false) : setState(() => page--);

  @override
  Widget build(BuildContext context) {
    final p = introPages[page];
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: Palette.felt,
      appBar: AppBar(
        backgroundColor: Palette.feltDeep,
        title: Text('How to play · ${page + 1} of ${introPages.length}',
            style: const TextStyle(fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip to the lessons'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress: one pip per page.
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Semantics(
                label: 'Page ${page + 1} of ${introPages.length}',
                excludeSemantics: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < introPages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == page ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i <= page ? Palette.gold : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: reduceMotion ? 0 : 260),
                transitionBuilder: (child, a) =>
                    FadeTransition(opacity: a, child: child),
                child: SingleChildScrollView(
                  key: ValueKey(page),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
                                    color: Palette.gold)),
                          ),
                          const SizedBox(height: 16),
                          Center(child: _art(p.art)),
                          const SizedBox(height: 18),
                          for (final para in p.paragraphs)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SuitText(para,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      height: 1.45,
                                      color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              color: Palette.feltDeep,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _back,
                        child: Text(page == 0 ? 'Cancel' : 'Back'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _continue,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(160, 52)),
                        icon: Icon(_last
                            ? Icons.play_arrow_rounded
                            : Icons.arrow_forward_rounded),
                        label: Text(_last ? 'Start lesson 1' : 'Continue'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _task(String description, {double width = 150}) {
    final task = GameState.taskPool
        .firstWhere((t) => t.description == description)
        .freshCopy();
    final size = TableCard.sizeFor(task.cardText(3), width);
    return TableCard(
        task: task,
        points: task.getPointsForPlayerCount(3),
        width: size.width,
        height: size.height);
  }

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
        return Wrap(
          spacing: 4,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _labelled(_card('4♠', edge: Palette.players[1]), 'The Duke leads the 4♠'),
            _labelled(_card('9♠', glow: true, edge: Palette.players[0]),
                'Your 9♠ is highest: you win', color: Palette.gold),
            _labelled(_card('2♠', edge: Palette.players[2]), 'The Bishop plays the 2♠'),
          ],
        );
      case IntroArt.follow:
        return Column(children: [
          _labelled(_card('6♥'), '♥ was led'),
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
      case IntroArt.courtCards:
        return Wrap(
          spacing: 4,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _labelled(_card('9♦'), '9♦ led'),
            _labelled(_card('3♦'), '3♦ follows'),
            _labelled(_card('Joker', glow: true), 'No ♦ left: the Joker wins',
                color: Palette.gold),
          ],
        );
      case IntroArt.tasks:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _task('Win the 3♥', width: 140),
            _task("Don't win any of the first three tricks", width: 140),
            _task('Win no Court Cards', width: 140),
          ],
        );
      case IntroArt.together:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (i, name) in const [(1, 'Duke'), (0, 'You'), (2, 'Bishop')])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Palette.players[i],
                  child: Text(name[0],
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: Colors.white)),
                ),
                _caption(name),
              ]),
            ),
          const Icon(Icons.handshake_rounded, size: 40, color: Palette.gold),
        ]);
      case IntroArt.lessons:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, l) in lessons.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: Palette.gold,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, color: Palette.ink)),
                  ),
                  const SizedBox(width: 10),
                  Text(l.title,
                      style: const TextStyle(
                          fontFamily: displayFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Colors.white)),
                ]),
              ),
          ],
        );
    }
  }
}
