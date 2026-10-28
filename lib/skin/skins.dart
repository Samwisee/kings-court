/// Every skin the game can wear, the first the default.
library;

import 'court/court_skin.dart';
import 'plain/plain_skin.dart';
import 'skin.dart';

const skins = <Skin>[CourtSkin(), PlainSkin()];

/// The skin saved as [id]; the default for none, or one that's gone.
Skin skinById(String? id) =>
    skins.firstWhere((s) => s.id == id, orElse: () => skins.first);
