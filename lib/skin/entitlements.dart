/// Which skins this player may wear, and what the others cost. Every skin
/// is everyone's today ([AllOwned]). [Shop] is the shop's answer: what's
/// for sale and what's been bought. It isn't open yet: a build made with
/// `--dart-define=SHOP_PREVIEW=true` shows the Livery page as a shop, with
/// [samplePrices], so it can be seen and tried; nothing can be bought.
library;

import 'skin.dart';
import 'tailored.dart';

abstract class Entitlements {
  const Entitlements();

  bool owns(Skin skin);

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
  const Shop(this.prices, {this.bought = const {}});

  final Map<String, String> prices;
  final Set<String> bought;

  @override
  bool owns(Skin skin) {
    final id = TailoredSkin.baseOf(skin).id;
    return !prices.containsKey(id) || bought.contains(id);
  }

  @override
  String? priceOf(Skin skin) => owns(skin) ? null : prices[TailoredSkin.baseOf(skin).id];
}

/// Whether this build shows the shop as it will be (with [samplePrices]).
const shopPreview = bool.fromEnvironment('SHOP_PREVIEW');

/// A sample of what might be for sale, for the preview: placeholders, not
/// decided prices.
const samplePrices = {
  'midnight': r'A$2',
  'velvet': r'A$2',
  'marble': r'A$3',
  'ballroom': r'A$3',
  'chequers': r'A$3',
  'salon': r'A$3',
};

/// What the game starts with: everything owned, or the preview's shop.
const Entitlements startingEntitlements = shopPreview ? Shop(samplePrices) : AllOwned();
