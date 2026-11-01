/// Which skins this player may wear, and what the others cost. [Shop] is
/// the store's answer: what's for sale and what's owned. The store shows
/// [samplePrices] for now: nothing can be bought yet (Buy says the store
/// opens soon), and a style a player already wore is theirs to keep.
library;

import 'skin.dart';
import 'tailored.dart';

abstract class Entitlements {
  const Entitlements();

  bool owns(Skin skin);

  /// [skin] is the player's to keep (one they wore before there was a
  /// store, say).
  void keep(Skin skin) {}

  /// What [skin] costs, as shown (say 'A$3'), when it's for sale and not
  /// owned; null otherwise.
  String? priceOf(Skin skin) => null;
}

class AllOwned extends Entitlements {
  const AllOwned();

  @override
  bool owns(Skin skin) => true;
}

/// The shop: the skins in [prices] are for sale (a skin's id to its price),
/// and owned once [bought]; every other skin is free. A skin dressed with
/// other choices (a [TailoredSkin]) is its style's.
class Shop extends Entitlements {
  Shop(this.prices, {Set<String>? bought}) : bought = {...?bought};

  final Map<String, String> prices;

  /// The ids of the styles owned.
  final Set<String> bought;

  @override
  void keep(Skin skin) => bought.add(TailoredSkin.baseOf(skin).id);

  @override
  bool owns(Skin skin) {
    final id = TailoredSkin.baseOf(skin).id;
    return !prices.containsKey(id) || bought.contains(id);
  }

  @override
  String? priceOf(Skin skin) => owns(skin) ? null : prices[TailoredSkin.baseOf(skin).id];
}

/// A sample of what might be for sale: placeholders, not decided prices.
const samplePrices = {
  'midnight': r'A$2',
  'velvet': r'A$2',
  'marble': r'A$3',
  'ballroom': r'A$3',
  'chequers': r'A$3',
  'salon': r'A$3',
};
