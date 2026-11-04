# Serial driver and remote console

English translation of `docs/console-distance.md` (the French document is the reference;
the other documents it points to are in French unless an English version exists in
`docs/en/`).

Goal: a Mac (or the Pi) **types and reads in place of the keyboard and the screen** of a
real Oric, through the LOCI's WiFi modem (`docs/loci-modem-wifi.md`). Uses: driving the
tests on the real Oric the way `tools/run_test.sh` does in Oricutron, pasting a text into
EDIT, working on the Oric from a window on the Mac or from a phone's browser. The remote
console must survive programs: it lives in the BIOS.

Done: the resident driver (`src/serial.s`, `SERIE` option), function 117, PUNCH and
READER, `REMOTE.COM`, the daemon `tools/remote.py` and its command line, the web page
(§ 9), the tkinter window (§ 9.2), the fake daemon (§ 9.3), the showcase (§ 9.5) and
read-only publishing on the Internet through a gateway (§ 9.6); tried in Oricutron
(`tools/test_remote.sh`), the page with the fake daemon. User guide:
`docs/en/manuel.md`, "Remote console: REMOTE".

## 1. Principle

- **On the Oric, a stateless driver**: it receives keys, which it puts into the keyboard
  buffer as if they had been typed, and answers requests from the Mac about the screen
  (checksums of the 28 rows, then the rows asked for). It sends **nothing** unasked: a
  Mac that has gone away makes nothing go out to the modem.
- **On the Mac, a daemon** (`tools/remote.py`) holds the link with the Oric, keeps a copy
  of the screen and keeps it up to date by comparing the checksums. The windows (local
  web page, tkinter window on the small screen of a Raspberry Pi Zero), the test scripts
  and the command line talk to it through the same local interface (§ 9.1); they can
  stop and start again without cutting off the Oric.
- **The whole text mode is seen**, whatever the program: EDIT, CMDER, HEX, the menus and
  the status line write straight into `SCREEN`; the driver reads the screen itself. Not
  full-screen HIRES; in SPLIT, only the text rows (16 to 27).
- **Redefined characters too** (GRAPHER sprites and tiles, the EDSPRITE grid): in text
  mode, the Mac follows the font itself (`$B400-$BB7F`), cut into 48 rows of 40 bytes
  (five characters) numbered 28 to 75 after those of the screen, with the same checksums
  and the same frames (§ 4, "Font").
- **The service runs under the 50 Hz IRQ**: it works during a computation, during ASM or
  LOGO, with a program that does not read the keyboard through the BDOS. It stops while
  interrupts are disabled (disk access): the LOCI, the Pico and TCP keep what arrives
  (`loci-modem-wifi.md`, "Contrôle de flux"); nothing is lost.
- **The Oric's keyboard stays active**: both sources fill the same buffer.

## 2. Line and settings

- Port: the one in `acia_inc.s` (LOCI `$0380`, Oricutron `$031C`), 9600 baud 8N1, DTR,
  no ACIA interrupt, set by REMOTE; accessed by absolute `LDA` / `STA` only. The driver's
  three register routines (`sr_rsta`, `sr_rdat`, `sr_wdat`: `LDA $0381` / `LDA $0380` /
  `STA $0380`, followed by `RTS`) are in the overlay RAM; their low byte is set by
  function 117 (§ 6).
- Call: **the Oric calls the Mac** (`ATDT-host:port`, name taken from `HOSTS`, § 8). The
  Mac cannot wake the Oric up: that would take work in the LOCI's firmware. Daemon port
  **2324** (2323 stays with `xfer_server.py`). In Oricutron, `serial = 'modem'` and
  `ATDT127.0.0.1:2324`, as in `tools/test_xfer.sh`.

## 3. Who leads

Animated diagram, scenarios and both screens side by side: `docs/en/console-distance.html`
(to open in a browser).

| What | Who decides | When |
|---|---|---|
| open, close the link | the Oric (`REMOTE`, `REMOTE OFF`) | by hand or in `AUTO.BAT` |
| keys from the Mac | the Mac sends them; the Oric stores them if it has room | at any time |
| keys from the Oric | stay on the Oric; the Mac sees them on the screen at the next cycle | at any time |
| echo of a key from the Mac | **the Mac** asks for the cursor row (`L cy`) | as soon as the key has gone (fast echo, below) |
| refreshing the screen | **the Mac** asks (`S`, then `L n`); the Oric answers | every 0.5 s; right after the fast echo; at once as long as a cycle finds changed rows |
| warm start | the Mac (`$FD 'B'`) or the RESET button | on request |

The TCP connection stays open both ways as long as the console is on; the Oric only
writes to it to answer. **The Mac is the one that finds the changed rows**: it computes
the checksums of its own copy and compares them with those the Oric sends back. The
daemon's loop:

    if keys are waiting:
        send them ($FE k for each)
        fast echo: send $FD 'L' cy (cursor row, from the last S frame);
            copy[cy] = the 40 bytes received
    send $FD 'S'; wait for the S frame (1 s at most, otherwise ask again)
    for each row n whose received checksum differs from fletcher(copy[n]):
        send $FD 'L' n; wait for the L frame; copy[n] = its 40 bytes
    a row has changed: start again at once;
    otherwise wait 0.5 s, or the next key

**No local echo**: a key typed on the Mac is not displayed on the Mac. It goes to the
Oric, and the Oric's program decides what to display (in CMDER, an arrow moves the
selection; in EDIT, a key inserts, deletes or scrolls). The Mac then shows what the Oric
displayed, like a remote terminal (telnet, ssh). So the Mac does not need to know where a
change comes from: key from the Mac or from the Oric's keyboard, it sees the Oric's
screen.

**Fast echo**: right after a key, the Mac first asks for the cursor row (almost always
the one that changes), then does the full cycle for the rest (scrolling, menus, status
line). Estimated delay between typing and display: 0.1 to 0.15 s, instead of 0.3 to
0.4 s with the cycle alone. Cost on the Oric: none.

Faithfulness: the copy holds the exact bytes of the screen, attributes included; the
page draws them with CP/A's font and the ULA's rules. A state shorter than a cycle is not
seen (only the final state arrives).

## 4. Protocol

A single byte stream each way. The modem's messages (`CONNECT`, `NO CARRIER`, `OK`) go
through the same stream: both sides must ignore them.

### Mac to Oric: every message starts with a `$FD` or `$FE` byte

The modem only sends ASCII (< `$80`): a byte that does not follow a prefix is ignored.
So `NO CARRIER` never reaches the Oric as typing.

| Message | Effect |
|---|---|
| `$FE k` | key of code `k` (0-255), stored in the keyboard buffer; codes of the contract (`architecture.md` § 2, "Codes du clavier"; FUNCT = `$80`) |
| `$FD 'S'` | asks for the checksums (answer `S`) |
| `$FD 'L' n` | asks for row `n` (0-27) (answer `L`); `n + $80`: rows `n` to 27, one `L` frame each, in a row, with no further request (the Mac uses it from 3 changed rows) |
| `$FD 'C' n` | checksums of font rows `n` to `n+7` (28 ≤ `n` ≤ 68) (answer `C`) |
| `$FD 'B'` | warm start, like the RESET button (tests: a stuck program that keeps interrupts on) |

- A key is only read from the ACIA if there is room in the keyboard buffer (16 bytes):
  otherwise the driver leaves the byte in the LOCI. A pasted text of several KB thus
  arrives without loss, at the pace at which the program reads (EDIT, the command line).
- A request that arrives while another is being served replaces it (that is how the Mac
  resynchronises). The Mac has only one in progress at a time.

### Oric to Mac: frames, only as answers

    $FF  type  length  data (length bytes)  checksum

`checksum` = 8-bit sum of `type`, `length` and the data. The Mac looks for `$FF`, checks
the length and the checksum, and throws away everything else (modem messages, cut
frame); a rejected frame is asked for again.

| Type | Data |
|---|---|
| `'S'` (60 bytes) | mode (0 text, 1 SPLIT, 2 full-screen HIRES; bit 7 = `SCR_PROG`, text screen owned by the program), cursor column and row, cursor on, then 28 Fletcher checksums (`s1 += byte; s2 += s1`, 8 bits each, `s1` sent first), one per row of `$BB80` |
| `'L'` (41 bytes) | row number, then its 40 bytes as they are (attributes and bit 7 included) |
| `'C'` (16 bytes) | the Fletcher checksums (`s1`, `s2`) of the 8 font rows asked for |

- **The cursor does not count**: when it is inverted on the screen (`cur_vis`), its cell
  is read restored (bit 7 inverted again) for the checksums as for the rows. Otherwise
  the blinking would change a checksum every 0.4 s. The Mac draws its own cursor from
  the `S` frame.
- In full-screen HIRES (mode 2), the Mac asks for no rows and shows "Ecran graphique";
  in SPLIT (mode 1), it only compares rows 16 to 27.
- Mode 2 is recognised like the BIOS's `hires_on`: text mode for the system, attribute
  `$1E` in the last cell of the screen.

### Font (redefined characters)

Row `n` from 28 to 75: the 40 bytes at `$B400 + 40 × (n − 28)`; `L n` and the run
`L n+$80` (up to 75) work as for the screen. A character takes 8 bytes: a row holds
exactly five, a character is never split. Useful: 6 to 25 (characters 32-127 of the
standard set) and 32 to 47 (32-111 of the alternate set; 112-127 are in rows 0-3 of the
screen, as for the ULA); the others hold codes 0-31 (attributes), never drawn.

- **Text mode only**: in HIRES and SPLIT, `$B400` is inside the picture (the SPLIT font
  is at `$9800`); the Mac asks for none of it, and draws SPLIT's text rows with CP/A's
  font.
- **The Mac**: at the first `S` frame in text mode of each call, it reads the 48 rows
  (`L 28+$80`, 1.8 s in Oricutron); a driver that does not answer does not know the
  font (old driver): it is no longer asked for during that call. Then, at each cycle
  (every 0.5 s when idle), `C` frames over the five useful slices (28+6, 28+14, 28+22,
  28+32, 28+40): each slice that changed less than 10 s ago (animated sprite) at every
  cycle, plus two others in turn (the whole font in 1.5 s when idle, faster when the
  screen changes: the cycles follow one another); all of them on returning to text mode.
  Changed rows: `L`, or a run.
- **Cost on the Oric**: a `C` frame computes 8 checksums (320 bytes read); no extra
  variable. Driver: +65 bytes.

### Budget under the IRQ

Limits set with the port (function 117, op 1; table `sr_par` in `src/serial.s`, variables
`sr_rxn`, `sr_rxw`, `sr_txn`, `sr_bdg` at `$FD23-$FD26`): a real 6551 (Oricutron, serial
card) holds only one received byte and sends at the line's pace; the LOCI keeps 32
received bytes, readable at once, and takes a byte to send as soon as USB accepts it (its
emulated ACIA has no timing: the 9600 baud is only a setting passed on to the modem).

| Task | Per 1/50 s frame: 6551 | LOCI (`$80`) |
|---|---|---|
| reading | 4 bytes at most; the first without waiting, the next ones after ~1.2 ms at most | 16 bytes at most (8 keys); wait for the next ones ~0.2 ms |
| checksums | computed while sending, when their turn comes (~0.6 ms per row): no buffer | same |
| sending | 24 bytes at most, as long as the wait for the transmitter, counted over the whole IRQ, stays under ~6 ms; transmitter busy: the rest at the next IRQ | 64 bytes at most (a whole `S` frame), wait ~7.5 ms at most |

Measured on the real Oric (LOCI, Pico with the firmware in `tools/pico-modem/`, daemon on
the Mac): 27 rows in 0.4 s, i.e. ~3 KB/s, the limit of 64 bytes per IRQ (1.0 s with the
6551 limits); echo 0.21 s; `VER` on a full screen 0.8 to 0.9 s.

The limits can be changed without rebuilding (tests): `DEBUG`, then `M FD23 rx at tx bu`;
they go back to the table at the next `REMOTE`.

Measured in Oricutron (9600 baud, transmitter free after ~1 ms): 8 bytes per IRQ, i.e.
the `S` frame (64 bytes) in 8 IRQs (0.16 s), an `L` frame (45 bytes) in 6; during an
answer, the service takes ~10 ms out of 20, the program goes on more slowly. A pasted
text of 2 KB arrives in EDIT in ~40 s (~55 keys per second). When idle, the Mac asks for
`S` every 0.5 s; right after a key, at once. On the LOCI: to be measured
(`essais-materiel.md`).

### Link lost

The driver only speaks to answer: without a Mac, it is silent. The Pico W sometimes holds
back sending for several tenths of a second (`loci-modem-wifi.md`, "Contrôle de flux"):
the service simply resumes at the next IRQ. If the transmitter stays busy for 5 s during
an answer (modem unplugged: the LOCI no longer empties the register), the answer is
dropped and the light turns to `r`; the console stays on (a new request restarts the
service). `REMOTE OFF` cuts off and hangs up.

## 5. On the Oric: what is resident

`src/serial.s`, included with the `SERIE` build option (on by default, `build.sh`):

| Part | Bytes |
|---|---:|
| `sr_irq`: called by the IRQ after `snd_tick`; reading (prefixes, room in the keyboard buffer, key stored by `kb_push` from `kb_scan`), bounded sending, link lost | 132 |
| `sr_rx`: prefixes and requests; `$FD 'B'` | 77 |
| `sr_next`: next byte of the frame (header, data, checksum) | 148 |
| `sr_fl`, `sr_line`, `sr_byte`, `sr_lda`: checksums and reading of a row, cursor cell restored | 80 |
| registers (`sr_rsta`, `sr_rdat`, `sr_wdat`) | 12 |
| function 117 (`sr_call`) | 76 |
| PUNCH, READER (functions 4 and 3) | 72 |
| light (`draw_flags`, table `sr_flg`), BDOS dispatch, call in the IRQ (minus the former empty entries of PUNCH and READER) | 25 |
| additions: run of rows (`L n+$80`), transmitter wait counted over the IRQ (`sr_bud`) | 38 |
| **total** | **660** |

(Plus 65 bytes for the font, § 4.)

Variables `sr_port`... (`src/hw.inc`, `$FD13-$FD21`): low byte of the port, state
(console on, link lost), received prefix, current frame, position, requested row, row
being read, `s1`, `s2`, checksum, IRQs without sending, length, counter, start of the
PUNCH delay. Cleared at cold start only. The row is read by an `LDA abs,Y` instruction
whose address is set (`sr_lda`, overlay RAM): no zero-page pointer. Row addresses come
from `line_lo` / `line_hi` (page `$FF00`); font rows are computed from `$B400`.

Not in a bank of the window: the service runs at every IRQ, and the window is used by PUT
and IMG.

- **PUNCH** (`$C012`, BDOS 4): sends A to the port, wait for the transmitter bounded to
  5 s (50 Hz counter: interrupts allowed); returns A = 0 and C = 0 if the byte went out,
  A = `$FF` and C = 1 otherwise, or if no port is set.
- **READER** (`$C015`, BDOS 3): waits for a byte from the port; returns `$1A` (^Z) at once
  if no port is set or if the remote console is on (the stream belongs to it), and as
  soon as a key is typed on the Oric (the key stays in the buffer).
- The driver survives a warm start (variables in overlay RAM, ACIA setting untouched); a
  cold start turns it off. `AUTO.BAT` may contain `REMOTE host:port`: the Oric makes
  itself available to the Mac on its own.
- `$FD 'B'` does `JMP wboot` from the IRQ (stack reset, hardware and console put back in
  order, back to the CCP), without the `*RESET* at` message.

## 6. Contract: what is added

Additions only, nothing moves (`architecture.md` § 2):

- PUNCH and READER, reserved for the serial port, get their definition (§ 5); BDOS
  functions 3 and 4 call them.
- **BDOS function 117, "serial"**, block `[op, p1..p5]` like 115 and 116:

| op | Effect |
|---|---|
| 0 | state -> A: bit 0 port set, bit 1 console on, bit 2 link lost; X = low byte of the port (0: none) |
| 1 | sets the port: p1 = low byte (`$80` LOCI, `$1C` Oricutron; 0: none, console off) |
| 2 | remote console on |
| 3 | remote console off |

  Ops 1 to 3 also clear the prefix and the current frame. The ROM version, and a build
  without `SERIE`, return `$FF` (rule of the contract). `progs/cpa.inc`:
  `F_SERIAL = 117`, `SE_STATE`, `SE_PORT`, `SE_ON`, `SE_OFF`.
- Protocol constants in `progs/cpa.inc`: `RP_REQ` (`$FD`), `RP_KEY` (`$FE`),
  `RP_FRM` (`$FF`), `RP_PORT` (2324).

## 7. REMOTE.COM

`progs/remote.s` (1,966 bytes, one block; 1,918 in English). Turns the console off if it
is on, finds and sets the ACIA (`ac_find`, `ac_setup`), dials with `ac_dial` (§ 8: name
taken from `HOSTS`, port 2324 by default), sets the port and raises the flag through
function 117. `REMOTE /N` only sets the ACIA if it is not set already (like XFER).
`REMOTE OFF`: function 117 op 3, then `ac_hang` (`AT`, otherwise `+++`; then `ATH0`).

    REMOTE host        dial and turn on (host: name from HOSTS,
                       IP address or DNS name; :port optional)
    REMOTE /N          turn on without dialling (link opened by TERM)
    REMOTE OFF         turn off, then +++ and ATH
    REMOTE             state

Screens (37 columns at most, no accents; French on `cpa.dsk`):

    A>REMOTE MAC
    LOCI modem (ACIA 0380)
    Calling 192.168.1.20:2324...
    CONNECT
    Remote console on (R light)
    A>REMOTE
    Remote console: on
    Port: LOCI (ACIA 0380)
    A>REMOTE OFF
    Remote console off

- A failed call gives the modem's answer (`NO CARRIER`, `BUSY`...) or `No answer from
  the modem`; the console stays off. Without a serial driver (build without `SERIE`):
  `No serial driver in the system`.
- TERM and XFER refuse to start while the console is on (they would read the ACIA in its
  place): `Remote console on: REMOTE OFF` (`ac_busy` in `acia_inc.s`).
- REMOTE is on every bootable disk (hidden on the special-purpose disks, like TERM and
  XFER).

## 8. `HOSTS` and calling through the modem (TERM, XFER, REMOTE)

User guide: `docs/en/manuel.md`, "Hosts: HOSTS", "Serial terminal: TERM" and "File
transfer: XFER" (`TERM mac`, `XFER R file @mac`). Implementation: `progs/acia_inc.s`,
`ac_host` (lookup in `HOSTS`), `ac_dial` (call), `ac_hang` (hang up), `ac_busy` (refusal
while the console is on), messages in `acia.msg`; REMOTE uses it with port 2324. Choices
made while coding:

- XFER takes the host last, preceded by `@`: the CCP puts the second word in FCB2, which
  is the file.
- `HOSTS` is looked for on the current drive, then on A: only (an empty drive of a real
  Microdisc costs several seconds); every bootable disk carries one.
- Hanging up: `ATH0` (Oricutron's modem refuses `ATH`).
- In Oricutron, the number goes out without a mode sign (`ATDT127.0.0.1:port`).
- Before `AT`, `ac_at` sends a lone CR, then throws away whatever arrives until 0.2 s of
  silence (`ac_purge`). The CR empties the modem's command line: bytes sent while a link
  was cut (XMODEM, typing in TERM) pile up there, and `AT` would have given `ERROR`; in
  command mode, an empty line gives no answer on the Pico W (an empty line on
  Oricutron), and on an open link, a lone CR is ignored by `xfer_server.py` and by the
  daemon. What gets thrown away are late answers (a `NO CARRIER` left by a stopped
  server, the `OK` of `ATH0`...), which shifted the answers of a command by one. After
  `ATDT`, one more `OK` is skipped.
- `xfer_server.py` and `remote.py` accept a new call at any time: it replaces the current
  connection. Otherwise an Oric (or a LOCI) gone without hanging up left the server
  waiting forever on a dead connection; the new call went through (`CONNECT`: the Mac's
  system accepts the connection) but the server did not serve it. TCP keepalive probes
  on top.
- TERM: 2,007 bytes (one block), XFER: 3,179 (two blocks).

## 9. On the Mac: `tools/remote.py`

Python 3 standard library only (nothing to install on the Mac).

- **Daemon log**: `logs/remote.log` in the repository (`--log` for another file; 1 MB,
  three old ones kept, `logs/` outside git): at start-up, daemon version (`VERSION`),
  repository commit ("remote.py modifié" if it differs), Python, machine, arguments and
  parameters; then the calls, each cycle that changes the screen (keys, duration of the
  echo, of the `S` frame, of the rows, grouped request or row by row), font changes,
  exceeded waits, rejected frames (start in hexadecimal), a lost link, and a summary
  every minute. Readable without a console: `GET /journal?n=200`, `GET /version`; the
  answer to `/ecran` also carries the counters (`stats`).
- **Daemon**: `tools/remote.py serve [--port 2324] [--http 8040] [--lent]
  [--spectateurs ADDRESSES] [--max-spectateurs N]` waits for the Oric, keeps the copy of
  the screen, serves the local interface. A new call from the Oric replaces the previous
  one. `--spectateurs` (addresses or networks, separated by commas: `10.77.0.1`,
  `192.168.2.0/24`): clients coming from there only watch (§ 9.6). `--lent`: one byte
  every 25 ms towards the Oric (test; useless with the LOCI as with Oricutron, whose
  modem keeps what arrives).
- **Keys**: those waiting go out at once (1,024 at most), each as `$FE k`; the driver only
  reads them if the keyboard buffer has room, so the Oric's program sets the pace. The
  `S` request that follows waits 1 s, plus 0.1 s per key sent beyond 4. The fast echo
  (cursor row) only follows a sending of 4 keys at most (typing, not a pasted text).
  Link lost: 5 s without a valid frame (plus the request's delay). Delay of an answer:
  3 s (`DELAI`) before asking again: the WiFi modem sometimes holds back sending for more
  than a second (seen on the real Oric), and a request repeated too early makes the
  current frame start over on the Oric. The grouped request is only given up after 3
  runs without an answer. Under Linux, the daemon acknowledges each reception at once
  (`TCP_QUICKACK`): the modem does not wait for the delayed acknowledgement before
  sending the rest.
- **Command line** (talks to the daemon): `remote.py touches $'DIR\n'` (same notation as
  `run_test.sh`: `\n`, `~` DEL, `\x01-\x04` arrows, `\x05` FUNCT, `\x1c` CTRL, `\x0f`
  SHIFT, `|` pause, `\x06` warm start through `$FD 'B'`), `remote.py ecran` (text like
  `tools/screen.py`), `remote.py attendre 'A>' [seconds]` (waits for a text to appear on
  the screen). With them, a test script on the real Oric is written like those for
  Oricutron.
- **Web page** (`tools/remote.html`, served by the daemon on `GET /`:
  `http://localhost:8040` on the daemon's machine, `http://address:8040` from a phone or
  another computer; `?demon=http://address:8040`: talk to a daemon other than the one
  serving the page). Its requests use relative addresses (`ecran`, `touches`...): behind
  a gateway, the page works under a path (`https://site/cpa/`, with the trailing slash).
  A single file, no library, to be kept next to `oric_ecran.py`; the daemon inserts
  CP/A's font into it (`page_web()`, read from `src/font.s`). File or font missing: a
  500 answer that says so.

        +-------------------------------------------------+
        | CP/A a distance   10.0.0.2   R             0,4 s |
        +-------------------------------------------------+
        |                                                 |
        |        screen 40 x 28 (CP/A font)               |
        |                                                 |
        +-------------------------------------------------+
        | FUNCT ESC TAB CTRL SHIFT   < ^ v >  RETURN      |
        | ^C  Clavier  Coller  RESET                      |
        +-------------------------------------------------+

  - Rendering: that of `oric_ecran.py` (§ 9.2), redone in JavaScript, identical to the
    dot (checked on the fake daemon's test card, and with redefined characters against
    an Oricutron memory dump); cursor and blinking at 0.32 s; in SPLIT, rows 0 to 15
    hatched; in full-screen HIRES, "Ecran graphique". **TV shape**: on a PAL TV, an
    Oric dot (240 per line at 6 MHz) is ~1.23 times wider than tall (14.75 MHz, the
    PAL square-pixel rate, / 6 MHz / 2 fields); the page widens the picture by that
    much, otherwise sprites look stretched vertically (as in Oricutron). Two-step
    enlargement: dots repeated up to a whole number of screen pixels per Oric line
    (letters sharp vertically), then width adjusted with smoothing (at most one
    softened pixel per edge). `?pixels=carres`: square dots, as before. Integer scale
    when it fits, in physical pixels (`devicePixelRatio`), otherwise the largest
    possible.
  - Status line: host (the Oric), light (`R` on, `r` lost, `-` waiting), age of the last
    full cycle. Messages on the screen: waiting for the call, link lost, daemon
    unreachable (new try every 2 s).
  - Reading: `GET /ecran` with long polling (5 s), only the changed rows. Sendings in
    order, fast typing grouped into a single `POST /touches`.
  - Computer keyboard: arrows `$08-$0B`, with SHIFT `$F0-$F3`, with CTRL `$F4-$F7`;
    Ctrl + letter 1-26 (H to K: 28-31), Ctrl-Space and Ctrl-@ 0, Ctrl-[ 27; Tab 29;
    Backspace and Delete `$7F`; Enter 13; Escape 27; F1 FUNCT. An accented character
    goes through `/coller` (accents removed by the daemon). Cmd (Mac) is left to the
    browser: Cmd-V pastes the clipboard to the Oric, Cmd-R reloads. Some Ctrl
    combinations are kept by the browser (Ctrl-W, Ctrl-T, Ctrl-N in Chrome): the CTRL
    button then the letter replaces them.
  - Phone: the Clavier (keyboard) button opens the phone's keyboard (an invisible input
    field: nothing stays in it, each character goes to the Oric, Return 13, erase
    `$7F`); the page keeps to the visible part, screen at the top, buttons above the
    keyboard. The buttons do not take the focus: the keyboard stays open. CTRL and SHIFT
    apply to the next key (letter or arrow); RETURN next to the arrows: a menu can be
    browsed and confirmed without the phone's keyboard.
  - Paste (Coller): the clipboard is read directly when the browser allows it
    (`localhost`); otherwise (phone over http), a field where the text is pasted, then
    Envoyer (send). The text goes through `/coller` (accents removed as by XFER `/T`,
    line ends as CR): in EDIT, open a file, paste, save (a text from the Mac thus reaches
    the Oric without XFER); flow control (§ 4) makes sure no key is lost.
  - RESET: two presses less than 3 s apart (`Sur ?`), then `POST /reset` (warm start).
  - Spectator (`"lecture_seule": true` in the answer to `/ecran`, or a sending refused
    with 403): no buttons and no keyboard, "en direct, lecture seule" (live, read-only)
    in the status line.

### 9.1 The daemon's local interface

HTTP on the `--http` port (8040), without authentication (home network); the web page,
the tkinter window and the command line all use it.

| Request | Answer, effect |
|---|---|
| `GET /ecran?depuis=V&attendre=S` | JSON of the screen (below); only the rows changed since version `V` (all if `V` = 0); with `attendre`, the answer waits up to `S` seconds (5 at most) for a newer version to appear (long polling: no busy polling) |
| `POST /touches` | body: raw bytes, codes of the contract (FUNCT `$80`), sent as `$FE k` in order; 204 |
| `POST /coller` | body: UTF-8 text; accents removed as by XFER `/T`, line ends as CR, tab as 29, then as `/touches`; 204 |
| `POST /reset` | `$FD 'B'` (warm start); 204 |
| `GET /` | the web page (`tools/remote.html`, font inserted) |
| `GET /version`, `GET /journal?n=N` | version and parameters of the daemon; the last N lines of the log |

A spectator (`--spectateurs`) gets 403 for the `POST`s, `/version` and `/journal`; its
answer to `/ecran` has neither `stats` nor `humain`, but `"lecture_seule": true`. It is
counted by its real address (the first one in `X-Forwarded-For`, set by Apache) for 20 s
after its last request; beyond `--max-spectateurs` (40), a newcomer gets 503 (the page
tries again 30 s later). `spectateurs` (in every answer to `/ecran`): the number online,
shown in the page's status line. A call on the Oric's port (2324) coming from a
spectator address is refused. A `POST` without the `X-Vitrine` header (page, window,
command line) records the time of human typing: the showcase pauses (§ 9.5).

    {"version": 812, "liaison": "active", "hote": "192.168.1.30",
     "mode": 0, "curseur": [4, 19, true], "delai": 0.4,
     "lignes": {"19": "1007413e444952...", ...},
     "police": {"22": "0c1e3f3f1e0c0000...", ...}}

- `version` grows at each change (row, cursor, mode, link). A version smaller than the
  client's means that the daemon has restarted: the client asks for everything again
  (`depuis=0`).
- `liaison` (link): `attente` (the Oric has not called yet), `active`, `perdue` (no more
  answers from the Oric); `delai`: age in seconds of the last full cycle.
- `mode`, `curseur` (column, row, on): those of the `S` frame; `lignes`: the 40 bytes of
  each row in hexadecimal, as in the `L` frame; `police` (font): likewise, the font rows
  received (key `k` from 0 to 47, row `28 + k` of the driver, bytes at `$B400 + 40 × k`)
  changed since `V`, absent as long as nothing has been received.
- `humain`: seconds since the last typing that does not come from the showcase (`null`:
  none); `stats`: link counters (diagnostics).

### 9.2 tkinter window: `tools/remote_tk.py` (Raspberry Pi Zero, Mac, Pi 400)

Same role as the web page, without a browser: for a Pi Zero and its small screen, placed
next to the Oric or elsewhere in the house. Python 3 and tkinter only.

    python3 tools/remote_tk.py [--demon URL] [--plein-ecran] [--etirer]
                               [--echelle E] [--sans-boutons] [--mem DUMP.mem]

- `--demon`: the daemon to reach (default `http://localhost:8040`). The daemon can run on
  the Pi Zero itself (the Oric calls it: `pizero 192.168.1.40` in `HOSTS`, then
  `REMOTE pizero`), or on the Mac (`--demon http://192.168.1.20:8040`).
- Size: the largest that fits, an integer from 2 up, otherwise a cell of fixed size (for
  instance 8 x 10 dots instead of 6 x 8 on a 480 x 320 screen): all cells grow the same
  way, first doubling the spacing column and the empty bottom row, so that the letters
  stay sharp. `--etirer` (stretch) fills the space without keeping the proportions;
  `--echelle` forces the scale.
- Rendering: that of the ULA (`tools/oric_ecran.py`): ink, paper, inverse, double height,
  blinking (attributes 8-15: bit 0 alternate set, bit 1 double height, bit 2 blinking;
  checked against Oricutron on the EDSPRITE screen); in text mode, the standard and alternate sets as the Oric has them in memory
  (font sent by the daemon, § 4 "Font": sprites, tiles, EDSPRITE; `polices()`), CP/A's
  font (`src/font.s`) for what has not been received yet and for SPLIT's text rows. The
  web page does the same (rendering compared dot by dot). Blinking cursor drawn from the
  `S` frame. In SPLIT, rows 0 to 15 are hatched; in full-screen HIRES, "Ecran
  graphique". Only the changed rows are redrawn.
- Keys: those of the web page; F1 FUNCT, F5 warm start, F9 paste the clipboard, F11 full
  screen, F10 quits. Button bar (FUNCT, CTRL-C, ESC, RESET, Coller) for a touch screen,
  removed by `--sans-boutons`.
- Status line: host, light (`R` on, `r` lost, `-` waiting), age of the last cycle.
  Daemon unreachable or Oric not called yet: a message on the screen; the client tries
  again by itself every 2 s.
- `--mem`: shows a dump from `tools/run_test.sh`, without a daemon.

On the Pi Zero (Raspberry Pi OS with desktop): `sudo apt install python3-tk` if
`python3 -c "import tkinter"` fails; the repository (or only `tools/remote_tk.py`,
`tools/oric_ecran.py` and `src/font.s`, in their places); then
`python3 tools/remote_tk.py --plein-ecran --sans-boutons --demon http://...`. On a
480 x 320 screen, the Oric's screen is 320 x 280 dots (480 x 280 with `--etirer`).

### 9.3 Tests without an Oric: `tools/faux_demon.py`

Serves the interface of § 9.1 (web page included) like the daemon, with a test card
(colours, inverse, double height, blinking, whole font, `A>` prompt that shows the
typing) or Oricutron dumps shown in turn; it prints the keys received.

    python3 tools/faux_demon.py [--http 8040] [--periode S] [DUMP.mem ...]
    python3 tools/remote_tk.py --demon http://localhost:8040

`python3 tools/oric_ecran.py DUMP.mem OUTPUT.png` draws a dump with the same rendering,
to compare it with Oricutron's screenshot (`OUTPUT.png` from `run_test.sh`).

### 9.4 The Pi Zero as the Oric's screen: `tools/pizero_ecran.sh`

Starts the X server on the text console where it is typed (tty1), without a desktop or a
window manager, with the window of § 9.2 full screen, without a mouse pointer and
without screen blanking. F10 in the window: back to the console; if the window stops on
an error, it is started again.

    DEMON=http://192.168.1.20:8040 tools/pizero_ecran.sh   # daemon on the Mac
    FAUX=1 tools/pizero_ecran.sh                           # test card, no Oric

- Variables: `DEMON` (default `http://localhost:8040`), `FAUX=1` (also starts
  `faux_demon.py` on the Pi Zero, arguments in `FAUX_ARGS`), `OPTIONS` (options of
  `remote_tk.py`, default `--sans-boutons`); other options can follow the command.
- To be started from the console itself, not through ssh (the X server takes the
  current terminal).
- Packages, on Raspberry Pi OS Lite: `sudo apt install --no-install-recommends
  xserver-xorg xinit x11-xserver-utils python3-tk fonts-dejavu-core`.
- At start-up: automatic login on the console (`raspi-config`, System Options, Boot /
  Auto Login, Console Autologin), then at the end of `~/.bash_profile`:

        if [ "$(tty)" = /dev/tty1 ] && [ -z "$DISPLAY" ]; then
          ~/cpa-oric/tools/pizero_ecran.sh
        fi

  A login through ssh is not affected (it is not on tty1).

### 9.5 Showcase: `tools/vitrine.py`

CP/A shown in a loop, with nobody at the keyboard, for the page's spectators (§ 9.6): the
showcase types on the Oric through the daemon, like someone using it.

    python3 tools/vitrine.py [--demon URL] [--humain S] [--scenes a,b,...]
                             [--langue fr|en] [--une]
    python3 tools/vitrine.py --liste

- **Pace**: one showpiece scene (`heure`, `mosaique`, `edit`, `debug`, `cmder`,
  `edsprite`; marked `*` by `--liste`), then two commands at the prompt, and so on; in
  each group, weighted random draw, never the same one twice in a row; less than a
  second between two scenes (0.3 to 1 s). A program erased by CMDER comes first at the
  next showpiece scene.
- **Scenes**: `heure` (the clock: HORLOGE, CLOCK in English), `mosaique` (MOSAIQUE,
  MOSAIC), `dir` (DIR, DIRS, STAT), `completion` (TAB on the command then on the name,
  TYPE), `type`, `aide` (HELP and a topic), `menus` (FUNCT: bar, pulled-down menus,
  closed with ESC: never RETURN, since the bar reopens on the last menu seen and the
  first item of Screen is SPLIT mode), `usb` (USBDIR, `USBDIR /S`, USBMOUNT), `debug`
  (`DEBUG MEM`: `L C000`, `D BB80`, the screen seen by itself...), `edit` (a `.GRX`
  browsed, a search, quit without changing anything), `cmder` (moves, sorts, info; six
  times out of ten, if both programs are there, erases one of them: filter `/` on its
  name, DEL, `O` / `Y` only if the question names that file, then no filter), `edsprite`
  (EDSPRITE on `DUN.SPR`, otherwise another `.SPR` of the disk, otherwise `edit`: cursor
  in the grid, codes `^H`, copy of the sprite (`^C` `^V` in the list) flipped by
  Draw/Horizontal mirror, View/Background, View/Animate, then `^Q` and `O` / `Y` at the
  "File changed. Quit (Y/N)?" question: nothing is saved, the scene plays again
  identically; its redefined characters are seen by the page, § 4 "Font"), `echo` (the
  time at the prompt), `divers` (VER, MEM, CLS). Typing at 5 to 12 keys per second, with
  hesitations; end-of-screen pauses (`-- Suite` / `-- More`) passed after a reading time.
- **Two GRAPHER programs** in text mode (LORES), in `tools/vitrine/` (French) and
  `tools/vitrine/en/` (English): `MOSAIQUE.GRX n` / `MOSAIC.GRX n` (n pictures drawn at
  random: rain of colours, concentric frames that turn, stripes that scroll with
  `ROTH`, checkerboard, bands with `ROTV`; each cell is a paper attribute, hence a
  colour tile; ~13 s per picture; 2 or 3 pictures) and `HORLOGE.GRX n` / `CLOCK.GRX n`
  (the time in big colour digits for n seconds, 15 to 25; the Oric has no clock: the
  program asks for the time, the showcase types it, field by field, waiting for each
  input field to open, shown as an inverse-video cell). Digits drawn row by row: a
  string of attributes per pattern of 3 dots, written by `PRINT`; a second lasts
  `DELAY 16` plus ~0.68 s of drawing, measured in Oricutron: ~2 s late per minute. At
  start-up, the showcase notes those that are missing (`DIR *.GRX`, and `DIR *.SPR` for
  EDSPRITE); the first scene that uses one writes it in EDIT, in front of everyone:
  pasted text, `^S`, `^Q`, then runs it. Nothing else is written, erased or changed.
- **Language**: the same showcase for `cpa.dsk` and `cpa-en.dsk`; the system's language
  is recognised at start-up from the menu bar (`Systeme` or `System`), `--langue fr|en`
  forces it. Table `TEXTES` in `vitrine.py`: what the showcase reads (`-- Suite` /
  `-- More`, `(O/N)` / `(Y/N)` questions...) and types (answer `O` / `Y`, HELP topics,
  ECHO sentences, programs: `MOSAIC.GRX` and `CLOCK.GRX` in English, same drawings,
  texts and comments translated). Tried in Oricutron on both disks.
- **Recovery**: each scene starts from the prompt, empty line, in text mode (`TEXT` typed
  if the Oric was left in SPLIT or HIRES); otherwise ESC, `^Q`, `^C`, RETURN, and as a
  last resort the warm start (`/reset`). Link not active: waiting. Daemon unreachable:
  new try every 10 s.
- **Someone types** (page, window, command line; any `POST` without the `X-Vitrine`
  header): the scene stops and the showcase waits `--humain` seconds (120) without
  typing before resuming. Typing on the Oric's own keyboard is not seen: stop the
  showcase (CTRL-C) to use it.
- The showcase reads the time of the machine where it runs (Mac, simon, Pi 400): Paris
  time.

### 9.6 Publishing on the Internet: gateway, read-only

The daemon has neither authentication nor encryption (home network). To show the Oric to
others (a forum), a gateway on a public server (VPS) serves the page over HTTPS and only
lets reading through; the home router opens no port.

    browser --HTTPS--> Apache (VPS) --WireGuard--> daemon (Pi 400) :8040 --> Oric

    python3 tools/passerelle.py --vps NAME [--chemin /cpa/] [--reseau 10.77.0]
                                [--utilisateur pi] [--depot /home/pi/cpa-oric]

writes into `logs/passerelle/` (not versioned: the keys do not leave the machine) the
files to copy and `LISEZMOI.txt`, the commands in order. WireGuard keys computed by the
script (X25519, RFC 7748, checked against `wg pubkey`), kept in `cles.json`: running the
script again does not change them.

- **Tunnel**: WireGuard between the VPS (`10.77.0.1`) and the daemon's machine
  (`10.77.0.2`), with a pre-shared key on top, opened from home
  (`PersistentKeepalive = 25`): no port forwarding on the router; the VPS listens on UDP
  51820. `10.77.0` rather than `10.8.0`, taken by OpenVPN by default.
- **Daemon** (`cpa-remote.service`): `remote.py serve --spectateurs 10.77.0.1`: everything
  arriving through the tunnel is read-only (§ 9.1), whatever Apache's setting, and cannot
  pretend to be the Oric.
- **Showcase** (`cpa-vitrine.service`, § 9.5) on the same machine, so that the spectators
  see something move. Demonstration disk in A:.
- **Apache** (`mod_proxy`, `mod_proxy_http`, certificate already in place on the VPS),
  `cpa-oric.conf` included in the HTTPS `VirtualHost`:

        RedirectMatch ^/cpa$ /cpa/
        <Location /cpa/>
            ProxyPass http://10.77.0.2:8040/ timeout=30 retry=5
            ProxyPassReverse http://10.77.0.2:8040/
            <LimitExcept GET HEAD>
                Require all denied
            </LimitExcept>
        </Location>
        <LocationMatch "^/cpa/(journal|version)">
            Require all denied
        </LocationMatch>

  `timeout=30` lets the long polling of `/ecran` (5 s) through. The trailing slash
  matters: the page's addresses are relative. Tried in a local Apache 2.4: page,
  redirection, 403 on `POST` and `/journal`, 503 beyond the limit, page without buttons.
- To let someone trusted type later: a second path protected by a password, which reaches
  the daemon from an address other than the spectators'.

## 10. Batches

1. **`HOSTS` and calling through the modem** (§ 8): done.
2. **Measurements** (on the real Oric): XFER of 7.8 KB received in 5 to 10 s; sent in
   less than 10 s since `ac_txw` waits 5 s.
3. **Driver, REMOTE and daemon**: done. `tools/test_remote.sh` (Oricutron, real time,
   ~7 min): the screen kept by the daemon is that of the memory dump after DIR and a
   FUNCT menu, EDIT (2 KB pasted, `^S`, `^Q`, then TYPE; file identical to the text),
   CMDER, GRAPHER in SPLIT, GRAPHER in LORES with two sprites (the daemon's font equals
   the dump's, sprites included), `$FD 'B'` during CMDER (console still on), daemon
   killed in the middle of an answer (the Oric goes on, then calls a new daemon);
   refusal of TERM and XFER, `REMOTE`, `REMOTE OFF`. What Oricutron does not show: the
   `r` light (its modem always accepts the byte sent).
4. **Web page** (§ 9): done. Rendering compared dot by dot with `oric_ecran.py`, keys and
   Paste tried with the fake daemon (computer and phone browsers simulated), page served
   by the daemon. It only displays and sends what the daemon of batch 3 already knows how
   to do.
5. **Showcase and spectators** (§ 9.5, § 9.6): done. Each scene played in Oricutron by a
   local daemon (programs written in EDIT identical to the byte); spectators refused
   (403) and page read-only.
6. **Font** (§ 4): done. Redefined characters followed in text mode; page and window
   draw them.

To check on the real Oric: `essais-materiel.md` (remote console).

## 11. Open questions

None. Set aside: a copy of everything that goes through CONOUT to the Mac (a log); the
screen is enough, and `PUT` already captures a command's output into a file.
