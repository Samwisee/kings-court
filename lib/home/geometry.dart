// Where everything sits on the table: seats round the edge, the cards in the middle, the dealt tasks.
part of '../main.dart';

/// Where everything sits on the table for a given screen size. The phone
/// lies in the middle of the table, so seats are spread evenly around its
/// edge and turned to face the player sitting there.
class _TableGeometry {
  _TableGeometry(this.size, this.players, this.textOf,
      {double? fixedCardWidth, this.upright = false})
      : seatSize = clampD(math.min(size.width, size.height) * 0.13, 36, 64) {
    seatExtent = seatSize + 32; // token, with room for the crown
    rx = size.width / 2 - seatExtent / 2 - trimInset;
    ry = size.height / 2 - seatExtent / 2 - trimInset;
    cardWidth = fixedCardWidth ??
        // Bigger on a big screen, so the table is easy to read from a
        // distance.
        clampD(math.min(size.width, size.height) * 0.27, 92, 172);
  }

  final Size size;
  final int players;

  /// Laptop view: nothing turns to face its seat; everything reads the
  /// right way up for one screen.
  final bool upright;

  /// Seats and cards stay inside the brass inlay round the table edge.
  static const trimInset = 14.0;

  /// The part of the table inside the inlay.
  Rect get playArea => (Offset.zero & size).deflate(trimInset);

  /// The wording printed on each task's card, which decides its height.
  final String Function(Task) textOf;
  final double seatSize;
  late final double seatExtent;
  late final double rx;
  late final double ry;
  late double cardWidth;

  Offset get center => size.center(Offset.zero);
  double get cardHeight => TableCard.heightFor(cardWidth);

  static final _sizeCache = <String, Size>{};

  /// A task card's upright size: usual width, taller for long tasks.
  Size cardSize(Task t) {
    final text = textOf(t);
    final sealed = t.seal != null;
    return _sizeCache.putIfAbsent('$cardWidth|$sealed|$text',
        () => TableCard.sizeFor(text, cardWidth, sealed: sealed));
  }

  /// Seat 0 sits at the bottom edge (whoever is holding the phone); the
  /// rest follow clockwise at equal angles.
  double seatAngle(int i) => math.pi / 2 + i * 2 * math.pi / players;

  Offset seatCenter(int i) {
    final a = seatAngle(i);
    return center + Offset(rx * math.cos(a), ry * math.sin(a));
  }

  double _turn(int i) => seatAngle(i) - math.pi / 2;

  /// The seat's frame snapped to the nearest table edge. Cards are laid
  /// out in this frame (their "up" points into the table) even when the
  /// view is upright.
  double _frame(int i) =>
      (_turn(i) / (math.pi / 2)).roundToDouble() * (math.pi / 2);

  /// Rotation that turns a widget's bottom edge towards seat [i].
  double facing(int i) => upright ? 0 : _turn(i);

  /// [facing] snapped to the nearest table edge, so a player's cards are
  /// always square to them and easy to read.
  double cardFacing(int i) => upright ? 0 : _frame(i);

  /// Which table edge seat [i] faces: 0 bottom, 1 left, 2 top, 3 right.
  int edge(int i) =>
      upright ? 0 : ((_frame(i) / (math.pi / 2)).round() % 4 + 4) % 4;

  /// Screen size of [t] when owned by seat [i] (side seats turn it
  /// sideways).
  Size ownedCardSize(int i, Task t) {
    final s = cardSize(t);
    return edge(i).isOdd ? Size(s.height, s.width) : s;
  }

  /// Lays out every owned card so that no two cards overlap each other, a
  /// seat, or the table edge.
  ///
  /// Each card goes in the free spot nearest its owner: first in front of
  /// the seat, then beside it along the table edge, then further in. Spots
  /// are worked out in the owner's frame (their right, and "up" towards
  /// the middle), so every card sits square to the person who holds it.
  Map<Task, Offset> layoutOwned(List<Task> order,
      {List<Rect> obstacles = const []}) {
    // Keep clear of the loose cards too, unless that leaves no room.
    final first = _layoutOwned(order, obstacles);
    if (!first.crowded || obstacles.isEmpty) return first.spots;
    return _layoutOwned(order, const []).spots;
  }

  ({Map<Task, Offset> spots, bool crowded}) _layoutOwned(
      List<Task> order, List<Rect> obstacles) {
    var crowded = false;
    final table = playArea;
    final placed = <Rect>[
      // Cards still waiting to be taken: owned cards keep clear of them.
      ...obstacles,
      for (int i = 0; i < players; i++)
        // The whole seat: crown above the token, name below it. Seats can
        // be turned at any angle, so keep a square clear around them.
        Rect.fromCenter(
            center: seatCenter(i),
            width: seatSize + 34,
            height: seatSize + 34),
    ];
    const gap = 6.0;
    final result = <Task, Offset>{};
    // Whose card each placed rect is (null for seats and loose cards), so
    // a crowded stack may squeeze onto itself but never a neighbour's.
    final placedBy = <int?>[for (final _ in placed) null];

    for (var i = 0; i < players; i++) {
      final owned = order.where((t) => t.assignedPlayerIndex == i).toList();
      if (owned.isEmpty) continue;
      final a = _frame(i);
      final right = Offset(math.cos(a), math.sin(a));
      final up = Offset(math.sin(a), -math.cos(a));
      final seat = seatCenter(i);
      // Half the seat's footprint in the owner's frame: the token, plus
      // the crown above it.
      final tokenHalfW = seatSize / 2 + 8;
      final tokenHalfH = seatSize / 2 + 17;

      // Rows as tall as this seat's tallest card, so a stack of long tasks
      // still has room.
      final rowH = owned
          .map((t) => ownedCardSize(i, t).height)
          .fold<double>(cardHeight, math.max);
      // Candidate spots in the owner's frame, nearest first.
      final spots = <Offset>[];
      for (var row = 0; row < 6; row++) {
        for (var col = -4; col <= 4; col++) {
          final dx = col * (cardWidth + gap);
          final dy = row == 0
              ? 0.0
              : tokenHalfH + rowH / 2 + gap + (row - 1) * (rowH + gap);
          // The row level with the seat can't use the seat's own spot.
          if (row == 0 && col.abs() * (cardWidth + gap) < tokenHalfW + cardWidth / 2) {
            continue;
          }
          spots.add(Offset(dx, dy));
        }
      }
      spots.sort((p, q) => p.distance.compareTo(q.distance));

      for (final t in owned) {
        final size = ownedCardSize(i, t);
        Offset? chosen;
        Rect? chosenRect;
        for (final s in spots) {
          final p = seat + right * s.dx + up * s.dy;
          final rect = Rect.fromCenter(
              center: p, width: size.width, height: size.height);
          final onTable = table.contains(rect.topLeft) &&
              table.contains(rect.bottomRight - const Offset(1, 1));
          if (onTable && !placed.any((r) => r.deflate(1).overlaps(rect))) {
            chosen = p;
            chosenRect = rect;
            break;
          }
        }
        if (chosen == null) {
          crowded = true;
          // No clear spot: overlap this seat's own cards rather than a
          // neighbour's.
          for (final s in spots) {
            final p = seat + right * s.dx + up * s.dy;
            final rect = Rect.fromCenter(
                center: p, width: size.width, height: size.height);
            final onTable = table.contains(rect.topLeft) &&
                table.contains(rect.bottomRight - const Offset(1, 1));
            var clear = onTable;
            for (var k = 0; clear && k < placed.length; k++) {
              if (placedBy[k] != i && placed[k].deflate(1).overlaps(rect)) {
                clear = false;
              }
            }
            if (clear) {
              chosen = p;
              chosenRect = rect;
              break;
            }
          }
        }
        // Table completely full: fan this card over the seat's own last
        // card, so it never lands on a neighbour's.
        final mine = [
          for (int k = 0; k < placed.length; k++)
            if (placedBy[k] == i) placed[k]
        ];
        if (chosen == null && mine.isNotEmpty) {
          chosen = mine.last.center + right * 10 + up * 10;
        }
        chosen ??= clampToTable(seat + up * (tokenHalfH + cardHeight / 2));
        chosenRect ??= Rect.fromCenter(
            center: chosen, width: size.width, height: size.height);
        result[t] = chosen;
        placed.add(chosenRect);
        placedBy.add(i);
      }
    }
    return (spots: result, crowded: crowded);
  }

  /// Positions for freshly dealt cards: a neat grid in the open middle of
  /// the table, shrinking the cards if needed so they all fit. Each row is
  /// as tall as its tallest card.
  List<Offset> dealPositions(List<Task> tasks) {
    final count = tasks.length;
    final innerW = math.max(size.width - 2 * (seatExtent + 6), cardWidth);
    final innerH = math.max(size.height - 2 * (seatExtent + 6), cardHeight);
    const gap = 8.0;

    var cols = 1;
    var rowHeights = <double>[];
    while (true) {
      cols = math.max(1, ((innerW + gap) / (cardWidth + gap)).floor());
      rowHeights = [
        for (int r = 0; r * cols < count; r++)
          tasks
              .skip(r * cols)
              .take(cols)
              .map((t) => cardSize(t).height)
              .reduce(math.max),
      ];
      final gridH = rowHeights.fold(0.0, (a, h) => a + h) +
          gap * (rowHeights.length - 1);
      if (gridH <= innerH || cardWidth <= 72) break;
      cardWidth -= 4;
    }

    final gridH =
        rowHeights.fold(0.0, (a, h) => a + h) + gap * (rowHeights.length - 1);
    final result = <Offset>[];
    var top = center.dy - gridH / 2;
    for (var r = 0; r < rowHeights.length; r++) {
      final inRow = math.min(cols, count - r * cols);
      final rowW = inRow * (cardWidth + gap) - gap;
      for (var c = 0; c < inRow; c++) {
        result.add(Offset(
          center.dx - rowW / 2 + c * (cardWidth + gap) + cardWidth / 2,
          top + rowHeights[r] / 2,
        ));
      }
      top += rowHeights[r] + gap;
    }
    return result;
  }

  /// The seat closest to [p]: the side of the table someone is touching.
  int nearestSeat(Offset p) {
    var best = 0;
    for (var i = 1; i < players; i++) {
      if ((seatCenter(i) - p).distance < (seatCenter(best) - p).distance) {
        best = i;
      }
    }
    return best;
  }

  /// The seat a card centred at [p] is being dropped on, if any.
  int? seatAt(Offset p) {
    for (var i = 0; i < players; i++) {
      if ((seatCenter(i) - p).distance < seatSize / 2 + 34) return i;
    }
    return null;
  }

  /// Keeps a card on the table whichever way it is turned.
  Offset clampToTable(Offset p, [Size? card]) {
    final c = card ?? Size(cardWidth, cardHeight);
    final half = math.max(c.width, c.height) / 2;
    final area = playArea;
    return Offset(
      clampD(p.dx, area.left + half, area.right - half),
      clampD(p.dy, area.top + half, area.bottom - half),
    );
  }
}

/// Something the arrow keys can stop on: a card in your hand (row 0), a
/// task (row 1) or the button beside your hand (row 2), and where it is.
class _KbStop {
  const _KbStop(this.row, this.item, this.rect);
  final int row;
  final Object? item;
  final Rect rect;
}
