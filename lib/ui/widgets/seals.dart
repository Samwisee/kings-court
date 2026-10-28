/// Wax seals and the decree scroll.
library;

import 'package:flutter/material.dart';

import '../../engine/decrees.dart';
import '../../skin/theme.dart';
import 'clamp.dart';
import 'icons.dart';

/// A red wax seal pressed with its order: I, II, III or Ω for last.
class WaxSeal extends StatelessWidget {
  const WaxSeal({super.key, required this.seal, this.size = 20});
  final int seal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = Seals.label(seal);
    return Tooltip(
      message: Seals.describe(seal),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFFD23A4C), Palette.cardRed, Color(0xFF7A0B1C)],
            stops: [0, 0.55, 1],
          ),
          border: Border.all(color: const Color(0xFF7A0B1C)),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w900,
                fontSize: size * (label.length > 2 ? 0.38 : 0.5),
                height: 1,
                color: const Color(0xFFFFE9C9))),
      ),
    );
  }
}

/// A royal decree, unrolled like a scroll before the deal.
class DecreeScroll extends StatelessWidget {
  const DecreeScroll(
      {super.key, required this.decree, this.detail, this.onAccept});
  final Decree decree;

  /// Extra line, e.g. who has been exiled.
  final String? detail;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(1, clampD(t, 0.02, 1.2), 1),
        child: Opacity(opacity: clampD(t * 1.5, 0, 1), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: Palette.parchment, // parchment
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Palette.goldDeep, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CrownIcon(size: 26, color: Palette.goldDeep),
            const SizedBox(height: 4),
            const Text('Royal Decree',
                style: TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Palette.inkSoft)),
            Text(decree.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    color: Palette.cardRed)),
            const SizedBox(height: 8),
            Text(decree.rule,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17, height: 1.35, color: Palette.ink)),
            if (detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(detail!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Palette.ink)),
              ),
            const SizedBox(height: 12),
            if (onAccept != null)
              FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                    backgroundColor: Palette.cardRed,
                    foregroundColor: Colors.white),
                child: const Text('So be it'),
              ),
            if (onAccept == null)
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
