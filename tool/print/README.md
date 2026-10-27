# The King's Court: printed deck and box

Generates print-ready files for a premium deck that is both a full standard
deck and the King's Court deck, and a two-piece box.

```
pip install segno playwright      # Chromium is used to render
python3 tool/print/deck.py OUT    # cards
python3 tool/print/box.py OUT     # box
```

## The deck (56 cards)

Drawn in the game's own look: the app's fonts (Cinzel Decorative, Alegreya
Sans), its Court Card cloths, patterns and gold emblems, its crown, the
felt and the card-back red, with a cartoon outline and gold foil.

| Cards | Count | Notes |
| --- | --- | --- |
| A–10 in four-colour suits | 40 | ♥ red, ♦ blue, ♣ green, ♠ black, as in the app's colour setting; plain, large pips (the Aces too: the Court Cards are the stars). A–9 carry a small gold crown: they're in the King's Court deck. |
| Jack, Queen, King in every suit | 12 | Court Cards on cloth in the suit's colour: red, blue, green and black, each with the app's emblem (sword and shield, tiara, crown) and pattern (stripes, lattice, sunburst). Players choose which Jack, Queen and King make their court; the app's are the green Jack, blue Queen and red King. |
| Jokers | 2 | Purple (the app's) and orange, with the jester's cap, harlequin checks of the card's colour on its liripipes. |
| Back | – | The table's felt inside an ivory border, with a field of little crowns and a medallion that reads either way up: never mistaken for a face. |
| How to play | 1 | On the felt: choosing a court, the rules in brief, a QR code to the app. |
| Your court awaits | 1 | Unlock code, QR code and the NFC table note. **The code shown is a sample**: each deck needs its own (see below). |

**Size:** poker, 63 × 88 mm, rounded corners (3.5 mm). Files are 69 × 94 mm
with 3 mm bleed on every side, at 300 dpi (816 × 1109 px). Keep anything
important 3 mm inside the trim.

**Files:**
* `cards/png/` artwork, one per card, plus `00-back.png`
* `cards/foil/` foil plates: black = gold foil, white = none
* `cards/pdf/` the same as PDFs (vector), fronts and back

Make Playing Cards' template is 822 × 1122 px; their uploader accepts these,
or re-run with the size changed in `deck.py`.

## The box

Two pieces, pulled apart from the top like a slide box:
* **Tray** (inner): in the card-back red, with the crown medallion that
  shows when the box opens; holds the cards upright; front wall has a thumb
  notch so you can pinch the cards out. Walls are doubled with a fold-over
  liner in the table's felt, so the inside is finished too. Outside about
  66.2 × 20.3 × 80 mm.
* **Sleeve** (outer): the app's welcome screen: felt green with the brass
  inlay, the crown, the four Court Cards fanned and the title. Open at the
  top, glued bottom, thumb notches front and back to draw the tray out. Outside about 67 × 21.1 × 90 mm. It covers the
  cards completely when closed.

Board assumed: about 400 gsm (0.55 mm). These dielines are a starting point:
your printer will send theirs for the board they use, and the art drops
onto it.

**Files (`box/`):** `*-art` (art with 3 mm bleed), `*-foil` (foil plate),
`*-lines` (dieline only: red = cut, blue dashed = fold), `*-proof.png` (art
with the dieline over it).

## Making it feel premium

* **Card stock:** 310–330 gsm black-core, embossed (linen or "air cushion")
  finish, for a snap and slide like the best decks. Ask for crushed stock.
* **Gold foil:** hot foil on the backs, the frames, the Court Cards and the
  box, from the foil plates. Lines are at least 0.18 mm, the finest most
  foil printers will hold.
* **Gilded edges:** gold-foiled card edges are the single most "luxury"
  touch. Most premium playing-card printers offer it.
* **Box:** soft-touch lamination, foil, and a blind or foil emboss on the
  crown.

Print-on-demand (Make Playing Cards, The Game Crafter) can't do foil or
gilding: the gold prints as the gradient in the artwork, which still looks
good for prototypes. For the full finish, quote with a specialist playing-card
printer such as Legends Playing Card Co, Expert Playing Card Co or
Cartamundi; minimums are typically in the hundreds to low thousands of decks.

## Unlock codes and NFC

* **Unlock code:** every deck needs a unique code (and QR) on the "Your court
  awaits" card, or on a separate insert. That's variable-data printing: ask
  the printer, or print the codes as stickers/scratch cards. Generate codes
  server-side and record them so each redeems once.
* **NFC:** an NTAG215 sticker inside the tray (under the cards) holds a URL
  such as `…/kings-court/?table=new`; tapping the box with a phone opens a
  new table others can join. Per-deck tags can carry the deck's code too.
