# Taking the card game online

The on-screen card game is built so a backend can be added without
rewriting the rules.

## How it fits together

- `lib/engine/cards.dart`: the deck, legal plays and who wins a trick.
- `lib/engine/rules.dart`: every task as a rule that returns done, failed
  or pending from the tricks so far.
- `lib/engine/task.dart`: `Task`, and every task in the game (`allTasks`).
- `lib/engine/match.dart`: `MatchState`, plain data that saves to JSON, and
  `MatchAction` (`PickTask`, `Announce`, `PlayCard`, `ShowCard`).
  `MatchState.apply` changes a game, and `problem()` says why an action
  isn't allowed.
- `lib/engine/bot.dart`: bot teammates that see only their own hand and
  imagine the rest (`engine/sampling.dart`), so a bot in an empty seat at
  an online table knows no more than a player would (see HANDOFF.md).
- `lib/game/bot_turn.dart`: what a courtier does on their turn
  (`botDecision`), from the game alone: pick, pass, announce, show or
  play. A server can run it for empty seats.
- `lib/net/table_link.dart`: `TableLink` is where moves are sent, and
  where they come back from. `LocalLink` is the one in use: a move comes
  straight back. Every move at the table goes through it (`_onMove` in
  main.dart makes them as they come back): `PickTask`, `Pass`,
  `Announce`, `PlayCard`, `ShowCard`.
- `GameState.seed` with `dealId` fixes each round's cards and tasks
  (`dealRandom`), so a deal can be made again anywhere.
- `GameController.mySeat` is the seat this device plays from.

The engine and the whole game model (`models.dart`, chronicle, courtiers,
story, tutorial, bot_turn) are plain Dart with no Flutter;
`test/net_test.dart` checks their imports, so they can run on a server as
they are.

## What's still in the way

- **Two records of the round.** `GameState` (tasks, owners, statuses,
  Dynasty) and `MatchState` (hands, tricks) are both kept; the page joins
  them with `_matchView` for the bots, and judges tasks itself
  (`_judgeTasks`, seals and absolution included) rather than through
  `MatchState.apply`'s `_check`. A server needs one record and one judge:
  either `MatchState` learns seals, decrees and Dynasty's rules, or the
  server runs `GameState` (it can, now it has no Flutter) and
  `MatchState` becomes its cards.
- **Dealing happens on the page** (`_syncCards`: the deal, the King, task
  swaps for impossible deals). Online, the server deals from the seed and
  the devices receive hands; `_syncCards` should become "take the deal
  the link gives".
- **Timing lives on the page** (bot delays, trick pauses, the play-out).
  Fine for one device; online, the server paces bots and devices animate
  what arrives.

## Plan for Firebase

1. `flutterfire configure`, add `firebase_core`, `firebase_auth`
   (anonymous sign-in) and `cloud_firestore`.
2. A room document: `rooms/{code}` with seats (uid or "bot"), the target,
   and a public view of `MatchState` (tasks, tricks, current trick, hand
   sizes; not the hands).
3. Hands are private: `rooms/{code}/hands/{seat}`, readable only by the
   uid in that seat (security rules).
4. Actions are written to `rooms/{code}/actions` in order. A Cloud
   Function (Dart engine compiled to JS, or ported to TypeScript) checks
   each with `problem()`, applies it, and writes the new state. That keeps
   anyone from playing a card they don't hold.
5. A `FirestoreLink implements TableLink` writes each move to the actions
   collection and emits the moves the function accepts, in order. Bots can
   run in the same function for empty seats.

`Task` and the task data are already Flutter-free (`lib/engine/task.dart`,
`lib/tasks.dart`).
