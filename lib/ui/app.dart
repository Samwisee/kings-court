/// The app: one page, the table, in the skin's look. The skin can change
/// while it runs (the menu), and everything is drawn again in the new one.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../engine/bot.dart';

import '../platform/page_colour.dart' if (dart.library.js_interop) '../platform/page_colour_web.dart';
import '../skin/court/court_skin.dart';
import '../skin/skin.dart';
import '../skin/skin_scope.dart';
import '../skin/tailored.dart';
import 'table_page.dart';
import 'widgets/character_token.dart';

class TheKingsCourtApp extends StatefulWidget {
  const TheKingsCourtApp({super.key, this.skin = const CourtSkin()});

  /// The skin it opens in.
  final Skin skin;

  @override
  State<TheKingsCourtApp> createState() => _TheKingsCourtAppState();
}

class _TheKingsCourtAppState extends State<TheKingsCourtApp>
    with SingleTickerProviderStateMixin {
  late Skin _skin = dressed(widget.skin);

  /// The whole screen, to hold as a still while the look changes.
  final _screen = GlobalKey();

  /// The screen as it was in the old look, dissolving away over the new.
  ui.Image? _still;
  late final AnimationController _dissolve;
  late final Animation<double> _fading;

  @override
  void initState() {
    super.initState();
    // The courtiers think a slice after each frame (engine/bot.dart), so
    // their thinking never holds a frame up. (Widget tests pump their own
    // frames, and keep the plain wait.)
    if (!CharacterToken.underTest) Bot.breather = _afterNextFrame;
    colourPage(_skin.table);
    _dissolve = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _drop();
      });
    _fading = ReverseAnimation(CurvedAnimation(parent: _dissolve, curve: Curves.easeInOut));
  }

  /// Changes the look in one go: the new one is built under a still of the
  /// old (the frame that rebuilds everything is never seen), which then
  /// dissolves. With animations turned off it simply changes.
  void _choose(Skin chosen) {
    final s = dressed(chosen);
    if (s == _skin) return;
    final quiet = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    ui.Image? still;
    final screen = _screen.currentContext?.findRenderObject();
    if (!quiet && screen is RenderRepaintBoundary && screen.hasSize) {
      try {
        still = screen.toImageSync(pixelRatio: View.of(context).devicePixelRatio);
      } catch (_) {
        // Not painted yet (or no way to take one here): change without it.
      }
    }
    setState(() {
      _still?.dispose();
      _still = still;
      _skin = s;
    });
    colourPage(s.table);
    // The frame that rebuilds everything is a long one: the still holds
    // through it, and the dissolve starts after, so its first frames
    // aren't skipped.
    if (still != null) {
      _dissolve.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _still == still) _dissolve.forward(from: 0);
      });
    }
  }

  void _drop() {
    if (!mounted) return;
    setState(() {
      _still?.dispose();
      _still = null;
    });
  }

  /// Straight after the next frame, when anything on screen is moving;
  /// with nothing moving there's no frame to keep clear, so a moment's
  /// wait (for a tap) will do.
  static Future<void> _afterNextFrame() {
    final s = SchedulerBinding.instance;
    if (s.transientCallbackCount > 0 || s.hasScheduledFrame) return s.endOfFrame;
    return Future<void>.delayed(const Duration(milliseconds: 1));
  }

  @override
  void dispose() {
    _dissolve.dispose();
    _still?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SkinScope(
        skin: _skin,
        onChoose: _choose,
        child: MaterialApp(
          title: "The King's Court",
          debugShowCheckedModeBanner: false,
          theme: _skin.theme(),
          // The skin's own colours change at once; the theme does too,
          // rather than easing on its own (which rebuilt every widget for a
          // dozen frames, half in one look and half the other).
          themeAnimationDuration: Duration.zero,
          // Inside the app, so the still covers dialogs and the menu too.
          builder: (context, page) {
            final still = _still;
            return Stack(fit: StackFit.expand, children: [
              RepaintBoundary(key: _screen, child: page ?? const SizedBox.shrink()),
              if (still != null)
                IgnorePointer(
                  child: FadeTransition(
                    opacity: _fading,
                    child: RawImage(image: still, fit: BoxFit.fill),
                  ),
                ),
            ]);
          },
          home: const HomePage(),
        ),
      );
}
