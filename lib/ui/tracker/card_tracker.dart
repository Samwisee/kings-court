/// The card tracker: every card in the deck, and what each player may still hold.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/inference.dart';
import '../../engine/round.dart';
import '../../game/state.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../../skin/theme.dart';
import '../cards/mini_card.dart';
import '../widgets.dart';

/// The card tracker: every card in the deck, row by suit, outlined in the
/// colour of whoever played it (with its trick number), or of whoever
/// holds it if that's known. Tap a player in the key above it to see what
/// they may still hold.
class CardTracker extends StatefulWidget {
  const CardTracker(
      {super.key,
      required this.cards,
      required this.you,
      required this.players,
      this.onClose,
      this.onPeek});
  final VoidCallback? onClose;

  /// Held down (true) and let go (false): hide the tracker to see the table.
  final ValueChanged<bool>? onPeek;
  final Round cards;
  final int you;
  final List<Player> players;

  @override
  State<CardTracker> createState() => CardTrackerState();
}

class CardTrackerState extends State<CardTracker> {
  /// The player whose possible hand is shown under the grid.
  int? _seat;

  /// The eye is held down.
  bool _peekHeld = false;

  /// How far past the panel's padding its bronze rule runs (the panel's
  /// padding, less where [OrnateCard] draws the rule): the eye reaches
  /// out to meet it.
  static const _notchReach = 12.0 - OrnateCard.ruleInset;

  Round get cards => widget.cards;
  int get you => widget.you;
  List<Player> get players => widget.players;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final playedIn = <PlayingCard, (int, int)>{}; // trick number, seat
    for (var i = 0; i < cards.tricks.length; i++) {
      final t = cards.tricks[i];
      for (var k = 0; k < t.cards.length; k++) {
        playedIn[t.cards[k]] = (i + 1, t.seats[k]);
      }
    }
    for (var k = 0; k < cards.current.length; k++) {
      playedIn[cards.current[k]] = (cards.tricks.length + 1, cards.currentSeats[k]);
    }
    final mine = cards.hands.length > you ? cards.hands[you].toSet() : <PlayingCard>{};
    final guesses = guessHands(cards, you);
    // Who's known to hold each unplayed card: you, someone who showed it,
    // or someone it must belong to.
    final holder = <PlayingCard, int>{
      for (final c in mine) c: you,
      for (final g in guesses)
        for (final c in g.certain) c: g.seat,
    };
    final deck = fullDeck();
    // The Court Cards first, then each suit.
    const suits = [Suit.court, Suit.hearts, Suit.diamonds, Suit.spades, Suit.clubs];

    Widget cell(PlayingCard c, double w) {
      final p = playedIn[c];
      final h = holder[c];
      final edge = p != null
          ? players[p.$2].color
          : h != null
              ? players[h].color
              : null;
      final where = p != null
          ? 'played in trick ${p.$1} by ${players[p.$2].name}'
          : h == you
              ? 'in your hand'
              : h != null
                  ? 'held by ${players[h].name}'
                  : 'still to come';
      return Semantics(
        label: '${c.spoken}: $where',
        excludeSemantics: true,
        child: MiniCard(
            card: c, width: w, dimmed: p != null, edge: edge, trick: p?.$1),
      );
    }

    Widget swatch(Player p, {double size = 14}) => Container(
          width: size * 0.72,
          height: size,
          decoration: BoxDecoration(
            color: skin.card,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: p.color, width: 3),
            boxShadow: const [BoxShadow(spreadRadius: 1.2)],
          ),
        );

    Widget suitLabel(Suit suit) => SizedBox(
          width: 22,
          child: suit == Suit.court
              ? const CrownIcon(size: 14)
              : SuitText(suit.symbol,
                  keywords: false,
                  style: const TextStyle(fontSize: 16, color: Colors.white)),
        );

    // The key: everyone's colour. Tap someone else to see what they may
    // hold instead of the deck; tap the deck to come back.
    Widget deckChip() {
      final on = _seat == null;
      return Semantics(
        button: true,
        selected: on,
        label: 'Every card',
        child: Material(
          color: on ? skin.gold : const Color(0x33000000),
          shape: StadiumBorder(
              side: BorderSide(color: skin.gold.withValues(alpha: 0.7), width: 1.3)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            highlightColor: Colors.transparent,
            onTap: () => setState(() => _seat = null),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text('Deck',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: on ? skin.ink : Colors.white,
                      shadows: on ? null : skin.feltShadow)),
            ),
          ),
        ),
      );
    }

    Widget key(int seat) {
      final p = players[seat];
      final picked = _seat == seat;
      final label = Row(mainAxisSize: MainAxisSize.min, children: [
        swatch(p, size: 12),
        const SizedBox(width: 5),
        Text(seat == you ? 'You' : p.name.replaceFirst('The ', ''),
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: picked ? skin.ink : Colors.white,
                shadows: picked ? null : skin.feltShadow)),
      ]);
      if (seat == you) {
        return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: label);
      }
      return Semantics(
        button: true,
        selected: picked,
        label: 'What ${p.name} may hold',
        child: Material(
          color: picked ? skin.gold : const Color(0x33000000),
          shape: StadiumBorder(
              side: BorderSide(color: skin.gold.withValues(alpha: 0.7), width: 1.3)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            highlightColor: Colors.transparent,
            splashColor: skin.gold.withValues(alpha: 0.2),
            onTap: () => setState(() => _seat = seat),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              child: label,
            ),
          ),
        ),
      );
    }

    Widget guessBox(HandGuess g, double small) {
      Widget suitRow(Suit suit) {
        final cs = [
          for (final c in deck)
            if (c.suit == suit && g.possible.contains(c)) c
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(children: [
            suitLabel(suit),
            Expanded(
              child: g.voids.contains(suit) || cs.isEmpty
                  ? Text(g.voids.contains(suit) ? 'none' : 'none left',
                      style: const TextStyle(
                          fontSize: 13, fontStyle: FontStyle.italic, color: Colors.white54))
                  : Wrap(spacing: 3, runSpacing: 3, children: [
                      for (final c in cs)
                        MiniCard(
                            card: c,
                            width: small,
                            faint: !g.certain.contains(c),
                            edge: g.certain.contains(c) ? players[g.seat].color : null),
                    ]),
            ),
          ]),
        );
      }

      // The tracker's own edge turns their colour, so no box of its own.
      return Padding(
        key: ValueKey('guess-${g.seat}'),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${players[g.seat].name}: ${g.size} card${g.size == 1 ? '' : 's'}. '
                'Bright: certain. Faint: possible.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 6),
            for (final suit in suits) suitRow(suit),
          ],
        ),
      );
    }

    final picked = [for (final g in guesses) if (g.seat == _seat) g];
    return LayoutBuilder(builder: (context, box) {
      final w = math.min(34.0, (box.maxWidth - 8 * 3 - 1) / 9);
      final small = clampD(w * 0.7, 20, 34);
      // The deck's height: the Court Cards and four suits, a row each.
      final deckHeight = 5 * (w * 1.3 + 3);
      // Its edge turns the colour of whoever's hand is shown.
      return TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: _seat == null ? skin.gold : players[_seat!].color),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        builder: (context, edge, child) => OrnateCard(
          won: false,
          court: true,
          edge: edge,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: child!,
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The title and a cross.
          Row(children: [
            const SizedBox(width: 36),
            Expanded(
              child: Text('Card tracker',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: skin.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: skin.gold,
                      shadows: skin.feltShadow)),
            ),
            SizedBox(
              width: 36,
              child: IconButton(
                tooltip: 'Close',
                onPressed: widget.onClose,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(overlayColor: Colors.transparent),
                icon: Icon(Icons.close_rounded,
                    color: skin.gold, size: 22, shadows: skin.feltShadow),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          // The deck, or the chosen player's possible hand in its place: the
          // same height either way, so the tracker never changes size.
          SizedBox(
            height: deckHeight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, if (current != null) current]),
              child: picked.isNotEmpty
                  ? SingleChildScrollView(
                      key: ValueKey('hand-${picked.single.seat}'),
                      child: guessBox(picked.single, small))
                  : Column(
                      key: const ValueKey('deck'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final suit in suits)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 3,
                              runSpacing: 3,
                              children: [
                                for (final c in deck)
                                  if (c.suit == suit) cell(c, w)
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // Along the bottom: the deck and each player, then (in the
          // corner, easy to reach with a thumb) the eye to hold for a look at
          // the table.
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  deckChip(),
                  for (int s = 0; s < players.length; s++) key(s),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Set into the corner of the panel: its own top and left edges
            // meet the panel's bronze rule, which makes its other two
            // sides, round the same curve.
            Transform.translate(
              offset: const Offset(_notchReach, _notchReach),
              child: Tooltip(
                message: 'Hold to see the table',
                child: Listener(
                  onPointerDown: (_) {
                    setState(() => _peekHeld = true);
                    widget.onPeek?.call(true);
                  },
                  onPointerUp: (_) {
                    setState(() => _peekHeld = false);
                    widget.onPeek?.call(false);
                  },
                  onPointerCancel: (_) {
                    setState(() => _peekHeld = false);
                    widget.onPeek?.call(false);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: CustomPaint(
                      painter: _CornerNotch(skin: context.skin, held: _peekHeld),
                      child: SizedBox(
                        width: 54,
                        height: 42,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 3, top: 3),
                          child: Icon(Icons.visibility_rounded,
                              color: skin.gold, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
      );
    });
  }

  /// The arrow keys: step through the deck and each other player's hand.
  void step(int dir) {
    final order = <int?>[null, for (int s = 0; s < players.length; s++) if (s != you) s];
    final at = order.indexOf(_seat);
    setState(() => _seat = order[(at + dir) % order.length]);
  }

}

/// The eye's corner of the card tracker: a tint following the panel's
/// rounded corner, with a bronze line along its top and left only, curved
/// like the panel's own rule ([OrnateCard.ruleRadius]).
class _CornerNotch extends CustomPainter {
  const _CornerNotch({required this.skin, required this.held});
  final Skin skin;
  final bool held;

  @override
  void paint(Canvas canvas, Size size) {
    const r = Radius.circular(OrnateCard.ruleRadius);
    final rect = Offset.zero & size;
    canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: r, bottomRight: r),
        Paint()..color = held ? skin.gold.withValues(alpha: 0x33 / 255) : const Color(0x33000000));
    final edge = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, r.y)
      ..arcToPoint(Offset(r.x, 0), radius: r)
      ..lineTo(size.width, 0);
    canvas.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = OrnateCard.ruleWidth
          ..color = OrnateCard.ruleColour(skin.gold));
  }

  @override
  bool shouldRepaint(_CornerNotch old) => old.held != held || old.skin != skin;
}
