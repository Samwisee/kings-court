# Making a skin

A skin is the game's whole look: its colours and fonts, and the shapes of
its table, panels, cards, seats and buttons. Widgets read it from
`context.skin` and name no look of their own (`test/skin_test.dart` keeps
them to that), so a new skin never touches a widget.

There are three ways to make one. Start with the first and go further only
where it can't say what you want.

## 1. From a design (the easy way)

Most skins are a `SkinDesign`: about fifteen colours, two fonts and a
finish. `DesignSkin` works out everything else (the felt's shades, the
panels' grounds, the dialogs, the Material theme) from them.

```dart
// lib/skin/harbour/harbour_skin.dart
class HarbourSkin extends DesignSkin {
  const HarbourSkin() : super(harbourDesign);
}

const harbourDesign = SkinDesign(
  id: 'harbour',          // saved in settings: never change it once shipped
  name: 'Harbour',        // what the menu calls it ("Look: Harbour")
  ground: Color(0xFF0B1A22),   // behind everything
  felt: Color(0xFF14404F),     // the play area
  feltDeep: Color(0xFF0C2B36), // its shadows, a panel's ground
  surface: Color(0xFF12313D),  // dialogs and sheets
  card: Color(0xFFFAF8F2),     // card stock
  ink: Color(0xFF1A1E24),      // text on cards
  inkSoft: Color(0xFF5D6670),
  accent: Color(0xFFF2B950),   // where the court has gold
  accentDeep: Color(0xFFB97F1E),
  red: Color(0xFFC62839),      // the red suits
  won: Color(0xFF3FA66A),
  lost: Color(0xFFE0533F),
  displayFont: 'AlegreyaSans', // titles; a family in pubspec.yaml
  bodyFont: 'AlegreyaSans',
  finish: Finish.simple,
);
```

Then list it in `lib/skin/skins.dart`. That's all: the menu's *Look* row
steps through every listed skin, the screenshots take a set of it (front
page, setup, a round, the menu) and a sheet of its pieces
(`skin-<id>-pieces.png`), and the skin tests check it defines everything.

The **finish** picks a family of shapes:

| | `Finish.rich` | `Finish.simple` |
|---|---|---|
| Table | felt set in a rim, with rules | runs to the edge, a fine line inside |
| Panels | patterned, scrolled corners, a medallion on occasions | flat, a soft shadow, a coloured band on occasions |
| Court Cards | each on its cloth with its emblem, framed | the card's letter large on the stock, a coloured band |
| Card backs | plain, edged | a fine lattice |
| Seats | each house's shape | discs |
| Buttons | cut corners, a pulsing glow | rounded, a steady glow |

Optional: `radius` (corners), `onAccent` (text on accent buttons),
`cloth` (the Joker, Jack, Queen and King's colours, light then dark) and
`players` (the seats' six colours; the default set is kept apart for
colour-blind players, so change it with care).

Plain (`skin/plain`) is made this way.

## 2. Change a look (the flexible way)

Each shape is a small value on the skin (`lib/skin/looks.dart`):
`tableLook`, `panelLook`, `cardLook`, `tokenLook`, `buttonLook`. Override
any getter on your skin to change one without the others: a rich skin with
round seats, say.

```dart
class HarbourSkin extends DesignSkin {
  const HarbourSkin() : super(harbourDesign);

  @override
  TokenLook get tokenLook => const TokenLook(shaped: false, ringWidth: 3);
}
```

The court's, for instance, sets a pool of lamp light over the felt
(`TableLook(lamp: 0.07)`) and a ruled, latticed back
(`CardLook(backPattern: true, backRule: …)`).

Any colour getter (`gold`, `felt`, `dialogTitle`, `theme()` …) can be
overridden the same way. The court skin (`skin/court`) sets every value by
hand, which is the furthest this goes: a skin that extends `Skin` directly.

## 3. Draw a part yourself

For what no look can say, a skin draws the part itself: a card's face or
back, a panel, the table's edge. Return them from `parts`:

```dart
@override
SkinParts get parts => const SkinParts(cardBack: _back);

Widget _back(BuildContext context, CardBackSpec spec) => ...;
```

Each builder is handed what to draw (the card, its width, whether it's
dimmed…), a `kit` of the game's own pieces to draw with (`kit.suitMark`,
`kit.crown`), and `spec.standard()`, the part the looks would give, to wrap
or to fall back on (draw your own King and `standard()` for the rest, say).
Keep a part's size what the spec asks: the layout counts on it.

Lacquer (`skin/lacquer`) is a design with one part of its own: its card
backs, a gold crest on black lacquer.

## Checking it

Push and read the screenshots (`shots-<branch>`): `skin-<id>-*.png`. New
skins' shots are new files, so they don't trip the compare; a change that
moves the court's or another skin's screenshots does, and goes in
`tool/shots/expected_changes.txt` with the reason.
