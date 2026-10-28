/// The royal decree: the scroll over the whole table when a round opens
/// under one, until it is accepted, and the same scroll as a dialog when
/// the seal on the table is tapped.
library;

import 'package:flutter/material.dart';

import '../../engine/decrees.dart';
import '../../engine/round.dart';
import '../../models.dart';
import '../../widgets.dart';

/// What the decree means at this table, when it names a seat.
String? decreeDetail(Round round, List<Player> players) =>
    round.decree == Decree.exile && round.exiledSeat != null
        ? 'Seat ${seatLabels(players)[round.exiledSeat!]} is exiled this round.'
        : null;

/// The decree over a darkened table; [onAccept] when it has been read.
class DecreeOverlay extends StatelessWidget {
  const DecreeOverlay(
      {super.key,
      required this.round,
      required this.players,
      required this.onAccept});

  final Round round;
  final List<Player> players;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black38,
        child: Center(
          child: DecreeScroll(
            decree: round.decree!,
            detail: decreeDetail(round, players),
            onAccept: onAccept,
          ),
        ),
      );
}

/// The round's decree again, as a dialog; nothing without one.
void showDecree(BuildContext context, Round round, List<Player> players) {
  final d = round.decree;
  if (d == null) return;
  showDialog<void>(
    context: context,
    builder: (context) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: DecreeScroll(
          decree: d,
          detail: decreeDetail(round, players),
          onAccept: () => Navigator.pop(context),
        ),
      ),
    ),
  );
}
