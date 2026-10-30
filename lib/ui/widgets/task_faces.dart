/// What's printed on a task card's face (looks.dart: [TaskLook]): a faint
/// motif over the stock, and its frame.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/looks.dart';
import 'back_motifs.dart';

/// Paints [look]'s motif and frame on a task's face. The face runs
/// [reach] beyond the box painted (the padding round the words), with
/// corners of [radius].
class TaskFacePainter extends CustomPainter {
  const TaskFacePainter(this.look, {required this.reach, this.radius = 5});
  final TaskLook look;
  final EdgeInsets reach;
  final double radius;

  /// Whether [look] prints anything at all.
  static bool prints(TaskLook look) => look.frame != TaskFrame.plain || look.motif != BackMotif.none;

  @override
  void paint(Canvas canvas, Size size) {
    final face = RRect.fromRectAndRadius(reach.inflateRect(Offset.zero & size), Radius.circular(radius));
    final rule = look.rule;
    if (backMotifPainter(look.motif, look.ink.withValues(alpha: look.motifAlpha)) case final motif?) {
      canvas.save();
      canvas.clipRRect(face);
      canvas.translate(face.left, face.top);
      motif.paint(canvas, face.outerRect.size);
      canvas.restore();
    }
    Paint line(double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = rule;
    switch (look.frame) {
      case TaskFrame.plain:
        break;
      case TaskFrame.ruled:
        canvas.drawRRect(face.deflate(2.5), line(1.2));
        canvas.drawRRect(face.deflate(4.8), line(0.6));
      case TaskFrame.corners:
        final r = face.deflate(3).outerRect;
        final l = math.min(11.0, math.min(r.width, r.height) / 3);
        final p = Path();
        for (final (c, sx, sy) in [
          (r.topLeft, 1.0, 1.0),
          (r.topRight, -1.0, 1.0),
          (r.bottomLeft, 1.0, -1.0),
          (r.bottomRight, -1.0, -1.0),
        ]) {
          p
            ..moveTo(c.dx, c.dy + sy * l)
            ..lineTo(c.dx, c.dy)
            ..lineTo(c.dx + sx * l, c.dy);
          canvas.drawCircle(c + Offset(sx * 3.2, sy * 3.2), 1.1, Paint()..color = rule);
        }
        canvas.drawPath(p, line(1.4));
      case TaskFrame.ribbon:
        canvas.save();
        canvas.clipRRect(face);
        final band = Rect.fromLTWH(face.left, face.top, face.width, 3.5);
        canvas.drawRect(band, Paint()..color = rule);
        canvas.drawLine(Offset(face.left, band.bottom + 2), Offset(face.right, band.bottom + 2),
            line(0.7)..color = rule.withValues(alpha: rule.a * 0.6));
        canvas.restore();
      case TaskFrame.stamp:
        final dot = Paint()..color = rule;
        for (final m in (Path()..addRRect(face.deflate(2.6))).computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 4) {
            canvas.drawCircle(m.getTangentForOffset(d)!.position, 0.9, dot);
          }
        }
      case TaskFrame.ledger:
        final x = face.left + 2.5;
        canvas.drawLine(Offset(x, face.top + 1), Offset(x, face.bottom - 1), line(0.9));
        canvas.drawLine(Offset(x + 2.2, face.top + 1), Offset(x + 2.2, face.bottom - 1), line(0.9));
    }
  }

  @override
  bool shouldRepaint(TaskFacePainter old) => old.look != look || old.reach != reach || old.radius != radius;
}
