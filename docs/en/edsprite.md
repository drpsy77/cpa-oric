# EDSPRITE — reference

> English translation of `docs/edsprite.md`. Screens, menus, questions and messages are those
> of the English disks (`cpa-en.dsk`...); on the French disks (`cpa.dsk`...), EDSPRITE speaks
> French, and its answers are `O`, `N` instead of `Y`, `N`.

Full-screen editor for GRAPHER's `.SPR` files (format: `grapher.md` § 10.1): sprites (kind
0: drawing and mask) and tiles or characters (kind 1: drawing only, copied into the font by
`TFONT`). It replaces HEX and `tools/mkspr.py` for making these files on the Oric. One `.COM`
(10,265 bytes; 10,444 in French), nothing resident. With a LOCI, the USB mouse works too
(§ 3.1); everything can be done from the keyboard. On the disks that have GRAPHER: `cpa.dsk`,
`cpa-exemples.dsk`, `cpa-anim.dsk` and their English twins.

## 1. Calling it

    EDSPRITE             new file (no name: asked for when saving)
    EDSPRITE HEROS       opens HEROS.SPR (the type is added), or creates it

A new file has one 2 × 2 character sprite `SP01` (kind 0) or one character `CAR1` (kind 1). A
file that is not a `.SPR` (signature `SPR`, version 1, kind 0 or 1, sizes from 1 to 4, right
length) is refused: `Not a .SPR file`. Started in SPLIT mode, EDSPRITE switches to text and
goes back to SPLIT when it ends, picture intact.

## 2. Screen

     0|  File Edit Sprite Draw View         A
     1|     1  :  2  :  3  :  4  : HEROS.SPR
     2|   ....####...:.....:.....:>HER1 2x2 S
     3|   ...######..:.....:.....: HER2 2x2 S
     4|   ...# ## #..:.....:.....: MSTR 2x2 M
     5|  1...######..:.....:.....: BOSS 4x4 S
     6|   ....####...:.....:.....:
     7|   .....##....:.....:.....:
     8|   ..########.:.....:.....:
     9|   _##########+_____+_____+
    10|   .#..####..#:.....:.....:
    11|   .#..####..#:.....:.....:
    12|   ....####...:.....:.....:
    13|  2....#:.#...:.....:.....:
    14|   ...##:.##..:.....:.....:
    15|   ...#.:..#..:.....:.....: 1/4
    16|   ..##.:..##.:.....:.....: sprites
    17|   _____+_____+_____+_____+
    18|   .....:.....:.....:.....: Real
    19|   .....:.....:.....:.....:
    20|   .....:.....:.....:.....:::::::::
    21|  3.....:.....:.....:.....:::::::::
    22|   .....:.....:.....:.....:::::@@::
    23|   .....:.....:.....:.....:::::@@::
    24|   .....:.....:.....:.....:::::::::
    25|   _____+_____+_____+_____+::::::::
    26|  SPC:solid  M:mask  P:pen  ^I:list
    27|  x7 y12 char 2,2 solid  pen         *

- **Grid** (columns 3-26, rows 2-25): one sprite dot per screen cell, 4 × 3 characters
  visible (24 × 24 dots); a sprite 4 characters high scrolls by one character when the
  cursor leaves the grid. Column 2: character row number; row 1: character column numbers.
  The cursor blinks.
- **Three states**, drawn with redefined characters: solid dot (cell fully lit, `#` above),
  mask (an unlit dot that hides the backdrop: empty cell), clear (grey cell, one dot in four,
  dark so that the cursor stands out, `.`). Kind 1: two states, solid and empty.
- **Character limits**: on the 6th dot column of a character, a line on the right of the
  cell; on the 8th row, a line at the bottom; at the corner, both (`:`, `_`, `+` above). The
  line is drawn over the state: lit on an empty or grey cell, unlit on a solid one.
- **`S` or `M` mode** (sprite or mask), per sprite, shown in the list; it applies to the
  grid, the codes and "Real". `S`: the three states, the drawing bytes, the sprite. `M`: the
  mask; solid and mask dots are both solid, clear stays grey; the mask bytes; the mask in
  "Real". This mode is for display only: it is not saved.
- **List** (row 1: the file; rows 2-13: one sprite per row, name, size, `S` or `M`,
  scrolling beyond 12); `>` marks the current sprite. Rows 15-16: rank, count, kind.
- **Real** (rows 20-25, columns 28-33): the sprite at real size over a backdrop (none,
  checks, bricks, grass), with the real redefined characters; it follows every dot set. Kind
  1: the tile repeated over the whole area, to see the pattern it makes.
- **Codes** (`^H` or View menu): instead of the list and "Real", next to each dot row of the
  grid, its bytes in hexadecimal (two digits per character of width): those of the drawing
  in `S` mode, of the mask in `M` mode. `^H` again: the list.
- **Help** (row 26): the keys of the zone (`SPC:solid  M:mask  P:pen  ^I:list` in the
  grid, `S:sprite  M:mask  RETURN:draw` in the list).
- **Status line** (27): cursor position (dot), character, dot state, `pen` when it is down,
  `*` if the file has changed; questions and messages show there too.

## 3. Keys

Two zones: **drawing** (the grid) and **selection** (the sprite list). `^I` switches from
one to the other (or the Sprite menu, Select / Draw).

| Key | Drawing | Selection |
|---|---|---|
| arrows | move the cursor by one dot | ↑ ↓: previous / next sprite |
| SHIFT + arrows | to the edge of the character, then the next character | page of 12 |
| CTRL ← / CTRL → | previous / next sprite | previous / next sprite |
| CTRL ↑ / CTRL ↓ | first / last sprite | first / last sprite |
| SPACE | dot solid / clear | — |
| `M` | mask / clear (kind 0) | mask mode |
| `S` | — | sprite mode |
| DEL | clear dot (kind 1: empty) | — |
| `P` | pen: while moving, the cursor sets the last state chosen; `P` again, or ESC, lifts it | — |
| RETURN | — | go to drawing |
| `^H` | hex codes / list and "Real" | same |
| `^Z` `^X` `^C` `^V` | undo, cut, copy, paste the character under the cursor | the whole sprite |
| `^N` `^O` `^S` `^Q` | new file, open, save, quit | same |

### 3.1 Mouse (LOCI)

A USB mouse plugged into the LOCI is taken at start; without a LOCI (or in an emulator
without a mouse), nothing changes.

- **Pointer**: the screen cell under the mouse, in inverse video (in normal video on the
  inverse row of the list). In the grid, while drawing, the cursor follows it.
- **Left button**: sets the state chosen from the keyboard (SPACE: full, `M`: mask; full at
  start); **right**: transparent (eraser; tiles: empty); **middle**: mask (sprites only). A
  click sets one dot; with the button held, the mouse draws (two positions read in a row are
  joined by a line, with no gap). A click in the grid switches to drawing. `^Z` undoes the
  whole stroke.
- **Left click in the list**: that sprite becomes the current one (selection). **In
  "Real"**: next backdrop.
- **Wheel**: previous sprite (up) or next.
- **Scrolling** (sprite 4 characters high): the pointer on the row of numbers, above the
  grid, moves it up by one character; on the help row, below it, down.
- **Speed**: View menu, Mouse...; from 1 (slow) to 5 (fast), 3 at first (16 mouse steps per
  cell). The LOCI keeps it (file `0:CPA.MOU` in its memory), for later runs and for the
  other programs that will use the mouse.

## 4. Menus (FUNCT)

- **File**: New `^N` (question: sprites or tiles), Open... `^O`, Save `^S`, Save as...,
  Quit `^Q`. A changed file asks for confirmation before being dropped.
- **Edit**: Undo `^Z`, Cut `^X`, Copy `^C`, Paste `^V`, Clear. In the selection they act on
  the whole sprite (cut removes it, unless it is the last one; paste inserts the copy after
  the current one; clear makes it all clear); in drawing, on the character under the cursor.
  Undo brings back the sprite's drawing from before the last change (one level; not the
  adding or removing of sprites).
- **Sprite**: New... (size 1 to 4 × 1 to 4, typed `2X2`, then a name of 1 to 4 letters or
  digits; it goes after the current one), Duplicate (the copy gets the name with its last
  digit increased: `HER1` → `HER2`), Delete (confirmation), Rename..., Size... (the drawing
  keeps its top-left corner), Move down / Move up by one rank in the file, Select, Draw.
- **Draw**: Invert (solid ↔ mask, clear stays; kind 1: solid ↔ empty), Flip horizontal,
  Flip vertical, Quarter turn (a sprite square in dots: 4 × 3 characters only), Shift by one
  dot in the 4 directions (what goes out comes back on the other side), Mask = drawing,
  Outline (each clear dot touching a solid dot, corners included, becomes mask: the sprite
  gets a black outline that sets it off from the backdrop; kind 0). Kind
  1: From the font... copies the drawing of standard-set characters from a code (32 to 127)
  as a starting point. Each transformation can be undone with `^Z`.
- **View**: Hex codes `^H`, Backdrop (none, checks, bricks, grass, in turn), Animate: plays
  in "Real" the sprites of the same size whose names start the same way (without the final
  digits: `HER1`, `HER2`...), one every 12/50 s; a key stops it. Mouse...: speed from 1
  to 5 (§ 3.1); without a mouse, `No mouse (LOCI)`.

## 5. Files and safety

- The whole file is in memory: about 34 KB (29 KB when started in SPLIT mode), i.e. more
  than 120 sprites of 4 × 4; 255 sprites at most. Beyond: `Memory full`.
- Saving as in EDIT: `NAME.$$$` written in full, then the old file erased and the new one
  renamed. Disk full, directory full, read-only file: a message, the old file stays intact.
  The last record is padded with zeros. Tests: `tools/test_fichiers.py` (normal, disk full,
  directory full, R/O, save as, replace, RESET).
- Save as onto an existing file: `Replace this file (Y/N)?`.

## 6. Implementation

- The 12 grid characters (3 states × no line, right, bottom, both) take standard-font codes
  that no text of the program or of the system shows (``@ # [ \ ] _ ` { | } ~`` and DEL):
  drop-down menus are written in the font of their row, the alternate font is not possible
  there. The preview takes codes 64-79 (sprite) and 80 (backdrop) of the alternate set
  (attribute 9 in column 27, 8 in column 34), below any drop-down menu. The original
  drawings of the 12 codes are kept (for "From the font"); on leaving, the warm boot gives
  the font back. The alternate set is all taken by the system (`docs/systeme.md`): codes
  64-79 cover the line being edited (`$BA00`), free while EDSPRITE runs; code 80 covers the
  first 8 bytes of the line history (`$BA80`), saved at start and put back on leaving. After
  a RESET in EDSPRITE, the history may keep damaged lines (harmless: lengths are bounded).
- The grid is redrawn cell by cell (one read of the sprite per character and per dot row,
  then its 6 dots).
- Mouse: library `progs/mou_inc.s` (read through window 0 of the XRAM, report at `$FF00`,
  nothing under interrupt; test `tools/test_mou.py`). EDSPRITE reads it in its waiting loop
  and at each grid row during a redraw (about a tenth of a second): the library adds up
  buttons, wheel and moves, nothing is lost. A move alone only redraws the cursor and the
  status line; a dot set, the whole screen. After a key, the mouse move made meanwhile is
  dropped (`mo_sync`). Position in text cells (columns 2-39, rows 1-27: never on the
  attributes nor on the menu bar). On leaving, the LOCI stops writing the mouse. Test in
  Oricutron: `ORIC_MOUSE` (`docs/atelier.md`).

## 7. Later

- Sprites in full-screen HIRES: the `.SPR` format (6 dots per byte) already fits; what is
  missing is the display in GRAPHER (library), not the editor.
- Characters animated at 50 Hz (`suite.md` point 1).
