/// The skins (lib/skin): every one defines the whole look, the app wears
/// the one chosen, and the menu switches between them and remembers it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/skin/entitlements.dart';
import 'package:kings_court/skin/plain/plain_skin.dart';
import 'package:kings_court/skin/skin.dart';
import 'package:kings_court/skin/skin_scope.dart';
import 'package:kings_court/skin/skins.dart';
import 'package:kings_court/ui/app.dart';
import 'package:kings_court/ui/table_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoneOwned extends Entitlements {
  const _NoneOwned();
  @override
  bool owns(Skin skin) => false;
}

void main() {
  test('Every skin has its own id and a theme in its colours', () {
    expect({for (final s in skins) s.id}, hasLength(skins.length));
    for (final s in skins) {
      expect(s.players, hasLength(6), reason: s.id);
      expect(s.theme().colorScheme.primary, s.gold, reason: s.id);
      expect(s.dialogTitle.fontFamily, s.displayFont, reason: s.id);
    }
    expect(skinById('plain'), isA<PlainSkin>());
    expect(skinById('gone'), same(skins.first));
  });

  testWidgets('A skin not owned can’t be chosen', (tester) async {
    late BuildContext ctx;
    Skin? chosen;
    await tester.pumpWidget(SkinScope(
        skin: skins.first,
        entitlements: const _NoneOwned(),
        onChoose: (s) => chosen = s,
        child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })));
    expect(SkinScope.owns(ctx, skins[1]), isFalse);
    expect(SkinScope.choose(ctx, skins[1]), isFalse);
    expect(chosen, isNull);
  });

  testWidgets('The menu switches to the Plain look and remembers it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    HomePageTestHooks.fast();
    await tester.pumpWidget(const TheKingsCourtApp());
    await tester.pumpAndSettle();
    Skin worn() => SkinScope.of(tester.element(find.byType(HomePage)));
    expect(worn().id, 'court');
    // No menu on the front page; it's there once setup opens.
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plain look'));
    await tester.pumpAndSettle();
    expect(worn().id, 'plain');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kingsCourt.skin'), 'plain');
  });
}
