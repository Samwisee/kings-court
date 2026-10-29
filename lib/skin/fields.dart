/// Text boxes in a skin's own colours: a dark well on the table with an
/// edge of the skin's accent, brighter and thicker while you type in it,
/// the label in the accent once it's lifted, and the cursor and selection
/// in the accent too.
library;

import 'package:flutter/material.dart';

/// The fields' look for a skin with [accent] (its gold), corners of
/// [radius], and [font] for what's typed and the labels.
InputDecorationThemeData fieldTheme({required Color accent, required double radius, required String font}) {
  OutlineInputBorder edge(Color c, double w) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide(color: c, width: w));
  return InputDecorationThemeData(
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.24),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: TextStyle(fontFamily: font, color: Colors.white70, fontSize: 16),
    floatingLabelStyle: TextStyle(fontFamily: font, color: accent, fontWeight: FontWeight.w700),
    hintStyle: TextStyle(fontFamily: font, color: Colors.white38),
    border: edge(accent.withValues(alpha: 0.5), 1.2),
    enabledBorder: edge(accent.withValues(alpha: 0.5), 1.2),
    focusedBorder: edge(accent, 2),
    errorBorder: edge(const Color(0xFFFF8A80), 1.2),
    focusedErrorBorder: edge(const Color(0xFFFF8A80), 2),
  );
}

/// The cursor, selection and its handles in [accent].
TextSelectionThemeData selectionTheme(Color accent) => TextSelectionThemeData(
    cursorColor: accent, selectionColor: accent.withValues(alpha: 0.35), selectionHandleColor: accent);
