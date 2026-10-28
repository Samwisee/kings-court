# Adding tasks without making rounds impossible

Every task added makes the number of possible pairings grow, and most
"impossible round" bugs come from pairings nobody thought about. This is the
system that keeps that under control, and the checklist for a new task.

## 1. Know which tier it is in

Every task falls into a tier by *how it can go wrong*
(`lib/engine/deal_mix.dart`, `tierOf`):

| Tier | Example | Why it's risky | Deal rule |
| --- | --- | --- | --- |
| capture | Win the 3♥, Win at least two Aces | Only by competing for the same cards | Never two that need more of a card/rank/suit than exists (`clash`) |
| trick | Win a trick with a 5, Win the first trick | Same, plus timing | Same; two tasks can't both need the same trick |
| avoid | Don't win any 9s, Win no ♠ cards | Someone else must take what you avoid | No card may be avoided by every player (`overAvoided`) |
| race | Win more tricks than the King | Measured against other players | At most 2 a round |
| precise | Win exactly two tricks, Win only the last trick | Too many *and* too few both fail, so it fights everything | At most 1 a round, drawn half as often |

Capture and trick tasks are *monotone*: winning more never hurts. They are
the safe place to add variety. Avoid, race and precise tasks are where the
impossible rounds come from, so add them sparingly and give them a profile.

## 2. How the draw keeps rounds fair and fresh

* **Weighted shuffle.** Each tier has a weight (`tierWeight`); precise tasks
  turn up about half as often as capture tasks, so they still appear but
  rarely stack with other hard tasks.
* **Tier limits.** `tierLimit` caps precise at 1 and race at 2 per round.
* **Bigger tasks at bigger targets.** As the point target rises past 10, the
  draw leans toward higher-point tasks, so a 20-point round is five or six
  meaty tasks rather than nine small ones tangling together. Difficulty comes
  from the tasks, not from the number of interactions.
* **Clash checks.** `clash` (two players), `selfClash` (one player holding
  both), `overAvoided` (whole table) and `handBlocks` (your own cards) run
  on every draw and every pick.
* **After the deal** (on-screen games), any task the cards make impossible is
  swapped for one of similar value.

## 3. Checklist for a new task

1. **Write it so more is never worse**, if you can. "Win at least two Aces"
   is safe; "Win exactly two Aces" is precise.
2. `lib/tasks.dart`: description and points for 3/4/5/6 players. Start from
   a similar existing task's points.
3. `lib/engine/rules.dart`: the rule (`taskRules`), and add it to
   `_anyTrickTasks` or `_earlyTasks` if it can be done mid-round (seals use
   this). Add a tracker in `taskProgress` if it counts something.
4. `lib/engine/conflicts.dart`: a `TaskProfile` naming the cards, ranks,
   suits, Court Cards and tricks it needs or forbids. **This is what stops
   impossible pairings**: a task with no profile can't clash with anything.
   Add a `handBlocks` line if it needs a card in your own hand.
5. `lib/task_help.dart`: a plain-words explanation (tests fail without one).
6. Check `tierOf` puts it in the tier you expect (add a case to the
   engine test).
7. Push, and read the **balance report** (below). Adjust points or the
   profile until it sits in line with similar tasks.

## 4. The balance report

`tool/balance/balance_test.dart` has the bots play hundreds of rounds at
3, 4 and 5 players and targets 6 to 22, and reports:

* win rate by table size and target,
* win rate by how many precise tasks were dealt,
* every task, hardest first: the round win rate when it's on the table, and
  how often it failed itself,
* the worst pairs dealt together.

It runs on GitHub Actions whenever tasks or rules change (and by hand from
the Actions tab, "Balance", with a longer time). The report lands on the
`balance` branch as `latest.txt`, plus one file per commit to compare.

The bots play fair, seeing only their own hands (as in the game), so the
numbers are close to what a good table of people would manage
(`BALANCE_OMNISCIENT=1` gives the old all-seeing, best-case numbers).
Rough guide:

* A task whose round win rate is well below others of its points is
  underpriced: raise its points or tighten its profile.
* A pair that the bots almost never win needs a `clash` rule (or the tasks
  belong in a tier with a limit).
* If a whole target is below about 40% for the bots, people will find it
  near impossible: lower tier weights or limits at that target.

## What the first reports showed (Oct 2026)

* **Precise tasks hurt most.** Rounds with no precise task were won 35% of
  the time, rounds with one 21%; before the limit, rounds with two or more
  were won 11%. Hence the limit of one.
* **The number of tasks decides a round more than the points do.** Two or
  three tasks: about 65%; five: 29%; seven: 10%; nine or more: 5% or less.
* **Targets above about 14 are close to impossible even for the bots**
  (4 players: 21% at 14, 7% at 18, 2% at 22), and leaning toward bigger
  tasks barely helps because big tasks fail on their own. Making high
  targets winnable needs something besides more tasks: a cap on the target,
  harder seals or decrees instead of extra points, or new mid-value tasks
  that are worth more without being harder.
* "Win a trick with" a number now counts the card it needs, so it is no
  longer dealt beside "Win all four" of the same number.
* The targets are capped at 20.

## The library is the game's own (Oct 2026)

The task list began as an adaptation of The Crew's. It is now a library of
the King's Court's own, built in two passes:

* **Second edition (28 Oct 2026): rebuilt around the court.** The borrowed
  compositions are gone: trick totals, odd and even tricks, "win an X with
  a Y" pairings, suit balances ("as many ♠ as ♣"), the secret bid, the
  "and no other Court Card" tasks and their redeal clauses, "don't lead"
  by suit, and the run-of-tricks exact counts. In their place are tasks
  about the game's own pieces: the King's tricks (a trick the King leads,
  the trick after the King wins, no tricks until the King has won, more
  Court Cards than the King), the Court Cards by name (the Joker, the
  Jack, the Queen with the King, two Court Cards in one trick) and the
  shape of a trick (won by one rank, won by the last to play, a trick
  nobody followed, three suits in one trick, two tricks with the same
  rank, the trick after the Queen falls). What remains from the first
  pass is the plain stock of every trick-taking game: win a named card, a
  count of a rank or suit, the first or last trick, exactly N tricks, no
  tricks, nothing of a suit.
* **Not legal advice.** Game mechanics can't be copyrighted; a specific
  curated list and its wording can be. The library is now a different
  selection in the court's own words. Before anything is sold, have a
  lawyer look at it, with The Crew's task cards beside it.
* **First pass:** new card picks, numbers and wording for the kept tasks.
* **Points from the game's own data.** Every task's points, at each table
  size, come from the balance report: points are proportional to
  -ln(chance the task succeeds), scaled so the average task keeps the same
  average points (so targets mean what they did). Rerun the report and
  paste its SUGGESTED POINTS whenever the library changes.
* `renamedTasks` in lib/tasks.dart maps old wording to new so saved games
  still load.

Plain ones like "Win the first trick" or "Win the Queen" stay as they are:
they are how anyone would say it.

## 5. Ideas that fit the system

Safe (capture/trick, monotone):

* Win a trick containing two cards of the same rank
* Win a trick where the cards are all different suits
* Win a trick led by the King
* Win both red 9s (9♥ and 9♦)
* Win a trick with the lowest card of the suit led winning it (someone else
  couldn't follow)

Spicy (precise/avoid, give them profiles and keep the limits):

* Win exactly one Ace
* Don't win any of the last three tricks
* Win fewer ♠ cards than anyone else

Possible later steps:

* **Solve before dealing.** On-screen games could run the bots' playouts on
  each deal and redraw when no assignment of tasks looks winnable. It needs
  to run in slices so the screen doesn't stall.
* **Tier budgets by target**, e.g. a second precise task allowed only above
  20 points, if the report shows rounds there are too easy.
