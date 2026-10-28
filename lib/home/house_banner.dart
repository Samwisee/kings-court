// A courtier’s banner, at the top of their card.
part of '../main.dart';

/// The top of a courtier's card: a wash of their colour with their sigil
/// large behind the house name and motto.
class _HouseBanner extends StatelessWidget {
  const _HouseBanner(
      {required this.courtier,
      required this.color,
      required this.name,
      required this.antagonist,
      this.king = false});
  final Courtier courtier;
  final Color color;
  final String name;
  final bool antagonist;

  /// The King's seat: their token wears the crown, as at the table.
  final bool king;

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(color, const Color(0xFF0A0A0A), 0.55)!;
    return Container(
      constraints: const BoxConstraints(minHeight: 128),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: antagonist
              ? [const Color(0xFF5A0C18), Palette.traitorDeep]
              : [color, deep],
        ),
      ),
      child: Stack(
        // The token and words sit in the middle of the band, top to bottom.
        alignment: AlignmentDirectional.centerStart,
        children: [
          // The sigil, big and faint, like a banner on the wall.
          Positioned(
            right: -26,
            top: -14,
            child: Opacity(
              opacity: 0.22,
              child: ShapedToken(
                  shape: courtier.shape,
                  size: 160,
                  color: Colors.white,
                  ring: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  if (king)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: CrownIcon(size: 26),
                    ),
                  ShapedToken(
                      shape: courtier.shape,
                      size: 52,
                      color: antagonist ? Palette.traitor : color,
                      ring: Palette.gold,
                      ringWidth: 2.5),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A player's own name, only when it says something the
                      // title doesn't ("The Jester" once is enough).
                      if (!name.toLowerCase().contains(
                          courtier.title.toLowerCase().replaceFirst('the ', '')))
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70)),
                      Text(courtier.title,
                          style: const TextStyle(
                              fontFamily: displayFont,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              height: 1.1,
                              color: Colors.white)),
                      Text(courtier.house,
                          style: const TextStyle(
                              fontFamily: displayFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Palette.gold)),
                      const SizedBox(height: 2),
                      Text('“${courtier.motto}”',
                          style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
