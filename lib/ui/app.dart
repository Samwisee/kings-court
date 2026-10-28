/// The app: one page, the table, in the skin's look.
library;

import 'package:flutter/material.dart';

import '../skin/court/court_skin.dart';
import '../skin/skin.dart';
import '../skin/skin_scope.dart';
import 'table_page.dart';

class TheKingsCourtApp extends StatelessWidget {
  const TheKingsCourtApp({super.key, this.skin = const CourtSkin()});

  final Skin skin;

  @override
  Widget build(BuildContext context) {
    return SkinScope(
      skin: skin,
      child: MaterialApp(
        title: "The King's Court",
        debugShowCheckedModeBanner: false,
        theme: skin.theme(),
        home: const HomePage(),
      ),
    );
  }
}
