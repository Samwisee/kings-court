/// The King's Court. The app is in lib/ui/app.dart and its one page, the
/// table, in lib/ui/table_page.dart; see README.md for the map.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'platform/analytics.dart';
import 'platform/crash_reports.dart';
import 'ui/app.dart';

/// Kept so the accessibility tree stays built (see [main]).
// ignore: unused_element
SemanticsHandle? _semantics;

void main() {
  // For tests on real devices (Pocket Lab's journeys, docs/JOURNEYS.md):
  // `?semantics=1` builds the accessibility tree from the start, so a step
  // can find "New game" by its words; otherwise the page is one canvas.
  // Players don't get it this way: a screen reader turns it on by itself.
  if (kIsWeb && Uri.base.queryParameters['semantics'] == '1') {
    WidgetsFlutterBinding.ensureInitialized();
    _semantics = SemanticsBinding.instance.ensureSemantics();
  }
  Analytics.visit();
  runWithCrashReports(const TheKingsCourtApp());
}
