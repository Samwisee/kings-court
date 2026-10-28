/// Where widgets get the skin: `context.skin`. The app puts a [SkinScope]
/// over everything; with none (a widget test pumping one widget) the
/// King's Court skin is the look. [SkinScope.choose] changes it, for
/// skins the player [Entitlements.owns].
library;

import 'package:flutter/widgets.dart';

import 'court/court_skin.dart';
import 'entitlements.dart';
import 'skin.dart';

class SkinScope extends InheritedWidget {
  const SkinScope(
      {super.key,
      required this.skin,
      this.entitlements = const AllOwned(),
      this.onChoose,
      required super.child});

  final Skin skin;
  final Entitlements entitlements;

  /// Wears another skin (the app rebuilds under it).
  final ValueChanged<Skin>? onChoose;

  static Skin of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkinScope>()?.skin ??
      const CourtSkin();

  /// Changes the skin to [skin], if the player owns it; whether it did.
  static bool choose(BuildContext context, Skin skin) {
    final scope = context.getInheritedWidgetOfExactType<SkinScope>();
    if (scope == null || scope.onChoose == null || !scope.entitlements.owns(skin)) {
      return false;
    }
    scope.onChoose!(skin);
    return true;
  }

  /// Whether the player may wear [skin].
  static bool owns(BuildContext context, Skin skin) =>
      context.getInheritedWidgetOfExactType<SkinScope>()?.entitlements.owns(skin) ?? true;

  @override
  bool updateShouldNotify(SkinScope old) => old.skin != skin;
}

extension SkinOf on BuildContext {
  /// The look everything on screen is drawn in.
  Skin get skin => SkinScope.of(this);
}
