# LOGO — reference

> English translation of `docs/logo.md`. This LOGO is a French Logo: its primitives are French
> words (`AVANCE` for FORWARD, `POUR ... FIN` for TO ... END) and they are kept as they are
> here, with their meaning. An English LOGO (`LOGOEN.COM`) is planned.

A>LOGO

This is a Logo in French. The turtle draws in the SPLIT mode picture (LOGO switches to it by
itself), and you type commands under the picture, after the `?` prompt. Numbers are integers
or decimals (see below).

| Command | Effect |
|---|---|
| `AVANCE n` / `AV`, `RECULE n` / `RE` | forward, back |
| `DROITE n` / `DR`, `GAUCHE n` / `GA` | turn right, left (degrees) |
| `LEVECRAYON` / `LC`, `BAISSECRAYON` / `BC` | pen up, pen down |
| `GOMME`, `INVERSE` | the pen erases, inverts |
| `CACHETORTUE` / `CT`, `MONTRETORTUE` / `MT` | hide, show the turtle |
| `VIDEECRAN` / `VE`, `NETTOIE`, `ORIGINE` | clear and go back to the centre, clear, go back to the centre |
| `FIXECAP n`, `FIXEXY x y` | absolute heading, absolute position (centre = 0 0, y upwards) |
| `POINT x y`, `TRAIT x1 y1 x2 y2` | a point, a line (turtle coordinates) |
| `RECTANGLE x1 y1 x2 y2`, `PAVE x1 y1 x2 y2` | rectangle (two opposite corners), filled rectangle |
| `CERCLE r` | circle of radius r (0 to 127) around the turtle |
| `ETIQUETTE x` | writes x (number, word or list, like `ECRIS`) in the picture, to the right of the turtle and sitting on its line |
| `FIXECOULEUR v` | colour of the whole picture: ink 0 to 7 (0 black, 1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white) or paper 16 to 23 |
| `ECRANTEXTE`, `ECRANMIXTE` | switch to the text screen (26 lines, no picture or turtle), back to the picture and the turtle |
| `VIDETEXTE` / `VT` | clear the console (lines 1-27 on the text screen, under the bar on the mixed screen), cursor at the top left |
| `TAPE x` | like `ECRIS`, without a new line (games: a score in its place) |
| `FIXECURSEUR c l` | place the console cursor (for `TAPE`, `ECRIS`): column 0-39, line 0-27 of the whole screen (see "Games on the text screen") |
| `FIXECARECRAN c l n` | write code n (0-255) into a cell without moving the cursor: character, colour attribute (0-7 ink, 16-23 paper), +128 for reverse video |
| `REPETE n [ ... ]` | repeat a list |
| `SI condition [ ... ] [ ... ]` | condition, with an optional "else" list |
| `POUR NAME :A :B` ... `FIN` | define a procedure (parameters optional) |
| `STOP` | leave the procedure |
| `RENDS x` | leave the procedure returning x: it becomes a function (see below) |
| `DONNE "X n`, `:X` | global variable, value of a variable or a parameter |
| `ECRIS n` / `EC`, `ECRIS "word`, `ECRIS [text]` | print |
| `ATTENDS n` | wait n fiftieths of a second |
| `LISLISTE` / `LL` | reads a line from the keyboard and returns it as a list (`DONNE "R LISLISTE`); the line is turned to upper case |
| `LISMOT` | reads a line and returns it as a single word (without leading and trailing blanks) |
| `LISCAR` | waits for a key and returns the character (`ASCII LISCAR` for its code) |
| `TOUCHE?` | 1 if a key has been typed (read it next with `LISCAR`), 0 otherwise; does not wait |
| `TOUCHE` | the key, without waiting and without repeat delay (action games, like `KEY$` in BASIC): the one typed since the last `TOUCHE`, otherwise the one still held down, otherwise the empty word |
| `CURSEUR`, `CARECRAN c l` | cursor position `[column line]`; code of the cell (0-255) |
| `ASCII x`, `CAR n` | code of the first character; character of code n |
| `SAUVE "NAME`, `CHARGE "NAME` | save the procedures, load a file (`NAME.LOG`: procedures and other lines, executed); the name can be computed (`CHARGE :F`, `CHARGE MOT "S :N`) and start with a drive (`CHARGE "B:GAME`) |
| `EDITE "NAME` | change the procedures with EDIT, then come back (see below) |
| `SAUVEIMAGE "NAME`, `CHARGEIMAGE "NAME` | save, load the drawing (`NAME.IMG`, without the turtle) |
| `TITRES`, `LISTE "NAME`, `OUBLIE "NAME`, `OUBLIETOUT` | list the procedures, show one, forget one, forget all |
| `SON v n vol d`, `SONF`, `BRUITV`, `ENVELOPPE`, `MELANGE`, `ENSEMBLE`, `ATTENDSSON`, `SILENCE` | sound: see "Sound in LOGO" below |
| `AIDE`, `QUITTE` / `AUREVOIR` | help, back to CP/A (the picture stays) |

**Drawing without the turtle.** `POINT`, `TRAIT`, `RECTANGLE`, `PAVE`, `CERCLE` and `ETIQUETTE`
take turtle coordinates (centre 0 0, y upwards) but do not move it. They follow the pen mode
(`GOMME`, `INVERSE`), even with the pen up, and are clipped at the edges of the picture;
`CERCLE` and `ETIQUETTE` draw nothing if the turtle is outside the picture. `FIXECOULEUR` sets
the colour at the start of every line of the picture: its first 6 points (column 0) become
the colour, which drawing does not erase. `ALLUME? x y` returns 1 if the point is lit, 0
otherwise. All of them refuse the text screen (`ECRANTEXTE`).

    VE CERCLE 40 RECTANGLE -40 -40 40 40 TRAIT -40 -40 40 40
    ETIQUETTE [HELLO] FIXECOULEUR 3
    SI ALLUME? 0 0 [ECRIS "LIT]

In expressions: `+ - * / ( ) = < >`, as well as `HASARD n` (random), `CAP` (heading), `XCOR`,
`YCOR`, `ALLUME? x y`, `LISCAR`, `TOUCHE?`, `TOUCHE`, `CURSEUR`, `CARECRAN c l`, `JOUE? v`,
`RACINE x` (square root), `SIN x`, `COS x`, `ARCTAN x` (angles in degrees, like the turtle:
`SIN 30` gives 0.5, `ARCTAN 1` gives 45), `LN x`, `EXP x`, `ENT x` (integer part, towards
zero), `ARRONDI x` (nearest integer, 2.5 gives 3), `ABS x`, `QUOTIENT a b` (integer division,
towards zero) and `RESTE a b` (remainder, with the sign of `a`). A key typed while a program
runs is kept for `LISCAR` (the last one only); it is forgotten on return to the prompt. ESC
and CTRL-C also interrupt `LISCAR` (so `LISCAR` never returns them).

**Games on the text screen.** `FIXECURSEUR`, `CURSEUR`, `CARECRAN` and `FIXECARECRAN` take
whole-screen coordinates, like GRAPHER's LORES: columns 0 to 39 (0 and 1 hold the line's
attributes: `FIXECARECRAN 0 5 20` puts line 5 on a blue background), lines 0 to 27 on the text
screen (line 0 is the system bar, redrawn when a menu is opened), 16 to 26 on the mixed screen
(above, the picture; line 27 holds the mode attributes). LOGO keeps its console: `TAPE` and
`ECRIS` write at the cursor, wrap at the end of the line and scroll the console after line 27;
for the last cell of the screen, use `FIXECARECRAN`. `TOUCHE` reads the keyboard without
waiting and without the repeat delay: an arrow held down moves at every call as soon as it is
pressed, and nothing more once released (`LISCAR` and `TOUCHE?` follow the keyboard repeat).
The arrows return `CAR 8` (left), `CAR 9` (right), `CAR 10` (down), `CAR 11` (up); with SHIFT,
`CAR 240` to `CAR 243`, with CTRL `CAR 244` to `CAR 247` (same order). Example on
`cpa-logo-en.dsk`: `LOGO ARROWS.LOG` (an `@` moved inside a frame, the walls read with
`CARECRAN`).

    DONNE "K TOUCHE
    SI VIDE? :K [STOP]
    SI :K = CAR 9 [DONNE "X :X + 1]
    SI (CARECRAN :X :Y) = 32 [FIXECARECRAN :X :Y 64]

**Sound in LOGO.** The three voices of the AY (0, 1, 2) play while the program goes on; each
duration is in fiftieths of a second (0 to 255; 0: the note holds until the next one on the
voice, or until `SILENCE`). A value out of range gives `Valeur hors limites :` (value out of
range) followed by the command. ESC and any error cut the sound.

| Primitive | Effect |
|---|---|
| `SON v n vol d` | note n on voice v: 1 to 96, 37 = middle C, 46 = A 440 Hz (n = 12 × (octave − 1) + semitone + 1, C = 0), 0 = silence for d; volume 0 to 15, 16 = the voice follows the envelope |
| `SONF v p vol d` | tone of raw period p (0 to 4095): frequency = 62,500 / p Hz (p = 142: A 440 Hz) |
| `BRUITV v p vol d` | noise on voice v, period p (0 to 31; the noise generator is shared by the three voices) |
| `ENVELOPPE f p` | shape f (0 to 15, those of the AY: 0 decay, 4 attack, 8 sawtooth, 10 triangle...), period p (0 to 65535, in 256 µs units); one envelope for all the voices at volume 16 |
| `MELANGE v s b` | tone (s) and noise (b) of voice v, 1 = on, 0 = off, both possible at once; give it after `SON`, `SONF` or `BRUITV`, which set it |
| `ENSEMBLE [ ... ]` | the voices set in the list all start at the same instant at the end of the list (chord, common attack); also after a `STOP` or a `RENDS` in the list |
| `ATTENDSSON v` | waits for the end of voice v, or of all of them with 255; ESC interrupts |
| `JOUE? v` | 1 if voice v (255: any of the three) is still playing, 0 otherwise; an endless note (duration 0) does not count |
| `SILENCE` | stops the three voices |

    SON 0 37 12 20 ATTENDSSON 0
    REPETE 2 [SON 0 37 12 20 ATTENDSSON 0 SON 0 41 12 20 ATTENDSSON 0]
    ENVELOPPE 0 2000
    ENSEMBLE [SON 0 37 16 100 SON 1 41 16 100 SON 2 44 16 100]
    BRUITV 0 20 15 50 MELANGE 0 1 1

The C major chord starts at once and fades with the envelope; the last line mixes a note and
noise on voice 0. `NOTE` and `BRUIT` from earlier versions no longer exist: `NOTE 37 20` is
written `SON 0 37 12 20 ATTENDSSON 0`.

**Numbers.** Decimals are written with a point: `3.14`, `0.5`, `1.5E-7`, `6E23`. They are
"Oric style": 5 bytes, about 9 significant digits, from about 1E-38 to 1E38. A calculation
between integers stays an integer as long as it fits between -32768 and 32767; otherwise it
becomes decimal (`32767 + 1` gives 32768, `1000 * 1000` gives 1000000). `/` is a true
division: `7 / 2` gives 3.5, `6 / 3` gives 2. `ECRIS` prints at most 9 digits, without useless
zeros, in E notation above 999999999 or below 0.00001. Commands that expect an integer
(`REPETE`, `SON`, `ATTENDS`...) round to the nearest (`REPETE 2.6` repeats 3 times); beyond
32767: `Nombre trop grand` (number too large). `SI` is true for any non-zero number.

**Words and lists.** `"BONJOUR` is a word (it runs up to the next blank or bracket: `"-3.5`
too), `[UN DEUX [TROIS]]` a list; both can be stored in variables (`DONNE "L [A B C]`) and
passed to procedures. Functions:

| Function | Result |
|---|---|
| `PREMIER x` / `PR`, `DERNIER x` / `DER` | first, last element (or character of a word) |
| `SAUFPREMIER x` / `SP`, `SAUFDERNIER x` / `SD` | all but the first, all but the last |
| `ITEM n x`, `COMPTE x` | n-th element; number of elements (or characters) |
| `MOT a b` | word made of a then b (`MOT "BON "JOUR`) |
| `PHRASE a b` / `PH` | list of the elements of a then of b |
| `LISTE a b` | list of two elements (a list stays a sublist) |
| `VIDE? x`, `MOT? x`, `LISTE? x`, `NOMBRE? x`, `MEMBRE? a b` | 1 or 0 (empty, word, list, number, member) |

`EXECUTE [ECRIS 5 AV 10]` (or `EXEC`) runs a list. A word that looks like a number counts as
that number (`"12 + 1` gives 13), and a number becomes a word where one is needed (`COMPTE
12345` gives 5). `=` also compares words and lists. In an expression, `LISTE` is the function
above; at the start of a line, `LISTE "NAME` always shows a procedure. Words and lists take
the top of free memory, procedures the bottom; when space runs short, LOGO reclaims the space
of texts no longer in use.

**User functions.** A procedure that ends with `RENDS x` can be used in an expression, like
`RACINE`:

    POUR FACT :N
    SI :N < 2 [RENDS 1]
    RENDS :N * FACT :N - 1
    FIN
    ? ECRIS FACT 10
    3628800

It can return a number, a word or a list, call itself and be an argument of another one
(`ECRIS SOMME SQUARE 3 SQUARE 4`). A function that reaches `FIN` (or `STOP`) without `RENDS`
gives `Rien n'a ete rendu par NAME` (nothing was returned); a procedure called as a command
must not use `RENDS` (`Que faire de ce que rend NAME`: what to do with what NAME returns).
Self-calling functions go down to about forty levels (`Trop de niveaux`, too many levels,
beyond); procedures called as commands can call themselves much deeper.

**The turtle and decimals.** `AV`, `RE`, `DR`, `GA`, `FIXECAP` and `FIXEXY` accept decimals:
position and heading are kept to 1/256 (of a step or a degree), and the sine, read from a
table to 1/65536, is interpolated between two degrees. `REPETE 7 [AV 30 DR 360 / 7]` closes,
`DR 0.5` turns half a degree. `XCOR`, `YCOR` and `CAP` return an integer when the turtle is on
a whole point, otherwise a decimal rounded to 2 places (`FIXECAP 30 AV 100` gives `86.6` for
`YCOR`). A position beyond -32768..32767 gives `Nombre trop grand`.

**Changing procedures with EDIT.** `EDITE "NAME` (Fichier menu, "Editer...") saves all the
procedures to `NAME.LOG` and opens that file in EDIT. EDIT's Fichier menu then offers Retour
[Back]: the file is saved if it changed, LOGO comes back with its variables, its words and
lists, the turtle, the drawing and the screen mode, and loads `NAME.LOG` again (the
procedures are those of the file). LOGO's state goes through the file `LOGO.$$$`, erased on
return. A running program stops. You can also start `LOGO NAME`, which loads `NAME.LOG` right
away. Going from one program to the other uses BDOS function 47 (see "Calling the BDOS"
(`manuel.md`)).

**Text screen.** For a program that only writes text (decimal calculations, words and lists),
`ECRANTEXTE` (Tortue menu, "Ecran texte") gives the whole screen to text: 26 lines instead of
10. The picture stays in memory: `ECRANMIXTE` brings it back, with the turtle where it was. On
the text screen, the commands that move the turtle or touch the picture (`AV`, `RE`, `DR`,
`GA`, `FIXECAP`, `FIXEXY`, `ORIGINE`, `VE`, `NETTOIE`, `SAUVEIMAGE`, `CHARGEIMAGE`) give
`Impossible en ecran texte : AV` (impossible on the text screen); `LC`, `BC`, `GOMME`,
`INVERSE`, `CT`, `MT` remain allowed (they are used on the way back), and `XCOR`, `YCOR`, `CAP`
always answer. The space for procedures and texts does not change.

`-5` stuck after a blank is a negative number (`FIXEXY -50 -30`), whereas `3 - 2` is a
subtraction. ESC or CTRL-C interrupts a program (you stay in LOGO, procedures and variables
kept); at the `?` prompt, CTRL-C does nothing. The menu bar (Fichier, Tortue, Aide) types the
commands for the user.

Procedures are saved as text (`POUR` ... `FIN`), which can be changed with `EDIT DEMO.LOG`.
`CHARGE` also runs the other lines of the file. A file line is at most 126 characters, as on
the keyboard: beyond that, `CHARGE` stops on `Ligne de plus de 126 car. : L 12` (the number is
that of EDIT's status line, which flags these lines: see `EDIT.CFG`); a long list is built
over several lines (`DONNE "L PH :L [...]`). The disk contains `DEMO.LOG`, with SQUARE, POLY,
STAR, FLOWER, SPIRAL, TREE (recursive) and DEMO:

    ? CHARGE "DEMO
    ? DEMO

The LOGO disk (`cpa-logo-en.dsk`) adds examples by Pierre, which start by themselves with `LOGO
NAME`: `ELIZA` (the "doctor", a conversation in English; `GOODBYE` to leave), and three curve
plotters on axes: `PLOTSQR` (x²), `PLOTSIN` (sine), `PLOTSINX` (x sin x). `ELIZA2` gives the
same answers, but its searches are recursive functions (`RENDS`) that stop as soon as they
find, and a word missing from the table is ruled out with a single `MEMBRE?` instead of an
80-turn loop that copies the table: an answer takes 1 to 2 s instead of 15 to 30. Comparing
the two is a good Logo lesson on the Oric: a `REPETE` that goes on after finding, and `SP` on
a long list (a copy at every step), are expensive.

The Logo reads the text of the procedures directly; primitive names are found through an
index by first letter, built at start-up. Lists and calls go through a context stack in
memory, not through the 6502 stack. Recursion can therefore go down to 120 levels, with 100
active parameters and 32 global variables.

**A large program in stages.** A `.LOG` file can hold any Logo lines, not only procedures:
`CHARGE` runs them all, as if they were typed. And `OUBLIE "NAME` really gives back the
procedure's space. A program too large for memory (an adventure game, for instance) is
therefore split into stages: a kernel loaded once, then, at each stage, the file of that
stage, forgotten when it is left. Global variables carry over from one stage to the next.
Example (tried): `KERNEL.LOG` contains

    POUR GAME
    DONNE "N 1
    REPETE 3 [STAGE]
    ECRIS "END
    FIN
    POUR STAGE
    CHARGE MOT "S :N
    ROOM
    OUBLIE "ROOM
    FIN

and `S1.LOG`, `S2.LOG`, `S3.LOG` each define a procedure `ROOM`, which plays the stage and
chooses the next one (`DONNE "N 2`). Start `LOGO KERNEL`, then `GAME`. The name given to
`CHARGE` (as to `SAUVE`, `SAUVEIMAGE`, `CHARGEIMAGE` and `EDITE`) can be computed: `"S1`, `:F`,
`MOT "S :N`... A stage file can load its picture (`CHARGEIMAGE "SALLE1`). Two rules:

- No `CHARGE`, `SAUVE` or `EDITE` during a `CHARGE` (in the loaded file, or in a procedure it
  calls): they would take the file being read. LOGO refuses it (`Interdit pendant CHARGE :
  CHARGE`, forbidden during CHARGE) and goes back to the prompt. The kernel chains the loads,
  once each file is finished.
- The kernel, loaded first and never forgotten, loads and forgets the stages. Forgetting the
  running procedure, or a procedure loaded before it, would move in memory the text being
  executed.

Every value (variable, parameter, intermediate result of a calculation) is typed: one type
byte and 5 bytes of contents: an integer, or a decimal (library `progs/fp_inc.s`, reusable by
other programs). Words and lists are texts stored in a heap (see "Implementation").

## Implementation

Source: `progs/logo.s`, with `progs/fp_inc.s` (decimals and functions) and
`progs/ltxt_inc.s` (words and lists). Tests: `tools/test_logo.sh` (scenarios
`tools/logo_tests/*.log` compared with the `.ref` files, about 20 min) and
`python3 tools/test_fp.py`.

**Values.** 6 bytes: a type (16-bit integer, decimal, text) and 5 bytes. Decimals use the
format of the Oric's BASIC (exponent and 32-bit mantissa, about 9 digits), with routines
written for CP/A. An integer that overflows becomes decimal; a decimal result stays decimal
even if it comes out whole (`0.5 * 4`); primitives that want an integer round. `QUOTIENT`
truncates towards zero, `RESTE` has the sign of the dividend. Measured accuracy: + - * / to
0.5 ulp; RACINE 0.5 ulp, EXP 0.9, LN 1.75, ARCTAN 1.5; SIN in degrees 1.5E-9 (notable angles
exact: `COS 90` = 0). There is no `PUISSANCE` (power): it is written in Logo.

**Value stack.** The evaluator's intermediate values go through a stack of 40 values, not
through the 6502 stack. Together with variables and arguments, it is the root set of the heap
compaction.

**Words and lists.** They are texts in a heap that grows down from `memtop` while procedures
grow up. Compaction in the manner of Microsoft BASIC. Two rules make it safe: a result is
always a copy (never a piece of another text), and only variables, arguments and the value
stack count; a primitive that reserves space first pushes its texts there. A list is stored
normalised (one space between elements, none after `[` or before `]`); a sublist is a group
`[...]`. EXECUTE copies the list into a separate 512-byte stack (`xstack`), which compaction
does not touch.

**Turtle.** Fixed point to 1/256; the heading has a fraction byte (`headf`). Sine table in
65536 × sin (90° handled separately). XCOR, YCOR, CAP: an integer if the turtle is on a whole
point, otherwise rounded to 2 places. `ECRANTEXTE` keeps `memtop` at `$A000`: the picture is
kept and nothing has to move on return.

**RENDS.** A procedure called in an expression goes through `call_func` (context `FR_FUNC`,
nested `run` loop). So that depth is not limited by the 6502 stack, the part of the stack
between `savsp` and the top is copied into `spill` (640 bytes). A function that ends without
RENDS, or RENDS in a procedure called as a statement, is an error. Depth: about forty levels.

**EDITE.** SAUVE, then the state into `LOGO.$$$` (header "LGS1", global variables, heap, zero
page read back last), then CHAIN to `EDIT NAME.LOG /L`. EDIT's Retour chains to
`LOGO NAME.LOG /R`, which reloads the state and the file. Procedures are not in the state; the
execution context is not kept.

**CHARGE.** Accepts a computed name; a CHARGE inside a loaded file is refused (`ldon`,
`Interdit pendant CHARGE :`). A large program is loaded in stages (`CHARGE`, `OUBLIE`): that
is why loadable modules were ruled out.

**Primitive lookup.** The tables `prims` and `funcs` are sorted by first letter; `ix_build`
builds an index from them at start-up (`pix`, 2 × 26 addresses): a new primitive goes into
the group of its letter. The index is built in RAM rather than written as labels, because 40
more labels overflowed ASM's symbol table on `LOGO.ASM`.

**Sound.** The arguments are kept on the 6502 stack until the BDOS call (a function called in
an argument can itself play a sound). ESC and any error do `SILENCE`. `ENSEMBLE`: SYNC 0, the
list in a `FR_ENS` context, SYNC 1 when that context is removed (end, `STOP`, `RENDS`); an
ENSEMBLE inside another is included in the first (`ensd`). `JOUE?` and `ATTENDSSON` only see
timed notes.

**Text screen.** `FIXECURSEUR` writes `CON_CURX`/`CON_CURY` (the displayed cursor is removed
first, interrupts masked). On the mixed screen, only lines 16-26 are allowed. `TOUCHE` works
like GRAPHER's `INKEY` (buffer emptied, new key, otherwise `KB_HELD`).
