// The top bar’s gold buttons and the ornate menu that drops down from it.
part of '../main.dart';

/// A button in the top corner, flat on the felt: just its gold, pressing
/// in when tapped.
class _GoldBar extends StatefulWidget {
  const _GoldBar({required this.onTap, required this.child, this.semanticLabel});
  final VoidCallback onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  State<_GoldBar> createState() => _GoldBarState();
}

class _GoldBarState extends State<_GoldBar> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: Alignment.center,
            // Flat on the felt: just the gold, with its soft shadow.
            child: widget.child,
          ),
        ),
      )),
    );
  }
}

/// A gold double rule with a jewel at each corner, for menus and dialogs.
class OrnateBorder extends ShapeBorder {
  const OrnateBorder({this.radius = 16, this.gems = true});
  final double radius;

  /// The small diamonds at the inner rule's corners.
  final bool gems;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(2);

  RRect _r(Rect rect) => RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_r(rect.deflate(2)));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_r(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..color = Palette.gold;
    canvas.drawRRect(_r(rect.deflate(1)), gold..strokeWidth = 2);
    final inner = rect.deflate(7);
    canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(math.max(0, radius - 6))),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Palette.gold.withValues(alpha: 0.55));
    if (!gems) return;
    // A small diamond at each corner of the inner rule.
    final gem = Paint()..color = Palette.gold;
    final o = radius * 0.3 + 6;
    for (final c in [
      inner.topLeft + Offset(o, o),
      inner.topRight + Offset(-o, o),
      inner.bottomLeft + Offset(o, -o),
      inner.bottomRight + Offset(-o, -o),
    ]) {
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - 4)
            ..lineTo(c.dx + 4, c.dy)
            ..lineTo(c.dx, c.dy + 4)
            ..lineTo(c.dx - 4, c.dy)
            ..close(),
          gem);
    }
  }

  @override
  ShapeBorder scale(double t) => OrnateBorder(radius: radius * t, gems: gems);
}

typedef _MenuEntry = ({String value, IconData icon, String title, bool? on});

/// The menu, on the court's ornate panel: a medallion over the top, each
/// line with a gold icon, divided by fine gold rules.
class _OrnateMenu extends StatefulWidget {
  const _OrnateMenu({required this.entries, required this.onToggle});
  final List<_MenuEntry> Function() entries;
  final void Function(String) onToggle;

  @override
  State<_OrnateMenu> createState() => _OrnateMenuState();
}

class _OrnateMenuState extends State<_OrnateMenu> {
  /// Settings, which change in place without closing the menu.
  static const _toggles = {'sound', 'suits', 'upright', 'keys'};

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries();
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Material(
          type: MaterialType.transparency,
          child: OrnateCard(
      ornament: Ornament.medium,
            won: false,
            court: true,
            margin: const EdgeInsets.fromLTRB(16, 86, 14, 16),
            // Clear of the scrollwork in the corners.
            padding: const EdgeInsets.fromLTRB(22, 34, 26, 26),
            maxWidth: 310,
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, e) in entries.indexed) ...[
                    if (i > 0)
                      Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: Palette.gold.withValues(alpha: 0.22)),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      highlightColor: Palette.gold.withValues(alpha: 0.08),
                      splashColor: Palette.gold.withValues(alpha: 0.12),
                      hoverColor: Palette.gold.withValues(alpha: 0.06),
                      onTap: () {
                        if (_toggles.contains(e.value)) {
                          widget.onToggle(e.value);
                          setState(() {});
                        } else {
                          Navigator.pop(context, e.value);
                        }
                      },
                      child: Semantics(
                        button: true,
                        toggled: e.on,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 50),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(children: [
                              Icon(e.icon, color: Palette.gold, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(e.title,
                                    style: const TextStyle(
                                        fontFamily: displayFont,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        letterSpacing: 0.3,
                                        color: Palette.goldOnFelt)),
                              ),
                              if (e.on != null) ...[
                                const SizedBox(width: 10),
                                GoldPip(on: e.on!),
                              ],
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The menu button: three gold bars, the middle one shorter, each tipped
/// with a small diamond. While the menu is open the outer bars cross and
/// the middle one draws in to a single jewel.
class _OrnateMenuIcon extends StatelessWidget {
  const _OrnateMenuIcon({this.open = false});
  static const size = 30.0;
  final bool open;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: open ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        builder: (context, t, _) =>
            CustomPaint(size: Size.square(size), painter: _OrnateMenuPainter(t)),
      );
}

class _OrnateMenuPainter extends CustomPainter {
  _OrnateMenuPainter(this.t);

  /// 0: three bars; 1: a cross with a jewel at its heart.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bar = Paint()
      ..color = Palette.gold
      ..strokeWidth = h * 0.09
      ..strokeCap = StrokeCap.round;
    final gem = Paint()..color = Palette.gold;
    void diamond(Offset c, double r) => canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r, c.dy)
          ..close(),
        gem);
    final c = Offset(w / 2, h / 2);
    // The outer bars: from level, they swing to cross through the middle.
    for (final (y, sign) in [(0.25, 1.0), (0.75, -1.0)]) {
      final level = Offset(0, h * y - h / 2);
      final half = w * 0.3 * (1 - 0.1 * t);
      final angle = sign * math.pi / 4 * t;
      final dir = Offset(math.cos(angle), math.sin(angle)) * half;
      final mid = c + level * (1 - t);
      canvas.drawLine(mid - dir, mid + dir, bar);
      diamond(mid - dir * 1.25, h * 0.07 * (1 - t * 0.4));
      diamond(mid + dir * 1.25, h * 0.07 * (1 - t * 0.4));
    }
    // The middle bar draws in to a jewel.
    final half = w * 0.2 * (1 - t);
    if (half > 0.5) canvas.drawLine(c - Offset(half, 0), c + Offset(half, 0), bar);
    if (t < 0.95) {
      diamond(c - Offset(half + h * 0.07, 0), h * 0.07);
      diamond(c + Offset(half + h * 0.07, 0), h * 0.07);
    }
    if (t > 0.05) diamond(c, h * 0.11 * t);
  }

  @override
  bool shouldRepaint(_OrnateMenuPainter old) => old.t != t;
}
