/// The kind of device on the web, coarsely: the sort of machine, the
/// browser, and whether the game was opened from the home screen (an
/// installed app). Never the browser's whole description.
library;

import 'package:web/web.dart' as web;

String deviceKind() {
  try {
    final ua = web.window.navigator.userAgent;
    final touch = web.window.navigator.maxTouchPoints > 0;
    final machine = ua.contains('iPhone')
        ? 'iphone'
        : ua.contains('iPad') || (ua.contains('Macintosh') && touch)
            ? 'ipad'
            : ua.contains('Android')
                ? (ua.contains('Mobile') ? 'android-phone' : 'android-tablet')
                : ua.contains('Macintosh')
                    ? 'mac'
                    : ua.contains('Windows')
                        ? 'windows'
                        : ua.contains('CrOS')
                            ? 'chromebook'
                            : ua.contains('Linux')
                                ? 'linux'
                                : 'other';
    final browser = ua.contains('Firefox/')
        ? 'firefox'
        : ua.contains('Edg/')
            ? 'edge'
            : ua.contains('Chrome/') || ua.contains('CriOS/')
                ? 'chrome'
                : ua.contains('Safari/')
                    ? 'safari'
                    : 'other';
    final installed = web.window.matchMedia('(display-mode: standalone)').matches;
    return '$machine $browser${installed ? ' installed' : ''}';
  } catch (_) {
    return 'web';
  }
}
