# CP/A — architecture and interface contract

English translation of `docs/architecture.md` (the French document is the reference; the other documents it points to are in French unless an English version exists in `docs/en/`).

This document is the reference of CP/A: a system loaded from a disk (`build/cpa.dsk`) into
the overlay RAM, extended by `.COM` programs — status in `docs/etat.md`. The 16 KB ROM
version of the early days is abandoned: the major commands are `.COM` files that would not
fit in it, and a program for an Oric on its own is made with `GRXASM /O` and a `.TAP`
(`docs/oric-basic.md`). The contract below is what the programs already written expect: it
does not change without agreement.

## 1. The layers

| Layer | Role | Where |
|---|---|---|
| BIOS | hardware: keyboard, screen, console, 50 Hz IRQ, recovery after a crash, disk, serial port and remote console | `src/bios.s`, `src/disk.s`, `src/serial.s` |
| BDOS | numbered services as in CP/M 2.2 (`JSR $0203`, X = function) | `src/bdos.s`, `src/fs.s`, `src/gfx.s`, `src/snd.s` |
| CCP | `A>` prompt and built-in commands (the line is read by `src/rline.s`, BDOS 10) | `src/ccp.s`, `src/ccp_gfx.s`, `src/ccp_disk.s`, `src/put.s`, `src/script.s` |
| Menus | drop-down menu bar (FUNCT) | `src/menu.s` |
| Programs | `.COM` files loaded at `$0500` (a name without `.COM` falls back to the `.BAT` script) | `progs/*.s` |

**Placement rule** (for any new function):

1. Whatever touches the hardware or must run under interrupt → **BIOS**.
2. A service that several programs will use (graphics, sound, files) → **BDOS**, with a
   function number and a parameter block `[op, p1..p5]` like functions 115 and 116.
3. A command that is instantaneous or useful in scripts → **CCP** (built-in command), only if
   space allows.
4. Everything else → **`.COM` program**: it costs nothing as long as it is not
   run.

## 2. Interface contract (identical in both versions)

### BIOS table (`$C000`, 3 bytes per entry)

`$C000` BOOT, `$C003` WBOOT, `$C006` CONST, `$C009` CONIN, `$C00C` CONOUT, `$C00F` LIST,
`$C012` PUNCH, `$C015` READER, `$C018` HOME, `$C01B` SELDSK, `$C01E` SETTRK, `$C021` SETSEC,
`$C024` SETDMA, `$C027` READ, `$C02A` WRITE, `$C02D` MENUBAR. Disk version: SELDSK
takes A = drive (0-3) and returns A = 0, or `$FF` if the drive is missing or unreadable; READ and
WRITE act on that drive, even if unreadable (this is how FORMAT writes the directory of a
disk it has just formatted); SETSEC takes a logical sector from 0 to 2,719.

Existing entries never move; a new entry is added at the end (`$C030`…).
LIST prints A on the Centronics port (VIA port A, strobe PB4, CA1 acknowledge awaited 2 ms at
most; Oricutron writes to `printer_out.txt`). PUNCH and READER: serial port
(`SERIE` option; port set by function 117). PUNCH sends A,
waits at most 5 s for the transmitter to be free and returns A = 0, C = 0 (sent) or A = `$FF`, C = 1 (not
sent, or no port). READER waits for a byte and returns it in A; `$1A` (^Z) at once
if no port is set or if the remote console is active, and as soon as a key is
typed (it stays in the buffer). Without the serial driver: PUNCH does nothing, READER returns
`$1A`.

### Keyboard codes (CONIN, functions 1, 6, 10)

ASCII; DEL `$7F`; arrows `$08` left, `$09` right, `$0A` down, `$0B` up; with SHIFT
`$F0-$F3`, with CTRL `$F4-$F7` (same order). CTRL + letter: 1-26, except CTRL-H to CTRL-K:
28-31 (TAB = CTRL-I = 29); CTRL-SPACE and CTRL-@: 0; CTRL-[: 27; CTRL with any other
key: nothing. FUNCT: menus (codes `$81` and up, chosen by the program).

### Vectors and page 2

| Address | Contents |
|---|---|
| `$0200` / `$0203` | `JMP WBOOT` / `JMP BDOS` |
| `$0206` / `$0209` | `JMP` IRQ / NMI, can be redirected (DEBUG uses this) |
| `$020C` | top of the TPA (word): `$B400` in text mode, `$A000` in SPLIT, less if a ceiling is set |
| `$020E` | `SCR_PROG`: 1 = a program has the whole text screen (LORES); the console is silent (no menus, no indicators, FUNCT and CTRL-T have no effect); reset to 0 on warm boot |
| `$0210-$0214` | console: cursor X, Y, visible, active, blinking |
| `$021B` | 50 Hz counter (word) |
| `$02A3` | 1 = pause at end of screen |
| `$02A9` | TPA ceiling (page; 0 = none), reset to 0 on warm boot |
| `$0244` | 1 = a line left by CHAIN is waiting in `$0400` (internal to the system) |
| `$0245` | printer: bit 0 = CTRL-P active, bit 7 = suspended while a line is being edited (internal) |

The other page 2 variables are internal (full list, page 3 included: `docs/memoire-pages-2-3.md`). The public
part is in `progs/cpa.inc`, which every program includes.

### BDOS functions

| No. | Function |
|---|---|
| 0-12 | console and system, as in CP/M 2.2 (3 and 4: the BIOS READER and PUNCH; 5 prints on the Centronics port); 10 edits the line (arrows, insertion, history; file name completion by TAB or ESC; CTRL-C there does a warm boot only on an empty line at the CCP prompt), 126 characters at most |
| 13-25, 30, 33-36 | files (CP/M 2.2, random access, attributes); drives A: to D: (FCB byte 0: 0 = current, 1 = A:...; 14 selects the current drive, 24 returns the logged-in drives, 25 the current drive); the directory entries returned by 17 and 18 are those of the disk format (§ 2, "Disk") |
| 26 | DMA address |
| 47 | CHAIN (as in CP/M 3): A/Y = command line terminated by 0 (78 characters at most), executed by the CCP after a warm boot; does not return |
| 115 | SPLIT mode graphics: block `[op, p1..p5]`, op 0-13 |
| 116 | AY-3-8912 sound: block `[op, p1..p5]`, op 0-8 (7 SYNC: simultaneous start of the voices, 8 MIXER: tone and noise of a voice) |
| 117 | serial port and remote console: block `[op, p1..p5]`; op 0 status -> A (bit 0 port set, bit 1 console active, bit 2 link lost), X = low byte of the port; op 1 sets the port (p1 = low byte: `$80` LOCI, `$1C` Oricutron, 0 none); op 2 console on (`$FF` without a port); op 3 off (`docs/en/console-distance.md`) |

Numbers free for the future: 37-46, 48-114 and 118 onwards. A function tied to a build
option (`SERIE`) keeps its number and returns `$FF` when the option is absent.

### Disk

2 sides × 80 tracks × 17 sectors of 256 bytes (2,720 logical sectors, MFM_DISK image of
1 MB), 2 KB blocks: 331 blocks, 2 of which hold the 128-entry directory. Entry
format: that of CP/M 2.2 beyond 255 blocks (8 block numbers on 16 bits, low byte
first; one entry = one 16 KB extent, EX = its number, RC = its records).
Entry 0: format label (byte 0 = `$20`, then `CPA-2X80-2K`), invisible to the BDOS;
a disk without it is refused. Constants `D_NCYL`, `D_NSECT`, `D_DIRLSN`, `D_NBLK`
in `progs/cpa.inc`; details in `docs/systeme.md` § 3. 42-track disks (blocks
numbered on 8 bits) are no longer read: `tools/mkdisk.py conv` copies them to the new
format.

### `.COM` programs

- Loaded and started at `$0500` by `JSR`; return by `RTS` or `JMP $0200`.
- Base page at `$0400`: FCB1 `$045C`, FCB2 `$046C`, parameters and DMA `$0480`.
- Free zero page: `$0000-$00DF` (`$E0-$FF` belong to the system; DEBUG swaps `$D0-$DF`).
- A program respects the top of the TPA (`$020C`) instead of a fixed address.

## 3. Memory map

| Area | Contents |
|---|---|
| `$0000-$04FF` | zero page, stack, page 2 (system), base page |
| `$0500-$B3FF` | TPA (programs); `$A000-$B3FF` = picture in SPLIT; in full-screen HIRES (program with `progs/hires.inc`), picture `$A000-$BF3F`, which also covers the font, the `$B800-$BB7F` areas and the text screen |
| `$B400-$BFDF` | `$B400-$B4FF`: addresses of the SPLIT mode pixel rows (`g_ylo`, `g_yhi`), computed by `font_init` in place of the glyphs of codes 0-31 (attributes, never displayed); font, secondary font (`$B800-$B9FF`: menu save area, and names already seen during an ESC completion; `$BA00-$BA7F`: line being edited; `$BA80-$BB7F`: line history), text screen |
| `$C000-$FFFF` | overlay RAM loaded from the disk: code up to `$F5C8` at most (`SYS_END`; actual end: `rom_end`, shown by `./build.sh`), then allocation maps of the 4 drives (`ALV`, `$F5C8-$F66F`), buffers (command line `$F670`, DO `$F6C0`), window `$F7C0-$FCFF` (one bank at a time at `$F7C0-$F9FF`: PUT, loaded with the system, or IMG, read from `CPA.BNK` when it is needed; or GFX, the SPLIT drawing routines, up to `$FBFF` over the PUT buffer; PUT buffer `$FA00`; cold boot; `docs/systeme.md` § 6), BDOS variables `$FD00` (`$FD00-$FD03`: BDOS block and count, `$FD04-$FD12`: banks, `$FD13-$FD21`: serial driver, `$FD22`: `gfx_ko`, `$FD23-$FD26`: serial driver ceilings, `$FD27-$FD57`: serial driver redial and checksum limit, then variables; `win_id` `$FDF8`: contents of the window; free: `$FDFC-$FDFF`), sector buffer `$FE00`, page `$FF00-$FFF9` loaded with the system (tables `src/tables_ff.s`, `rl_keys.s`, `menu_col.s` up to `$FFEF`, then free; it only receives data or self-contained routines, since it is not contiguous with the code), vectors `$FFFA` |

## 4. Building and testing

Full details (tools, scenarios, installation on a Raspberry Pi): `docs/atelier.md`.

    ./tools/setup_linux.sh [roms]    # once, on Linux: xa, py65, test Oricutron
    ./build.sh                       # build/cpa.dsk and the other disks (+ size checks)
    tools/smoke_test.sh              # build + disk boot in the emulator
    tools/test_asm.sh                # ASM.COM must give back the bytes of xa
    tools/test_logo.sh               # LOGO.COM: scenarios compared with the references
    tools/test_grapher.sh            # GRAPHER.COM, GRXASM.COM: calculations, loops, errors (no emulator)
    LANGUE=en tools/test_grapher.sh  # the same in English, against the translated references
    tools/test_inc.sh                # slimmed-down disk libraries == originals
    tools/test_lib.sh                # GRX.LIB (precompiled): same translated programs as through the .INCs
    tools/test_exemples_en.sh        # translated .GRX examples: same code as the originals
    python3 tools/test_fp.py         # decimals (progs/fp_inc.s) against an exact calculation
    python3 tools/test_anim.py       # .HIZ pictures and .ANI animations (h_unz, VOIR)
    python3 tools/pf_mesure.py --ecrire   # measurements and totals of docs/points-de-fonction.md
    python3 tools/test_fichiers.py   # EDIT, GRAPHER: disk full, R/O, RESET during writing
    tools/test_mktap.sh              # MKTAP.COM == tools/mktap.py, then CLOAD under BASIC 1.1
    python3 tools/test_bas.py        # .BAS: mktap.py encoding == ROM 1.1 (simulated 6502)
    tools/test_oric.sh               # GRXASM /O, ASM /T: refusals, .TAP under BASIC 1.1 (build/tap/)
    tools/test_xfer.sh               # XFER.COM and xfer_server.py in Oricutron (simulated modem)
    tools/test_remote.sh             # remote console: driver, REMOTE, remote.py (~6 min)
    python3 tools/test_fdc.py        # disk driver: controller that stops responding (simulated 6502)
    python3 tools/test_fs.py         # files: end of file, appending after the end (simulated 6502)

- `build.sh` refuses a disk system that goes beyond `SYS_END` (`$F5C8`), a window that overflows (PUT after
  `$FA00`, cold boot after `$FD00`; through `tools/mkbnk.py`: IMG after `$FA00`, GFX after
  `GFX_END`), a `$FF00` page that reaches the vectors (`$FFFA`);
  it shows the margins.
- Tests in Oricutron: `tools/run_test.sh` (simulated typing and memory dump, with the patch
  `tools/oricutron-testhook.patch`; `DSK=` for the disk) and
  `tools/screen.py` (screen text).
- `tools/run_com.py` runs a `.COM` in a simulated 6502 with a minimal BDOS (no screen).
- Hardware: tried on Oric Atmos + LOCI. The menu colours look
  better on a real screen than in some emulators.

**Which tests for which change** (in proportion to the risk; `test_logo.sh` takes ~25 min):

| Change | Tests |
|---|---|
| Always | `./build.sh` (size, margin) and `tools/test_asm.sh` |
| System (BIOS, BDOS, CCP, menus) | in addition: Oricutron trial targeted at what changes, `tools/smoke_test.sh` |
| LOGO.COM, `fp_inc.s`, `ltxt_inc.s`, or BDOS functions 10, 47, 115, 116 | in addition: `tools/test_logo.sh` |
| `fp_inc.s` | in addition: `python3 tools/test_fp.py` |
| MKTAP.COM, `tools/mktap.py`, `progs/bas_tab.s` | in addition: `tools/test_mktap.sh` (also runs `tools/test_bas.py`) |
| ASM.COM (`/T` option) | in addition: `tools/test_oric.sh` |
| ASM.COM (`#lib`), GRXASM.COM (`kb_lib`), `tools/mk_lib.py`, a library of translated programs | in addition: `tools/test_lib.sh` (~30 min; names as arguments for a targeted run) |
| XFER.COM, TERM.COM, `acia_inc.s`, `tools/xfer_server.py` | in addition: `tools/test_xfer.sh` (~4 min); for TERM, Oricutron trial in loopback (`serial = 'loopback'`) |
| `src/serial.s`, REMOTE.COM, `tools/remote.py`, function 117, PUNCH, READER | in addition: `tools/test_remote.sh` (~6 min) and `tools/test_xfer.sh` |
| GRAPHER.COM, GRXASM.COM (`grx*_inc.s`, `arr.inc`, `fil.inc`, `spr.inc`), `hires.inc`, `oric.inc` | in addition: `tools/test_grapher.sh` (and `LANGUE=en` if a message changes), `tools/test_inc.sh`, `tools/test_oric.sh`, Oricutron trial of the `.GRX` examples (drawing) |
| EDIT (opening, saving), `fil.inc`, `src/fs.s`, `src/disk.s` | in addition: `python3 tools/test_fichiers.py` (~10 min; `--vite` for a looser sweep); for `src/disk.s`, also `python3 tools/test_fdc.py` |
| VOIR.COM, `hires.inc` (`h_unz`), `anim.inc`, `lzhir.py` | in addition: `python3 tools/test_anim.py` (pictures and animations in the simulated 6502) |
| Before a release commit, or on request | everything |

## 5. Conventions

- `progs/*_tab.s` files (tables) and `progs/*_inc.s` files (libraries): included by a
  program, never assembled on their own. `progs/hires.inc` is a library shipped on the
  disks (`HIRES.INC`, 8.3 name for ASM); its internal labels start with `hz_`
  so as not to get in the way of any program. `progs/grx.inc` (`GRX.INC`) is the runtime library
  of the programs translated by `GRXASM NOM` (or `GRAPHER NOM /A`); `progs/oric.inc`
  (`ORIC.INC`) replaces `CPA.INC` for those translated for a bare Oric
  (`GRXASM NOM /O`: `.TAP` without CP/A, `docs/en/grapher.md` § 12.1). `progs/arr.inc` (`ARR.INC`,
  arrays), `progs/fil.inc` (`FIL.INC`, data files) and `progs/spr.inc` (`SPR.INC`,
  text-mode sprites) serve the interpreter and the translated programs. `progs/anim.inc` (`ANIM.INC`) plays
  `.ANI` animations; it is included before `HIRES.INC`, which stays at the end of the program (its
  tables follow `h_end`), and also uses the internal `hz_` labels.
- Screen owned by the program. Full-screen HIRES: a convention, not a function of the contract. A program that puts `$1E`
  at `$BFDF` outside SPLIT mode has the screen to itself; the system recognises it (`hires_on`) and
  draws nothing on it (FUNCT ignored, indicators, cursor turned off by the program); the warm
  boot restores the text, the font and an empty history.
  Text screen (LORES, `h_lores` in `hires.inc`): `SCR_PROG` (`$020E`) set to 1, same effects
  (FUNCT and CTRL-T reach the program as keys); `h_text` and the warm boot
  give the console back.
- Display and PUT: a program whose output must be capturable by
  `PUT fichier programme` displays through the BDOS (functions 2 and 9), not through the BIOS CONOUT
  (`B_CONOUT`): the BDOS entry flushes the PUT buffer (768 bytes). With CONOUT alone, whatever
  overflows the buffer between two BDOS calls is lost (`PUT: end lost`).
- Assembler: OSDK `xa` syntax. The programs in `progs/` stay within the subset
  understood by ASM.COM (no `&label`, no `#define`): `tools/test_asm.sh` checks this.
  The system (`src/`) may use all of `xa`.
- `xa` pitfalls: a block-local label `.( .)` cannot have the name of a
  global label already defined; no label named like an instruction; branches
  limited to ±127 bytes (go through a `JMP`).
- Text on screen: ASCII without accents, 37 columns at most for a full line (the 38th
  causes an extra automatic line break). CCP messages in short English; menus,
  help and programs in French on `cpa.dsk`, in English on `cpa-en.dsk` (below).
- Comments and documentation in French.
- **Two languages**: everything produced, system included, exists
  in French and in English (`cpa.dsk`, `cpa-en.dsk`). System: menu bar and console
  messages in `src/msg/fr/sys.msg` or `src/msg/en/sys.msg` (same labels);
  `build.sh` assembles `cpa_sys.bin` and `cpa_sys_en.bin` and checks the margin of both (the
  French one, being longer, is the constraint); the short CCP messages are in English
  in both.
- Program messages in two languages: each translated program includes its messages
  (`#include "nom.msg"`, name of 8 characters at most for ASM), taken from `progs/msg/fr/`
  or `progs/msg/en/` (same labels; the "yes" key is the constant `K_YES`, `O` or
  `Y`). `build.sh` assembles twice: `build/progs` (French, `-I msg/fr`) and
  `build/progs-en` (`-I msg/en -I msg/fr`: a program not yet translated keeps its
  French messages), then `cpa-en.dsk`. Since ASM has only one level of inclusion, a
  library contains no `#include`: the program includes the messages of
  `loci_inc.s` (`loci.msg`) just before it. A program's menus (FUNCT) are in
  its messages file, width included; the other answer keys also have their
  constant (`K_ALL`, "all": `T` or `A`). Shipped files that have an English
  version are in `files/en/`, under their English name in lower case (except when one
  name has a different content on each disk: the welcome screen, `ACCUEIL.TXT`, in
  `files/accueil/NAME/` and `files/en/accueil/`, third column of `files/en/noms.txt`).
- **Twin disks**: each French disk has its English twin (`cpa-en.dsk`,
  `cpa-logo-en.dsk`... `cpa-project-en.dsk`), made by the same line of `build.sh`
  (`disque`). `files/en/noms.txt` gives the English name of each shipped file;
  `tools/en_files.py` derives from it the files of the English disk (programs from `build/progs-en`,
  libraries from `build/src-en`, translated examples) and refuses an example without a translation;
  `--jumelles` checks, at each build, that the English disk has the files of the French one
  (translated names, same attributes). A translated example keeps the code of the original: only the
  comments, the displayed texts and the names (subroutines, procedures, files mentioned)
  change, at the same screen columns; `tools/test_exemples_en.sh` checks this for the
  `.GRX` files (same `.ASM` through GRXASM). A change to one is carried over to the other. The English `.LOG`
  files are converted to the English primitives by LOGOTR (`logo.md`). The English `HELLO.ASM` and
  `GTEST.ASM` (`files/en/*.asm`) give the `.COM` files of `build/progs-en`
  (`tools/test_asm.sh` also assembles them with ASM.COM).
- Help: `tools/gen_readme_txt.py` produces both README.TXT (notation and pointer to HELP:
  `files/readme.txt`, `files/en/readme.txt`) and the texts of HELP.COM (`helptab.msg` in
  `progs/msg/fr` and `progs/msg/en`, LZSS-compressed, decoded by `help.s`), from one
  list per language (same topics, same number of lines: checked).
- Libraries on the disk (CPA.INC, HIRES.INC, GRX.INC, ANIM.INC, ARR.INC, FIL.INC, SPR.INC, ORIC.INC): copies without
  comments made by `tools/strip_inc.py`; the documentation stays in `progs/*.inc`.
  Their messages are in `progs/msg/fr` and `progs/msg/en` (`arr.msg`...): in the
  library, a line `;#msg nom.msg` marks their place, `strip_inc.py` copies them there
  in the language of the disk (`build/src`, `build/src-en` for `cpa-en.dsk`), and a
  program in `progs/` that includes the library also includes its messages, just after.
  The seven libraries of the translated programs (GRX, ARR, FIL, SPR, ANIM, ORIC, HIRES)
  are in addition marked by `tools/mark_inc.py` (comment lines `;@`): GRXASM copies
  only the routines that are needed (`docs/en/grapher.md` § 12, § 15). Source annotations,
  kept by `strip_inc.py` for `mark_inc.py`: `;[` ... `;]` (interpreter checks,
  removed from the copies), `;>a b` and `;&nom` (needs and lines of `ORIC.INC`).
  `tools/mk_lib.py` then precompiles them into `GRX.LIB` (same disks): GRXASM takes it
  when it finds it and ends `NAME.ASM` with `#lib "GRX.LIB",...`, which ASM links (same
  bytes as through the `.INC`s, `tools/test_lib.sh`).
- Git: one commit per delivery, message in French, tested beforehand. The repository is published on
  GitHub (https://github.com/drpsy77/cpa-oric).

## 6. Repository layout

| Folder | Contents |
|---|---|
| `src/` | system (BIOS, BDOS, CCP, menus, graphics, sound, disk) |
| `boot/` | Microdisc boot loader |
| `progs/` | `.COM` programs and `cpa.inc` |
| `files/` | files copied as they are onto the disk (README.TXT, DEMO.LOG, DESSIN.BAT) |
| `tools/` | PC tools: disk images, tables, tests |
| `docs/` | documentation (index in `README.md`) |
| `build/` | outputs, not under version control, except the checksums of the disks (`disquettes.md5`: `git status` shows whether an image has changed) and the example `.TAP` files (`build/tap/`); the disks are published by a GitHub release (`.github/workflows/release.yml`, when a `vX.Y` tag is pushed) |

## 7. Documentation

A single source per subject, in the present tense: a document describes what **is** (or what is
decided), without narrative, without discussion dates, without "Pierre said". The history is in git.

| Subject | Where |
|---|---|
| goal, audience, principles, what CP/A is not | `docs/en/vision.md` (criterion for ordering what comes next) |
| contract, conventions, building | this document |
| status, version 1.0 checklist | `docs/etat.md` (short: re-read at each conversation) |
| planned next steps | `docs/suite.md` |
| space reserves | `docs/place.md` |
| internal workings of the system | `docs/systeme.md` |
| user guide of a program | `docs/en/manuel.md`, or its reference (`logo.md`, `grapher.md`, `cmder.md`, `edsprite.md`) |
| implementation choices of a program | "Mise en œuvre" (Implementation) section of its reference |
| trials on the real hardware | `docs/essais-materiel.md` (read only when needed) |
| help on the Oric | `tools/gen_readme_txt.py` (HELP.COM, README.TXT) |
| measurement (function points, lines, bytes) | `docs/points-de-fonction.md` |
| project review: findings, decided batches | `docs/revue.md` |
| ideas examined and rejected, with the reasons | `docs/fausses-bonnes-idees.md` |

- A working specification follows the same plan: what is done, "Décidé, pas encore
  fait" (Decided, not yet done), "Questions ouvertes" (Open questions). A question disappears as soon as it has its answer: the
  answer is worked into the text. Once the work is delivered, the specification becomes (or
  joins) the reference of the program.
- At each delivery: the reference of the program, `docs/etat.md` (sizes, margin), `docs/suite.md`,
  `docs/essais-materiel.md` ("À vérifier", To be checked) and, if a function changes,
  `docs/points-de-fonction.md` (§ 2.4) are updated; nothing is narrated.
- `README.md` (English) and `README.fr.md` (French) go together: a change to one
  is carried over to the other. The same holds for the documents translated in `docs/en/`: the
  user documents (`manuel.md`, `logo.md`, `grapher.md`, `cmder.md`, `edsprite.md`) and five
  internal ones (`architecture.md`, `vision.md`, `usb.md`, `console-distance.md`,
  `loci-modem-wifi.md`); the others are in French only. `python3 tools/check_en.py`
  reports a translation that is lagging behind (headings, tables, examples).
- The documents in `docs/en/` describe the English disks: screens, menus, questions,
  messages and example names there are those of `cpa-en.dsk` and its twins; the French
  documents, those of `cpa.dsk`.
