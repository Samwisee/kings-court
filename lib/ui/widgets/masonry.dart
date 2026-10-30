/// Task cards packed in columns in the middle of the table.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Cards of one width laid out in columns, each going under the shortest
/// column so far, so short and tall cards pack together with no gaps.
/// The columns are centred in the space. Once laid out, a card keeps its
/// column, and the columns and their height on the table stay where they
/// are: when a card goes, only those under it in its column close up.
/// Those that move go straight to their new places one after another, top
/// to bottom (worked out during layout, so nothing is ever drawn a frame
/// in the wrong place). A fresh set of cards is laid out afresh.
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

  /// Its column, kept once it's laid out.
  int column = 0;

  /// When in the glide it moves, as shares of the whole (one card after
  /// another).
  double start = 0;
  double end = 1;
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

  /// The columns, and how far down the cards start, kept from one layout
  /// to the next while the same set of cards is on the table.
  int _cols = 0;
  double? _top;

  /// One card's move, and the gap before the next one sets off.
  static const _moveMs = 340;
  static const _staggerMs = 110;

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

  double _t(_MasonryData d) {
    if (_starting) return 0;
    final span = d.end - d.start;
    final u = span <= 0 ? 1.0 : ((_glide.value - d.start) / span).clamp(0.0, 1.0);
    return Curves.easeInOutCubic.transform(u);
  }

  Offset _shown(_MasonryData d) {
    final from = d.from;
    if (from == null) return d.offset;
    return Offset.lerp(from, d.offset, _t(d))!;
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
    final fit = math.max(1, ((maxW + _spacing) / (colW + _spacing)).floor());
    // A fresh set (none of these cards laid out before): laid out afresh.
    var fresh = true;
    for (var c = firstChild; c != null; c = (c.parentData! as _MasonryData).nextSibling) {
      if ((c.parentData! as _MasonryData).placed) fresh = false;
    }
    if (fresh || _cols > fit || _cols == 0) {
      _cols = math.max(1, math.min(fit, childCount));
      _top = null;
    }
    final cols = _cols;
    final heights = List<double>.filled(cols, 0);
    final used = cols * colW + (cols - 1) * _spacing;
    final left = (maxW - used) / 2;
    final shownNow = <_MasonryData, Offset>{};
    // First where each card goes: in its own column if it has one, else
    // under the shortest; then how far down the lot starts.
    final places = <_MasonryData, Offset>{};
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: colW), parentUsesSize: true);
      final data = child.parentData! as _MasonryData;
      var c = 0;
      if (data.placed && data.column < cols) {
        c = data.column;
      } else {
        for (var i = 1; i < cols; i++) {
          if (heights[i] < heights[c] - 0.5) c = i;
        }
      }
      data.column = c;
      places[data] = Offset(left + c * (colW + _spacing), heights[c]);
      heights[c] += child.size.height + _spacing;
      child = data.nextSibling;
    }
    final content = math.max(0.0, heights.fold<double>(0, math.max) - _spacing);
    final tall = math.max(content, _minHeight);
    // Centred when first laid out; then kept, unless the cards no longer
    // fit below it.
    var top = _top ?? (tall - content) / 2;
    if (top + content > tall) top = math.max(0, tall - content);
    _top = top;
    final movers = <_MasonryData>[];
    child = firstChild;
    while (child != null) {
      final data = child.parentData! as _MasonryData;
      final next = places[data]! + Offset(0, top);
      // Wherever it shows now, mid-glide or not; new cards just appear.
      shownNow[data] = data.placed ? _shown(data) : next;
      if (data.placed && (next - shownNow[data]!).distance > 1) movers.add(data);
      data.offset = next;
      data.placed = true;
      child = data.nextSibling;
    }
    if (movers.isNotEmpty) {
      // Each goes in turn, top to bottom, left to right, straight to its
      // place; the rest stay put.
      movers.sort((a, b) => a.offset.dy != b.offset.dy ? a.offset.dy.compareTo(b.offset.dy) : a.offset.dx.compareTo(b.offset.dx));
      final total = _moveMs + (movers.length - 1) * _staggerMs;
      for (final e in shownNow.entries) {
        e.key
          ..from = e.value
          ..start = 0
          ..end = 0;
      }
      for (final (k, d) in movers.indexed) {
        d
          ..start = k * _staggerMs / total
          ..end = (k * _staggerMs + _moveMs) / total;
      }
      _glide.duration = Duration(milliseconds: total);
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
