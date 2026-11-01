part of 'livery_page.dart';

/// A panel of the style's own (its colours, corners and edge) round a part
/// of the page. No blurred shadow: on the web every frame draws it again,
/// and this page is the phone's slowest already.
class _Enclosure extends StatelessWidget {
  const _Enclosure({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final look = skin.panelLook;
    final radius = BorderRadius.circular(math.min(look.radius, 20));
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [for (final c in look.court) c.withValues(alpha: 0.92)],
        ),
        borderRadius: radius,
        border: Border.all(color: skin.gold.withValues(alpha: 0.4), width: math.min(look.edgeWidth, 2)),
        // A hard shadow, a step below: as good as a blurred one at this
        // size, and nothing to draw again.
        boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 3))],
      ),
      child: child,
    );
  }
}

/// The grid's scrollbar in the livery's own colours: a slim thumb in its
/// accent on a dark track, always showing, so there's plainly more below.
class _LiveryScrollbar extends StatelessWidget {
  const _LiveryScrollbar({super.key, required this.controller, required this.child});
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

/// The livery put together, as a showcase: its name, a hand of the Court
/// Cards over the Ace to the 4, a pile of tricks in the backs, the seats'
/// tokens and a task, under a soft light. Each part changes on its own, as
/// its own choice does, and the lot only when the style does. Wide, the
/// hand is in the middle, the backs to its left and the tokens and task to
/// its right; narrow, the backs go with the tokens and task.
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
          final cardW = clampD(math.min((h - 84) / (1.42 * 1.85), w * (wide ? 0.11 : 0.13)), 40, 66);
          final cardH = PlayingCardView.heightFor(cardW);
          final step = cardW * 0.66;
          final fanW = 3 * step + cardW + 10;
          final gap = clampD(w * 0.05, 14, 36);
          Widget fan(List<PlayingCard> cards, {required bool high}) => SizedBox(
                width: fanW,
                height: cardH + 12,
                child: Stack(clipBehavior: Clip.none, children: [
                  for (final (k, card) in cards.indexed)
                    Positioned(
                      left: k * step,
                      top: (k - 1.5).abs() * (high ? 4 : 2),
                      child: Transform.rotate(
                          angle: (k - 1.5) * (high ? 0.09 : 0.05), child: PlayingCardView(card: card, width: cardW)),
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
                  child: _Swap(id: '$base-${dressed?.face?.id}', child: fan(_numbers, high: false))),
            ]),
          );
          final backW = cardW * (wide ? 0.95 : 0.8);
          final backs = _Swap(
            id: '$base-${dressed?.back?.id}',
            child: SizedBox(
              width: backW + 12,
              height: PlayingCardView.heightFor(backW) + 8,
              child: Stack(children: [
                for (var k = 0; k < 3; k++)
                  Positioned(
                    left: k * 5.0,
                    top: k * 2.0,
                    child: Transform.rotate(angle: (k.isEven ? -1 : 1) * 0.06, child: CardBack(width: backW)),
                  ),
              ]),
            ),
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
          final scene = wide
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  backs,
                  SizedBox(width: gap),
                  hand,
                  SizedBox(width: gap),
                  Column(mainAxisSize: MainAxisSize.min, children: [tokens, const SizedBox(height: 14), task]),
                ])
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  hand,
                  SizedBox(width: gap),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    tokens,
                    const SizedBox(height: 10),
                    backs,
                    const SizedBox(height: 10),
                    task,
                  ]),
                ]);
          return Stack(fit: StackFit.expand, children: [
            // A soft light over the middle.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                    center: const Alignment(0, 0.2),
                    radius: 0.8,
                    colors: [skin.gold.withValues(alpha: 0.14), skin.gold.withValues(alpha: 0)]),
              ),
            ),
            Column(children: [
              const SizedBox(height: 10),
              Text('Livery',
                  style: TextStyle(fontSize: 13, letterSpacing: 1.2, color: Colors.white.withValues(alpha: 0.6))),
              _Swap(
                id: base,
                child: Text(skin.name,
                    style: TextStyle(
                        fontFamily: skin.displayFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        height: 1.15,
                        color: skin.gold,
                        shadows: skin.feltShadow)),
              ),
              Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: scene))),
              const SizedBox(height: 10),
            ]),
          ]);
        });
      }),
    );
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
