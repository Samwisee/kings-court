import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../skin/court/emblems.g.dart';
import '../../skin/looks.dart';
import '../../skin/parts.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../../skin/theme.dart';
import '../widgets.dart';
import 'face_frame.dart';

export 'card_back.dart';

/// A playing card drawn on screen. Plain suits show their pip. Each Court
/// Card has a face of its own, all framed in gold: the Joker's jester cap
/// on harlequin purple, the Jack's sword and inset shield on striped
/// emerald, the Queen's tiara on a sapphire lattice, and the King's crown
/// in rays on crimson. The emblems and cloths are the printed deck's
/// (tool/print), so the cards on screen and in the box match.
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    required this.card,
    required this.width,
    this.dimmed = false,
    this.glow = false,
    this.edge,
    this.marks = const [],
  });

  final PlayingCard card;
  final double width;

  /// Not playable right now: shaded (but never see-through).
  final bool dimmed;

  /// Won the trick.
  final bool glow;

  /// A coloured border, such as the colour of the player who played it.
  final Color? edge;

  /// Colours of the players whose tasks need this card.
  final List<Color> marks;

  static double heightFor(double width) => width * 1.42;

  bool get _isKing => card == PlayingCard.king;

  /// The ink of its rank and suit: the suit's colour.
  Color _inkColour(Skin skin) => skin.suitColour(card.suit);

  /// What's woven into this Court Card's cloth, and in what: its own
  /// pattern from the Court Cards chosen, or else its own art (a
  /// harlequin, stripes, a lattice, a sunburst), in the style's cloths.
  (FeltPattern, Color)? _art(Skin skin) {
    final look = skin.cardLook;
    final patterns = look.courtPatterns;
    if (patterns == null || patterns.length < 4) return null;
    return (patterns[card.rank - 1], look.courtInk ?? skin.gold.withValues(alpha: 0.4));
  }

  // Its own layer: the emblems are costly to draw, so a card is drawn once and kept while things move around it.
  @override
  Widget build(BuildContext context) {
    final part = context.skin.parts.cardFace;
    Widget standard() => _build(context);
    return RepaintBoundary(
        child: part == null
            ? standard()
            : part(
                context,
                CardFaceSpec(
                    card: card,
                    width: width,
                    dimmed: dimmed,
                    glow: glow,
                    edge: edge,
                    marks: marks,
                    kit: partKit,
                    standard: standard)));
  }

  Widget _build(BuildContext context) {
    final skin = context.skin;
    final look = skin.cardLook;
    // A Court Card's cloth (its emblem on it), or the card stock with the
    // card's letter in its colours.
    // Every Court Card is full art: its emblem on its cloth.
    final cloth = card.isCourt;
    final h = heightFor(width);
    final outer = width * (card.isCourt ? look.courtRadius ?? look.radius : look.radius);
    final r = BorderRadius.circular(outer - skin.outlineWidth);
    final corner = TextStyle(
        // The faces chosen print the number cards; the Court Cards keep the
        // skin's own lettering.
        fontFamily: card.isCourt ? skin.displayFont : look.faceFont ?? skin.bodyFont,
        fontWeight: FontWeight.w900,
        fontSize: width * (card.isCourt ? 0.3 : 0.26),
        height: 1,
        color: _inkColour(skin));
    final borderColour = edge ??
        (marks.isNotEmpty
            ? marks.first
            : glow
                ? skin.gold
                : cloth
                    ? skin.gold
                    : card.isCourt
                    ? look.cloth[card.rank - 1][0]
                    // Number cards keep the same band in their own white,
                    // so their lines sit where a player's colour would.
                    : skin.card);
    final thick = glow || edge != null || marks.isNotEmpty || card.isCourt;
    // A player's colour (or the gold of a suggested card) round the edge:
    // dark lines touch it on both sides, so it reads against anything.
    final coloured = glow || edge != null || marks.isNotEmpty;
    final borderWidth = thick || !card.isCourt ? 3.0 : 2.0;

    return Semantics(
      label: card.spoken,
      value: dimmed ? 'can’t be played now' : glow ? 'suggested' : null,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: h,
        child: InkOutline(
        radius: outer,
        shadows: [
          if (glow)
            BoxShadow(color: skin.gold, blurRadius: 14)
          else if (marks.isNotEmpty)
            BoxShadow(color: marks.first.withValues(alpha: 0.85), blurRadius: 10)
          else if (_isKing)
            BoxShadow(color: skin.gold.withValues(alpha: 0x88 / 255), blurRadius: 8)
          else
            const BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
        child: Container(
        decoration: BoxDecoration(
          color: cloth ? null : skin.card,
          gradient: cloth
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: look.cloth[card.rank - 1])
              : null,
          borderRadius: r,
          border: Border.all(color: borderColour, width: borderWidth),
        ),
        foregroundDecoration: dimmed
            ? BoxDecoration(color: const Color(0x66000000), borderRadius: r)
            : null,
        child: Stack(
          children: [
            // Each Court Card's cloth has its own pattern.
            if (cloth)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: r,
                  child: CustomPaint(
                      // A face's own art woven into every cloth, or each
                      // card's own pattern.
                      painter: _art(skin) != null
                          ? FeltPatternPainter(_art(skin)!.$1, _art(skin)!.$2,
                              ground: look.cloth[card.rank - 1][1], scale: width / 200)
                          : switch (card.rank) {
                              1 => _Harlequin(),
                              2 => _Stripes(),
                              3 => _Lattice(),
                              _ => _Sunburst(),
                            }),
                ),
              ),
            // (The Stack already sits inside the coloured border, so the
            // line goes right at its edge, touching the colour.)
            if (coloured || !cloth)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                          math.max(0.0, outer - skin.outlineWidth - borderWidth)),
                      border: Border.all(color: skin.outlineColour, width: skin.outlineWidth),
                    ),
                  ),
                ),
              ),
            // Every card has an inner frame, as on the printed deck: gold
            // on the Court Cards, a fine dark rule on the rest (unless a
            // player's colour is already framed in dark).
            if (cloth && look.courtArch)
              Positioned.fill(child: CustomPaint(painter: ArchFrame(look.courtFrame, width)))
            else if (cloth)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.all(width * 0.06),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.06),
                  border: Border.all(color: look.courtFrame),
                ),
              ),
            ),
            // On the card stock: anything printed over it, and its frame.
            if (!cloth && look.faceMotif != BackMotif.none)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: r,
                  child: CustomPaint(
                      painter: backMotifPainter(
                          look.faceMotif, _inkColour(skin).withValues(alpha: look.faceMotifAlpha))),
                ),
              ),
            if (!cloth && look.faceFrame != FaceFrame.none)
              Positioned.fill(
                child: CustomPaint(
                    painter: FaceFramePainter(look.faceFrame,
                        look.faceFrameColour ?? _inkColour(skin).withValues(alpha: 0.35), width)),
              ),
            if (cloth)
              Positioned.fill(
                child: CustomPaint(painter: _Emblem(card.rank, look.cloth[card.rank - 1][0])),
              )
            else
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: width * 0.18),
                  child: _face(skin),
                ),
              ),
            Positioned(
              left: width * 0.09,
              top: width * 0.08,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(card.rankLabel, style: corner),
                  // Court Cards are their own suit: no pip in the corner.
                  if (!card.isCourt)
                    Padding(
                      padding: EdgeInsets.only(top: width * 0.02),
                      child: SuitIcon(card.suit,
                          size: width * 0.18, color: corner.color ?? _inkColour(skin)),
                    ),
                ],
              ),
            ),
            // Flags for whoever needs this card, under the corner, where
            // they show even when the next card in a hand covers the rest.
            if (marks.isNotEmpty)
              Positioned(
                left: width * 0.06,
                top: width * 0.6,
                child: Column(
                  children: [
                    for (final m in marks)
                      Container(
                        width: width * 0.2,
                        height: width * 0.2,
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: m,
                          shape: BoxShape.circle,
                          border: Border.all(color: skin.ink, width: 1.2),
                        ),
                        child: Icon(Icons.flag_rounded,
                            size: width * 0.13, color: Colors.white),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  /// A number card's middle, as the faces say ([PipStyle]).
  Widget _face(Skin skin) {
    final ink = _inkColour(skin);
    return switch (skin.cardLook.pips) {
      PipStyle.large => SuitIcon(card.suit, size: width * 0.44, color: ink),
      PipStyle.medallion => Container(
          width: width * 0.56,
          height: width * 0.56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ink.withValues(alpha: 0.12),
            border: Border.all(color: ink.withValues(alpha: 0.45), width: math.max(1, width * 0.02)),
          ),
          alignment: Alignment.center,
          child: SuitIcon(card.suit, size: width * 0.32, color: ink),
        ),
      PipStyle.rank => Column(mainAxisSize: MainAxisSize.min, children: [
          Text(card.rankLabel,
              style: TextStyle(
                  fontFamily: skin.cardLook.faceFont ?? skin.displayFont,
                  fontWeight: FontWeight.w900,
                  fontSize: width * 0.5,
                  height: 0.95,
                  color: ink)),
          SuitIcon(card.suit, size: width * 0.18, color: ink),
        ]),
    };
  }
}

// The emblems' gold: the court skin's art (skin/court).
const _goldLight = Color(0xFFF9E08C);
const _goldMid = Color(0xFFD4A63A);

/// The printed card is 63 mm wide; the app's card is [width] wide. Sizes
/// below are the printed deck's, in millimetres, scaled to the card.
double _mm(Size size) => size.width / 63;

/// A Court Card's emblem, placed as on the printed card (a touch larger,
/// to read at a glance in a hand).
class _Emblem extends CustomPainter {
  _Emblem(this.rank, this.cloth);

  final int rank;
  final Color cloth;

  static const _grow = 1.15;

  @override
  void paint(Canvas canvas, Size size) {
    final mm = _mm(size) * _grow;
    final (bounds, anchor, box, draw) = switch (rank) {
      1 => (jesterBounds, jesterAnchor, emblemBox, paintJester),
      2 => (jackBounds, jackAnchor, jackBox, paintJack),
      3 => (tiaraBounds, tiaraAnchor, emblemBox, paintTiara),
      _ => (kingBounds, kingAnchor, kingBox, paintKing),
    };
    final s = math.min(box.width * mm / bounds.width, box.height * mm / bounds.height);
    // The outline is the same weight whatever the emblem's scale, and never
    // thinner than a hairline.
    final ow = 2 * math.max(0.8, outlineMm * _mm(size)) / s;
    final centre = Offset(size.width / 2, size.height / 2 + size.width * 0.06);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(s);
    canvas.translate(-anchor.dx, -anchor.dy);
    // On its own layer: the Jack's inset shield is a window to the cloth.
    canvas.saveLayer(bounds.inflate(ow * 2), Paint());
    draw(canvas, ow, cloth);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Emblem old) => old.rank != rank || old.cloth != cloth;
}

/// The Joker's cloth: a field of diamonds.
class _Harlequin extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dw = size.width / 4, dh = size.height / 5;
    final dark = Paint()..color = const Color(0x381A0C2A);
    final light = Paint()..color = const Color(0x14F9E08C);
    for (var row = -1; row <= 5; row++) {
      for (var col = -1; col <= 4; col++) {
        final cx = col * dw + (row.isOdd ? dw / 2 : 0);
        final cy = row * dh;
        final p = Path()
          ..moveTo(cx, cy - dh / 2)
          ..lineTo(cx + dw / 2, cy)
          ..lineTo(cx, cy + dh / 2)
          ..lineTo(cx - dw / 2, cy)
          ..close();
        canvas.drawPath(p, (row + col).isEven ? dark : light);
      }
    }
  }

  @override
  bool shouldRepaint(_Harlequin old) => false;
}

/// The King's cloth: ten rays from the crown, lit ones faint white (the
/// Jack's stripes' white at the edges, brighter at the crown) edged in fine
/// gold, a dark one running straight down; and a soft halo behind the crown.
class _Sunburst extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mm = _mm(size);
    final c = Offset(size.width / 2, 46.8 * mm);
    final r = size.longestSide * 1.5;
    const n = 10;
    const step = 2 * math.pi / n;
    const half = step * 0.3 / 2;
    final fade = const RadialGradient(
      colors: [Color(0x42FFFFFF), Color(0x12FFFFFF), Color(0x12FFFFFF)],
      stops: [0, 0.5, 1],
    ).createShader(Rect.fromCircle(center: c, radius: 50.8 * mm));
    final edge = Paint()
      ..color = _goldLight.withValues(alpha: 0.7)
      ..strokeWidth = math.max(0.6, 0.26 * mm);
    for (var i = 0; i < n; i++) {
      final a = i * step + math.pi / 2 + step / 2;
      final p1 = c + Offset(math.cos(a - half), math.sin(a - half)) * r;
      final p2 = c + Offset(math.cos(a + half), math.sin(a + half)) * r;
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(p1.dx, p1.dy)
            ..lineTo(p2.dx, p2.dy)
            ..close(),
          Paint()..shader = fade);
    }
    final glow = Offset(c.dx, c.dy - 4.7 * mm);
    canvas.drawCircle(
        glow,
        23.5 * mm,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)])
              .createShader(Rect.fromCircle(center: glow, radius: 23.5 * mm)));
    for (var i = 0; i < n; i++) {
      final a = i * step + math.pi / 2 + step / 2;
      for (final e in [a - half, a + half]) {
        canvas.drawLine(c, c + Offset(math.cos(e), math.sin(e)) * r, edge);
      }
    }
  }

  @override
  bool shouldRepaint(_Sunburst old) => false;
}

/// The Jack's cloth: fine diagonal stripes in faint white.
class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x12FFFFFF)
      ..strokeWidth = size.width * 0.05;
    for (var x = -size.height; x < size.width; x += size.width * 0.16) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Stripes old) => false;
}

/// The Queen's cloth: a soft glow behind the tiara, and a lattice of fine
/// gold lines with a gold pearl on every crossing, one crossing at the
/// card's centre.
class _Lattice extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mm = _mm(size);
    final glow = Offset(size.width / 2, 43.1 * mm);
    canvas.drawCircle(
        glow,
        24.8 * mm,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x21FFFFFF), Color(0x00FFFFFF)])
              .createShader(Rect.fromCircle(center: glow, radius: 24.8 * mm)));
    final step = 22.83 * mm;
    final c = size.center(Offset.zero);
    final line = Paint()
      ..color = _goldLight.withValues(alpha: 0.5)
      ..strokeWidth = math.max(0.6, 0.18 * mm);
    final pearl = Paint()..color = _goldMid;
    final reach = size.width + size.height;
    final k = (reach / step).ceil();
    for (var i = -k; i <= k; i++) {
      // lines x - y = c.dx - c.dy + i step, and x + y = c.dx + c.dy + i step
      final a = c.dx - c.dy + i * step;
      final b = c.dx + c.dy + i * step;
      canvas.drawLine(Offset(a - 1, -1), Offset(a + size.height + 1, size.height + 1), line);
      canvas.drawLine(Offset(b + 1, -1), Offset(b - size.height - 1, size.height + 1), line);
    }
    for (var i = -k; i <= k; i++) {
      for (var j = -k; j <= k; j++) {
        final a = c.dx - c.dy + i * step;
        final b = c.dx + c.dy + j * step;
        final p = Offset((a + b) / 2, (b - a) / 2);
        if (p.dx >= -2 && p.dx <= size.width + 2 && p.dy >= -2 && p.dy <= size.height + 2) {
          canvas.drawCircle(p, math.max(1.0, 0.5 * mm), pearl);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Lattice old) => false;
}
