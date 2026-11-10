# Connecting a Raspberry Pi Pico W (WiFi modem) to the LOCI

English translation of `docs/loci-modem-wifi.md` (the French document is the reference;
the other documents it points to are in French unless an English version exists in
`docs/en/`).

**Status**: the link works in both directions (Oric, LOCI, Pico W, WiFi, Mac), with LOCI
firmware 0.3.98 (`tools/loci-acia-diag/`, see "LOCI firmware").

Goal: give a real Oric network access (sending and receiving files) through the LOCI and
a USB WiFi modem, for CP/A. This document describes the hardware and how to prepare it.
On the CP/A side, `TERM.COM` (terminal, `docs/en/manuel.md` "Serial terminal") and `XFER.COM`
(files, "File transfer") exist and dial the number themselves, taken from the `HOSTS`
file ("Hosts: HOSTS"); the BIOS serial driver and the remote console (`REMOTE`) are
described in `docs/en/console-distance.md`.

## Principle

The LOCI presents to the Oric an emulated 6551 serial chip (ACIA) at address `$0380`, at
9600 baud, connected to a USB modem plugged into its port. The PicoWiFiModemUSB modem is a
Raspberry Pi Pico W that behaves like a Hayes modem: you talk to it with AT commands and,
instead of dialling a number, it opens a TCP connection over WiFi
(`ATDT-host:port`, the `-` turning off telnet mode to get raw bytes; `ATD` alone,
without `T`, `P` or `I`, answers `ERROR`).

## Hardware

- **A Raspberry Pi Pico W** (the WiFi version of the Pico, about 7 €). The test version
  of the firmware targets the Pico W; nothing indicates that it works on the Pico 2 W.
- **A cable to connect it to the LOCI.** The Pico W has a micro-USB socket, the LOCI a
  USB-C socket in host mode: you need a male USB-C to male micro-USB cable that carries
  data (or a USB-C OTG adapter and a standard micro-USB cable). A charge-only cable
  powers the Pico (its LED lights up) but the LOCI sees no modem:
  `$038C` stays at 0 in `ACIADIAG`, the ACIA status stays `70` and the Oric's orders
  (DTR, speed) are not applied.
- **Perhaps a USB hub.** The LOCI has only one USB port. If `cpa.dsk` is on a USB stick,
  a hub is needed for the stick and the Pico. The LOCI documentation recommends a small
  USB 2.0 hub, rather old and simple: most recent hubs do not work with it.
  Tried: a powered Anker hub refused; an **unpowered** hub recognises the stick and the
  Pico (all the current then goes through the Oric: see "Power supply").
- **To avoid the hub**, copy `cpa.dsk` into the LOCI's internal memory (15 MB); the
  Pico then has the USB port to itself.

## Power supply

- The LOCI draws its power from the Oric's expansion port, and each USB device adds to the
  consumption. Oric power supply unit: at least 9 V / 1 A.
- With a powered hub, the LOCI cuts, for safety, the power it supplies to the expansion
  port: the Oric must have its own power supply (the normal case).

- Without a powered hub, the LOCI, the stick and the Pico draw their current from the
  Oric's 5 V regulator, which dissipates as heat the difference between the input and 5 V:
  a 12 V unit makes it noticeably hotter than a 9 V unit. Keep an eye on the heat near the
  Oric's power input.

## Pico firmware

- **v0.1.0** (the only published release, `wifi_modem_v0.1.0.uf2` under "Assets", a
  collapsed list): **does not keep the settings**. `AT&W` freezes the Pico (WiFi interrupt
  during the flash write); you have to unplug it, and nothing is saved.
- The repository code (June 2026, commit `c65fcd0`) fixes this defect, but no `.uf2` is
  published: build it (below). It adds `AT$SCAN` (visible WiFi networks) and a
  restart into BOOTSEL mode when the host opens the USB port at **1200 baud**. Now the LOCI
  passes on to the Pico the speed that the Oric writes into the ACIA control register
  (`loci-firmware`, `src/mia/oric/acia.c`): an Oric program at 1200 baud (Oricomms)
  would make the modem disappear. For the LOCI, build without this restart: in
  `src/usb_cdc.c`, empty `tud_cdc_line_coding_cb`. Otherwise the Pico ignores the speed: over
  USB, all speeds work.
- Building (Linux or Mac, with `cmake`, `ninja` and `arm-none-eabi-gcc` and its newlib):

      git clone https://github.com/sodiumlb/PicoWiFiModemUSB.git
      cd PicoWiFiModemUSB && git submodule update --init
      (cd src/pico-sdk && git submodule update --init)
      (cd src/pico-extras && git submodule update --init)
      mkdir src/bld && cd src/bld && cmake -G Ninja .. && ninja    # -> wifi_modem.uf2

- **Version for CP/A**: `tools/pico-modem/wifi_modem-cpa.uf2`, the code of `c65fcd0`
  with Nagle kept (WiFi packets grouped: the remote console and sending with XFER
  no longer have stops of several seconds), reading everything waiting on USB
  (the original read one byte per loop iteration: ~650 bytes/s at most from the Oric to
  WiFi) and without the 1200 baud restart; patch and build: `tools/pico-modem/LISEZMOI.md`.

## LOCI firmware

- **0.3.98 "acia-diag"** (`tools/loci-acia-diag/`): the 0.3.1 sources (repository
  `sodiumlb/loci-firmware`, branch `main`), the LOCI 0.3.0 ROM rebuilt and built in,
  and read-only check registers: pattern `A5 5A 0F F0` at `$0384-$0387` and
  `$0344-$0347`, reads of `$0381` seen (`$0388`), writes to `$0380-$0383` seen
  (`$0389`), last bytes written to command and control (`$038A`, `$038B`), modem mounted
  and DTR (`$038C`, bits 0 and 1), marker `$D1` (`$038D`). `CONFIG.SYS` keeps its format.
  Instructions and reading of the results: `tools/loci-acia-diag/LISEZMOI.md`. Built with
  GCC 13 and newlib-nano: `printf` without decimals, so the stick is described as `1: MSC  GB General
  UDisk` (without its size), in the LOCI menu as for CP/A (`docs/en/usb.md` § 2). Mounting
  an image from the internal memory (`0:`) freezes the LOCI with it: CP/A refuses it.
- **Official 0.3.1**: `TERM /D` read `A7 4C D0` there (status, command, control), but the
  Pico was then connected by a cable without data; the counter-test must be redone with the
  right cable (`docs/suite.md` item 4).
- The firmware's issue 17 branch (ACIA at `$0340` or `$0380`, March 2026) is not
  finished: it saves `CONFIG.SYS` before the file system is mounted and does not
  reapply the setting it read; do not install it as it stands.

## Preparing the Pico, on the Mac

1. **Install the firmware.** Plug the Pico into the Mac while holding its BOOTSEL button:
   it appears as a disk (RPI-RP2). Copy the `.uf2` onto it; the Pico restarts by
   itself.
2. **Configure the WiFi.** Plugged in again normally, the Pico is a serial port:

       screen /dev/tty.usbmodem* 9600

   then type:

       AT$SSID=network name
       AT$PASS=password
       ATC1
       AT&W

   The Pico then connects to the WiFi at each power-up (2.4 GHz WiFi only).
   `ATI` gives the IP address and the connection status, `AT&V1` the saved settings,
   `AT?` the list of commands. To quit `screen`: control key (not ⌘) and A, then K,
   then Y; if it stays stuck, close the window and `killall screen` (otherwise the port stays
   taken).
3. **Check.** On the Mac, in another terminal: `nc -l 2323`. In `screen`:
   `ATDT-MAC_IP:2323` (Mac address: `ipconfig getifaddr en0`). What is typed on one side must appear on the other. `+++`
   (a one-second pause before and after) returns to command mode, `ATH` hangs up.

Default modem settings: 9600 baud, 8 bits, no parity, 1 stop bit.
`ATDT[+=-]host[:port]`: `+` simulated telnet, `=` real telnet, `-` no telnet;
port 23 by default. `ATNETn`: 0 no telnet, 1 real, 2 simulated.
Host names: the modem resolves names through the network's DNS (`ATDT-ipinfo.io:80`:
CONNECT); not mDNS names ending in `.local` (`NO CARRIER`). Speed-dial numbers with aliases
(`AT&Zn=host:port,alias`, `ATDSn`, or the alias after `ATDT`), according to the
PicoWiFiModem documentation: `AT&Z0=...` answers OK but the saved entry does not change
(flash write by `AT&W`? it freezes v0.1.0); unresolved.

## Plugging the Pico into the LOCI

- The configured Pico plugs into the LOCI's USB port, directly or through the hub.
- The LOCI recognises USB modems of this type (CDC) and presents them to the Oric as the
  serial port at `$0380`; it sets the modem to 9600 baud when plugged in, then to the speed
  that the Oric writes into the ACIA control register.
- No setting in the LOCI menu: it is automatic (the LOCI takes the first USB serial device
  that declares itself a modem). The LOCI menu sees the stick and the Pico through an
  unpowered hub (observed).

## Testing the chain

1. **The LOCI and the modem**: `ACIADIAG.TAP` (`tools/loci-acia-diag/`) mounted as a tape,
   BASIC, `CLOAD""`. Expected with the Pico plugged in: marker `D1`, both patterns correct,
   modem `1`, ACIA before `10 2 0`, 10 reads and 2 writes seen, `B 1E`, ACIA after
   `18 B 1E` (the modem has already answered), modem `3`. Under CP/A: `DEBUG`, `D 0380`.
2. **The whole chain**: `TERM /E` on the Oric side, `nc -l 2323` on the Mac side; `AT` answers `OK`,
   then `ATDT-MAC_IP:2323`: what is typed on one side appears on the other. Tried:
   it works in both directions. Oricomms (an 80s
   Prestel terminal) crashes at the first key on this setup: do not use it.

The LOCI's ACIA (`loci-firmware`, `src/mia/oric/acia.c`): registers always present at
`$0380-$0383`; status: bit 3 received, bit 4 transmitter free, bits 5 and 6 (DCD, DSR) at 1 as long
as no modem is mounted; nothing is sent as long as DTR (bit 0 of the command) is 0;
reception through a 32-byte buffer, filled only if it has room (the modem waits:
no loss if the Oric is slow).
Access: absolute `LDA` / `STA` only. An indexed write (`STA (zp),Y`, `STA abs,X`,
`POKE` in BASIC) reads the target address before writing it: on the data register, that is a
received byte consumed (warning from the LOCI's author, defence-force forum, topic 2926).
Same topic: sodiumlb states that the published binaries (0.3.1) work at `$0380`; another
user nevertheless reads `$36`/`$76` there (undriven bus), cause not found. With 0.3.98:
`70 02 00` at startup without a modem, `10 02 00` with the Pico mounted, then `18 0B 1E` after
setup (see "LOCI firmware" for 0.3.1).

## CP/A side

1. `TERM.COM`: done (`docs/en/manuel.md`, "Serial terminal").
2. Serial driver in the BIOS (`src/serial.s`): CP/M `PUNCH` / `READER` entries connected to
   the ACIA (port set by function 117: `$0380` on LOCI, `$031C` in Oricutron), and
   the remote console (`REMOTE`, `docs/en/console-distance.md`). Done.
3. `XFER.COM`: sending and receiving files in XMODEM-CRC (128-byte blocks
   acknowledged one by one), with the server `tools/xfer_server.py` on the Mac or the Pi: done
   (`docs/en/manuel.md`, "File transfer"; `tools/test_xfer.sh` in Oricutron).
   TERM and XFER share the library `progs/acia_inc.s` (port, setup, polled reading and
   writing), which the BIOS driver will reuse.

Throughput: 9600 baud, about 1 KB per second.

## Flow control

No byte is lost when the Oric is slow to read, without RTS/CTS and without anything on the Oric side:

- LOCI (`loci-firmware`, `src/mia/oric/acia.c`): it reads the USB modem only for the free
  space in its 32-byte buffer; as long as the Oric does not read, USB does not advance.
- Pico W (`PicoWiFiModemUSB`, `src/ser_cdc.c`): `ser_putc` waits until USB accepts
  the byte; the TCP receive buffer (`src/tcp_support.h`) gives the window back to the sender
  (`altcp_recved`) only if it stays below one segment: the Mac waits in turn.

The buffers are therefore in the LOCI, the Pico and the TCP stack, not in the Oric: the CP/A
serial driver works by polling. This is only true of the LOCI: a real 6551 (Oricutron at
`$031C`, serial card) has only one receive byte and loses it if reading is late.

In the other direction (from the Oric to the Mac), the Pico W sometimes holds back sending: the LOCI
stops emptying the ACIA transmit register for several tenths of a second, in fits and starts
(observed with XFER: 7,774 bytes sent in 27 s, pauses every 8 to 12 blocks; receiving
the same file takes 5 to 10 s, without pauses). The Mac's delayed acknowledgements play no
part in it (tried). A program must therefore wait several seconds for the transmitter to be free before
concluding that the modem is absent: `ac_txw` in `acia_inc.s` waits 5 s (it used to wait
0.3 s and lost bytes, hence re-requested blocks and the pauses).

Line endings: the modem, in command mode, takes CR (or LF) as the end of a command; `nc` on
the Mac sends LF alone and expects LF. TERM displays CR, LF alone and CR LF as a line
break; towards `nc`, `TERM /E /L` (RETURN sends CR LF).

Another avenue: the LOCI also exposes an interface (registers at `$03A0`) to read and write
ordinary files on its USB stick; a CP/A command could export a file
to the stick without going through `mkdisk.py`. In the meantime, the LOCI's stick or card contains
`cpa.dsk`, from which `python3 tools/mkdisk.py get cpa.dsk LETTRE.TXT lettre.txt` extracts a
file on the Mac.

## Without an Oric: a machine that simulates it

The Oric, LOCI, Pico W chain is only one way of providing CP/A's serial port. What a
replacement must present to CP/A, nothing more:

- the LOCI's ACIA at `$0380-$0383` (status: bit 3 received, bit 4 transmitter free, bit 6
  no DSR; nothing sent without DTR; reading the data register consumes the byte), with a
  receive buffer that only fills when it has room ("Flow control");
- the LOCI's signature (`$03AF`, `$03B0-$03B7`, tested by `ac_lchk` in `acia_inc.s`),
  otherwise CP/A looks for the ACIA at `$031C` as in Oricutron; with the signature, the
  USB stick commands (`USBDIR`, `EXPORT`, `USBMOUNT`...) also call the LOCI's file
  interface (`$03A0`);
- a Hayes modem: `AT`, `+++`, `ATH`, `ATDT-host:port`, answers `OK`, `CONNECT`,
  `NO CARRIER`, `ERROR` (`ac_dial` in `acia_inc.s`, and the driver's automatic redial,
  `docs/en/console-distance.md` § 4).

On the network side, nothing then tells a replacement from the real Oric: same `HOSTS`,
same daemon (`tools/remote.py`), same `tools/xfer_server.py`.

In service: a bare-metal emulator on a Raspberry Pi 3B+, based on Phosphoric, which
emulates the LOCI and uses the Pi's WiFi ("Un Oric dans un RPI ZERO" project); it is the
showcase's machine (`docs/en/console-distance.md` § 9.6). The real Oric is switched off:
without a powered hub, the LOCI, the stick and the Pico draw their current from its 5 V
regulator, which gets too hot ("Power supply").

## Sources

- PicoWiFiModemUSB: https://github.com/sodiumlb/PicoWiFiModemUSB
- LOCI User Manual: https://github.com/sodiumlb/loci-hardware/wiki/LOCI-User-Manual
- LOCI Mode d'emploi: https://github.com/sodiumlb/loci-hardware/wiki/LOCI-Mode-d'emploi
- ProphetOric (LOCI + PicoWiFiModemUSB, ACIA at $0380): https://github.com/benedictemarty/ProphetOric
- Phosphoric (emulator with LOCI and WiFi): https://github.com/benedictemarty/Phosphoric
- defence-force forum, LOCI thread: https://forum.defence-force.org/viewtopic.php?t=2593&start=885
