/// Panels and dialogs: the ornate court card at each level, gold pips, and the shared dialogs.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/task_help.dart';
import '../../skin/looks.dart';
import '../../skin/parts.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import 'court_dialog.dart';
import 'felt_patterns.dart';
import 'icons.dart';
import 'pips.dart';
import 'suit_text.dart';

export '../../skin/looks.dart' show Ornament;

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
    final skin = context.skin;
    Widget standard() =>
        skin.panelLook.style == PanelStyle.ornate ? _ornate(skin) : _flat(skin);
    final part = skin.parts.panel;
    if (part == null) return standard();
    return part(
        context,
        PanelSpec(
            won: won,
            court: court,
            ornament: ornament,
            edge: edge,
            margin: margin,
            padding: padding,
            maxWidth: maxWidth,
            kit: partKit,
            standard: standard,
            child: child));
  }

  /// A flat card: the ground, a fine edge, a soft shadow, and on an
  /// occasion a band of colour along the top.
  Widget _flat(Skin skin) {
    final look = skin.panelLook;
    final edge = this.edge ??
        (court ? skin.gold.withValues(alpha: 0.35) : won ? skin.goldDeep : skin.lost);
    final band = court ? look.courtMedallion : won ? look.wonMedallion : look.lostMedallion;
    return Container(
      margin: margin,
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: court ? look.court : won ? look.won : look.lost,
        ),
        borderRadius: BorderRadius.circular(look.radius),
        border: Border.all(color: edge, width: look.edgeWidth),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          if (ornament != Ornament.low)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(look.radius - look.edgeWidth)),
                child: Container(height: 5, color: band.first),
              ),
            ),
          if (court && skin.tableLook.pattern != FeltPattern.none)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(look.radius - look.edgeWidth),
                child: RepaintBoundary(child: CustomPaint(painter: _feltOn(skin, look.court.first))),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  /// What's worked into [skin]'s felt, smaller and fainter, on a panel's
  /// [ground]: the menus and dialogs dressed like the table.
  static CustomPainter _feltOn(Skin skin, Color ground) {
    final t = skin.tableLook;
    return FeltPatternPainter(t.pattern, t.patternColour.withValues(alpha: t.patternColour.a * 0.6),
        ground: ground, scale: 0.75);
  }

  Widget _ornate(Skin skin) {
    final look = skin.panelLook;
    final edge = this.edge ?? (court ? skin.gold : won ? skin.goldInk : skin.lost);
    final ink = won && !court ? skin.goldInk : skin.gold;
    return Container(
      margin: margin,
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: court
              ? look.court
              : won
              ? look.won
              : look.lost,
        ),
        borderRadius: BorderRadius.circular(look.radius),
        border: Border.all(color: edge, width: look.edgeWidth),
        boxShadow: [
          const BoxShadow(color: Colors.black54, blurRadius: 28, offset: Offset(0, 8)),
          BoxShadow(
              color: (won || court ? skin.gold : skin.lost)
                  .withValues(alpha: court ? 0.2 : 0.35),
              blurRadius: 40,
              spreadRadius: 2),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // A faint damask of diamonds across the panel (or, in the
          // court's colours, what's worked into the skin's felt), the double
          // rule and filigree scrolls in every corner.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(look.radius - 2),
              child: RepaintBoundary(
                  child: CustomPaint(
                      painter: court && skin.tableLook.pattern != FeltPattern.none
                          ? _feltOn(skin, look.court[1])
                          : _Damask(ink.withValues(alpha: 0.07)))),
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
                  borderRadius: BorderRadius.circular(look.radius - 2),
                  child: const Glitter(),
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
                        ? look.courtMedallion
                        : won
                        ? look.wonMedallion
                        : look.lostMedallion,
                  ),
                  border: Border.all(color: edge, width: 2.5),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                ),
                alignment: Alignment.center,
                child: CrownIcon(size: 30, color: won && !court ? skin.ink : skin.gold),
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
            keywords: false, textAlign: TextAlign.center, style: context.skin.dialogBody),
      ),
    );
