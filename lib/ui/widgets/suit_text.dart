/// Game text: suits in colour, named cards, icons, and gold game words you can tap.
library;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../skin/skin.dart';
import '../../skin/skin_scope.dart';
import 'icons.dart';
import 'panels.dart';
import 'same.dart';

/// Game text with suits printed in their card colours (♥ ♦ in red,
/// ♠ ♣ in black) and the term "Court Cards" always capitalised and set a
/// little bolder, so it reads as a game term.
class SuitText extends StatelessWidget {
  const SuitText(this.text,
      {super.key,
      required this.style,
      this.textAlign,
      this.struck = const {},
      this.maxLines,
      this.overflow,
      this.keywords = true,
      this.leading = const [],
      this.trailing = const []});
  final String text;

  /// Set before the words and after them, in the same lines (a task's
  /// points, how far along it is).
  final List<InlineSpan> leading;
  final List<InlineSpan> trailing;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Game words set in gold, a little bolder, each tappable for what it
  /// means (the first time each appears). Off on small task cards, where a
  /// tap opens the card.
  final bool keywords;

  /// The game words found in text, and the glossary entry each opens.
  static const _terms = <(String, String)>[
    ('follow(?:ing|s)? suit', 'Follow suit'),
    ('court cards?', 'Court Cards'),
    ('tricks?', 'Trick'),
    ('lead|leads|led|leading', 'Lead'),
    ('suits?', 'Suit'),
    ('aces?', 'Ace'),
    ('the king', 'The King'),
    ('in a row', 'In a row'),
    ('total|totalling', 'Total'),
    ('pass|passes', 'Pass'),
    ('show(?:s|ing)? (?:a|one) card', 'Show a card'),
    ('(?:wax )?seals?', 'Seal'),
    ('(?:royal )?decrees?', 'Royal decree'),
  ];
  static final _termPattern = RegExp(
      [for (final (i, (p, _)) in _terms.indexed) '(?<k$i>\\b(?:$p)\\b)'].join('|'),
      caseSensitive: false);

  /// Cards named in the text that are already won ("A♥"), crossed out.
  final Set<String> struck;

  static final _marked = RegExp(r'([A2-9])([♥♦♠♣])|[♥♦♠♣]|\uE000|\uE001|\uE002|\uE003|\bcourt cards?\b',
      caseSensitive: false);

  /// Markers [Task.boardText] uses: no Court Cards, and a Court Card.
  static const noCourt = '\uE000';
  static const court = '\uE001';

  /// Markers for the buttons by your hand, drawn as they look there: show a
  /// card, and the card tracker.
  static const showButton = '\uE002';
  static const trackerButton = '\uE003';

  /// A card named on the felt: a little card of its own, rank and suit in
  /// the colours the card is printed in, so the words match the cards.
  InlineSpan _cardChip(Skin skin, String? rank, String symbol, bool done) {
    final fs = style.fontSize ?? 14;
    final suit = Suit.values.firstWhere((s) => s.symbol == symbol);
    final colour = skin.suitColour(suit);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Same.of(('card', rank, symbol, done, fs, colour, skin.card, skin.outlineColour, skin.bodyFont), () => Opacity(
        opacity: done ? 0.5 : 1,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: fs * 0.08),
          padding: EdgeInsets.fromLTRB(fs * 0.22, fs * 0.04, fs * 0.22, fs * 0.06),
          decoration: BoxDecoration(
            color: skin.card,
            borderRadius: BorderRadius.circular(fs * 0.22),
            border: Border.all(color: skin.outlineColour),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (rank != null)
              Text(rank,
                  style: TextStyle(
                      fontFamily: skin.bodyFont,
                      fontSize: fs * 0.88,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: colour,
                      shadows: const [],
                      decoration: done ? TextDecoration.lineThrough : null)),
            SuitIcon(suit, size: fs * 0.74, color: colour),
          ]),
        ),
      )),
    );
  }

  /// A game word in gold, a little bolder; tap it to read what it means.
  InlineSpan _keyword(
      BuildContext context, String word, String term, TextStyle base, bool dark) {
    final colour = dark ? context.skin.gold : context.skin.goldDeep;
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Same.of(('word', word, term, base, colour), () => Semantics(
        button: true,
        hint: 'What it means',
        child: MouseRegion(cursor: SystemMouseCursors.click, child: Builder(
          // Its own context: the word may be shown again in another
          // paragraph (Same), so it can't keep the first one's.
          builder: (context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showTermDialog(context, term),
            child: Text(word, style: base.copyWith(color: colour, fontWeight: FontWeight.w700)),
          ),
        )),
      )),
    );
  }

  InlineSpan _suit(String symbol, Color colour) {
    final size = (style.fontSize ?? 14) * 0.8;
    return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Same.of(('suit', symbol, size, colour), () => Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.04),
          child: SuitIcon(Suit.values.firstWhere((s) => s.symbol == symbol),
              size: size, color: colour),
        )));
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final spans = <InlineSpan>[];
    // On a dark background, suits are printed in lighter colours so they
    // keep their contrast.
    final dark = (style.color?.computeLuminance() ?? 0) > 0.3;
    final seen = <String>{};
    final base = DefaultTextStyle.of(context).style.merge(style);

    // Plain words, with any game words in them picked out.
    void words(String part) {
      if (!keywords) {
        spans.add(TextSpan(text: part));
        return;
      }
      var at = 0;
      for (final m in _termPattern.allMatches(part)) {
        var term = '';
        for (var i = 0; i < _terms.length; i++) {
          if (m.namedGroup('k$i') != null) term = _terms[i].$2;
        }
        if (!seen.add(term)) continue;
        if (m.start > at) spans.add(TextSpan(text: part.substring(at, m.start)));
        spans.add(_keyword(context, m.group(0)!, term, base, dark));
        at = m.end;
      }
      if (at < part.length) spans.add(TextSpan(text: part.substring(at)));
    }

    Color suitColour(String symbol) {
      final suit = Suit.values.firstWhere((s) => s.symbol == symbol);
      return dark
          ? skin.suitColourOnDark(suit, style.color!)
          : skin.suitColour(suit);
    }

    var last = 0;
    for (final m in _marked.allMatches(text)) {
      if (m.start > last) words(text.substring(last, m.start));
      final token = m.group(0)!;
      if (m.group(1) != null && dark) {
        spans.add(_cardChip(skin, m.group(1), m.group(2)!, struck.contains(token)));
      } else if (m.group(1) != null) {
        // A named card: its rank, then its suit in colour; crossed out once
        // it's been won.
        final done = struck.contains(token);
        final cross = done
            ? TextDecoration.lineThrough
            : TextDecoration.none;
        final mark = TextStyle(
            decoration: cross,
            decorationThickness: 2.5,
            decorationColor: style.color ?? skin.ink);
        spans.add(TextSpan(
            text: m.group(1),
            style: mark.copyWith(
                color: done ? (style.color ?? skin.ink).withValues(alpha: 0.5) : null)));
        spans.add(_suit(m.group(2)!,
            done ? suitColour(m.group(2)!).withValues(alpha: 0.5) : suitColour(m.group(2)!)));
      } else if (token == noCourt || token == court) {
        final size = (style.fontSize ?? 14) * 0.95;
        spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Same.of(('court', token, size), () => Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.08),
              child: token == noCourt
                  ? NoCourtIcon(size: size)
                  : CourtCardIcon(size: size * 1.05),
            ))));
      } else if (token == showButton || token == trackerButton) {
        final size = (style.fontSize ?? 14) * 1.25;
        final c = dark ? skin.gold : skin.goldDeep;
        spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Same.of(('button', token, size, c), () => Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.08),
              child: token == showButton
                  ? ShowCardIcon(size: size, color: c)
                  : TrackerIcon(size: size, color: c),
            ))));
      } else if (token.length == 1) {
        spans.add(_suit(token, suitColour(token)));
      } else {
        final plural = token.toLowerCase().endsWith('s');
        final name = plural ? 'Court Cards' : 'Court Card';
        if (keywords && seen.add('Court Cards')) {
          spans.add(_keyword(context, name, 'Court Cards', base, dark));
        } else {
          spans.add(TextSpan(
              text: name, style: const TextStyle(fontWeight: FontWeight.w700)));
        }
      }
      last = m.end;
    }
    if (last < text.length) words(text.substring(last));
    return Text.rich(TextSpan(style: style, children: [...leading, ...spans, ...trailing]),
        textAlign: textAlign, maxLines: maxLines, overflow: overflow);
  }
}
