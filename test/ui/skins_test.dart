/// The skins (lib/skin): every one defines the whole look, the app wears
/// the one chosen, and the menu switches between them and remembers it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/engine/cards.dart';
import 'package:kings_court/game/state.dart';
import 'package:kings_court/skin/entitlements.dart';
import 'package:kings_court/skin/plain/plain_skin.dart';
import 'package:kings_court/skin/skin.dart';
import 'package:kings_court/skin/skin_scope.dart';
import 'package:kings_court/skin/skins.dart';
import 'package:kings_court/ui/app.dart';
import 'package:kings_court/ui/cards/card_view.dart';
import 'package:kings_court/ui/cards/mini_card.dart';
import 'package:kings_court/ui/table_page.dart';
import 'package:kings_court/ui/widgets.dart';
import 'package:kings_court/ui/widgets/buttons.dart';
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
    // The menu steps through them in order, round to the first, past any
    // not owned.
    expect(skinAfter(skins.first, (_) => true), same(skins[1]));
    expect(skinAfter(skins.last, (_) => true), same(skins.first));
    expect(skinAfter(skins.first, (s) => s == skins.last), same(skins.last));
    expect(skinAfter(skins.first, (_) => false), isNull);
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

  testWidgets('The menu steps through the looks and remembers the one worn', (tester) async {
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
    await tester.tap(find.text('Look: Court'));
    await tester.pumpAndSettle();
    expect(worn().id, 'plain');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kingsCourt.skin'), 'plain');
    // Round them all and back to the court.
    for (final s in skins.skip(2)) {
      if (find.text('Look: ${worn().name}').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Menu'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Look: ${worn().name}'));
      await tester.pumpAndSettle();
      expect(worn().id, s.id);
    }
  });

  // Every skin listed draws every piece its looks describe, so a new skin
  // can't ship a look that throws; what it looks like is the screenshots'
  // job (skin-<id>-pieces.png).
  for (final skin in skins) {
    testWidgets('The ${skin.name} skin draws every piece', (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final player = Player('Ann', colorValue: skin.players[0].toARGB32());
      Widget panel(bool won, bool court, Ornament o) => SizedBox(
          width: 260,
          child: OrnateCard(
              won: won, court: court, ornament: o, margin: EdgeInsets.zero, child: const Text('Panel')));
      await tester.pumpWidget(SkinScope(
        skin: skin,
        child: MaterialApp(
          theme: skin.theme(),
          home: Scaffold(
            body: Stack(children: [
              const Positioned.fill(child: TableTrim()),
              const Positioned.fill(child: FeltLight()),
              SingleChildScrollView(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var id = 0; id < 40; id += 3) ...[
                    PlayingCardView(card: PlayingCard.fromId(id), width: 60),
                    MiniCard(card: PlayingCard.fromId(id), width: 30),
                  ],
                  for (final c in [PlayingCard.joker, PlayingCard.jack, PlayingCard.queen, PlayingCard.king])
                    PlayingCardView(card: c, width: 90, glow: true),
                  const CardBack(width: 60),
                  SeatToken(player: player, isKing: true),
                  SeatToken(player: player, highlighted: true),
                  GlowButton(label: 'Go', onPressed: () {}),
                  GlowButton(label: 'Chosen', onPressed: () {}, focused: true),
                  for (final o in Ornament.values) ...[
                    panel(false, true, o),
                    panel(true, false, o),
                    panel(false, false, o),
                  ],
                  const SizedBox(width: 200, height: 100, child: TableTrim(table: false)),
                ]),
              ),
            ]),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byType(PlayingCardView), findsWidgets);
    });
  }
}
