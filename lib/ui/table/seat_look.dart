/// In a game with other people, each person's cards are shown in the look
/// they play in: the faces of the cards they play, and the backs of the
/// tricks they win and the card they show. Another's look, at your table.
library;

import 'package:flutter/widgets.dart';

import '../../skin/entitlements.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';

/// The look each seat plays in (a seat not in [looks]: the table's own),
/// for the table under it. Its cards rebuild only when a look changes, not
/// with every move.
class SeatLooks extends InheritedWidget {
  const SeatLooks({super.key, required this.looks, required super.child});
  final Map<int, Skin> looks;

  Skin? of(int seat) => looks[seat];

  @override
  bool updateShouldNotify(SeatLooks old) =>
      old.looks.length != looks.length || looks.entries.any((e) => old.looks[e.key]?.id != e.value.id);
}

/// [child] (a card, or a pile of them) in the look the person in [seat]
/// plays in.
class SeatLook extends StatelessWidget {
  const SeatLook({super.key, required this.seat, required this.child});
  final int seat;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final look = context.dependOnInheritedWidgetOfExactType<SeatLooks>()?.of(seat);
    if (look == null || look.id == context.skin.id) return child;
    final entitlements =
        context.getInheritedWidgetOfExactType<SkinScope>()?.entitlements ?? const AllOwned();
    return SkinScope(skin: look, entitlements: entitlements, child: child);
  }
}
