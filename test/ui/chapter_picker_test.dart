/// The Chronicle's chapter choice (ui/setup/chapter_picker.dart): you can
/// step back freely and on only as far as you've reached, and the list of
/// every chapter gives back only one that's unlocked.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kings_court/modes/chronicle/chapters.dart';
import 'package:kings_court/ui/setup/chapter_picker.dart';

Widget page(Widget child) => MaterialApp(home: Scaffold(body: child));

IconButton button(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton,
        tooltip == 'Next chapter' ? Icons.chevron_right : Icons.chevron_left));

void main() {
  testWidgets('A new player is held to the first chapter', (tester) async {
    await tester.pumpWidget(page(ChapterPicker(
        progress: ChronicleProgress(), chapter: 0, onChanged: (_) => fail('no other chapter'))));
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text(chronicle[0].title), findsOneWidget);
    expect(button(tester, 'Previous chapter').onPressed, isNull);
    expect(button(tester, 'Next chapter').onPressed, isNull, reason: 'chapter 2 is locked');
  });

  testWidgets('A beaten chapter opens the next; back is always open', (tester) async {
    final chosen = <int>[];
    await tester.pumpWidget(page(ChapterPicker(
        progress: ChronicleProgress(crowns: {0: 2}), chapter: 1, onChanged: chosen.add)));
    expect(button(tester, 'Next chapter').onPressed, isNull, reason: 'chapter 2 isn’t beaten yet');
    await tester.tap(find.byTooltip('Previous chapter'));
    expect(chosen, [0]);
    await tester.pumpWidget(page(ChapterPicker(
        progress: ChronicleProgress(crowns: {0: 2}), chapter: 0, onChanged: chosen.add)));
    await tester.tap(find.byTooltip('Next chapter'));
    expect(chosen, [0, 1]);
  });

  testWidgets('The list of chapters gives back an unlocked one, never a locked one', (tester) async {
    int? got = -1;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async =>
                        got = await showChronicleDialog(context, ChronicleProgress(crowns: {0: 3})),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('3/${chronicle.length * 3}'), findsOneWidget);
    // Chapter 3 is locked: a tap does nothing.
    await tester.tap(find.text(chronicle[2].title));
    await tester.pumpAndSettle();
    expect(find.text('The Chronicle'), findsOneWidget);
    await tester.tap(find.text(chronicle[1].title));
    await tester.pumpAndSettle();
    expect(got, 1);
  });

  test('A chapter’s summary names its points, seals and decree', () {
    for (final c in chronicle) {
      final s = chapterSummary(c);
      expect(s, startsWith('${c.points} points'));
      expect(s.contains('seal'), c.seals > 0);
      expect(s.contains('decree'), c.decree != null);
    }
  });
}
