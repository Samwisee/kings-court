/// A courtier's card: their house and story, and their card reveal (on
/// screen, yours to use; at a real table, a pip to mark it used).
library;

import 'package:flutter/material.dart';

import '../../engine/round.dart';
import '../../game/courtiers.dart';
import '../../game/state.dart';
import '../../skin/skin_scope.dart';
import '../../skin/theme.dart';
import '../widgets.dart';
import '../widgets/house_banner.dart';

/// Opens [CourtierCard] as a dialog.
Future<void> showCourtierCard(BuildContext context, CourtierCard card) =>
    showDialog<void>(context: context, builder: (_) => card);

class CourtierCard extends StatelessWidget {
  const CourtierCard({
    super.key,
    required this.seat,
    required this.courtier,
    required this.player,
    required this.round,
    required this.quarterTurns,
    required this.onScreen,
    required this.choosingKing,
    this.you = -1,
    this.onSpeak,
    this.onToggleReveal,
  });

  final int seat;
  final Courtier courtier;
  final Player player;
  final Round round;

  /// Turned to face the seat at a real table.
  final int quarterTurns;
  final bool onScreen;
  final bool choosingKing;

  /// Your seat on screen (your card offers to show a card).
  final int you;

  /// Show a card now; null when you can't.
  final VoidCallback? onSpeak;

  /// At a real table: the seat's card reveal is marked used (or not).
  final void Function(bool on)? onToggleReveal;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isKing = round.king == seat;
    return StatefulBuilder(
        builder: (context, setDialogState) {
          final spoke = round.spoke[seat];
          final canSpeak = round.canSpeak(seat) || spoke;
          final speak = onSpeak;
          return RotatedBox(
            quarterTurns: quarterTurns,
            child: Dialog(
              backgroundColor: skin.paper,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              // Edged in the player's colour, like their tasks.
              shape: HighVisBorder(player.color, context.skin),
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HouseBanner(
                        courtier: courtier,
                        color: player.color,
                        name: isKing ? '${player.name}, the King' : player.name,
                        king: isKing,
                      ),
                      // A gilt band between the banner and the card.
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            skin.goldDeep,
                            skin.goldLight,
                            skin.gold,
                            skin.goldDeep,
                          ]),
                          border: Border(
                              bottom: BorderSide(color: skin.outlineColour)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(courtier.story,
                                style: TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                    color: skin.inkSoft)),
                            if (onScreen && !choosingKing) ...[
                              const SizedBox(height: 8),
                              if (seat == you)
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  OutlinedButton.icon(
                                    onPressed: speak == null
                                        ? null
                                        : () {
                                            Navigator.pop(context);
                                            speak();
                                          },
                                    icon: const Icon(Icons.record_voice_over),
                                    label: Text(spoke ? 'Card shown' : 'Show a card'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: skin.ink,
                                        disabledForegroundColor: skin.inkSoft,
                                        side: BorderSide(color: skin.ink)),
                                  ),
                                ])
                              else
                                Text(
                                    spoke ? 'Has shown a card.' : 'Hasn\u2019t shown a card.',
                                    style: TextStyle(
                                        fontSize: 15, color: skin.inkSoft)),
                            ],
                            if (!choosingKing && !onScreen) ...[
                              const Divider(height: 26),
                              Row(children: [
                                SpeakToken(
                                    used: spoke,
                                    locked: !canSpeak,
                                    size: 26),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                      !canSpeak
                                          ? 'Silence: no card reveals this round'
                                          : spoke
                                              ? 'Card reveal used'
                                              : 'Card reveal available',
                                      style: TextStyle(
                                          fontSize: 15, color: skin.ink)),
                                ),
                                MouseRegion(cursor: canSpeak ? SystemMouseCursors.click : MouseCursor.defer, child: GestureDetector(
                                  onTap: !canSpeak
                                      ? null
                                      : () {
                                          onToggleReveal?.call(!round.spoke[seat]);
                                          setDialogState(() {});
                                        },
                                  child: Semantics(
                                    toggled: spoke,
                                    label: 'Card reveal used',
                                    child: GoldPip(on: spoke, enabled: canSpeak, size: 26),
                                  ),
                                )),
                              ]),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Row(
                          children: [
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                  foregroundColor: skin.ink),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
  }
}
