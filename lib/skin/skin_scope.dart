/// Where widgets get the skin: `context.skin`. The app puts a [SkinScope]
/// over everything; with none (a widget test pumping one widget) the
/// King's Court skin is the look.
library;

import 'package:flutter/widgets.dart';

import 'court/court_skin.dart';
import 'skin.dart';

class SkinScope extends InheritedWidget {
  const SkinScope({super.key, required this.skin, required super.child});

  final Skin skin;

  static Skin of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkinScope>()?.skin ??
      const CourtSkin();

  @override
  bool updateShouldNotify(SkinScope old) => old.skin != skin;
}

extension SkinOf on BuildContext {
  /// The look everything on screen is drawn in.
  Skin get skin => SkinScope.of(this);
}
