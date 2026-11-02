/// Dynasty's court, between hands (see modes/dynasty/run.dart): the herald
/// reads what the last hand did, a courtier brings a petition and the King
/// answers from the throne, and the King picks the projects for the next
/// hand. At the end of a reign, how it ended.
library;

import 'package:flutter/material.dart';

import '../../../game/courtiers.dart';
import '../../../game/players.dart';
import '../../../modes/dynasty/realm.dart';
import '../../../modes/dynasty/run.dart';
import '../../../skin/skin_scope.dart';
import '../../dynasty/hall_pieces.dart';
import '../../dynasty/throne_room.dart';
import '../../widgets.dart';

/// Opens the court over the table: [report] (the hand just played) first,
/// if there is one. True once the King has picked the next hand's
/// projects; false when the reign is over (or the court is left).
Future<bool> showCourt(BuildContext context, DynastyRun run, {HandReport? report}) async {
  final go = await Navigator.of(context).push<bool>(PageRouteBuilder<bool>(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, a, b) => _Court(run: run, report: report),
    transitionsBuilder: (context, a, b, child) => FadeTransition(opacity: a, child: child),
  ));
  return go ?? false;
}

/// The end of a Dynasty hand, over the table: won or lost, and on to court.
class HandOverCard extends StatelessWidget {
  const HandOverCard({super.key, required this.won, required this.onCourt});
  final bool won;
  final VoidCallback onCourt;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: skin.feltDeep,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: skin.gold, width: 2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(won ? 'Every task done' : 'The hand is lost',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: skin.displayFont,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: won ? skin.gold : skin.lost)),
        const SizedBox(height: 8),
        Text('The court awaits you in the great hall.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85))),
        const SizedBox(height: 16),
        FilledButton(
            key: const ValueKey('to-court'), onPressed: onCourt, child: const Text('To court ›')),
      ]),
    );
  }
}

enum _Stage { news, petition, answer, pick, end }

class _Court extends StatefulWidget {
  const _Court({required this.run, this.report});
  final DynastyRun run;
  final HandReport? report;

  @override
  State<_Court> createState() => _CourtState();
}

class _CourtState extends State<_Court> {
  DynastyRun get run => widget.run;
  late _Stage _stage = widget.report != null || run.hand == 0 ? _Stage.news : _after();
  String _said = '';
  final _chosen = <Work>[];

  /// Where the court goes once the news is read or an answer given.
  _Stage _after() => run.over
      ? _Stage.end
      : run.petition != null
          ? _Stage.petition
          : _Stage.pick;

  Color _colour(Courtier c) => Color(playerColours[c.index % playerColours.length]);

  HallFigure _figure(Courtier c, {bool enters = false}) =>
      HallFigure(c.name, c, _colour(c), enters: enters);

  List<HallFigure> get _court => [for (final c in run.court) _figure(c)];

  HallLine _line(Line l) => HallLine(l.text, who: l.who?.name);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return PopScope(
      canPop: false,
      child: Stack(children: [
        switch (_stage) {
          _Stage.pick => _pick(context),
          _ => _room(context),
        },
        // The realm, always in view (the pick lists it in its column).
        if (_stage != _Stage.pick)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 62, 16, 0),
                child: IgnorePointer(
                    child: Material(type: MaterialType.transparency, child: _Meters(run: run, colour: skin.gold))),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _room(BuildContext context) {
    final skin = context.skin;
    final king = ShapedToken(
        shape: Courtier.king.shape,
        size: 44,
        color: skin.gold,
        ring: skin.goldDeep,
        child: CrownIcon(size: 20, color: skin.ink));
    final (title, figures, lines) = switch (_stage) {
      _Stage.news => (
          run.hand == 0 ? 'The court gathers' : 'After hand ${run.hand}',
          _court,
          run.hand == 0
              ? const [
                  HallLine('Long live the King! The great houses gather in the hall.'),
                  HallLine('The realm is yours to steer. Choose its works well.'),
                ]
              : [for (final l in widget.report?.lines ?? const <String>[]) HallLine(l)],
        ),
      _Stage.petition => (
          run.petition!.id == 'treason'
              ? 'Treason'
              : run.petition!.visitor
                  ? 'A visitor'
                  : '${run.petition!.bringer.title} asks',
          [
            ..._court,
            if (run.petition!.visitor && run.petition!.id != 'treason')
              _figure(run.petition!.bringer, enters: true),
          ],
          [for (final l in run.petition!.lines) _line(l)],
        ),
      _Stage.answer => ('So it is decreed', _court, [HallLine(_said)]),
      _ => (
          run.ending!.won ? 'Act I won' : 'The reign ends',
          _court,
          [
            HallLine(run.ending!.words),
            HallLine('You reigned ${run.hand} hand${run.hand == 1 ? '' : 's'}.'),
          ],
        ),
    };
    final p = _stage == _Stage.petition ? run.petition : null;
    HallChoice? choice(int i) {
      if (p == null || i >= p.choices.length) return null;
      final c = p.choices[i];
      return HallChoice(c.label, () => _answer(i), cost: c.cost, enabled: run.affords(c));
    }

    return ThroneRoom(
      key: const ValueKey('court'),
      scene: '${_stage.name}-${run.hand}-${p?.id}',
      title: title,
      figures: figures,
      lines: lines,
      king: king,
      kingName: 'Hand ${run.hand + 1} of ${DynastyRun.handsInAct}',
      coffers: run.coffers,
      left: choice(0),
      right: choice(1),
      onContinue: p != null ? null : _continue,
    );
  }

  void _continue() {
    if (_stage == _Stage.end) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _stage = _after());
  }

  void _answer(int i) {
    final said = run.choose(i);
    setState(() {
      _said = said.isEmpty ? 'So be it.' : said;
      _stage = _Stage.answer;
    });
  }

  Widget _pick(BuildContext context) {
    final skin = context.skin;
    final seated = [for (final c in run.table) c.short].join(', ');
    return Material(
      color: skin.feltDeep,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: HallPainter(skin))),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: Text('The works',
                          style: TextStyle(
                              fontFamily: skin.displayFont,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: skin.gold)),
                    ),
                    Coffers(run.coffers),
                  ]),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: _Meters(run: run, colour: skin.gold)),
                  const SizedBox(height: 12),
                  Text(
                      'Pick up to ${run.picks} for hand ${run.hand + 1}. Each deals a task. '
                      'At your table: $seated.',
                      style: TextStyle(fontSize: 14.5, height: 1.35, color: Colors.white.withValues(alpha: 0.85))),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(children: [
                      for (final w in run.pool)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ProjectCard(
                            work: w,
                            chosen: _chosen.contains(w),
                            enabled: _chosen.contains(w) || run.canPick(w, _chosen),
                            onTap: () => setState(() =>
                                _chosen.contains(w) ? _chosen.remove(w) : _chosen.add(w)),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: FilledButton(
                      key: const ValueKey('begin-hand'),
                      onPressed: _chosen.isEmpty
                          ? null
                          : () {
                              run.pick(_chosen);
                              Navigator.of(context).pop(true);
                            },
                      child: Text(_chosen.isEmpty ? 'Pick a work' : 'Begin the hand ›'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// A project in the pool, as a task card in the style's own task cards:
/// its suit and name, how far along (a pip a stage), the task its next stage
/// deals, and what it brings or costs. Chosen: ringed in the accent and
/// lifted a little, as a task taken is.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard(
      {required this.work, required this.chosen, required this.enabled, required this.onTap});
  final Work work;
  final bool chosen, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final look = skin.taskLook;
    final p = work.project;
    const radius = 10.0;
    return Semantics(
      button: true,
      selected: chosen,
      label: '${p.title}: ${work.task}',
      child: AnimatedScale(
        scale: chosen ? 1.02 : 1,
        duration: const Duration(milliseconds: 140),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: MouseRegion(
              cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
              child: Container(
                decoration: BoxDecoration(
                  color: look.face,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                      color: chosen ? skin.gold : (look.frameColour ?? skin.outlineColour),
                      width: chosen ? 3 : 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black38, offset: Offset(0, 3))],
                ),
                child: CustomPaint(
                  // What the style prints on its task cards.
                  painter: TaskFacePainter.prints(look)
                      ? TaskFacePainter(look, reach: EdgeInsets.zero, radius: radius - 2)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        SuitText(p.mark, keywords: false, style: const TextStyle(fontSize: 18, height: 1)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(p.title,
                              style: TextStyle(
                                  fontFamily: skin.displayFont,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  height: 1.15,
                                  color: p.keystone ? (look.crown ?? skin.goldDeep) : look.ink)),
                        ),
                        // How far along: a pip a stage, filled when done.
                        for (var i = 0; i < p.stages.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Icon(i < work.stage ? Icons.circle : Icons.circle_outlined,
                                size: 10, color: look.crown ?? skin.goldDeep),
                          ),
                        if (chosen) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle_rounded, size: 18, color: skin.goldDeep),
                        ],
                      ]),
                      const SizedBox(height: 6),
                      // The task this stage deals, as a task card words it.
                      SuitText(work.task,
                          style: TextStyle(fontSize: 14.5, height: 1.25, fontWeight: FontWeight.w600, color: look.ink)),
                      const SizedBox(height: 5),
                      SuitText(
                          '${p.keystone ? 'Wins the act. ' : ''}Done: ${effectWords(p.reward)}. '
                          'Failed: ${effectWords(p.failure)}.',
                          keywords: false,
                          style: TextStyle(fontSize: 12.5, height: 1.25, color: look.inkSoft)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [e] in a few words: "♥ +2, 3 gold".
String effectWords(Effect e) {
  String signed(int n) => n > 0 ? '+$n' : '−${-n}';
  final parts = [
    for (final m in e.meters.entries) '${m.key.suit} ${signed(m.value)}',
    if (e.coffers != 0) '${signed(e.coffers)} gold',
    for (final l in e.loyalty.entries) '${l.key.short} ${signed(l.value)}',
  ];
  return parts.isEmpty ? 'nothing' : parts.join(', ');
}

/// The realm's meters: each suit, and how full.
class _Meters extends StatelessWidget {
  const _Meters({required this.run, required this.colour});
  final DynastyRun run;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final m in Meter.values)
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Semantics(
            label: '${m.label}: ${run.meters[m]} of ${DynastyRun.most}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 3, 9, 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (run.meters[m] ?? 0) <= 2 ? context.skin.lost : colour.withValues(alpha: 0.6)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SuitText(m.suit, keywords: false, style: const TextStyle(fontSize: 15, color: Colors.white)),
                const SizedBox(width: 4),
                Text('${run.meters[m]}',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: (run.meters[m] ?? 0) <= 2 ? context.skin.lost : Colors.white)),
              ]),
            ),
          ),
        ),
    ]);
  }
}
