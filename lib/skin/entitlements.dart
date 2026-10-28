/// Which skins this player may wear. Every skin is everyone's today
/// ([AllOwned]); a shop would answer from what was bought.
library;

import 'skin.dart';

abstract class Entitlements {
  const Entitlements();

  bool owns(Skin skin);
}

class AllOwned extends Entitlements {
  const AllOwned();

  @override
  bool owns(Skin skin) => true;
}
