# LOGO — reference

> English translation of `docs/logo.md`. On the English disks (`cpa-en.dsk`,
> `cpa-logo-en.dsk`), LOGO speaks English: `FORWARD`, `TO ... END`. On the French disks it
> speaks French (`AVANCE`, `POUR ... FIN`); `LOGOTR` translates a `.LOG` file from one to the
> other (see "Translating a program").

A>LOGO

The turtle draws in the SPLIT mode picture (LOGO switches to it by
itself), and you type commands under the picture, after the `?` prompt. Numbers are integers
or decimals (see below).

| Command | Effect |
|---|---|
| `FORWARD n` / `FD`, `BACK n` / `BK` | forward, back |
| `RIGHT n` / `RT`, `LEFT n` / `LT` | turn right, left (degrees) |
| `PENUP` / `PU`, `PENDOWN` / `PD` | pen up, pen down |
| `PENERASE`, `PENREVERSE` | the pen erases, inverts |
| `HIDETURTLE` / `HT`, `SHOWTURTLE` / `ST` | hide, show the turtle |
| `CLEARSCREEN` / `CS`, `CLEAN`, `HOME` | clear and go back to the centre, clear, go back to the centre |
| `SETHEADING n`, `SETXY x y` | absolute heading, absolute position (centre = 0 0, y upwards) |
| `DOT x y`, `LINE x1 y1 x2 y2` | a point, a line (turtle coordinates) |
| `RECTANGLE x1 y1 x2 y2`, `FILLRECT x1 y1 x2 y2` | rectangle (two opposite corners), filled rectangle |
| `CIRCLE r` | circle of radius r (0 to 127) around the turtle |
| `LABEL x` | writes x (number, word or list, like `PRINT`) in the picture, to the right of the turtle and sitting on its line |
| `SETCOLOR v` | colour of the whole picture: ink 0 to 7 (0 black, 1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white) or paper 16 to 23 |
| `TEXTSCREEN`, `SPLITSCREEN` | switch to the text screen (26 lines, no picture or turtle), back to the picture and the turtle |
| `CLEARTEXT` / `CT` | clear the console (lines 1-27 on the text screen, under the bar on the mixed screen), cursor at the top left |
| `TYPE x` | like `PRINT`, without a new line (games: a score in its place) |
| `SETCURSOR c l` | place the console cursor (for `TYPE`, `PRINT`): column 0-39, line 0-27 of the whole screen (see "Games on the text screen") |
| `SETCELL c l n` | write code n (0-255) into a cell without moving the cursor: character, colour attribute (0-7 ink, 16-23 paper), +128 for reverse video |
| `REPEAT n [ ... ]` | repeat a list |
| `IF condition [ ... ] [ ... ]` | condition, with an optional "else" list |
| `TO NAME :A :B` ... `END` | define a procedure (parameters optional) |
| `STOP` | leave the procedure |
| `OUTPUT x` | leave the procedure returning x: it becomes a function (see below) |
| `MAKE "X n`, `:X` | global variable, value of a variable or a parameter |
| `PRINT n` / `PR`, `PRINT "word`, `PRINT [text]` | print |
| `WAIT n` | wait n fiftieths of a second |
| `READLIST` / `RL` | reads a line from the keyboard and returns it as a list (`MAKE "R READLIST`); the line is turned to upper case |
| `READWORD` | reads a line and returns it as a single word (without leading and trailing blanks) |
| `READCHAR` | waits for a key and returns the character (`ASCII READCHAR` for its code) |
| `KEY?` | 1 if a key has been typed (read it next with `READCHAR`), 0 otherwise; does not wait |
| `KEY` | the key, without waiting and without repeat delay (action games, like `KEY$` in BASIC): the one typed since the last `KEY`, otherwise the one still held down, otherwise the empty word |
| `CURSOR`, `CELL c l` | cursor position `[column line]`; code of the cell (0-255) |
| `ASCII x`, `CHAR n` | code of the first character; character of code n |
| `SAVE "NAME`, `LOAD "NAME` | save the procedures, load a file (`NAME.LOG`: procedures and other lines, executed); the name can be computed (`LOAD :F`, `LOAD WORD "S :N`) and start with a drive (`LOAD "B:GAME`) |
| `EDIT "NAME` | change the procedures with EDIT, then come back (see below) |
| `SAVEPIC "NAME`, `LOADPIC "NAME` | save, load the drawing (`NAME.IMG`, without the turtle) |
| `POTS`, `PRINTOUT "NAME`, `ERASE "NAME`, `ERALL` | list the procedures, show one, forget one, forget all |
| `NOTE v n vol d`, `TONE`, `NOISE`, `ENVELOPE`, `MIX`, `TOGETHER`, `WAITSOUND`, `SILENCE` | sound: see "Sound in LOGO" below |
| `HELP`, `QUIT` / `BYE` | help, back to CP/A (the picture stays) |

**Drawing without the turtle.** `DOT`, `LINE`, `RECTANGLE`, `FILLRECT`, `CIRCLE` and `LABEL`
take turtle coordinates (centre 0 0, y upwards) but do not move it. They follow the pen mode
(`PENERASE`, `PENREVERSE`), even with the pen up, and are clipped at the edges of the picture;
`CIRCLE` and `LABEL` draw nothing if the turtle is outside the picture. `SETCOLOR` sets
the colour at the start of every line of the picture: its first 6 points (column 0) become
the colour, which drawing does not erase. `DOT? x y` returns 1 if the point is lit, 0
otherwise. All of them refuse the text screen (`TEXTSCREEN`).

    CS CIRCLE 40 RECTANGLE -40 -40 40 40 LINE -40 -40 40 40
    LABEL [HELLO] SETCOLOR 3
    IF DOT? 0 0 [PRINT "LIT]

In expressions: `+ - * / ( ) = < >`, as well as `RANDOM n` (random), `HEADING` (heading), `XCOR`,
`YCOR`, `DOT? x y`, `READCHAR`, `KEY?`, `KEY`, `CURSOR`, `CELL c l`, `PLAYING? v`,
`SQRT x` (square root), `SIN x`, `COS x`, `ARCTAN x` (angles in degrees, like the turtle:
`SIN 30` gives 0.5, `ARCTAN 1` gives 45), `LN x`, `EXP x`, `INT x` (integer part, towards
zero), `ROUND x` (nearest integer, 2.5 gives 3), `ABS x`, `QUOTIENT a b` (integer division,
towards zero) and `REMAINDER a b` (remainder, with the sign of `a`). A key typed while a program
runs is kept for `READCHAR` (the last one only); it is forgotten on return to the prompt. ESC
and CTRL-C also interrupt `READCHAR` (so `READCHAR` never returns them).

**Games on the text screen.** `SETCURSOR`, `CURSOR`, `CELL` and `SETCELL` take
whole-screen coordinates, like GRAPHER's LORES: columns 0 to 39 (0 and 1 hold the line's
attributes: `SETCELL 0 5 20` puts line 5 on a blue background), lines 0 to 27 on the text
screen (line 0 is the system bar, redrawn when a menu is opened), 16 to 26 on the mixed screen
(above, the picture; line 27 holds the mode attributes). LOGO keeps its console: `TYPE` and
`PRINT` write at the cursor, wrap at the end of the line and scroll the console after line 27;
for the last cell of the screen, use `SETCELL`. `KEY` reads the keyboard without
waiting and without the repeat delay: an arrow held down moves at every call as soon as it is
pressed, and nothing more once released (`READCHAR` and `KEY?` follow the keyboard repeat).
The arrows return `CHAR 8` (left), `CHAR 9` (right), `CHAR 10` (down), `CHAR 11` (up); with SHIFT,
`CHAR 240` to `CHAR 243`, with CTRL `CHAR 244` to `CHAR 247` (same order). Example on
`cpa-logo-en.dsk`: `LOGO ARROWS.LOG` (an `@` moved inside a frame, the walls read with
`CELL`).

    MAKE "K KEY
    IF EMPTY? :K [STOP]
    IF :K = CHAR 9 [MAKE "X :X + 1]
    IF (CELL :X :Y) = 32 [SETCELL :X :Y 64]

**Sound in LOGO.** The three voices of the AY (0, 1, 2) play while the program goes on; each
duration is in fiftieths of a second (0 to 255; 0: the note holds until the next one on the
voice, or until `SILENCE`). A value out of range gives `Value out of range :` followed by the
command. ESC and any error cut the sound.

| Primitive | Effect |
|---|---|
| `NOTE v n vol d` | note n on voice v: 1 to 96, 37 = middle C, 46 = A 440 Hz (n = 12 × (octave − 1) + semitone + 1, C = 0), 0 = silence for d; volume 0 to 15, 16 = the voice follows the envelope |
| `TONE v p vol d` | tone of raw period p (0 to 4095): frequency = 62,500 / p Hz (p = 142: A 440 Hz) |
| `NOISE v p vol d` | noise on voice v, period p (0 to 31; the noise generator is shared by the three voices) |
| `ENVELOPE f p` | shape f (0 to 15, those of the AY: 0 decay, 4 attack, 8 sawtooth, 10 triangle...), period p (0 to 65535, in 256 µs units); one envelope for all the voices at volume 16 |
| `MIX v s b` | tone (s) and noise (b) of voice v, 1 = on, 0 = off, both possible at once; give it after `NOTE`, `TONE` or `NOISE`, which set it |
| `TOGETHER [ ... ]` | the voices set in the list all start at the same instant at the end of the list (chord, common attack); also after a `STOP` or an `OUTPUT` in the list |
| `WAITSOUND v` | waits for the end of voice v, or of all of them with 255; ESC interrupts |
| `PLAYING? v` | 1 if voice v (255: any of the three) is still playing, 0 otherwise; an endless note (duration 0) does not count |
| `SILENCE` | stops the three voices |

    NOTE 0 37 12 20 WAITSOUND 0
    REPEAT 2 [NOTE 0 37 12 20 WAITSOUND 0 NOTE 0 41 12 20 WAITSOUND 0]
    ENVELOPE 0 2000
    TOGETHER [NOTE 0 37 16 100 NOTE 1 41 16 100 NOTE 2 44 16 100]
    NOISE 0 20 15 50 MIX 0 1 1

The C major chord starts at once and fades with the envelope; the last line mixes a note and
noise on voice 0.

**Numbers.** Decimals are written with a point: `3.14`, `0.5`, `1.5E-7`, `6E23`. They are
"Oric style": 5 bytes, about 9 significant digits, from about 1E-38 to 1E38. A calculation
between integers stays an integer as long as it fits between -32768 and 32767; otherwise it
becomes decimal (`32767 + 1` gives 32768, `1000 * 1000` gives 1000000). `/` is a true
division: `7 / 2` gives 3.5, `6 / 3` gives 2. `PRINT` prints at most 9 digits, without useless
zeros, in E notation above 999999999 or below 0.00001. Commands that expect an integer
(`REPEAT`, `NOTE`, `WAIT`...) round to the nearest (`REPEAT 2.6` repeats 3 times); beyond
32767: `Number too big`. `IF` is true for any non-zero number.

**Words and lists.** `"HELLO` is a word (it runs up to the next blank or bracket: `"-3.5`
too), `[ONE TWO [THREE]]` a list; both can be stored in variables (`MAKE "L [A B C]`) and
passed to procedures. Functions:

| Function | Result |
|---|---|
| `FIRST x`, `LAST x` | first, last element (or character of a word) |
| `BUTFIRST x` / `BF`, `BUTLAST x` / `BL` | all but the first, all but the last |
| `ITEM n x`, `COUNT x` | n-th element; number of elements (or characters) |
| `WORD a b` | word made of a then b (`WORD "SUN "DAY`) |
| `SENTENCE a b` / `SE` | list of the elements of a then of b |
| `LIST a b` | list of two elements (a list stays a sublist) |
| `EMPTY? x`, `WORD? x`, `LIST? x`, `NUMBER? x`, `MEMBER? a b` | 1 or 0 (empty, word, list, number, member) |

`RUN [PRINT 5 FD 10]` runs a list. A word that looks like a number counts as
that number (`"12 + 1` gives 13), and a number becomes a word where one is needed (`COUNT
12345` gives 5). `=` also compares words and lists. `LIST a b` makes a list; `PRINTOUT "NAME` (`PO`) shows a
procedure (both are `LISTE` in French). Words and lists take
the top of free memory, procedures the bottom; when space runs short, LOGO reclaims the space
of texts no longer in use.

**User functions.** A procedure that ends with `OUTPUT x` can be used in an expression, like
`SQRT`:

    TO FACT :N
    IF :N < 2 [OUTPUT 1]
    OUTPUT :N * FACT :N - 1
    END
    ? PRINT FACT 10
    3628800

It can return a number, a word or a list, call itself and be an argument of another one
(`PRINT SUM SQUARE 3 SQUARE 4`). A function that reaches `END` (or `STOP`) without `OUTPUT`
gives `No output from NAME`; a procedure called as a command must not use `OUTPUT` (`What to
do with the output of NAME`). Self-calling functions go down to about forty levels (`Too many
levels` beyond); procedures called as commands can call themselves much deeper.

**The turtle and decimals.** `FD`, `BK`, `RT`, `LT`, `SETHEADING` and `SETXY` accept decimals:
position and heading are kept to 1/256 (of a step or a degree), and the sine, read from a
table to 1/65536, is interpolated between two degrees. `REPEAT 7 [FD 30 RT 360 / 7]` closes,
`RT 0.5` turns half a degree. `XCOR`, `YCOR` and `HEADING` return an integer when the turtle is on
a whole point, otherwise a decimal rounded to 2 places (`SETHEADING 30 FD 100` gives `86.6` for
`YCOR`). A position beyond -32768..32767 gives `Number too big`.

**Changing procedures with EDIT.** `EDIT "NAME` (File menu, "Edit...") saves all the
procedures to `NAME.LOG` and opens that file in EDIT. EDIT's File menu then offers Back: the file is saved if it changed, LOGO comes back with its variables, its words and
lists, the turtle, the drawing and the screen mode, and loads `NAME.LOG` again (the
procedures are those of the file). LOGO's state goes through the file `LOGO.$$$`, erased on
return. A running program stops. You can also start `LOGO NAME`, which loads `NAME.LOG` right
away. Going from one program to the other uses BDOS function 47 (see "Calling the BDOS"
(`manuel.md`)).

**Text screen.** For a program that only writes text (decimal calculations, words and lists),
`TEXTSCREEN` (Turtle menu, "Text screen") gives the whole screen to text: 26 lines instead of
10. The picture stays in memory: `SPLITSCREEN` brings it back, with the turtle where it was. On
the text screen, the commands that move the turtle or touch the picture (`FD`, `BK`, `RT`,
`LT`, `SETHEADING`, `SETXY`, `HOME`, `CS`, `CLEAN`, `SAVEPIC`, `LOADPIC`) give
`Not on the text screen : FD`; `PU`, `PD`, `PENERASE`,
`PENREVERSE`, `HT`, `ST` remain allowed (they are used on the way back), and `XCOR`, `YCOR`, `HEADING`
always answer. The space for procedures and texts does not change.

`-5` stuck after a blank is a negative number (`SETXY -50 -30`), whereas `3 - 2` is a
subtraction. ESC or CTRL-C interrupts a program (you stay in LOGO, procedures and variables
kept); at the `?` prompt, CTRL-C does nothing. The menu bar (File, Turtle, Help) types the
commands for the user.

Procedures are saved as text (`TO` ... `END`), which can be changed with `EDIT DEMO.LOG`.
`LOAD` also runs the other lines of the file. A file line is at most 126 characters, as on
the keyboard: beyond that, `LOAD` stops on `Line over 126 chars : L 12` (the number is
that of EDIT's status line, which flags these lines: see `EDIT.CFG`); a long list is built
over several lines (`MAKE "L SE :L [...]`). The disk contains `DEMO.LOG`, with SQUARE, POLY,
STAR, FLOWER, SPIRAL, TREE (recursive) and DEMO:

    ? LOAD "DEMO
    ? DEMO

The LOGO disk (`cpa-logo-en.dsk`) adds examples by Pierre, which start by themselves with `LOGO
NAME`: `ELIZA` (the "doctor", a conversation in English; `GOODBYE` to leave), and three curve
plotters on axes: `PLOTSQR` (x²), `PLOTSIN` (sine), `PLOTSINX` (x sin x). `ELIZA2` gives the
same answers, but its searches are recursive functions (`OUTPUT`) that stop as soon as they
find, and a word missing from the table is ruled out with a single `MEMBER?` instead of an
80-turn loop that copies the table: an answer takes 1 to 2 s instead of 15 to 30. Comparing
the two is a good Logo lesson on the Oric: a `REPEAT` that goes on after finding, and `BF` on
a long list (a copy at every step), are expensive.

The Logo reads the text of the procedures directly; primitive names are found through an
index by first letter, built at start-up. Lists and calls go through a context stack in
memory, not through the 6502 stack. Recursion can therefore go down to 120 levels, with 100
active parameters and 32 global variables.

**A large program in stages.** A `.LOG` file can hold any Logo lines, not only procedures:
`LOAD` runs them all, as if they were typed. And `ERASE "NAME` really gives back the
procedure's space. A program too large for memory (an adventure game, for instance) is
therefore split into stages: a kernel loaded once, then, at each stage, the file of that
stage, forgotten when it is left. Global variables carry over from one stage to the next.
Example (tried): `KERNEL.LOG` contains

    TO GAME
    MAKE "N 1
    REPEAT 3 [STAGE]
    PRINT "END
    END
    TO STAGE
    LOAD WORD "S :N
    ROOM
    ERASE "ROOM
    END

and `S1.LOG`, `S2.LOG`, `S3.LOG` each define a procedure `ROOM`, which plays the stage and
chooses the next one (`MAKE "N 2`). Start `LOGO KERNEL`, then `GAME`. The name given to
`LOAD` (as to `SAVE`, `SAVEPIC`, `LOADPIC` and `EDIT`) can be computed: `"S1`, `:F`,
`WORD "S :N`... A stage file can load its picture (`LOADPIC "ROOM1`). Two rules:

- No `LOAD`, `SAVE` or `EDIT` during a `LOAD` (in the loaded file, or in a procedure it
  calls): they would take the file being read. LOGO refuses it (`Not allowed during LOAD :
  LOAD`) and goes back to the prompt. The kernel chains the loads,
  once each file is finished.
- The kernel, loaded first and never forgotten, loads and forgets the stages. Forgetting the
  running procedure, or a procedure loaded before it, would move in memory the text being
  executed.

Every value (variable, parameter, intermediate result of a calculation) is typed: one type
byte and 5 bytes of contents: an integer, or a decimal (library `progs/fp_inc.s`, reusable by
other programs). Words and lists are texts stored in a heap (see "Implementation").

## Translating a program (LOGOTR)

    A>LOGOTR GAME          GAME.LOG into English, the original kept as GAME.BAK
    A>LOGOTR GAME JEU /FR  GAME.LOG into French, in JEU.LOG

`LOGOTR NAME [DEST] [/EN|/FR]` translates the primitives of `NAME.LOG`: into English with
`/EN` (the default on the English disks), into French with `/FR` (the default on the French
disks). Without `DEST`, the file is replaced and the original kept as `NAME.BAK`; the
translation is written to `NAME.$$$` first, so nothing is lost if the disk is full. It
reports the number of words translated and the warnings, with their line number.

Only the primitives are translated: the user's names (procedures, variables, quoted words)
stay as they are, and so does everything that is data. In Logo, code and data look the same
(`[FD 10]` can be run or printed): LOGOTR translates the lists that are instruction lists of
`REPEAT`, `IF`, `RUN` and `TOGETHER`, and copies the other lists as they are. Two warnings:

- `data list ? FD`: a data list that starts with a primitive name; it may be run later
  (`MAKE "L [FD 10]` then `RUN :L`): check it and translate it by hand if needed. A sentence
  printed by the program can also trigger it (`PRINT [SILENCE IS...]`): nothing to do.
- `primitive name : STEP`: a user's name that is a primitive in the target language;
  rename the procedure, or LOGO would take it for the primitive.

No warning: a quoted word that the program turns into code (`RUN LIST "PRINT 9`) stays as it
is; translate it by hand.

An abbreviation becomes the other language's abbreviation when there is one (`FD` / `AV`),
otherwise the long name (`RUN` gives `EXECUTE`). In French, `LISTE` is both a command (show a
procedure) and a function (make a list): it becomes `PRINTOUT` at the start of an instruction
before a quoted word, otherwise `LIST`. Translated there and back, the examples and test
scenarios come back unchanged (apart from those abbreviations).

## Implementation

Source: `progs/logo.s`, with `progs/fp_inc.s` (decimals and functions) and
`progs/ltxt_inc.s` (words and lists). Tests: `tools/test_logo.sh` (scenarios
`tools/logo_tests/*.log` compared with the `.ref` files, about 20 min; `LANGUE=en`: English
LOGO, scenarios translated by LOGOTR, references in `tools/logo_tests/en`) and
`python3 tools/test_fp.py`.

**Vocabulary.** `tools/gen_logo_voc.py` holds the only table of primitives: each one has a
number (its rank: the token of a future in-memory tokenisation), its routine and its names in
French and in English (long name first, then abbreviations). It writes the `prims` and
`funcs` tables of each language (`progs/msg/fr/logovoc.msg`, `progs/msg/en/logovoc.msg`), the
words `TO` / `END`, the commands typed by the menus, and the numbered table of LOGOTR
(`progs/lgtr_tab.s`). The messages, menus and `HELP` text are in `logo.msg`. `END` has three
letters in both languages: a stored procedure ends with that word (`w_fin`).

**Values.** 6 bytes: a type (16-bit integer, decimal, text) and 5 bytes. Decimals use the
format of the Oric's BASIC (exponent and 32-bit mantissa, about 9 digits), with routines
written for CP/A. An integer that overflows becomes decimal; a decimal result stays decimal
even if it comes out whole (`0.5 * 4`); primitives that want an integer round. `QUOTIENT`
truncates towards zero, `REMAINDER` has the sign of the dividend. Measured accuracy: + - * / to
0.5 ulp; SQRT 0.5 ulp, EXP 0.9, LN 1.75, ARCTAN 1.5; SIN in degrees 1.5E-9 (notable angles
exact: `COS 90` = 0). There is no `POWER`: it is written in Logo.

**Value stack.** The evaluator's intermediate values go through a stack of 40 values, not
through the 6502 stack. Together with variables and arguments, it is the root set of the heap
compaction.

**Words and lists.** They are texts in a heap that grows down from `memtop` while procedures
grow up. Compaction in the manner of Microsoft BASIC. Two rules make it safe: a result is
always a copy (never a piece of another text), and only variables, arguments and the value
stack count; a primitive that reserves space first pushes its texts there. A list is stored
normalised (one space between elements, none after `[` or before `]`); a sublist is a group
`[...]`. RUN copies the list into a separate 512-byte stack (`xstack`), which compaction
does not touch.

**Turtle.** Fixed point to 1/256; the heading has a fraction byte (`headf`). Sine table in
65536 × sin (90° handled separately). XCOR, YCOR, HEADING: an integer if the turtle is on a whole
point, otherwise rounded to 2 places. `TEXTSCREEN` keeps `memtop` at `$A000`: the picture is
kept and nothing has to move on return.

**OUTPUT.** A procedure called in an expression goes through `call_func` (context `FR_FUNC`,
nested `run` loop). So that depth is not limited by the 6502 stack, the part of the stack
between `savsp` and the top is copied into `spill` (640 bytes). A function that ends without
OUTPUT, or OUTPUT in a procedure called as a statement, is an error. Depth: about forty levels.

**EDIT.** SAVE, then the state into `LOGO.$$$` (header "LGS1", global variables, heap, zero
page read back last), then CHAIN to `EDIT NAME.LOG /L`. EDIT's Back chains to
`LOGO NAME.LOG /R`, which reloads the state and the file. Procedures are not in the state; the
execution context is not kept.

**LOAD.** Accepts a computed name; a LOAD inside a loaded file is refused (`ldon`,
`Not allowed during LOAD :`). A large program is loaded in stages (`LOAD`, `ERASE`): that
is why loadable modules were ruled out.

**Primitive lookup.** The tables `prims` and `funcs` are sorted by first letter; `ix_build`
builds an index from them at start-up (`pix`, 2 × 26 addresses): a new primitive goes into
the group of its letter. The index is built in RAM rather than written as labels, because 40
more labels overflowed ASM's symbol table on `LOGO.ASM`.

**Sound.** The arguments are kept on the 6502 stack until the BDOS call (a function called in
an argument can itself play a sound). ESC and any error do `SILENCE`. `TOGETHER`: SYNC 0, the
list in a `FR_ENS` context, SYNC 1 when that context is removed (end, `STOP`, `OUTPUT`); a
TOGETHER inside another is included in the first (`ensd`). `PLAYING?` and `WAITSOUND` only see
timed notes.

**Text screen.** `SETCURSOR` writes `CON_CURX`/`CON_CURY` (the displayed cursor is removed
first, interrupts masked). On the mixed screen, only lines 16-26 are allowed. `KEY` works
like GRAPHER's `INKEY` (buffer emptied, new key, otherwise `KB_HELD`).
