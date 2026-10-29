/// The tasks flying from the middle of the on-screen table to whoever took
/// them. Each is laid out at its owner first, unseen; a frame later, once
/// its place there is known, a copy flies exactly there, and it shows as
/// the copy lands, so nothing jumps.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../engine/round.dart';
import '../cards/task_chip.dart';

class TaskFlights {
  /// The open tasks in the middle, where each is, and their type size.
  final openKeys = <RoundTask, GlobalKey>{};
  Map<RoundTask, Rect> openRects = {};
  double openFontSize = 13;

  /// Where each task sits in front of its owner, and how it's drawn there
  /// (its width and type size).
  final destKeys = <RoundTask, GlobalKey>{};
  final miniStyle = <RoundTask, (double, double)>{};

  /// Tasks on their way to their owner: laid out there but not shown yet.
  final Set<RoundTask> landing = {};

  /// The copies in the air.
  final flights = <Flight>[];
  final _timers = <Timer>[];

  /// Who held each task last time, to see which were taken since.
  Map<RoundTask, int?> _owners = {};

  /// Sends each task taken since last time flying to its owner. [rectOn]
  /// finds where a keyed widget is on the table; [flight] makes the copy
  /// (from, to, at its owner's type size); [update] changes what's shown,
  /// while [mounted].
  void launch(List<RoundTask> tasks,
      {required Rect? Function(GlobalKey key) rectOn,
      required Flight Function(RoundTask task, Rect from, Rect to, double toFont) flight,
      required bool Function() mounted,
      required void Function(VoidCallback change) update}) {
    final owners = {for (final t in tasks) t: t.owner};
    final taken = <(RoundTask, Rect)>[];
    for (final t in tasks) {
      final owner = owners[t];
      if (_owners[t] != null || owner == null) continue;
      // Where the card is right now on screen (last frame), not where it
      // was when the middle was last built: that may have been part way
      // through the deal, when it was still sliding in from the side.
      final key = openKeys[t];
      final from = (key == null ? null : rectOn(key)) ?? openRects[t];
      if (from == null) continue;
      landing.add(t);
      taken.add((t, from));
    }
    _owners = owners;
    if (taken.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted()) return;
      for (final (t, from) in taken) {
        final key = destKeys[t];
        final to = key == null ? null : rectOn(key);
        if (to == null) {
          landing.remove(t);
          continue;
        }
        final style = miniStyle[t] ?? (to.width, 12.0);
        final f = flight(t, from, to, style.$2);
        flights.add(f);
        _timers.add(Timer(Flight.duration, () {
          if (mounted()) {
            update(() {
              flights.remove(f);
              landing.remove(t);
            });
          }
        }));
      }
      update(() {});
    });
  }

  /// Stops every flight's timer (the page is going).
  void cancel() {
    for (final t in _timers) {
      t.cancel();
    }
  }
}
