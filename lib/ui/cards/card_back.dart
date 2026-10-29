/// A card's back, and the pieces that show it: a card turning over, a
/// deck being shuffled.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/looks.dart';
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
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
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
class FlipIn extends StatelessWidget {
  const FlipIn(
      {super.key, required this.t, required this.front, required this.back});
  final double t;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    // Once face up, no 3D transform at all: on the web a lingering
    // perspective layer can cut a card off as it's drawn.
    if (t >= 1) return front;
    final angle = (1 - t) * math.pi;
    final showBack = angle > math.pi / 2;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateY(angle),
      child: showBack
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: back)
          : front,
    );
  }
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
