# CMDER — reference

> English translation of `docs/cmder.md`. On `cpa.dsk`, CMDER speaks French: menus,
> questions and messages are quoted as they appear there, with in brackets the English text
> shown on `cpa-en.dsk` (or their meaning). On `cpa-en.dsk` the screen reads `NAME TYP SIZE
> RS N KIND`, the answers are `Y` (yes), `N` (no) and `A` (all).

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

`CMDER A: A:` is refused (`Deux lecteurs differents`, two different drives needed), and so is
`CMDER USB: USB:` (`Une seule colonne USB`, only one USB panel). To load another drive into a
panel: `^L`, or quit and start again. ESC quits: every operation is carried out at once.
Started in SPLIT mode, CMDER switches back to text (the picture is lost).

## 2. Screen

**Full screen** (one panel, or zoom `^Z`):

```
 0 |Fichier Marque Trier Vue          a  |
 1 |A: *.*     22/40 fic 126K libre      |
 2 |  NOM+     TYP  TAILLE RS   N GENRE  |
 3 |  ANIM     INC   8 832 R    1 Source |
 4 |* ASM      COM   6 144 R    3 Prog   |
   ...
25 |3 marques : 8 064 o                  |
26 |                                     |
27 |FUNCT menus  ESP marque  ESC fin     |
```

- Line 0: the system menu bar (FUNCT) and indicators. Lines 1-2: header. Lines 3-24: 22 files
  per page (128 entries at most). Line 25: the file under the cursor
  (`ASM.COM : 48 enr., 3 bloc(s)`: records, blocks) or the total of the marked files. Line 26:
  messages and questions. Line 27: help.
- Columns: mark `*`, name, type, size, `R` (read-only), `S` (system), `N` (rank in the
  directory, the order of DIR), kind (`COM` Prog, `BAT` Script, `GRX` Grapher, `LOG` Logo,
  `ASM`/`INC` Source, `TXT` Texte, `CFG` Config, `HIR`/`IMG`/`HIZ` Image, `ANI` Anim, `SYM`
  Symboles, `$$$` Tempo).
- The sort order is shown by `+` (ascending) or `-` stuck to the column title (`NOM+`,
  `TAILLE-`).
- Header: drive, filter, `22/40` when a filter hides files, free space in KB.
- Scroll bar in column 39 (rail `:`, thumb in reverse video) when the list is longer than
  the screen.
- Colours: titles (line 2) cyan paper, black ink; lines 25-26 blue paper, white ink; the rest
  keeps the user's colours (`PAPER`, `INK`). Constants at the top of the source.

**Two panels**: two columns of 18 characters (mark, name, type, size in KB); column 20 is the
scroll bar of the left panel, column 39 that of the right one. Header: `A:*.*#        112K`
(`#`: "Absents de l'autre" [missing from the other] is on), in reverse video for the active
panel, which alone shows its cursor. Lines 25-26: active panel. Each panel keeps its own
drive, filter, sort order, marks and cursor.

**USB panel**: header `USB:JEUX/` (current directory only; `USB:?` if the LOCI is missing or
the stick unreadable, `+` after the number of files if the list is cut at 128). `..` (except at
the root) and the subdirectories (`<REP>`) come first, whatever the sort order. Long names are
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
| RETURN | View; on `<REP>`: enter; on `..`: go up |
| DEL | Erase |
| `^C` | Copy... |
| `^X` | Move... |
| `^N` | Rename... |
| `^A` | Attributes... |
| `?` | Info (exact size, blocks) |
| `^E` | Exact sizes |
| `^L` | Drive... (active panel) |
| `^R` | Read the directory again (after changing disks) |
| TAB (`^I`) | other panel |
| `^Z` | zoom: active panel in full screen, and back (TAB shows the other one there) |
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

- **Fichier** [File]: Voir RET [View], Copier... ^C [Copy...], Copier texte... [Copy as
  text...], Deplacer... ^X [Move...], Renommer... ^N [Rename...], Effacer DEL [Erase],
  Attributs... ^A [Attributes...], Infos ? [Info], Imprimer liste [Print list], Lecteur... ^L
  [Drive...], Relire ^R [Reread], Quitter ^Q [Quit] (or ESC).
- **Marque** [Mark]: Marquer ESP [Mark SPC], Marquer... + [Mark...], Oter... - [Unmark...],
  Inverser * [Invert], Tout [All], Rien [None].
- **Trier** [Sort]: Ordre disque 1 [Disk order], Nom 2 [Name], Type 3, Taille 4 [Size].
- **Vue** [View]: Filtrer... / [Filter...], Sans filtre [No filter], Cacher SYS [Hide SYS]
  (becomes Montrer SYS [Show SYS]), Taille exacte ^E [Exact size], Absents autre [Not on
  other], Zoom ^Z, Echanger ^W [Swap], Autre col. TAB [Other col.].

## 6. Operations

Questions and input on line 26, through CMDER's own input line (proposed text you can edit,
ESC cancels): BDOS function 10 does not fit (ESC completes file names there).

- **View**: text in pages of 26 lines, cut at 38 columns, stops at `^Z`; non-printable
  characters shown as `.`; a lone LF line ending is understood. The user's colours come back
  during the display. For binaries: HEX.
- **Erase**: `Effacer 3 fichiers (O/N) ?` (erase 3 files, yes/no); a read-only file is skipped;
  summary at the end.
- **Rename**: one file only; the current name is proposed; `Nom deja pris` (name already
  taken), `Fichier protege` (file protected).
- **Attributes**: `R`, `S`, `RS` or nothing, proposed from the file under the cursor, applied
  to every target file (function 30).
- **Copy**: the question proposes the drive of the other panel (`Copier 3 fichiers vers : B:`);
  any drive, or a name (`B:NAME.EXT`, one file only) is possible. Progress
  `Copie : NAME.EXT (3/12)`. File already there: `Remplacer NAME.EXT (O/N/T) ?` (replace:
  yes/no/all); read-only at the destination: skipped. The R/O and SYS attributes are copied
  (unlike COPY). Disk full: the file being written is erased and the copy stops. ESC between
  two files or two slices. A copied file loses its mark: after a stop, the remaining marks
  show what is left. **Space**: towards a disk, the blocks needed (minus those of the files
  replaced) are compared with the free space: `Libre 14K, requis 18K : O/N ?` (free 14K,
  needed 18K).
- **Move**: same drive and another name = rename; another drive = copy, then erase the
  original if the copy succeeded; refused at once if an original is read-only.
- **Single drive** (destination = drive of the list): read into the buffer (up to 32 slices),
  then `DESTINATION en A:, une touche` (destination disk in A:, press a key), write,
  `SOURCE en A:, une touche`... A disk identical to the source asks
  `Comme la source : continuer (O/N) ?` (same as the source: continue?). At the end,
  `SOURCE en A:, une touche (ESC : rester)`: ESC keeps the destination disk (not for Move).
- **Missing from the other** (toggle per panel): shows only the files missing from the other
  panel, or present there with another size or other attributes (without reading the
  contents; with the stick: 8.3 name and size). `Tout` [All] then `^C`: synchronisation.
- **Print the list**: active panel, in the full-screen format, through function 5.
- **Disk errors**: `Erreur disque : verifiez la disquette` (disk error: check the disk) on
  line 26, without the BDOS message; during a single-drive copy, the same disk is asked for
  again (`Erreur, DESTINATION en A:...`).

After every operation: directory (or directories) read again, cursor kept on the same file.

**USB stick**: a gateway, the real medium remains the disk. Copy in both directions (like
EXPORT and IMPORT: `^Z` removed when sending, added on arrival, names brought down to 8 + 3
with `_` for a forbidden character, `.DSK` refused when sending, file on the stick replaced
without asking). `/T` at the end of the Copy answer (or `Copier texte...`) turns a lone LF into
CR LF and a tab (TAB) into a space. Move from a disk to the stick, not the other way. Erase,
Rename, Attributes refused: `Cle USB : lecture et copie seulement` (USB stick: read and copy
only). No copy of a whole directory.

## 7. Implementation

- `progs/cmder.s`, with `progs/loci_inc.s` (USB stick); zero page outside `$30-$3B` (the area
  of `loci_inc.s`).
- **Texts**: menu bar, messages, column titles, kind names and the column of the sort sign
  (`spos`, `spos2`) are in `progs/msg/fr/cmder.msg` and `progs/msg/en/cmder.msg`
  (`cpa-en.dsk`: `File Mark Sort View`, columns `NAME TYP SIZE RS N KIND`, answers `Y`, `N`,
  `A`). The attribute letters (`R`, `S`), `USB:` and the `/T` option are the same in both
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
  `EDITE`).
