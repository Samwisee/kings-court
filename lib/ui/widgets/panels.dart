/// Panels and dialogs: the ornate court card at each level, gold pips, and the shared dialogs.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../task_help.dart';
import '../../theme.dart';
import 'icons.dart';
import 'suit_text.dart';
import 'tokens.dart';

/// How dressed up a panel or dialog is. Everything is [low] unless it's an
/// occasion:
/// * [low]: the gradient, a faint damask and a bronze rule round it.
/// * [medium]: a curl in each corner and a crown medallion over the top
///   (the menu, a lesson or round's result, You're ready).
/// * [high]: a sheen of gold sweeps across it and stars twinkle.
enum Ornament { low, medium, high }

/// The court's panel for menus, results and dialogs: a framed card at one
/// of three [Ornament] levels. Gold for a win, dark wine for a loss, felt
/// and gold for the court ([court]).
class OrnateCard extends StatelessWidget {
  const OrnateCard(
      {super.key,
      required this.won,
      required this.child,
      this.court = false,
      this.margin = const EdgeInsets.fromLTRB(24, 46, 24, 24),
      this.padding = const EdgeInsets.fromLTRB(28, 30, 28, 18),
      this.maxWidth = 400,
      this.ornament = Ornament.low,
      this.edge});
  final bool won;

  /// A different colour for its edge (say, a player's).
  final Color? edge;

  /// How much decoration: see [Ornament].
  final Ornament ornament;

  /// The court's own colours, for menus and settings: deep felt, gold.
  final bool court;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final double maxWidth;
  final Widget child;

  /// The bronze rule inside the edge: how far in it runs, how round its
  /// corners are, how thick, and its colour on an [ink]. Something set
  /// into a corner (the card tracker's eye) follows these.
  static const ruleInset = 8.0;
  static const ruleRadius = 12.0;
  static const ruleWidth = 1.3;
  static Color ruleColour(Color ink) => ink.withValues(alpha: 0.8);

  @override
  Widget build(BuildContext context) {
    final edge = this.edge ?? (court ? Palette.gold : won ? Palette.goldInk : Palette.lost);
    final ink = won && !court ? Palette.goldInk : Palette.gold;
    return Container(
      margin: margin,
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: court
              ? const [Color(0xFF15583A), Color(0xFF0C3A25), Color(0xFF07291A)]
              : won
              ? const [Palette.goldLight, Palette.gold, Color(0xFFB98A24)]
              : const [Color(0xFF3A1218), Color(0xFF1C0A0E), Color(0xFF12080A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: edge, width: 2.5),
        boxShadow: [
          const BoxShadow(color: Colors.black54, blurRadius: 28, offset: Offset(0, 8)),
          BoxShadow(
              color: (won || court ? Palette.gold : Palette.lost)
                  .withValues(alpha: court ? 0.2 : 0.35),
              blurRadius: 40,
              spreadRadius: 2),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // A faint damask of diamonds across the panel, the double rule
          // and filigree scrolls in every corner.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(painter: _Damask(ink.withValues(alpha: 0.07))),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
                painter: _Filigree(ruleColour(ink),
                    scrolls: ornament != Ornament.low)),
          ),
          // A win glitters: a sheen sweeps the gold and stars twinkle.
          if (won && !court || ornament == Ornament.high)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: const _Glitter(),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
          // A medallion over the top edge.
          if (ornament != Ornament.low)
          Positioned(
            top: -30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: court
                        ? const [Color(0xFF1E6B47), Palette.feltDeep]
                        : won
                        ? const [Palette.goldPale, Palette.gold]
                        : const [Color(0xFF5A1A22), Color(0xFF2A0E12)],
                  ),
                  border: Border.all(color: edge, width: 2.5),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                ),
                alignment: Alignment.center,
                child: CrownIcon(size: 30, color: won && !court ? Palette.ink : Palette.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A lattice of small diamonds, very faint, like woven damask.
class _Damask extends CustomPainter {
  _Damask(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const step = 18.0;
    for (double y = 0; y < size.height + step; y += step) {
      for (var x = (y ~/ step).isOdd ? step / 2 : 0.0; x < size.width + step; x += step) {
        final path = Path()
          ..moveTo(x, y - 4)
          ..lineTo(x + 4, y)
          ..lineTo(x, y + 4)
          ..lineTo(x - 4, y)
          ..close();
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(_Damask old) => old.color != color;
}

/// The rule inside the edge, with a curl in each corner.
class _Filigree extends CustomPainter {
  _Filigree(this.color, {this.scrolls = true});
  final Color color;

  /// A curl in each corner; without it, just the rule inside the edge.
  final bool scrolls;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = OrnateCard.ruleWidth
      ..strokeCap = StrokeCap.round;
    const inset = OrnateCard.ruleInset, r = OrnateCard.ruleRadius;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
            const Radius.circular(r)),
        line);
    if (!scrolls) return;
    line.strokeWidth = 1.6;
    // A scroll in the top-left corner, mirrored into the others.
    void corner(double sx, double sy, Offset o) {
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.scale(sx, sy);
      // Just the curl: the second rule, the arc hugging the corner and
      // the gem are gone, so the corner stays quiet.
      final scroll = Path()
        ..moveTo(14, 26)
        ..cubicTo(14, 18, 18, 14, 26, 14)
        ..moveTo(26, 14)
        ..cubicTo(32, 14, 34, 20, 30, 22)
        ..cubicTo(27, 24, 24, 21, 26, 19)
        ..moveTo(14, 26)
        ..cubicTo(14, 32, 20, 34, 22, 30)
        ..cubicTo(24, 27, 21, 24, 19, 26);
      canvas.drawPath(scroll, line);
      canvas.restore();
    }

    corner(1, 1, const Offset(4, 4));
    corner(-1, 1, Offset(size.width - 4, 4));
    corner(1, -1, Offset(4, size.height - 4));
    corner(-1, -1, Offset(size.width - 4, size.height - 4));
  }

  @override
  bool shouldRepaint(_Filigree old) => old.color != color || old.scrolls != scrolls;
}

/// A rule with a gem in the middle, for under a title.
class OrnateDivider extends StatelessWidget {
  const OrnateDivider({super.key, required this.color, this.width = 180});
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget line(bool left) => Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: left
                    ? [color.withValues(alpha: 0), color]
                    : [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        );
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          line(true),
          const SizedBox(width: 6),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: 7, height: 7, color: color),
          ),
          const SizedBox(width: 4),
          CrownIcon(size: 14, color: color),
          const SizedBox(width: 4),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: 7, height: 7, color: color),
          ),
          const SizedBox(width: 6),
          line(false),
        ]),
      ),
    );
  }
}

/// The court's on/off mark: a gold ring, filled with a gold jewel when on.
/// Used for every setting in place of switches and tick boxes.
class GoldPip extends StatelessWidget {
  const GoldPip({super.key, required this.on, this.size = 22, this.enabled = true});
  final bool on;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final gold = enabled ? Palette.gold : Palette.gold.withValues(alpha: 0.4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: gold, width: 2),
        boxShadow: on && enabled
            ? [BoxShadow(color: Palette.gold.withValues(alpha: 0.45), blurRadius: 8)]
            : null,
      ),
      padding: EdgeInsets.all(size * 0.17),
      child: AnimatedScale(
        scale: on ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: [Palette.goldPale, gold]),
          ),
        ),
      ),
    );
  }
}

/// A setting with a title, a line about it, and a [GoldPip] to turn it on
/// or off (the whole line is the tap target).
class PipTile extends StatelessWidget {
  const PipTile(
      {super.key,
      required this.title,
      this.subtitle,
      required this.value,
      required this.onChanged});
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        // A faint gold wash when pressed, never a white flash.
        highlightColor: Palette.gold.withValues(alpha: 0.08),
        splashColor: Palette.gold.withValues(alpha: 0.12),
        hoverColor: Palette.gold.withValues(alpha: 0.06),
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                      child: title),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                        child: subtitle!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            GoldPip(on: value, enabled: enabled),
          ]),
        ),
      ),
    );
  }
}

/// A sheen that sweeps across a gold panel every few seconds, and small
/// four-pointed stars twinkling over it.
class _Glitter extends StatefulWidget {
  const _Glitter();

  @override
  State<_Glitter> createState() => _GlitterState();
}

class _GlitterState extends State<_Glitter> with SingleTickerProviderStateMixin {
  // One long cycle: a sheen sweeps the gold at its start, then rests,
  // while stars twinkle all the way through.
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 6500));

  /// Under the test runner nothing loops (a test waits for stillness).
  static bool get _underTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context) || !CharacterToken.alive || _underTest;
    if (_still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Its own layer: the sheen sweeps forever, and only it repaints.
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: _build(context));

  Widget _build(BuildContext context) => _still
      ? const SizedBox.shrink()
      : AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _GlitterPainter(_c.value)),
        );
}

class _GlitterPainter extends CustomPainter {
  _GlitterPainter(this.t);
  final double t;

  static const _stars = [
    (0.12, 0.18, 0.0), (0.86, 0.14, 0.35), (0.22, 0.78, 0.6), (0.78, 0.7, 0.15),
    (0.5, 0.08, 0.8), (0.93, 0.48, 0.5), (0.06, 0.5, 0.9), (0.62, 0.9, 0.25),
    (0.38, 0.3, 0.7), (0.7, 0.36, 0.05),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // The sheen: crosses in the first fifth of each cycle, then rests.
    final sweep = (t / 0.2).clamp(0.0, 1.0);
    if (sweep < 1) {
      // A soft diagonal band crossing from left to right.
      final rect = Offset.zero & size;
      final cx = -0.3 * size.width + 1.6 * size.width * Curves.easeInOut.transform(sweep);
      final band = size.width * 0.18;
      canvas.drawRect(
          rect,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(cx - band, 0),
              Offset(cx + band, size.height * 0.35),
              const [Color(0x00FFFFFF), Color(0x66FFFBE6), Color(0x00FFFFFF)],
              const [0, 0.5, 1],
            ));
    }
    // The stars, each twinkling in its own moment.
    final star = Paint()..color = const Color(0xFFFFFBEA);
    for (final (sx, sy, phase) in _stars) {
      // Each star twinkles three times a cycle, each in its own moment,
      // so there are always a few catching the light.
      final local = (((t * 3) - phase) % 1) / 0.35;
      if (local < 0 || local > 1) continue;
      final k = math.sin(local * math.pi);
      if (k <= 0) continue;
      final r = 5.0 * k;
      final c = Offset(size.width * sx, size.height * sy);
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, star..color = Color.fromRGBO(255, 251, 234, k));
    }
  }

  @override
  bool shouldRepaint(_GlitterPainter old) => old.t != t;
}

/// A dialog's edge in a player's colour with a dark line either side, like
/// a task card's outline on the table; just the dark line for nobody's.
class HighVisBorder extends RoundedRectangleBorder {
  const HighVisBorder(this.colour)
      : super(borderRadius: const BorderRadius.all(Radius.circular(24)));
  final Color? colour;

  @override
  ShapeBorder scale(double t) => this;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final r = borderRadius.resolve(textDirection).toRRect(rect);
    Paint line(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = c;
    if (colour == null) {
      canvas.drawRRect(r.deflate(1), line(outlineColour, 2));
      return;
    }
    canvas.drawRRect(r.deflate(4.5), line(colour!, 6));
    canvas.drawRRect(r.deflate(1), line(outlineColour, 2));
    canvas.drawRRect(r.deflate(8.5), line(outlineColour, 1.5));
  }
}

/// The court's ornate pop-up: the felt, gold filigree and a crown
/// medallion over the top. Every ornate dialog is one of these, so a skin
/// restyles them all at once (see [DialogStyle] and [OrnateCard]).
class CourtDialog extends StatelessWidget {
  const CourtDialog(
      {super.key,
      this.title,
      required this.child,
      this.actions = const [],
      this.maxWidth = 420,
      this.ornament = Ornament.low,
      this.align = CrossAxisAlignment.center});
  final String? title;
  final Widget child;

  /// How dressed up it is: plain by default.
  final Ornament ornament;

  /// Where its words sit: centred, or from the left for longer reading.
  final CrossAxisAlignment align;

  /// Buttons, centred under the words, the main one first.
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // No edge of its own: the panel draws its edges.
        shape: const RoundedRectangleBorder(),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: OrnateCard(
          won: false,
          court: true,
          ornament: ornament,
          maxWidth: maxWidth,
          margin: EdgeInsets.only(top: ornament == Ornament.low ? 0 : 34),
          padding: EdgeInsets.fromLTRB(
              26, ornament == Ornament.low ? 24 : 38, 26, 14),
          child: DefaultTextStyle.merge(
            style: DialogStyle.body,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  Text(title!, textAlign: TextAlign.center, style: DialogStyle.title),
                  const SizedBox(height: 12),
                ],
                Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: align,
                    children: [child]),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// What a game word means, in the court's colours.
Future<void> showTermDialog(BuildContext context, String term) => showDialog<void>(
      context: context,
      builder: (context) => CourtDialog(
        title: term,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
        child: SuitText(glossary[term] ?? '',
            keywords: false, textAlign: TextAlign.center, style: DialogStyle.body),
      ),
    );

/// The ring round whatever the arrow keys have chosen (a task, a button):
/// pale gold with a dark line outside it, drawn just outside [child] so
/// nothing moves when it comes and goes. One look for every keyboard
/// choice; a skin changes [KeyFocusRing.colour].
class KeyFocusRing extends StatelessWidget {
  const KeyFocusRing(
      {super.key, required this.on, required this.child, this.radius = 10, this.gap = 3});
  final bool on;
  final double radius;
  final double gap;
  final Widget child;

  static const colour = Palette.goldPale;

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: on ? _FocusRingPainter(radius, gap) : null,
        child: child,
      );
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter(this.radius, this.gap);
  final double radius;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(gap + 1.5), Radius.circular(radius + gap));
    canvas.drawRRect(
        r.inflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = outlineColour);
    canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = KeyFocusRing.colour);
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) => old.radius != radius || old.gap != gap;
}
