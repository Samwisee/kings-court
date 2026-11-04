# Journeys: the game on real phones

Pocket Lab (the device lab) plays these on its devices after a deploy and
on its daily check. What's saved on the site in Pocket Lab is the "Saved"
set; change both together.

The game is drawn on one canvas, so the steps find buttons by their words
only with `?semantics=1`, which builds the accessibility tree from the start
(lib/main.dart). Players never get it that way. `drawn` after a tap lets
the panels finish sliding in before the next tap.

## Saved (passing on Chrome and the Pixel)

```
flow front-page
open /?semantics=1
wait for "New game"
drawn
not "Error"
shot front-page
```

## Not saved yet

These pass as far as starting a game on Chrome at phone size, then stop:

- **The Pixel:** `tap "Single player"` reports done but the next step never
  comes ("Free play" doesn't appear), every time.
- **Every device:** `tap "Menu"` reports done but the menu doesn't open
  ("Store", "How to Play", "Sign in" never appear).

Both look like taps that land but don't reach the button (Pocket Lab's side
to explain: it says which element it tapped). Save them once they pass.

```
flow free-play
open /?semantics=1
wait for "New game"
drawn
tap "New game"
wait for "Single player"
drawn
tap "Single player"
wait for "Free play"
drawn
tap "Free play"
wait for "Next"
tap "4"
tap "Next"
wait for "Start"
drawn
tap "Start"
wait for "Menu"
drawn
drawn
not "Error"
shot table

flow store
open /?semantics=1
wait for "New game"
drawn
tap "New game"
wait for "Single player"
drawn
tap "Single player"
wait for "Free play"
drawn
tap "Free play"
wait for "Next"
tap "4"
tap "Next"
wait for "Start"
drawn
tap "Start"
wait for "Menu"
drawn
drawn
tap "Menu"
wait for "Store"
tap "Store"
wait for "Style"
drawn
shot store

flow how-to-play
open /?semantics=1
wait for "New game"
drawn
tap "New game"
wait for "Single player"
drawn
tap "Single player"
wait for "Free play"
drawn
tap "Free play"
wait for "Next"
tap "4"
tap "Next"
wait for "Start"
drawn
tap "Start"
wait for "Menu"
drawn
drawn
tap "Menu"
wait for "How to Play"
tap "How to Play"
drawn
shot rules

flow sign-in-sheet
open /?semantics=1&login=1
wait for "New game"
drawn
tap "New game"
wait for "Single player"
drawn
tap "Single player"
wait for "Free play"
drawn
tap "Free play"
wait for "Next"
tap "4"
tap "Next"
wait for "Start"
drawn
tap "Start"
wait for "Menu"
drawn
drawn
tap "Menu"
wait for "Sign in"
tap "Sign in"
wait for "Sign in with a passkey"
shot sign-in

```

If a step can't find its words, the label has changed: fix the journey in
the same commit as the change.
