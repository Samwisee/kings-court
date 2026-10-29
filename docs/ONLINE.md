# Taking the card game online

Multiplayer is built: a room on the game's web service numbers the moves
and every device plays them in that order. Every change to a game is an
action with JSON, applied in one place; a game is replayable from its
setup and its moves; each seat has a view that hides the other hands; a
fake network proves two devices stay the same through latency,
reordering, duplicates and a dropped connection.

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

## Playing online

- **The rooms.** `tool/bug_worker/rooms.js`: a Cloudflare Durable Object
  per room, named by its four-letter code, joined over a WebSocket. It
  keeps the setup, the seats, the host and every move, and numbers each
  move as it comes in. It doesn't know the rules: a device moves for its
  own seat (and may hand a task to anyone, for the King's Command), the
  host's for the courtiers and anyone away, and every table refuses a move
  the rules don't allow, the same way, because they all see the same moves
  in the same order. A host who drops hands the room to whoever's left.
- **The link.** `OnlineTable` (`net/online_table.dart`) is the
  `TableLink` to a room: moves in `seq` order, each once; moves made while
  the socket is down wait and go when it's back; it reconnects by itself,
  asking for the moves after the last it played. Devices on another build
  are turned away (they'd play the rules differently).
- **The page.** Setup's Multiplayer starts a room or joins one by code
  (`ui/online/online_setup.dart`), then waits in the room until the host
  starts it; empty seats go to courtiers. `ui/online/room_play.dart` is the
  room from the page's side. Every device deals from the shared seed and
  asks only its own player for moves; the host's device plays the
  courtiers and anyone away, crowns the King, deals each round and keeps
  the round's record. Online games aren't saved on the device.
- **Tests.** `test/online_table_test.dart` plays a whole game on two
  devices through a room in this process (`test/fake_rooms.dart`, the
  rules of rooms.js in Dart); `test/ui/online_play_test.dart` does it from
  the page, and has the host play out the seat of a friend who drops.

## Still to do

- Coming back after the app is closed: the seat is kept, but the page
  doesn't yet reopen the room.
- Private hands: today every device deals every hand from the seed. A
  server dealing would send each seat `Round.visibleTo(seat)` instead.
- An idle player: the host could play a seat that hasn't moved for a while.
