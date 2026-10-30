/// What's printed round a playing card's face (looks.dart: [FaceFrame]).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/looks.dart';

/// What's printed round a card's face, inside its edge ([FaceFrame]), in
/// [colour], for a card [width] wide.
class FaceFramePainter extends CustomPainter {
  const FaceFramePainter(this.frame, this.colour, this.width);
  final FaceFrame frame;
  final Color colour;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final u = width / 60;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, 1.1 * u)
      ..color = colour;
    final inset = 4.5 * u;
    final box = (Offset.zero & size).deflate(inset);
    final rr = RRect.fromRectAndRadius(box, Radius.circular(3 * u));
    switch (frame) {
      case FaceFrame.none:
        break;
      case FaceFrame.rule:
        canvas.drawRRect(rr, line);
      case FaceFrame.double:
        canvas.drawRRect(rr, line);
        canvas.drawRRect(rr.deflate(2.2 * u), line..strokeWidth = math.max(0.5, 0.6 * u));
      case FaceFrame.corners:
        final l = 10 * u;
        final p = Path();
        for (final (c, sx, sy) in [
          (box.topLeft, 1.0, 1.0),
          (box.topRight, -1.0, 1.0),
          (box.bottomLeft, 1.0, -1.0),
          (box.bottomRight, -1.0, -1.0),
        ]) {
          p
            ..moveTo(c.dx, c.dy + sy * l)
            ..lineTo(c.dx, c.dy)
            ..lineTo(c.dx + sx * l, c.dy)
            ..moveTo(c.dx + sx * 2.5 * u, c.dy + sy * l * 0.7)
            ..quadraticBezierTo(c.dx + sx * 2.5 * u, c.dy + sy * 2.5 * u, c.dx + sx * l * 0.7, c.dy + sy * 2.5 * u);
        }
        canvas.drawPath(p, line);
      case FaceFrame.deco:
        // A rule stepped in twice at each corner, and a fan in the bottom one.
        final s = 3.2 * u;
        final p = Path()
          ..moveTo(box.left + 2 * s, box.top)
          ..lineTo(box.right - 2 * s, box.top)
          ..lineTo(box.right - 2 * s, box.top + s)
          ..lineTo(box.right - s, box.top + s)
          ..lineTo(box.right - s, box.top + 2 * s)
          ..lineTo(box.right, box.top + 2 * s)
          ..lineTo(box.right, box.bottom - 2 * s)
          ..lineTo(box.right - s, box.bottom - 2 * s)
          ..lineTo(box.right - s, box.bottom - s)
          ..lineTo(box.right - 2 * s, box.bottom - s)
          ..lineTo(box.right - 2 * s, box.bottom)
          ..lineTo(box.left + 2 * s, box.bottom)
          ..lineTo(box.left + 2 * s, box.bottom - s)
          ..lineTo(box.left + s, box.bottom - s)
          ..lineTo(box.left + s, box.bottom - 2 * s)
          ..lineTo(box.left, box.bottom - 2 * s)
          ..lineTo(box.left, box.top + 2 * s)
          ..lineTo(box.left + s, box.top + 2 * s)
          ..lineTo(box.left + s, box.top + s)
          ..lineTo(box.left + 2 * s, box.top + s)
          ..close();
        canvas.drawPath(p, line);
        final c = Offset(box.center.dx, box.bottom - 1.5 * s);
        for (var k = 1; k <= 3; k++) {
          canvas.drawArc(Rect.fromCircle(center: c, radius: k * 2.6 * u), math.pi, math.pi, false,
              line..strokeWidth = math.max(0.5, 0.7 * u));
        }
      case FaceFrame.leaves:
        canvas.drawRRect(rr, line..strokeWidth = math.max(0.5, 0.7 * u));
        final leaf = Paint()..color = colour;
        for (final (c, a) in [(box.topRight, 2.4), (box.bottomLeft, -0.75)]) {
          for (var k = 0; k < 3; k++) {
            canvas.save();
            canvas.translate(c.dx, c.dy);
            canvas.rotate(a + (k - 1) * 0.55);
            canvas.drawOval(Rect.fromLTWH(-1.6 * u, 1.5 * u, 3.2 * u, 7 * u), leaf);
            canvas.restore();
          }
        }
    }
  }

  @override
  bool shouldRepaint(FaceFramePainter old) => old.frame != frame || old.colour != colour || old.width != width;
}

/// The arch round a Court Card's emblem in [colour], with a stone under
/// it, for a card [width] wide: the tarot's window instead of the plain
/// frame.
class ArchFrame extends CustomPainter {
  const ArchFrame(this.colour, this.width);
  final Color colour;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final u = width / 60;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, 1.2 * u)
      ..color = colour;
    Path arch(double inset) {
      final b = (Offset.zero & size).deflate(inset);
      final r = b.width / 2;
      return Path()
        ..moveTo(b.left, b.bottom)
        ..lineTo(b.left, b.top + r)
        ..arcToPoint(Offset(b.right, b.top + r), radius: Radius.circular(r))
        ..lineTo(b.right, b.bottom)
        ..close();
    }

    canvas.drawPath(arch(5 * u), line);
    canvas.drawPath(arch(7.5 * u), line..strokeWidth = math.max(0.5, 0.6 * u));
    // A keystone at the top, and a sill under the emblem.
    final top = Offset(size.width / 2, 5 * u);
    canvas.drawCircle(top, 1.6 * u, Paint()..color = colour);
    final sill = size.height - 14 * u;
    canvas.drawLine(Offset(8 * u, sill), Offset(size.width - 8 * u, sill), line..strokeWidth = math.max(0.5, 0.8 * u));
  }

  @override
  bool shouldRepaint(ArchFrame old) => old.colour != colour || old.width != width;
}
