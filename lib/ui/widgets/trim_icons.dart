/// The icons that change with the room (skin/trim.dart): the cross that
/// closes, and the eye that peeks at the table. Each is tipped with its
/// room's mark (trim_glyphs.dart).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/skin_scope.dart';
import 'trim_glyphs.dart';

/// A cross, its arms tipped with the room's mark.
class TrimCloseIcon extends StatelessWidget {
  const TrimCloseIcon({super.key, this.size = 22, this.color});
  final double size;

  /// The skin's gold unless given.
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size.square(size),
      painter: _ClosePainter(color ?? context.skin.gold, markOf(context.skin.buttonLook.trim)));
}

class _ClosePainter extends CustomPainter {
  _ClosePainter(this.color, this.mark);
  final Color color;
  final TrimMark mark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final reach = mark == TrimMark.round ? s * 0.32 : s * 0.26;
    final line = Paint()
      ..strokeWidth = s * 0.1
      ..strokeCap = StrokeCap.round
      ..color = color;
    final fill = Paint()..color = color;
    for (final a in [math.pi / 4, 3 * math.pi / 4]) {
      final d = Offset(math.cos(a), math.sin(a)) * reach;
      canvas.drawLine(c - d, c + d, line);
      for (final end in [c - d, c + d]) {
        paintMark(canvas, mark, end + (end - c) * 0.22, s * 0.075, fill);
      }
    }
  }

  @override
  bool shouldRepaint(_ClosePainter old) => old.color != color || old.mark != mark;
}

/// An eye, its pupil the room's mark.
class TrimEyeIcon extends StatelessWidget {
  const TrimEyeIcon({super.key, this.size = 22, this.color});
  final double size;

  /// The skin's gold unless given.
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size.square(size), painter: _EyePainter(color ?? context.skin.gold, markOf(context.skin.buttonLook.trim)));
}

class _EyePainter extends CustomPainter {
  _EyePainter(this.color, this.mark);
  final Color color;
  final TrimMark mark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final lid = Path()
      ..moveTo(s * 0.06, c.dy)
      ..quadraticBezierTo(c.dx, s * 0.06, s * 0.94, c.dy)
      ..quadraticBezierTo(c.dx, s * 0.94, s * 0.06, c.dy)
      ..close();
    canvas.drawPath(
        lid,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.09
          ..strokeJoin = StrokeJoin.round
          ..color = color);
    final fill = Paint()..color = color;
    if (mark == TrimMark.round || mark == TrimMark.dot || mark == TrimMark.leaf) {
      canvas.drawCircle(c, s * 0.15, fill);
    } else {
      paintMark(canvas, mark, c, s * 0.12, fill);
    }
  }

  @override
  bool shouldRepaint(_EyePainter old) => old.color != color || old.mark != mark;
}
