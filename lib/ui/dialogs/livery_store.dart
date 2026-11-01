part of 'livery_page.dart';

/// The styles new in the store: ribboned on the shelves.
const _newStyles = {'riviera', 'winter', 'egyptian', 'galleon', 'scopa', 'casino'};

/// Every style for sale at once (a sample, like the store's prices).
const _bundlePrice = r'A$12';

/// The top of the store's case: its name over a fine divider.
class _StoreHeading extends StatelessWidget {
  const _StoreHeading();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_Store.gutter, 12, _Store.gutter, 2),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Store',
            style: TextStyle(
                fontFamily: skin.displayFont,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: 0.5,
                color: skin.gold,
                shadows: skin.feltShadow)),
        OrnateDivider(color: skin.gold.withValues(alpha: 0.7), width: 150),
      ]),
    );
  }
}

/// One item on the store's shelves: its picture on the style's felt, and
/// under it a footer with its name and, for sale, its price. Ringed in the
/// accent when chosen; ribboned when it's the one in use, or new; lifted,
/// under a pointer, with the hand.
class _Tile extends StatefulWidget {
  const _Tile(
      {required this.name,
      required this.selected,
      required this.onTap,
      required this.child,
      this.inUse = false,
      this.fresh = false,
      this.price});
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  /// What's in use now.
  final bool inUse;

  /// New in the store.
  final bool fresh;

  /// For sale: its price.
  final String? price;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final selected = widget.selected;
    final lit = selected || _hover;
    return Semantics(
      button: true,
      selected: selected,
      label: [
        widget.name,
        if (widget.inUse) 'in use',
        if (widget.fresh) 'new',
        if (widget.price != null) 'for sale, ${widget.price}',
      ].join(', '),
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(_Store.tileRadius),
              border: Border.all(
                  color: selected
                      ? skin.gold
                      : _hover
                          ? skin.gold.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.1),
                  width: selected ? 2 : 1.2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // The picture, on the style's own felt.
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: RadialGradient(radius: 0.95, colors: [skin.feltGlow, skin.feltDeep])),
                  ),
                  Center(
                    child: AnimatedScale(
                        scale: _hover ? 1.05 : 1,
                        duration: const Duration(milliseconds: 160),
                        // Its own layer: drawn once, not again as the shelves scroll.
                        child: RepaintBoundary(child: widget.child)),
                  ),
                  if (widget.inUse)
                    Positioned(left: 6, top: 6, child: _Badge(text: 'In use', fill: skin.gold, ink: skin.goldInk))
                  else if (widget.fresh)
                    const Positioned(
                        left: 6, top: 6, child: _Badge(text: 'New', fill: Color(0xFFD9483B), ink: Colors.white)),
                  if (selected)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: skin.gold, shape: BoxShape.circle),
                        child: Icon(Icons.check_rounded, size: 14, color: skin.goldInk),
                      ),
                    ),
                ]),
              ),
              // The footer: its name, and its price.
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.black.withValues(alpha: 0.28),
                child: Row(children: [
                  Expanded(
                    child: Text(widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: lit ? skin.gold : Colors.white.withValues(alpha: 0.88))),
                  ),
                  if (widget.price case final price?) _PriceTag(price: price),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The store's measures: one corner radius a level, so the case, the window
/// and the tiles nest.
abstract final class _Store {
  static const caseRadius = 20.0;
  static const windowRadius = 14.0;
  static const tileRadius = 12.0;
  static const gutter = 12.0;
}

/// A heading over a shelf, with an offer beside it if there is one.
class _ShelfHeading extends StatelessWidget {
  const _ShelfHeading({required this.title, this.offer});
  final String title;
  final Widget? offer;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(children: [
        Text(title,
            style: TextStyle(
                fontFamily: skin.displayFont, fontSize: 17, fontWeight: FontWeight.w800, color: skin.gold)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: skin.gold.withValues(alpha: 0.25))),
        if (offer != null) ...[const SizedBox(width: 10), offer!],
      ]),
    );
  }
}

/// Every style for sale at once, for less: beside the For sale shelf.
class _BundleOffer extends StatelessWidget {
  const _BundleOffer({required this.price, required this.onTap});
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      button: true,
      label: 'Get every style, $price',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
            decoration: BoxDecoration(
              color: skin.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: skin.gold.withValues(alpha: 0.7)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: skin.gold),
              const SizedBox(width: 5),
              Text('Get every style · $price',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: skin.gold)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The counter at the foot of the case. A style for sale: its name, that
/// it's theirs to keep, and Buy. Anything else: Choose (or Done, if nothing
/// changed).
class _Counter extends StatelessWidget {
  const _Counter(
      {required this.look, required this.price, required this.changed, required this.onChoose, required this.onBuy});
  final Skin look;
  final String? price;
  final bool changed;
  final VoidCallback onChoose, onBuy;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final name = TailoredSkin.baseOf(look).name;
    final button = FilledButton.styleFrom(minimumSize: const Size(180, 46));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(top: BorderSide(color: skin.gold.withValues(alpha: 0.3))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: price == null
            ? Center(
                child: FilledButton(
                    key: const ValueKey('livery-wear'),
                    style: button,
                    onPressed: onChoose,
                    child: Text(changed ? 'Choose' : 'Done')))
            : Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: skin.displayFont,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: skin.gold)),
                    const SizedBox(height: 2),
                    Text('Yours to keep, in every game.',
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75))),
                  ]),
                ),
                const SizedBox(width: 12),
                FilledButton(style: button, onPressed: onBuy, child: Text('Buy · $price')),
              ]),
      ),
    );
  }
}

/// A small pill on a tile: in use, or new.
class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.fill, required this.ink});
  final String text;
  final Color fill, ink;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(9)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: ink)),
      );
}

/// A price: gold on the style's dark, with a little lock.
class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.price});
  final String price;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
      decoration: BoxDecoration(
        color: skin.feltDeep.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: skin.gold.withValues(alpha: 0.85)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_rounded, size: 11, color: skin.gold),
        const SizedBox(width: 3),
        Text(price, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: skin.gold)),
      ]),
    );
  }
}
