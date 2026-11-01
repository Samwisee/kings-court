/// A card's back, and the pieces that show it: a card turning over, a
/// deck being shuffled.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/effects.dart';
import '../../skin/parts.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../widgets.dart';
import 'card_view.dart';

/// The back of a card, for hands you can't see and cards being dealt.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    Widget standard() => _standard(skin);
    final part = skin.parts.cardBack;
    if (part == null) return standard();
    return part(context, CardBackSpec(width: width, kit: partKit, standard: standard));
  }

  Widget _standard(Skin skin) {
    final look = skin.cardLook;
    final radius = BorderRadius.circular(width * look.radius);
    return Container(
      width: width,
      height: PlayingCardView.heightFor(width),
      decoration: BoxDecoration(
        color: look.back,
        borderRadius: radius,
        border: Border.all(color: look.backEdge, width: 1.5 + skin.outlineWidth),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: blurs ? 4 : 0, offset: Offset(0, 2)),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: skin.outlineColour, width: skin.outlineWidth),
      ),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter: backMotifPainter(look.backMotif, look.backEdge.withValues(alpha: look.backPatternAlpha)),
          foregroundPainter: look.backRule == null ? null : _BackRule(look.backRule!, width),
          child: Center(
              child: CrownIcon(
                  size: width * (look.backPattern ? 0.42 : 0.5), color: look.backCrown)),
        ),
      ),
    );
  }
}

/// A fine rule inside a card back's edge.
class _BackRule extends CustomPainter {
  const _BackRule(this.colour, this.width);
  final Color colour;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = math.max(2.5, width * 0.07);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            (Offset.zero & size).deflate(inset), Radius.circular(width * 0.05)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, width * 0.012)
          ..color = colour);
  }

  @override
  bool shouldRepaint(_BackRule old) => old.colour != colour || old.width != width;
}

/// Turns a card over: the back while [face] runs from 0 to 0.5, the front
/// after, like a card flipped on the table.
///
/// With [backFillsFront], the back is drawn at the front's size, and both
/// stay built the whole way over: the front is built once, as the flip
/// starts, rather than when it first shows mid-turn (a task card is a lot
/// to build, and a deal turns several at once), and nothing is needed just
/// to give the back the front's size. Without it, the back is its own
/// size (a card back), and only the side showing is built.
///
/// The transform stays once it's face up, as no transform at all (a plain
/// one: no perspective, which on the web can cut a card off as it's
/// drawn), so landing doesn't build the card again either.
class FlipIn extends StatelessWidget {
  const FlipIn({super.key, required this.t, required this.front, required this.back, this.backFillsFront = false});
  final double t;
  final Widget front;
  final Widget back;
  final bool backFillsFront;

  @override
  Widget build(BuildContext context) {
    final done = t >= 1;
    final angle = done ? 0.0 : (1 - t) * math.pi;
    final showBack = angle > math.pi / 2;
    final turned = Transform(alignment: Alignment.center, transform: Matrix4.identity()..rotateY(math.pi), child: back);
    return Transform(
      alignment: Alignment.center,
      transform: done
          ? Matrix4.identity()
          : (Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle)),
      child: backFillsFront
          ? Stack(children: [
              _Side(shown: !showBack, child: front),
              Positioned.fill(child: _Side(shown: showBack, child: turned)),
            ])
          : showBack
              ? turned
              : front,
    );
  }
}

/// One side of a card turning over: built and laid out all the way over,
/// drawn (and read out, and touchable) only while it's the side showing.
class _Side extends StatelessWidget {
  const _Side({required this.shown, required this.child});
  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Visibility(visible: shown, maintainState: true, maintainAnimation: true, maintainSize: true, child: child);
}

/// A deck being shuffled: the two halves part and riffle together a few
/// times. Plays once.
class ShufflingDeck extends StatelessWidget {
  const ShufflingDeck({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = PlayingCardView.heightFor(width);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, t, _) {
        // Three riffles: the halves swing apart and back.
        final phase = (t * 3) % 1;
        final apart = t >= 1 ? 0.0 : math.sin(phase * math.pi);
        return SizedBox(
          width: width * 2.6,
          height: h + 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 4; i++)
                Transform.translate(
                  offset: Offset(-apart * width * 0.7 + i * 1.5, -i * 1.5),
                  child: Transform.rotate(
                      angle: -apart * 0.18, child: CardBack(width: width)),
                ),
              for (int i = 0; i < 4; i++)
                Transform.translate(
                  offset: Offset(apart * width * 0.7 + i * 1.5,
                      -i * 1.5 - (phase < 0.5 ? 0 : 4)),
                  child: Transform.rotate(
                      angle: apart * 0.18, child: CardBack(width: width)),
                ),
            ],
          ),
        );
      },
    );
  }
}
