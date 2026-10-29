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
import '../skin/skin_scope.dart';

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
  // A page of its own, not a dialog: with the keyboard up on a phone the
  // words and Send stay in view above it, whatever the browser does.
  return Navigator.of(context).push<void>(PageRouteBuilder(
    opaque: false,
    pageBuilder: (context, a, b) => _BugDialog(
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
    transitionsBuilder: (context, a, b, child) =>
        FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
  ));
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
    final skin = context.skin;
    final (title, words, done) = switch (_stage) {
      _Stage.sent => (
          'Thank you!',
          'Your report is on its way, with the game as it was, so it can be put right.',
          'Back to the game'
        ),
      _Stage.copied => (
          'Report copied',
          'It couldn’t be sent from here, so it’s been copied instead. Paste it into a message to Sam.',
          'Done'
        ),
      _ => ('Report a bug', null, null),
    };
    final writing = done == null;
    return Scaffold(
      backgroundColor: skin.feltDeep,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: writing ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Expanded(child: Text(title, style: skin.dialogTitle)),
                    if (writing)
                      IconButton(
                        tooltip: 'Cancel',
                        onPressed: _stage == _Stage.sending ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  if (!writing) ...[
                    Text(words!, style: skin.dialogBody),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(done)),
                    ),
                  ] else ...[
                    Text(
                        'What went wrong, or what did you expect to happen? '
                        'The game as it is now is sent along with it.',
                        style: skin.dialogNote),
                    const SizedBox(height: 12),
                    // As tall as there's room for: above the keyboard when
                    // it's up.
                    Expanded(
                      child: TextField(
                        key: const ValueKey('bugMessage'),
                        controller: _message,
                        autofocus: true,
                        expands: true,
                        maxLines: null,
                        maxLength: 2000,
                        textAlignVertical: TextAlignVertical.top,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(hintText: 'I tapped the Jester and nothing happened…'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      TextButton(
                          onPressed: _stage == _Stage.sending ? null : () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      const Spacer(),
                      FilledButton(
                          onPressed: _stage == _Stage.sending ? null : _send,
                          child: Text(_stage == _Stage.sending ? 'Sending…' : 'Send')),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
