/// The Look dialog: the style the game is dressed in (a skin: its table
/// and everything round it, menus and pages too), the backs of the cards,
/// and the task cards (skin/tailored.dart), to mix and match. Each choice is worn at once, so
/// the game behind the dialog shows it.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../skin/entitlements.dart';
import '../../skin/looks.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../../skin/skins.dart';
import '../../skin/tailored.dart';
import '../../engine/cards.dart';
import '../cards/card_back.dart';
import '../cards/card_view.dart';
import '../widgets.dart';

/// Opens the Look dialog; [wear] puts a look on (and keeps it), and says
/// whether it could.
Future<void> showLookDialog(BuildContext context, {required bool Function(Skin) wear}) =>
    showDialog<void>(context: context, builder: (_) => _LookDialog(wear: wear));

class _LookDialog extends StatefulWidget {
  const _LookDialog({required this.wear});
  final bool Function(Skin) wear;

  @override
  State<_LookDialog> createState() => _LookDialogState();
}

class _LookDialogState extends State<_LookDialog> {
  /// What's chosen: the dialog wears it at once; the game behind it, a
  /// moment later (dressing the whole table again is the dear part), and
  /// only the last of several quick taps.
  Skin? _chosen;
  Timer? _wearing;

  void _choose(Skin s) {
    setState(() => _chosen = s);
    _wearing?.cancel();
    _wearing = Timer(const Duration(milliseconds: 140), () => widget.wear(s));
  }

  @override
  void dispose() {
    // Closed before it was worn: worn now.
    if (_wearing?.isActive ?? false) {
      _wearing!.cancel();
      widget.wear(_chosen!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final worn = _chosen ?? context.skin;
    return SkinScope(
      skin: worn,
      entitlements: context.getInheritedWidgetOfExactType<SkinScope>()?.entitlements ?? const AllOwned(),
      child: Theme(data: worn.theme(), child: Builder(builder: (context) => _dialog(context, worn))),
    );
  }

  Widget _dialog(BuildContext context, Skin worn) {
    final base = TailoredSkin.baseOf(worn);
    final back = worn is TailoredSkin ? worn.backChoice : null;
    final task = worn is TailoredSkin ? worn.taskChoice : null;
    final face = worn is TailoredSkin ? worn.faceChoice : null;
    Skin made(Skin base, BackChoice? back, [TaskChoice? task, FaceChoice? f]) =>
        TailoredSkin.of(base, back: back, task: task, face: f);
    void choose(Skin s) => _choose(s);

    return CourtDialog(
      title: 'Look',
      maxWidth: 560,
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading('Style', 'The room you play in: its table, and the menus and pages to match.'),
          _Choices(children: [
            for (final s in skins)
              if (SkinScope.owns(context, s))
                _Choice(
                  name: s.name,
                  selected: s.id == base.id,
                  onTap: () => choose(made(s, back, task, face)),
                  child: _TableSwatch(
                      felt: s.felt,
                      deep: s.feltDeep,
                      rim: s.table,
                      accent: s.gold,
                      pattern: s.tableLook.pattern,
                      ink: s.tableLook.patternColour),
                ),
          ]),
          const _Heading('Card faces', 'The cards in your hand and on the table: their stock, inks and Court Cards.'),
          _Choices(children: [
            _Choice(
              name: '${base.name}’s own',
              selected: face == null,
              onTap: () => choose(made(base, back, task)),
              child: _Faces(base),
            ),
            for (final f in faceChoices)
              _Choice(
                name: f.name,
                selected: face?.id == f.id,
                onTap: () => choose(made(base, back, task, f)),
                child: _Faces(TailoredSkin(base, faceChoice: f)),
              ),
          ]),
          const _Heading('Card backs', 'On every hand you can’t see, the tricks each player has won, and the tasks done.'),
          _Choices(children: [
            _Choice(
              name: '${base.name}’s own',
              selected: back == null,
              onTap: () => choose(made(base, null, task, face)),
              child: _Back(base),
            ),
            for (final b in backChoices)
              _Choice(
                name: b.name,
                selected: back?.id == b.id,
                onTap: () => choose(made(base, b, task, face)),
                child: _Back(TailoredSkin(base, backChoice: b)),
              ),
          ]),
          const _Heading('Task cards', 'The face of every task: its card, its ink and the frame printed on it.'),
          _Choices(children: [
            _Choice(
              name: '${base.name}’s own',
              selected: task == null,
              onTap: () => choose(made(base, back, null, face)),
              child: _TaskSwatch(base.taskLook),
            ),
            for (final k in taskChoices)
              _Choice(
                name: k.name,
                selected: task?.id == k.id,
                onTap: () => choose(made(base, back, k, face)),
                child: _TaskSwatch(k.look),
              ),
          ]),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.about);
  final String title;
  final String about;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontFamily: skin.displayFont, fontWeight: FontWeight.w700, fontSize: 18, color: skin.gold)),
        Text(about, style: skin.dialogNote),
      ]),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 10, children: children);
}

/// One choice: its picture over its name, ringed in the accent when worn.
class _Choice extends StatelessWidget {
  const _Choice({required this.name, required this.selected, required this.onTap, required this.child});
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // Each its own layer: drawn once, not again as the dialog scrolls.
    return RepaintBoundary(child: Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 84,
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? skin.gold.withValues(alpha: 0.14) : Colors.transparent,
            border: Border.all(
                color: selected ? skin.gold : Colors.white.withValues(alpha: 0.12), width: selected ? 2 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(height: 62, child: Center(child: child)),
            const SizedBox(height: 4),
            Text(name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: 12.5, height: 1.15, color: selected ? skin.gold : Colors.white70)),
          ]),
        ),
      ),
    ));
  }
}

/// A little table: its felt, lit in the middle, set into its rim, with a
/// crown in the accent.
class _TableSwatch extends StatelessWidget {
  const _TableSwatch(
      {required this.felt,
      required this.deep,
      required this.rim,
      required this.accent,
      this.pattern = FeltPattern.none,
      this.ink = Colors.transparent});
  final Color felt, deep, rim, accent;
  final FeltPattern pattern;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
        width: 68,
        height: 50,
        decoration: BoxDecoration(
          color: rim,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: RadialGradient(colors: [Color.lerp(felt, Colors.white, 0.08)!, deep], radius: 0.9),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CustomPaint(
              // What's worked into it, a little smaller than on the table
              // (and a little stronger, to be seen so small).
              painter: FeltPatternPainter(pattern, ink.withValues(alpha: math.min(1, ink.a * 1.6)),
                  ground: felt, scale: 0.4),
              child: Center(child: CrownIcon(size: 20, color: accent)),
            ),
          ),
        ),
      );
}

/// A little task card in [look]: points, a crown, and two lines of words.
class _TaskSwatch extends StatelessWidget {
  const _TaskSwatch(this.look);
  final TaskLook look;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    Widget words(double width) => Container(
        width: width,
        height: 4,
        margin: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(color: look.ink.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(2)));
    return Container(
      width: 70,
      height: 52,
      decoration: BoxDecoration(
        color: look.face,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: skin.outlineColour),
      ),
      child: CustomPaint(
        painter: TaskFacePainter(look, reach: EdgeInsets.zero, radius: 6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('3',
                  style: TextStyle(
                      fontFamily: skin.displayFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      height: 1,
                      color: look.ink)),
              const SizedBox(width: 2),
              CrownIcon(size: 11, color: look.crown ?? skin.goldDeep),
            ]),
            words(48),
            words(32),
          ]),
        ),
      ),
    );
  }
}

/// Two cards' faces as [look] draws them: a number card and a Court Card.
class _Faces extends StatelessWidget {
  const _Faces(this.look);
  final Skin look;

  @override
  Widget build(BuildContext context) => SkinScope(
        skin: look,
        child: const SizedBox(
          width: 66,
          height: 56,
          child: Stack(children: [
            Positioned(left: 4, top: 4, child: PlayingCardView(card: PlayingCard(Suit.hearts, 7), width: 34)),
            Positioned(right: 2, top: 2, child: PlayingCardView(card: PlayingCard.queen, width: 34)),
          ]),
        ),
      );
}

/// A card back as [look] draws it.
class _Back extends StatelessWidget {
  const _Back(this.look);
  final Skin look;

  @override
  Widget build(BuildContext context) => SkinScope(skin: look, child: const CardBack(width: 40));
}
