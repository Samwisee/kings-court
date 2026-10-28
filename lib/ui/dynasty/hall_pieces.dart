/// The throne room’s pieces: the hall and throne painted behind the scene, the herald’s scroll, a choice’s button and the coffers.
library;

import 'package:flutter/material.dart';

import '../../game/courtiers.dart';
import '../../skin/theme.dart';
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

/// The herald reads the news from a scroll.
class HeraldScroll extends StatelessWidget {
  const HeraldScroll(this.text, {super.key});
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
            color: Palette.parchment,
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

class ChoiceButton extends StatelessWidget {
  const ChoiceButton(this.c, {super.key});
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
class Coffers extends StatelessWidget {
  const Coffers(this.gold, {super.key});
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
class HallPainter extends CustomPainter {
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
      for (var i = 0; i < 2; i++) {
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
  bool shouldRepaint(HallPainter old) => false;
}

/// A tall gilt throne with a crimson back.
class ThronePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Palette.goldLight, Palette.gold, Color(0xFF9C7420)],
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
  bool shouldRepaint(ThronePainter old) => false;
}
