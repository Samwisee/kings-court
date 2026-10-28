/// The round table (ui/round_table/round_table.dart): its controller lays
/// the deal out and follows a drag; the widget shows the seats, the King
/// prompt before the crowning and the cards after, and hands taps and
/// drops to the page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/round.dart';
import 'package:kings_court/models.dart';
import 'package:kings_court/ui/overlays/king_prompt.dart';
import 'package:kings_court/ui/round_table/geometry.dart';
import 'package:kings_court/ui/round_table/round_table.dart';
import 'package:kings_court/widgets.dart';

const tableSize = Size(600, 400);

GameState fourSeats() {
  final g = GameState()
    ..players = [for (var i = 0; i < 4; i++) Player('P$i', colorValue: 0xFF336699)]
    ..startRound(4, 6);
  return g;
}

TableGeometry geoFor(RoundTableController table, GameState g) => table.geometry(
    players: g.players.length,
    textOf: (t) => t.boardText(g.players.length),
    upright: false,
    dealId: g.dealId);

void main() {
  testWidgets('The controller deals the cards out, stacks owned ones and follows a drag', (tester) async {
    final table = RoundTableController(vsync: tester);
    final g = fourSeats();
    table.tableSize = tableSize;
    expect(table.dealtFor, -1);
    final geo = geoFor(table, g);
    table.dealCards(geo, g.tasks, g.dealId);
    expect(table.dealtFor, g.dealId);
    expect(table.order, g.tasks);
    expect(table.pos.length, g.tasks.length);
    expect(table.cardWidth, geo.cardWidth);
    // Every card lies on the table, as a fraction of it.
    for (final p in table.pos.values) {
      expect(p.dx, inInclusiveRange(0, 1));
      expect(p.dy, inInclusiveRange(0, 1));
    }
    // Picked up, a card comes to the top; moved, it follows the finger,
    // stays on the table, and says which seat it's over, if one may take it.
    final t = g.tasks.first;
    table.dragStart(t);
    expect(table.dragging, t);
    expect(table.order.last, t);
    final before = table.toPx(table.pos[t]!);
    expect(table.dragMove(t, const Offset(10, 5), geo, (_, __) => false), isNull);
    expect(table.toPx(table.pos[t]!), offsetMoreOrLessEquals(before + const Offset(10, 5)));
    table.dragMove(t, const Offset(5000, 5000), geo, (_, __) => true);
    final clamped = table.toPx(table.pos[t]!);
    expect(clamped.dx, lessThan(tableSize.width));
    expect(clamped.dy, lessThan(tableSize.height));
    // Dropped on a seat (by the card's centre when the finger's unknown).
    expect(table.dropSeat(geo, geo.seatCenter(1)), 1);
    expect(table.dropSeat(geo, geo.center), isNull);
    // Reset clears everything for the next deal.
    table.reset();
    expect(table.dealtFor, -1);
    expect(table.pos, isEmpty);
    table.dispose();
  });

  testWidgets('The table shows the prompt until the King is crowned, then the cards', (tester) async {
    final table = RoundTableController(vsync: tester);
    final g = fourSeats();
    final taps = <int>[];
    var dealt = false;
    Widget build({required bool choosingKing, required bool readyToDeal}) => MaterialApp(
        home: SizedBox(
            width: tableSize.width,
            height: tableSize.height,
            child: RoundTable(
              table: table,
              game: g,
              geometry: () => geoFor(table, g),
              onScreen: false,
              choosingKing: choosingKing,
              crowning: null,
              crownAnimation: const AlwaysStoppedAnimation(0),
              playAnimation: const AlwaysStoppedAnimation(0),
              readyToDeal: readyToDeal,
              onDeal: () {
                dealt = true;
                table.dealCards(geoFor(table, g), g.tasks, g.dealId);
              },
              seatTap: (i) => () => taps.add(i),
              cardText: (t) => t.boardText(4),
              onTaskTap: (_, __) {},
              onDragStart: (_) {},
              onDragUpdate: (_, __) {},
              onDragEnd: (_) {},
            )));
    await tester.pumpWidget(build(choosingKing: true, readyToDeal: false));
    expect(find.byType(SeatToken), findsNWidgets(4));
    expect(find.byType(KingPrompt), findsOneWidget);
    expect(find.byType(TableCard), findsNothing);
    await tester.tap(find.byType(SeatToken).at(2));
    expect(taps, [2]);
    // Crowned: the cards are dealt after the frame and lie on the felt.
    await tester.pumpWidget(build(choosingKing: false, readyToDeal: true));
    expect(dealt, isTrue);
    await tester.pumpWidget(build(choosingKing: false, readyToDeal: false));
    await tester.pumpAndSettle();
    expect(find.byType(KingPrompt), findsNothing);
    expect(find.byType(TableCard), findsNWidgets(g.tasks.length));
    table.dispose();
  });
}
