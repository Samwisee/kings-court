/// The outline of each courtier’s token shape.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/courtiers.dart';

/// The outline of a courtier's token, fitted to a [size] square.
Path tokenPath(TokenShape shape, Size size) {
  final w = size.width, h = size.height;
  final c = Offset(w / 2, h / 2);
  Path polygon(int sides, double rotation, [double scale = 0.5]) {
    final p = Path();
    for (var i = 0; i < sides; i++) {
      final a = rotation + i * 2 * math.pi / sides;
      final pt = c + Offset(math.cos(a), math.sin(a)) * (w * scale);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  switch (shape) {
    case TokenShape.shield:
      return Path()
        ..moveTo(w * 0.08, h * 0.06)
        ..lineTo(w * 0.92, h * 0.06)
        ..lineTo(w * 0.92, h * 0.45)
        ..quadraticBezierTo(w * 0.9, h * 0.82, w * 0.5, h * 0.98)
        ..quadraticBezierTo(w * 0.1, h * 0.82, w * 0.08, h * 0.45)
        ..close();
    case TokenShape.arch:
      return Path()
        ..moveTo(w * 0.1, h * 0.98)
        ..lineTo(w * 0.1, h * 0.45)
        ..arcToPoint(Offset(w * 0.9, h * 0.45),
            radius: Radius.circular(w * 0.4))
        ..lineTo(w * 0.9, h * 0.98)
        ..close();
    case TokenShape.hexagon:
      return polygon(6, -math.pi / 2, 0.52);
    case TokenShape.diamond:
      return polygon(4, -math.pi / 2, 0.56);
    case TokenShape.octagon:
      return polygon(8, math.pi / 8, 0.52);
    case TokenShape.star:
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? w * 0.55 : w * 0.38;
        final a = -math.pi / 2 + i * math.pi / 5;
        final pt = c + Offset(math.cos(a), math.sin(a)) * r + Offset(0, h * 0.04);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
  }
}
