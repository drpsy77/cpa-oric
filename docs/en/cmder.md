# CMDER — reference

> English translation of `docs/cmder.md`. Screens, menus, questions and messages are those
> of the English disks (`cpa-en.dsk`...); on the French disks (`cpa.dsk`...), CMDER speaks
> French (`docs/cmder.md`), and its answers are `O`, `N`, `T` instead of `Y`, `N`, `A`.

Full-screen file manager: one or two panels, disks A: to D: and the LOCI's USB stick. A list
you can sort and filter, marking, View, Copy, Move, Rename, Erase, Attributes, exact sizes;
copying with a single drive. A `.COM` (13,566 bytes), nothing resident. It is first of all a
tool for listing and sorting; to copy a whole disk, DISKCOPY is faster.

## 1. Starting it

    CMDER                current drive, all files, full screen
    CMDER B:*.COM        drive B:, filter *.COM
    CMDER A: B:          two panels (one pattern per drive: CMDER A:*.COM B:)
    CMDER USB:[path]     the LOCI's USB stick (no path: root of the first stick)
    CMDER A: USB:        two panels, disk and stick (the USB panel left or right)

`CMDER A: A:` is refused (`Two different drives`), and so is `CMDER USB: USB:` (`Only one
USB column`). To load another drive into a
panel: `^L`, or quit and start again. ESC quits: every operation is carried out at once.
Started in SPLIT mode, CMDER switches back to text (the picture is lost).

## 2. Screen

**Full screen** (one panel, or zoom `^Z`):

```
 0 |File Mark Sort View               a  |
 1 |A: *.*     22/40 fls 126K free       |
 2 |  NAME+    TYP    SIZE RS   N KIND   |
 3 |  ANIM     INC   8 832 R    1 Source |
 4 |* ASM      COM   6 144 R    3 Prog   |
   ...
25 |3 marked : 8 064 bytes               |
26 |                                     |
27 |FUNCT menus  SPC mark  ESC quit      |
```

- Line 0: the system menu bar (FUNCT) and indicators. Lines 1-2: header. Lines 3-24: 22 files
  per page (128 entries at most). Line 25: the file under the cursor
  (`ASM.COM : 48 rec, 3 block(s)`) or the total of the marked files. Line 26:
  messages and questions. Line 27: help.
- Columns: mark `*`, name, type, size, `R` (read-only), `S` (system), `N` (rank in the
  directory, the order of DIR), kind (`COM` Prog, `BAT` Script, `GRX` Grapher, `LOG` Logo,
  `ASM`/`INC` Source, `TXT` Text, `CFG` Config, `HIR`/`IMG`/`HIZ` Image, `ANI` Anim, `SYM`
  Symb., `$$$` Temp, `DSK` Disk).
- The sort order is shown by `+` (ascending) or `-` stuck to the column title (`NAME+`,
  `SIZE-`).
- Header: drive, filter, `22/40` when a filter hides files, free space in KB.
- Scroll bar in column 39 (rail `:`, thumb in reverse video) when the list is longer than
  the screen.
- Colours: titles (line 2) cyan paper, black ink; lines 25-26 blue paper, white ink; the rest
  keeps the user's colours (`PAPER`, `INK`). Constants at the top of the source.

**Two panels**: two columns of 18 characters (mark, name, type, size in KB); column 20 is the
scroll bar of the left panel, column 39 that of the right one. Header: `A:*.*#        112K`
(`#`: "Not on other" is on), in reverse video for the active
panel, which alone shows its cursor. Lines 25-26: active panel. Each panel keeps its own
drive, filter, sort order, marks and cursor.

**USB panel**: header `USB:GAMES/` (current directory only; `USB:?` if the LOCI is missing or
the stick unreadable, `+` after the number of files if the list is cut at 128). `..` (except at
the root) and the subdirectories (`<DIR>`) come first, whatever the sort order. Long names are
cut with `~` (12 characters in two panels, 26 in full screen).

## 3. Sizes

The CP/M directory only counts 128-byte records: CMDER shows `records × 128` straight away
(exact for binaries). **Exact sizes** (`^E`) applies STAT's rule (the `^Z` of the last record
removed): one read per file, a few seconds on a real Microdisc (ESC stops it); kept until the
directory is read again. Files of more than 16 KB (several entries) are grouped into one line.
On the stick: exact size, and the blocks the file would take on a disk.

## 4. Keys

| Key | Effect |
|---|---|
| ↑ ↓ | previous / next file |
| ← →, SHIFT-↑ SHIFT-↓ | previous / next page |
| `<` `>`, CTRL-↑ CTRL-↓ | first / last file |
| A-Z | next file whose name starts with that letter |
| SPACE | mark / unmark, then move down |
| `+` `-` | mark / unmark by pattern (RETURN alone = `*.*`) |
| `*` | invert the marks |
| 1 2 3 4 | sort by disk order, name, type, size; the same key reverses the order |
| `/` | filter (RETURN alone = no filter) |
| RETURN | View; on `<DIR>`: enter; on `..`: go up |
| DEL | Erase |
| `^C` | Copy... |
| `^X` | Move... |
| `^N` | Rename... |
| `^A` | Attributes... |
| `?` | Info (exact size, blocks) |
| `^E` | Exact sizes |
| `^L` | Drive... (active panel) |
| `^R` | Read the directory again (after changing disks) |
| `^I` (CTRL-I) | other panel |
| `^Z` | zoom: active panel in full screen, and back (`^I` shows the other one there) |
| `^W` | swap the two panels |
| FUNCT | menus |
| ESC, `^Q` | quit; in a question, ESC cancels |

Keys shared with EDIT and HEX (`manuel.md`, "The same keys everywhere"); `^M` (RETURN),
`^T` and `^P` (system) are not used. `^C` does not quit. **Operations apply to the marked
files, or to the file under the cursor if none is marked.** A pattern without a dot covers
all types (`LO*` = `LO*.*`). When keys are equal, files are sorted by name, A to Z.

## 5. Menus

The items type codes (`$81-$98`): an item and its shortcut go through the same dispatch; the
shortcut is written to the right of the label.

- **File**: View RET, Copy... ^C, Copy as text..., Move... ^X, Rename... ^N, Erase DEL,
  Attributes... ^A, Info ?, Print list, Drive... ^L, Reread ^R, Quit ^Q (or ESC).
- **Mark**: Mark SPC, Mark... +, Unmark... -, Invert *, All, None.
- **Sort**: Disk order 1, Name 2, Type 3, Size 4.
- **View**: Filter... /, No filter, Hide SYS (becomes Show SYS), Exact size ^E, Not on
  other, Zoom ^Z, Swap ^W, Other col. ^I.

## 6. Operations

Questions and input on line 26, through CMDER's own input line (proposed text you can edit,
ESC cancels): BDOS function 10 does not fit (ESC completes file names there).

- **View**: text in pages of 26 lines, cut at 38 columns, stops at `^Z`; non-printable
  characters shown as `.`; a lone LF line ending is understood. The user's colours come back
  during the display. For binaries: HEX.
- **Erase**: `Erase 3 files (Y/N) ?`; a read-only file is skipped;
  summary at the end.
- **Rename**: one file only; the current name is proposed; `Name already used`,
  `File protected (R/O)`.
- **Attributes**: `R`, `S`, `RS` or nothing, proposed from the file under the cursor, applied
  to every target file (function 30).
- **Copy**: the question proposes the drive of the other panel (`Copy 3 files to : B:`);
  any drive, or a name (`B:NAME.EXT`, one file only) is possible. Progress
  `Copy : NAME.EXT (3/12)`. File already there: `Replace NAME.EXT (Y/N/A) ?` (yes, no,
  all); read-only at the destination: skipped. The R/O and SYS attributes are copied
  (unlike COPY). Disk full: the file being written is erased and the copy stops. ESC between
  two files or two slices. A copied file loses its mark: after a stop, the remaining marks
  show what is left. **Space**: towards a disk, the blocks needed (minus those of the files
  replaced) are compared with the free space: `Free 14K, needed 18K : Y/N ?`.
- **Move**: same drive and another name = rename; another drive = copy, then erase the
  original if the copy succeeded; refused at once if an original is read-only.
- **Single drive** (destination = drive of the list): read into the buffer (up to 32 slices),
  then `DESTINATION in A:, press a key`, write, `SOURCE in A:, press a key`... A disk
  identical to the source asks `Same as the source : go on (Y/N) ?`. At the end,
  `SOURCE in A:, press a key (ESC : stay)`: ESC keeps the destination disk (not for Move).
- **Missing from the other** (toggle per panel): shows only the files missing from the other
  panel, or present there with another size or other attributes (without reading the
  contents; with the stick: 8.3 name and size). `All` then `^C`: synchronisation.
- **Print the list**: active panel, in the full-screen format, through function 5.
- **Disk errors**: `Disk error : check the disk` on line 26, without the BDOS message;
  during a single-drive copy, the same disk is asked for again (`Error, DESTINATION in
  A:...`).

After every operation: directory (or directories) read again, cursor kept on the same file.

**USB stick**: a gateway, the real medium remains the disk. Copy in both directions (like
EXPORT and IMPORT: `^Z` removed when sending, added on arrival, names brought down to 8 + 3
with `_` for a forbidden character, `.DSK` refused when sending, file on the stick replaced
without asking). `/T` at the end of the Copy answer (or `Copy as text...`) turns a lone LF into
CR LF and a tab (TAB) into a space. Move from a disk to the stick, not the other way. Erase,
Rename, Attributes refused: `USB key : read and copy only`. No copy of a whole directory.

## 7. Implementation

- `progs/cmder.s`, with `progs/loci_inc.s` (USB stick); zero page outside `$30-$3B` (the area
  of `loci_inc.s`).
- **Texts**: menu bar, messages, column titles, kind names and the column of the sort sign
  (`spos`, `spos2`) are in `progs/msg/en/cmder.msg` and `progs/msg/fr/cmder.msg`
  (French disks: `Fichier Marque Trier Vue`, columns `NOM TYP TAILLE RS N GENRE`, answers
  `O`, `N`, `T`). The attribute letters (`R`, `S`), `USB:` and the `/T` option are the same in both
  languages.
- **File table**: 128 × 24 bytes, filled by functions 17/18 with `?` everywhere (all
  entries, extents included, in directory order); entries of the same file grouped by name
  (records = the largest `EX × 128 + RC`, blocks = sum). Two panels: the state of the active
  panel (zero page `$25-$2F`, filter, visible list, table) is in its usual place, that of the
  other in a second area of the same shape; `pswap` swaps them. `ent_ptr` and `vis_ptr` read a
  table through a pointer. Only the active panel is redrawn when the cursor moves.
- **Stick**: 8 + 3 name in the table, long name (26 characters) in a separate area; the full
  name is read again from the stick to open the file. Copy file by file. `path_up`: `FILES`
  goes up to `/`, `1:REP` to `1:`, `A/B` to `A`; `is_root` recognises empty, `/`, `1:`, `1:/`.
- **Copy**: a single mechanism, in slices (the following files are read into the buffer, the
  rest of the TPA, then written). Single drive: function 13 before each swap; a file in
  progress is closed (function 16, checkpoint) then resumed with the same FCB. A
  **fingerprint** of each disk's directory (checksums and number of entries), redone after
  each write: the wrong disk is refused.
- **Errors**: CMDER sets `IO_QUIET` (`$FDAC`) during its accesses; the BDOS displays nothing
  and sets bit 7; CMDER reads it after each operation. `IO_QUIET` is reset to 0 before each
  exit.
- Direct display into `$BB80`, keys through the BIOS CONIN (like EDIT).
- Memory: CMDER.COM, two tables (2 × 3 KB), copy buffer about 25 KB.

## 8. Later

- A file comparison program, separate.
- Open a file in EDIT or HEX, then come back to CMDER (CHAIN and a script, like LOGO's
  `EDIT`).
