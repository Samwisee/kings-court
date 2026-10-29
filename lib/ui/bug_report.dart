/// Reporting a bug from inside the game.
///
/// The player says what went wrong; the game adds everything needed to see
/// it again: the build, the screen, and the whole game as saved (hands,
/// tasks, tricks so far) with the last moves. That goes to a small web
/// service (see tool/bug_worker/), which files it as a GitHub issue
/// labelled `bug`. Without the service, or if sending fails, the report is
/// copied so it can be sent another way.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../game/state.dart';
import '../net/table_link.dart';

import '../platform/analytics.dart';
import '../platform/build_info.dart';
import '../platform/crash_reports.dart';
import '../platform/settings.dart';
import '../platform/sfx.dart';
import 'widgets.dart';

/// Where reports go, set when the game is built
/// (`--dart-define=BUG_URL=https://…`). Empty means copy instead.
const bugReportUrl = String.fromEnvironment('BUG_URL');


/// What goes with a bug report: where the player is, their settings, and
/// the whole game as saved with every move of it ([game], null off the
/// table), so it can be loaded (GameState.fromJson) and seen exactly as
/// they saw it, or played again from the start move by move
/// (net/replay.dart, tool/replay_report). Online, the [room] too.
Map<String, dynamic> bugDetails(GameState? game,
        {required List<Move> moves,
        required bool settingUp,
        required bool keyboard,
        Map<String, dynamic>? room}) =>
    {
      'where': {
        'inGame': game != null,
        if (game != null) 'mode': game.mode.name,
        if (game != null) 'round': game.roundNumber,
        'onScreen': game?.digital ?? false,
        'settingUp': settingUp,
        if (room != null) 'room': room,
      },
      'settings': {
        'sound': Sfx.enabled,
        'fourColourSuits': Settings.fourColourSuits,
        'keyboard': keyboard,
      },
      if (game != null) 'state': game.toJson(),
      if (moves.isNotEmpty) 'moves': [for (final m in moves) m.toJson()],
    };

/// Asks what went wrong and sends it. [details] is called when the report
/// is sent, so it captures the game as it is at that moment.
Future<void> showBugReport(BuildContext context,
    {required Map<String, dynamic> Function() details}) {
  // Taken now, before the dialog covers anything up.
  final snapshot = _safely(details);
  final size = MediaQuery.sizeOf(context);
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return showDialog<void>(
    context: context,
    builder: (context) => _BugDialog(
      payload: (message) => {
        'message': message,
        'build': buildVersion,
        'device': {
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'os': defaultTargetPlatform.name,
          'screen': '${size.width.round()}x${size.height.round()}',
          'pixelRatio': dpr,
          'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
        },
        'time': DateTime.now().toUtc().toIso8601String(),
        if (recentErrors.isNotEmpty) 'recentErrors': List.of(recentErrors),
        if (Analytics.sent.isNotEmpty) 'recentEvents': List.of(Analytics.sent),
        ...snapshot,
      },
    ),
  );
}

Map<String, dynamic> _safely(Map<String, dynamic> Function() f) {
  try {
    return f();
  } catch (e) {
    return {'snapshotError': '$e'};
  }
}

class _BugDialog extends StatefulWidget {
  const _BugDialog({required this.payload});
  final Map<String, dynamic> Function(String message) payload;

  @override
  State<_BugDialog> createState() => _BugDialogState();
}

enum _Stage { writing, sending, sent, copied }

class _BugDialogState extends State<_BugDialog> {
  final _message = TextEditingController();
  _Stage _stage = _Stage.writing;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    final body = jsonEncode(widget.payload(text));
    setState(() => _stage = _Stage.sending);
    var sent = false;
    if (bugReportUrl.isNotEmpty) {
      try {
        final r = await http
            .post(Uri.parse(bugReportUrl),
                headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(const Duration(seconds: 15));
        sent = r.statusCode >= 200 && r.statusCode < 300;
      } catch (_) {}
    }
    if (!sent) await Clipboard.setData(ClipboardData(text: body));
    if (mounted) setState(() => _stage = sent ? _Stage.sent : _Stage.copied);
  }

  @override
  Widget build(BuildContext context) {
    const field = InputDecoration(isDense: true);
    return switch (_stage) {
      _Stage.sent => CourtDialog(
          title: 'Thank you!',
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context), child: const Text('Back to the game')),
          ],
          child: const Text('Your report is on its way, with the game as it was, so it can be put right.',
              textAlign: TextAlign.center),
        ),
      _Stage.copied => CourtDialog(
          title: 'Report copied',
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
          child: const Text(
              'It couldn’t be sent from here, so it’s been copied instead. '
              'Paste it into a message to Sam.',
              textAlign: TextAlign.center),
        ),
      _ => CourtDialog(
          title: 'Report a bug',
          align: CrossAxisAlignment.stretch,
          actions: [
            FilledButton(
                onPressed: _stage == _Stage.sending ? null : _send,
                child: Text(_stage == _Stage.sending ? 'Sending…' : 'Send')),
            TextButton(
                onPressed: _stage == _Stage.sending ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  'What went wrong, or what did you expect to happen? '
                  'The game as it is now is sent along with it.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('bugMessage'),
                controller: _message,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: field.copyWith(hintText: 'I tapped the Jester and nothing happened…'),
              ),
            ],
          ),
        ),
    };
  }
}
