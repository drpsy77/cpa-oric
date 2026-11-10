# The USB stick and the LOCI from CP/A

English translation of `docs/usb.md` (the French document is the reference; the other documents it points to are in French unless an English version exists in `docs/en/`).

The goal: no longer go back through the LOCI's menu (nor through its file manager) to
work. From CP/A, you browse all the LOCI's media, you mount a disk or a tape, you duplicate,
rename or erase an image or a file, you find out what is mounted.

Two levels:

- **Level 1** (this document): the files on the stick stay outside the Oric's world. You
  list them, copy them in both directions, mount them, duplicate them, rename them, erase
  them; you do not open them directly in EDIT. `.COM` programs only: nothing resident,
  interface contract intact.
- **Level 2** (later, § 5): a directory of the stick mounted as a drive, whose files behave
  like those of a disk.

**A single way of doing each thing.** CMDER is the only interactive screen: there you browse
the media and the directories, you choose, you act. The command-line commands (USBDIR,
IMPORT, EXPORT, USBMOUNT) perform a direct action, for the prompt and for scripts, with no
list to browse: an ambiguous name does not open a choice, it is refused with the list of
candidates. The common code (paths, current directory, media, LOCI configuration) is
written once, in `progs/loci_inc.s`.

## 1. Done

- EXPORT, IMPORT, USBDIR (`docs/en/manuel.md`) and the USB panel of CMDER
  (`docs/en/cmder.md`): copy in both directions, listing of a directory, `0:` (the LOCI's
  internal memory).
- The stick is a gateway: copy in both directions, mounting (USBMOUNT, CMDER); rename,
  erase, duplicate in CMDER only.
- `progs/loci_inc.s`: calls to the LOCI API (open, read, write, close, list), current
  directory, paths, media; `progs/ljok_inc.s`: wildcards.
- Test Oricutron (`ORIC_LOCI`, `docs/atelier.md`): a folder on the PC stands in for the
  stick, its subfolder `int` for `0:`, its subfolders `usb1` to `usb8` for several sticks
  (description in `usbN.txt`, other devices in `autres.txt`), list of devices; the menu's
  configuration in XRAM is imitated (`"LOCI"`, `mounts`).

**Batch 1: current directory and media.**

### 1.1 Media and paths

- **Media**: `0:` (internal memory, 15 MB) and `n:`, one per USB storage device. The
  number is the device's USB address: it changes with the socket, the hub, the other
  devices (keyboard, Pico W). No command assumes `1:`.
- **The LOCI does not give the volume name of sticks.** A stick is recognised by its
  **description**: size, manufacturer and model (`14.9 GB SanDisk Cruzer`).
- **CP/A's current directory**, specific to CP/A (independent of the LOCI menu's one) and
  kept across a restart: file `0:CPA.CWD` (the path, then the description of the
  medium), read by each USB command, written by CMDER on exit (§ 1.3), only if it
  changes. Never written: the root of the first stick.
- **Renumbered medium**: if the recorded medium no longer has the same description (or no
  longer exists), the command looks for the one that has it and corrects the number
  (`Cle trouvee en 4:`); otherwise `Cle absente : SanDisk Cruzer`, and the command starts
  from the root of the first stick; the file is not rewritten (the recorded directory comes
  back with the stick; the message is repeated with each command until then).
- **Paths** in all the USB commands (USBDIR, IMPORT, EXPORT, USBMOUNT, CMDER):

| Written | Designates |
|---|---|
| `nom`, `rep/nom` | relative to the current directory |
| `/rep/nom` | from the root of the current medium |
| `2:/rep/nom`, `0:nom` | on that medium |
| `..` | the parent directory |

  For anyone who has never changed directory, nothing changes (current directory = root of
  the first stick). `..` is resolved by CP/A (the LOCI menu has its own current directory
  in FatFs, which CP/A does not depend on: every path sent to the LOCI is complete,
  `2:/...`). Full path of 127 characters at most (`Chemin trop long`). Long names: displayed
  truncated (`~`), read again in full from the stick for opening (as CMDER does).
- **Wildcards** (`*`, `?`, case ignored; a final `.*` also accepts a name without a dot) in
  the last element of a name on the stick: `USBDIR *.DSK` filters the list; IMPORT and
  USBMOUNT, which expect a single file, take the only one that matches, otherwise write them
  (one per line, 8 at most, then `...`) and stop: `Plusieurs fichiers : preciser`; none:
  `Introuvable : JE*`.

### 1.2 Command-line commands

**USBDIR**:

    USBDIR [path]          lists a directory (without a path: the current directory),
                           then its full path and the number of elements
                           (2:/JEUX/ORIC : 12 element(s) ; number on its own line
                           if the path exceeds 20 characters)
    USBDIR /S              catalogue of the media
    USBDIR /C [path]       the directory becomes the current directory, written
                           back; without a path: CMDER USB: /R (via CHAIN);
                           this is the script USBCD.BAT

    A>USBDIR /S
    0: memoire du LOCI          15 Mo
    2: SanDisk Cruzer Blade   14.9 Go *
    4: Kingston DataTraveler   7.5 Go

  Storage media only (not the keyboard, nor the Pico W); `*`: the medium of the current
  directory.

**IMPORT, EXPORT**: names on the stick are relative to the current directory; IMPORT accepts
wildcards (a single file). Manufacturer and model come from the LOCI's text (`2: MSC 14.9 GB
SanDisk  Cruzer Blade    rev 1.00`), spaces reduced; size `GB` written `Go` in French.

### 1.3 CMDER

- **Current directory**: the USB panel opens in the current directory (`CMDER USB:`,
  or `CMDER USB:rep` to start from elsewhere); on exit, the last USB directory displayed
  becomes the current directory. Changing directory means entering CMDER, going where you
  want, quitting; or, on the command line, `USBCD rep` (§ 1.2, `USBDIR /C`).
- **Media**: `..` at the root of a medium shows the list of media (header
  `USB:supports`), the one you came from marked `*`, the cursor on it; RETURN on a
  medium enters its root; nothing can be copied there (`Choisir d'abord un support`):

```
 1 |USB:supports         3 fic           |
 2 |  NOM+                        TAILLE |
 3 |  0: memoire du LOCI   15 Mo         |
 4 |  2: SanDisk Cruzer  14.9 Go *       |
 5 |  4: Kingston DataTra 7.5 Go         |
```

- **Directories only**: one more filter (View menu, `Repertoires seuls`, per panel;
  `Cle USB seulement` on a disk; option `/R` on the call) shows only `..` and the
  `<REP>` entries; with `CMDER USB:JEUX /R`, you browse the tree without the files. The
  script `USBCD.BAT` (one line, `USBDIR /C $1`, § 1.2): `USBCD JEUX` changes directory
  without a screen and writes the new one; `USBCD` alone opens `CMDER USB: /R` (ESC: the
  displayed directory becomes the current directory). `USBCD.BAT` is on every disk,
  protected (hidden on the special-purpose disks, like the basic commands).
- **Copying to the stick**: `USB:rep` is relative to the directory of the USB panel
  (without one, to CP/A's current directory); `USB:` alone: that very directory.

**Batch 2: USBMOUNT.**

### 1.4 USBMOUNT

    USBMOUNT               what is mounted
    USBMOUNT B:            full path of B:'s image
    USBMOUNT B: JEU.DSK    mounts JEU.DSK in B: (C:, D:); JE*.DSK if there is only one
    USBMOUNT B: /E         ejects
    USBMOUNT JEU.TAP       mounts the tape (K7:)
    USBMOUNT JEU.TAP /B    then leaves CP/A for BASIC 1.1 and loads the tape
    USBMOUNT K7: /E        ejects the tape

    A>USBMOUNT
    A: cpa.dsk
    B: projets.dsk
    C: -
    D: jeux-fr.dsk
    K7: jeucoul.tap
    A>USBMOUNT B: PUZZLE.DSK
    B: puzzle.dsk

- Names read from the LOCI menu's configuration (32 characters at most): what CP/A shows
  and what the menu shows are always the same, whichever of them did the mounting.
- **A: forbidden**: `A: interdit (disquette systeme)`. The `.COM` programs and the system's
  bank file are read from it.
- Refused: an image already mounted in another drive (`Deja montee en C:`: two
  writes to the same file would damage it); a file that is not a disk image
  (`Pas une disquette`: signature `MFM_DISK` checked); a `.TAP`
  on a CP/A disk (`Exporter d'abord : EXPORT JEU.TAP`); an image in the internal
  memory (`Pas d'image sur 0:`: the firmware does not check the opening of a file on
  `0:` before reading it; a mount of `0:CPA-ANIM.DSK` froze the LOCI, `mt_mount` in
  `lmnt_inc.s`, CMDER included).
- A tape must begin with the synchronisation byte `$16` (`Pas une cassette
  (.TAP)`); a `.DSK` name without a drive: `Lecteur ? USBMOUNT B: nom.DSK`.
- After mounting or ejecting a disk: pending writes done, disks reset (BDOS function 13),
  as after a disk change and a CTRL-C. During the change, A: is the drive in use: a drive
  without an image never receives a command (the LOCI's controller would hang). The current
  drive, when ejected, gives way to A:.
- The name kept by the menu is the one on the stick (case included), found again in the
  directory; `USBMOUNT B:` writes the image's directory (getcwd) followed by that name.
- `/B` goes immediately (no question): the LOCI starts in BASIC 1.1, tape in use,
  automatic loading (`CLOAD""` without typing anything). The menu's configuration is
  written first as the menu would write it (FDC disabled, tape, BASIC 1.1, automatic
  loading; bit mode kept), then operation `$A0` with flags `$96`
  (`$9E` in bit mode), VIA interrupts disabled as the menu does. The
  disks remain mounted for a return to CP/A through the LOCI menu (FDC re-enabled). If the
  LOCI refuses: `Erreur USB n`, and you stay in CP/A. Closes the loop: `GRXASM JEU /O`,
  `EXPORT JEU.TAP`, `USBMOUNT JEU.TAP /B`.

**Batch 3: CMDER operations on the stick.**

### 1.5 CMDER, operations on the stick

Rename, Erase (mounted images skipped), Duplicate (`^U`, temporary name `~CPADUP.TMP`
renamed at the end), Mount (`^O`, USBMOUNT's code: `lmnt_inc.s`), name of each drive's
disk in the headers: details in `docs/en/cmder.md` (§ 6, "USB stick"). Files only
(`Fichiers seulement`); long names are typed in full (63 characters, the line scrolls).

## 2. Implementation

**LOCI API** (firmware, `src/mia/main.c` for the list, `api/mnt.c`, `api/dir.c`,
`usb/msc.c`), in addition to what `loci_inc.s` already calls:

| Operation | Effect |
|---|---|
| `$90` mount | A = drive (0-3), 4 tape, 5 ROM; path on the exchange stack; FAT or `0:` |
| `$91` umount | A = drive |
| `$88` getcwd | A = drive: the **directory** of the mounted image (up to the last `/`), not its name |
| `$1A` lseek, `$1B` unlink, `$1C` rename, `$83` mkdir | as in C |
| `$92`-`$94` | tape: position, next header |
| `$A0` boot | flags: `$01` disk, `$02` tape, `$04` BASIC 1.1, `$10` automatic loading, `$40` resume, `$80` fast |

- No copy (duplicating goes through the Oric, in chunks of 512 bytes); no chdir (the
  current directory is CP/A's, § 1.1).
- `opendir` of an empty path lists the devices: `0: Internal storage [15MB]`, then
  `n: MSC 14.9 GB` + manufacturer (8) + model (16) + revision for a storage device; the
  other devices (keyboard, Pico W) have other texts and are skipped. A firmware compiled
  without decimals in `printf` (the 0.3.98 in `tools/loci-acia-diag/`) writes
  `n: MSC  GB General  UDisk`: `dv_next` keeps any text that begins with `MSC `, except
  `MSC mounted, inquiring` (stick not ready yet); the displayed size is then reduced to
  the unit.
- `readdir` returns the FAT short name beyond the maximum length of a name.
- `open` on `0:` (littlefs, `api/std.c`): `O_TRUNC`, `O_APPEND` or `O_EXCL` replace
  `O_CREAT` there instead of adding to it; `O_CREAT+O_TRUNC` therefore does not create an
  absent file (error 130, `LFS_ERR_NOENT`). `usb_open` first opens with `O_CREAT` alone,
  closes, then reopens with `O_TRUNC`. The test Oricutron reproduces this behaviour.
- **LOCI menu configuration in XRAM** (`loci-rom`, `src/persist.h`, `persist.c`),
  read and written through window 1 (`$03A8-$03AB`):

| XRAM | Contents |
|---|---|
| `$8000` | `"LOCI"` |
| `$8004-$800A` | `fdc_on`, `tap_on`, `bit_on`, `mou_on`, `b11_on`, `ser_on`, `ald_on` |
| `$800B` | `mounts`: bits 0-3 drives, 4 tape, 5 ROM (read by `loci_abs`, `src/disk.s`) |
| `$800C` | `tui_pos` |
| `$800D` | `path`: the menu's directory (`1:/jeux`), 256 bytes |
| `$810D` + 35 × n | `drv_names[n]`: image name only (32 characters at most, empty if none), n = 0-3 drives, 4 tape, 5 ROM |

- **A mount through the API writes nothing in XRAM**: it is the menu that maintains
  `mounts` and `drv_names`. USBMOUNT and CMDER write them as it does; without the bit in
  `mounts`, CP/A would refuse the drive (`loci_abs`). The image's directory is read with `$88`.
- Common code, by files (ASM has no conditional assembly): `loci_inc.s` (API,
  current directory `cw_get` / `cw_write`, paths `lpath`, media `dv_open`,
  `dv_next`, `dv_parse`, `dv_fmt`: all the USB programs, ~1.7 KB), `lcwp_inc.s`
  (`cw_put`, changing directory: USBDIR, CMDER), `ljok_inc.s` (wildcards
  `wmatch`, `lp_find`, `lp_findx`: USBDIR, IMPORT, USBMOUNT; ~0.4 KB), `lmnt_inc.s`
  (mounting `mt_mount`, `mt_eject`, menu configuration in XRAM, `mt_where`, `mt_head`,
  `mt_pre` / `mt_post` around the BDOS: USBMOUNT, and CMDER in batch 3; ~0.8 KB; its buffers
  are placed by the program after `loci_inc.s`). Messages in 37 columns, without accents
  (`loci.msg`, `usbmount.msg`).
- Test Oricutron: `rename`; `mount` changes the inserted disk (drives 0 to 3: the image from
  the stick, rewritten on ejection if it has changed), `umount`, `getcwd`, XRAM `$8000-$81FF`
  writable (initially: the configuration of a menu that would have mounted the inserted
  disks); `boot` starts nothing, it writes its flags into `boot.txt` and answers with an
  error (start-up is tried on the real Oric).

## 3. Batches

| Batch | Contents | Tests | Space (generous estimate) |
|---|---|---|---|
| 1 | **Done.** Current directory and media (§ 1) | Oricutron: two sticks, renumbering, absent stick, `0:`; hardware: `docs/essais-materiel.md` | CMDER +1,773 bytes (8 blocks); USBDIR 2,810, IMPORT 3,443, EXPORT 3,055 (one more block each) |
| 2 | **Done.** USBMOUNT (§ 1.4) | Oricutron: mounting, write then read back on the mounted image, ejection of the current drive, refusals, tape, flags of `/B`; hardware: `docs/essais-materiel.md` | USBMOUNT 4,086 bytes (2 blocks); HELP goes to 7 blocks |
| 3 | **Done.** CMDER, operations on the stick (§ 1.5) | Oricutron: rename, erase (mounted image skipped), duplicate (ESC included), mount, headers; hardware: `docs/essais-materiel.md` | CMDER +2,535 bytes (9 blocks) |

The three batches are done; CMDER is 17,889 bytes (9 blocks, 543 bytes free).

## 4. What this level does not do

- Open a file on the stick directly in EDIT, GRAPHER...: it has to be imported
  (level 2).
- Completion of names on the stick with ESC at the prompt: it is resident and reads only
  the disks; adding it would require the LOCI API in the system (12 bytes of
  margin). You choose in CMDER.
- Copy, erase or create a whole directory (`$83` exists: later if needed).

## 5. Later: level 2

A directory of the stick mounted as drive B:, C: or D: (instead of an image): its 8 + 3
files behave like those of a disk (EDIT, GRAPHER, COPY, DIR...). A driver in the BDOS
sends all the file functions of that drive to the LOCI API; neither attributes nor
allocation table (fictitious free space; FORMAT, DISKCOPY and direct sector accesses
refused). Estimated resident space 1.5 to 2 KB, when the system has 12 bytes of margin:
after PUT is moved down into a bank (`docs/place.md`), or the driver itself in a bank.
Erasing is used there (EDIT saves through `NOM.$$$`, erase, rename). Affects the system,
not the BDOS numbers.
