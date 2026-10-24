import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../courtiers.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Someone in the throne room.
class HallFigure {
  const HallFigure(this.id, this.role, this.color,
      {this.enterAt = 0, this.exitAt, this.enters = false, this.name});
  final String id;

  /// Their courtier role, or null for a visitor to the court.
  final Courtier? role;
  final Color color;

  /// Make an entrance when first seen (otherwise they're simply there).
  final bool enters;

  /// What they're called, if not their courtier title.
  final String? name;

  String get label => name ?? role!.short;

  /// The line at which they walk in (0: there from the start, walking in
  /// as the scene opens).
  final int enterAt;

  /// The line at which they leave, if they do.
  final int? exitAt;
}

/// One line of the scene: spoken by a figure, or by the herald when
/// [who] is null.
class HallLine {
  const HallLine(this.text,
      {this.who, this.mood = CharacterMood.speaking, this.side = 0, this.name});
  final String text;
  final String? who;
  final CharacterMood mood;

  /// After speaking, the speaker stands on the left (-1) or right (1),
  /// by the choice they back.
  final int side;

  /// Shown above the words, if not the speaker's title.
  final String? name;
}

/// A decision beside the throne.
class HallChoice {
  const HallChoice(this.label, this.onTap,
      {this.backers = const [], this.cost = 0, this.enabled = true});
  final String label;
  final VoidCallback onTap;
  final List<HallFigure> backers;

  /// Gold it costs from the coffers.
  final int cost;
  final bool enabled;
}

/// The throne room: the court gathers, moves about and talks, the herald
/// reads the news, and you decide from the throne. Tap to hurry the talk.
class ThroneRoom extends StatefulWidget {
  const ThroneRoom({
    super.key,
    required this.title,
    required this.figures,
    required this.lines,
    required this.king,
    required this.kingName,
    required this.coffers,
    this.left,
    this.right,
    this.wounds = 0,
    this.extra,
    this.fast = false,
    this.scene = '',
  });

  /// Which scene this is: a new one starts the talk again, but the court
  /// stays where it is.
  final String scene;

  final String title;
  final List<HallFigure> figures;
  final List<HallLine> lines;

  /// Your token, for the throne.
  final Widget king;
  final String kingName;
  final int coffers;
  final int wounds;
  final HallChoice? left, right;

  /// Anything else to show once the talk is done (a scheme to settle).
  final Widget? extra;

  /// Tests: no waiting between lines.
  final bool fast;

  /// The [HallLine.who] for lines you speak yourself.
  static const kingId = 'king';

  @override
  State<ThroneRoom> createState() => _ThroneRoomState();
}

class _ThroneRoomState extends State<ThroneRoom> {
  int _line = 0;
  bool _done = false;
  Timer? _timer, _wander;
  final _sides = <String, int>{};
  final _nudge = <String, Offset>{};
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    if (widget.lines.isEmpty) {
      _done = true;
    } else {
      _schedule();
    }
    // Now and then someone shifts about the hall.
    _wander = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted || widget.figures.isEmpty) return;
      final f = widget.figures[_rand.nextInt(widget.figures.length)];
      setState(() => _nudge[f.id] = Offset(
          (_rand.nextDouble() - 0.5) * 0.08, (_rand.nextDouble() - 0.5) * 0.05));
    });
  }

  @override
  void didUpdateWidget(ThroneRoom old) {
    super.didUpdateWidget(old);
    if (old.scene != widget.scene) {
      _line = 0;
      _done = widget.lines.isEmpty;
      _sides.clear();
      if (!_done) _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wander?.cancel();
    super.dispose();
  }

  /// Each line stays until you tap; tests run through on their own.
  void _schedule() {
    _timer?.cancel();
    if (widget.fast) _timer = Timer(const Duration(milliseconds: 10), _next);
  }

  void _next() {
    if (!mounted || _done) return;
    final l = widget.lines[_line];
    if (l.who != null && l.side != 0) _sides[l.who!] = l.side;
    if (_line >= widget.lines.length - 1) {
      setState(() => _done = true);
      return;
    }
    setState(() => _line++);
    _schedule();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.feltDeep,
      child: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _done ? null : _next,
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _HallPainter())),
              // The court about the hall.
              ..._figures(w, h),
              // Who is speaking, and what they say.
              if (!_done || widget.lines.isNotEmpty) _speech(w, h),
              _header(w),
              _throne(w, h),
            ]),
          );
        }),
      ),
    );
  }

  Widget _header(double w) => Positioned(
        left: 16,
        right: 16,
        top: 8,
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.kingName,
                    style: const TextStyle(fontSize: 13, color: Colors.white60)),
                Text(widget.title,
                    maxLines: 2,
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        height: 1.1,
                        color: Palette.gold)),
              ],
            ),
          ),
          for (int i = 0; i < widget.wounds; i++)
            const Padding(
              padding: EdgeInsets.only(right: 2),
              child: Icon(Icons.water_drop, size: 16, color: Palette.lost),
            ),
          const SizedBox(width: 8),
          _Coffers(widget.coffers),
        ]),
      );

  /// Where the speaker stands: on the floor before the throne.
  Offset _floor(double w, double h) => Offset(w / 2, h * 0.6);

  List<Widget> _figures(double w, double h) {
    const size = 46.0;
    // The last to speak stays on the floor while you decide.
    final speaking = widget.lines.isEmpty
        ? null
        : widget.lines[_done ? widget.lines.length - 1 : _line].who;
    final present = [
      for (final f in widget.figures)
        if (f.enterAt <= _line || _done) f
    ];
    // Home spots in a shallow arc across the hall; those who've taken a
    // side stand by that side of the throne.
    final unsided = [for (final f in present) if (!_sides.containsKey(f.id)) f];
    final left = [for (final f in present) if (_sides[f.id] == -1) f];
    final right = [for (final f in present) if (_sides[f.id] == 1) f];
    Offset home(HallFigure f) {
      final side = _sides[f.id];
      if (side != null) {
        final group = side < 0 ? left : right;
        final i = group.indexOf(f);
        return Offset(w * (side < 0 ? 0.12 : 0.88), h * (0.64 + 0.09 * i));
      }
      final i = unsided.indexOf(f), n = unsided.length;
      final x = n == 1 ? 0.5 : 0.14 + 0.72 * i / (n - 1);
      final arc = 0.2 + 0.06 * math.pow((x - 0.5) * 2, 2);
      final nudge = _nudge[f.id] ?? Offset.zero;
      return Offset(w * (x + nudge.dx), h * (arc + nudge.dy));
    }

    return [
      for (final f in present)
        () {
          final at = f.id == speaking ? _floor(w, h) : home(f);
          final line = widget.lines.isEmpty
              ? null
              : widget.lines[_done ? widget.lines.length - 1 : _line];
          final leaving = f.exitAt != null && (_line >= f.exitAt! || _done);
          Widget token = Column(mainAxisSize: MainAxisSize.min, children: [
            _token(f, size),
            const SizedBox(height: 2),
            Text(f.label,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]);
          if (f.id == speaking && line != null) {
            token = CharacterToken(
              key: ValueKey('say-${f.id}-${_done ? widget.lines.length - 1 : _line}'),
              mood: line.mood,
              size: size,
              child: token,
            );
          }
          return AnimatedPositioned(
            key: ValueKey('fig-${f.id}'),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeInOutCubic,
            left: at.dx - 40,
            top: at.dy - size / 2,
            width: 80,
            child: CharacterToken(
              key: ValueKey('life-${f.id}-${leaving ? 'out' : 'in'}'),
              // Only newcomers make an entrance; the rest of the court
              // stays put from scene to scene.
              entrance: leaving || !f.enters
                  ? null
                  : f.role == null
                      ? Entrance.march
                      : entranceOf(f.role!),
              exit: leaving ? Exit.walk : null,
              size: size,
              phase: f.id.hashCode % 100 / 100,
              delay: Duration(
                  milliseconds: f.enters && f.enterAt == 0 && !leaving
                      ? 200 + 260 * widget.figures.indexOf(f)
                      : 0),
              child: token,
            ),
          );
        }()
    ];
  }

  Widget _token(HallFigure f, double size) => f.role == null
      // A visitor: no house, no sigil.
      ? Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: f.color,
            shape: BoxShape.circle,
            border: Border.all(color: Palette.gold, width: 2),
          ),
          child: Icon(Icons.person_rounded, size: size * 0.62, color: Colors.white),
        )
      : ShapedToken(
        shape: f.role!.shape,
        size: size,
        color: f.color,
        ring: Palette.gold,
        child: OutlinedLabel(seatLabels([Player(f.role!.title, color: f.color)]).first,
            fontSize: size * 0.36, strokeWidth: size * 0.07),
      );

  Widget _speech(double w, double h) {
    if (_done && widget.lines.isEmpty) return const SizedBox.shrink();
    final line = widget.lines[_done ? widget.lines.length - 1 : _line];
    final fig = widget.figures.where((f) => f.id == line.who).firstOrNull;
    final king = line.who == ThroneRoom.kingId;
    final floor = _floor(w, h);
    // You speak from the throne; the court from the floor before it.
    final bottom = king ? 168.0 : h - floor.dy + (fig == null ? -20 : 34);
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: Align(
          key: ValueKey('line-$_line-$_done'),
          alignment: Alignment.bottomCenter,
          child: king
              ? SpeechBubble(line.text, who: line.name ?? 'You', tailBelow: true)
              : fig == null
                  ? _HeraldScroll(line.text)
                  : SpeechBubble(line.text,
                      who: line.name ?? fig.name ?? fig.role!.title, tailBelow: true),
        ),
      ),
    );
  }

  Widget _throne(double w, double h) {
    final showChoices = _done;
    Widget slot(HallChoice? c) => Expanded(
          child: AnimatedOpacity(
            opacity: showChoices && c != null ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: IgnorePointer(
              ignoring: !showChoices || c == null,
              child: c == null ? const SizedBox(height: 90) : _ChoiceButton(c),
            ),
          ),
        );
    return Positioned(
      left: 10,
      right: 10,
      bottom: 10,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.extra != null && _done) widget.extra!,
        if (!_done)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Tap to hear more',
                style: TextStyle(fontSize: 12, color: Colors.white38)),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          slot(widget.left),
          SizedBox(
            width: 116,
            height: 130,
            child: Stack(alignment: Alignment.bottomCenter, children: [
              Positioned.fill(child: CustomPaint(painter: _ThronePainter())),
              Positioned(
                bottom: 30,
                child: !_done && widget.lines[_line].who == ThroneRoom.kingId
                    ? CharacterToken(
                        key: ValueKey('king-says-$_line'),
                        mood: CharacterMood.speaking,
                        size: 44,
                        child: widget.king)
                    : widget.king,
              ),
            ]),
          ),
          slot(widget.right),
        ]),
      ]),
    );
  }
}

/// The herald reads the news from a scroll.
class _HeraldScroll extends StatelessWidget {
  const _HeraldScroll(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(1, clampD(t, 0.05, 1.2), 1),
          child: Opacity(opacity: clampD(t * 1.5, 0, 1), child: child),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EBD2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Palette.goldDeep, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14)],
          ),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                  color: Palette.ink)),
        ),
      );
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton(this.c);
  final HallChoice c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: c.enabled ? Palette.gold : const Color(0xFF6B5A2E),
        borderRadius: BorderRadius.circular(14),
        shadowColor: Colors.black54,
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: c.enabled ? c.onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(c.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: Palette.ink)),
              if (c.cost != 0) ...[
                const SizedBox(height: 4),
                Text(
                    c.cost > 0 ? '−${c.cost} gold' : '+${-c.cost} gold',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.cost > 0 ? Palette.lost : const Color(0xFF2E6B2E))),
              ],
              if (c.backers.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 4, children: [
                  for (final b in c.backers)
                    if (b.role != null)
                    ShapedToken(
                        shape: b.role!.shape,
                        size: 20,
                        color: b.color,
                        ring: Palette.ink,
                        ringWidth: 1.5),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// The royal coffers, counting up or down when they change.
class _Coffers extends StatelessWidget {
  const _Coffers(this.gold);
  final int gold;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: gold.toDouble()),
        duration: const Duration(milliseconds: 900),
        builder: (context, v, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Palette.goldDeep),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.paid_rounded, size: 18, color: Palette.gold),
            const SizedBox(width: 5),
            Text('${v.round()}',
                style: TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: gold < 0 ? Palette.lost : Palette.gold)),
          ]),
        ),
      );
}

/// The felt of the table, become a hall: a red carpet to the throne,
/// banners, and candlelight.
class _HallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, 0.2),
            radius: 1.1,
            colors: [Palette.felt, Palette.feltDeep],
          ).createShader(Offset.zero & size));
    // The brass lines of the table, as the edge of the stage.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            (Offset.zero & size).deflate(6), const Radius.circular(18)),
        Paint()
          ..color = const Color(0x55D4A63A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // The carpet, narrowing into the distance.
    final carpet = Path()
      ..moveTo(w * 0.44, h * 0.16)
      ..lineTo(w * 0.56, h * 0.16)
      ..lineTo(w * 0.66, h)
      ..lineTo(w * 0.34, h)
      ..close();
    canvas.drawPath(carpet, Paint()..color = const Color(0xFF7A1A28));
    final trim = Paint()
      ..color = const Color(0xFFB8892B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(carpet, trim);
    // Banners down the walls.
    for (final x in [0.06, 0.94]) {
      for (int i = 0; i < 2; i++) {
        final bx = w * x, by = h * (0.12 + i * 0.22);
        final banner = Path()
          ..moveTo(bx - 12, by)
          ..lineTo(bx + 12, by)
          ..lineTo(bx + 12, by + 52)
          ..lineTo(bx, by + 42)
          ..lineTo(bx - 12, by + 52)
          ..close();
        canvas.drawPath(banner, Paint()..color = const Color(0xFF7A1A28));
        canvas.drawPath(banner, trim);
      }
    }
    // Candlelight from the throne.
    canvas.drawCircle(
        Offset(w / 2, h * 0.95),
        w * 0.6,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0x33F2C14E), Color(0x00F2C14E)])
              .createShader(
                  Rect.fromCircle(center: Offset(w / 2, h * 0.95), radius: w * 0.6)));
  }

  @override
  bool shouldRepaint(_HallPainter old) => false;
}

/// A tall gilt throne with a crimson back.
class _ThronePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF9E08C), Color(0xFFD4A63A), Color(0xFF9C7420)],
      ).createShader(Offset.zero & size);
    // Back, with a pointed crest.
    final back = Path()
      ..moveTo(w * 0.18, h * 0.85)
      ..lineTo(w * 0.18, h * 0.2)
      ..lineTo(w * 0.35, h * 0.1)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w * 0.65, h * 0.1)
      ..lineTo(w * 0.82, h * 0.2)
      ..lineTo(w * 0.82, h * 0.85)
      ..close();
    canvas.drawPath(back, gold);
    canvas.drawRRect(
        RRect.fromLTRBR(w * 0.26, h * 0.2, w * 0.74, h * 0.8, const Radius.circular(10)),
        Paint()..color = const Color(0xFF8B1A2B));
    // Arms and seat.
    canvas.drawRRect(
        RRect.fromLTRBR(w * 0.04, h * 0.58, w * 0.22, h * 0.92, const Radius.circular(6)),
        gold);
    canvas.drawRRect(
        RRect.fromLTRBR(w * 0.78, h * 0.58, w * 0.96, h * 0.92, const Radius.circular(6)),
        gold);
    canvas.drawRRect(
        RRect.fromLTRBR(w * 0.12, h * 0.8, w * 0.88, h, const Radius.circular(6)), gold);
  }

  @override
  bool shouldRepaint(_ThronePainter old) => false;
}
