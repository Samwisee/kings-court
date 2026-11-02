# Dynasty (Alpha)

A solo, story-driven roguelike. You are always the King. The court comes and
goes around you; every answer you give decides who sits at the next table,
what it costs, and which works the realm takes on. Hard by design, with
random petitions in the Slay the Spire way. Tone: *Yes, Your Grace*.

Hidden for now: on the setup screen (Single player), tap the Dynasty tile
five times within four seconds. It then reads **(Alpha)** and a sixth tap
starts a run. Runs are not saved (closing the tab ends the reign).

Code: rules and data in `lib/modes/dynasty/` (pure Dart, seeded), the court
screens in `lib/ui/modes/dynasty/court.dart` (on the throne room,
`lib/ui/dynasty/`), the wiring in `lib/ui/table_setup.dart`. Tests:
`test/dynasty_test.dart` (rules, and seeded runs played to the end by bots),
`test/ui/dynasty_flow_test.dart` (the app flow).

## The run loop

1. **Court.** The herald's news of the last hand (what finished, what
   failed, the gold earned, the stores eaten). At the start, the opening.
2. **Petition.** A courtier (or a visitor) brings a dilemma with two
   answers. Answers may cost gold (greyed out if you can't pay), move the
   meters, change loyalty, add a project to the pool, bring a visitor to
   court, and **seat the next table** (who sits, who's kept away). Every
   petition has a free answer, so you're never stuck.
3. **Pick.** The pool of works. Pick up to one per seat (at most four);
   each picked work deals its current stage's task card into the hand.
   Works whose tasks would clash in one deal can't be picked together.
4. **The hand.** Played on the digital table, you as King (seat 0), the
   seated courtiers as all-seeing bots. Target 1: it's the tasks that
   matter, not the round's win.
5. **Aftermath.** For each picked work: task done → the work moves on a
   stage and pays its points as gold; courtiers at the table whose house
   leans to that suit gain loyalty; the last stage done applies its
   reward. Task failed → its failure effect. Then upkeep: the court eats
   one ♠.
6. **Checks**, then back to 1.

## Suits, meters and money

| Suit | Meaning | Kept as |
| --- | --- | --- |
| ♦ | money | **Coffers**: gold. Points are money. Starts at 6. |
| ♥ | the people | meter, 0–10, starts at 5 |
| ♣ | the army | meter, 0–10, starts at 5 |
| ♠ | stores and works | meter, 0–10, starts at 5; −1 every hand |

Houses lean to suits: Duke ♠, Bishop ♥, General ♣, Merchant ♦.

## How a reign ends

There are no wounds. A meter at 0 ends it:

- ♥ 0: **Revolt.** The people storm the palace (death).
- ♣ 0: **Invaded.** A rival marches in; you flee (exile).
- ♠ 0: **Famine.** The great houses send you into exile.
- **Treason.** A courtier whose loyalty reaches 0 turns traitor. The next
  petition is theirs: *Hunt them down* (3 gold, ♣ −2) or *Let them go*
  (free, but a coin flip says their knife finds you: death). Either way
  they leave the court.
- **Survived.** Eight hands played: the act is won.
- **Triumph.** Raise the cathedral (the keystone, four stages): the act is
  won early.

The end screen tells how it ended and how many hands you reigned, then
returns to the menu.

## Starting state

Meters 5/5/5, 6 gold. Court: Duke, Bishop, General, Merchant, loyalty 3
each (0–5). Table of three: those a petition seats, then the most loyal
(up to four if a petition seats more). Pool: the cathedral and three of
temple / levy / granaries / bandits / tax, at random.

## Projects (10)

| Work | Suit | Stages | Done | Failed stage |
| --- | --- | --- | --- | --- |
| Raise the cathedral (keystone) | ♥ | 4 | wins the act; ♥+3 ♠+1 | ♠−1, 2 gold |
| Mend the temple roof | ♥ | 2 | ♥+2, Bishop +1 | ♥−1 |
| Search for the miller's daughter | ♥ | 2 | ♥+2, Spymaster +1 | ♥−2 |
| Raise the levy | ♣ | 2 | ♣+2, General +1 | ♥−1 |
| Fortify the border | ♣ | 3 | ♣+3 | ♣−1 |
| Hunt the bandits | ♣ | 1 | ♥+1 ♣+1 | ♣−1 |
| Fill the granaries | ♠ | 2 | ♠+3 | ♠−1 |
| Mend the river bridge | ♠ | 2 | ♠+1, 3 gold, Duke +1 | ♠−1 |
| Tax the guilds | ♦ | 2 | 8 gold; ♥−1, Merchant −1 | 2 gold |
| Hold the harvest feast | ♥ | 1 | ♥+2 ♠−1 | ♥−1 |

Each stage is a task from the task library (`engine/tasks.dart`).

## Courtiers

- **Duke** (♠): land and rents. Wants soldiers for his tenants, the abbey's
  fields, the bridge.
- **Bishop** (♥): the faithful. The temple, the winter, the abbey.
- **General** (♣): the army. Bandits, border forts.
- **Merchant** (♦): gold. Loans, the fair, the guilds.
- Visitors: the **Spymaster** (the missing girl; brings word of traitors)
  and the **Jester** (a laugh, for 2 gold). They join the court if
  welcomed.

## Petitions (12, each once an act)

roads (General), loan (Merchant), roof (Bishop), tenants (Duke),
miller (Spymaster, visitor), jest (Jester, visitor), harvest (Merchant),
forts (General), abbey (Duke against Bishop: one sits, the other is kept
away), winter (Bishop), guilds (Merchant), bridge (Duke, only while ♠ is
under 6). Plus treason, when a courtier turns.

## Open questions

- Treason is simplified to one petition and a coin flip.
- Upkeep of ♠−1 every hand: it's the clock that keeps the run hard.
- An act is 8 hands, or the cathedral. More acts come later.
- No saves yet.
