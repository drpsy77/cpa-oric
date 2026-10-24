# CP/A — manual

> English translation of `docs/manuel.md`. Messages, questions, menus and screens are those
> of the English disks (`cpa-en.dsk`...); on the French disks (`cpa.dsk`...) they are in
> French (`docs/manuel.md`).

User guide for the disk version: commands, programs, programming. GRAPHER and LOGO have their
own reference (`grapher.md`, `logo.md`), and so do CMDER and EDSPRITE (`cmder.md`,
`edsprite.md`). Interface contract
(BIOS table, BDOS functions, memory map): `docs/architecture.md` (in French). On the Oric,
`HELP` gives a summary of each command.

## CCP commands

| Command | Effect |
|---|---|
| `DIR [afn]` | lists the files (wildcards `*` and `?`) and the free space; SYS files are hidden |
| `DIRS [afn]` | like DIR, SYS files included |
| `TYPE file` | shows a text file (a key interrupts it) — TYPE.COM |
| `ERA afn [/Q]` | erases: shows the target files and asks `Erase n file(s) (Y/N) ?` (read-only files are kept); `/Q` without asking, for a script — ERA.COM |
| `REN old new` | renames — REN.COM; also `REN new=old`, the CP/M order |
| `SAVE n file` | saves n pages of 256 bytes from `$0500` |
| `GSAVE file`, `GLOAD file` | saves / loads the SPLIT mode picture (type `.IMG` by default) |
| `PUT file command [parameters]` | runs the command, copying everything it displays into the file |
| `DO file [p1 ... p9]` | runs the commands of `FILE.BAT`, one per line |
| `ECHO text`, `PAUSE [text]` | displays a text; waits for a key (for scripts) |
| `SPLIT`, `TEXT`, `GCLS` | SPLIT mode (picture and text), text mode, clear the picture |
| `NAME [args]` | loads `NAME.COM` at `$0500` and runs it; failing that, runs the script `NAME.BAT` (like `DO NAME [args]`) |
| `VER`, `CLS` | version, clear the screen |
| `PAPER n`, `INK n` | background, ink colour (0 black, 1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white) of the whole console; the same colour for both is allowed (hidden text) |
| `PAGE ON`, `PAGE OFF` | pause at the end of each screen, or not (see below) |
| `B:` (`A:` to `D:`) | changes the current drive (disk version); the prompt becomes `B>` |

TYPE, ERA and REN are programs (`.COM`), to save resident space. The drawing commands
(`PLOT`, `LINE`, `BOX`, `FBOX`, `CIRCLE`, `GTEXT`, `ATTR`, `PEN`) are in `GRAPHER.COM`
(`grapher.md`); the ROM version keeps them at the prompt. A `.COM` is typed like a built-in
command, including in scripts and after PUT; it is searched for on the other drives if it is
not on the current one (see "Drives A: to D:").

Transient commands (`.COM` files on the disk) that complete the CCP:

| Command | Effect |
|---|---|
| `HELP [topic]` | help: built-in commands, then `HELP EDIT`, `HELP HEX`, `HELP LOGO`, `HELP ASM`, `HELP DEBUG`, `HELP MEMORY` (memory map), `HELP KEYS`, `HELP PROG`, `HELP CMDER`, `HELP USB`, `HELP GRAPHER`, `HELP EDSPRITE`; on `cpa.dsk`, in French (`HELP TOUCHES`, `HELP MEMOIRE`...) |
| `CMDER [d:][afn]` | full-screen file manager: list you can sort and filter, marking, View, Copy, Move, Rename, Erase, Attributes; copying with a single drive (`cmder.md`) |
| `SET afn [RO\|RW\|SYS\|DIR]` | file attributes (no option: shows them) |
| `STAT [d:][afn]` | size of each file: 128-byte records, 2 KB blocks, bytes, attributes (`R` read-only, `S` system); no parameter: free space on the disk |
| `MEM` | memory map (size of the TPA in text or SPLIT mode) |
| `POKE adr bb [bb...]` | writes bytes into memory (hexadecimal, `$` optional) |
| `GO adr [parameters]` | runs the code at `adr` like a `.COM` (an `RTS` returns to the prompt) |
| `XDO NAME [p1 ... p9]` | a script called by a script; started by the CCP, not to be typed (see DO) |

In the disk version, `HELP`, `MEM`, `POKE` and `GO` are `.COM` files and DEBUG replaces `DUMP`,
to leave room for the BDOS; the ROM version, with no disk, has them built in.

Other programs on the disk:
- `HELLO.COM` displays its arguments;
- `COPY.COM src [dst]` copies files (wildcards allowed), in large blocks, through the BDOS.
- `EDIT.COM [file]`, the text editor (below).
- `GTEST.COM`, the test of SPLIT mode and the graphics primitives.
- `LOGO.COM`, with `DEMO.LOG`; `LOGOTR.COM`, the `.LOG` translator (`logo.md`).
- `HEX.COM file`, the hex editor described below.
- `EDSPRITE.COM [NAME]`, the full-screen editor for GRAPHER's `.SPR` sprites and characters
  (`edsprite.md`).
- `GRAPHER.COM NAME`, the small drawing language of `.GRX` files (run), and `GRXASM.COM NAME`
  (or `GRAPHER NAME /A`), which translates it into assembly (copying the useful routines of
  `GRX.INC`, `HIRES.INC`...), with its examples (`grapher.md` § 14), and `VOIR.COM NAME`,
  which shows a picture (see "Full-screen HIRES" below).
- `ASM.COM NAME`, the 6502 assembler, with the example sources `HELLO.ASM`, `GTEST.ASM`,
  `CPA.INC` and `HIRES.INC`.
- `DEBUG.COM NAME`, the monitor, disassembler and single-stepper.
- `STAT.COM`, `MEM.COM`, `POKE.COM`, `GO.COM`, `XDO.COM`, described above.
- `EXPORT.COM`, `IMPORT.COM`, `USBDIR.COM`: file exchange with the LOCI's USB stick.
- `MKTAP.COM NAME file adr [/R]...`: `.TAP` file for the Oric under BASIC (see "Publishing for
  the Oric under BASIC").
- `TERM.COM [/E] [/L]`: serial terminal, for the LOCI's WiFi modem (see "Serial terminal").
- `FORMAT.COM X: [/Q]`: formats a disk (see "Drives A: to D:").
- `DISKCOPY.COM src: dst: [/T] [/V] [/S]`: copies a disk, or its system.

**POKE and GO in the disk version.** Like any `.COM`, they are loaded at `$0500`: each fits in
one page (`$0500-$05FF`), so everything from `$0600` on is preserved from one call to the next.
A small program typed with several POKEs therefore starts at `$0600`:

    A>POKE 0600 A9 41 A2 02 20 03 02 60
    A>GO 0600
    A

A single POKE can also write at `$0500` (for a `SAVE` right after): it first decodes all the
bytes, then copies them from the zero page (`$D0-$DD`), over itself. The next POKE would
overwrite these bytes as it loads. `GO adr NAME.EXT` passes the rest of the line to the code it
starts: parameter line at `$0480` and FCB1 filled with the first parameter (FCB2 empty, as
under DEBUG).

**File size (STAT).** The CP/M directory only counts 128-byte records. STAT reads the last one
and removes the `^Z` (`$1A`) that pad it, as EDIT, PUT, LOGO and the PC tool `mkdisk.py` do:
the size in bytes is exact for those files. A binary file whose last bytes really are `$1A`
looks slightly shorter.

    A>STAT *.TXT
    File          Recs   Blks  Bytes  At
    README  .TXT     79      5  10054 R
    1 file(s), R : 1, S : 0

The `At` column gives the attributes: `R` for a read-only (R/O) file, `S` for a system file
(hidden from DIR). The last line counts the files, the read-only ones and the hidden ones.

**128 files per disk.** The directory (the table of files that `DIR` lists; not a folder:
CP/A has none) has 128 entries, one per file whatever its size up to 32 KB (beyond that, one
more entry per 32 KB). A disk therefore holds 128 files at most, even with room left: EDIT,
HEX, CMDER, EDSPRITE and GRAPHER then answer `Directory full`, and nothing is written.
Erase unneeded files (`ERA`) or use another disk.

## Drives A: to D:

Any file name can start with a drive: `DIR B:`, `TYPE B:LETTRE.TXT`, `COPY LETTRE.TXT B:`,
`ERA B:*.BAK`, `STAT B:`, `EDIT B:NOTES.TXT`, `ASM B:PROG` (the `.COM` and the `.SYM` on the
source's drive; the `#include`s are looked for there, then on A: to D:), and in LOGO `LOAD "B:GAME`. Without a drive, it is the
current drive, chosen with `B:` at the prompt or with the **Next drive** item
of the System menu (A, B, C, D, then A). A program (`.COM`) or a script (`.BAT`, also through
`DO`) typed without a drive is searched for on the current drive, then on `A:`, then on those
of drives `B:`, `C:` and `D:` already read since power-on (`DIR B:`, `B:`, a copy...): from
`B>`, `EDIT`, `LOGO` or `STAT` start from the system disk. With a real Microdisc, an empty or
missing drive costs several seconds: an unknown command (a typo) would take about 16 s if the
search tried drives never read; so it answers in about 2 s. A disk just inserted in `B:` is
read first (`DIR B:`), and its programs are found after that. With the LOCI, which tells which
drives have an image, all of those are searched, read or not. In a script, the search starts
with the script's drive: a script and its programs stored on the same disk are found,
whatever drive it is in (then `A:`, then the others). A drive that does not answer is then
skipped by this search, until it is read again (`C:`, `DIR C:`...). A name typed with its
drive (`C:PROG`) is only searched for there. Limit: the end of a script that called another
one is read from `$$$.BAT`, written on the current drive; that drive then comes first.

Every drive has the same disk layout. A data disk (without the system) is prepared on the
Oric with `FORMAT B:`, or on the PC: `python3 tools/mkdisk.py new data.dsk [files...]`; the
system tracks stay unused there (336 KB for files). On the LOCI, mount the image on drive B, C
or D.

On the LOCI, a drive without an image is refused straight away (`BDOS: disk I/O error` if it is
typed, nothing during the program search): the LOCI's controller never completes a command
sent to such a drive, and does not answer any more until it restarts. So, before switching to
another drive, CP/A reads the list of mounted drives kept by the LOCI's menu. An image mounted
or ejected is taken into account at the next start from the LOCI's menu.

**FORMAT.** `FORMAT B:` formats the disk in drive B: in CP/A's format (2 sides, 42 tracks, 17
sectors of 256 bytes): each track is written in one go (the controller's Write Track
command), then read back; progress is shown (`Track 12 side 1`), ESC
interrupts between two tracks. Confirmation is asked (`All of B: will be erased. Go on (Y/N) ?`). `FORMAT A:` works with a single drive: it asks you to
insert the disk to format, then to put the system disk back (the system stays in memory).
`FORMAT B: /Q` only empties the directory of a disk already formatted: it is instant, and
enough for a LOCI or Oricutron image. Sectors are interleaved (1, 10, 2, 11...) so that a real
Microdisc drive reads a track in two revolutions instead of seventeen; the images made by
`mkdisk.py` (`build/*.dsk`) are interleaved the same way. Measured in Clock Signal, which
simulates rotation: copying LOGO.COM takes about 12 s instead of about 50 s, and booting about
7 s instead of about 9 s. It changes nothing on the LOCI or in Oricutron.

**DISKCOPY.** `DISKCOPY A: B:` copies the disk in A: onto the one in B: (already formatted):
boot and system, directory, then only the blocks used by files; `/T` copies all 1,428 sectors,
`/V` reads back and compares each sector written. The copy is done in slices of about 165
sectors (the TPA), with progress shown (`Tranche 2 : ecriture`, slice 2: writing); ESC stops
between two slices. `DISKCOPY A: A:` works with a single drive: source and destination are
asked for in turn, once per slice (4 swaps for the system disk, 9 with `/T`).

`DISKCOPY A: B: /S` makes the disk in B: bootable **without touching its files**, like SYSGEN
under CP/M: it only copies the boot and the system (sectors 0 to 67, outside the file area).
The commands are then copied with COPY, as with PIP:

    A>DISKCOPY A: B: /S
    A>COPY *.COM B:

`DISKCOPY A: A: /S` also works with a single drive.

**COPY** copies one or more files, wildcards allowed, like PIP: `COPY LETTRE.TXT LETTRE.BAK`,
`COPY *.COM B:` (drive only: same names), `COPY *.TXT *.BAK` (a `?` in the pattern takes the
source's character), `COPY B:*.LOG` (no destination: the current drive). Each file copied is
named, then the number of copies. Attributes are not copied (like PIP): the copy of a
read-only command can be changed. A read-only destination file is left alone (`: file
protected`), a file onto itself refused (`: same file`); other files with the same
name are replaced. ESC stops between two files. COPY respects the top of the TPA (it also
works in SPLIT mode). With a single drive, to copy from one disk to another: CMDER.

**CMDER** (as in "commander") shows the files of a disk in full screen and acts on them:
`CMDER`, `CMDER B:`, `CMDER B:*.COM` (drive and filter). Each line gives the name, the type, the
size in bytes, `R` (read-only) and `S` (system), the rank in the directory (`N`, the order of
DIR) and a kind (Prog, Source, Texte, Image...); at the bottom, the file under the cursor or
the total of the marked files. Up and down arrows: file; left and right: page; `<` `>`: first,
last; a letter: next file starting with it. `SPACE` marks, `+` / `-` mark or unmark by pattern,
`*` inverts; `1` to `4` sort by disk order, name, type, size (the same key reverses the order);
`/` filters (`B:*.TXT` also changes drive). Operations apply to the marked files, or to the
one under the cursor: RETURN shows them (text, page by page), `^C` copies, `^X` moves, `^N`
renames, DEL erases (after confirmation), `^A` changes the attributes, `?` gives the exact
size of the file and `^E` that of all (STAT's rule), `^L` changes drive, `^R` reads again
(disk changed), ESC or `^Q` quits. The same actions are in the menus (FUNCT) File, Mark,
Sort and View. A copy keeps the original's attributes; a file already there is replaced after
agreement (`Y/N/A`, A for all), a read-only destination file is left alone; disk full: the copy
in progress is erased.

The column titles and the two status lines are in colour (cyan, blue); the list and the help
line keep the colours chosen with PAPER and INK. In column 39, a scroll bar shows the visible
part of the list. A disk error is shown on line 26 (`Disk error : check the disk`)
instead of the BDOS message in the middle of the screen.

**Two panels**: `CMDER A: B:` (one filter per drive: `CMDER A:*.COM B:`) shows two disks side
by side (name, type, size in KB); the header of the active panel is in reverse video. `^I` goes
to the other panel, `^W` swaps their places, `^Z` puts the active panel in full screen (and
back). Copy proposes the drive of the other panel (RETURN is enough) and checks the space first
(`Free 14K, needed 18K : Y/N ?`). View menu, "Not on other": the panel
only shows the files missing from the other, or present with another size or other attributes
(`#` in the header); with "All" then `^C`, you copy what is missing. File menu,
"Print list": the list of the active panel on the printer.

**The LOCI's USB stick**: `CMDER USB:` (or `CMDER USB:/GAMES`, `CMDER A: USB:`) shows the
current directory of the stick (`USB:GAMES/`): folders first (`<DIR>`), long names (in full up
to 26 characters in full screen). RETURN enters a folder, or goes up on `..`; on a file, it
shows it. The stick is a gateway: you copy to it (Copy to `USB:`, or to the stick's panel) and
from it, but you neither erase nor rename anything on it. From the stick, a long name is
brought down to 8 + 3 (like IMPORT); `/T` at the end of the answer (or the "Copy as text..."
menu item) turns a lone LF into CR LF and a tab into a space. Towards the stick, the trailing
`^Z`s are removed (like EXPORT) and a `.DSK` is refused.

Copying to the list's drive without changing the name (`A:` when the list is that of A:) means
**a single drive**: CMDER reads as many files as memory holds (about 33 KB), asks
`DESTINATION in A:, press a key`, writes, then `SOURCE in A:`
for the rest, and so on. Before writing, it checks a fingerprint of each disk's directory and
refuses the wrong one (`No ! DESTINATION in A:...`); a large file is closed before each swap,
then resumed. A disk with the same directory as the source (a copy of the source, an older
version) is accepted after `Same as the source : go on (Y/N) ?`; you must then take care to put back the right one yourself. At the end of a copy,
`SOURCE in A:, press a key (ESC : stay)`: ESC leaves the destination in the drive and the list shows it.
ESC at any other prompt stops everything. Moving with a single drive erases the originals
when the source comes back.

As under CP/M, a drive's directory is read at its first use, and read again after a warm start
(CTRL-C at the start of a line, or the end of a program): after changing disks, press CTRL-C
before writing to it. The current drive is kept across a warm start (back to `A:` if it no
longer answers). An empty or missing drive does not lock up the Oric: after less than a
second, `BDOS: disk I/O error`, and `B:` answers `B:?` without changing drive. A DO script
keeps reading from its own disk even if it changes drive.

**File attributes.** As under CP/M 2.2, two bits of the file name are used as attributes: R/O
(read-only: the file can be neither erased, nor renamed, nor written, nor replaced) and SYS
(system file: `DIR` does not show it, `DIRS` does; it remains usable). `SET HELP.COM RO SYS`
protects and hides, `SET HELP.COM RW DIR` goes back. ERA keeps read-only files (and counts
them), REN answers `File protected`; EDIT and HEX refuse to save a read-only
file, COPY and IMPORT answer `file protected`. Programs go through BDOS function 30 (bit 7 of
byte 9 of the FCB = R/O, of byte 10 = SYS). `STAT *.*` shows the attributes of all files.

On the disk provided, the commands and applications (COPY, STAT, HELP, EDIT, LOGO, ASM...),
README.TXT, CPA.INC, HIRES.INC, GRX.INC, ANIM.INC, ARR.INC, FIL.INC and SPR.INC are
**read-only** (R/O) and stay **visible** in DIR, as on a CP/M disk: an `ERA *.*` or a name
completed with ESC can no longer erase them. To replace a command with a new version:
`SET COPY.COM RW`, then copy it. The examples (HELLO, GTEST and their `.ASM`, DEMO.LOG, the
`.GRX` files, HERO.SPR, TILES.SPR) stay changeable: `ASM HELLO` rewrites HELLO.COM. No file is hidden
(SYS): the attribute stays at the user's disposal.

SYS does not change the name: `HELP.COM` marked SYS stays `HELP.COM` and still runs (a file
renamed `.SYS` would no longer be a command: the CCP only starts `.COM` and `.BAT` files).

**Disks by use.** `build.sh` also makes four bootable disks, lighter to look at. On each one,
the basic commands (TYPE, ERA, REN, SET, STAT, COPY, HELP, FORMAT, DISKCOPY, XDO, EXPORT,
IMPORT, USBDIR, VOIR, CMDER) are read-only and **hidden** (SYS): `DIR` only shows the disk's
tool and the working files, `DIRS` shows everything. EDIT is on every disk, read-only and
visible.

| Image | Visible (read-only) | Also, hidden | Changeable examples |
|---|---|---|---|
| `build/cpa-logo-en.dsk` | EDIT, LOGO, GRAPHER, EDSPRITE | | DEMO.LOG, ELIZA.LOG, ELIZA2.LOG, PLOTSQR.LOG, PLOTSIN.LOG, PLOTSINX.LOG, DRAWING.GRX, TITLE.GRX, PATTERNS.GRX, SKETCH.GRX, ARROWS.GRX, ARROWS.LOG, SNAKE.GRX, SCORES.GRX, SPRITES.GRX, HERO.SPR, MAP.GRX, TILES.SPR, ROAD.GRX, ROTSCROL.GRX, PUZZLE.GRX |
| `build/cpa-notes-en.dsk` | EDIT | | |
| `build/cpa-asm-en.dsk` | EDIT, ASM, DEBUG, HEX, GRAPHER, GRXASM, EDSPRITE, MKTAP, CPA.INC, HIRES.INC, GRX.INC, ANIM.INC, ARR.INC, FIL.INC, SPR.INC | MEM, POKE, GO | HELLO, GTEST (`.ASM`, `.COM`) |
| `build/cpa-anim-en.dsk` | EDIT, VOIR, VSYNC, GRAPHER, GRXASM, ASM, EDSPRITE, MKTAP | CPA.INC, HIRES.INC, GRX.INC, ANIM.INC, ARR.INC, FIL.INC, SPR.INC | CUBE.ANI, BALL.ANI, SHIP.ANI, LOGO.HIZ, ANIMS.GRX, DEMO.BAT |

On `cpa-anim-en.dsk`, `DEMO` (the script `DEMO.BAT`) chains the compressed picture, the three
animations in VOIR, then `GRAPHER ANIMS` (a key between each).

**French disks.** Every disk has a French twin: `cpa.dsk`, `cpa-logo.dsk`, `cpa-notes.dsk`,
`cpa-asm.dsk`, `cpa-anim.dsk`, `cpa-projet.dsk`. Same programs, same files, same attributes,
with the system, messages, menus, help (HELP, README.TXT), `EDIT.CFG` and the libraries of
translated programs in French (the "yes" key is `O` there, and "all" is `T` in EDIT's
replacements). The examples have French names there; the same code, with comments, displayed
texts and names of subroutines and procedures in French. LOGO speaks French there (`AVANCE`,
`POUR ... FIN`); `LOGOTR` translates a program from one language to the other (`logo.md`).

| English | French | English | French |
|---|---|---|---|
| DRAWING.GRX | DESSIN.GRX | DEMO.LOG | DEMO.LOG |
| TITLE.GRX | ECRAN.GRX | ELIZA.LOG, ELIZA2.LOG | ELIZA.LOG, ELIZA2.LOG |
| PATTERNS.GRX | MOTIFS.GRX | PLOTSQR.LOG | TRACARRE.LOG |
| SKETCH.GRX | ARDOISE.GRX | PLOTSIN.LOG | TRASINUS.LOG |
| ARROWS.GRX, ARROWS.LOG | FLECHES.GRX, FLECHES.LOG | PLOTSINX.LOG | TRASINXX.LOG |
| SNAKE.GRX | SERPENT.GRX | HERO.SPR | HEROS.SPR |
| SCORES.GRX, SPRITES.GRX | SCORES.GRX, SPRITES.GRX | TILES.SPR | TUILES.SPR |
| MAP.GRX | CARTE.GRX | BALL.ANI | BALLE.ANI |
| ROAD.GRX | DEFILE.GRX | SHIP.ANI | VAISSEAU.ANI |
| ROTSCROL.GRX | ROTSCROL.GRX | PUZZLE.GRX | JEU.GRX |

The other files keep their names (ANIMS.GRX, DEMO.BAT, CUBE.ANI, LOGO.HIZ, HELLO, GTEST). The
table used by the build is `files/en/noms.txt`; `build.sh` checks that each English disk has
the files of the French one.

**Project disk.** `build/cpa-project-en.dsk` (`cpa-projet.dsk`) is a blank disk (no system,
336 KB for files), to put in `B:` and copy for each project.

Suggested use: the system disk in `A:` (`cpa-en.dsk`, or a disk for the task), a project disk in
`B:`, and `B:` as the current drive. From `B>`, `EDIT`, `LOGO`, `ASM`, `GRAPHER` or `GRXASM`
are found on `A:`, and so are the libraries (`CPA.INC`, `HIRES.INC`, `GRX.INC`...) that ASM and
GRXASM look for on the project's drive, then on A: to D:; everything produced (`.ASM`,
`.COM`, `.SYM`, data files) goes to `B:`, and `DIR` only shows the work in progress.
`build/cpa-en.dsk` remains the complete disk, everything visible, and the demonstration; about
70 KB are left on it, little for working (a GRXASM translation quickly writes over 40 KB).

Keys: CTRL-T toggles upper case (indicator `A`, or `a` for lower case, at the end of the menu
bar), CTRL-C on an empty line at the prompt does a warm start. The RESET button returns to the
CCP.

**The same keys everywhere.** The Oric has no TAB, Home, End or Page keys: the system replaces
them with combinations, which EDIT, HEX, CMDER and the command line understand in the same
way.

| Key | Effect |
|---|---|
| SHIFT-← / SHIFT-→ | start / end of the line |
| SHIFT-↑ / SHIFT-↓ | previous / next page |
| CTRL-↑ / CTRL-↓ | start / end of the text (of the file, of the list) |
| CTRL-← / CTRL-→ | previous / next word (EDIT) |
| CTRL-I (`^I`) | tab: complete a name, change zone or panel (EDIT: insert a file) |
| CTRL-SPACE | mark one end of the block (EDIT); ESC removes the mark |
| CTRL-X / CTRL-C / CTRL-V | cut / copy / paste (CMDER: move / copy) |
| CTRL-F / CTRL-G | find / next |
| CTRL-S / CTRL-Q | save / quit |

CTRL-H, CTRL-I, CTRL-J and CTRL-K are separate keys, distinct from the arrows. CTRL with a
digit or a sign gives nothing.

**Line editing, history, completion.** At the `A>` prompt as in programs that read a line
through the BDOS (function 10: LOGO, DEBUG…):

| Key | Effect |
|---|---|
| ← / → | move the cursor in the line; what you type is inserted |
| ↑ / ↓ | lines already entered (history), from the most recent to the oldest |
| `^I` (CTRL-I) or ESC | complete the file name that ends at the cursor; at the start of the line, the command |
| DEL / CTRL-D | erase to the left / under the cursor |
| SHIFT-← / SHIFT-→, CTRL-A / CTRL-E | start / end of the line |
| CTRL-U | erase the whole line |
| CTRL-C | on an empty line at the `A>` prompt: warm start (no effect inside a program) |
| CTRL-P | printer: copy everything displayed, on / off (indicator `P`; see below) |

The history keeps the last lines (256 bytes, about twenty short commands); it survives a warm
start, and a line identical to the previous one does not go in twice.

Completion is inspired by the C shell's `filec`, which already completed with ESC — a key
placed on the Oric where a PC keyboard has its TAB key; `^I` (CTRL-I) does the same, as in
today's shells. `TYPE REA` + ESC gives `TYPE README.TXT ` (with the space, ready for what comes
next). If several files match, ESC adds the common part (`DIR HELL` → `DIR HELLO.`); if
nothing can be added, ESC displays the possible names and rewrites the line below. Without
upper case (CTRL-T), the name is completed in lower case. An empty word + ESC shows the whole
disk.

**First word: the commands.** At the start of a line, ESC completes a command: the built-in
commands (`DIRS` after `DIR` + ESC) and the `.COM` and `.BAT` programs, without their type
(`ED` → `EDIT `, `GR` → `GRAPHER `). Programs are searched for on the same drives as when a
command is started: the current drive, then the others (without a LOCI, those already read
since power-on, with `DIR B:` for instance); a program present on two drives is only offered
once. `D` + ESC shows `DEBUG DISKCOPY DIR DIRS DO`. Other files are not offered at the start of
a line. This completion costs about 250 bytes in the system; it is assembled with the `CPLCMD`
option, and `DISK_OPTS="" ./build.sh` builds a system without it (file-name completion
remains).

**Pause at the end of the screen.** When a command fills the console (27 lines in text mode, 10
in SPLIT mode) without the user touching the keyboard, the display stops on
` -- More (^C stop) -- `. A key continues, CTRL-C gives up and returns to the prompt.
This applies to `HELP`, `TYPE`, `DIR`, `DUMP`… and to programs that display through the BDOS
or the BIOS. `PAGE OFF` (or the Paging item of the Screen menu, which toggles) removes the
pause, `PAGE ON` puts it back; the setting stays until the cold start. A program that does not
want the pause sets `$02A3` to 0 (public variable, reset to 1 at cold start).

**Redirecting the output: PUT.** `PUT LIST.TXT DIR`, `PUT HELP.TXT HELP` or
`PUT RAPPORT.TXT ASM PROG` run the command (built-in or `.COM` program) normally, and everything
it displays is also written into the file, in CP/M text format (`^Z` at the end). You can then
read it again with `TYPE` or change it with `EDIT`. During a PUT, the end-of-screen pause is
suspended. DIR lines, which fill the screen, get their line ending in the file.

How it works: `conout` also stores each character in a 1,280-byte buffer. Writing to the disk
in the middle of a display would be dangerous (the display can happen in the middle of a BDOS
function, or between "search first" and "search next"). Full records are therefore written on
entry to the next BDOS call, saving then restoring the state of the file system. The file is
closed on return to the prompt (or at warm start). A program that displayed a lot without ever
calling the BDOS would overflow the buffer: the end would be lost, and a message says so.

**Scripts: DO.** `DO NAME [p1 ... p9]` reads `NAME.BAT` and runs its lines one by one, as if
they were typed at the prompt (each line is shown after `A>`). Empty lines and those starting
with `;` are ignored. `$1` to `$9` are replaced by the parameters given to DO (`$$` gives `$`).
A script can also be started by its name, like a program: `NAME [p1 ... p9]` runs `NAME.BAT` if
there is no `NAME.COM` (`NAME.BAT` typed in full too; a type other than COM or BAT is refused).
The programs started by the script read the keyboard normally, and a script can call another
one (with DO or by its name): at the end of the called script, the caller resumes at the next
line. `XDO.COM` takes care of that, at the time of the call only: it writes `$$$.BAT`, made of
the called script (with its parameters) followed by the end of the caller (with its own), then
chains to `DO $$$`; you see `A>XDO ...` and `A>DO $$$` go by. The called script is read again
at each call: nothing to recompile when you change it. A script that calls no other does not
go through XDO. It needs a disk you can write to; without `XDO.COM`, the calling line is
skipped (`XDO?`). A script that changes a script already running (the caller) is not safe. ESC
typed between two lines, or during a `PAUSE`, stops the script. `ECHO text` displays a text and
`PAUSE [text]` waits for a key. The end-of-screen pause starts again from zero at each line of
the script. Example:

    ; PICTURES.BAT: shows two pictures, then draws
    VOIR TITLE
    VOIR MAP
    GRAPHER DRAWING $1
    ECHO Done.

    A>DO PICTURES Hello

`ECHO` and DO's parameters keep lower case as typed (the rest of the command line is turned to
upper case).

**Limits of scripts.** A script is only a series of commands, as typed on the keyboard: there
is no calculation, no variable, no condition, no loop. `$1` to `$9` are replaced by the text of
the parameters, without evaluating anything: `($1+4)` becomes `(10+4)`, which the commands do
not understand. A script that calls itself never stops by itself (there is no condition to get
out): only ESC stops it. An example that does not work:

    ; SCRIPT.BAT: a line at $1, then the next one 4 points further on?
    GRAPHER STROKE $1
    SCRIPT ($1+4)

(`STROKE.GRX` contains `SPLIT` then `LINE $1 100 $1 110`.) The first line does draw the line at
10, but the second passes `(10+4)` as it is. At the next level, GRAPHER refuses
`LINE (10+4) 100 (10+4) 110` (`parameters?`); the script then calls itself endlessly with a
longer and longer parameter, until ESC. To calculate, repeat or decide, you need a program:
LOGO (`REPEAT`, variables, `IF`) or a `.COM`.

**The alternative: hand the calculation to LOGO, from the script.** The script keeps what it
does well (chaining commands and programs) and LOGO does the rest. Two properties make this
possible: `LOGO NAME` loads `NAME.LOG` at start-up and `LOAD` runs the lines of the file that
are not procedures, so a program can start by itself and end with `BYE`; and when leaving
LOGO, the picture stays intact, in SPLIT mode: the script carries on with the same drawing, and
GRAPHER, started in SPLIT mode, draws over it without clearing it. Example:

    ; LAWN.BAT (CIRCLE.GRX: SPLIT then CIRCLE 120 30 20;
    ; WORD.GRX: GTEXT 2 114 $1 $2)
    GRAPHER CIRCLE
    LOGO GRASS
    GRAPHER WORD Lawn done

    TO GRASS :N
    REPEAT :N [FD 10 BK 10 PU RT 90 FD 4 LT 90 PD]
    END
    PU SETXY -110 -40 PD
    GRASS 50
    BYE

(the second part is `GRASS.LOG`). The circle drawn by GRAPHER, the 50 blades drawn by LOGO and
the text then added by the script stay together on the screen. The script cannot pass a
parameter to LOGO (`LOGO NAME` only takes the file name): the values are in `NAME.LOG`, which
you may have written with EDIT.

## File exchange with the LOCI's USB stick

On an Oric fitted with a LOCI, three commands copy files between CP/A and the LOCI's USB stick
(a FAT stick, often the one that holds `cpa.dsk`), without going through the PC or
`mkdisk.py`:

| Command | Effect |
|---|---|
| `EXPORT file [name]` | copies the CP/A file `file` to the stick, under the name `name` (by default, `file` as typed, lower case kept, at the root) |
| `EXPORT afn [folder]` | with wildcards (`*.LOG`, `B:*.*`): each file under its own name, in lower case if the pattern was typed in lower case, at the root or in the given folder; a `.DSK` is skipped, ESC stops between two files |
| `IMPORT name [file] [/T]` | copies the file `name` from the stick into CP/A, under the name `file` (by default, the stick's name without its path, cut to 8 + 3 characters; `B:` alone: that name on drive B:); `/T`: text, a lone LF (Mac or Linux line ending) becomes CR LF and a tab (which the Oric does not have) a space — essential for a `.LOG` written on the Mac, which LOGO's `CHARGE` only reads with CR LF |
| `USBDIR [path]` | lists a folder of the stick (the root by default): name and size, `<REP>` for a folder |

    A>EXPORT LETTRE.TXT
    A>EXPORT B:GAME.LOG 1:/oric/game.log
    A>export *.log oric
    A>IMPORT notes.txt /T
    A>IMPORT docs/MATH.LOG B:
    A>USBDIR docs

Names on the stick can have a path. Without a drive, it is the first USB stick seen by the
LOCI: this is the safest, because with a hub the stick is not necessarily `1:` (the LOCI
numbers the USB devices). `0:` is the LOCI's internal memory (`USBDIR 0:`,
`EXPORT X.TXT 0:X.TXT`). A name with spaces does not pass on the command line: rename it on the
Mac.

- A file with the same name is replaced, on the stick as in CP/A.
- EXPORT removes the `^Z` (`$1A`) that pad the last record (same rule as STAT): a text arrives
  at its real size; line endings stay CR LF, which Mac editors read. IMPORT pads the last
  record with `^Z`. A binary makes the round trip unchanged, unless it really ends with `$1A`
  bytes.
- EXPORT refuses a `.DSK` name: it could be the disk image in use.
- If the disk or the stick is full, the file being written is erased (IMPORT) or the message
  says so (EXPORT).
- USBDIR shows neither hidden or system files, nor those starting with a dot (the `._NAME`
  files the Mac leaves on FAT sticks). ESC or CTRL-C stops the list.
- Without a LOCI (Oricutron, Microdisc, Cumulus): `No LOCI : USB stick out of reach`. LOCI
  errors are shown with their code: `USB error 36 : not found`.

These commands go through the interface the LOCI offers the 6502, that of the Picocomputer 6502
(registers at `$03A0-$03BF`, details in `progs/loci_inc.s`). To try them without the hardware,
the workshop's Oricutron simulates this interface on a folder of the PC: `ORIC_LOCI=folder`
(see "Tools"), or the line `loci = '~/Oric/loci'` in `oricutron.cfg` (the folder must exist,
with its subfolder `int` for `0:`).

## Publishing for the Oric under BASIC: MKTAP

`MKTAP` makes a `.TAP` file: a tape that any Oric Atmos loads with `CLOAD""`, without CP/A or
a disk (BASIC ROM 1.1). The program is first assembled for its address under BASIC
(`*= $8000`, for instance), then:

    A>MKTAP GAME GAME.COM 8000 /R
    GAME     8000-84D1 /R
    GAME.TAP written
    A>MKTAP GAME GAME.COM 8000 /R MAP.DAT 9800
    GAME     0501-0516 BASIC
    GAME     8000-84D1 /R
    MAP      9800-9BFF
    GAME.TAP written

| Item | Role |
|---|---|
| `NAME` | the file written, `NAME.TAP` (type `.TAP` by default, drive allowed) |
| `file adr` | one block per file, loaded at `adr` (hexadecimal, `$` allowed), named after the file without its type; 8 files at most |
| `,len` | length of the block (hexadecimal); without it, the size of the file minus the `^Z` that fill its last record (the STAT and EXPORT rule); it may go up to the raw size (whole records), for data that really ends with `$1A` |
| `/R` | this block is run after loading (once only) |

- A single block with `/R`: it carries the auto-run mark; `CLOAD""` loads and runs it.
- Several blocks with `/R`: MKTAP puts a small BASIC program first, named like the `.TAP` and
  run by itself: `10 CLOAD"":CLOAD"":CALL#8000` (one `CLOAD""` per block, then the call of the
  `/R` block). A single `CLOAD""` is therefore enough; the BASIC program stays in memory
  (`LIST`, editable).
- Without `/R`: each block is loaded by its own `CLOAD""`, then `CALL#adr`.
- Checks, before anything is written: each block within `$0500-$BFFF` (the BASIC RAM, text
  screen included), no overlap (the BASIC loader included, at `$0501`), a non-zero length.
- The code that is run lives under the Oric's ROM: no CP/A BDOS or BIOS (`JSR $0203`, `$C000`),
  no files; an `RTS` returns to BASIC. Under BASIC, a BASIC program uses `$0501-$97FF`, and
  page 2 and the zero page belong to the ROM (`docs/oric-basic.md` § 1).
- A `.COM` written by ASM ends with zeros (the fill of its last record): they are loaded too,
  with no effect; `,len` removes them.
- Transport: `EXPORT GAME.TAP` to the LOCI's USB stick, tape mounted from the LOCI menu, then
  `CLOAD""`. EXPORT removes the `^Z` that fill the `.TAP` (MKTAP first adds a 0 byte if the
  last useful byte is `$1A`). In Oricutron: `-t GAME.TAP`.
- On the PC, `tools/mktap.py` does the same with files of the PC (same arguments).

## Serial terminal: TERM

`TERM` talks to the serial port: what you type goes to the modem, what arrives is shown. On a
LOCI, the port is the USB WiFi modem (a Raspberry Pi Pico W, see `docs/loci-modem-wifi.md`)
that the LOCI presents as a 6551 ACIA at `$0380`; without a LOCI, it is Oricutron's ACIA at
`$031C`. The first line says which one is used.

| Command, key | Effect |
|---|---|
| `TERM` | terminal (9600 baud, 8 bits, no parity, 1 stop bit) |
| `TERM /E` | local echo: also shows what you type (for a peer that does not send it back, such as `nc` on the Mac; the modem itself echoes it in command mode) |
| `TERM /L` | RETURN sends CR LF instead of CR alone (for a peer that expects LF, such as `nc`: `TERM /E /L`) |
| `TERM /D` | diagnostics: ACIA registers (status, command, control) read back before and after set-up (after: command `0B`, control `1E`), then each change of the status in brackets (`[10]` transmitter free, `[18]` character received, bit 6 (`$40`): no modem) |
| `TERM /B` | "blind" sending: each character goes out without waiting for the ACIA to report the transmitter free (fixed pause of about 3 ms); used to check writes when ACIA reads are wrong (`TERM /B /E`, `ATDT-` to `nc` on the Mac) |
| CTRL-Q | quits; the link stays up (DTR stays active) |
| DEL | sends BS (8); CTRL-H to CTRL-K send 8 to 11 |
| arrows | nothing (no ANSI emulation yet) |

    A>TERM
    TERM : LOCI modem (ACIA 0380)
    CTRL-Q : quit. Try : AT, ATI
    AT
    OK
    ATDT-192.168.1.20:2323

Modem commands: `AT?` (list), `ATI` (status, IP address), `ATDT-host:port` (connection
without telnet), `+++` with a one-second pause before and after (back to command mode), `ATH`
(hang up). Details: `docs/loci-modem-wifi.md`.

- `No modem (DSR) : plug the Pico in`: the LOCI sees no USB modem; TERM stays open, and
  `Modem silent : character lost` is shown if you type.
- What arrives: a CR is shown as CR LF (a peer that sends back only CR, and the local echo
  of RETURN, do go to the next line); a LF right after a CR is skipped (no blank line with
  those that send CR LF).
- TERM only accesses the ACIA registers with absolute `LDA` / `STA`: an indexed write
  (`STA (zp),Y`, and `POKE` in BASIC) reads the address before writing it, and an ACIA read
  has side effects (the data register consumes the received byte).
- The end-of-screen pause is off during TERM (it would block reception). While the menus
  (FUNCT) are open, the LOCI keeps what arrives.
- In Oricutron: `serial = 'loopback'` in `oricutron.cfg` sends back each character sent;
  `serial = 'modem'` links the ACIA to a simulated modem (reduced AT command set).

## Start-up and recovery after a crash

At cold start, CP/A tests the program RAM as the Atmos ROM does: it writes `$AA` then `$55` into
each byte and checks what it reads back. It then displays `RAM test OK.` or the address of the
first faulty byte. The test takes about 1.5 s.

Unlike the ROM, it leaves the memory filled with `$00`, which is the `BRK` instruction. A
program that jumps into an empty area by mistake is therefore caught: `*BRK* at xxxx` is
displayed, then the system returns to the prompt.

The Atmos RESET button, wired to an NMI interrupt, returns to the prompt, displaying the
address where the program was running (`*RESET* at xxxx`). This lets you get out of an endless
loop and know where it was. After BRK or RESET, the screen goes back to text mode, even if the
program was in high resolution, and the font is reloaded.

Every warm start also puts back in place:
- the page 2 vectors;
- the VIA and the 50 Hz timer;
- the sound, switched off;
- the font;
- the menu bar.

Only illegal "JAM" instructions, which lock up the 6502 itself, and overwriting the system in
RAM (disk version) force a full restart.

## Pull-down menus

The status line is used as a menu bar: **System** (Version, Help, Memory, Printer `^P`, Next
drive, Reboot `^C`), **Files** (disk version only: Directory, Show..., Copy..., Rename...,
Erase...), **Screen** (SPLIT mode, Text mode, Clear, Ink, Paper, Caps lock `^T`, Paging) and
**Keyboard** (Fast, Normal, Slow). An item that has a keyboard shortcut shows it
at the end of its label (`^C` reboots only on an empty line of the prompt; the item also works
inside a program). Ink and Paper move to the next colour (never the same for both); in
scripts, `INK n` and `PAPER n` do the same with a chosen colour. A pull-down menu takes the
complementary colour of the paper, and its inks are chosen for each paper (on black paper:
magenta, blue selection on white; on white paper: yellow, cyan selection...). On
`cpa-en.dsk`, the bar is in English: System, Files, Screen, Keyboard. At the end of the bar, two indicators:
`A` (upper case locked) or `a` (lower case), then `P` when copying to the printer is on. The
engine is rewritten from Pierre Garnier's [Menus](https://github.com/drpsy77/Menus) project,
whose ergonomics, colours and table format it takes over.

- **FUNCT** opens the bar, then **←/→** go from one menu to the other.
- **↓** or **ENTER** pulls the menu down, **↑/↓** choose the item, and going above the first
  item closes the menu.
- **ENTER** runs the chosen item, **ESC** or **FUNCT** close the menu.

The menu opens at every keyboard read: at the `A>` prompt, but also in a program that reads the
keyboard through the BIOS or the BDOS. The screen area it covers is saved, then restored.

An item triggers one of these two actions:
- **type a command** for the user, for instance `DIR` followed by Enter, or `TYPE ` left to be
  completed;
- **call a routine**, for instance to change the ink, the paper, the upper case or the key
  repeat speed.

A program can install its own bar with `JSR $C02D`, A/Y = address of the bar:

    bar     .byt 2                      ; number of menus (8 at most)
            .word menu1, menu2
    menu1   .byt 2,7                    ; number of items, width of the longest label
            .asc "File",0               ; title
            .asc "Open...",0            ; label
            .byt 1                      ; 1 = type a string, 2 = call a routine
            .word string_or_routine
            .asc "Quit",0
            .byt 2
            .word quit

(In this table: number of menus, 8 at most; number of items and width of the longest label;
title; label; 1 = type a string, 2 = call a routine.)

## SPLIT mode: picture and text

`SPLIT` divides the screen in two: a 240 × 128 high-resolution picture at the top, and text
below (the menu bar then 10 console lines). The prompt, the commands and the menus keep working
under the picture. `TEXT` goes back to text mode, and `GCLS` clears the picture.

`GSAVE NAME` saves the picture to `NAME.IMG`, and `GLOAD NAME` loads it again, switching to SPLIT
mode if needed (the console is not cleared if it is already there). The file is the raw copy of
`$A000-$B3FF`: 5,120 bytes, colour attributes included. You can thus prepare pictures (with
LOGO, or a drawing program) and load them again in a game.

How it works: as with BASIC's `HIRES`, the last cell of the screen (`$BFDF`) contains the
attribute `$1E`, which makes the next frame start in high resolution: the whole byte `$A000` is
thus visible and usable. The first cell of point line 127 (`$B3D8`, the only byte of the
picture not used for points) contains `$1A`, which brings back text at line 128. The last text
line only contains attributes (it stays empty): the real video circuit changes mode at the next
point line, and the end of that line would be drawn with the HIRES mode font, which does not
exist here. The picture (`$A000-$B3FF`) ends just before the text mode font (`$B400`), so no
area overlaps. In SPLIT mode, the TPA ends at `$9FFF` (public variable `$020C`).

Full-screen HIRES (240 × 200) is not a system mode: programs take it over with the `hires.inc`
library (see "Full-screen HIRES"), as `GRAPHER` and `VOIR` do.

**Graphics primitives** (BDOS function 115, A/Y = address of a 6-byte block `[op, p1..p5]`,
as for CP/M's GSX extension):

| op | Primitive | Parameters |
|---|---|---|
| 0 | GCLS | — |
| 1 | PEN | 0 erases, 1 draws, 2 inverts |
| 2 | PLOT | x (0-239), y (0-127) |
| 3 | LINE | x1, y1, x2, y2 |
| 4 / 5 | BOX / FBOX | x1, y1, x2, y2 (empty / filled rectangle) |
| 6 | CIRCLE | x, y, r (r ≤ 127) |
| 7 | TEXT | column (0-39), y, address of the string |
| 8 | ATTR | column, y1, y2, attribute (ink 0-7, paper 16-23) |
| 9 | POINT | x, y → A = 1 if the point is lit |
| 10 | MODE | 0 text, 1 SPLIT (picture cleared), 2 SPLIT keeping the picture |
| 11 | GETMODE | → A = 0 text, 1 SPLIT |
| 12 | GSAVE | address of the FCB (low byte, high byte): saves the picture |
| 13 | GLOAD | address of the FCB: loads a picture and switches to SPLIT |

GSAVE and GLOAD (disk version) use the type `.IMG` if the name has none, and return 0 if all is
well, 1 if the file is missing, 2 if the disk or the directory is full, `$FF` for GSAVE outside
SPLIT mode. A program that calls GLOAD from text mode must stay below `$A000`.

**Without a program**, you draw with `GRAPHER` and a `.GRX` file (`grapher.md`), and `GSAVE`
keeps the result. The ROM version keeps one command per primitive at the prompt (`PEN m`,
`PLOT x y`, `LINE x1 y1 x2 y2`, `BOX`, `FBOX`, `CIRCLE x y r`, `GTEXT col y text`,
`ATTR col y1 y2 v`, `POINT x y`), in SPLIT mode only. The pen is in "draw" mode at start-up.

Outside SPLIT mode, primitives 0 to 9 return `$FF`. `GTEST.COM` is a complete example: it
switches to SPLIT and draws a frame, diagonals, circles, rectangles and text.

## Full-screen HIRES: VOIR, hires.inc, png2hir.py, animations

Full-screen HIRES (240 × 200 points, `$A000-$BF3F`) covers the font (`$B400`) and the text
screen (`$BB80`): the system can no longer display anything there. So it is not a system mode
but a rule: **the program takes the screen for itself**, and hands it back properly.

- `VOIR NAME` shows `NAME.HIR` in full screen, `VOIR NAME.HIZ` the same picture compressed, or
  `VOIR NAME.IMG` a SPLIT mode picture, and goes back to text at the first key.
- `VOIR NAME.ANI [n]` plays a full-screen animation n times (0 or nothing: until a key);
  `ANIM NAME [n]` does the same in GRAPHER (interpreted, or translated by GRXASM). See
  "Animations" below.
- A `.HIR` picture is the raw copy of the screen: 8,000 bytes, the usual format on the Oric.
  `GSAVE` in GRAPHER writes some; `tools/png2hir.py image.png NAME.HIR` makes one on the Mac
  from any picture (scaling, dithered black and white; `--split` for a 240 × 128 `.IMG`
  picture; Pillow module), which you then copy with `IMPORT` or `tools/mkdisk.py put`.
- `progs/hires.inc` (`HIRES.INC` on the disks) is the library a program includes
  (`#include "HIRES.INC"`, with xa on the Mac or ASM on the Oric): `h_full` (full screen),
  `h_split`, `h_text`, `h_cls`, `h_pen`, `h_plot`, `h_line`, `h_box`, `h_fbox`, `h_circle`,
  `h_print` (text), `h_attr`, `h_point`, `h_load`, `h_save`, `h_key`; for the text screen
  (LORES): `h_lores`, `h_lcls`, `h_loc`, `h_chr`, `h_scrn`, `h_lput`, `h_lstr`, `h_lspc`,
  `h_ltab`, `h_lnl` (writing cursor `h_lx`, `h_ly`). The parameters are in `h_x1`, `h_y1`,
  `h_x2`, `h_y2`, `h_r`; it uses `$C0-$C7` in the zero page and places its tables (2 KB) after
  the end of the program (`h_free`: first free address). The same routines work in SPLIT (128
  lines). See `progs/voir.s` for a short example.

During full-screen HIRES, the program does not write to the console (BDOS functions 2, 9...)
before `h_text`. The system, for its part, no longer draws anything there by itself: the FUNCT
key is ignored (no menus), the indicators are not redrawn and the cursor is off. It recognises
the situation by the attribute `$1E` in the last cell of the screen (`$BFDF`) outside SPLIT
mode. And if the program ends without `h_text` (CTRL-C, crash, oversight), the warm start
restores text mode, the font and a clean screen. The text screen given to a program (LORES,
`h_lores`) follows the same rule; the system recognises it by the public variable `SCR_PROG`
(`$020E`) set to 1, which `h_lores` sets and `h_text` and the warm start reset to 0.

### Compressed pictures and animations

**Compression.** A `.HIZ` picture is LZSS-compressed (the compressor of an old OSDK project by
Pierre, kept in `archives/lzss-osdk/`): about 1.1 to 1.4 KB for a line drawing, 4 to 8 KB for a
dithered picture, instead of 8,000 bytes. `h_load` recognises it by its type, loads it into free
memory (`h_zbuf`, after the program) and decompresses it with `h_unz`. Making one:
`tools/png2hir.py image.png NAME.HIZ --hiz` (or `tools/lzhir.py c NAME.HIR NAME.HIZ`).

**Animations.** A `.ANI` animation is a series of pictures where each one only describes what
changes since the previous one. The stream format remains that of the original compressor: a
copy at distance 0 copies the byte onto itself (it is **kept**), a "negative" distance takes the
byte further on, still from the previous picture. `h_unz` handles the jump without copying
anything, which is what makes it fast. Measurements (simulated 6502, to the cycle): about 52
cycles per literal byte, 18 per copied byte, about 105 per kept area whatever its length; in
practice, **about 200 changed bytes per 1/50 s**.

| Demo (`cpa-anim.dsk`) | Size | Decoding | Rate |
|---|---|---|---|
| `CUBE.ANI`: line-drawn cube, 12 frames (a quarter turn loops) | 18.3 KB | about 65,000 cycles | 10 frames/s |
| `BALL.ANI`: ball in front of a dithered picture, 30 frames | 21.2 KB | about 21,000 cycles | 25 frames/s |
| `SHIP.ANI`: animated GIF passed through `mkanim.py`, 24 frames | 12.5 KB | about 21,000 cycles | 12.5 frames/s |

- Making one on the Mac: `tools/mkanim.py FILM.ANI anim.gif [--seuil 128] [--delai N]
  [--apercu voir.gif]` (threshold, delay, preview; or a series of PNGs); the summary gives the
  size, the estimated decoding time (to within 1%) and the rate obtained. `--seuil` is advised:
  dithering changes the whole screen from one frame to the next, and a full-screen dithered
  video does not go beyond 2 to 3 frames/s. `--longue` gives a smaller but slower file. The
  demos: `tools/anim_demos.py`.
- The whole animation is loaded into memory: about 34 KB in VOIR, about 25 KB in GRAPHER (after
  the text of the `.GRX`). The 1st frame is drawn on a cleared screen; the last is followed by a
  frame going back to the 1st, to loop without redrawing everything.
- Rate: each frame has its own delay (1/50 s) and starts at the next 50 Hz tick; if decoding
  overruns, the frame waits for the following tick, without drift.
- **Tearing.** The Oric has only one screen: a frame is drawn while the beam sweeps. The system
  IRQ timer runs at 19,968 cycles, an exact video frame (tick at 50.08 Hz), and is only
  restarted at cold start: the tick always falls on the same scan line, and the tear line does
  not move. The **left and right arrows** move it by 8 lines; put it where nothing changes.
  This setting holds until the next start.
- **VSYNC** aligns the tick with the end of the picture, like the setting at the start of
  Oricium (the Oric has no sync signal a program can read). A text hidden in the middle of the
  screen is only made visible during 8 scan lines, at a fixed moment after the tick; the arrows
  shift the tick (left / right: 1 line, up / down: 8 lines) until you see the text whole and
  still; RETURN keeps the setting (ESC cancels it). A frame is then decoded just after the beam
  has left the picture, and does not tear if it fits in the time the beam takes to come back:
  about 7,000 cycles, plus 64 per line going down (a small moving figure). The demos change too
  many points per frame (10,000 to 75,000 cycles): tearing remains there, at a fixed place. To
  be done once after power-on; to be tried on a real Oric.
- In a program: `#include "ANIM.INC"` **before** `HIRES.INC` (which stays at the end), then
  `a_play` (A/Y = FCB, X = passes; C=1 on error, `a_msg` gives the message). GRXASM only
  includes `ANIM.INC` if the program uses ANIM.

## Sound (BDOS function 116)

The Oric's sound chip (AY-3-8912, three voices and a noise generator) is reached like the
graphics: X = 116, A/Y = address of a block `[op, p1..p5]`. Both versions (disk and ROM) have
it.

| op | Primitive | Parameters |
|---|---|---|
| 0 | SILENCE | — (stops the three voices) |
| 1 | NOTE | voice (0-2), note (1-96; 37 = middle C, 46 = A 440 Hz; 0 = silence), volume (0-15, 16 = envelope), duration |
| 2 | NOISE | voice, noise period (0-31), volume, duration |
| 3 | ENV | shape (0-15), period lo, period hi (envelope) |
| 4 | WAIT | voice (255: all) — waits for the end of the notes |
| 5 | STATUS | → A: one bit per voice still playing |
| 6 | TONE | voice, period lo, period hi (0-4095), volume, duration |
| 7 | SYNC | mode: 0 prepare, 1 start, 2 cancel (see below) |
| 8 | MIXER | voice, tone (0/1), noise (0/1) — both at once are possible |

The duration is in fiftieths of a second (0: the note holds until the next one). It is counted
down by the 50 Hz interrupt: the program goes on while the note plays, and `WAIT` or `STATUS`
are used to synchronise. Since the keyboard also goes through the AY, writes to the chip are
made with interrupts masked. In LOGO: `NOTE`, `TONE`, `NOISE`, `ENVELOPE`, `MIX`,
`TOGETHER`, `WAITSOUND`, `PLAYING?` and `SILENCE` (see `logo.md`).

**Simultaneous start (SYNC).** After `SYNC 0`, NOTE, NOISE and TONE set the voice's period and
mixer at once, but mute it and hold back its volume and duration; ENV sets the envelope period
and holds back its start. `SYNC 1` then starts all the prepared voices at the same instant,
interrupts masked (a few microseconds apart), and restarts the envelope if it was set during
the preparation: the voices begin together and, for equal durations, stop at the same 50 Hz
tick. `SYNC 2` cancels (the prepared voices stay silent), and so does SILENCE.

**Mixer (MIXER).** NOTE and TONE switch on the voice's tone and switch off its noise, NOISE the
reverse. MIXER, given afterwards, chooses tone and noise freely, including both at once on the
same voice (sound effects). The noise generator and the envelope are single in the AY: their
period is shared by the three voices.

## The text editor EDIT

    A>EDIT LETTRE.TXT

It is a full-screen editor: 26 lines of 38 columns, with a menu bar and a status line (file
name, `*` if the text is modified, paragraph `L`, position `C` of the cursor in the paragraph,
`INS`/`OVR` for insert/overwrite, `M` if a mark is set). The text can reach 32,000 bytes (about
27 KB when started from SPLIT mode). In memory a line end is one byte, two on the disk
(CR LF): a file can therefore exceed 32,000 bytes by as many bytes as it has lines and still
open whole, and any text saved by EDIT opens again. A longer file opens **truncated** (`File
truncated: too big`); it cannot be saved under its own name (`Text truncated: Save as...`),
which would lose its end, but can be under another one. A long assembler program is therefore written as
modules under 32,000 bytes, brought together by `#include` (see ASM); TYPE and ASM read a file
of any size.

Three display modes (Options menu, or CTRL-W which moves to the next one):

- **Word wrap** (default): a paragraph that is too long continues on the
  following lines, broken between words;
- **Wrap at 38**: broken every 38 characters;
- **Line**: one paragraph per screen line; the window scrolls sideways (10
  columns at a time) to follow the cursor, and all lines with it. The status line shows `<`
  when the window is shifted and `>` when the paragraph goes on to the right. Beyond 240
  characters, the paragraph continues on the next line. This is the mode for code (`.ASM`,
  `.GRX`, `.LOG`, `.BAT`) and for GRAPHER maps written in plain text, wider than the screen.

An EDIT paragraph has no length limit, but the programs that read the file do: LOGO reads 126
characters per line, a `.BAT` script 78. The file **`EDIT.CFG`** gives, for each file, the
maximum length of a paragraph, the line breaking on screen and the printer width:

    ; name   max  breaking printer
    LETTER.TXT 0   WORDS 96
    *.LOG    126  LINE  80
    *.BAT    78   LINE  80
    *.*      0    WORDS 80

(Columns: name, maximum, breaking — `WORDS` between words, `CHAR` at the character, `LINE` one
line per paragraph: the starting mode, which can be changed while editing; only the first
letter counts, and `MOTS`, `CAR`, `LIGNE`, those of the `EDIT.CFG` of `cpa.dsk`, are
accepted too — and printer width.) The first line whose name matches applies (wildcards `*` and `?`, optional drive:
`B:*.TXT`); so put the special files first. Missing columns keep their default value (no limit,
`WORDS`, 80); `;` starts a comment. EDIT looks for `EDIT.CFG` on the document's drive, then on
`A:`, at every open and every "Save as...". Without `EDIT.CFG`, it keeps 126 for
`*.LOG` and 78 for `*.BAT`. The disks provided have one, changeable (`EDIT EDIT.CFG`); it is
hidden (SYS) on the disks by use.

When the paragraph under the cursor is longer than the maximum, the status line shows `C 127!`
in reverse video. **CTRL-L** (Search menu, Too long) goes to the first extra character of the
next paragraph that is too long; the Statistics give the length of the longest paragraph and its
number (`max 177 (L4)`).

| Key | Action |
|---|---|
| Arrows | move the cursor |
| SHIFT-← / SHIFT-→ | start / end of line |
| CTRL-← / CTRL-→ | start of the word (or of the previous one) / of the next word; a word ends at a space or at the end of a paragraph |
| SHIFT-↑ / SHIFT-↓ | previous / next page |
| CTRL-↑ / CTRL-↓ | start / end of the text |
| RETURN | new paragraph |
| DEL / CTRL-D | erase to the left / under the cursor |
| CTRL-SPACE | mark one end of the block (Edit, Mark); ESC removes the mark |
| CTRL-X / CTRL-C / CTRL-V | cut / copy the block (from the mark to the cursor) / paste |
| CTRL-K | erase the paragraph |
| CTRL-E | insert / replace |
| CTRL-F / CTRL-G / CTRL-H | find / next (starts again from the top if needed) / replace |
| CTRL-O / CTRL-S / CTRL-Q | open / save / quit |
| CTRL-I (TAB) | insert a file at the cursor (File, Insert...) |
| CTRL-P | print the text (File, Print) |
| CTRL-L | next paragraph too long (Search, Too long) |
| CTRL-W | next display mode: break at words, at 38 characters, whole line (Options) |
| FUNCT | menus |

Menus:
- **File**: New, Open..., Insert..., Save, Save as..., Print, Quit. The system asks for
  confirmation before losing changes. Insert... adds the contents of another text file at the cursor (the
  cursor ends up after the inserted text). Print sends the whole text to the printer
  (Centronics port, BDOS function 5), laid out: each paragraph is broken between words into
  lines of at most the printer width minus one character (79 for 80, adjustable in
  `EDIT.CFG`), so that a printer that wraps by itself does not add a blank line; a word longer
  than a line is cut. ESC stops between two lines. Without a printer nothing hangs, but each
  character waits 2 ms for the acknowledge (about twenty seconds for 10 KB): ESC. Started from
  LOGO with `EDIT`, EDIT shows Back instead of Quit: it saves the text if it
  changed and goes back into LOGO (see LOGO).
- **Edit**: Mark, Copy, Cut, Paste, Del. para. (erase the paragraph). The clipboard holds 4 KB at most. Mark one end of the block (CTRL-SPACE),
  move the cursor to the other end, then copy (CTRL-C) or cut (CTRL-X); CTRL-V pastes at the
  cursor. ESC removes the mark.
- **Search**: Find..., Next, Replace..., Too long. For each occurrence, answer Y (yes), N
  (no), A (all) or Esc. The search ignores the
  difference between upper and lower case.
- **Options**: Word wrap, Wrap at 38, Line (the three display modes; `>` in front of the
  current one; the starting mode comes from `EDIT.CFG`), Ins/Ovr (insert/overwrite),
  Statistics (characters, words, longest paragraph).

Started from SPLIT mode, the editor switches to full-screen text and keeps its text below
`$A000` (about 27 KB). When leaving, it shows the picture again, intact.

Files are CP/M text: CR LF between paragraphs, `^Z` at the end. To lose nothing if the disk is
full, saving first writes `NAME.$$$`, then replaces the old file: the new file needs room in
addition to the old one. Disk full (`Disk full: not saved`) or directory full: the old
file has not changed and `NAME.$$$` is erased. Save as... onto an existing file asks
`Replace NAME.EXT (Y/N) ?`; a protected file is refused (`File protected (R/O)`)
without writing anything. A document opened read-only can be saved under another name. A RESET
during saving leaves the old file, or the new one; at worst (RESET between erasing the old file
and the renaming, half a second) the new text is complete in `NAME.$$$`:
`REN NAME.EXT=NAME.$$$` puts it back. A leftover `NAME.$$$` is erased by the next save of the
same name.

## The hex editor HEX

    A>HEX EDIT.COM

HEX shows any file in hexadecimal and ASCII, 8 bytes per line on 26 lines, and lets you change
it:

    0000 D8 A2 73 A9 E3 A0 16 20 ..s....

The status line gives the file name (`*` if it is modified), the cursor position and the file
size (`$0125/$1700`), the value of the current byte in hex and decimal, and the mode (`HEX`,
`ASC`, or `R/O` for read-only). The current byte is in reverse video in the area where you
type.

| Key | Action |
|---|---|
| Arrows | previous / next byte, previous / next line |
| RETURN, DEL | start of the next line, previous byte |
| SHIFT-← / SHIFT-→ | start / end of the line |
| SHIFT-↑ / SHIFT-↓ | previous / next page |
| CTRL-↑ / CTRL-↓ | start / end of the file |
| CTRL-L | go to an address (in hex) |
| CTRL-F / CTRL-G | find / next |
| `^I` (CTRL-I) | edit in hex or in ASCII |
| CTRL-S / CTRL-R | save / reload |
| ESC or CTRL-Q | quit (confirmation if the file is modified) |
| FUNCT | menus File (Save, Reload, Quit), Go to (Top, End, Address..., Find..., Next), Mode (Hex/ASCII) |

In HEX mode, type two digits per byte (the first replaces the high nibble, the second the low
one, then the cursor moves on). In ASCII mode, each character typed replaces the byte. The size
of the file never changes.

The search takes text (ignoring case) or, after `#`, bytes in hex: `#20 03 02` or `#200302`.
It starts again from the top if needed.

HEX reads the file by random access, in windows of 32 KB at most: a file that fits in the window
is read at once, a larger one is walked through in pieces, up to 64 KB (beyond that, only the
start is shown). `^S` rewrites in place only the records that were modified; leaving a modified
window for another part of the file also writes it (message `Modifications ecrites`, changes
written). Started from SPLIT mode, HEX keeps the picture and shows it again when leaving. As
under CP/M, the size is a multiple of 128 bytes: the end of a text file therefore shows the
padding `^Z`s (`1A`). A read-only (R/O) file can be viewed but not saved.

## The assembler ASM

    A>EDIT PROG.ASM
    A>ASM PROG
    A>PROG

`ASM NAME [/S] [/E]` assembles `NAME.ASM` (or `NAME.ext` if you give the type) and writes
`NAME.COM`. You can thus write, assemble and run a program without leaving the Oric. `/S` also
writes `NAME.SYM`, the list of symbols for DEBUG; `/E` erases the source if assembly succeeded
(this is what `GRXASM NAME /C` does, its `.ASM` being only an intermediate). Example on the
disk:

    A>ASM HELLO /S
    ASM CP/A 1.0
    Pass 1
    Pass 2
    HELLO.COM $0500-$0557 : 88 bytes
    8 symbols (.SYM)

The syntax is that of the OSDK's `xa` assembler, for the part CP/A programs need: the same
sources assemble on the Oric and on the PC. Assembled on the Oric, HELLO, COPY, GTEST, HEX, EDIT,
LOGO and ASM itself give exactly the same bytes as with `xa`.

| Element | Syntax |
|---|---|
| Label | in column 1, case-sensitive (`:` optional) |
| Constant | `NAME = expression` |
| Address | `*= $0500` (also the default value) |
| Data | `.byt` / `.byte` / `.asc` (numbers and strings `"..."`), `.word`, `.dsb n[,value]` |
| Blocks | `.(` ... `.)`: labels defined inside are local to the block |
| Include | `#include "CPA.INC"` (one level), looked for on the source's drive, then on the drives already read from A: to D: |
| Comment | `;` to the end of the line |

Expressions: decimal numbers, `$hex`, `%binary`, characters `"A"` or `'A'`, `*` (address of the
instruction), symbols, brackets, `+ - * / & | ^ << >>`, unary minus, and `<` / `>` (low / high
byte) before the expression. Mnemonics can be written in upper or lower case; `ASL`, `LSR`,
`ROL`, `ROR` accept `A` or nothing. An address known before the line and below 256 gives zero
page mode.

As with `xa`, a second `*=` leaves no gap in the file: the code that follows is placed next,
assembled for the new address (DEBUG uses this to copy itself to the top of memory).

**A program in several files.** EDIT only holds 32,000 bytes: a long program is split into
modules, edited separately and brought together by the main file.

    ; GAME.ASM
    #include "CPA.INC"
    *= $0500
            jsr init
            ...
    #include "TITLE.INC"
    #include "LEVELS.INC"

One level of inclusion only: a module does not include another (`Only one include
level`). Labels are shared by all the files: prefix those of each module (`ti_`,
`lv_`...), as the libraries do (`h_`, `r_`, `f_`). Modules are looked for like `CPA.INC`: on
the drive of `GAME.ASM`, then on A: to D:.

Errors are listed with the line number, the message and the start of the line (the name of the
included file in brackets where relevant). The list pauses at each full screen. If there is an
error, nothing is written. ESC interrupts the assembly.

The assembler reads the source line by line from the disk, in two passes: the size of the source
is only limited by the disk. The second pass writes the code into `NAME.COM` as it goes, in
128-byte records: free memory (about 37 KB in text mode) is only used for the symbol table
(about 10 bytes plus the length of the name per symbol; LOGO has 1,500 of them). A line can be
about 1,000 characters. As an example, LOGO (6,500 lines, 136 KB of source, 19 KB of code)
assembles in a little over a minute and a half (about 28 million instructions, plus the disk
accesses).

## The debugger DEBUG

    A>ASM PROG
    A>DEBUG PROG [parameters]

DEBUG loads `PROG.COM` at `$0500`, where it will run, and `PROG.SYM` if it exists (`ASM PROG /S`). The
parameters after the name are passed to the program. The debugger places itself at
`$8400-$9FFF`, with the symbols just below, and lowers the top of the TPA accordingly (variable
`$020C`, ceiling `$02A9`): about 31 KB remain for the program. Programs that respect the top of
the TPA (EDIT, HEX, ASM, LOGO) therefore work under the debugger.

    PC=0504 A=00 X=03 Y=00 S=F9
    P=20  N V - B D I Z C
          0 0 1 0 0 0 0 0
    loop:
    0504 20 0C 05  JSR double

| Command | Effect |
|---|---|
| `R` | registers, with the status register shown bit by bit |
| `R A=41`, `R PC=boucle`, `R S=F0`, `R C=1` | changes a register (A X Y P S PC) or a flag (N V D I Z C) |
| `L [adr]` | disassembles 12 instructions, with the labels of the source |
| `D [adr]` | memory in hex and ASCII |
| `M adr bb bb ...` | writes bytes |
| `G [adr]` | runs until a breakpoint, the end of the program or the RESET button |
| `T [n]` | single step (n instructions), going into `JSR`s |
| `P [n]` | single step, each `JSR` run in one go |
| `B [adr]`, `B- [adr]` | sets or lists breakpoints (8 at most), removes one or all |
| `? expr` | value in hex and decimal, and the nearest symbol |
| `H`, `Q` | help, back to the system |

Addresses are written in hex (`512`, `$512`), in decimal (`#1298`) or with a symbol name,
optionally followed by `+` or `-`: `L boucle+3`. For names, case does not matter. Global symbols
come before the local labels of `.( .)` blocks. The disassembly replaces addresses with names
(`STX cnt`, `JSR BDOS`, `LDA TAIL+1,Y`) and shows labels on their own line. In single step,
each instruction gives a line of registers, with the flags as letters (upper case = 1):
`A=00 X=03 Y=00 S=F7 nvdiZc`. ESC stops a series of steps.

How it works: since the 6502 has no single-step mode, DEBUG sets a temporary `BRK` on the next
instruction (on both outcomes of a branch), and on each breakpoint. It hooks the vectors in RAM:
IRQ (to recognise its `BRK`s), NMI (the RESET button stops the program instead of restarting
the system) and WBOOT (the end of the program). A `JSR` to the system (`JSR BDOS`, BIOS) is
always run in one go. The debugger keeps the program's stack and works below it. Its zero page
variables (`$D0-$DF`) are swapped with the program's at each stop.

## Writing a .COM program

A `.COM` is code assembled for `$0500`. The CCP loads it at that address and calls it with
`JSR`. A program must stay below the top of the TPA, given at `$020C` (`$B400` in text mode,
`$A000` in SPLIT mode). The program returns with `RTS` or `JMP $0200`.

Before starting it, the CCP prepares:
- at `$045C`, FCB 1, filled with the 1st argument;
- at `$046C`, FCB 2 (16 bytes), filled with the 2nd argument;
- at `$0480`, the parameter line: a length byte then the characters, ending with 0;
- the DMA, set to `$0480`.

Programs have the zero page `$00-$DF` for themselves. See `progs/hello.s`, `progs/copy.s` and
`progs/edit.s`.

`progs/cpa.inc` gathers the public interface:
- the BDOS and BIOS entry points;
- the function numbers;
- the cursor variables (`$0210-$0214`), which a full-screen program can drive;
- the menu constants.

A program that installs its own menu bar can make it "type" codes `$81-$FF`. These codes never
come from the keyboard, and the program receives them through CONIN like ordinary keys. This
is what the editor does.

## Calling the BDOS

    X = function number (register C under CP/M)
    A/Y = parameter, low byte / high byte (register DE under CP/M)
    JSR $0203  -> result in A

| No. | Function | No. | Function |
|---|---|---|---|
| 0 | warm start | 15 | open (A=$FF if missing) |
| 1 | read a character with echo | 16 | close |
| 2 | write character A | 17 / 18 | search first / next (32-byte entry copied to the DMA) |
| 5 | print character A (Centronics) | | |
| 6 | direct I/O (`$FF` read, `$FE` status) | 19 | erase (wildcards) |
| 9 | string ending with `$` | 20 | sequential read (0 OK, 1 end) |
| 10 | read a line (CP/M format) | 21 | sequential write (0 OK, 1 directory full, 2 disk full) |
| 11 | console status | 22 | create |
| 12 | version (`$22`) | 23 | rename (new name at FCB+16) |
| | | 30 | attributes (bit 7 of FCB bytes 9 and 10: R/O, SYS) |
| | | 33 / 34 | random read / write of record R0-R1 (FCB+33) |
| | | 35 | file size in records -> R0-R1 |
| | | 36 | R0-R1 <- current sequential position |
| 13 | reset the disks | 24 / 25 | drives read (bit 0 = A:) / current drive (0 = A:) |
| 14 | current drive <- A (0-3; `$FF` if missing) | 26 | DMA address (128-byte records) |
| | | 47 | CHAIN: A/Y = command line (0 at the end); does not return |

The FCB has the CP/M 2.2 format on 36 bytes; its byte 0 is the drive (0 = current drive, 1 =
A: ... 4 = D:). A missing or unreadable drive makes the function fail (`$FF`).

**Printer.** CP/A prints on the Oric's Centronics port (BIOS entry LIST, BDOS function 5: A =
character). CTRL-P, typed while entering a line (at the prompt, in LOGO, DEBUG...), or the
Printer item of the System menu, switches on or off the copy to the printer of everything
displayed, as under CP/M (indicator `P` at the end of the bar): CTRL-P then `TYPE README.TXT`
prints the file. While a line is being edited, only the final line is printed (not the
corrections). Without a printer plugged in, nothing hangs: the wait for the acknowledge is
limited to about 2 ms per character. In Oricutron, what is printed is added to the file
`printer_out.txt` in its folder (printer enabled by default). EDIT, which draws its screen
directly, is not copied.

**Chaining two programs.** Function 47 (like CP/M 3's) ends the program and has the CCP run a
line, as if it had been typed: it is shown after `A>` and then run, before the next line of a
DO script in progress. Under CP/M 3 the line is at the DMA; here it is given by A/Y (78
characters at most). Example: LOGO starts `EDIT NAME.LOG /L`, and EDIT comes back with
`LOGO NAME.LOG /R`.

**Random access.** Functions 33 to 36 read and write the 128-byte record whose number is in
R0-R1 (FCB bytes 33 and 34, R2 at 0), without reading everything again from the start. As under
CP/M, the current position does not move on: a sequential read resumes at the same record. Read
return codes: 0, 1 (record never written), 4 (extent does not exist), 6 (out of range). Writing
can create a file with holes; it returns 2 if the disk is full, 5 if the directory is full,
`$FF` if the file is read-only. Function 35 gives the size (number of records, taking holes
into account).

## Disk format

The image is in MFM_DISK format: 2 sides × 42 tracks × 17 sectors of 256 bytes, that is 357 KB.
Sectors are addressed by logical number (LSN): logical track = LSN / 17, cylinder = track / 2,
side = track mod 2.

| LSN | Contents |
|---|---|
| 0-2 | Microdisc boot (fake Oric DOS directory, loader) |
| 3-66 | system (16 KB) |
| 68-1427 | 170 blocks of 2 KB. Blocks 0 and 1 make up the directory: 128 entries in CP/M 2.2 format (EXM=1) |

Writes go through a write-behind buffer. A file must be closed (function 16) for its data and
its directory entry to be up to date on the disk.

## Tools

`tools/mkdisk.py` creates and handles the images from the PC:

    python3 tools/mkdisk.py ls  build/cpa.dsk
    python3 tools/mkdisk.py put build/cpa.dsk myprog.com
    python3 tools/mkdisk.py get build/cpa.dsk NOTES.TXT notes.txt
    python3 tools/mkdisk.py era build/cpa.dsk NOTES.TXT
    python3 tools/mkdisk.py attr build/cpa.dsk NOTES.TXT RO      # RO RW SYS DIR
    python3 tools/mkdisk.py new data.dsk [files...]          # data disk (B: to D:)

Text files (`.ASM`, `.INC`, `.LOG`, `.GRX`, `.TXT`, `.BAT`, `.CFG`, `.DOC`, `.SUB`, `.PRN`,
`.LST`) get CR LF line endings, those of CP/M, from `put` and `new` (so also from `build.sh`): a
file written on the Mac, with LF only, would otherwise show as a staircase in EDIT and TYPE.
Other types are copied as they are.

`tools/mktap.py` makes a `.TAP` on the PC, like MKTAP on the Oric ("Publishing for the Oric
under BASIC").

Pictures and animations made on the PC: `tools/png2hir.py` (PNG or JPEG -> `.HIR`, `.IMG` with
`--split`, `.HIZ` with `--hiz`), `tools/mkanim.py` (GIF -> `.ANI`); see "Full-screen HIRES". The
other tools (building, tests, emulators) are described in `docs/atelier.md` (in French).

## Implementation of the programs

What is useful before changing a program. The system: `docs/systeme.md` (in French).

- **COPY** (like PIP): names collected first (first extent, 128 at most), then copied one by
  one; buffer up to the top of the TPA (`$020C`); attributes not copied; read-only destination
  left alone (`: file protected`); partial copy erased if the disk is full.
- **ERA**: collects and shows the target files, counts the read-only ones (kept: function 19
  spares them), always asks for confirmation (`/Q` for scripts).
- **REN**: without `=`, the order of COPY (`REN old new`); with `=`, that of CP/M 2.2
  (`REN new=old`); refused if the new one exists, if the old one is read-only or not found.
- **SET** takes the drive from the name (`SET B:NAME RO`).
- **Attributes**: R/O protects, SYS hides from DIR; that is all. The commands on the disk
  provided are R/O and visible; the examples have no attribute. Set by `mkdisk.py` (lists in
  `build.sh`).
- **FORMAT** drives the WD1793 itself (the BIOS has no Write Track entry; adding one would touch
  the contract) and keeps `phy_drv` and `dsk_trk` up to date (`src/hw.inc`). Track image
  identical to that of `mkdisk.py` (the LOCI finds the data at a fixed offset from the header),
  6,078 bytes then `$4E`. 2:1 interleave. Each track is read back as soon as it is written
  (verification; on the LOCI, it also resets its wait counter). Positioning with side 1
  selected (otherwise Oricutron reads side 0 again from its old cache). `/Q` goes through the
  BIOS. Same LOCI test as the BIOS (`Drive B: missing or empty`).
- **DISKCOPY** goes through SELDSK, SETSEC, SETDMA, READ, WRITE of the BIOS, in slices as large
  as the TPA. Without `/T`: LSN 0-67 then the blocks named by the directory. `/S`: LSN 0-67 only
  (SYSGEN). Single drive: source and destination asked for at each slice, BDOS buffer flushed
  before the first swap, system disk asked for again at the end.
- **EXPORT, IMPORT, USBDIR** (`progs/loci_inc.s`): the LOCI is recognised by the code its MIA
  places at `$03B0-$03B7`, after operation 0 (when a disk boots, the firmware leaves something
  else there); without a LOCI, these addresses are those of the VIA. Paths without a drive: the
  first mounted stick. Original case taken from `ORIG_LINE`. `^Z` removed on EXPORT, added on
  IMPORT; `/T` changes a lone LF into CR LF and TAB into a space. A `.DSK` is refused on EXPORT
  (it would overwrite the image in use). Transfers in 128-byte records. MIA API
  (`$03A0-$03B9`): `loci-rom/src/asminc/loci.inc`.
- **MKTAP** checks every block (size by function 35, last record read by function 33 to
  remove its `^Z`, ranges, overlaps) before creating the `.TAP`, then copies each file byte by
  byte, record by record. Disk full: the started `.TAP` is erased. The BASIC loader is
  tokenised (`CLOAD` = `$B6`, `CALL` = `$BF`, table of ROM 1.1); its block is one byte longer
  than the program, because the ROM takes the end of the block as the start of the variables.
  `tools/test_mktap.sh`: MKTAP.COM against `mktap.py`, then loading under BASIC 1.1 in
  Oricutron.
- **EDIT**: exactly 8,192 bytes (any addition costs a 2 KB block; 842 bytes of buffers could
  leave the file). `/L`: the Quitter item becomes Retour (back to LOGO).
- **ASM** writes the code during pass 2, record by record (`wput`): memory is only used for the
  symbols. The file is erased if there are errors. `tools/test_asm.sh`: each program of
  `progs/` assembled by ASM.COM must be identical to xa's output.
- **HEX** writes in place (random access); leaving a modified window writes it.
- **EDSPRITE** keeps the whole file in memory and saves it as EDIT does (`NAME.$$$`);
  details in `edsprite.md` § 6.
- **DEBUG** places itself at `$8400-$9FFF` and lowers the top of the TPA (ceiling `$02A9`).
- **POKE, GO** fit in `$0500-$05FF`; POKE decodes everything before writing, from the zero page
  (`$D0-$DD`).
- **STAT** computes the free space from the directory (no function 27).
- **HELP** and README.TXT are produced by `tools/gen_readme_txt.py`, one list per language
  (HELP texts compressed with LZSS).

## Known limits

- Four drives (A: to D:), no user areas.
- COPY does not copy from one disk to another with a single drive: CMDER does.
- Interrupts are off during a sector transfer: a key typed during a disk access may be lost.
- Commands "typed" by a menu go through the keyboard buffer (15 characters at most).
