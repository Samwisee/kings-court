/// The front page: the Court Cards fanning out, the crowned title and its sparks.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../play/card_view.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../overlays/crowning.dart';

/// The opening flourish on the front page: the four Court Cards rise and
/// fan out wide, with a burst of sparks. It plays once (about two seconds)
/// and then holds still.
class WelcomeIntro extends StatefulWidget {
  const WelcomeIntro({super.key, required this.crownSize, required this.buttons});
  final double crownSize;

  /// The front page's buttons, which fade in one after another.
  final List<Widget> buttons;

  @override
  State<WelcomeIntro> createState() => _WelcomeIntroState();
}

class _WelcomeIntroState extends State<WelcomeIntro> {
  /// The very first time, the flourish waits for the loading crown to fade
  /// away, so it isn't spent behind it.
  static bool _firstShow = true;
  late final double _wait;

  @override
  void initState() {
    super.initState();
    _wait = _firstShow &&
            CharacterToken.alive &&
            !WidgetsBinding.instance.runtimeType.toString().contains('Test')
        ? 0.35
        : 0;
    _firstShow = false;
  }

  double get crownSize => widget.crownSize;
  List<Widget> get buttons => widget.buttons;

  /// The four Court Cards, lowest to highest.
  static const _cards = [
    PlayingCard.joker,
    PlayingCard.jack,
    PlayingCard.queen,
    PlayingCard.king,
  ];

  static double _iv(double t, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final stageW = crownSize * 2;
    final cardW = crownSize * 0.6;
    final cardH = PlayingCardView.heightFor(cardW);
    // Room above the cards for the outer ones to tilt up.
    final handTop = cardH * 0.12;
    final stageH = handTop + cardH + 10;
    // With reduced motion asked for, the flourish is skipped.
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: Duration(milliseconds: (2400 / (1 - _wait)).round()),
      builder: (context, raw, _) {
        final t = _wait == 0 ? raw : clampD((raw - _wait) / (1 - _wait), 0, 1);
        final rise = _iv(t, 0.0, 0.3, Curves.easeOutCubic);
        final fan = _iv(t, 0.1, 0.5, Curves.easeOutBack);
        final spark = _iv(t, 0.35, 0.75);
        final title = _iv(t, 0.5, 0.75, Curves.easeOutCubic);
        final sub = _iv(t, 0.62, 0.85, Curves.easeOutCubic);
        // Each button a beat after the one above it.
        double btn(int i) => _iv(t, 0.7 + 0.15 * i, 0.85 + 0.15 * i, Curves.easeOutCubic);
        final mid = (_cards.length - 1) / 2;
        // On a phone the fan closes up a little, clear of the screen's edges.
        final narrow = crownSize < 200;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: stageW,
              height: stageH,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Sparks behind the cards as they fan out.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: spark > 0 && spark < 1
                            ? IntroSparks(
                                origin: Offset(stageW / 2, handTop + cardH * 0.45),
                                progress: spark,
                                scale: crownSize / 100)
                            : null,
                      ),
                    ),
                  ),
                  // The four Court Cards, fanned wide so each one's art shows.
                  for (int i = 0; i < _cards.length; i++)
                    Positioned(
                      left: stageW / 2 - cardW / 2 + (i - mid) * cardW * (narrow ? 0.6 : 0.7) * fan,
                      top: handTop + (1 - rise) * 40 + ((i - mid).abs() * cardH * 0.05) * fan,
                      child: Opacity(
                        opacity: rise,
                        child: Transform.rotate(
                          angle: (i - mid) * 0.13 * fan,
                          alignment: const Alignment(0, 1.6),
                          child: PlayingCardView(card: _cards[i], width: cardW),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            Opacity(
              opacity: title,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - title)),
                child: const _CrownedTitle(),
              ),
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: sub,
              child: const Text(
                  'A cooperative trick-taking game for 2 to 6 players.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.white70, shadows: feltShadow)),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, b) in buttons.indexed) ...[
                    if (i > 0) const SizedBox(height: 12),
                    IgnorePointer(
                      ignoring: btn(i) < 0.5,
                      child: Opacity(
                        opacity: btn(i),
                        child: Transform.translate(
                            offset: Offset(0, 12 * (1 - btn(i))), child: b),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A clip [extra] wider on the right than the box it wraps.
class ReachRight extends CustomClipper<Rect> {
  const ReachRight(this.extra);
  final double extra;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, -40, size.width + extra, size.height + 40);

  @override
  bool shouldReclip(ReachRight old) => old.extra != extra;
}

/// The game's name, with a little crown over the I of King's.
class _CrownedTitle extends StatelessWidget {
  const _CrownedTitle();

  static const _style = TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w900,
      fontSize: 44,
      height: 1.05,
      color: Palette.gold,
      shadows: [Shadow(color: Colors.black54, blurRadius: 12)]);

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(style: _style, children: [
        const TextSpan(text: 'The K'),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              const Text('i', style: _style),
              // Just over the I, a hair left of the glyph's box to sit on
              // its stroke, with the same soft shadow as the letters.
              Positioned(
                top: -_style.fontSize! * 0.36,
                left: -_style.fontSize! * 0.3 + _style.fontSize! * 0.045,
                right: -_style.fontSize! * 0.3,
                child: Center(
                  child: Stack(clipBehavior: Clip.none, children: [
                    ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: CrownIcon(
                          size: _style.fontSize! * 0.5, color: Colors.black54),
                    ),
                    CrownIcon(size: _style.fontSize! * 0.5),
                  ]),
                ),
              ),
            ],
          ),
        ),
        const TextSpan(text: "ng's Court"),
      ]),
      semanticsLabel: "The King's Court",
      textAlign: TextAlign.center,
    );
  }
}
