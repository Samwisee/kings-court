/// The app: one page, the table, in the court's theme.
library;

import 'package:flutter/material.dart';

import '../skin/theme.dart';
import 'table_page.dart';

class TheKingsCourtApp extends StatelessWidget {
  const TheKingsCourtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "The King's Court",
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomePage(),
    );
  }
}
