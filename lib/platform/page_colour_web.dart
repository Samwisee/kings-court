/// The page round the game on the web: the colour behind the status bar
/// and round the safe area (web/index.html), and the browser's bars, set
/// to the table of the look worn, so the edges always match the game.
library;

import 'dart:ui';

import 'package:web/web.dart' as web;

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

void colourPage(Color table) {
  try {
    final hex = _hex(table);
    final root = web.document.documentElement as web.HTMLElement?;
    root?.style.setProperty('--table', hex);
    root?.style.setProperty('background', hex);
    web.document.body?.style.background = hex;
    web.document.querySelector('meta[name="theme-color"]')?.setAttribute('content', hex);
  } catch (_) {
    // Nothing to colour.
  }
}
