# Taking the card game online

Everything short of the server is built: every change to a game is an
action with JSON, applied in one place; moves are numbered; a game is
replayable from its setup and its moves; each seat has a view that hides
the other hands; a fake network proves two devices stay the same through
latency, reordering, duplicates and a dropped connection; rooms and
sessions are interfaces with an in-process implementation. What's left is
a server and a link to it.

## How it fits together

- **Actions.** A move within a round is a `MatchAction`
  (`engine/round.dart`: `PickTask`, `Pass`, `Announce`, `PlayCard`,
  `ShowCard`, `ReturnTask`), applied by `Round.apply`; `Round.problem`
  says why one isn't allowed. The rest are `GameAction`s
  (`game/actions.dart`: `Crown`, `Speak`, `MarkTask`, `UndoMark`,
  `NextRound`, `RetryRound`, `Redeal`), applied by `GameState.apply` with
  `GameState.problem`. Both are plain data: `toJson`, `fromJson`
  (`tableActionFromJson`). The page sends every action through the link
  and changes the game only when the action comes back (`_onAction` in
  main.dart); a stale action is let go.
- **Moves.** `TableLink` (`net/table_link.dart`) sends actions and plays
  back `Move`s (`seq` + action) in the order the table plays them, and
  keeps the game's history. `LocalLink` is the one in use: straight back.
- **The seed.** `GameState.seed` and `game/dice.dart` fix every random
  choice (the deal, the tasks, the exile, the courtiers' choices, the
  seats): every device at a table deals the same cards from the same seed,
  and the same seed plays the same game (`test/determinism_test.dart`).
- **Setup and replay.** `GameSetup` (`game/setup.dart`) is what a game
  starts from, kept in the game and its saves; `replay(setup, moves)`
  (`net/replay.dart`) rebuilds a game move by move. Bug reports carry the
  setup and the moves (see the bug replay tool).
- **Seat views.** `Round.visibleTo(seat)` is what a seat may see: its own
  hand, how many cards the others hold, everything public (the set-aside
  cards stay, so every device judges alike; a server judging for everyone
  could withhold them). The page draws card counts with `Round.cardsIn`
  and shown cards with `Round.holds`, so it can draw from a view.
- **Seats.** `Seats` (`game/seats.dart`): each seat held by a person (by
  session id, connected or not), a courtier, or nobody. The host plays the
  courtiers' seats and a dropped person's (`Host.plays`); a person who
  returns takes their seat back.
- **The headless table.** `HeadlessTable` (`net/headless_table.dart`) is
  the page without a screen: it deals, crowns, runs the courtiers, applies
  every move that comes back, and waits for its own moves before thinking
  again. A server runs this for a room.
- **The fake network.** `FakeNetwork` and `FakeLink`
  (`net/fake_network.dart`): a server between several links, with latency,
  reordering, duplicates and disconnection; a link hands its table the
  moves in order, each once, and a reconnecting one catches up from the
  last move it saw. `test/two_devices_test.dart` plays a round on two
  devices, one of them dropping out and coming back, and checks the two
  games end the same.
- **Rooms.** `Rooms`, `Room` and `Session` (`net/rooms.dart`): a room is
  made from a setup by its host, joined by code, each session takes a
  seat and gets a link; drops and rejoins keep the seat. `InMemoryRooms`
  runs rooms in this process on the fake network (`test/rooms_test.dart`).

## What a server does

1. **Rooms**: implement `Rooms`/`Room` over the backend (a room document
   with the setup, the seats and the host; sessions by auth id).
2. **The table**: run a `HeadlessTable` for the room (host-side today;
   server-side when there is one): it numbers each action as it arrives
   (`problem` first, so nobody plays a card they don't hold), applies it,
   and sends the move to every device. Bots play the empty seats.
3. **The link**: a `ServerLink implements TableLink` that sends actions
   to the server and plays back its moves in `seq` order, buffering early
   ones and dropping repeats as `FakeLink` does, and asks for everything
   after its last `seq` on reconnection.
4. **Views**: send each seat `Round.visibleTo(seat)` at the deal rather
   than letting devices deal from the seed, once hands must be private.

## Plan for Firebase

- `flutterfire configure`; `firebase_auth` (anonymous sign-in),
  `cloud_firestore`.
- `rooms/{code}`: setup, seats, host; `rooms/{code}/moves/{seq}`: the
  numbered moves; `rooms/{code}/hands/{seat}`: private, readable by the
  session in that seat.
- A Cloud Function applies each action with `problem`/`apply` (the engine
  is plain Dart: compile it to JS, or run it in a Dart container) and
  writes the move; the `ServerLink` listens to `moves` in order.
