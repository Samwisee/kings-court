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
- `lib/engine/bot.dart`: bot teammates (random playouts).
- `lib/net/table_link.dart`: `TableLink` is where moves are sent, and
  where they come back from. `LocalLink` is the one in use: a move comes
  straight back. The table (`_onMove` in main.dart) plays card plays and
  shown cards as they come back; taking tasks and passing still go
  through `GameState` directly, and are the next to move onto the link.

The whole engine is plain Dart (no Flutter); `test/net_test.dart` checks
its imports, so it can run on a server as it is.

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
