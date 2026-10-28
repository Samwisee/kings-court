/// Who holds each seat at the table: a person (by id, connected or not), a
/// courtier (a bot), or nobody yet. The host plays the courtiers' seats and
/// the seats of people who have dropped; a person who returns takes their
/// seat back. Plain data with JSON, so a room can tell every device who
/// sits where.
library;

sealed class SeatHolder {
  const SeatHolder();

  Map<String, dynamic> toJson();

  static SeatHolder fromJson(Map<String, dynamic> j) => switch (j['who']) {
        'person' =>
          Person(j['id'] as String, connected: (j['connected'] as bool?) ?? true),
        'courtier' => const CourtierSeat(),
        _ => const EmptySeat(),
      };
}

/// A person, by the id their session gave them.
class Person extends SeatHolder {
  const Person(this.id, {this.connected = true});
  final String id;
  final bool connected;

  Person copyWith({bool? connected}) =>
      Person(id, connected: connected ?? this.connected);

  @override
  Map<String, dynamic> toJson() => {'who': 'person', 'id': id, 'connected': connected};

  @override
  bool operator ==(Object other) =>
      other is Person && other.id == id && other.connected == connected;
  @override
  int get hashCode => Object.hash(id, connected);
}

/// A courtier plays this seat.
class CourtierSeat extends SeatHolder {
  const CourtierSeat();
  @override
  Map<String, dynamic> toJson() => const {'who': 'courtier'};
  @override
  bool operator ==(Object other) => other is CourtierSeat;
  @override
  int get hashCode => 1;
}

/// Nobody yet.
class EmptySeat extends SeatHolder {
  const EmptySeat();
  @override
  Map<String, dynamic> toJson() => const {'who': 'empty'};
  @override
  bool operator ==(Object other) => other is EmptySeat;
  @override
  int get hashCode => 2;
}

class Seats {
  Seats(int count) : holders = List.filled(count, const EmptySeat());
  Seats.of(List<SeatHolder> holders) : holders = List.of(holders);

  /// One device playing against courtiers: [you] a person, the rest
  /// courtiers.
  Seats.solo(int count, {int you = 0, String id = 'you'})
      : holders = [
          for (var s = 0; s < count; s++)
            s == you ? Person(id) : const CourtierSeat()
        ];

  final List<SeatHolder> holders;

  int get count => holders.length;

  /// The seat [id] holds, or null.
  int? seatOf(String id) {
    for (var s = 0; s < holders.length; s++) {
      if (holders[s] case Person(id: final held) when held == id) return s;
    }
    return null;
  }

  /// The first empty seat, or null when the table is full.
  int? get firstEmpty {
    final i = holders.indexWhere((h) => h is EmptySeat);
    return i < 0 ? null : i;
  }

  /// Whether the host makes the moves for [seat]: a courtier's, a person's
  /// who has dropped, or an empty one.
  bool hostPlays(int seat) => switch (holders[seat]) {
        Person(:final connected) => !connected,
        CourtierSeat() => true,
        EmptySeat() => true,
      };

  /// Whether [seat] is played by a person who is there.
  bool present(int seat) => switch (holders[seat]) {
        Person(:final connected) => connected,
        _ => false,
      };

  /// [id] takes [seat] (their old one again, or an empty one).
  void sit(String id, int seat) => holders[seat] = Person(id);

  /// [id] drops: their seat is kept for them, played by the host meanwhile.
  void drop(String id) {
    final s = seatOf(id);
    if (s != null) holders[s] = (holders[s] as Person).copyWith(connected: false);
  }

  /// [id] is back in their seat.
  void rejoin(String id) {
    final s = seatOf(id);
    if (s != null) holders[s] = (holders[s] as Person).copyWith(connected: true);
  }

  /// The empty seats are given to courtiers (the game begins).
  void fillWithCourtiers() {
    for (var s = 0; s < holders.length; s++) {
      if (holders[s] is EmptySeat) holders[s] = const CourtierSeat();
    }
  }

  List<Map<String, dynamic>> toJson() => [for (final h in holders) h.toJson()];

  static Seats fromJson(List<dynamic> j) => Seats.of([
        for (final h in j) SeatHolder.fromJson(Map<String, dynamic>.from(h as Map))
      ]);
}
