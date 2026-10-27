# The King's Court: printed deck and box

Generates print-ready files for a premium deck that is both a full standard
deck and the King's Court deck, and a two-piece box.

```
pip install segno playwright      # Chromium is used to render
python3 tool/print/deck.py OUT    # cards
python3 tool/print/box.py OUT     # box
```

## The deck (60 cards)

| Cards | Count | Notes |
| --- | --- | --- |
| A–10, J, Q, K in ♠ ♥ ♦ ♣ | 52 | A–9 carry a small gold crown under the index: the King's Court's 40-card deck (with the Court Cards). |
| Court Cards: Joker, Jack, Queen, King | 4 | Their own suit, on coloured cloth, with 1–4 diamonds showing their order. |
| Jokers | 2 | For standard games. |
| How to play | 1 | Rules in brief and a QR code to the app. |
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
* **Tray** (inner): holds the cards upright; front wall has a thumb notch so
  you can pinch the cards out. Walls are doubled with a fold-over liner in
  the card-back red, so the inside is finished too. Outside about
  66.2 × 21.3 × 80 mm.
* **Sleeve** (outer): open at the top, glued bottom, thumb notches front and
  back to draw the tray out. Outside about 67 × 22.1 × 90 mm. It covers the
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
