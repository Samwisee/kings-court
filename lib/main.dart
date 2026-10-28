/// The King's Court. The app is in lib/ui/app.dart and its one page, the
/// table, in lib/ui/table_page.dart; see README.md for the map.
library;

import 'platform/analytics.dart';
import 'platform/crash_reports.dart';
import 'ui/app.dart';

void main() {
  Analytics.visit();
  runWithCrashReports(const TheKingsCourtApp());
}
