# What isn't open

Copyright 2026 Sam (github.com/Samwisee). All rights reserved.

Everything in this repository is under the Apache License 2.0 (LICENSE)
except the following, which is not licensed to anyone for copying,
modifying or distributing, in whole or in part, without written permission:

**The rooms' art** (the styles players choose, some of them sold): their
designs, colours, patterns, emblems, card faces and backs, tokens and task
cards. Each of these files starts with a line saying it's not under the
Apache licence:

- `lib/skin/rooms/room_skins.dart`
- `lib/skin/midnight/midnight_skin.dart`
- `lib/skin/sets/` (every file)
- `lib/ui/cards/emblems/` (every file)
- `lib/ui/widgets/felt_patterns_more.dart`
- `lib/ui/widgets/felt_patterns_eggs.dart`
- `lib/ui/widgets/back_motifs_more.dart`
- `lib/ui/widgets/token_styles_more.dart`

**The game's name and look as a product:** the name "The King's Court" and
its logo (`assets/images/logo.png`), which the Apache licence doesn't grant
in any case (its section 6).

**Its sounds:** `assets/sounds/`.

The rest (the rules engine, the courtiers, the online play, the app and its
widgets, the tools and tests, and the court, plain, lacquer, garden and
harbour rooms) is open under Apache 2.0. The open code does import the
files above (the list of rooms, lib/skin/skins.dart, names them), so a fork
that leaves them out takes those rooms out of that list and plays with the
five open ones.

Contributions to this repository are taken under the Apache licence
(its section 5), whichever files they touch.
