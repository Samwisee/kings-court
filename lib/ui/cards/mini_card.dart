/// Small cards: in the tracker, a task’s close-up and shown cards.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../skin/looks.dart';
import '../../skin/skin_scope.dart';
import '../widgets.dart';

/// A plain card face for the card tracker: just its number and suit (or
/// the Court Card's letter) and an outline, cheap enough to show dozens.
class MiniCard extends StatelessWidget {
  const MiniCard(
      {super.key,
      required this.card,
      required this.width,
      this.dimmed = false,
      this.edge,
      this.trick,
      this.faint = false});

  /// Only possibly there: drawn in faded colours (cheaper than making it
  /// see-through).
  final bool faint;
  final PlayingCard card;
  final double width;

  /// Played: greyed inside, but its outline stays bright.
  final bool dimmed;
  final Color? edge;

  /// The trick it was played in, shown in its corner.
  final int? trick;

  Color _small(CardLook look) {
    final i = card.rank - 1;
    return look.small?[i] ?? Color.lerp(look.cloth[i][0], look.cloth[i][1], 0.5)!;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final court = card.isCourt;
    final felt = skin.feltDeep;
    final fade = faint ? 0.55 : 0.0;
    // A Court Card on its cloth in gold, or (a skin whose Court Cards are
    // letters) on the card stock in its cloth's colour.
    final cloth = court && skin.cardLook.courtStyle == CourtCardStyle.emblems;
    final ink = Color.lerp(
        cloth
            ? skin.gold
            : court
                ? skin.cardLook.cloth[card.rank - 1][0]
                : skin.suitColour(card.suit),
        felt,
        fade)!;
    final face = Color.lerp(
        cloth
            ? Color.lerp(_small(skin.cardLook), Colors.black, dimmed ? 0.5 : 0)!
            : dimmed
                ? const Color(0xFFB4AFA4)
                : skin.card,
        felt,
        fade)!;
    final r = width * 0.14;
    final edgeW = edge != null ? math.max(2.5, width * 0.08) : 1.0;
    // Nudged up a little: the suit's glyph sits low in its line.
    final label = Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            width * 0.06, width * 0.02, width * 0.06, width * 0.14),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: card.rankLabel,
                  style: TextStyle(
                      fontFamily: court ? skin.displayFont : skin.bodyFont,
                      fontWeight: FontWeight.w900,
                      fontSize: width * 0.5)),
              if (!court) ...[
                const TextSpan(text: '\n'),
                WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(top: width * 0.06),
                      child: SuitIcon(card.suit, size: width * 0.38, color: ink),
                    )),
              ],
            ]),
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.0, color: ink),
          ),
        ),
      ),
    );
    // A coloured outline is edged in black on both sides, so it stands out
    // from the felt and from the card face alike.
    return Container(
      width: width,
      height: width * 1.3,
      decoration: BoxDecoration(
        color: skin.outlineColour,
        borderRadius: BorderRadius.circular(r),
      ),
      padding: EdgeInsets.all(edge != null ? 1.2 : 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: face,
          borderRadius: BorderRadius.circular(r - 1),
          border: Border.all(
              color: edge ??
                  Color.lerp(cloth ? skin.gold : const Color(0xFFD9D2C3),
                      felt, fade)!,
              width: edgeW),
        ),
        // Inside the border, as a Container would place it (the refactor's
        // lint fix to DecoratedBox lost this inset; docs/DECISIONS.md).
        child: Padding(
          padding: EdgeInsets.all(edgeW),
          child: DecoratedBox(
          decoration: edge != null
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(math.max(0, r - edgeW)),
                  border: Border.all(color: skin.outlineColour),
                )
              : const BoxDecoration(),
          child: Padding(
            padding: EdgeInsets.all(edge != null ? 1 : 0),
            child: Stack(children: [
            Positioned.fill(child: label),
            if (trick != null)
              Positioned(
                right: width * 0.04,
                bottom: 0,
                child: _OutlinedNumber('$trick',
                    size: width * 0.28, color: edge ?? Colors.white),
              ),
          ]),
          ),
        ),
        ),
      ),
    );
  }
}

/// A small number in a colour, ringed in black so it reads on anything.
class _OutlinedNumber extends StatelessWidget {
  const _OutlinedNumber(this.text, {required this.size, required this.color});
  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontSize: size, fontWeight: FontWeight.w900, height: 1.05);
    return Stack(children: [
      Text(text,
          style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = math.max(2.5, size * 0.22)
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.black)),
      Text(text, style: style.copyWith(color: color)),
    ]);
  }
}
