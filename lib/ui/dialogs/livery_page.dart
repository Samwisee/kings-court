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
import '../../platform/frame_stats.dart';
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

part 'livery_showcase.dart';
part 'livery_store.dart';
part 'livery_swatches.dart';

/// Opens the Livery page; [wear] puts the look on (and keeps it) as it
/// closes.
Future<void> showLivery(BuildContext context, {required bool Function(Skin) wear}) {
  final worn = context.skin;
  final entitlements = context.getInheritedWidgetOfExactType<SkinScope>()?.entitlements ?? const AllOwned();
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, a, b) => _LiveryPage(start: worn, wear: wear, entitlements: entitlements),
    transitionsBuilder: (context, a, b, child) {
      final t = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
          opacity: t,
          child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(t), child: child));
    },
  ));
}

class _LiveryPage extends StatefulWidget {
  const _LiveryPage({required this.start, required this.wear, required this.entitlements});
  final Skin start;
  final bool Function(Skin) wear;
  final Entitlements entitlements;

  @override
  State<_LiveryPage> createState() => _LiveryPageState();
}

class _LiveryPageState extends State<_LiveryPage> {
  late Skin _base = TailoredSkin.baseOf(widget.start);
  late BackChoice? _back = _chosen(widget.start)?.backChoice;
  late FaceChoice? _face = _chosen(widget.start)?.faceChoice;
  late TaskChoice? _task = _chosen(widget.start)?.taskChoice;
  late TokenChoice? _token = _chosen(widget.start)?.tokenChoice;
  late CourtChoice? _court = _chosen(widget.start)?.courtChoice;
  bool _worn = false;

  /// The tab open: which kind of choice the grid shows.
  _Kind _kind = _Kind.style;

  /// The shop's one scroll: the window shrinks, then the shelves go by.
  final _scroll = ScrollController();

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

  /// Buying: the store isn't open yet, so it says so.
  void _buy(String what, String price) => showDialog<void>(
        context: context,
        builder: (context) => CourtDialog(
          title: 'The store opens soon',
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Keep looking'))],
          child: Text('$what will be $price. Until the store opens, look at anything you like here.',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.35)),
        ),
      );

  void _wearNow() {
    if (_worn) return;
    _worn = true;
    // Only what's owned is worn: a style tried on and not bought is left
    // in the shop.
    if (_look.id != widget.start.id && widget.entitlements.owns(_look)) {
      widget.wear(_look);
    } else {
      colourPage(widget.start.table);
    }
  }

  final _wasAt = FrameStats.at;

  @override
  void initState() {
    super.initState();
    FrameStats.at = 'livery';
  }

  @override
  void dispose() {
    // Left without wearing it: the page's own colour back.
    if (!_worn) colourPage(widget.start.table);
    FrameStats.at = _wasAt;
    _scroll.dispose();
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
            final price = widget.entitlements.priceOf(look);
            final windowH = clampD(height * 0.3, 200, 300);
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
                  // One case down the middle of a wide screen: the shop
                  // window at the top, the sections, the shelves, and the
                  // counter.
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: _Case(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            // The store's name, the window, and the sections
                            // stay put; only the shelves scroll.
                            const _StoreHeading(),
                            SizedBox(height: windowH, child: _Showcase(look: look, price: price)),
                            SizedBox(
                                height: 54,
                                child: _Tabs(kind: _kind, onKind: (k) => setState(() => _kind = k), look: look)),
                            Expanded(
                              child: _LiveryScrollbar(
                                controller: _scroll,
                                child: CustomScrollView(key: const ValueKey('livery-shelves'), controller: _scroll, slivers: [
                                  SliverPadding(
                                    // Room on the right for the scrollbar.
                                    padding: const EdgeInsets.fromLTRB(_Store.gutter, 14, _Store.gutter + 10, 16),
                                    sliver: SliverMainAxisGroup(
                                        key: ValueKey('look-grid-${_kind.name}'), slivers: _shelves(look)),
                                  ),
                                ]),
                              ),
                            ),
                            _Counter(
                              look: look,
                              price: price,
                              changed: look.id != widget.start.id,
                              onChoose: _done,
                              onBuy: () => _buy(base.name, price!),
                            ),
                          ]),
                        ),
                      ),
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

  static SliverGrid _grid(List<Widget> tiles) => SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140, mainAxisExtent: 150, crossAxisSpacing: 10, mainAxisSpacing: 12),
        delegate: SliverChildListDelegate(tiles),
      );

  /// The open section's shelves. Styles: those for sale first (with the
  /// offer of every one at once), then the player's own. Anything else:
  /// one shelf, the style's own first.
  List<Widget> _shelves(Skin look) {
    if (_kind != _Kind.style) return [_grid(_tiles(look))];
    final forSale = [for (final s in skins) if (widget.entitlements.priceOf(s) != null) s];
    final yours = [for (final s in skins) if (widget.entitlements.priceOf(s) == null) s];
    final inUse = TailoredSkin.baseOf(widget.start).id;
    Widget tile(Skin s) => _Tile(
        name: s.name,
        selected: s.id == _base.id,
        inUse: s.id == inUse,
        fresh: _newStyles.contains(s.id),
        price: widget.entitlements.priceOf(s),
        onTap: () => _style(s),
        child: _TableSwatch(s));
    if (forSale.isEmpty) return [_grid([for (final s in yours) tile(s)])];
    return [
      SliverToBoxAdapter(
          child: _ShelfHeading(
              title: 'For sale',
              offer: _BundleOffer(price: _bundlePrice, onTap: () => _buy('Every style', _bundlePrice)))),
      _grid([for (final s in forSale) tile(s)]),
      const SliverToBoxAdapter(child: SizedBox(height: 18)),
      const SliverToBoxAdapter(child: _ShelfHeading(title: 'Yours')),
      _grid([for (final s in yours) tile(s)]),
    ];
  }

  /// The open section's choices, a tile each: the style's own first.
  List<Widget> _tiles(Skin look) {
    final base = _base;
    final own = TailoredSkin.of(base);
    final ownName = '${base.name}’s';
    final tiles = <Widget>[
      ...switch (_kind) {
        _Kind.style => <Widget>[],
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
    return tiles;
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
    // The shop's sections, on the case's own ground (they stay at the top
    // as the shelves scroll under them), all on one line: smaller on a
    // narrow screen, never wrapped or scrolled away.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _Case.ground(skin),
        border: Border(bottom: BorderSide(color: skin.gold.withValues(alpha: 0.35), width: 1.5)),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
          for (final k in _Kind.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Semantics(
              button: true,
              selected: k == kind,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onKind(k),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    // As wide as its word: no alignment, which would stretch it.
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
