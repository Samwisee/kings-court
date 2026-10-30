/// The Livery page: the style the game is dressed in (a skin: its table
/// and everything round it, menus and pages too, and the card faces, Court
/// Cards, backs, tokens and task cards it comes with), and each of those
/// swapped for another if you like (skin/tailored.dart). A showcase at the
/// top puts the livery together, each part changing as its choice does;
/// under it a tab for each kind of choice, its choices in a grid. The game
/// behind wears the livery once, as you leave: dressing the whole table
/// again on every tap was what made it slow.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/round.dart';
import '../../engine/task.dart';
import '../../game/courtiers.dart';
import '../../platform/page_colour.dart' if (dart.library.js_interop) '../../platform/page_colour_web.dart';
import '../../skin/entitlements.dart';
import '../../skin/looks.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../../skin/skins.dart';
import '../../skin/tailored.dart';
import '../cards/card_view.dart';
import '../cards/task_chip.dart';
import '../widgets.dart';

part 'look_swatches.dart';

/// Opens the Look page; [wear] puts the look on (and keeps it) as it
/// closes.
Future<void> showLookDialog(BuildContext context, {required bool Function(Skin) wear}) {
  final worn = context.skin;
  final entitlements = context.getInheritedWidgetOfExactType<SkinScope>()?.entitlements ?? const AllOwned();
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, a, b) => _LookPage(start: worn, wear: wear, entitlements: entitlements),
    transitionsBuilder: (context, a, b, child) {
      final t = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
          opacity: t,
          child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(t), child: child));
    },
  ));
}

class _LookPage extends StatefulWidget {
  const _LookPage({required this.start, required this.wear, required this.entitlements});
  final Skin start;
  final bool Function(Skin) wear;
  final Entitlements entitlements;

  @override
  State<_LookPage> createState() => _LookPageState();
}

class _LookPageState extends State<_LookPage> {
  late Skin _base = TailoredSkin.baseOf(widget.start);
  late BackChoice? _back = _chosen(widget.start)?.backChoice;
  late FaceChoice? _face = _chosen(widget.start)?.faceChoice;
  late TaskChoice? _task = _chosen(widget.start)?.taskChoice;
  late TokenChoice? _token = _chosen(widget.start)?.tokenChoice;
  late CourtChoice? _court = _chosen(widget.start)?.courtChoice;
  bool _worn = false;

  /// The tab open: which kind of choice the grid shows.
  _Kind _kind = _Kind.style;

  static TailoredSkin? _chosen(Skin s) => s is TailoredSkin ? s : null;

  Skin get _look => TailoredSkin.of(_base, back: _back, task: _task, face: _face, token: _token, court: _court);

  /// A new style comes as it's meant to: its own faces, backs and tasks.
  void _style(Skin s) => setState(() {
        _base = s;
        _back = null;
        _face = null;
        _task = null;
        _token = null;
        _court = null;
      });

  void _done() {
    _wearNow();
    Navigator.of(context).pop();
  }

  void _wearNow() {
    if (_worn) return;
    _worn = true;
    if (_look.id != widget.start.id) {
      widget.wear(_look);
    } else {
      colourPage(widget.start.table);
    }
  }

  @override
  void dispose() {
    // Left without wearing it: the page's own colour back.
    if (!_worn) colourPage(widget.start.table);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    // The page round the game (the status bar, the browser's bars) in the
    // livery as it's chosen.
    colourPage(look.table);
    final base = _base;
    final height = MediaQuery.sizeOf(context).height;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _wearNow();
      },
      child: SkinScope(
        skin: look,
        entitlements: widget.entitlements,
        child: Theme(
          data: look.theme(),
          child: Builder(builder: (context) {
            final skin = context.skin;
            final rule = Container(height: 1.5, color: skin.gold.withValues(alpha: 0.45));
            return Scaffold(
              backgroundColor: skin.feltDeep,
              body: Stack(children: [
                // The page in the style chosen, changing with it.
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    child: KeyedSubtree(key: ValueKey('ground-${base.id}'), child: const FeltGround(quiet: true)),
                  ),
                ),
                SafeArea(
                  // A column down the middle of a wide screen.
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(children: [
                        SizedBox(height: clampD(height * 0.36, 250, 350), child: _Showcase(look: look)),
                        _Tabs(kind: _kind, onKind: (k) => setState(() => _kind = k), look: look),
                        rule,
                        Expanded(child: _grid(context, look)),
                        rule,
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(onPressed: _done, child: const Text('Done'))),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            );
          }),
        ),
      ),
    );
  }

  /// The open tab's choices, in a grid of tiles: the style's own first.
  Widget _grid(BuildContext context, Skin look) {
    final base = _base;
    final own = TailoredSkin.of(base);
    final ownName = '${base.name}’s';
    final tiles = <Widget>[
      ...switch (_kind) {
        _Kind.style => [
            for (final s in skins)
              if (widget.entitlements.owns(s))
                _Tile(name: s.name, selected: s.id == base.id, onTap: () => _style(s), child: _TableSwatch(s)),
          ],
        _Kind.faces => [
            _Tile(name: ownName, selected: _face == null, onTap: () => setState(() => _face = null), child: _Faces(own)),
            for (final f in faceChoices)
              _Tile(
                  name: f.name,
                  selected: _face?.id == f.id,
                  onTap: () => setState(() => _face = f),
                  child: _Faces(TailoredSkin(base, faceChoice: f))),
          ],
        _Kind.court => [
            _Tile(
                name: ownName, selected: _court == null, onTap: () => setState(() => _court = null), child: _Courts(own)),
            for (final c in courtChoices)
              _Tile(
                  name: c.name,
                  selected: _court?.id == c.id,
                  onTap: () => setState(() => _court = c),
                  child: _Courts(TailoredSkin(base, courtChoice: c))),
          ],
        _Kind.backs => [
            _Tile(name: ownName, selected: _back == null, onTap: () => setState(() => _back = null), child: _Back(own)),
            for (final b in backChoices)
              _Tile(
                  name: b.name,
                  selected: _back?.id == b.id,
                  onTap: () => setState(() => _back = b),
                  child: _Back(TailoredSkin(base, backChoice: b))),
          ],
        _Kind.tokens => [
            _Tile(
                name: ownName, selected: _token == null, onTap: () => setState(() => _token = null), child: _Tokens(own)),
            for (final t in tokenChoices)
              _Tile(
                  name: t.name,
                  selected: _token?.id == t.id,
                  onTap: () => setState(() => _token = t),
                  child: _Tokens(TailoredSkin(base, tokenChoice: t))),
          ],
        _Kind.tasks => [
            _Tile(
                name: ownName,
                selected: _task == null,
                onTap: () => setState(() => _task = null),
                child: _TaskSwatch(own.taskLook)),
            for (final k in taskChoices)
              _Tile(
                  name: k.name,
                  selected: _task?.id == k.id,
                  onTap: () => setState(() => _task = k),
                  child: _TaskSwatch(k.look)),
          ],
      },
    ];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: GridView.builder(
        key: ValueKey('look-grid-${_kind.name}'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 132, mainAxisExtent: 136, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: tiles.length,
        itemBuilder: (context, i) => tiles[i],
      ),
    );
  }
}

/// The kinds of choice, a tab each.
enum _Kind {
  style('Style'),
  faces('Faces'),
  court('Court'),
  backs('Backs'),
  tokens('Tokens'),
  tasks('Tasks');

  const _Kind(this.label);
  final String label;
}

/// A tab for each kind of choice, the open one filled in the accent.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.kind, required this.onKind, required this.look});
  final _Kind kind;
  final ValueChanged<_Kind> onKind;
  final Skin look;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // All in view at once (wrapping if they must), never scrolled away.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final k in _Kind.values)
            Semantics(
              button: true,
              selected: k == kind,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onKind(k),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: k == kind ? skin.gold : Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: skin.gold.withValues(alpha: k == kind ? 1 : 0.35)),
                    ),
                    child: Text(k.label,
                        style: TextStyle(
                            fontFamily: skin.bodyFont,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: k == kind ? skin.goldInk : Colors.white.withValues(alpha: 0.85))),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One choice: its picture on the livery's felt over its name, ringed and
/// lit in the accent when chosen; lit, under a pointer, with the hand.
class _Tile extends StatefulWidget {
  const _Tile({required this.name, required this.selected, required this.onTap, required this.child});
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final selected = widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.name,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  gradient: RadialGradient(radius: 0.9, colors: [skin.feltGlow, skin.feltDeep]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: selected
                          ? skin.gold
                          : _hover
                              ? skin.gold.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.12),
                      width: selected ? 2.5 : 1.5),
                  boxShadow: [
                    if (selected) BoxShadow(color: skin.gold.withValues(alpha: 0.35), blurRadius: 14),
                    const BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
                child: Stack(children: [
                  // Its own layer: drawn once, not again as the grid scrolls.
                  Center(
                      child: AnimatedScale(
                          scale: _hover ? 1.06 : 1,
                          duration: const Duration(milliseconds: 160),
                          child: RepaintBoundary(child: widget.child))),
                  if (selected)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: skin.gold, shape: BoxShape.circle),
                        child: Icon(Icons.check_rounded, size: 14, color: skin.goldInk),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Text(widget.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected || _hover ? skin.gold : Colors.white.withValues(alpha: 0.8))),
          ]),
        ),
      ),
    );
  }
}

/// The livery put together, as a showcase: its name, a hand of the Court
/// Cards over the Ace to the 4, the seats' tokens, a pile of tricks in the
/// backs and a task, under a soft light. Each part changes on its own, as
/// its own choice does, and the lot only when the style does.
class _Showcase extends StatelessWidget {
  const _Showcase({required this.look});
  final Skin look;

  static const _courts = [PlayingCard.joker, PlayingCard.jack, PlayingCard.queen, PlayingCard.king];
  static const _numbers = [
    PlayingCard(Suit.hearts, 1),
    PlayingCard(Suit.spades, 2),
    PlayingCard(Suit.diamonds, 3),
    PlayingCard(Suit.clubs, 4),
  ];

  @override
  Widget build(BuildContext context) {
    final dressed = look is TailoredSkin ? look as TailoredSkin : null;
    final base = TailoredSkin.baseOf(look).id;
    return SkinScope(
      skin: look,
      child: Builder(builder: (context) {
        final skin = context.skin;
        return LayoutBuilder(builder: (context, c) {
          final h = c.maxHeight, w = math.min(c.maxWidth, 560.0);
          final cardW = clampD(math.min((h - 78) / (1.42 * 1.85), w * 0.13), 40, 66);
          final cardH = PlayingCardView.heightFor(cardW);
          final step = cardW * 0.66;
          final fanW = 3 * step + cardW + 10;
          Widget fan(List<PlayingCard> cards, {required bool high}) => SizedBox(
                width: fanW,
                height: cardH + 12,
                child: Stack(clipBehavior: Clip.none, children: [
                  for (final (k, card) in cards.indexed)
                    Positioned(
                      left: k * step,
                      top: (k - 1.5).abs() * (high ? 4 : 2),
                      child: Transform.rotate(
                          angle: (k - 1.5) * (high ? 0.09 : 0.05), child: PlayingCardView(card: card, width: cardW)),
                    ),
                ]),
              );
          return Stack(fit: StackFit.expand, children: [
            // A soft light over the middle.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                    center: const Alignment(0, 0.15),
                    radius: 0.75,
                    colors: [skin.gold.withValues(alpha: 0.16), skin.gold.withValues(alpha: 0)]),
              ),
            ),
            Column(children: [
              const SizedBox(height: 10),
              Text('Livery',
                  style: TextStyle(fontSize: 13, letterSpacing: 1.2, color: Colors.white.withValues(alpha: 0.6))),
              _Swap(
                id: base,
                child: Text(skin.name,
                    style: TextStyle(
                        fontFamily: skin.displayFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        height: 1.15,
                        color: skin.gold,
                        shadows: skin.feltShadow)),
              ),
              Expanded(
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    // The hand: the Court Cards, and the number cards in front of them.
                    SizedBox(
                      width: fanW,
                      height: cardH * 1.82 + 12,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Positioned(
                            left: 0, top: 0, child: _Swap(id: '$base-${dressed?.court?.id}', child: fan(_courts, high: true))),
                        Positioned(
                            left: 0,
                            top: cardH * 0.82,
                            child: _Swap(id: '$base-${dressed?.face?.id}', child: fan(_numbers, high: false))),
                      ]),
                    ),
                    SizedBox(width: clampD(w * 0.06, 14, 34)),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      _Swap(id: '$base-${dressed?.token?.id}', child: _Tokens(look)),
                      const SizedBox(height: 10),
                      _Swap(
                        id: '$base-${dressed?.back?.id}',
                        child: SizedBox(
                          width: cardW * 0.8 + 12,
                          height: PlayingCardView.heightFor(cardW * 0.8) + 8,
                          child: Stack(children: [
                            for (var k = 0; k < 3; k++)
                              Positioned(
                                left: k * 5.0,
                                top: k * 2.0,
                                child: Transform.rotate(
                                    angle: (k.isEven ? -1 : 1) * 0.06, child: CardBack(width: cardW * 0.8)),
                              ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Swap(
                        id: '$base-${dressed?.task?.id}',
                        child: TaskChip(
                          task: RoundTask(taskByDescription('Win the first trick')),
                          points: 2,
                          text: 'Win the first trick',
                          color: skin.players[0],
                          width: 124,
                          progress: '0/1',
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ]);
        });
      }),
    );
  }
}

/// One part of the showcase, changing (fading and settling in) only when
/// [id] does, in a layer of its own.
class _Swap extends StatelessWidget {
  const _Swap({required this.id, required this.child});
  final String id;
  final Widget child;

  // The part carries the livery it was drawn in, so the old one fades out
  // as it was rather than in the new one.
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, a) => FadeTransition(
            opacity: a, child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child)),
        layoutBuilder: (current, previous) =>
            Stack(alignment: Alignment.center, children: [...previous, if (current != null) current]),
        child: RepaintBoundary(key: ValueKey(id), child: SkinScope(skin: context.skin, child: child)),
      );
}
