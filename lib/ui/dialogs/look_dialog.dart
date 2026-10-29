/// The Look dialog: the style the game is dressed in (a skin), the table
/// it's played on, and the backs of the cards (skin/tailored.dart). Each
/// choice is worn at once, so the game behind the dialog shows it.
library;

import 'package:flutter/material.dart';

import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import '../../skin/skins.dart';
import '../../skin/tailored.dart';
import '../cards/card_back.dart';
import '../widgets.dart';

/// Opens the Look dialog; [wear] puts a look on (and keeps it), and says
/// whether it could.
Future<void> showLookDialog(BuildContext context, {required bool Function(Skin) wear}) =>
    showDialog<void>(context: context, builder: (_) => _LookDialog(wear: wear));

class _LookDialog extends StatelessWidget {
  const _LookDialog({required this.wear});
  final bool Function(Skin) wear;

  @override
  Widget build(BuildContext context) {
    final worn = context.skin;
    final base = TailoredSkin.baseOf(worn);
    final table = worn is TailoredSkin ? worn.tableChoice : null;
    final back = worn is TailoredSkin ? worn.backChoice : null;
    Skin made(Skin base, TableChoice? table, BackChoice? back) =>
        table == null && back == null ? base : TailoredSkin(base, tableChoice: table, backChoice: back);
    void choose(Skin s) => wear(s);

    return CourtDialog(
      title: 'Look',
      maxWidth: 560,
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading('Style', 'The whole dress of the game: its colours, cards, panels and seats.'),
          _Choices(children: [
            for (final s in skins)
              if (SkinScope.owns(context, s))
                _Choice(
                  name: s.name,
                  selected: s.id == base.id,
                  onTap: () => choose(made(s, table, back)),
                  child: _TableSwatch(felt: s.felt, deep: s.feltDeep, rim: s.table, accent: s.gold),
                ),
          ]),
          const _Heading('Table', 'The felt you play on.'),
          _Choices(children: [
            _Choice(
              name: '${base.name}’s own',
              selected: table == null,
              onTap: () => choose(made(base, null, back)),
              child: _TableSwatch(felt: base.felt, deep: base.feltDeep, rim: base.table, accent: base.gold),
            ),
            for (final t in tableChoices)
              _Choice(
                name: t.name,
                selected: table?.id == t.id,
                onTap: () => choose(made(base, t, back)),
                child: _TableSwatch(felt: t.felt, deep: t.feltDeep, rim: t.table, accent: base.gold),
              ),
          ]),
          const _Heading('Card backs', 'On every hand you can’t see, and the tasks as they’re dealt.'),
          _Choices(children: [
            _Choice(
              name: '${base.name}’s own',
              selected: back == null,
              onTap: () => choose(made(base, table, null)),
              child: _Back(made(base, null, null)),
            ),
            for (final b in backChoices)
              _Choice(
                name: b.name,
                selected: back?.id == b.id,
                onTap: () => choose(made(base, table, b)),
                child: _Back(TailoredSkin(base, backChoice: b)),
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
    return Semantics(
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
    );
  }
}

/// A little table: its felt, lit in the middle, set into its rim, with a
/// crown in the accent.
class _TableSwatch extends StatelessWidget {
  const _TableSwatch({required this.felt, required this.deep, required this.rim, required this.accent});
  final Color felt, deep, rim, accent;

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
          child: Center(child: CrownIcon(size: 20, color: accent)),
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
