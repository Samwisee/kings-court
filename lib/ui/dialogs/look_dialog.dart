/// The Look page: the style the game is dressed in (a skin: its table and
/// everything round it, menus and pages too, and the card faces, backs
/// and task cards it comes with), and each of those swapped for another
/// if you like (skin/tailored.dart). A preview at the top shows the look
/// as it's put together, changing as you choose; each kind of choice is a
/// row to scroll sideways. The game behind wears the look once, as you
/// leave: dressing the whole table again on every tap was what made it
/// slow.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/round.dart';
import '../../engine/task.dart';
import '../../game/courtiers.dart';
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
  bool _worn = false;

  static TailoredSkin? _chosen(Skin s) => s is TailoredSkin ? s : null;

  Skin get _look => TailoredSkin.of(_base, back: _back, task: _task, face: _face, token: _token);

  /// A new style comes as it's meant to: its own faces, backs and tasks.
  void _style(Skin s) => setState(() {
        _base = s;
        _back = null;
        _face = null;
        _task = null;
        _token = null;
      });

  void _done() {
    _wearNow();
    Navigator.of(context).pop();
  }

  void _wearNow() {
    if (_worn) return;
    _worn = true;
    if (_look.id != widget.start.id) widget.wear(_look);
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    final base = _base;
    final dressed = look is TailoredSkin ? look : null;
    final height = MediaQuery.sizeOf(context).height;
    final styles = [for (final s in skins) if (widget.entitlements.owns(s)) s];
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
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
                      child: Row(children: [
                        Expanded(child: Text('Look', style: skin.dialogTitle.copyWith(fontSize: 26))),
                        FilledButton(onPressed: _done, child: const Text('Done')),
                      ]),
                    ),
                    // The look as it's put together.
                    SizedBox(
                      height: clampD(height * 0.3, 190, 290),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 360),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child)),
                          layoutBuilder: (current, previous) =>
                              Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
                          child: _Preview(key: ValueKey(look.id), look: look),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView(
                        key: const ValueKey('look-rows'),
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          _Row(
                            id: 'style',
                            title: 'Style',
                            chosen: base.name,
                            count: styles.length,
                            tile: (i) => _Tile(
                              name: styles[i].name,
                              selected: styles[i].id == base.id,
                              onTap: () => _style(styles[i]),
                              child: _TableSwatch(styles[i]),
                            ),
                          ),
                          _Row(
                            id: 'faces',
                            title: 'Card faces',
                            chosen: dressed?.face?.name ?? '${base.name}’s',
                            count: faceChoices.length + 1,
                            tile: (i) => i == 0
                                ? _Tile(
                                    name: '${base.name}’s',
                                    selected: _face == null,
                                    onTap: () => setState(() => _face = null),
                                    child: _Faces(TailoredSkin.of(base)),
                                  )
                                : _Tile(
                                    name: faceChoices[i - 1].name,
                                    selected: _face?.id == faceChoices[i - 1].id,
                                    onTap: () => setState(() => _face = faceChoices[i - 1]),
                                    child: _Faces(TailoredSkin(base, faceChoice: faceChoices[i - 1])),
                                  ),
                          ),
                          _Row(
                            id: 'backs',
                            title: 'Card backs',
                            chosen: dressed?.back?.name ?? '${base.name}’s',
                            count: backChoices.length + 1,
                            tile: (i) => i == 0
                                ? _Tile(
                                    name: '${base.name}’s',
                                    selected: _back == null,
                                    onTap: () => setState(() => _back = null),
                                    child: _Back(TailoredSkin.of(base)),
                                  )
                                : _Tile(
                                    name: backChoices[i - 1].name,
                                    selected: _back?.id == backChoices[i - 1].id,
                                    onTap: () => setState(() => _back = backChoices[i - 1]),
                                    child: _Back(TailoredSkin(base, backChoice: backChoices[i - 1])),
                                  ),
                          ),
                          _Row(
                            id: 'tokens',
                            title: 'Tokens',
                            chosen: dressed?.token?.name ?? '${base.name}’s',
                            count: tokenChoices.length + 1,
                            tile: (i) => i == 0
                                ? _Tile(
                                    name: '${base.name}’s',
                                    selected: _token == null,
                                    onTap: () => setState(() => _token = null),
                                    child: _Tokens(TailoredSkin.of(base)),
                                  )
                                : _Tile(
                                    name: tokenChoices[i - 1].name,
                                    selected: _token?.id == tokenChoices[i - 1].id,
                                    onTap: () => setState(() => _token = tokenChoices[i - 1]),
                                    child: _Tokens(TailoredSkin(base, tokenChoice: tokenChoices[i - 1])),
                                  ),
                          ),
                          _Row(
                            id: 'tasks',
                            title: 'Task cards',
                            chosen: dressed?.task?.name ?? '${base.name}’s',
                            count: taskChoices.length + 1,
                            tile: (i) => i == 0
                                ? _Tile(
                                    name: '${base.name}’s',
                                    selected: _task == null,
                                    onTap: () => setState(() => _task = null),
                                    child: _TaskSwatch(TailoredSkin.of(base).taskLook),
                                  )
                                : _Tile(
                                    name: taskChoices[i - 1].name,
                                    selected: _task?.id == taskChoices[i - 1].id,
                                    onTap: () => setState(() => _task = taskChoices[i - 1]),
                                    child: _TaskSwatch(taskChoices[i - 1].look),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ]),
            );
          }),
        ),
      ),
    );
  }
}

/// One kind of choice: its name and what's chosen, over a row of tiles
/// that scrolls sideways (built as they come into view).
class _Row extends StatelessWidget {
  const _Row({required this.id, required this.title, required this.chosen, required this.count, required this.tile});
  final String id;
  final String title;
  final String chosen;
  final int count;
  final Widget Function(int i) tile;

  static const height = 124.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(title,
                style: TextStyle(
                    fontFamily: skin.displayFont, fontWeight: FontWeight.w700, fontSize: 18, color: skin.gold)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(chosen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: ListView.separated(
            key: ValueKey('look-row-$id'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: count,
            separatorBuilder: (context, i) => const SizedBox(width: 10),
            itemBuilder: (context, i) => tile(i),
          ),
        ),
      ]),
    );
  }
}

/// One choice: its picture over its name, ringed in the accent when
/// chosen, with a tick.
class _Tile extends StatelessWidget {
  const _Tile({required this.name, required this.selected, required this.onTap, required this.child});
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 100,
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 100,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected ? skin.gold : Colors.white.withValues(alpha: 0.1), width: selected ? 2.5 : 1),
              ),
              child: Stack(children: [
                // Its own layer: drawn once, not again as the row scrolls.
                Center(child: RepaintBoundary(child: child)),
                if (selected)
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(color: skin.gold, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, size: 13, color: skin.goldInk),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 6),
            Text(name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? skin.gold : Colors.white70)),
          ]),
        ),
      ),
    );
  }
}

/// The look put together: a corner of its table, a hand fanned on it, a
/// pile of tricks in its backs, and a task.
class _Preview extends StatelessWidget {
  const _Preview({super.key, required this.look});
  final Skin look;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: SkinScope(
          skin: look,
          child: Builder(builder: (context) {
            final skin = context.skin;
            return Container(
              decoration: BoxDecoration(
                color: skin.table,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))],
              ),
              padding: const EdgeInsets.all(7),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LayoutBuilder(builder: (context, c) {
                  final w = c.maxWidth, h = c.maxHeight;
                  final cardW = clampD(h * 0.36, 46, 74);
                  return Stack(fit: StackFit.expand, children: [
                    const FeltGround(),
                    if (skin.tableLook.outerRule case final rule?)
                      DecoratedBox(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14), border: Border.all(color: rule, width: 2))),
                    Positioned(
                      left: 16,
                      top: 12,
                      child: Text(skin.name,
                          style: TextStyle(
                              fontFamily: skin.displayFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: skin.gold,
                              shadows: skin.feltShadow)),
                    ),
                    // A hand, fanned.
                    for (final (k, card) in const [
                      PlayingCard(Suit.hearts, 7),
                      PlayingCard(Suit.spades, 1),
                      PlayingCard.queen,
                    ].indexed)
                      Positioned(
                        left: w * 0.08 + k * cardW * 0.62,
                        top: h * 0.3 - (k == 1 ? 6 : 0),
                        child: Transform.rotate(
                            angle: (k - 1) * 0.12, child: PlayingCardView(card: card, width: cardW)),
                      ),
                    // A pile of tricks won.
                    Positioned(
                      right: w * 0.08,
                      top: h * 0.14,
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
                    // A task.
                    Positioned(
                      right: w * 0.05,
                      bottom: 10,
                      child: TaskChip(
                        task: RoundTask(taskByDescription('Win the first trick')),
                        points: 2,
                        text: 'Win the first trick',
                        color: skin.players[0],
                        width: math.min(150, w * 0.42),
                        progress: '0/1',
                      ),
                    ),
                  ]);
                }),
              ),
            );
          }),
        ),
      );
}
