/// The very same widget for the same thing, from one build to the next.
///
/// Flutter keeps what's on screen without building or laying it out again
/// only when a widget is the identical object it had before. Small pieces
/// built afresh on every rebuild never are, which matters most for the
/// icons set inline in game text (a suit, a crown, a seal): as inline
/// widgets they make their whole paragraph lay out again whenever anything
/// above them rebuilds, which on the table is every move. Kept here by
/// what they show, they come back identical, and the paragraph is left as
/// it was.
library;

import 'package:flutter/widgets.dart';

abstract final class Same {
  /// The newest last; the oldest go once there are more than [_most].
  static final _kept = <Object, Widget>{};
  static const _most = 400;

  /// The widget [build] makes for [value], the same one each time:
  /// [value] (a record, compared by what's in it) must hold everything the
  /// widget shows. Anything it reads from its context (the skin) still
  /// rebuilds it when that changes. Nothing in it may hold on to a
  /// context: use a [Builder] for that.
  static Widget of(Object value, Widget Function() build) {
    final kept = _kept.remove(value);
    final widget = kept ?? build();
    _kept[value] = widget;
    if (_kept.length > _most) _kept.remove(_kept.keys.first);
    return widget;
  }
}
