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
import '../../skin/effects.dart';
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

  /// A scroll position for each tab's grid (two are on screen as the tabs
  /// cross-fade, so they can't share one).
  final _scrolls = {for (final k in _Kind.values) k: ScrollController()};

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
    for (final c in _scrolls.values) {
      c.dispose();
    }
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
                  // A column down the middle of a wide screen: the showcase
                  // and the choices each in a panel of the style's own.
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Column(children: [
                          _Enclosure(
                              child: SizedBox(height: clampD(height * 0.34, 230, 330), child: _Showcase(look: look))),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _Enclosure(
                              child: Column(children: [
                                _Tabs(kind: _kind, onKind: (k) => setState(() => _kind = k), look: look),
                                Container(height: 1.5, color: skin.gold.withValues(alpha: 0.35)),
                                Expanded(child: _grid(context, look)),
                              ]),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: FilledButton(
                                style: FilledButton.styleFrom(minimumSize: const Size(200, 46)),
                                onPressed: _done,
                                child: const Text('Done')),
                          ),
                        ]),
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
    final scroll = _scrolls[_kind]!;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _LiveryScrollbar(
        key: ValueKey('look-grid-${_kind.name}'),
        controller: scroll,
        child: GridView.builder(
          controller: scroll,
          // Room on the right for the scrollbar.
          padding: const EdgeInsets.fromLTRB(14, 14, 22, 18),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 132, mainAxisExtent: 136, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: tiles.length,
          itemBuilder: (context, i) => tiles[i],
        ),
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 5,
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
                    if (selected) BoxShadow(color: skin.gold.withValues(alpha: 0.35), blurRadius: blurs ? 14 : 0),
                    const BoxShadow(color: Colors.black38, blurRadius: blurs ? 6 : 0, offset: Offset(0, 3)),
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
