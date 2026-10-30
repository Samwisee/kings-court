/// The courtiers’ living tokens: breathing, arriving, speaking, walking, and their speech bubbles.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/courtiers.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import 'clamp.dart';

/// How a character token is behaving.
enum CharacterMood {
  /// Sitting at the table: a slow, gentle breath (see [CharacterToken.alive]).
  idle,

  /// Has something to say: a little wobble and a speech bubble.
  speaking,

  /// Pleased with the King: a hop and a golden heart.
  pleased,

  /// Displeased: a shake and a red mark.
  angry,

  /// Just arrived at court: springs in, then breathes like the others.
  arriving,

  /// Leaving court: shrinks and fades.
  leaving,
}

/// Brings a courtier's token to life: [child] is the token itself.
class CharacterToken extends StatefulWidget {
  const CharacterToken({
    super.key,
    required this.child,
    this.mood = CharacterMood.idle,
    this.phase = 0,
    this.size = 40,
    this.delay = Duration.zero,
    this.entrance,
    this.exit,
  });

  final Widget child;
  final CharacterMood mood;

  /// Makes an entrance in this style, then breathes like the others.
  final Entrance? entrance;

  /// Leaves in this style (and stays gone).
  final Exit? exit;

  /// Wait this long before reacting (to take turns down a list).
  final Duration delay;

  /// Offsets the idle breath so a table of tokens doesn't move in step.
  final double phase;

  /// Roughly how big the token is, to scale the hop and the marks.
  final double size;

  /// Idle breathing on or off (off in tests, which wait for stillness).
  static bool alive = true;

  @override
  State<CharacterToken> createState() => _CharacterTokenState();
}

class _CharacterTokenState extends State<CharacterToken>
    with TickerProviderStateMixin {
  late final AnimationController _once = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: widget.entrance != null || widget.exit != null ? 1400 : 900));
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800));

  /// Whether it breathes while it sits: never now. The tokens are still
  /// between the moments they come alive (arriving, speaking, pleased,
  /// cross, leaving), so nothing on the table moves for no reason, and the
  /// screen isn't drawn again and again while it waits.
  bool get _idles => false;

  Timer? _wait;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _once.forward();
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) _once.forward();
      });
    }
    if (_idles && CharacterToken.alive) _breath.repeat();
  }

  @override
  void didUpdateWidget(CharacterToken old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _once.forward(from: 0);
      if (_idles && CharacterToken.alive) {
        if (!_breath.isAnimating) _breath.repeat();
      } else {
        _breath.stop();
      }
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _once.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // Its own layer: a breathing token repaints alone, never the table.
    // And the token within its own too: breathing only moves and scales
    // it, so it's drawn once (shadow, glow and all), not every frame.
    return RepaintBoundary(child: AnimatedBuilder(
      animation: Listenable.merge([_once, _breath]),
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        final t = _once.value;
        final b = math.sin(2 * math.pi * (_breath.value + widget.phase));
        final s = widget.size;
        var dx = 0.0, dy = 0.0, scale = 1.0, angle = 0.0, opacity = 1.0;
        IconData? mark;
        var markColor = skin.gold;
        // A white wash for ghosts, a gold halo for holy arrivals.
        var wash = 0.0, halo = 0.0;
        final e = Curves.easeOutCubic.transform(t);
        final entrance = widget.entrance, exit = widget.exit;
        if (exit != null) {
          switch (exit) {
            case Exit.dash:
              dx = t < 0.15 ? -s * 0.15 * (t / 0.15) : s * 3.5 * Curves.easeIn.transform((t - 0.15) / 0.85);
              dy = -math.sin(t * math.pi * 8).abs() * s * 0.08;
              opacity = 1 - clampD((t - 0.5) * 2, 0, 1);
            case Exit.ghost:
              dy = -s * 1.4 * Curves.easeIn.transform(t);
              dx = math.sin(t * math.pi * 3) * s * 0.12;
              wash = 0.7 * clampD(t * 2, 0, 1);
              opacity = 1 - Curves.easeIn.transform(t);
            case Exit.banished:
              if (t < 0.4) {
                dx = math.sin(t * 60) * s * 0.1;
              } else {
                final f = Curves.easeIn.transform((t - 0.4) / 0.6);
                dy = s * 1.8 * f;
                angle = 0.8 * f;
                opacity = 1 - f;
              }
              if (t < 0.4) {
                mark = Icons.gavel_rounded;
                markColor = skin.lost;
              }
            case Exit.walk:
              if (t < 0.3) {
                angle = 0.4 * math.sin(t / 0.3 * math.pi);
              } else {
                final f = (t - 0.3) / 0.7;
                dx = s * 2.6 * f;
                dy = -math.sin(f * math.pi * 6).abs() * s * 0.08;
                opacity = 1 - clampD((f - 0.5) * 2, 0, 1);
              }
            case Exit.poof:
              scale = 1 + 0.7 * t;
              opacity = 1 - Curves.easeOut.transform(t);
              mark = Icons.cloud_rounded;
              markColor = Colors.white;
          }
        } else if (entrance != null) {
          final before = t <= 0;
          switch (entrance) {
            case Entrance.march:
              dx = -s * 2.4 * (1 - e);
              dy = -math.sin(t * math.pi * 6).abs() * s * 0.1 * (1 - t);
            case Entrance.descend:
              dy = -s * 2.2 * (1 - e);
              scale = 0.6 + 0.4 * e;
              halo = math.sin(t * math.pi);
            case Entrance.stomp:
              dy = -s * 2.6 * (1 - Curves.bounceOut.transform(t));
              if (t > 0.35 && t < 0.9) {
                mark = Icons.cloud_rounded;
                markColor = Colors.white70;
              }
            case Entrance.shadow:
              opacity = clampD(e * (0.75 + 0.25 * math.sin(t * 40)), 0, 1);
              wash = 0;
              scale = 0.85 + 0.15 * e;
            case Entrance.roll:
              dx = s * 2.6 * (1 - e);
              angle = -math.pi * 4 * (1 - e);
            case Entrance.cartwheel:
              dx = -s * 2.8 * (1 - e);
              dy = -math.sin(e * math.pi) * s * 0.7;
              angle = math.pi * 4 * (1 - e);
          }
          if (before) opacity = 0;
          // Then a gentle bob: moved, never scaled, so its letter
          // stays crisp and still on it.
          if (t >= 1) dy += b * s * 0.03;
        } else {
        switch (widget.mood) {
          case CharacterMood.idle:
            dy = b * s * 0.03;
          case CharacterMood.arriving:
            scale = t >= 1 ? 1 : Curves.elasticOut.transform(t);
            opacity = clampD(t * 3, 0, 1);
            dy = b * s * 0.03;
          case CharacterMood.speaking:
            angle = math.sin(t * math.pi * 6) * 0.1 * (1 - t);
            scale = 1 + 0.08 * math.sin(t * math.pi);
            mark = Icons.chat_bubble_rounded;
            markColor = Colors.white;
          case CharacterMood.pleased:
            dy = -s * 0.28 * math.sin(t * math.pi);
            scale = 1 + 0.12 * math.sin(t * math.pi);
            mark = Icons.favorite_rounded;
          case CharacterMood.angry:
            dx = math.sin(t * math.pi * 8) * s * 0.1 * (1 - t);
            mark = Icons.priority_high_rounded;
            markColor = skin.lost;
          case CharacterMood.leaving:
            scale = 1 - 0.35 * Curves.easeIn.transform(t);
            opacity = 1 - 0.65 * t;
            dy = s * 0.1 * t;
        }
        }
        final markOpacity = mark == null ? 0.0 : math.sin(clampD(t, 0, 1) * math.pi);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (halo > 0.01)
              Container(
                width: s * 1.6,
                height: s * 1.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    skin.gold.withValues(alpha: 0.6 * halo),
                    skin.gold.withValues(alpha: 0),
                  ]),
                ),
              ),
            Opacity(
              opacity: clampD(opacity, 0, 1),
              child: Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.rotate(
                  angle: angle,
                  child: Transform.scale(
                    scale: scale,
                    child: wash > 0.01
                        ? ColorFiltered(
                            colorFilter: ColorFilter.mode(
                                Colors.white.withValues(alpha: wash),
                                BlendMode.srcATop),
                            child: child)
                        : child,
                  ),
                ),
              ),
            ),
            if (mark != null && markOpacity > 0.01)
              Positioned(
                top: -s * 0.25 - s * 0.35 * t,
                right: -s * 0.15,
                child: Opacity(
                  opacity: markOpacity,
                  child: Icon(mark, size: s * 0.45, color: markColor, shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ]),
                ),
              ),
          ],
        );
      },
    ));
  }
}

/// Words spoken at the table, in a bubble pointing back at the speaker
/// (on its left).
class SpeechBubble extends StatefulWidget {
  const SpeechBubble(this.text,
      {super.key, this.who, this.delay = Duration.zero, this.tailBelow = false, this.tailAbove = false});
  final String text;

  /// Point down at a speaker below, rather than left.
  final bool tailBelow;

  /// Point up at a speaker above.
  final bool tailAbove;

  /// Who is speaking, shown small above the words.
  final String? who;

  /// Wait this long before speaking (to take turns).
  final Duration delay;

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // A gentle rise into place: no overshoot, no flicker.
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
        );
      },
      child: CustomPaint(
        painter: _BubbleTail(skin: context.skin, below: widget.tailBelow, above: widget.tailAbove),
        child: Container(
          margin: widget.tailBelow
              ? const EdgeInsets.only(bottom: 9)
              : widget.tailAbove
                  ? const EdgeInsets.only(top: 9)
                  : const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: skin.ivory,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.who != null)
                Text(widget.who!,
                    style: TextStyle(
                        fontFamily: skin.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: skin.goldDeep)),
              Text(widget.text,
                  style: TextStyle(
                      fontSize: 16, height: 1.4, color: skin.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleTail extends CustomPainter {
  _BubbleTail({required this.skin, this.below = false, this.above = false});
  final Skin skin;
  final bool below;
  final bool above;

  @override
  void paint(Canvas canvas, Size size) {
    if (below) {
      final x = size.width / 2;
      canvas.drawPath(
          Path()
            ..moveTo(x - 9, size.height - 10)
            ..lineTo(x + 9, size.height - 10)
            ..lineTo(x, size.height)
            ..close(),
          Paint()..color = skin.ivory);
      return;
    }
    if (above) {
      final x = size.width / 2;
      canvas.drawPath(
          Path()
            ..moveTo(x - 9, 10)
            ..lineTo(x + 9, 10)
            ..lineTo(x, 0)
            ..close(),
          Paint()..color = skin.ivory);
      return;
    }
    final y = math.min(22.0, size.height / 2);
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(10, y - 7)
      ..lineTo(10, y + 7)
      ..close();
    canvas.drawPath(path, Paint()..color = skin.ivory);
  }

  @override
  bool shouldRepaint(_BubbleTail old) => old.below != below || old.above != above || old.skin != skin;
}
