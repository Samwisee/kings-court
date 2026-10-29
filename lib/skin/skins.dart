/// Every skin the game can wear, the first the default.
library;

import 'court/court_skin.dart';
import 'garden/garden_skin.dart';
import 'harbour/harbour_skin.dart';
import 'lacquer/lacquer_skin.dart';
import 'midnight/midnight_skin.dart';
import 'plain/plain_skin.dart';
import 'skin.dart';
import 'tailored.dart';

const skins = <Skin>[
  CourtSkin(),
  PlainSkin(),
  LacquerSkin(),
  GardenSkin(),
  MidnightSkin(),
  HarbourSkin(),
];

/// The skin saved as [id] (with any table and backs chosen for it, see
/// tailored.dart); the default for none, or one that's gone.
Skin skinById(String? id) {
  final parts = (id ?? '').split('+');
  final base = skins.firstWhere((s) => s.id == parts.first, orElse: () => skins.first);
  String? chosen(String key) =>
      parts.skip(1).where((p) => p.startsWith('$key:')).map((p) => p.substring(key.length + 1)).firstOrNull;
  final table = tableChoices.where((t) => t.id == chosen('t')).firstOrNull;
  final back = backChoices.where((b) => b.id == chosen('b')).firstOrNull;
  if (table == null && back == null) return base;
  return TailoredSkin(base, tableChoice: table, backChoice: back);
}

/// The skin after [worn] in the list that the player [owns], round to the
/// first; null if they own no other.
Skin? skinAfter(Skin worn, bool Function(Skin) owns) {
  final at = skins.indexWhere((s) => s.id == TailoredSkin.baseOf(worn).id);
  for (var k = 1; k < skins.length; k++) {
    final s = skins[(at + k) % skins.length];
    if (owns(s)) return s;
  }
  return null;
}
