/// The people at the table: a seat's name and colour, and the short labels
/// seats are known by on screen.
library;

/// The colours seats are given, as ARGB values (the Okabe–Ito set, which
/// stays distinct for colour-blind players and at a glance). The screen's
/// Palette.players is made from these.
const playerColours = <int>[
  0xFFE69F00, // orange
  0xFF56B4E9, // sky blue
  0xFFCC79A7, // reddish purple
  0xFF009E73, // bluish green
  0xFFF0E442, // yellow
  0xFF0072B2, // deep blue
];

class Player {
  String name;

  /// The seat's colour, as an ARGB value (the screen turns it into a
  /// Color; the game itself has no Flutter in it, so it can run on a server).
  int colorValue;
  Player(this.name, {required this.colorValue});
}

/// Short labels for seat tokens and the owner badge on cards. Default
/// names ("Player 3") show the seat number; real names show initials. If
/// two players would share a label, they get the first two letters of
/// their name instead, and failing that their seat number.
List<String> seatLabels(List<Player> players) {
  final defaultName = RegExp(r'^player \d+$', caseSensitive: false);
  String initials(String name) {
    // "The General" is G: the article isn't part of the name.
    final words = name
        .replaceFirst(RegExp(r'^the\s+', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  final labels = <String>[
    for (int i = 0; i < players.length; i++)
      () {
        final name = players[i].name.trim();
        return name.isEmpty || defaultName.hasMatch(name)
            ? '${i + 1}'
            : initials(name);
      }(),
  ];

  for (var pass = 0; pass < 2; pass++) {
    final counts = <String, int>{};
    for (final l in labels) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    for (var i = 0; i < labels.length; i++) {
      if (counts[labels[i]]! < 2) continue;
      final name = players[i]
          .name
          .trim()
          .replaceFirst(RegExp(r'^the\s+', caseSensitive: false), '');
      labels[i] = pass == 0 && name.length >= 2 && !defaultName.hasMatch(name)
          ? '${name[0].toUpperCase()}${name[1].toLowerCase()}'
          : '${i + 1}';
    }
  }
  return labels;
}
