# GRAPHER — reference

> English translation of `docs/grapher.md`. GRAPHER's commands are already English words;
> its error messages are in French for now and are quoted as they appear, with their meaning
> in brackets.

GRAPHER runs a `.GRX` text file (written with EDIT): one command per line, in English. It is
a low-level language, close to the screen. It handles integers, variables of one or two
letters, arrays, the HIRES or SPLIT picture and the text screen. It is used to make screens
(title, scenery) and small games. The same file can be **interpreted**, or **translated** into
assembly by GRXASM and then assembled into a standalone `.COM`, 5 to 20 times faster (§ 12).

This document is the only reference for GRAPHER. The README only gives an overview. HELP and
README.TXT (on the disk) give a summary (`tools/gen_readme_txt.py`).

    ; un eventail en plein ecran
    HIRES
    FOR X 0 239 6
      LINE X 0 239-X 199
    NEXT
    WAIT

## 1. Starting

| Command | Effect |
|---|---|
| `GRAPHER NAME [p1 ... p9]` | loads `NAME.GRX` (drive optional) into memory and runs it; `p1`-`p9` replace `$1`-`$9` |
| `GRXASM NAME [p1 ... p9]` | does not run it: writes `NAME.ASM`, to be assembled with `ASM NAME` (§ 12) |
| `GRAPHER NAME /A [p1 ... p9]` | the same thing: GRAPHER hands over to GRXASM (`/A` right after the name) |
| `GRXASM NAME /C [p1 ... p9]`, `GRAPHER NAME /C [...]` | translates, then chains `ASM NAME /E`: only `NAME.COM` is left (`NAME.ASM` is erased if assembly succeeds; an error leaves it, to read it) |

## 2. Writing a program

- One command per line, 126 characters at most (`ligne de plus de 126 car.`). Indentation is
  free. The text stops at the first `^Z`. A tab (TAB, code 9) counts as a space (the Oric has
  none; `IMPORT name /T` already replaces them on arrival).
- `;` starts a comment, at the start or the end of a line.
- `$1` to `$9` are replaced by the parameters of the command line, with their original case
  (`X = $1`, `GTEXT 2 90 $2`).
- **Space rule**: a space separates parameters; an expression among several parameters
  therefore contains no space, except inside brackets (`LINE X 0 (239 - X) 199`). An
  expression alone at the end of the line (`X = ...`, `IF`, `WHILE`, `PRINT`) may contain
  some.

## 3. Numbers, variables, expressions

- Signed 16-bit integers (-32768 to 32767); variables start at 0.
- Variable name: one letter (`A` to `Z`), optionally followed by a letter or a digit (`PX`,
  `PY`, `N1`), that is 961 variables. Upper and lower case are the same. `IF` is reserved.
  Two-character names are for simple variables only: an array or a string keeps one letter
  (`AX(3)` and `AX$` are refused).
- Good practice: named variables for what is unique (the player `PX PY`, the score `SC`), an
  array for what is walked through in a loop (monsters `X(3) Y(3)`), and constants written
  out. In a translated program, a simple variable is read in one instruction; an element of
  an array declared at the top of the program, of constant size, is read almost as fast
  (§ 12).
- Assignment: `V = expr` or `LET V = expr`.
- Operators, from strongest to weakest: `-` (sign); `*` `/` `%` (`/` truncates towards 0, `%`
  is the remainder); `+` `-`; comparisons `=` `<>` `<` `<=` `>` `>=` (1 if true, 0
  otherwise); `&` `|` (bitwise and, or).
- Brackets: `(X * 2)`.

| Function | Value |
|---|---|
| `RND(n)` | random number from 0 to n-1 (successive draws are independent: no bands or patterns when they are used as coordinates) |
| `ABS(n)` | absolute value |
| `POINT(x,y)` | 1 if the point of the picture is lit (HIRES or SPLIT) |
| `SCRN(col,lin)` | byte of a cell of the text screen (LORES) |
| `INKEY` | key, 0 if none; does not wait; no repeat delay (§ 8) |
| `FOUND` | 1 if the last `LOAD` or `BLOAD` found its file, 0 otherwise (§ 10) |
| `LEN(A$)` | length of a string (§ 9) |

A letter followed by `(` is an array; functions have names of three letters or more.

## 4. Control

| Block | Effect |
|---|---|
| `REPEAT n` ... `NEXT` | n times (nothing if n ≤ 0) |
| `FOR V a b [step]` ... `NEXT` | V from a to b, step 1 by default, negative to go down; nothing if a is already past b; zero step: `pas nul` |
| `WHILE expr` ... `NEXT` | as long as the expression is not zero (`WHILE 1`: endless; ESC stops it when interpreted, § 8) |
| `IF expr` ... [`ELSE` ...] `ENDIF` | if the expression is not zero |
| `SUB NAME` ... `ENDSUB` | subroutine, called with `CALL NAME`; `RETURN` leaves it before the end; met on the way, it is skipped (it can be placed anywhere) |
| `END` | end of the program |

Blocks nest up to 16 levels (loops and calls).

## 5. Screen modes

| Command | Effect |
|---|---|
| `HIRES` | full-screen HIRES, 240 × 200 points, picture cleared; no console |
| `SPLIT` | 240 × 128 points, console below, picture cleared |
| `LORES` | the whole text screen for the program (§ 7); it is cleared (`CLS`) |
| `TEXT` | back to the console |

- **End of the program** (end of the file or `END`): HIRES and LORES give the console back at
  once, without waiting. To leave the screen displayed, the program ends with `WAIT` or
  `GET`. A SPLIT picture stays above the prompt.
- Started in SPLIT mode, GRAPHER draws on the picture already there (after a LOGO program, for
  instance).
- In full-screen HIRES, `ECHO`, `PRINT` and `CLS` display nothing (no console).

## 6. Drawing (HIRES and SPLIT)

| Command | Effect |
|---|---|
| `GCLS` | clears the picture |
| `PEN m` | pen: 0 erases, 1 draws, 2 inverts (other value: `parametres ?`) |
| `PLOT x y` | point (x 0-239; y 0-199, or 0-127 in SPLIT) |
| `LINE x1 y1 x2 y2` | line |
| `BOX x1 y1 x2 y2`, `FBOX x1 y1 x2 y2` | rectangle, filled rectangle |
| `CIRCLE x y r` | circle (r ≤ 127) |
| `GTEXT col y text` | text in the picture: cell `col` (0-39, 6 points), point line `y` |
| `GNUM col y n` | number in the picture (a score) |
| `ATTR col y1 y2 v` | attribute in cell `col`, lines `y1` to `y2`: ink 0-7, paper 16-23 |

Drawing parameters go from 0 to 255 (`valeur hors de 0-255`). Outside HIRES and SPLIT:
`HIRES ou SPLIT d'abord` (HIRES or SPLIT first). Pictures and animations: § 10.

## 7. Text screen (LORES)

`LORES` gives the program 40 columns (0-39) on 28 lines (0-27), line 0 and columns 0-1
included. There is no console, no menus, no console cursor: FUNCT and CTRL-T reach the program
as ordinary keys. The program sets the colour attributes itself, wherever it wants.

| Command | Effect |
|---|---|
| `CLS` | attribute 16 (black paper) in all 1,120 cells; writing cursor at (0, 0). Outside LORES: clears the console |
| `LOCATE col lin` | places the writing cursor |
| `CHAR col lin code` | writes the byte `code` (0-255) into the cell: character 32-127, +128 in reverse video, or attribute (ink 0-7, paper 16-23...); the cursor does not move |
| `SCRN(col,lin)` | function: the byte of the cell |
| `ECHO text` | writes the text at the cursor, which moves on. Without quotes, leading spaces are skipped; within quotes, the text is taken as is (`ECHO "  Score : "`) |
| `ECHO` (alone) | column 0 of the next line; after line 27: line 0; nothing is cleared |
| `PRINT expr`, `PRINT A$` | writes the number or the string at the cursor, without a new line |
| `SPC n [x]` | writes byte x n times (32 by default): to clear, to restore attribute 16, to draw a line |
| `TAB n` | moves the cursor n columns on without writing (relative: `LOCATE` gives the absolute column) |
| `PRINTV`, `ECHOV`, `SPCV` | like `PRINT`, `ECHO` and `SPC`, but the cursor **goes down**: one character per line, in the same column (a column of digits, a vertical word, a wall: `SPCV 20 35`). `ECHOV` alone: line 0 of the next column |

- **Right edge**: nothing is written past column 39. What goes beyond is lost, without an
  error; the cursor stays at the end until the next `LOCATE` or lone `ECHO`. Nothing wraps to
  the next line and nothing scrolls the screen. Vertically (`PRINTV`...), nothing is written
  below line 27, in the same way.
- Column or line off the screen: `valeur hors limites` (value out of range); `n` of `SPC` and
  `TAB`, `x` and `code`: 0-255 (`valeur hors de 0-255`).
- Outside LORES, `LOCATE`, `CHAR`, `SCRN`, `SPC`, `TAB`, `PRINTV`, `ECHOV` and `SPCV` give
  `LORES d'abord` (LORES first). In LORES, the drawing commands give `HIRES ou SPLIT d'abord`.
- `HIRES` or `SPLIT` from LORES: the text screen is lost. `GLOAD` of an `.IMG` picture from
  LORES gives the console back first.

### 7.1 Sprites

A sprite is a small character of 1 to 4 columns by 1 to 4 lines of cells, drawn in a `.SPR`
file (format: § 10.1), loaded with `BLOAD` into a `$` array. It moves from cell to cell over
the text-screen scenery without damaging it: each cell it covers receives a redrawn character,
a combination of the cell's scenery and the sprite.

    displayed cell = (scenery AND NOT silhouette) OR drawing

The scenery stays visible around the sprite's silhouette, within its own cells. The colour is
that of the line (attributes): the sprite takes the colour of the lines it crosses.

    DIM S$(112) T(16)
    BLOAD S$ HEROS.SPR
    FOR I 0 15
      T(I) = 112+I          ; codes 112-127 reserves aux sprites
    NEXT
    LORES
    ...                     ; le decor
    SPRITES 2
    SPOOL T
    SSHOW 0 S$ 0 X Y        ; le sprite 0 du fichier, emplacement 0

| Command | Effect |
|---|---|
| `SPRITES n` | reserves n slots (0 to n-1, n from 1 to 255), once, before `SPOOL`; a slot is an object on display |
| `SPOOL T [ALT]` | the integer array T (declared, or read with `LOAD`) gives the codes sprites may take: 32 to 127 (`ALT`: secondary set, 32 to 111), 96 at most, in any order; they all become free. It is the character set's **pool** |
| `SSHOW k S$ n col lin [ALT]` | shows sprite n (rank in the file, from 0) of array `S$` in slot k, top-left corner at (col, lin), with the pool of the given set. On a slot already in use, the old sprite is removed first: this is also how you move it and show the next frame of an animation |
| `SHIDE k` | removes the sprite of slot k: the scenery comes back, the codes go back to the pool (nothing if the slot is free) |

`SSHOW` and `SHIDE` need LORES (`LORES d'abord`).

**Rules for the programmer** (the translated program checks nothing, § 12):

- A pool code never appears in the scenery; keep at least the digits, the capital letters and
  the space (59 codes remain: 33-47, 58-64, 91-127). A sprite on display takes one code per
  covered cell; there must be enough codes for all the sprites shown at the same time
  (`plus de caracteres pour les sprites`: no more characters for sprites).
- **Attributes take priority**: a cell holding an attribute (code 0-31) is never covered, the
  sprite is invisible there. Now `CLS` puts attribute 16 everywhere: the area where sprites
  move must be filled with spaces (or scenery), for example `SPC 40` on each line. Colour
  attributes go where sprites do not pass (columns 0-1, edge of the playing area).
- The sprite must fit on the screen (`valeur hors limites`).
- Two overlapping sprites share the common character (the second is drawn over the first).
  Removing one restores the scenery on the common part: show the other again. No code is
  lost, whatever the order of removals.
- Do not change the scenery under a sprite on display (remove it first), nor the pool array
  while sprites are displayed. A new `SPOOL` makes all the pool's codes free: sprites still
  displayed with it must be shown again.
- The pool matches the character set of the lines the sprite crosses (attribute 8: standard,
  9: secondary). A character straddling two sets is split into two sprites. The secondary set
  has no drawings of its own (the system keeps the line being edited and the history there):
  tiles draw it (`TFONT ... ALT`, § 7.3). An `INPUT` damages its codes 64 to 111; at the end of a
  program that used it, the line history is emptied.

### 7.2 Rectangles: copy, scrolling, rotation

These commands work on the text screen (LORES) as well as on the picture (HIRES, SPLIT). In
LORES, a cell is a character (or an attribute); in the picture, a cell is a byte of 6 points
in width (columns 0-39) and one point line in height (lines 0-199, or 0-127 in SPLIT). Bytes
are copied as they are, attributes included. In the console: `LORES d'abord`.

| Command | Effect |
|---|---|
| `PASTE T$(l,c) col lin wid hgt` | pastes on the screen, top-left corner at (col, lin), the rectangle of `wid` × `hgt` cells of the two-dimensional `$` array starting at `T$(l,c)` (line l, column c of the array) |
| `GRAB T$(l,c) col lin wid hgt` | the reverse: copies the rectangle of the screen into the array |
| `SCROLH n [c1 l1 c2 l2 [x]]` | slides the rectangle by n cells: n > 0 to the right, n < 0 to the left. The freed cells receive byte x: a space by default in LORES, the empty byte (64) in the picture |
| `SCROLV n [c1 l1 c2 l2 [x]]` | the same in height: n > 0 downwards, n < 0 upwards |
| `ROTH n [c1 l1 c2 l2]`, `ROTV n [c1 l1 c2 l2]` | rotation: what goes out on one side comes back on the other (n modulo the size) |

- Without a rectangle, it is the whole screen. The rectangle is given by its corners, as for
  `BOX`: columns c1 to c2, lines l1 to l2. Off the screen, or c2 < c1, or l2 < l1: `valeur
  hors limites`. n = 0, or a rotation of a whole turn: nothing. A scroll of at least the size
  of the rectangle fills it with x.
- `PASTE` and `GRAB`: the rectangle must fit on the screen (`valeur hors limites`) and in the
  array (`indice hors limites`, index out of range); `wid` and `hgt` are at least 1. There is
  no automatic clipping at the edges: the program keeps its own camera in bounds.
- **Sprites**: do not slide or cover scenery under a sprite on display. Remove the sprites
  (`SHIDE`), then `PASTE` or `SCROL...`, then show them again (§ 7.1).
- `CLS` puts attribute 16 everywhere: scenery pasted with `PASTE` replaces it in its area,
  and columns 0-1 keep their attributes if the rectangle starts at column 2.

**A map larger than the screen.** The map is in a `$` array (one byte per cell, attributes
allowed); after each step, `PASTE` redraws the window from the camera's corner. This is the
normal method: the camera position is enough to describe the screen (diagonal moves, jumps,
back to the start: the same line).

    DIM T$(64,128)
    BLOAD T$ CARTE
    LORES
    ...
    WHILE 1
      K = INKEY
      IF K>7 & K<12
        ...                     ; pas du joueur, CX, CY : coin de la camera, bornes
        PASTE T$(CY,CX) 2 1 38 26
      ENDIF
    NEXT

The redraw happens only after a step (§ 8, "Game loop"). For a much larger map in the same
memory, tiles (§ 7.3).

**Scroll, then fill in.** When the scenery is not entirely in memory (computed as you go,
drawn at random, endless), slide the playing area by one cell and write the strip that comes
in: a line with `LOCATE` and `SPC` or `PRINT A$`, a column with `PRINTV A$` or `SPCV`, or a
`PASTE` of one line or one column. Example: `DEFILE.GRX` (§ 14).

### 7.3 Tiles: a large map in little memory

A **tile** is a small drawing of 1 to 4 columns by 1 to 4 lines of characters. The map is a
two-dimensional `$` array in which each byte names a tile: a map of 64 × 32 tiles of 2 × 2
(2 KB) gives a world of 128 × 64 characters (8 KB with `PASTE`). `TMAP` draws a window of
it; the camera moves by one character, not one tile.

    DIM T$(32,64) D$(5,4) S$(152)
    BLOAD S$ TUILES.SPR       ; dessins des caracteres (genre 1)
    FOR J 0 3                 ; codes de chaque tuile, ligne par ligne
      D$(0,J) = 34            ; eau
      D$(1,J) = 33            ; herbe
      ...
    NEXT
    TILESET D$ 2 2 "~ #^M"    ; tuiles de 2 x 2 ; caracteres de la carte
    LOAD T$ NIVEAU1           ; la carte, ecrite en clair dans EDIT
    LORES
    TFONT S$ 33 ALT           ; dessins copies dans le jeu secondaire
    ...
    TMAP T$ X-19 Y-13 2 1 38 26
    IF TILE(NX,NY) = 1        ; de l'herbe sous le pas ?

| Element | Effect |
|---|---|
| `TILESET D$ wid hgt [K$]` | declares the tiles: each line of `D$` (two-dimensional `$` array) gives the `wid` × `hgt` codes of one tile, line by line (1 to 4 of each, 256 tiles at most); `K$` (text in quotes or a string) lists the map bytes in the order of the tiles: `"~ #^M"` makes `~` tile 0, the space tile 1... Without `K$`, the map byte is the tile number |
| `TMAP T$ X Y col lin wid hgt` | draws on the screen, corner at (col, lin), the window of `wid` × `hgt` cells of the map `T$` (two-dimensional `$` array) whose corner is character (X, Y) of the world; X and Y may leave the map, even be negative |
| `TFONT S$ code [ALT]` | copies into the font (standard set, or secondary with `ALT`) the drawings of a kind-1 `.SPR` file loaded in `S$` (§ 10.1): all the cells of all its tiles, in file order, onto consecutive codes from `code` (32 to 127; `ALT`: 32 to 111) |
| `TILE(X,Y)` | function: number of the tile under character (X, Y) of the world, on the map of the last `TMAP`; 0 outside the map, or before any `TMAP` |

- **Tile 0 fills everything**: a map byte missing from `K$` (or, without `K$`, larger than
  the last number), and everything outside the map, is shown as tile 0. This is handy for a
  map written in EDIT (`LOAD` puts 0s at the end of short lines) and for an island
  surrounded by water: the camera need not be kept in bounds. A byte present twice in `K$`:
  the first one wins.
- **Coordinates**: character (X, Y) of the world is in tile (X / wid, Y / hgt). Neither
  `TMAP` nor `TILE` divides: a few subtractions, once per command.
- **Codes**: tiles share their characters (water or a wall: a single repeated character).
  `TFONT` only copies the drawings; `D$` assembles the codes. In a kind-1 `.SPR`, a 1 × 1
  "tile" is simply a character: the file may contain only characters, which `D$` assembles
  into larger tiles.
- **Secondary set**: the map lines start with attribute 9 (`CHAR 0 L 9`); the whole set
  (codes 32 to 111) then belongs to the tiles, and the text of the other lines keeps the
  standard set. The secondary set has no drawings of its own: even the empty cell (the grass)
  must be given one. Same reservations as for sprites (§ 7.1): `INPUT` damages codes 64 to
  111, and the line history is emptied at the end.
- **Memory**: `TILESET` reserves below the arrays (wid × hgt + 1) × 256 bytes (2 × 2:
  1,280; 4 × 4: 4,352), aligned on a page, once; a later `TILESET` reuses them, or reserves
  again if it needs more. It prepares one table per place in the tile (map byte → displayed
  code): about 50 ms for 2 × 2 tiles.
- **Speed** of `TMAP` (38 × 26 window, translated or interpreted program: it is the same
  routine): 1 × 1 tiles, about 35 ms; 2 × 2, 55 ms; 4 × 4, 43 ms (`PASTE`: 22 ms). Redraw
  only after a step (§ 8, "Game loop").
- **Sprites**: a sprite crosses tiles as it crosses any scenery (§ 7.1): the tile stays
  visible around its silhouette. On map lines in the secondary set, its pool is declared
  with `ALT` (`SPOOL T ALT`, `SSHOW ... ALT`), on codes the tiles do not use. As for `PASTE`
  (§ 7.2), remove the sprites before `TMAP`, then show them again.
- `TMAP` and `TFONT` need LORES (`LORES d'abord`). Errors (interpreted): `TILESET d'abord`
  (TILESET first); `valeur hors limites` (tile larger than 4, window off the screen,
  `TFONT` codes outside the set); `indice hors limites` (line of `D$` too short, `K$` longer
  than the list of tiles, one-dimensional map); `fichier .SPR ?` (`TFONT` on a file that is
  not of kind 1). Translated: nothing is checked; `TMAP` without `TILESET` does nothing.

Complete example: `CARTE.GRX` (§ 14).

## 8. Keys and time

| Element | Effect |
|---|---|
| `INKEY` | function, like BASIC's `KEY$`: empties the keyboard buffer and returns the key typed since the last `INKEY`, otherwise the one still held down, otherwise 0. No repeat delay: for action games |
| `GET V` | waits for a key and stores its code in V; follows the keyboard's repeat delay and rate (Clavier menu) |
| `WAIT` | waits for a key, without keeping it |
| `DELAY n` | waits n fiftieths of a second, without looking at the keyboard |

Arrow codes: 8 left, 9 right, 10 down, 11 up; with SHIFT 240 to 243, with CTRL 244 to 247
(same order). CTRL + letter: 1 to 26, except CTRL-H to CTRL-K: 28 to 31. A key typed while the
program runs is kept for `WAIT`, `GET` or `INKEY`.

**ESC is the interpreter's key, not the program's.**

- **When interpreted**, ESC stops the program at any moment: between two lines, in a loop,
  during `GET`, `WAIT`, `INPUT` and `ANIM` (message `Interrompu`, interrupted). The program
  never sees it: it is the emergency exit while debugging.
- **In a translated program** (§ 12), ESC no longer stops anything: the program is in charge
  of everything. `INKEY`, `GET` and `WAIT` return it like any other key (27), `INPUT` ignores
  it, `ANIM` stops as on any other key. A loop with no planned way out only stops with the
  RESET button, which gives the system back.
- **So a game is left with another key**, chosen by the program (Q in the examples,
  `IF K = 81 | K = 113` for upper- or lower-case Q), which works the same way in both modes. A
  translated program can also give ESC a role (menu, inventory) with `IF K = 27`, which never
  fires when interpreted.

**Game loop: only redraw what changes.** With `INKEY`, the loop runs without waiting: if it
redraws the screen on every turn (`PASTE`, `CLS`, a score), the picture flickers, because it
is constantly erased and rewritten while the beam displays it. `GET` hid the problem by
stopping the loop until the next key, but it suffers the keyboard's repeat delay and rate.
The right shape: read the key, and only compute and redraw if it changed something; the
drawing goes into a subroutine, called once before the loop.

    CALL DESSIN                 ; premier affichage
    WHILE 1
      K = INKEY
      IF K>7 & K<12             ; une fleche : deplacement, puis dessin
        ...                     ; nouvelle position, verifiee
        CALL DESSIN
      ENDIF
      IF K = 81 | K = 113       ; Q ou q : fin
        END
      ENDIF
    NEXT

A key held down is returned on every turn by `INKEY`: the movement follows the speed of the
loop, much higher in a translated program. A `DELAY n` after the drawing sets the game's
speed.

## 9. Arrays and strings

**Names.** Each letter serves three independent purposes: `A` (integer), `A(...)` (array of
16-bit integers), `A$` (array of bytes 0-255: a string or a grid of characters).

**DIM.** `DIM S(10) N$(10,12) M$(25,38)`

- One or two dimensions. Several arrays per line. Sizes are expressions, at least 1.
- Indices from 0 to n-1, as in C: `DIM A(10)` gives `A(0)` to `A(9)`. Elements at 0.
- An array is declared only once (`deja dimensionne`, already dimensioned) and before use
  (`tableau non dimensionne`, array not dimensioned). No room: `memoire pleine` (memory full),
  at the `DIM` itself. Memory is never freed or grown.

**Elements.**

- `A(i)`, `A(i,j)`: in a calculation, or on the left of `=` (`A(I,J) = A(I,J) + 1`).
- `A(k)` on a two-dimensional array: element k of the flattened array, line after line, as
  in C (`G(7)` is `G(1,3)` with `DIM G(3,4)`).
- `A$(i)` (one dimension) and `M$(l,c)`: the code of a cell, for reading and writing
  (`M$(L,C) = 35`).

**Strings.** `A$` (one-dimensional `$` array) and `M$(l)` (line l of a two-dimensional `$`
array) are strings. A string stops at the first 0, or at the end of its capacity if it is
full: `DIM N$(12)` holds 12 characters at most. A string is at most 255 characters; a larger
`$` array is read cell by cell. An array of strings is a two-dimensional `$` array
(`N$(10,12)`: 10 names).

| Element | Effect |
|---|---|
| `A$ = "text"`, `A$ = B$`, `M$(I) = A$` | assignment; the rest of the capacity is set to 0; too long: `chaine trop longue` |
| `=` `<>` `<` `<=` `>` `>=` | comparison of two strings, or of a string and a text (`IF R$ = "O"`), in code order (`"AB" < "ABC"`); 1 or 0 |
| `LEN(A$)`, `LEN(M$(I))` | length |
| `PRINT A$` | in LORES: at the cursor, codes 0-31 written as they are (a level line keeps its colours). In the console: codes 0-31 replaced by a space, then a new line. `PRINT A$ = B$` prints the comparison |
| `INPUT A$`, `INPUT M$(I)` | input. In LORES: at the cursor (cell in reverse video), characters 32-126, DEL erases, RETURN confirms, stops at the capacity or the right edge. Elsewhere: console line input, cut at the capacity |
| `INPUT V` | integer from -32768 to 32767: digits and `-`, 6 characters at most; empty or out of range: a beep, and try again |
| `FILL A v`, `FILL M$ 32` | the whole array set to v |

- A string does not mix with calculations (`chaine dans un calcul`, string in a calculation).
  There is no concatenation or conversion: chain `ECHO` and `PRINT`.
- `ECHO` only writes the program's text (`ECHO A$` writes "A$").
- Attribute 0 cannot be displayed with `PRINT` (it is the end of a string): write it with
  `CHAR` or `M$(L,C) = 0`.
- No `INPUT` of an element: `INPUT V` then `A(I) = V`.
- When interpreted, every access checks the array and its indices (`indice hors limites`). A
  translated program checks nothing (§ 12).

## 10. Files: pictures, animations, data

| Command | Effect |
|---|---|
| `GLOAD name` | loads a picture: `.HIR` (or compressed `.HIZ`) in HIRES, `.IMG` in SPLIT; from text mode, the type chooses the mode (`.HIR` by default) |
| `GSAVE name` | saves the picture in the mode's format (`.HIR` or `.IMG`) |
| `ANIM name [n]` | plays the animation `name.ANI` n times (0 or nothing: until a key); full-screen HIRES only (refused in SPLIT); ESC stops the program when interpreted; in a translated program, ESC ends the animation like any other key |
| `SAVE A name`, `LOAD A name` | array as **text** (`.TXT` by default), editable with EDIT |
| `BSAVE A name`, `BLOAD A name` | array as **binary** (`.DAT` by default), bytes as they are, editable with HEX; integers: low byte then high byte |
| `BSAVE SCREEN name`, `BLOAD SCREEN name` | the whole text screen, 1,120 bytes (`.SCR` by default); LORES only (`LORES d'abord`); the cursor does not move |
| `FOUND` | function: 1 if the last `LOAD` or `BLOAD` found its file, 0 otherwise (0 at start) |

The name is written without quotes, with an optional drive; `$1`-`$9` are allowed. `.HIZ` and
`.ANI` formats, tools to make them: `manuel.md`, "Full-screen HIRES".

**Data files.** `A` is the name of the array (`SAVE N$ HOF`, `BLOAD M NIVEAU1`). `SAVE` and
`BSAVE` replace an existing file without asking, with no risk of losing it: they write
`NAME.$$$`, then erase the old file and rename (like EDIT). The new file therefore needs room in
addition to the old one. `disque plein` (or `code 0-31 : BSAVE` while writing): the old file
has not changed, `NAME.$$$` is erased. `repertoire plein` (directory full), `fichier protege`
(read-only): nothing is written. A RESET while writing leaves the old file or the new one; at
worst the new one is complete in `NAME.$$$` (`REN NAME.EXT=NAME.$$$`).

- **Missing file** at `LOAD` or `BLOAD`: no error, the array (or the screen) does not change,
  and `FOUND` is 0. Other errors stop the program.

      LOAD S SCORES
      IF FOUND = 0
        FILL S 0
      ENDIF

- **Text**, in CP/M format like EDIT. `SAVE` ends each line with CR LF and pads the last
  record with `^Z`; `LOAD` accepts CR LF, LF or CR, and stops at the first `^Z`.
- A line of the file always matches a line of the array (no comments). `$` array: the line as
  it is, spaces included, up to the first 0. Integer array: the numbers separated by spaces (a
  tab counts as a space), `-` sign allowed. A one-dimensional array fits on a single line (all
  its numbers, or its whole string).
- `LOAD` first sets the array to 0: a shorter line leaves the end of its line at 0; missing
  lines leave the rest of the array at 0. Extra empty lines are ignored.
- `LOAD` errors, with the line of the file: `ligne trop longue : L n` (line too long: too many
  characters or numbers), `trop de lignes : L n` (too many lines), `nombre ? : L n` (not an
  integer from -32768 to 32767). What was read before stays in the array.
- `SAVE` of a `$` array that contains a code 1-31: `code 0-31 : BSAVE` (these codes cannot be
  typed in EDIT: attributes go through `BSAVE`).
- **Binary**: CP/M files have no byte-exact size (128-byte records). `BSAVE` pads the last
  record with 0s. `BLOAD` sets the array to 0, then reads its size: a shorter file leaves the
  end at 0, anything beyond is ignored. `BLOAD SCREEN` does not clear the screen first.
- What the file contains for each command, and the pitfalls (CR LF, attributes, widths):
  § 10.2.
- Nothing else is saved (neither the variables `A`-`Z`, nor the font): a program that wants to
  keep variables stores them in an array.

### 10.1 Sprite files (`.SPR`)

A `.SPR` file is loaded as it is into a large enough `$` array (`BLOAD S$ HEROS.SPR`: the type
must be written, `BLOAD` uses `.DAT` by default). Everything is aligned on 8 bytes, the width
of a HEX line: each block starts at the beginning of a line, each cell of a sprite takes two
lines (drawing, silhouette). Sprites follow each other without gaps, of different sizes; their
name helps to find them in HEX and will be used by the editor.

**File header (8 bytes)**: `SPR` (signature), version 1, number of sprites (1 to 255), kind
(0: sprites, 16-byte cells; 1: tiles, 8-byte cells, drawing only, copied into the font by
`TFONT`, § 7.3), then two bytes at 0 (reserved).

**Each sprite**: an 8-byte header (width in columns 1-4, height in lines 1-4, two reserved
bytes at 0, 4-character ASCII name padded with spaces: `HER1`), then its cells, line by line
then column by column (2 × 2: top-left, top-right, bottom-left, bottom-right), 16 bytes each:
the **drawing** (8 bytes, from the top line to the bottom one), then the **silhouette** (8
bytes, 1 = the point belongs to the character).

| Drawing | Silhouette | On screen |
|---|---|---|
| 0 | 0 | the scenery (transparent) |
| 1 | 0 or 1 | point lit |
| 0 | 1 | point off: the scenery is hidden there (eyes, black outline) |

Each byte: 6 points in bits 5 to 0 (bit 5 on the left, like the Oric font), bits 7 and 6 at 0.
Size: 8 bytes, then per sprite 8 + 16 × width × height (1 × 1: 24 bytes; 4 × 4: 264). An
animation is a series of sprites (`HER1`, `HER2`...) shown in turn in the same slot.

Example: a little man of 1 column by 2 lines, alone in his file (48 bytes, in HEX):

    0000  53 50 52 01 01 00 00 00   SPR.....   version 1, 1 sprite, kind 0
    0008  01 02 00 00 48 45 52 4F   ....HERO   1 column, 2 lines, HERO
    0010  1E 12 1E 0C 3F 2D 0C 12   ........   cell (0,0): drawing
    0018  1E 1E 1E 0C 3F 2D 0C 12   ........   cell (0,0): silhouette (opaque eyes)
    0020  12 12 33 00 00 00 00 00   ..3.....   cell (0,1): drawing
    0028  12 12 33 00 00 00 00 00   ..3.....   cell (0,1): silhouette

The silhouette follows the convention "1 = the character" (the opposite of Oricium's mask,
`tile AND mask OR sprite`). Until the sprite editor exists, a `.SPR` is made in HEX or by a
small program that fills a `$` array and does `BSAVE`.

### 10.2 From array or screen to file: what you get

A `$` array declared `DIM T$(l,c)` has `l` lines (0 to l-1) of `c` bytes (columns 0 to c-1);
the bytes are stored line after line. What each command does with it:

| | `SAVE T$ name` (text) | `BSAVE T$ name` (binary) | `BSAVE SCREEN name` |
|---|---|---|---|
| Contents | one file line per array line: its bytes up to the first 0, at most `c` | the `l` × `c` bytes, one after another, no separator | the 28 lines of 40 cells of the screen, columns 0-1 (attributes) included: 1,120 bytes |
| Line ending | CR LF, **added by `SAVE`** | none | none |
| Bytes allowed | 32-255; a code 1-31 stops the program (`code 0-31 : BSAVE`) | all | all |
| End of file | last record padded with `^Z` | padded with 0s | padded with 0s |
| For | EDIT, `LOAD` | HEX, `BLOAD` | HEX, `BLOAD SCREEN` |

In practice:

- **Do not write CR and LF yourself** into an array meant for `SAVE`: they are codes 0-31,
  refused; `SAVE` adds them to each line.
- **`BSAVE` does not write a text.** Opened in EDIT, a `.DAT` is a single paragraph (no CR
  LF), ending with null bytes; if you store CR and LF yourself, EDIT understands them, but the
  end is still made of 0s instead of `^Z`. EDIT reads CR LF or a lone LF as the end of a
  paragraph, and a CR not followed by LF as one more end (so LF then CR gives an empty line
  between two lines).
- **Spaces are written, 0s are not**: a line stops at the first 0, but trailing spaces stay in
  the file.
- **Widths**: the screen has 40 columns, the first two of which are attributes; EDIT shows 38.
  A 38-column array taken from columns 2-39 of the screen gives lines that exactly fill an
  EDIT line. A line longer than the array's columns stops `LOAD` (`ligne trop longue : L n`).
- **LORES screen**: after `LORES` or `CLS`, each cell contains attribute 16 (black paper), not
  a space. `GRAB` of an area never written to, then `SAVE`, gives `code 0-31 : BSAVE`: fill
  the area with spaces first (`SPC`). Columns 0-1 contain attributes: start the `GRAB` at
  column 2. A character in reverse video (code + 128) goes through as it is.
- **Integer array**: `SAVE` writes the numbers of a line separated by a space (`DIM N(2,3)`
  gives two lines `0 0 0`); `BSAVE` writes each integer as two bytes, low then high (-5:
  `FB FF`).
- **Size on the disk**: always a multiple of 128 bytes (`BSAVE SCREEN`: 1,152). `BLOAD` only
  reads the size of the array; the rest is ignored.

Example: the text screen as a file readable and editable in EDIT, then read back.

    DIM T$(28,38)
    LORES
    FOR Y 0 27
      LOCATE 2 Y
      SPC 38             ; des espaces, pas l'attribut 16
    NEXT
    ; ... dessin du texte avec LOCATE, ECHO, CHAR ...
    GRAB T$(0,0) 2 0 38 28
    SAVE T$ ECRAN        ; ECRAN.TXT : 28 lignes de 38 caracteres + CR LF
    ; plus tard, ou dans un autre programme :
    LOAD T$ ECRAN
    PASTE T$(0,0) 2 0 38 28

Colours (attributes, codes 0-31) do not go through `SAVE`: for a screen in colour, use
`BSAVE SCREEN` (the whole screen) or `BSAVE` of an array, touched up with HEX.

## 11. Errors

An error stops the program: back to the console, then `L n COMMAND : message`
(`L 3 LINE : valeur hors de 0-255`). A translated program checks nothing while running (§ 12);
only the errors that are not the program's fault remain, without a line number: files
(`Erreur : disque plein`, disk full...), `memoire pleine` at a `DIM` of computed size. ESC
does not stop it (§ 8).

| Topic | Messages |
|---|---|
| Reading | `commande inconnue` (unknown command), `parametres ?` (parameters?), `ligne de plus de 126 car.` (line longer than 126 characters), `expression ?`, `variable ? (A, AB ou A1)` |
| Values | `valeur hors de 0-255` (value outside 0-255), `valeur hors limites` (value out of range), `division par zero`, `pas nul` (zero step) |
| Modes | `HIRES ou SPLIT d'abord`, `LORES d'abord` (... first) |
| Blocks | `NEXT sans boucle` (NEXT without loop), `NEXT manquant` (missing NEXT), `bloc non ferme` (block not closed), `fin de bloc en trop` (extra end of block), `trop de blocs imbriques` (too many nested blocks), `RETURN sans CALL`, `SUB introuvable` (SUB not found) |
| Arrays | `deja dimensionne`, `tableau non dimensionne`, `indice hors limites`, `memoire pleine`, `chaine trop longue`, `chaine dans un calcul` |
| Sprites | `SPRITES d'abord`, `SPOOL d'abord`, `fichier .SPR ?` (not a sprite `.SPR`, or malformed sprite), `plus de caracteres pour les sprites` (empty pool); `valeur hors limites`: slot, sprite rank, pool code, sprite off the screen |
| Files | `Fichier introuvable` (file not found) and `Fichier trop gros` (file too big) for the `.GRX`, `image introuvable`, `disque plein`, `repertoire plein` (directory full), `fichier protege` (read-only), `animation introuvable`, `animation trop grande`; data (§ 10): `ligne trop longue : L n`, `trop de lignes : L n`, `nombre ? : L n`, `code 0-31 : BSAVE` |

An `ENDIF` forgotten after a true `IF` is not reported: the rest runs normally.

## 12. Translation into assembly (GRXASM)

    A>GRXASM MOTIFS
    MOTIFS.ASM ecrit : ASM MOTIFS
    A>ASM MOTIFS
    A>MOTIFS

- Translation is done by `GRXASM.COM`, a separate program (the interpreter does not keep its
  code in memory). `GRAPHER NAME /A` starts it through CHAIN: the line becomes
  `GRXASM NAME /A ...`, 78 characters at most (`Ligne trop longue`). GRXASM must be on a
  drive where commands are searched for.
- Translation does the same analysis as the interpreter. Syntax and block errors are reported
  with the line, and `NAME.ASM` is then not written.
- The `.ASM` is readable: each line of the `.GRX` appears in it as a comment. Variables `V_A`
  to `V_Z` (in `GRX.INC`) and `V_PX`, `V_N1`... (reserved at the end of `NAME.ASM`, only those
  the program uses), labels `L3T`, `L3E`, `L3X` for blocks, `P_NAME` for subroutines, `B1`,
  `B2`... for `FOR` and `REPEAT` loops. To take little room on the disk, an instruction is
  preceded by a single space; labels and directives (`.byt`, `.word`, `*=`) are in column 1.
- Code produced, besides the constants computed:
  - a simple right operand (a number or a variable, with nothing binding more tightly after
    it: `K = 9`, `X - Y`, `N + 1`) goes straight into `g_et`, without going through the value
    stack; the operation is done the other way round (`<` becomes `>`, `X - 2` becomes
    `X + (-2)`, `X - Y` calls `g_rsub`). `/` and `%` always go through the stack;
  - `IF` and `WHILE` test the result of a comparison, an `&` or an `|` directly (Z flag
    returned by `g_cmp`, `g_and`, `g_or`);
  - `V = V + 1` and `V = V - 1` (nothing else on the line) become `inc` and `dec`;
  - a constant whose two bytes are equal (`0`, `-1`, `257`) is loaded once.
- The constant parts of expressions are computed during translation (`120+8` gives `128`); a
  constant outside 0-255 is reported at once.
- `$1`-`$9` are replaced at translation time.
- **No checks at run time.** The interpreter is for debugging; the translated program goes
  straight to the point, under the programmer's responsibility (as in C). If a translated
  program misbehaves, run it again interpreted to find the error.
  - Checked during translation (with the line number): syntax and blocks, a constant outside
    0-255 (parameter or byte of a `$` array), a constant zero step, a division by a constant
    zero, the depth of expressions.
  - No longer checked at all: a computed parameter outside 0-255 (only its low byte counts), a
    column or a line off the screen, a LORES command outside LORES, indices and arrays, a
    string too long (cut at the capacity), a division by zero (the result is meaningless), a
    computed zero step (the loop never ends), ESC (a key like any other, § 8).
  - A parameter that is a simple variable is read in one instruction (`lda V_L`, its low
    byte).
- An array must be declared by a `DIM` placed higher up in the file (translation reads the file
  in order).
- **Fixed-address arrays.** A `DIM` of constant sizes (`DIM X(8) G$(16,16)`), outside any
  block (no `IF`, loop or `SUB`), the first `DIM` of that array, is reserved when the program
  starts, before the first line: its address is known at translation time (`T_X` for `X()`,
  `C_G` for `G$()`, written at the end of `NAME.ASM`). Its elements are then read and written
  without going through the descriptor:
  - constant indices: a fixed address (`S(3)`: `lda T_S+6`); `A - S(3)` goes straight into
    the right operand, like a variable;
  - array of 256 bytes at most (128 integers), computed indices: the offset is put in Y
    (`lda T_X,y`); with two indices, a table of the start of each line (`TR_G`, a few bytes in
    the file) avoids the multiplication. `X(I)` or `G(I,J)` (constant indices or simple
    variables) also goes straight into the right operand;
  - larger array, computed indices: through the descriptor.

  The descriptor is written too (`LOAD`, `SAVE`, `FILL`, `SPRITES` and strings use it). A
  `DIM` of computed size, or inside a block, is still executed in its place. Measured example:
  8 "monsters" moved 50 times (arrays `X Y D E` of 8 integers, grid `G$(16,16)`): 3.2 times
  fewer instructions than through the descriptors, and a slightly smaller program.
- **Libraries.** GRXASM copies at the end of `NAME.ASM` only the routines the program needs
  (those it calls, and those they call), taken from `GRX.INC` and `HIRES.INC` always
  (`HIRES.INC` also holds the text screen: `h_init`, `h_text`, `PRINT`), plus `ARR.INC` if the
  program has arrays or strings (a `PRINT "..."` is enough), `FIL.INC` if it reads or writes data files (`SAVE`... `FOUND`),
  `SPR.INC` if it has sprites and `ANIM.INC` if it animates. These files are looked for on the
  drive of the `.GRX`, then on the drives already read from A: to D: (system disk in A:,
  project in B:); otherwise: `GRX.INC absente (bibliotheque)`, library missing. ASM then only
  needs `CPA.INC`, looked for the same way. For CARTE, `NAME.ASM` is 46 KB: `/C` only leaves
  `NAME.COM` (8 KB). They are, with GRXASM, on the complete disk, the Assembler disk and the
  Animations disk (not on the Logo disk, which has no ASM).
- Size of a translated `.COM`: 1.4 KB for `ARDOISE`, 1.7 KB for `DESSIN`, 2.2 KB for `MOTIFS`,
  4.0 KB for `SERPENT`, 6.0 KB for `SPRITES` (removing the checks took 4 to 15% off).
  `NAME.ASM` is longer (10 KB for `DESSIN`, 34 KB for `SPRITES`): the room is needed on the
  disk during translation. ASM takes less than a minute for `MOTIFS`.

## 13. Memory, speed, limits

- **Memory** (interpreted): GRAPHER.COM (17,654 bytes) at `$0500`, then the tables of
  `hires.inc`, the buffers and the variables. The text of the `.GRX` comes next and ends at
  `$9D60` at the latest. Arrays are reserved below `$9D60`, downwards, as far as the end of
  the text. An animation or a `.HIZ` picture is loaded after the text, never covering the
  arrays. The array descriptors take `$9D60-$9EFF`. `SPRITES n` reserves, below the arrays, 5
  bytes per slot and 192 bytes for the two pools; `TILESET`, (wid × hgt + 1) pages (§ 7.3).
  The free area for the text, the arrays and an animation is about 17 KB (text from
  `$599F`): `VAISSEAU.ANI` (12.5 KB) plays there, not `CUBE.ANI` or `BALLE.ANI` (18 and
  21 KB), which need translation.
- **Memory** (translated): the program at `$0500`, then the tables of `hires.inc`. Arrays are
  reserved below `$9D60` as when interpreted: fixed arrays (§ 12) at start, in the order of
  the `DIM`s, then the others at their `DIM`.
- **Sizes of a translated program** (measured on the eleven examples, `files/*.grx`; the
  program's part separated from the libraries'):

  | | Per byte of `.GRX` | Per line of `.GRX` | CARTE (96 lines, 2.1 KB) |
  |---|---:|---:|---:|
  | `NAME.ASM`, program | 6.4 to 7.0 bytes | ~10 lines, ~140 bytes | 14.2 KB |
  | `NAME.ASM`, libraries | — | — | 32.0 KB |
  | `NAME.COM`, program | 1.15 to 1.35 bytes | ~25 bytes | 2.6 KB |
  | `NAME.COM`, libraries | — | — | 5.8 KB |

  The compiled program is thus roughly the `.GRX` in clear, plus the library routines it
  uses: 0.8 KB (ARDOISE) to 5.8 KB (CARTE) in the examples. The intermediate `.ASM` is about
  6.5 times the `.GRX`, plus the text of the copied routines (5 to 32 KB; the six libraries
  are 69 KB on the disk, no program takes them all). A `.GRX` does not exceed ~17 KB
  interpreted (text and arrays together) nor ~21 KB for GRXASM (text from `$48AF` to
  `$9CE0`). Worst case for a 17 KB `.GRX`: a 145 to 175 KB `.ASM` and a ~30 KB `.COM`, both
  present during assembly, so ~200 KB on the project disk (336 KB); `/C` then leaves only
  the `.COM`. The limit that matters is memory: the `.COM` and its arrays fit between
  `$0500` and `$9D60` (~38 KB); 30 KB of code leave only ~8 KB of arrays.
- **Speed**: 150 to a few hundred lines per second interpreted (a sky of 400 stars,
  `PLOT 1+RND(238) 1+RND(198)`: 5 s; translated: 0.6 s). A sprite of 1 × 2 cells moved with
  `SSHOW`: 2.3 ms in a translated program (about 1.1 ms per cell: removal then display). An
  area of 38 × 26 cells (translated program, measured in the simulated 6502, estimated in
  cycles): `PASTE` or `SCROLV`, about 20 ms (one frame); `TMAP`, 35 to 55 ms depending on
  the tile size (§ 7.3); `SCROLH`, `ROTH`, about 40 ms (each
  line goes through a buffer); `ROTV n`: n passes of one line, in the shorter direction. In
  the picture, count 8,000 bytes for the whole HIRES screen: about 150 ms. Without run-time
  checks (§ 12), a loop of 1,000 `RND` and `CHAR` runs 2.2 times faster than with them, and
  1,064 `LOCATE` and `CHAR` 1.65 times (simulated 6502, in instructions).
- **Limits**: integers only, variables of one or two letters (arrays and strings: one
  letter), two dimensions at most, no string concatenation or conversion.

## 14. Examples provided

| File | Contents |
|---|---|
| `DESSIN.GRX` | SPLIT mode, with a parameter |
| `ECRAN.GRX` | title screen coloured with attributes (HIRES) |
| `MOTIFS.GRX` | fan, circles, starry sky: loops, random numbers, subroutine |
| `ARDOISE.GRX` | etch-a-sketch: the arrows draw, SPACE clears, Q ends (`INKEY`) |
| `FLECHES.GRX` | LORES: an `@` moved with the arrows inside a frame, `SCRN` for the walls |
| `SERPENT.GRX` | LORES: snake (body in two ring arrays, `SCRN` for collisions) |
| `SCORES.GRX` | high scores: `INPUT` of the name, sorting, title coloured by an attribute at the start of the string; the best five kept in `HOFN.TXT` and `HOFS.TXT` (`LOAD`, `SAVE`, `FOUND`) |
| `SPRITES.GRX` | LORES: a little man led with the arrows (two walking frames) and a bouncing ball, on two-colour scenery; sprites from `HEROS.SPR` |
| `CARTE.GRX` | LORES: an island of 64 × 32 tiles of 2 × 2 (128 × 64 characters) drawn at random in `T$` (lakes, trees, mountains, walls), written in plain text (`TILESET` with `K$`), seen through a 38 × 26 window centred on the player (`TMAP`; outside the island, tile 0: the sea); drawings from `TUILES.SPR` in the secondary set (`TFONT ... ALT`); you walk only on grass (`TILE`); arrows (`INKEY`, redraw only after a step, subroutine `CALC`), Q: end |
| `DEFILE.GRX` | LORES: a road scrolling downwards (`SCROLV`, then the new line at the top); left and right arrows, `INKEY` |
| `ANIMS.GRX` | animations (Animations disk) |
| `ROTSCROL.GRX` | LOAD, PASTE, SCROLV/H, ROTV/H demo |
| `JEU.GRX` | FILL, PASTE, ROTV/H local. Put the colors back to their initial location |

## 15. Implementation

| File | Role |
|---|---|
| `progs/grapher.s` | interpreter (`GRAPHER.COM`); `/A`: CHAIN to GRXASM |
| `progs/grxasm.s` | translator (`GRXASM.COM`) |
| `progs/grxd_inc.s`, `progs/grxc_inc.s` | shared by both: constants and zero page; reading the `.GRX` and its lines, parameters, table of command names (the frequent ones first), parsing of names, numbers and functions, constant folding, subroutines, errors. Each program has its own `cadr` table of command addresses, in the order of the name table, and its own assignments (`x_asg`, `x_aasg`), `ANIM` (`an_val`, `an_none`), `ndim_s`, `to_text`, `o_drop` and buffers |
| `progs/grx.inc` (`GRX.INC`) | run-time library of translated programs |
| `progs/arr.inc` (`ARR.INC`) | arrays and strings, shared by both (`r_chk`: checks when interpreted); descriptors at `$9D60`; screen rectangles (`r_blit`, `r_scrl`, `r_sdef`, `r_rows`) |
| `progs/hires.inc` (`HIRES.INC`) | screen: drawing, LORES (`h_lores`, `h_loc`, `h_chr`...), vertical writing (`h_lvon`, `h_lvoff`), pictures; `h_buf`: 40 free bytes after its tables (buffer of `r_scrl`) |
| `progs/anim.inc` (`ANIM.INC`) | `.ANI` animations; the `ANIM` of translated programs (`a_grx`) is in `GRX.INC`, so that it costs nothing to the interpreter or to VOIR |
| `progs/spr.inc` (`SPR.INC`) | sprites (`s_res`, `s_pool`, `s_show`, `s_hide`) and tiles (`t_set`, `t_map`, `t_get`, `t_font`; `g_tmap` of `GRX.INC` for translated programs), shared by both; uses `arr.inc` (descriptors, room below the arrays) and `hz_tad` (`hires.inc`); asks the program for the byte `s_hst` |
| `progs/fil.inc` (`FIL.INC`) | data files (`SAVE`... `FOUND`), shared by both; records in `DEF_DMA`; asks the program for its FCB (`f_fcb`), number writing (`f_fmt`, `f_nbuf`) and two messages |

Buffers (file names, parameters, words...) come after the end of the program, set to 0 at
start: they are not in the file.

**Variables**: `getvar` (a statement: `FOR`, `GET`, `INPUT`, assignment) and `kw_var` (in an
expression, after `parse_id`) return the first letter in `vix` (0-25) and the second
character in `vc` (0: none, 1-26: letter, 27-36: digit); `IF` is refused (`not_if`). The
interpreter stores the 962 variables in a `vars` table of 1,924 bytes (between `lbuf` and the
text, set to 0 at start): `vaddr` computes `vars + 2 * (26 * vc + vix)`, with no search, so as
fast as with one letter; a `FOR` loop keeps the address of its variable (`cs_v`, `cs_vh`). The
translator writes `V_` then the name (`o_sym`); it notes the two-character variables it meets
(`kvu`: 5 bytes per letter, one bit per second character) and reserves them at the end of
`NAME.ASM` (`o_vars`, `.word 0`). A `Bn` loop block is 6 bytes: limit, step, then the address
of the variable, written on entering the `FOR`; `g_forok` and `g_forstep` read it there. Loops
have their own number (`knb`, `k_newloop`, kept in `cs_bl`/`cs_bh`), distinct from that of
blocks (`kn`, labels `L`): only `FOR` and `REPEAT` have a `Bn`.

**Translated expressions**: the left side of an operation stays a constant (`vs_f` = 1), goes
through `g_push` (`vs_f` = 0), or stays in `g_ev` when `k_simple` sees, reading the rest of
the line, that the right side is a number or a variable with no stronger operator behind it
(`vs_f` = 2): `kdst` then sends the variable into `g_et` (`ld_var`), and `k_apply` (`lreg`)
puts the constant there, then picks the reversed operation (`cswp` for comparisons, `"r"` for
`g_rsub`). `kz` is 1 right after a `jsr g_cmp`, `g_and` or `g_or`; any other instruction
resets it to 0 (`o_tab`); `o_skipz` then only writes `bne *+5` / `jmp`. `k_incdec` recognises
`V = V + 1` and `V = V - 1`.

**Copied libraries** (GRXASM): `build.sh` passes the disk's stripped copies
(`tools/strip_inc.py`) through `tools/mark_inc.py`, which cuts the six libraries of translated
programs into routines (from a label in column 0, outside a `.( .)` block, to the next one),
numbers them in sequence in the order of `NAME.ASM` (GRX, ARR, FIL, SPR, ANIM, HIRES) and
writes comment lines: `;@#NNN` (the file's first routine is NNN+1), `;@DDDEEE` before each
routine (the routines it needs: what its instructions and data name, and the next one if it
ends neither with `rts`, nor `jmp`, nor data; `;@*`: always kept, `g_init`), `;@+DDD`
(continued), `;@=NNN` (lines of another routine: a constant equal to a label, such as
`a_fail = g_stop`, is a name of that routine; `000`: always copied). During translation, `oc`
records the names written that start with a lower-case letter and contain `_` (`kcapt`, list
`kroot`). At the end, `kl_libs` reads the useful libraries a first time (`kl_run` 0): a routine
whose label, or a constant equal to it, is a recorded name is kept (`KMK`, one mark per
number), and each need gives an edge (`KEDG`, 4 bytes); `kl_clos` walks the edges until
nothing changes; the second read (`kl_run` 1) copies the lines of the kept routines. These
tables take the place of the `.GRX` text, no longer needed. `tools/test_inc.sh` checks that the
marked copies assemble like the originals and that each translated program assembles (a
forgotten routine gives an undefined label); `test_grapher.sh` translates with them.

**Fixed arrays** (GRXASM): `kf_new` decides, at the `DIM`, that an array is fixed and computes
its address as `r_dim` will (`kftop` follows `r_top`, from `$9D60`); nothing is written at the
`DIM` line. The header of `NAME.ASM` calls `G_INIT`: without a fixed array, `G_INIT = g_init`
(written after `HIRES.INC`); otherwise a routine (`kf_init`) that calls `g_init`, corrects
`g_sp` (two `inc`: the start-up stack), then does the `r_dim1` / `r_dim2` of the fixed arrays
from the highest to the lowest, that is in the order of the `DIM`s. Then come the tables of
the lines used (`TR_G .byt`) and the addresses (`T_G = $9D38`). `kf_*` slots: 0-25 integers,
26-51 `$` arrays; an array is small (`kf_sm`) if it is 256 bytes at most. An access (`kf_get`,
`kf_put`) reads its indices through `kf_ix`: each one is computed (`g_ev`), a simple variable
(read later, without code; small array only) or a constant (`kcl`); the result is a fixed
address (`kfm` = 0, `kfo`), an offset in A (1) or to be loaded into Y from the operand (3,
bytes), or the descriptor (2). The destination `ksym` = 3 writes `T_S+kfo` then `,y` (`kyx`),
which lets `ld_var` and `o_st16` be reused. An assignment keeps the offset on the 6502 stack
(`pha` / `pla`) only if the value needs a calculation (`kf_look`); an integer received from a
variable is copied directly (`kf_cpv`). `kf_get` keeps its state (`kfst`, `KFN` bytes) on the
stack: an index can read another fixed array. `ks_arr` extends `k_simple` to elements with
constant indices, or with simple variables in a small integer array. Tests: `fix.grx`,
`e_fix.grx`.

**Checks**: a translated program makes none (§ 12). GRXASM writes `lda g_ev` (or `lda V_x`
for a single variable: `kv_one`) where it used to write `jsr g_byte`, calls `h_loc`, `h_chr`,
`h_ltab`, `h_lvon`, `r_scrl` directly, and no longer writes `jsr g_brk` at each `NEXT`.
`GRX.INC` no longer has `g_byte`, `g_needlo`, `g_chk`, `g_brk`, nor the tests of `g_push`,
`g_sdiv`, `g_forok`, `g_scrn`. In `arr.inc`, `r_chk` (0 when translated) also controls the
0-255 range of `r_stb` and `r_fill`, and `r_copy` cuts a string that is too long instead of
stopping. `k_apply` refuses a division by a constant zero; the depth of expressions is bounded
during translation (`NVS`), like the value stack of `GRX.INC` (24).

**Random numbers**: 32-bit xorshift (`x ^= x << 8`, `x ^= x >> 9`, `x ^= x << 23`), of period
2³² − 1. The shifts were chosen among those that give this period so as to work by bytes: byte
copies and a single one-bit shift (63 bytes, no loop). `RND(n)` takes one step, then, for
n < 256, returns (high word × n) / 65,536 (an 8-step multiplication); for larger n, the
remainder of the division of the high word (15 bits) by n. Seed: the 50 Hz counter, completed
with `$5A` `$A5` (never zero), then 4 steps, without which two runs one tick apart start with
close values. The interpreter (`rand`, `f_rnd`) draws the seed at start; `GRX.INC` (`g_rnd`)
at the first `RND`, so that a program without `RND` does not carry the generator. A 16-bit
generator (seed × 5 + 13849, for example) ties each draw to the previous one: coordinates
drawn in pairs line up in bands; no 16-bit generator holds in three dimensions. Tests:
`rnd.grx` (values, bounds), `rnd2.grx` (pairs of draws: 64 cells all filled), `e_div0.grx`.

**Rectangles** (`arr.inc`): they are in `ARR.INC` rather than in `HIRES.INC`, which other
programs include (VOIR) without using them; a translated program that scrolls therefore
includes `ARR.INC`, of which GRXASM copies only the useful routines.

- `rz_ra`: address of the start of a line at column `h_x1` (LORES: `hz_rows`; picture:
  `h_ylo`, `h_yhi`). `rz_mv` copies `rz_bn` bytes from `hp` to `hq` (`lda (hp),y` /
  `sta (hq),y`, about 18 cycles per byte); `rz_fl` fills.
- `r_blit` (`PASTE`, `GRAB`): one screen line per array line; memory moves on by `r_bst`
  bytes (size 2 of the array, read in its descriptor), the screen by one line. The interpreter
  checks the opposite corner with `r_ea2` before copying; the indices are kept in `flim` and
  `fstep` (`FOR` temporaries) while the four other parameters are computed. Translated, the
  two indices go through the value stack (`g_push`), then `g_paste` or `g_grab` takes them
  back.
- `r_scrl`: `|n|` brought back to the size (modulo for a rotation). In width, each line goes
  through `h_buf`, then comes back shifted in two pieces (the rest, then the k freed cells:
  `r_sf`, or the start of the buffer for a rotation). In height, whole lines are copied in the
  right order (bottom to top to go down); a rotation does k passes of one line, k brought down
  to at most half the height by changing direction, the line that goes out passing through
  `h_buf`.
- `r_sdef` sets the rectangle of the whole screen and the default byte; the parameters given
  then replace them (interpreted and translated do the same).
- `PRINTV`, `ECHOV`, `SPCV`: `h_lv` (`h_lvon` / `h_lvoff`) only changes the cursor's advance
  in `h_lput` and the direction of `h_lnl`; GRXASM wraps the translation of `PRINT`, `ECHO` or
  `SPC` in `jsr g_vlon` and `jsr h_lvoff`.
- Tests: `lo_rect.grx` (LORES: rectangles, signs, byte, rotations, vertical writing, `PASTE`,
  `GRAB`), `rect.grx` (picture, through `POINT`), `e_rect*.grx` (errors).

Zero page: `$10-$5C` for GRAPHER and GRXASM, plus `$5E-$61` (GRAPHER: random seed; GRXASM:
pointers), `$10-$2C` for `GRX.INC`, `$B0-$BF` for `spr.inc`, `$C0-$C7` for `hires.inc`,
`$C8-$CF` for `arr.inc`, `$D0-$DF` for `fil.inc`.

**Sprites** (`spr.inc`):

- One **pool** per character set: the programmer's array is used as a stack (the first `top`
  elements are the free codes; take: `top - 1` then read; give back: write then `top + 1`; the
  order of the codes changes, which does not matter), its top, its size (96 at most), and
  `SOUS`: 96 bytes, for each code from 32 to 127 the scenery byte hidden by the character that
  carries this code (0: free code). The two `SOUS` and the slots are reserved by `SPRITES`,
  below the arrays.
- A **slot**: 5 bytes, pool + 1 (0: free), column, line, width, height. The sprite's rank is
  not kept: `SHIDE` only needs the rectangle; the codes taken are read on the screen, what
  they hide in `SOUS`.
- `SSHOW`: removes the slot's old sprite; walks the file up to sprite n (size of each sprite in
  its header); when interpreted, checks the file and the screen, then counts the codes to take
  before drawing anything (nothing is half-placed); for each cell: attribute → nothing; code
  already taken in this pool (`SOUS` not zero) → draw over it; otherwise a code is taken from
  the pool, `SOUS` receives the scenery byte. The character is drawn
  (`(scenery AND NOT silhouette) OR drawing`, 8 lines) before being shown; bit 7 (reverse
  video) of the scenery is kept. Translated, an empty pool leaves the cell without a sprite.
- `SHIDE`: for each cell of the rectangle, if its code has a non-zero `SOUS`: the scenery comes
  back, `SOUS` at 0, the code goes back to the pool.
- **Line history**: `SPOOL ... ALT` sets `s_hst` to 1; when giving the console back (`to_text`
  in GRAPHER, `g_totext` in `GRX.INC`), the program then empties the history (`$BA80`),
  covered by the drawings of the secondary set. The system has nothing to do with it (no
  resident byte); after a crash or CTRL-C, the history may keep meaningless lines, with no
  other effect.
- Tests: `lo_spr.grx` (display, moving, overlap, attribute, reverse video; drawings checked
  on a dummy font, `NAME.env`), `lo_spr2.grx` (secondary set, history emptied), `e_spr*.grx`
  (errors).

**Tiles** (`spr.inc`, same zero page as the sprites):

- `TILESET` (`t_set`) reserves (wid × hgt + 1) aligned pages below the arrays (`tz_res`,
  `t_tb`, `t_np`: again only if a `TILESET` asks for more). Page 0: map byte → tile number
  (0 everywhere, then the numbers; with `K$`, from the last character to the first, so that
  the first one wins; `t_z`: a byte that gives tile 0). Page 1 + p, for each place
  p = line × wid + column in the tile: map byte → displayed code, filled byte by byte
  (address of the `D$` line by `rz_mul`, kept while the tile does not change). `TMAP` has no
  tile number left to look up: it translates, as for a 1 × 1 map.
- `tz_div`: X / wid (1 to 4, signed, rounded down) by 16 shifts and subtractions, once per
  command (`tz_cut`: tile and place for X and Y).
- `TMAP` (`t_map`): number of tile columns touched (`t_nt`), and the first and last ones in
  the map (`t_jl`, `t_jh`), once; then for each screen line, three pieces: before the map,
  in the map, after (outside the map: `t_z`). One-column tiles: `lda (map),y` / `tax` /
  `lda table,x` / `sta (screen),y` (about 35 cycles per cell). Wider: the bytes of the line's
  tiles go into `h_buf` (21 at most), then four `lda table,x` instructions (one per place,
  page modified on each line) follow each other; a counter tells when to move to the next
  tile (about 55 cycles per cell for 2 × 2). The map line (`t_mp`) moves on by one line of
  tiles every `hgt` lines; a line outside the map has only `t_z`.
- `TILE` (`t_get`): `tz_cut`, then the map byte and page 0; the map (address, lines,
  columns) is the one kept by the last `TMAP` (`t_ma`, `t_mr`, `t_mc`).
- `TFONT` (`t_font`, `tz_walk`): a first pass counts the cells (and checks the file when
  interpreted: `sz_find0`, kind 1, sizes, room in the array), the second copies them to
  `$B400` or `$B800` + 8 × code. `ALT` sets `s_hst` to 1 (history emptied).
- GRXASM copies only the useful routines: `tz_in` and `tz_inc` (two entries of the same test)
  are written so that `tz_in` can come without `tz_inc` (no `BIT abs` between them).
- Tests: `lo_tile.grx` (`K$`, camera straddling tiles, outside the map, unknown byte, short
  line, 3 × 1 tiles without `K$`, `TILE`), `lo_tile2.grx` (`TFONT` in both sets, `K$` in an
  array, 1 × 1 tiles), `lo_tile3.grx` (sprite on tiles, in both sets: drawings redrawn
  with the mask, tile restored when it moves), `e_tile*.grx` (errors); `TUIL.SPR` made by `tools/mkspr.py` (source
  `tuil_spr.txt`), `TUIL.TXT` and `MAPT.TXT` read by `LOAD`.

Tests: `tools/test_grapher.sh` checks the CHAIN of `/A`, then runs each case interpreted
(GRAPHER) then translated (GRXASM), in the simulated 6502 (`tools/run_com.py`, no emulator),
and compares with the expected result (`.ref`, `.kref`, inputs in `NAME.in`). Then the
examples are tried in Oricutron.

## 16. Decided, not done yet

- Characters animated at the 50 Hz rate (rippling water), without touching the map.
- **Character and sprite editor**: a full-screen `.COM` that writes the `.SPR` files
  (sprites and tiles). Meanwhile, `tools/mkspr.py` makes a `.SPR` on the PC from a drawing
  in text (`tools/spr/tuiles.txt`).

## 17. Open questions

- **Game phases** (`RUN NAME [p...]`): the program hands over to another `.GRX` or translated
  `.COM`, keeping variables, arrays and screen (LORES, HIRES, sprites). When interpreted, only
  the text is replaced (it must fit below the arrays). When translated: the variables in a
  fixed area common to all the `.COM`s (stored as in the interpreter), the arrays already
  below `$9D60`, a loader copied to `$9F00` that reads the `.COM` at `$0500` and jumps to it
  without resetting the variables; each phase keeps its libraries. Still to choose: the name
  (`RUN` or `CHAIN`); how a phase declares the arrays it receives (an identical `DIM`
  accepted without clearing, or `COMMON`).
- If `SSHOW` walking through the file is too slow for the last sprites: a table of positions
  built at load time.
- Later: sprites that bring their own colour ("attribute" cells in the file, placed as they
  are, restored on removal).
