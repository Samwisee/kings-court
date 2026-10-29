/// What's printed over a card's back (looks.dart: [BackMotif]), and a
/// back's ground for something drawn on it: a done task.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/looks.dart';
import '../../skin/skin_scope.dart';

/// The skin's card back (its colour and motif) filling the box, under
/// [child], in corners of [radius]: what a done task turns over to show.
class BackGround extends StatelessWidget {
  const BackGround({super.key, required this.radius, this.child});
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final look = context.skin.cardLook;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: look.back,
        child: CustomPaint(
          painter: backMotifPainter(look.backMotif, look.backEdge.withValues(alpha: look.backPatternAlpha)),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

/// What draws [motif] over a card's back in [colour]; null for none.
CustomPainter? backMotifPainter(BackMotif motif, Color colour) => switch (motif) {
      BackMotif.none => null,
      BackMotif.lattice => BackLattice(colour),
      _ => _Motif(motif, colour),
    };

/// The motifs beside the lattice (looks.dart: [BackMotif]).
class _Motif extends CustomPainter {
  const _Motif(this.motif, this.colour);
  final BackMotif motif;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = Paint()
      ..color = colour
      ..strokeWidth = math.max(1.0, w / 60)
      ..style = PaintingStyle.stroke;
    switch (motif) {
      case BackMotif.stripes:
        final step = math.max(4.0, w / 9);
        for (var x = -h; x < w; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x + h, h), line);
        }
      case BackMotif.dots:
        final step = math.max(5.0, w / 7);
        final dot = Paint()..color = colour;
        for (var y = step / 2; y < h; y += step) {
          final odd = (y / step).floor().isOdd;
          for (var x = odd ? step : step / 2; x < w; x += step) {
            canvas.drawCircle(Offset(x, y), math.max(0.8, w / 40), dot);
          }
        }
      case BackMotif.rays:
        final c = Offset(w / 2, h / 2);
        final reach = math.sqrt(w * w + h * h);
        for (var k = 0; k < 24; k++) {
          final a = k * math.pi / 12;
          canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * reach, line);
        }
      case BackMotif.waves:
        final step = math.max(5.0, w / 6);
        for (var y = step / 2; y < h + step; y += step) {
          final p = Path()..moveTo(0, y);
          for (var x = 0.0; x <= w; x += step / 2) {
            p.quadraticBezierTo(x + step / 4, y + ((x / (step / 2)).round().isEven ? -step / 4 : step / 4), x + step / 2, y);
          }
          canvas.drawPath(p, line);
        }
      case BackMotif.none:
      case BackMotif.lattice:
        break;
    }
  }

  @override
  bool shouldRepaint(_Motif old) => old.motif != motif || old.colour != colour;
}

/// A fine diagonal lattice over a card's back.
class BackLattice extends CustomPainter {
  const BackLattice(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = colour
      ..strokeWidth = 1;
    final step = math.max(5.0, size.width / 7);
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
      canvas.drawLine(Offset(x + size.height, 0), Offset(x, size.height), p);
    }
  }

  @override
  bool shouldRepaint(BackLattice old) => old.colour != colour;
}

