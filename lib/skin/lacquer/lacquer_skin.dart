/// Lacquer: the court at night, in red-black lacquer and gold leaf. A
/// skin made from its design alone, but for one part it draws itself:
/// the card backs, a gold crest on the lacquer.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design_skin.dart';
import '../parts.dart';

class LacquerSkin extends DesignSkin {
  const LacquerSkin() : super(lacquerDesign);

  @override
  SkinParts get parts => const SkinParts(cardBack: _back);
}

const lacquerDesign = SkinDesign(
  id: 'lacquer',
  name: 'Lacquer',
  ground: Color(0xFF0D0606),
  felt: Color(0xFF3C1013),
  feltDeep: Color(0xFF26090B),
  surface: Color(0xFF2A0B0E),
  card: Color(0xFFF7EFDF),
  ink: Color(0xFF1E1512),
  inkSoft: Color(0xFF6E5E52),
  accent: Color(0xFFDDB65E),
  accentDeep: Color(0xFFA37B2C),
  red: Color(0xFFB3122B),
  won: Color(0xFF4FA56E),
  lost: Color(0xFFE2563F),
  displayFont: 'CinzelDecorative',
  bodyFont: 'AlegreyaSans',
  finish: Finish.rich,
  // Jewel tones that hold against the red.
  cloth: [
    [Color(0xFF3E2A6E), Color(0xFF1A1033)],
    [Color(0xFF14594A), Color(0xFF07261F)],
    [Color(0xFF1F3F7A), Color(0xFF0A1733)],
    [Color(0xFF1A1414), Color(0xFF050303)],
  ],
);

/// A card's back: black lacquer, a gold rule inside the edge, and a crest
/// of rays round the crown.
Widget _back(BuildContext context, CardBackSpec spec) {
  final w = spec.width;
  return SizedBox(
    width: w,
    height: w * 1.42,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A0B0E), Color(0xFF0D0606)],
        ),
        borderRadius: BorderRadius.circular(w * 0.1),
        border: Border.all(color: lacquerDesign.accent, width: 1.6),
        boxShadow: const [
          BoxShadow(color: Color(0x73000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: CustomPaint(
        painter: _Crest(lacquerDesign.accent),
        child: Center(child: spec.kit.crown(w * 0.36)),
      ),
    ),
  );
}

class _Crest extends CustomPainter {
  const _Crest(this.gold);
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rule = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = gold.withValues(alpha: 0.6);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            (Offset.zero & size).deflate(size.width * 0.08), Radius.circular(size.width * 0.06)),
        rule);
    final ray = Paint()
      ..strokeWidth = 0.9
      ..color = gold.withValues(alpha: 0.35);
    final inner = size.width * 0.24, outer = size.width * 0.36;
    for (var k = 0; k < 24; k++) {
      final a = k * math.pi / 12;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * inner, c + d * outer, ray);
    }
    canvas.drawCircle(c, size.width * 0.22, rule);
  }

  @override
  bool shouldRepaint(_Crest old) => old.gold != gold;
}
