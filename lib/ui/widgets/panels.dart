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
          // An occasion's band along the top, unless the room marks its
          // panels in their corners instead.
          if (ornament != Ornament.low && look.corners == PanelCorners.none)
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
          // The room's mark in the corners, inside a fine rule.
          if (look.corners != PanelCorners.none)
            Positioned.fill(
              child: CustomPaint(
                  painter: _Filigree((court ? skin.gold : edge).withValues(alpha: 0.55),
                      corners: look.corners)),
            ),
          if (court && skin.tableLook.pattern != FeltPattern.none)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(look.radius - look.edgeWidth),
                child: RepaintBoundary(
                    child: CustomPaint(painter: _feltOn(skin, look.court.first), size: Size.infinite)),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  /// What's worked into [skin]'s felt, smaller, muted and softened, on a
  /// panel's [ground]: the menus and dialogs dressed like the table.
  static CustomPainter _feltOn(Skin skin, Color ground) {
    final t = skin.tableLook;
    return FeltPatternPainter(t.pattern, t.patternColour.withValues(alpha: t.patternColour.a * 0.35),
        ground: ground, scale: 0.75, soft: true);
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
                  child: court && skin.tableLook.pattern != FeltPattern.none
                      ? CustomPaint(painter: _feltOn(skin, look.court[1]), size: Size.infinite)
                      : CustomPaint(painter: _Damask(ink.withValues(alpha: 0.07)))),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
                painter: _Filigree(ruleColour(ink),
                    scrolls: ornament != Ornament.low, corners: look.corners)),
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

/// The rule inside the edge, with the room's mark in each corner
/// ([PanelCorners]): the court's curl of filigree (only on an occasion),
/// or another room's, always.
class _Filigree extends CustomPainter {
  _Filigree(this.color, {this.scrolls = true, this.corners = PanelCorners.scrolls});
  final Color color;

  /// The court's curls (on an occasion); without them, just the rule.
  final bool scrolls;
  final PanelCorners corners;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = OrnateCard.ruleWidth
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;
    const inset = OrnateCard.ruleInset, r = OrnateCard.ruleRadius;
    final rule = RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2), const Radius.circular(r));
    if (corners != PanelCorners.fans) canvas.drawRRect(rule, line);
    if (corners == PanelCorners.none || corners == PanelCorners.scrolls && !scrolls) return;

    // Along the rule.
    switch (corners) {
      case PanelCorners.studs:
        final m = (Path()..addRRect(rule)).computeMetrics();
        for (final pm in m) {
          for (var d = 0.0; d < pm.length; d += 22) {
            final p = pm.getTangentForOffset(d)!.position;
            canvas.drawCircle(p, 2.2, fill);
            canvas.drawCircle(p.translate(-0.6, -0.6), 0.8, Paint()..color = Colors.white.withValues(alpha: 0.35));
          }
        }
        return;
      case PanelCorners.tooled:
        canvas.drawRRect(rule.deflate(4), line..strokeWidth = 0.8);
        final m = (Path()..addRRect(rule.deflate(2))).computeMetrics();
        for (final pm in m) {
          for (var d = 0.0; d < pm.length; d += 9) {
            canvas.drawCircle(pm.getTangentForOffset(d)!.position, 0.8, fill);
          }
        }
        line.strokeWidth = OrnateCard.ruleWidth;
      case PanelCorners.fans:
        // The rule stepped in at each corner.
        const s = 8.0;
        final b = rule.outerRect;
        final p = Path()
          ..moveTo(b.left + 2 * s, b.top)
          ..lineTo(b.right - 2 * s, b.top)
          ..lineTo(b.right - 2 * s, b.top + s)
          ..lineTo(b.right - s, b.top + s)
          ..lineTo(b.right - s, b.top + 2 * s)
          ..lineTo(b.right, b.top + 2 * s)
          ..lineTo(b.right, b.bottom - 2 * s)
          ..lineTo(b.right - s, b.bottom - 2 * s)
          ..lineTo(b.right - s, b.bottom - s)
          ..lineTo(b.right - 2 * s, b.bottom - s)
          ..lineTo(b.right - 2 * s, b.bottom)
          ..lineTo(b.left + 2 * s, b.bottom)
          ..lineTo(b.left + 2 * s, b.bottom - s)
          ..lineTo(b.left + s, b.bottom - s)
          ..lineTo(b.left + s, b.bottom - 2 * s)
          ..lineTo(b.left, b.bottom - 2 * s)
          ..lineTo(b.left, b.top + 2 * s)
          ..lineTo(b.left + s, b.top + 2 * s)
          ..lineTo(b.left + s, b.top + s)
          ..lineTo(b.left + 2 * s, b.top + s)
          ..close();
        canvas.drawPath(p, line);
      default:
        break;
    }

    // In each corner, drawn for the top left and mirrored.
    void corner(double sx, double sy, Offset o) {
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.scale(sx, sy);
      switch (corners) {
        case PanelCorners.scrolls:
          line.strokeWidth = 1.6;
          canvas.drawPath(
              Path()
                ..moveTo(14, 26)
                ..cubicTo(14, 18, 18, 14, 26, 14)
                ..moveTo(26, 14)
                ..cubicTo(32, 14, 34, 20, 30, 22)
                ..cubicTo(27, 24, 24, 21, 26, 19)
                ..moveTo(14, 26)
                ..cubicTo(14, 32, 20, 34, 22, 30)
                ..cubicTo(24, 27, 21, 24, 19, 26),
              line);
        case PanelCorners.fans:
          const c = Offset(14, 14);
          for (var k = 1; k <= 3; k++) {
            canvas.drawArc(Rect.fromCircle(center: c, radius: k * 7.0), 0, math.pi / 2, false, line..strokeWidth = 1);
          }
          for (var k = 0; k <= 4; k++) {
            final a = k * math.pi / 8;
            canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * 7, c + Offset(math.cos(a), math.sin(a)) * 21, line);
          }
        case PanelCorners.tooled:
          canvas.drawPath(
              Path()
                ..moveTo(16, 16)
                ..cubicTo(26, 18, 28, 26, 22, 30)
                ..cubicTo(16, 26, 14, 20, 16, 16)
                ..moveTo(16, 16)
                ..cubicTo(18, 26, 26, 28, 30, 22),
              line..strokeWidth = 1.2);
          canvas.drawCircle(const Offset(15, 15), 1.8, fill);
        case PanelCorners.stars:
          _star(canvas, const Offset(20, 20), 6, fill);
          canvas.drawCircle(const Offset(34, 16), 1.3, fill);
          canvas.drawCircle(const Offset(16, 34), 1.0, fill);
          canvas.drawLine(const Offset(20, 20), const Offset(34, 16), line..strokeWidth = 0.6);
        case PanelCorners.compass:
          const c = Offset(20, 20);
          _star(canvas, c, 8, fill);
          for (var k = 0; k < 4; k++) {
            final a = k * math.pi / 2 + math.pi / 4;
            canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * 3, c + Offset(math.cos(a), math.sin(a)) * 6,
                line..strokeWidth = 1);
          }
          canvas.drawCircle(c, 10, line..strokeWidth = 0.8);
        case PanelCorners.leaves:
          for (var k = 0; k < 3; k++) {
            canvas.save();
            canvas.translate(14, 14);
            canvas.rotate(math.pi / 4 + (k - 1) * 0.6);
            canvas.drawOval(const Rect.fromLTWH(-2.5, 3, 5, 13), fill);
            canvas.restore();
          }
        case PanelCorners.brackets:
          canvas.drawPath(
              Path()
                ..moveTo(14, 30)
                ..lineTo(14, 14)
                ..lineTo(30, 14),
              line..strokeWidth = 1.6);
        case PanelCorners.damask:
          canvas.save();
          canvas.translate(22, 22);
          for (var k = 0; k < 4; k++) {
            canvas.rotate(math.pi / 2);
            canvas.drawPath(
                Path()
                  ..moveTo(0, -2)
                  ..cubicTo(-4, -6, -3, -11, 0, -12)
                  ..cubicTo(3, -11, 4, -6, 0, -2),
                fill);
          }
          canvas.restore();
        case PanelCorners.chequer:
          for (var y = 0; y < 3; y++) {
            for (var x = 0; x < 3; x++) {
              if ((x + y).isEven) canvas.drawRect(Rect.fromLTWH(13 + x * 5.0, 13 + y * 5.0, 5, 5), fill);
            }
          }
        case PanelCorners.lozenge:
          canvas.drawPath(
              Path()
                ..moveTo(20, 11)
                ..lineTo(27, 20)
                ..lineTo(20, 29)
                ..lineTo(13, 20)
                ..close(),
              line..strokeWidth = 1.2);
          canvas.drawCircle(const Offset(20, 20), 2, fill);
        case PanelCorners.none:
        case PanelCorners.studs:
          break;
      }
      canvas.restore();
    }

    corner(1, 1, const Offset(4, 4));
    corner(-1, 1, Offset(size.width - 4, 4));
    corner(1, -1, Offset(4, size.height - 4));
    corner(-1, -1, Offset(size.width - 4, size.height - 4));
  }

  static void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_Filigree old) =>
      old.color != color || old.scrolls != scrolls || old.corners != corners;
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
