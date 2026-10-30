/// Every skin the game can wear, the first the default.
library;

import 'court/court_skin.dart';
import 'garden/garden_skin.dart';
import 'harbour/harbour_skin.dart';
import 'lacquer/lacquer_skin.dart';
import 'midnight/midnight_skin.dart';
import 'plain/plain_skin.dart';
import 'rooms/room_skins.dart';
import 'skin.dart';
import 'tailored.dart';

const skins = <Skin>[
  CourtSkin(),
  PlainSkin(),
  LacquerSkin(),
  GardenSkin(),
  MidnightSkin(),
  HarbourSkin(),
  VelvetSkin(),
  CountingSkin(),
  LibrarySkin(),
  TavernSkin(),
  MarbleSkin(),
  BallroomSkin(),
  CourtyardSkin(),
  CampaignSkin(),
  ChequersSkin(),
  SalonSkin(),
];

/// The tables once chosen apart from the skin (`+t:<table>`), and the
/// skin each became: worn instead, so a look saved then comes back.
const _tableSkins = {
  'sage': 'garden',
  'teal': 'harbour',
  'navy': 'midnight',
  'plum': 'velvet',
  'burgundy': 'counting',
  'walnut': 'library',
  'tavern': 'tavern',
  'marble': 'marble',
  'deco': 'ballroom',
  'tiles': 'courtyard',
  'map': 'campaign',
  'chess': 'chequers',
  'charcoal': 'salon',
};

/// The skin saved as [id] (with any backs and task cards chosen for it, see
/// tailored.dart); the default for none, or one that's gone.
Skin skinById(String? id) {
  final parts = (id ?? '').split('+');
  String? chosen(String key) =>
      parts.skip(1).where((p) => p.startsWith('$key:')).map((p) => p.substring(key.length + 1)).firstOrNull;
  final room = _tableSkins[chosen('t')] ?? parts.first;
  final base = skins.firstWhere((s) => s.id == room, orElse: () => skins.first);
  final back = backChoices.where((b) => b.id == chosen('b')).firstOrNull;
  final task = taskChoices.where((k) => k.id == chosen('k')).firstOrNull;
  final face = faceChoices.where((f) => f.id == chosen('f')).firstOrNull;
  return TailoredSkin.of(base, back: back, task: task, face: face, token: tokenById(chosen('o')), court: courtById(chosen('c')));
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
