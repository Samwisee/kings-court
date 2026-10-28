/// Glowing buttons, and the keyboard shortcuts card.
library;

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets.dart';

/// A button that softly pulses with a gold glow, to draw the eye.
class GlowButton extends StatefulWidget {
  const GlowButton(
      {super.key, required this.label, required this.onPressed, this.focused = false});
  final String label;
  final VoidCallback onPressed;

  /// Chosen with the arrow keys (Enter presses it).
  final bool focused;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton>
    with TickerProviderStateMixin {
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  /// A glint of light that sweeps across the gold every couple of seconds.
  late final _sheen = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 6000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No movement for reduced motion (or in tests, where it would never
    // settle).
    final still = MediaQuery.disableAnimationsOf(context) ||
        !CharacterToken.alive;
    if (still) {
      _pulse.stop();
      _pulse.value = 0.6;
      _sheen.stop();
      _sheen.value = 0.75; // at rest, past the button
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
      _sheen.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _sheen.dispose();
    super.dispose();
  }

  // Its own layer: the glow pulses forever, and only it repaints.
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: _build(context));

  Widget _build(BuildContext context) {
    final shape = Theme.of(context).filledButtonTheme.style?.shape?.resolve({}) ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _sheen]),
        builder: (context, child) {
          // The sweep crosses in the first half of each cycle, then rests.
          final x = -1.8 + 3.6 * (_sheen.value * 5).clamp(0.0, 1.0);
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Palette.gold.withValues(alpha: 0.3 + 0.5 * _pulse.value),
                    blurRadius: 10 + 12 * _pulse.value,
                    spreadRadius: 1.5),
              ],
            ),
            child: Stack(children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipPath(
                    clipper: ShapeBorderClipper(shape: shape),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(x - 0.5, -1),
                          end: Alignment(x + 0.5, 1),
                          colors: const [
                            Color(0x00FFFFFF),
                            Color(0xAAFFF6D8),
                            Color(0x00FFFFFF),
                          ],
                          stops: const [0.3, 0.5, 0.7],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          );
        },
        child: KeyFocusRing(
          on: widget.focused,
          radius: 12,
          child: FilledButton(
            onPressed: widget.onPressed,
            style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 18)),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

/// The keyboard shortcuts, as small gold key caps with what each does.
class ShortcutsCard extends StatelessWidget {
  const ShortcutsCard({super.key});

  static const _keys = [
    (['1', '2', '…'], 'Play the card with that key'),
    (['←', '→'], 'Choose a card or a task'),
    (['↑', '↓'], 'Up to the tasks and buttons, down to your hand'),
    (['Enter'], 'Play the card, open the task, or press the button'),
    (['S'], 'Show a card (again to skip)'),
    (['Space'], 'Card tracker; hold to peek'),
  ];

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        // The court's plain panel, like every dialog.
        child: OrnateCard(
          won: false,
          court: true,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          maxWidth: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Keyboard',
                  style: TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Palette.gold,
                      shadows: feltShadow)),
              const SizedBox(height: 8),
              for (final (caps, what) in _keys)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      width: 84,
                      child: Wrap(spacing: 3, runSpacing: 3, children: [
                        for (final c in caps) KeyCap(c, size: 21),
                      ]),
                    ),
                    // Long lines wrap inside the card rather than running
                    // off its edge.
                    Flexible(
                      child: Text(what,
                          softWrap: true,
                          style: const TextStyle(
                              fontFamily: bodyFont,
                              fontSize: 13.5,
                              height: 1.25,
                              color: Colors.white)),
                    ),
                  ]),
                ),
            ],
          ),
        ),
      );
}

/// A key on the keyboard, drawn as a small gold key cap.
class KeyCap extends StatelessWidget {
  const KeyCap(this.label, {super.key, required this.size});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        padding: EdgeInsets.symmetric(horizontal: size * 0.25, vertical: size * 0.16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Palette.goldLight, Palette.gold]),
          borderRadius: BorderRadius.circular(size * 0.22),
          border: Border.all(color: Palette.goldRim),
          boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 1.5))],
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: bodyFont,
                fontSize: size * 0.62,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Palette.ink,
                decoration: TextDecoration.none)),
      );
}
