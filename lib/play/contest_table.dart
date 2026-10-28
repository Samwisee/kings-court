import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/cards.dart';
import '../engine/contest.dart';
import '../theme.dart';
import 'card_view.dart';

/// The Trial of Hearts: a round of hearts that settles a divided court.
/// Sides stay secret until the end, so everyone plays for themselves.
class ContestTable extends StatefulWidget {
  const ContestTable({
    super.key,
    required this.contest,
    required this.you,
    required this.names,
    required this.colors,
    required this.token,
    required this.labelA,
    required this.labelB,
    required this.onDone,
    this.botDelay = const Duration(milliseconds: 650),
    this.trickPause = const Duration(milliseconds: 1100),
  });

  final ContestState contest;
  final int you;
  final List<String> names;
  final List<Color> colors;
  final Widget Function(int seat, double size) token;
  final String labelA, labelB;
  final VoidCallback onDone;
  final Duration botDelay, trickPause;

  @override
  State<ContestTable> createState() => ContestTableState();
}

class ContestTableState extends State<ContestTable> {
  Timer? _timer;

  /// The trick just won, shown for a moment before it's cleared.
  Trick? _shown;

  ContestState get c => widget.contest;

  @override
  void initState() {
    super.initState();
    _next();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() {
    _timer?.cancel();
    if (c.over || _shown != null || c.turn == widget.you) return;
    _timer = Timer(widget.botDelay, () {
      if (!mounted) return;
      _play(c.turn, c.botPlay(c.turn));
    });
  }

  void _play(int seat, PlayingCard card) {
    final trick = c.play(seat, card);
    setState(() => _shown = trick);
    if (trick != null) {
      _timer = Timer(widget.trickPause, () {
        if (!mounted) return;
        setState(() => _shown = null);
        _next();
      });
    } else {
      _next();
    }
  }

  /// For tests: plays your weakest legal card when it's your turn.
  void debugYourMove() {
    if (!c.over && _shown == null && c.turn == widget.you) {
      _play(widget.you, c.legalFor(widget.you).first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final others = [for (int s = 0; s < c.players; s++) if (s != widget.you) s];
    final yourTurn = !c.over && _shown == null && c.turn == widget.you;
    final onTable = _shown ?? Trick(c.leader, c.seats, c.current, -1);
    final status = c.over
        ? '${c.aWins ? widget.labelA : widget.labelB}: the cards have spoken'
        : _shown != null
            ? '${_shown!.winner == widget.you ? 'You take' : '${widget.names[_shown!.winner]} takes'} the trick'
            : yourTurn
                ? (c.current.isEmpty ? 'Your lead' : 'Your turn: follow ${c.current.first.isCourt ? 'Court Cards' : c.current.first.suit.name} if you can')
                : '${widget.names[c.turn]} is thinking';
    return ColoredBox(
      color: Palette.feltDeep,
      child: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final cardW = math.min(74.0, (w - 32) / 5.4);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                const Text('Trial of Hearts',
                    style: TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        color: Palette.gold)),
                const Text(
                    'Court Cards are just a suit here: only the suit led can win. Every ♥ you win is a mark of shame, and the Queen is five. Hearts can\u2019t be led until one falls. Sides stay secret: fewest marks per courtier wins, and a tie goes to the King.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _score(true)),
                  const SizedBox(width: 8),
                  Expanded(child: _score(false)),
                ]),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in others)
                      Expanded(child: _seat(s, active: !c.over && _shown == null && c.turn == s)),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (int i = 0; i < onTable.cards.length; i++)
                          TweenAnimationBuilder<double>(
                            key: ValueKey('contest-${onTable.cards[i].id}'),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            builder: (context, t, child) => Transform.translate(
                                offset: Offset(0, 40 * (1 - t)),
                                child: Opacity(opacity: t, child: child)),
                            child: PlayingCardView(
                              card: onTable.cards[i],
                              width: cardW,
                              edge: widget.colors[onTable.seats[i]],
                              glow: _shown != null &&
                                  onTable.seats[i] == _shown!.winner,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                      fontFamily: bodyFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: yourTurn || c.over ? Palette.gold : Colors.white70),
                  child: Text(status, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    widget.token(widget.you, 34),
                    const SizedBox(width: 8),
                    _sideChip(widget.you, always: true),
                    const SizedBox(width: 8),
                    _shameChip(widget.you),
                  ],
                ),
                const SizedBox(height: 8),
                if (c.over)
                  FilledButton(
                    onPressed: widget.onDone,
                    style: FilledButton.styleFrom(
                        backgroundColor: Palette.gold,
                        foregroundColor: Palette.ink),
                    child: const Text('Let it be done'),
                  )
                else
                  () {
                    // Your hand fans out across the width, overlapping when
                    // it's long.
                    final hand = c.hands[widget.you];
                    final handW = math.min(64.0, (w - 32) / 4.5);
                    final avail = w - 32;
                    final step = hand.length < 2
                        ? 0.0
                        : math.min(handW + 4, (avail - handW) / (hand.length - 1));
                    final span = hand.isEmpty ? 0.0 : handW + step * (hand.length - 1);
                    final legal = yourTurn ? c.legalFor(widget.you) : const <PlayingCard>[];
                    return SizedBox(
                      height: PlayingCardView.heightFor(handW) + 8,
                      width: avail,
                      child: Stack(children: [
                        for (int i = 0; i < hand.length; i++)
                          Positioned(
                            left: (avail - span) / 2 + i * step,
                            top: legal.contains(hand[i]) ? 0 : 8,
                            child: MouseRegion(cursor: legal.contains(hand[i]) ? SystemMouseCursors.click : MouseCursor.defer, child: GestureDetector(
                              onTap: legal.contains(hand[i])
                                  ? () => _play(widget.you, hand[i])
                                  : null,
                              child: PlayingCardView(
                                card: hand[i],
                                width: handW,
                                dimmed: yourTurn && !legal.contains(hand[i]),
                              ),
                            )),
                          ),
                      ]),
                    );
                  }(),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _score(bool a) {
    final avg = c.sideShame(a);
    final winning = c.over && c.aWins == a;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: winning ? const Color(0x33F2C14E) : Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: winning ? Palette.gold : Colors.white24),
      ),
      child: Column(children: [
        Text('${a ? 'A' : 'B'}. ${a ? widget.labelA : widget.labelB}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 4),
        Text(
            c.over
                ? (avg == avg.roundToDouble()
                    ? avg.toInt().toString()
                    : avg.toStringAsFixed(1))
                : '?',
            style: const TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w900,
                fontSize: 28,
                color: Palette.gold)),
      ]),
    );
  }

  /// Marks of shame taken so far.
  Widget _shameChip(int seat) => Text('♥ ${c.shame(seat)}',
      style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFFF8A8A)));

  /// Which side [seat] took: hidden until the end, except your own.
  Widget _sideChip(int seat, {bool always = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Palette.ink,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Palette.gold),
        ),
        child: Text(always || c.over ? (c.sideA[seat] ? 'A' : 'B') : '?',
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 12, color: Palette.gold)),
      );

  Widget _seat(int s, {required bool active}) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: active ? 1.1 : 1,
            duration: const Duration(milliseconds: 200),
            child: widget.token(s, 34),
          ),
          Text(widget.names[s],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _sideChip(s),
            const SizedBox(width: 6),
            _shameChip(s),
          ]),
        ],
      );
}
