/// The table itself: its red rim and brass inlay, sparks, confetti and the masonry layout.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../skin/looks.dart';
import '../../skin/parts.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import 'felt_patterns.dart';

/// The felt set into a royal-red table: round the edge of the screen the
/// table shows, then a thin double brass rule where the felt begins, like
/// the inlay on a card table.
class TableTrim extends StatelessWidget {
  const TableTrim({super.key, this.table = true});

  /// The table round the felt as well as the brass; without it, just the
  /// brass rules (for a panel set on the felt, like the card tracker).
  final bool table;

  /// How much of the table shows round the felt.
  static const rim = 7.0;

  /// The brass rules' thickness: the outer one where the felt begins, and
  /// the fainter one inside it.
  static const outerRule = 2.5;
  static const innerRule = 1.6;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    Widget standard() => _standard(skin);
    final part = skin.parts.table;
    if (part != null) return part(context, TableSpec(table: table, standard: standard));
    return standard();
  }

  Widget _standard(Skin skin) {
    final look = skin.tableLook;
    if (table) return CustomPaint(painter: _TablePainter(skin), size: Size.infinite);
    final outer = look.panelRule;
    final inner = look.panelInnerRule;
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(look.radius),
        border: outer == null ? null : Border.all(color: outer, width: outerRule),
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(math.max(0, look.radius - 4)),
          border: inner == null ? null : Border.all(color: inner, width: innerRule),
        ),
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
  const _TablePainter(this.skin);
  final Skin skin;

  @override
  void paint(Canvas canvas, Size size) {
    final look = skin.tableLook;
    final all = Offset.zero & size;
    // The rules sit where the felt meets the table, and 3px inside.
    final felt = RRect.fromRectAndRadius(all.deflate(look.rim), Radius.circular(look.radius));
    final table = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(all)
      ..addRRect(felt);

    // The felt is sunk a little into the table: a soft shadow just inside
    // its edge. Drawn as a few fading strokes rather than a blur: a blur
    // across the whole screen's edge was the dearest thing in every frame.
    if (look.sunk) {
      canvas.save();
      canvas.clipRRect(felt);
      const steps = 7;
      for (var i = 0; i < steps; i++) {
        // Darkest at the edge, fading inwards over about 9px.
        final alpha = (0x3A * (1 - i / steps) * (1 - i / steps)).round();
        canvas.drawRRect(
            felt.deflate(i * 1.3),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..color = Color(alpha << 24));
      }
      canvas.restore();
    }

    // The table round it.
    if (look.rim > 0) canvas.drawPath(table, Paint()..color = skin.table);

    if (look.outerRule case final rule?) {
      canvas.drawRRect(
          felt,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = TableTrim.outerRule
            ..color = rule);
    }
    if (look.innerRule case final rule?) {
      canvas.drawRRect(
          felt.deflate(4.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = TableTrim.innerRule
            ..color = rule);
    }
  }

  @override
  bool shouldRepaint(_TablePainter old) => false || old.skin != skin;
}

/// Lamp light on the felt: a pool of light over the middle of the table,
/// fading to the felt's own colour at its edges, over whatever's worked
/// into the felt (felt_patterns.dart). Under everything on the table, so
/// the cards and seats keep their colours.
class FeltLight extends StatelessWidget {
  const FeltLight({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final look = skin.tableLook;
    final lamp = look.lamp;
    final pattern = look.pattern == FeltPattern.none
        ? null
        : FeltPatternPainter(look.pattern, look.patternColour, ground: skin.felt);
    if (lamp <= 0 && pattern == null) return const SizedBox.expand();
    return CustomPaint(
        painter: pattern, foregroundPainter: lamp <= 0 ? null : _LampPainter(lamp), size: Size.infinite);
  }
}

class _LampPainter extends CustomPainter {
  const _LampPainter(this.lamp);
  final double lamp;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn in a square stretched to the felt, so the pool follows its
    // shape: round on a square table, long on a phone.
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.45);
    canvas.scale(size.width / 2, size.height / 2);
    const unit = Rect.fromLTRB(-1.2, -1.2, 1.2, 1.2);
    canvas.drawRect(
        unit,
        Paint()
          ..shader = RadialGradient(
            radius: 1 / 1.2,
            colors: [
              Color.fromRGBO(255, 255, 255, lamp),
              Color.fromRGBO(255, 255, 255, lamp * 0.45),
              const Color(0x00FFFFFF),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(unit));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LampPainter old) => old.lamp != lamp;
}

/// Paint for a soft round glow of [color] at [centre]: solid to [radius],
/// fading to nothing over [soft] beyond it, as a blur would, but drawn as a
/// gradient (a blur is costly to work out every frame, on the web above
/// all). Draw a circle of [radius] + [soft] with it.
Paint softGlow(Offset centre, double radius, double soft, Color color) {
  final outer = radius + soft;
  return Paint()
    ..shader = RadialGradient(
      colors: [color, color.withValues(alpha: color.a * 0.5), color.withValues(alpha: 0)],
      stops: [radius / outer * 0.6, radius / outer, 1],
    ).createShader(Rect.fromCircle(center: centre, radius: outer));
}

/// A ring of gold and white sparks flying out from [origin] and fading as
/// [progress] runs from 0 to 1. Used when the crown lands.
class SparkBurst extends CustomPainter {
  SparkBurst({required this.skin, required this.origin, required this.progress});
  final Skin skin;
  final Offset origin;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);
    for (var k = 0; k < 14; k++) {
      final a = k * 2 * math.pi / 14;
      final r = 10 + 48 * ease * (k.isEven ? 1 : 0.7);
      final p = origin + Offset(math.cos(a), math.sin(a)) * r;
      final color = k.isEven ? skin.gold : Colors.white;
      canvas.drawCircle(
        p,
        (k.isEven ? 3.5 : 2.5) * (1 - ease * 0.5),
        Paint()..color = color.withAlpha((255 * fade).round()),
      );
    }
    // A soft gold glow under the crown: a gradient as wide as the blur it
    // stands for, which costs nothing to soften.
    canvas.drawCircle(origin, 18 + 20 * ease + 24, softGlow(origin, 18 + 20 * ease, 24, skin.gold.withAlpha((90 * fade).round())));
  }

  @override
  bool shouldRepaint(SparkBurst old) =>
      old.progress != progress || old.origin != origin || old.skin != skin;
}

/// Gold crowns and confetti tumbling down the table when a round is won.
/// [progress] runs 0 to 1; [seed] keeps the pattern steady for one win.
class CrownConfetti extends CustomPainter {
  CrownConfetti({required this.skin, required this.progress, required this.seed});
  final Skin skin;
  final double progress;
  final int seed;

  static final _crownPath = Path()
    ..moveTo(0, 0.25)
    ..lineTo(0.27, 0.55)
    ..lineTo(0.5, 0)
    ..lineTo(0.73, 0.55)
    ..lineTo(1, 0.25)
    ..lineTo(0.88, 0.82)
    ..lineTo(0.12, 0.82)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final fade = progress < 0.75 ? 1.0 : (1 - progress) / 0.25;
    for (var i = 0; i < 46; i++) {
      final x0 = rand.nextDouble() * size.width;
      final delay = rand.nextDouble() * 0.35;
      final speed = 0.8 + rand.nextDouble() * 0.6;
      final sway = 12 + rand.nextDouble() * 22;
      final spin = (rand.nextDouble() - 0.5) * 10;
      final isCrown = i % 3 == 0;
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = -30 + t * speed * (size.height + 60);
      final x = x0 + math.sin(t * 6 + i) * sway;
      final color = switch (i % 4) {
        0 => skin.gold,
        1 => Colors.white,
        2 => skin.goldDeep,
        _ => skin.cardRed,
      };
      final paint = Paint()..color = color.withAlpha((255 * fade).round());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin * t);
      if (isCrown) {
        canvas.scale(18);
        canvas.translate(-0.5, -0.4);
        canvas.drawPath(_crownPath, Paint()..color = skin.gold.withAlpha((255 * fade).round()));
      } else {
        canvas.drawRect(const Rect.fromLTWH(-4, -2.5, 8, 5), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CrownConfetti old) =>
      old.progress != progress || old.seed != seed || old.skin != skin;
}

/// White Cinzel lettering with a solid black outline, readable on any seat
/// colour.
class OutlinedLabel extends StatelessWidget {
  const OutlinedLabel(this.text,
      {super.key, required this.fontSize, this.strokeWidth = 3});
  final String text;
  final double fontSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // Seat numbers use the plain face: Cinzel's old-style 1 reads as a
    // Roman I, which clashes with the wax seals.
    final numeric = RegExp(r'^\d+$').hasMatch(text);
    TextStyle style(Paint? stroke) => TextStyle(
          fontFamily: numeric ? skin.bodyFont : skin.displayFont,
          fontWeight: numeric ? FontWeight.w700 : FontWeight.w900,
          fontSize: fontSize,
          height: 1,
          foreground: stroke,
          color: stroke == null ? Colors.white : null,
        );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text,
            style: style(Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black)),
        Text(text, style: style(null)),
      ],
    );
  }
}

/// Cards of one width laid out in columns, each going under the shortest
/// column so far, so short and tall cards pack together with no gaps.
/// The columns are centred in the space. When the cards change, those
/// that stay glide to their new places (worked out during layout, so
/// nothing is ever drawn a frame in the wrong place).
class Masonry extends StatefulWidget {
  const Masonry(
      {super.key,
      required this.columnWidth,
      this.spacing = 6,
      this.minHeight = 0,
      required this.children});
  final double columnWidth;
  final double spacing;

  /// At least this tall, with the cards centred up and down in it.
  final double minHeight;
  final List<Widget> children;

  @override
  State<Masonry> createState() => _MasonryState();
}

class _MasonryState extends State<Masonry> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420), value: 1);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _MasonryLayout(
        columnWidth: widget.columnWidth,
        spacing: widget.spacing,
        minHeight: widget.minHeight,
        glide: _c,
        children: widget.children,
      );
}

class _MasonryLayout extends MultiChildRenderObjectWidget {
  const _MasonryLayout(
      {required this.columnWidth,
      required this.spacing,
      required this.minHeight,
      required this.glide,
      required super.children});
  final double columnWidth;
  final double spacing;
  final double minHeight;
  final AnimationController glide;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMasonry(columnWidth, spacing, glide)..minHeight = minHeight;

  @override
  void updateRenderObject(BuildContext context, _RenderMasonry r) {
    r
      ..columnWidth = columnWidth
      ..spacing = spacing
      ..minHeight = minHeight;
  }
}

class _MasonryData extends ContainerBoxParentData<RenderBox> {
  /// Where it was drawn when the latest glide began.
  Offset? from;
  bool placed = false;
}

class _RenderMasonry extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MasonryData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MasonryData> {
  _RenderMasonry(this._columnWidth, this._spacing, this._glide);
  double _columnWidth, _spacing;
  final AnimationController _glide;

  /// Set when a glide was started in layout, until its first tick.
  bool _starting = false;

  set columnWidth(double v) {
    if (v == _columnWidth) return;
    _columnWidth = v;
    markNeedsLayout();
  }

  set spacing(double v) {
    if (v == _spacing) return;
    _spacing = v;
    markNeedsLayout();
  }

  double _minHeight = 0;
  set minHeight(double v) {
    if (v == _minHeight) return;
    _minHeight = v;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _glide.addListener(_tick);
  }

  @override
  void detach() {
    _glide.removeListener(_tick);
    super.detach();
  }

  void _tick() {
    if (_glide.value > 0) _starting = false;
    markNeedsPaint();
  }

  double get _t =>
      _starting ? 0 : Curves.easeInOutCubic.transform(_glide.value);

  Offset _shown(_MasonryData d) {
    final from = d.from;
    if (from == null) return d.offset;
    return Offset.lerp(from, d.offset, _t)!;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MasonryData) child.parentData = _MasonryData();
  }

  @override
  void performLayout() {
    final maxW = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : _columnWidth * 3 + _spacing * 2;
    final colW = math.min(_columnWidth, maxW);
    var cols = math.max(1, ((maxW + _spacing) / (colW + _spacing)).floor());
    cols = math.max(1, math.min(cols, childCount));
    final heights = List<double>.filled(cols, 0);
    final used = cols * colW + (cols - 1) * _spacing;
    final left = (maxW - used) / 2;
    var moved = false;
    final shownNow = <_MasonryData, Offset>{};
    // First where each card goes, then how far down to centre the lot.
    final places = <_MasonryData, Offset>{};
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: colW), parentUsesSize: true);
      var c = 0;
      for (var i = 1; i < cols; i++) {
        if (heights[i] < heights[c] - 0.5) c = i;
      }
      final data = child.parentData! as _MasonryData;
      places[data] = Offset(left + c * (colW + _spacing), heights[c]);
      heights[c] += child.size.height + _spacing;
      child = data.nextSibling;
    }
    final content = math.max(0.0, heights.fold<double>(0, math.max) - _spacing);
    final tall = math.max(content, _minHeight);
    final top = (tall - content) / 2;
    child = firstChild;
    while (child != null) {
      final data = child.parentData! as _MasonryData;
      final next = places[data]! + Offset(0, top);
      // Wherever it shows now, mid-glide or not; new cards just appear.
      shownNow[data] = data.placed ? _shown(data) : next;
      if (data.placed && (next - data.offset).distance > 1) moved = true;
      data.offset = next;
      data.placed = true;
      child = data.nextSibling;
    }
    if (moved) {
      // Freeze everyone's starting point, then run the glide from the
      // next frame.
      for (final e in shownNow.entries) {
        e.key.from = e.value;
      }
      _starting = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) _glide.forward(from: 0);
      });
    }
    size = constraints.constrain(Size(maxW, tall));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final d = child.parentData! as _MasonryData;
      context.paintChild(child, offset + _shown(d));
      child = d.nextSibling;
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final o = _shown(child.parentData! as _MasonryData);
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final d = child.parentData! as _MasonryData;
      final hit = result.addWithPaintOffset(
          offset: _shown(d),
          position: position,
          hitTest: (r, p) => child!.hitTest(r, position: p));
      if (hit) return true;
      child = d.previousSibling;
    }
    return false;
  }
}
