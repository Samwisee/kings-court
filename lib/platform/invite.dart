/// Invite links: a link that opens the game straight into a room's join
/// step, with its code filled in (`…/kings-court/?room=ABCD`), shared
/// through the phone's share sheet where there is one, or copied.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'share_text.dart' if (dart.library.js_interop) 'share_text_web.dart' as native;

/// Where the game is played, for a link made off the web (an app).
const gameUrl = 'https://samwisee.github.io/kings-court/';

/// The room an invite link opened the game with ([at] is the page's
/// address; the one open, by default), or null.
String? invitedRoom([Uri? at]) {
  final code = (at ?? Uri.base).queryParameters['room']?.trim().toUpperCase();
  return code != null && RegExp(r'^[A-Z]{4}$').hasMatch(code) ? code : null;
}

/// The invite is taken: the address loses it, so opening the game again
/// doesn't ask again.
void forgetInvite() => native.dropRoomFromAddress();

/// The link that opens the game into room [code], from the game at [at]
/// (the page open on the web; the game's address elsewhere).
Uri inviteLink(String code, [Uri? at]) =>
    (at ?? (kIsWeb ? Uri.base : Uri.parse(gameUrl))).removeFragment().replace(queryParameters: {'room': code});

/// Shares an invite to room [code]: the share sheet where there is one,
/// otherwise the link is copied. True when it went to the share sheet.
Future<bool> shareInvite(String code) async {
  final link = inviteLink(code).toString();
  const text = 'Come and play The King’s Court with me';
  if (await native.shareText(text, link)) return true;
  await Clipboard.setData(ClipboardData(text: '$text: $link'));
  return false;
}
