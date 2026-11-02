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
    const radius = _Store.caseRadius;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ground(skin),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: skin.gold.withValues(alpha: 0.55), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4))],
      ),
      child: Stack(children: [
        // Inside the edge, so nothing in the case (the sections' ground,
        // the counter's) is drawn over it: one unbroken line all round.
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipRRect(borderRadius: BorderRadius.circular(radius - 2), child: child),
          ),
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

/// The shop window: the livery put together on the style's own table
/// (under the store's top, [_StoreTop]): a hand of the Court Cards over
/// the Ace to the 4 (the 4 face down, to show the backs), the seats'
/// tokens and a task, as large as the window allows. Each part changes on
/// its own, as its own choice does, and the lot only when the style does.
class _Showcase extends StatelessWidget {
  const _Showcase({required this.look});
  final Skin look;

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
          final cardW = clampD(math.min((h - 28) / (1.42 * 1.85), w * (wide ? 0.12 : 0.14)), 40, wide ? 92 : 76);
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
          return Padding(
            padding: const EdgeInsets.fromLTRB(_Store.gutter, 4, _Store.gutter, 8),
            child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: scene)),
          );
        });
      }),
    );
  }
}

/// The top of the store, all on the style's own table: its name, the
/// window and the sections, over the felt's pattern (drawn once into a
/// picture, and still) with a spotlight from above.
class _StoreTop extends StatelessWidget {
  const _StoreTop({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final base = TailoredSkin.baseOf(skin).id;
    return Stack(children: [
      Positioned.fill(child: ColoredBox(color: skin.felt)),
      Positioned.fill(child: _Swap(id: 'felt-$base', child: const FeltLight())),
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                  center: const Alignment(0, -1.1),
                  radius: 1.3,
                  colors: [skin.gold.withValues(alpha: 0.16), skin.gold.withValues(alpha: 0)]),
            ),
          ),
        ),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
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
