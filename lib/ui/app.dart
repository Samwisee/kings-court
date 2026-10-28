/// The app: one page, the table, in the skin's look. The skin can change
/// while it runs (the menu), and everything is drawn again in the new one.
library;

import 'package:flutter/material.dart';

import '../skin/court/court_skin.dart';
import '../skin/skin.dart';
import '../skin/skin_scope.dart';
import 'table_page.dart';

class TheKingsCourtApp extends StatefulWidget {
  const TheKingsCourtApp({super.key, this.skin = const CourtSkin()});

  /// The skin it opens in.
  final Skin skin;

  @override
  State<TheKingsCourtApp> createState() => _TheKingsCourtAppState();
}

class _TheKingsCourtAppState extends State<TheKingsCourtApp> {
  late Skin _skin = widget.skin;

  @override
  Widget build(BuildContext context) {
    return SkinScope(
      skin: _skin,
      onChoose: (s) {
        if (s != _skin) setState(() => _skin = s);
      },
      child: MaterialApp(
        title: "The King's Court",
        debugShowCheckedModeBanner: false,
        theme: _skin.theme(),
        home: const HomePage(),
      ),
    );
  }
}
