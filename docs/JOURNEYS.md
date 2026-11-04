# Journeys: the game on real phones

Pocket Lab (the device lab) plays these on every phone and browser after a
deploy and on its daily check. They're saved on the site in Pocket Lab;
this file is the copy to change with the code. A step a line; each flow
starts again from a fresh page.

The game is drawn on one canvas, so the steps find buttons by their words
only with `?semantics=1`, which builds the accessibility tree from the start
(lib/main.dart). Players never get it that way.

```
flow front-page
open /?semantics=1
wait for "New game" (up to 60 s)
drawn
not "Error"
shot front-page

flow free-play
open /?semantics=1
wait for "New game" (up to 60 s)
tap "New game"
tap "Single player"
tap "Free play"
tap "4"
tap "Next"
tap "Start"
wait for "Menu" (up to 30 s)
drawn
not "Error"
shot table

flow store
open /?semantics=1
wait for "Menu" (up to 60 s)
tap "Menu"
tap "Store"
wait for "Style" (up to 30 s)
drawn
shot store
tap "Faces"
shot store-faces

flow how-to-play
open /?semantics=1
wait for "Menu" (up to 60 s)
tap "Menu"
tap "How to Play"
drawn
shot rules

flow sign-in-sheet
open /?semantics=1&login=1
wait for "Menu" (up to 60 s)
tap "Menu"
tap "Sign in"
wait for "Sign in with a passkey" (up to 15 s)
shot sign-in
```

If a step can't find its words, the label has changed: fix the journey in
the same commit as the change.
