/// The shared dialogs: the court’s dialog, the high-visibility border a task’s close-up wears, and the keyboard focus ring.
library;

import 'package:flutter/material.dart';

import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../../skin/theme.dart';
import 'panels.dart';

/// A dialog's edge in a player's colour with a dark line either side, like
/// a task card's outline on the table; just the dark line for nobody's.
class HighVisBorder extends RoundedRectangleBorder {
  const HighVisBorder(this.colour, this.skin)
      : super(borderRadius: const BorderRadius.all(Radius.circular(24)));
  final Skin skin;
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
      canvas.drawRRect(r.deflate(1), line(skin.outlineColour, 2));
      return;
    }
    canvas.drawRRect(r.deflate(4.5), line(colour!, 6));
    canvas.drawRRect(r.deflate(1), line(skin.outlineColour, 2));
    canvas.drawRRect(r.deflate(8.5), line(skin.outlineColour, 1.5));
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
            style: context.skin.dialogBody,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  Text(title!, textAlign: TextAlign.center, style: context.skin.dialogTitle),
                  const SizedBox(height: 12),
                ],
                // The words scroll when there isn't room (a phone with its
                // keyboard up), so the title and the buttons stay in view.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: align,
                        children: [child]),
                  ),
                ),
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

/// The ring round whatever the arrow keys have chosen (a task, a button):
/// pale gold with a dark line outside it, drawn just outside [child] so
/// nothing moves when it comes and goes. One look for every keyboard
/// choice, in the skin's pale gold.
class KeyFocusRing extends StatelessWidget {
  const KeyFocusRing(
      {super.key, required this.on, required this.child, this.radius = 10, this.gap = 3});
  final bool on;
  final double radius;
  final double gap;
  final Widget child;


  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: on ? _FocusRingPainter(radius, gap, context.skin) : null,
        child: child,
      );
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter(this.radius, this.gap, this.skin);
  final Skin skin;
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
          ..color = skin.outlineColour);
    canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = skin.goldPale);
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) => old.radius != radius || old.gap != gap || old.skin != skin;
}
