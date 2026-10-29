/// Every skin the game can wear, the first the default.
library;

import 'court/court_skin.dart';
import 'lacquer/lacquer_skin.dart';
import 'plain/plain_skin.dart';
import 'skin.dart';

const skins = <Skin>[CourtSkin(), PlainSkin(), LacquerSkin()];

/// The skin saved as [id]; the default for none, or one that's gone.
Skin skinById(String? id) =>
    skins.firstWhere((s) => s.id == id, orElse: () => skins.first);

/// The skin after [worn] in the list that the player [owns], round to the
/// first; null if they own no other.
Skin? skinAfter(Skin worn, bool Function(Skin) owns) {
  final at = skins.indexWhere((s) => s.id == worn.id);
  for (var k = 1; k < skins.length; k++) {
    final s = skins[(at + k) % skins.length];
    if (owns(s)) return s;
  }
  return null;
}
