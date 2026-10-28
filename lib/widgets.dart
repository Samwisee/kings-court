/// The game's shared pieces of UI, used on every screen. Each part file in
/// lib/ui holds one family (icons, game text, tokens, task cards, the
/// table, panels and dialogs); their look comes from theme.dart.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'chronicle.dart';
import 'courtiers.dart';
import 'engine/cards.dart';
import 'engine/round.dart';
import 'models.dart';
import 'play/suits.g.dart';
import 'task_help.dart';
import 'theme.dart';

part 'ui/icons.dart';
part 'ui/suit_text.dart';
part 'ui/tokens.dart';
part 'ui/task_card.dart';
part 'ui/table.dart';
part 'ui/panels.dart';

/// Clamps [v] to [lo]..[hi] as a double. Unlike num.clamp it never throws
/// when the range is inverted (e.g. on a tiny window); it returns [lo].
double clampD(double v, double lo, double hi) =>
    v > hi ? (hi < lo ? lo : hi) : (v < lo ? lo : v);
