part of 'livery_page.dart';

/// The shop's one case, in the style's own panel colours: a fine gold
/// edge with a second rule inside it. No blurred shadow (on the web every frame draws one again, and
/// this page is the phone's slowest already): a hard one, a step below.
class _Case extends StatelessWidget {
  const _Case({required this.child});
  final Widget child;

  /// The case's ground: one colour, so what's pinned at its top (the
  /// sections) matches what's under it.
  static Color ground(Skin skin) {
    final c = skin.panelLook.court;
    return Color.lerp(c.first, c.last, 0.55)!;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final radius = math.min(skin.panelLook.radius, 20.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ground(skin),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: skin.gold.withValues(alpha: 0.55), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4))],
      ),
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(borderRadius: BorderRadius.circular(radius - 2), child: child),
        ),
        // The rule inside the edge: over the contents, not in the way of
        // them.
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(math.max(2, radius - 4)),
                  border: Border.all(color: skin.gold.withValues(alpha: 0.22)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The counter at the foot of the case: choose what's put together (or
/// just leave, if nothing changed); for a style tried on that's for sale, buy it, or
/// take it off.
class _Counter extends StatelessWidget {
  const _Counter(
      {required this.look,
      required this.price,
      required this.changed,
      required this.onWear,
      required this.onBuy,
      required this.onTakeOff});
  final Skin look;
  final String? price;
  final bool changed;
  final VoidCallback onWear, onBuy, onTakeOff;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final name = TailoredSkin.baseOf(look).name;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        border: Border(top: BorderSide(color: skin.gold.withValues(alpha: 0.35), width: 1.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            if (price case final price?) ...[
              FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(200, 46)),
                  onPressed: onBuy,
                  child: Text('Buy $name · $price')),
              TextButton(onPressed: onTakeOff, child: const Text('Take it off')),
            ] else
              FilledButton(
                  key: const ValueKey('livery-wear'),
                  style: FilledButton.styleFrom(minimumSize: const Size(200, 46)),
                  onPressed: onWear,
                  child: Text(changed ? 'Choose' : 'Done')),
          ],
        ),
      ),
    );
  }
}

/// A small pill on a tile: what's worn.
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

/// A price tag on a tile for sale: a little lock and the price, gold on
/// the style's dark.
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

/// The grid's scrollbar in the livery's own colours: a slim thumb in its
/// accent on a dark track, always showing, so there's plainly more below.
class _LiveryScrollbar extends StatelessWidget {
  const _LiveryScrollbar({required this.controller, required this.child});
  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ScrollConfiguration(
      // Ours instead of the platform's.
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: RawScrollbar(
        controller: controller,
        thumbVisibility: true,
        trackVisibility: true,
        thickness: 6,
        radius: const Radius.circular(3),
        trackRadius: const Radius.circular(3),
        thumbColor: skin.gold.withValues(alpha: 0.75),
        trackColor: Colors.black.withValues(alpha: 0.22),
        trackBorderColor: Colors.transparent,
        crossAxisMargin: 6,
        mainAxisMargin: 10,
        child: child,
      ),
    );
  }
}

/// The shop window: the livery put together on its own table, under the
/// store's hanging sign and the style's name; a hand of the Court Cards
/// over the Ace to the 4 (the 4 face down, to show the backs), the seats'
/// tokens and a task. A style for sale says it's being tried on, and its
/// price. Each part changes on its own, as
/// its own choice does, and the lot only when the style does.
class _Showcase extends StatelessWidget {
  const _Showcase({required this.look, this.price});
  final Skin look;

  /// Its price, when it's for sale and being tried on.
  final String? price;

  static const _courts = [PlayingCard.joker, PlayingCard.jack, PlayingCard.queen, PlayingCard.king];
  static const _numbers = [
    PlayingCard(Suit.hearts, 1),
    PlayingCard(Suit.spades, 2),
    PlayingCard(Suit.diamonds, 3),
    PlayingCard(Suit.clubs, 4),
  ];

  @override
  Widget build(BuildContext context) {
    final dressed = look is TailoredSkin ? look as TailoredSkin : null;
    final base = TailoredSkin.baseOf(look).id;
    return SkinScope(
      skin: look,
      child: Builder(builder: (context) {
        final skin = context.skin;
        return LayoutBuilder(builder: (context, c) {
          final h = c.maxHeight, w = c.maxWidth;
          final wide = w >= 520;
          final cardW = clampD(math.min((h - 104) / (1.42 * 1.85), w * (wide ? 0.11 : 0.13)), 40, wide ? 74 : 66);
          final cardH = PlayingCardView.heightFor(cardW);
          final step = cardW * 0.66;
          final fanW = 3 * step + cardW + 10;
          final gap = clampD(w * 0.05, 14, 36);
          // [faceDown] of them turned over at the end, to show the backs.
          Widget fan(List<PlayingCard> cards, {required bool high, int faceDown = 0}) => SizedBox(
                width: fanW,
                height: cardH + 12,
                child: Stack(clipBehavior: Clip.none, children: [
                  for (final (k, card) in cards.indexed)
                    Positioned(
                      left: k * step,
                      top: (k - 1.5).abs() * (high ? 4 : 2),
                      child: Transform.rotate(
                          angle: (k - 1.5) * (high ? 0.09 : 0.05),
                          child: k >= cards.length - faceDown
                              ? CardBack(width: cardW)
                              : PlayingCardView(card: card, width: cardW)),
                    ),
                ]),
              );
          final hand = SizedBox(
            width: fanW,
            height: cardH * 1.82 + 12,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(left: 0, top: 0, child: _Swap(id: '$base-${dressed?.court?.id}', child: fan(_courts, high: true))),
              Positioned(
                  left: 0,
                  top: cardH * 0.82,
                  // The last turned over: the backs, without a pile of
                  // their own.
                  child: _Swap(
                      id: '$base-${dressed?.face?.id}-${dressed?.back?.id}',
                      child: fan(_numbers, high: false, faceDown: 1))),
            ]),
          );
          final tokens = _Swap(id: '$base-${dressed?.token?.id}', child: _Tokens(look));
          final task = _Swap(
            id: '$base-${dressed?.task?.id}',
            child: TaskChip(
              task: RoundTask(taskByDescription('Win the first trick')),
              points: 2,
              text: 'Win the first trick',
              color: skin.players[0],
              width: 124,
              progress: '0/1',
            ),
          );
          final scene = Row(mainAxisSize: MainAxisSize.min, children: [
            hand,
            SizedBox(width: gap),
            Column(mainAxisSize: MainAxisSize.min, children: [tokens, SizedBox(height: wide ? 18 : 14), task]),
          ]);
          final frame = BorderRadius.circular(12);
          return Padding(
            // The window, set into the case.
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: frame,
                border: Border.all(color: skin.gold.withValues(alpha: 0.35)),
                color: skin.felt,
              ),
              child: ClipRRect(
                borderRadius: frame,
                child: Stack(fit: StackFit.expand, children: [
                  // The style's own table, its pattern and lamp (drawn once
                  // into a picture, and still).
                  _Swap(id: 'felt-$base', child: const FeltLight()),
                  // A spotlight from above.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                          center: const Alignment(0, -1.3),
                          radius: 1.5,
                          colors: [skin.gold.withValues(alpha: 0.18), skin.gold.withValues(alpha: 0)]),
                    ),
                  ),
                  Column(children: [
                    const _Sign(name: 'Store'),
                    // The style shown, and when it's for sale, its price.
                    SizedBox(
                      height: 22,
                      child: Center(
                        child: _Swap(
                          id: '$base-$price',
                          child: Text(price == null ? skin.name : '${skin.name} · trying on · $price',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  shadows: skin.feltShadow)),
                        ),
                      ),
                    ),
                    Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: scene))),
                    SizedBox(height: h * 0.05),
                  ]),
                ]),
              ),
            ),
          );
        });
      }),
    );
  }
}

/// The shop's sign: a name on a plaque, hung from two fine chains from the
/// top of the window.
class _Sign extends StatelessWidget {
  const _Sign({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final chain = Container(width: 1.2, height: 12, color: skin.gold.withValues(alpha: 0.6));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [chain, const SizedBox(width: 120), chain]),
      Container(
        padding: const EdgeInsets.fromLTRB(18, 3, 18, 5),
        decoration: BoxDecoration(
          color: Color.lerp(skin.feltDeep, Colors.black, 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: skin.gold.withValues(alpha: 0.85), width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black38, offset: Offset(0, 2))],
        ),
        child: Text(name,
            style: TextStyle(
                fontFamily: skin.displayFont,
                fontWeight: FontWeight.w800,
                fontSize: 24,
                height: 1.15,
                color: skin.gold,
                shadows: skin.feltShadow)),
      ),
    ]);
  }
}

/// One part of the showcase, changing (fading and settling in) only when
/// [id] does, in a layer of its own.
class _Swap extends StatelessWidget {
  const _Swap({required this.id, required this.child});
  final String id;
  final Widget child;

  // The part carries the livery it was drawn in, so the old one fades out
  // as it was rather than in the new one.
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, a) => FadeTransition(
            opacity: a, child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child)),
        layoutBuilder: (current, previous) =>
            Stack(alignment: Alignment.center, children: [...previous, if (current != null) current]),
        child: RepaintBoundary(key: ValueKey(id), child: SkinScope(skin: context.skin, child: child)),
      );
}
