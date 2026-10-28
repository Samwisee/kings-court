/// The trick in the middle of the on-screen table.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/round.dart';
import '../../game/state.dart';
import '../cards/card_view.dart';
import '../widgets.dart';

/// How wide trick cards are for a table [width] across with [n] players.
double trickCardWidth(double width, int n) =>
    clampD((width - 8 * n) / n, 34, width > 600 ? 100 : 64);

/// The trick in the middle of the table, in an [area]: each card glides in
/// from whoever played it ([origin], in the area's coordinates; null to
/// fade in), and once won ([trick], still on the table) sweeps off to the
/// winner while [collecting].
List<Widget> trickCards({
  required Size area,
  required Round round,
  required Trick? trick,
  required bool collecting,
  required List<Player> players,
  required Offset? Function(int seat, PlayingCard card) origin,
}) {
  if (!round.hasCards) return [];
  final c = round;
  final seats = trick?.seats ?? c.currentSeats;
  final cards = trick?.cards ?? c.current;
  if (cards.isEmpty) return [];
  final number = trick != null ? c.tricks.length - 1 : c.tricks.length;
  final n = c.players;
  // The same size every trick: set by the table's width, shrinking only
  // if the middle is truly short of room.
  final cardW = clampD(math.min(trickCardWidth(area.width, n),
      (area.height - 4) / 1.42), 34, 100);
  final cardH = PlayingCardView.heightFor(cardW);
  Offset topLeft(Offset centre) => centre - Offset(cardW / 2, cardH / 2);
  return [
    for (int i = 0; i < cards.length; i++)
      () {
        final target = Offset(
            area.width / 2 + (i - (n - 1) / 2) * (cardW + 8),
            area.height / 2);
        final seat = seats[i];
        final view = PlayingCardView(
          card: cards[i],
          width: cardW,
          // Edged in the colour of whoever played it.
          edge: players[seat].color,
          glow: trick != null && trick.winner == seat,
        );
        if (trick != null && collecting) {
          final to = origin(trick.winner, cards[i]) ?? target;
          return TweenAnimationBuilder<double>(
            key: ValueKey('collect-$number-${cards[i].id}'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInCubic,
            builder: (context, t, child) {
              final p = topLeft(Offset.lerp(target, to, t)!);
              return Positioned(
                left: p.dx,
                top: p.dy,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: clampD(1 - t, 0, 1),
                    child: Transform.scale(scale: 1 - 0.5 * t, child: child),
                  ),
                ),
              );
            },
            child: view,
          );
        }
        final from = origin(seat, cards[i]);
        return TweenAnimationBuilder<double>(
          key: ValueKey('play-$number-${cards[i].id}'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            final p = topLeft(Offset.lerp(from ?? target, target, t)!);
            return Positioned(
              left: p.dx,
              top: p.dy,
              child: IgnorePointer(
                child: Opacity(
                    opacity: from == null ? clampD(t * 2, 0, 1) : 1,
                    child: child),
              ),
            );
          },
          child: view,
        );
      }(),
  ];
}
