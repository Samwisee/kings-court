// The Look page's little pictures of each choice (look_dialog.dart).
part of 'look_dialog.dart';

/// A little table: its felt, lit in the middle, with what's worked into
/// it, set into its rim, with a crown in the accent.
class _TableSwatch extends StatelessWidget {
  const _TableSwatch(this.skin);
  final Skin skin;

  @override
  Widget build(BuildContext context) {
    final look = skin.tableLook;
    final ink = look.patternColour;
    return Container(
      width: 84,
      height: 64,
      decoration: BoxDecoration(
        color: skin.table,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: RadialGradient(colors: [skin.feltGlow, skin.feltDeep], radius: 0.9),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: CustomPaint(
            // A little smaller than on the table, and a little stronger,
            // to be seen so small.
            painter: FeltPatternPainter(look.pattern, ink.withValues(alpha: math.min(1, ink.a * 1.6)),
                ground: skin.felt, scale: 0.4),
            child: Center(child: CrownIcon(size: 22, color: skin.gold)),
          ),
        ),
      ),
    );
  }
}

/// A little task card in [look]: points, a crown, and two lines of words.
class _TaskSwatch extends StatelessWidget {
  const _TaskSwatch(this.look);
  final TaskLook look;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    Widget words(double width) => Container(
        width: width,
        height: 4,
        margin: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(color: look.ink.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(2)));
    return Container(
      width: 78,
      height: 56,
      decoration: BoxDecoration(
        color: look.face,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: skin.outlineColour),
      ),
      child: CustomPaint(
        painter: TaskFacePainter(look, reach: EdgeInsets.zero, radius: 6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('3',
                  style: TextStyle(
                      fontFamily: skin.displayFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      height: 1,
                      color: look.ink)),
              const SizedBox(width: 2),
              CrownIcon(size: 11, color: look.crown ?? skin.goldDeep),
            ]),
            words(52),
            words(34),
          ]),
        ),
      ),
    );
  }
}

/// Two cards' faces as [look] draws them: a number card and a Court Card.
class _Faces extends StatelessWidget {
  const _Faces(this.look);
  final Skin look;

  @override
  Widget build(BuildContext context) => SkinScope(
        skin: look,
        child: SizedBox(
          width: 80,
          height: 70,
          child: Stack(children: [
            Positioned(
                left: 4,
                top: 6,
                child: Transform.rotate(
                    angle: -0.08, child: const PlayingCardView(card: PlayingCard(Suit.hearts, 7), width: 40))),
            Positioned(
                right: 4,
                top: 4,
                child: Transform.rotate(angle: 0.08, child: const PlayingCardView(card: PlayingCard.queen, width: 40))),
          ]),
        ),
      );
}

/// Three seats' tokens as [look] makes them, the middle one the King's.
class _Tokens extends StatelessWidget {
  const _Tokens(this.look);
  final Skin look;

  @override
  Widget build(BuildContext context) {
    final l = look.tokenLook;
    const shapes = [TokenShape.shield, TokenShape.hexagon, TokenShape.diamond];
    Widget token(int k, double size) => StyledToken(
          style: l.style,
          shape: shapes[k],
          size: size,
          color: look.players[k],
          ring: k == 1 ? look.gold : look.feltDeep,
          ringWidth: k == 1 ? l.ringWidth + 1 : l.ringWidth,
          skin: look,
        );
    // The skin's own houses: drawn as the seats draw them.
    if (l.style == TokenStyle.houses) {
      return SkinScope(
        skin: look,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (k, shape) in const [TokenShape.shield, TokenShape.hexagon, TokenShape.diamond].indexed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: l.shaped
                  ? ShapedToken(
                      shape: shape,
                      size: k == 1 ? 32 : 24,
                      color: look.players[k],
                      ring: k == 1 ? look.gold : look.feltDeep,
                      ringWidth: l.ringWidth)
                  : Container(
                      width: k == 1 ? 32 : 24,
                      height: k == 1 ? 32 : 24,
                      decoration: BoxDecoration(
                          color: look.players[k],
                          shape: BoxShape.circle,
                          border: Border.all(color: k == 1 ? look.gold : look.feltDeep, width: l.ringWidth))),
            ),
        ]),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      token(0, 24),
      const SizedBox(width: 2),
      token(1, 32),
      const SizedBox(width: 2),
      token(2, 24),
    ]);
  }
}

/// A card back as [look] draws it.
class _Back extends StatelessWidget {
  const _Back(this.look);
  final Skin look;

  @override
  Widget build(BuildContext context) => SkinScope(skin: look, child: const CardBack(width: 46));
}
