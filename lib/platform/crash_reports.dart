/// Crash reports: errors the player never mentions.
///
/// With a Sentry DSN set at build time (`--dart-define=SENTRY_DSN=…`), every
/// uncaught error goes to Sentry with the build it came from. Errors only:
/// no performance tracing, no personal details. Either way, the last few
/// errors are kept here so a bug report can include them.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'build_info.dart';

const sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// The last few errors this session, newest last, for bug reports.
final List<String> recentErrors = [];

void _remember(Object error, StackTrace? stack) {
  final top = stack?.toString().split('\n').take(8).join('\n') ?? '';
  recentErrors.add('$error\n$top'.trim());
  if (recentErrors.length > 8) recentErrors.removeAt(0);
}

/// Runs the app, with crash reports when a DSN is set.
Future<void> runWithCrashReports(Widget app) async {
  void start() {
    // Chain after Sentry's own handlers (when there), so both see errors.
    final flutterPrev = FlutterError.onError;
    FlutterError.onError = (details) {
      _remember(details.exception, details.stack);
      flutterPrev?.call(details);
    };
    final platformPrev = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _remember(error, stack);
      return platformPrev?.call(error, stack) ?? false;
    };
    runApp(sentryDsn.isEmpty ? app : SentryWidget(child: app));
  }

  if (sentryDsn.isEmpty) return start();
  await SentryFlutter.init(
    (o) {
      o.dsn = sentryDsn;
      o.release = 'kings-court@$buildVersion';
      o.environment = kReleaseMode ? 'production' : 'debug';
      o.tracesSampleRate = 0;
      o.sendDefaultPii = false;
    },
    appRunner: start,
  );
}
