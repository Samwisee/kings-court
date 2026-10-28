// The Chronicle’s chapter picker and its crown ratings.
part of '../main.dart';

/// The rules, available from the welcome screen and during a game.
/// Chooses a Chronicle chapter in the setup dialog: any chapter up to the
/// first one not yet beaten.
class _ChapterPicker extends StatelessWidget {
  const _ChapterPicker(
      {required this.progress, required this.chapter, required this.onChanged});
  final ChronicleProgress progress;
  final int chapter;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = chronicle[chapter];
    final crowns = progress.crowns[chapter] ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.feltLine),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous chapter',
            onPressed: chapter > 0 ? () => onChanged(chapter - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text('Chapter ${chapter + 1}',
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Palette.gold)),
                Text(c.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 20)),
                const SizedBox(height: 4),
                Text(chapterSummary(c),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                CrownRating(crowns: crowns, size: 16),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next chapter',
            onPressed: chapter < chronicle.length - 1 &&
                    progress.isUnlocked(chapter + 1)
                ? () => onChanged(chapter + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// "6 points, 2 seals, decree: Silence"
String chapterSummary(Chapter c) => [
      '${c.points} points',
      if (c.seals > 0) '${c.seals} seal${c.seals == 1 ? '' : 's'}',
      if (c.decree != null) 'decree: ${c.decree!.title}',
    ].join(', ');

/// Three crowns, gold for each one earned.
class CrownRating extends StatelessWidget {
  const CrownRating({super.key, required this.crowns, this.size = 16});
  final int crowns;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: CrownIcon(
                size: size,
                color: i < crowns ? Palette.gold : const Color(0x44FFFFFF)),
          ),
      ],
    );
  }
}

/// The Chronicle: every chapter, its crowns, and which are still locked.
/// Returns the chapter the players chose to begin, if any.
Future<int?> showChronicleDialog(
    BuildContext context, ChronicleProgress progress) {
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Expanded(
            child: Text('The Chronicle',
                style: TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: Palette.gold)),
          ),
          const CrownIcon(size: 16),
          const SizedBox(width: 4),
          Text('${progress.totalCrowns}/${chronicle.length * 3}',
              style: const TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Palette.gold)),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 460,
        child: ListView.separated(
          itemCount: chronicle.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Palette.feltLine),
          itemBuilder: (context, i) {
            final c = chronicle[i];
            final unlocked = progress.isUnlocked(i);
            return ListTile(
              enabled: unlocked,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: SizedBox(
                width: 34,
                child: Text('${i + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: displayFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: unlocked ? Palette.gold : Colors.white24)),
              ),
              title: Text(c.title,
                  style: const TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              subtitle: Text(chapterSummary(c),
                  style: const TextStyle(color: Colors.white60)),
              trailing: unlocked
                  ? CrownRating(crowns: progress.crowns[i] ?? 0, size: 13)
                  : const Icon(Icons.lock_outline, color: Colors.white24),
              onTap: unlocked ? () => Navigator.pop(context, i) : null,
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    ),
  );
}
