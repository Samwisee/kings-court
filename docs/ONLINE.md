# Taking the card game online

The on-screen card game is built so a backend can be added without
rewriting the rules.

## How it fits together

- `lib/engine/cards.dart`: the deck, legal plays and who wins a trick.
- `lib/engine/rules.dart`: every task as a rule that returns done, failed
  or pending from the tricks so far.
- `lib/engine/match.dart`: `MatchState`, plain data that saves to JSON, and
  `MatchAction` (`PickTask`, `Announce`, `PlayCard`). `MatchState.apply`
  is the only thing that changes a game, and `problem()` says why an
  action isn't allowed.
- `lib/engine/bot.dart`: bot teammates (random playouts).
- `lib/play/controller.dart`: `MatchConnection` is where actions are sent.
  `MatchController` is the local one: it applies actions on this device
  and lets bots take their turns.

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
5. A `FirestoreConnection implements MatchConnection` sends actions and
   rebuilds the screen from the room document. Bots can run in the same
   function for empty seats.

Note: `Task` currently lives in `models.dart`, which imports Flutter for
colours. Before the engine runs on a server, move `Task` and the task data
into a Flutter-free file.
