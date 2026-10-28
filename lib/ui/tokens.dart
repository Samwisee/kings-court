// Seat tokens and the courtiers’ living tokens: breathing, arriving, speaking, walking.
part of '../widgets.dart';

/// A player's seat: a coloured token with their seat number or initials.
/// The King's seat gets a gold ring and a crown. During play the token
/// also carries a trick tally and the player's speaking token, and glows
/// when it is that player's turn to pick a task.
class SeatToken extends StatelessWidget {
  const SeatToken({
    super.key,
    required this.player,
    this.label,
    this.isKing = false,
    this.size = 48,
    this.highlighted = false,
    this.prompting = false,
    this.picking = false,
    this.exiled = false,
    this.speakLocked = false,
    this.shape,
    this.antagonist = false,
    this.wounds,
    this.powerUsed,
    this.loyalty,
    this.spoke,
    this.onTap,
    this.tight = false,
  });

  /// Drop the space under the token (for a label right beneath it).
  final bool tight;

  final Player player;

  /// Seat number or initials shown on the token; see [seatLabels].
  final String? label;
  final bool isKing;
  final double size;

  /// A task card is hovering over this seat and can be dropped here.
  final bool highlighted;

  /// The table is waiting for someone to tap a seat (choosing the King).
  final bool prompting;

  /// It is this player's turn to pick a task.
  final bool picking;

  /// Banished by royal decree: takes no tasks this round.
  final bool exiled;

  /// A decree forbids card reveals right now.
  final bool speakLocked;

  /// The courtier's token outline; a plain circle when null.
  final TokenShape? shape;

  /// Dynasty: this courtier has openly turned against the King.
  final bool antagonist;

  /// Dynasty: wounds the King has taken (shown by the crown).
  final int? wounds;

  /// Dynasty: whether the courtier's power is spent this round (hidden
  /// when null).
  final bool? powerUsed;

  /// Dynasty: loyalty to the crown, shown as a candle (hidden when null).
  final int? loyalty;

  /// Whether the player has used their card reveal; hidden when null.
  final bool? spoke;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = label ??
        (player.name.trim().isEmpty ? '?' : player.name.trim()[0].toUpperCase());
    final ring = isKing || highlighted || picking
        ? Palette.gold
        : prompting
            ? Colors.white70
            : Palette.feltDeep;
    final badge = clampD(size * 0.46, 20, 26);

    final labelText = OutlinedLabel(initial,
        fontSize: size * (initial.length > 1 ? 0.36 : 0.46),
        strokeWidth: size * 0.07);
    final ringColor = antagonist ? Palette.lost : ring;
    final ringWidth = isKing || highlighted || picking || antagonist ? 3.0 : 2.0;
    final fill = antagonist
        ? Color.lerp(player.color, Palette.traitor, 0.55)!
        : player.color;
    final Widget token = shape == null
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: ringWidth),
              boxShadow: [
                if (highlighted)
                  const BoxShadow(color: Palette.gold, blurRadius: 14)
                else
                  const BoxShadow(
                      color: Colors.black38,
                      blurRadius: 4,
                      offset: Offset(0, 2)),
              ],
            ),
            // A thin dark line inside the ring.
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: outlineColour, width: 1.3),
              ),
              child: labelText,
            ),
          )
        : ShapedToken(
            shape: shape!,
            size: size,
            color: fill,
            ring: ringColor,
            ringWidth: ringWidth,
            glow: highlighted,
            child: labelText,
          );

    return Semantics(
      button: onTap != null,
      label: [
        isKing ? '${player.name}, the King' : player.name,
        if (spoke == true) 'card reveal used',
        if (picking) 'picking a task',
        if (exiled) 'exiled',
        if (antagonist) 'against the King',
      ].join(', '),
      excludeSemantics: true,
      child: AnimatedScale(
        scale: highlighted ? 1.18 : 1,
        duration: const Duration(milliseconds: 150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 14,
              child: isKing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CrownIcon(size: 18),
                        // Wounds taken; how many the King can bear is secret.
                        for (int w = 0; w < (wounds ?? 0); w++)
                          const Padding(
                            padding: EdgeInsets.only(left: 1),
                            child: Icon(Icons.water_drop,
                                size: 12, color: Palette.lost),
                          ),
                      ],
                    )
                  : exiled
                      ? const Icon(Icons.block, size: 14, color: Palette.lost)
                      : antagonist
                          ? const Icon(Icons.dangerous,
                              size: 15, color: Palette.lost)
                          : null,
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: size + badge,
              height: size + badge * 0.4,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  if (picking)
                    Positioned(
                      top: 0,
                      child: PulseRing(size: size),
                    ),
                  AnimatedOpacity(
                    opacity: exiled ? 0.4 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: token,
                  ),
                  if (loyalty != null)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: LoyaltyCandle(loyalty: loyalty!, size: badge),
                    ),
                  if (powerUsed != null)
                    Positioned(
                      right: 0,
                      top: -4,
                      child: _PowerBadge(used: powerUsed!, size: badge),
                    ),
                  if (spoke != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: SpeakToken(
                          used: spoke!, locked: speakLocked, size: badge),
                    ),
                  // The whole seat is one button: badges included.
                  Positioned.fill(
                    child: MouseRegion(cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click, child: GestureDetector(
                      onTap: onTap,
                      behavior: HitTestBehavior.opaque,
                    )),
                  ),
                ],
              ),
            ),
            // Matches the crown's slot so the token sits on the seat's
            // centre.
            if (!tight) SizedBox(height: 16 - badge * 0.4),
          ],
        ),
      ),
    );
  }
}

/// A gold ring that breathes around the seat whose turn it is to pick.
class PulseRing extends StatefulWidget {
  const PulseRing({super.key, required this.size});
  final double size;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  /// Pulses a few times to catch the eye, then rests; the seat's gold ring
  /// keeps showing whose turn it is.
  static const _pulses = 5;
  int _done = 0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && ++_done < _pulses) {
        _c.forward(from: 0);
      }
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_done >= _pulses) return const SizedBox.shrink();
          final t = Curves.easeOut.transform(_c.value);
          return Transform.scale(
            scale: 1 + t * 0.45,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Palette.gold.withAlpha((230 * (1 - t)).round()),
                  width: 3,
                ),
              ),
            ),
          );
        },
      )),
    );
  }
}

/// A courtier's loyalty as a candle: the flame burns taller the more loyal
/// they are and gutters out at nothing. It flickers when loyalty changes,
/// so the table notices without being told a number.
class LoyaltyCandle extends StatelessWidget {
  const LoyaltyCandle(
      {super.key, required this.loyalty, required this.size, this.badge = true});
  final int loyalty;
  final double size;

  /// Drawn on a round dark badge (on the seat) or bare (in a dialog).
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final candle = TweenAnimationBuilder<double>(
      // A new key restarts the flicker every time loyalty changes.
      key: ValueKey(loyalty),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, t, _) => CustomPaint(
        size: Size.square(size),
        painter: _CandlePainter(loyalty: loyalty, flicker: t),
      ),
    );
    if (!badge) return candle;
    return Tooltip(
      message: 'Loyalty to the crown',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.ink,
          border: Border.all(
              color: loyalty <= 0 ? Palette.lost : const Color(0x88D4A63A),
              width: 1.5),
        ),
        child: candle,
      ),
    );
  }
}

/// Five candles for a courtier's loyalty, lit up to their level.
class LoyaltyCandles extends StatelessWidget {
  const LoyaltyCandles({super.key, required this.loyalty, this.size = 22});
  final int loyalty;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          CustomPaint(
            size: Size(size * 0.8, size),
            painter: _CandlePainter(loyalty: i < loyalty ? 4 : 0, flicker: 1),
          ),
      ],
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({required this.loyalty, required this.flicker});
  final int loyalty;

  /// 0 to 1 through the flicker after a change; 1 is steady.
  final double flicker;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final bodyW = w * 0.26;
    final bodyTop = h * 0.56;
    final bodyBottom = h * 0.84;
    canvas.drawRRect(
        RRect.fromLTRBR(cx - bodyW / 2, bodyTop, cx + bodyW / 2, bodyBottom,
            Radius.circular(bodyW * 0.2)),
        Paint()..color = Palette.card);
    canvas.drawLine(Offset(cx, bodyTop), Offset(cx, bodyTop - h * 0.05),
        Paint()
          ..color = Palette.inkSoft
          ..strokeWidth = math.max(1.0, w * 0.03));
    if (loyalty <= 0) {
      // Snuffed: a curl of smoke.
      final smoke = Path()
        ..moveTo(cx, bodyTop - h * 0.06)
        ..quadraticBezierTo(cx - w * 0.1, bodyTop - h * 0.18, cx, bodyTop - h * 0.28)
        ..quadraticBezierTo(cx + w * 0.1, bodyTop - h * 0.36, cx, bodyTop - h * 0.44);
      canvas.drawPath(
          smoke,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, w * 0.04)
            ..color = Colors.white38);
      return;
    }
    final level = (loyalty.clamp(1, 5)) / 5;
    final wobble = 1 + 0.3 * math.sin(flicker * math.pi * 9) * (1 - flicker);
    final flameH = h * (0.14 + 0.26 * level) * wobble;
    final flameW = w * (0.13 + 0.07 * level);
    final base = Offset(cx, bodyTop - h * 0.04);
    final color = Color.lerp(const Color(0xFFB4541C), Palette.gold, level)!;
    // Glow, brighter while flickering.
    canvas.drawCircle(
        base.translate(0, -flameH * 0.45),
        flameH * (0.7 + 0.5 * (1 - flicker)),
        Paint()
          ..color = color.withValues(alpha: 0.18 + 0.25 * (1 - flicker))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    final flame = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(base.dx - flameW, base.dy - flameH * 0.35,
          base.dx, base.dy - flameH)
      ..quadraticBezierTo(
          base.dx + flameW, base.dy - flameH * 0.35, base.dx, base.dy)
      ..close();
    canvas.drawPath(flame, Paint()..color = color);
    canvas.drawCircle(base.translate(0, -flameH * 0.25), flameW * 0.35,
        Paint()..color = Colors.white70);
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.loyalty != loyalty || old.flicker != flicker;
}

/// The once-per-round speaking token. It flips over when the player has
/// shown a card.
class SpeakToken extends StatelessWidget {
  const SpeakToken(
      {super.key, required this.used, this.locked = false, required this.size});
  final bool used;

  /// Reveals are forbidden by decree right now.
  final bool locked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: locked
          ? 'No card reveals allowed yet'
          : used
              ? 'Card reveal used'
              : 'Card reveal available',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: used ? math.pi : 0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        builder: (context, angle, _) {
          final back = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(angle),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: back || locked ? const Color(0xFF55524C) : Palette.card,
                border: Border.all(
                    color: back || locked ? Colors.white38 : Palette.gold,
                    width: 1.5),
              ),
              child: Icon(
                locked
                    ? Icons.lock_outline
                    : back
                        ? Icons.voice_over_off
                        : Icons.record_voice_over,
                size: size * 0.6,
                color: back || locked ? Colors.white54 : Palette.ink,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A seat token in its courtier's shape: filled with the seat colour, with
/// a ring, a shadow and an optional gold glow.
class ShapedToken extends StatelessWidget {
  const ShapedToken({
    super.key,
    required this.shape,
    required this.size,
    required this.color,
    required this.ring,
    this.ringWidth = 2,
    this.glow = false,
    this.child,
  });

  final TokenShape shape;
  final double size;
  final Color color;
  final Color ring;
  final double ringWidth;
  final bool glow;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TokenPainter(shape, color, ring, ringWidth, glow),
        child: Center(child: child),
      ),
    );
  }
}

class _TokenPainter extends CustomPainter {
  _TokenPainter(this.shape, this.color, this.ring, this.ringWidth, this.glow);
  final TokenShape shape;
  final Color color;
  final Color ring;
  final double ringWidth;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = tokenPath(shape, size);
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Palette.gold
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
    // A thin dark line just inside the ring, between it and the token's
    // colour, so a gold (or white) ring stands out from both.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth + 2.6
        ..strokeJoin = StrokeJoin.round
        ..color = outlineColour,
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeJoin = StrokeJoin.round
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_TokenPainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.ring != ring ||
      old.ringWidth != ringWidth ||
      old.glow != glow;
}

/// A courtier's power: a gold bolt while it's ready, dimmed once used.
class _PowerBadge extends StatelessWidget {
  const _PowerBadge({required this.used, required this.size});
  final bool used;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: used ? const Color(0xFF55524C) : Palette.ink,
        border: Border.all(
            color: used ? Colors.white38 : Palette.gold, width: 1.5),
      ),
      child: Icon(Icons.bolt_rounded,
          size: size * 0.7, color: used ? Colors.white38 : Palette.gold),
    );
  }
}

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

  bool get _idles =>
      widget.exit == null &&
      (widget.entrance != null ||
          widget.mood == CharacterMood.idle ||
          widget.mood == CharacterMood.arriving);

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
    // Its own layer: a breathing token repaints alone, never the table.
    return RepaintBoundary(child: AnimatedBuilder(
      animation: Listenable.merge([_once, _breath]),
      child: widget.child,
      builder: (context, child) {
        final t = _once.value;
        final b = math.sin(2 * math.pi * (_breath.value + widget.phase));
        final s = widget.size;
        var dx = 0.0, dy = 0.0, scale = 1.0, angle = 0.0, opacity = 1.0;
        IconData? mark;
        Color markColor = Palette.gold;
        // A white wash for ghosts, a gold halo for holy arrivals.
        var wash = 0.0, halo = 0.0;
        final e = Curves.easeOutCubic.transform(t);
        final entrance = widget.entrance, exit = widget.exit;
        if (exit != null) {
          switch (exit) {
            case Exit.dash:
              dx = t < 0.15 ? -s * 0.15 * (t / 0.15) : s * 3.5 * Curves.easeIn.transform((t - 0.15) / 0.85);
              dy = -(math.sin(t * math.pi * 8)).abs() * s * 0.08;
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
                markColor = Palette.lost;
              }
            case Exit.walk:
              if (t < 0.3) {
                angle = 0.4 * math.sin(t / 0.3 * math.pi);
              } else {
                final f = (t - 0.3) / 0.7;
                dx = s * 2.6 * f;
                dy = -(math.sin(f * math.pi * 6)).abs() * s * 0.08;
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
              dy = -(math.sin(t * math.pi * 6)).abs() * s * 0.1 * (1 - t);
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
          if (t >= 1) {
            dy += b * s * 0.03;
            scale *= 1 + 0.015 * b;
          }
        } else {
        switch (widget.mood) {
          case CharacterMood.idle:
            dy = b * s * 0.03;
            scale = 1 + 0.015 * b;
          case CharacterMood.arriving:
            scale = Curves.elasticOut.transform(t) + 0.015 * b;
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
            markColor = Palette.lost;
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
                    Palette.gold.withValues(alpha: 0.6 * halo),
                    Palette.gold.withValues(alpha: 0),
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
        painter: _BubbleTail(below: widget.tailBelow, above: widget.tailAbove),
        child: Container(
          margin: widget.tailBelow
              ? const EdgeInsets.only(bottom: 9)
              : widget.tailAbove
                  ? const EdgeInsets.only(top: 9)
                  : const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: Palette.ivory,
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
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Palette.goldDeep)),
              Text(widget.text,
                  style: const TextStyle(
                      fontSize: 16, height: 1.4, color: Palette.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleTail extends CustomPainter {
  _BubbleTail({this.below = false, this.above = false});
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
          Paint()..color = Palette.ivory);
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
          Paint()..color = Palette.ivory);
      return;
    }
    final y = math.min(22.0, size.height / 2);
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(10, y - 7)
      ..lineTo(10, y + 7)
      ..close();
    canvas.drawPath(path, Paint()..color = Palette.ivory);
  }

  @override
  bool shouldRepaint(_BubbleTail old) => old.below != below || old.above != above;
}

/// Glides [child] from wherever it was last laid out to where it is now,
/// so a courtier changing places walks there instead of jumping. Give it
/// a key that follows the courtier.
class SlideToPlace extends StatefulWidget {
  const SlideToPlace(
      {super.key, required this.child, this.hop = true, this.within, this.enabled = true});
  final Widget child;

  /// Off: stays put, however the layout moves.
  final bool enabled;

  /// A little hop in each step, for walking courtiers.
  final bool hop;

  /// Only moves within this ancestor count (so the whole thing scrolling
  /// or shifting doesn't set it gliding).
  final GlobalKey? within;

  @override
  State<SlideToPlace> createState() => _SlideToPlaceState();
}

class _SlideToPlaceState extends State<SlideToPlace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  Offset? _last;
  Offset _from = Offset.zero;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _measure(_) {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final anchor = widget.within?.currentContext?.findRenderObject();
    final now = box.localToGlobal(Offset.zero,
        ancestor: anchor is RenderBox && anchor.attached ? anchor : null);
    final last = _last;
    _last = now;
    if (last == null || !widget.enabled) return;
    final moved = last - now;
    if (moved.distance > 2) {
      // Start from where it appeared to be, mid-glide or not.
      final showing = _from * (1 - Curves.easeInOutCubic.transform(_c.value));
      _from = moved + showing;
      _c.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(_c.value);
        final off = _c.isAnimating || _c.value < 1 ? _from * (1 - t) : Offset.zero;
        // A little hop in each step as they walk.
        final hop = widget.hop && _c.isAnimating
            ? -(math.sin(t * math.pi * 4)).abs() * 4
            : 0.0;
        return Transform.translate(offset: off + Offset(0, hop), child: child);
      },
    );
  }
}
