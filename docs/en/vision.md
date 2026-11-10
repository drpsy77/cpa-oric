# CP/A — vision

English translation of `docs/vision.md` (the French document is the reference; the other
documents it points to are in French unless an English version exists in `docs/en/`).

*My Oric back to life: create, develop and publish — all on the lovely little machine itself.*

## The sentence

Make people want to use their Oric again: create and develop on the machine itself, with
the ease of a present-day system, and run what is created there on any Oric.

## Why

An Oric stays in its cupboard when nothing on it is pleasant. BASIC and its editor have
aged, SEDORIC is hard to get into, the editors and assemblers of the time were laborious
to use. So people develop on the PC (OSDK) and play in an emulator: the machine is no
longer used. The LOCI has solved storage; what was missing was an environment that makes
you want to sit down in front of the Oric. CP/A is that environment: a smooth system,
tools that speak the same language, and everything needed to create without leaving the
machine.

## For whom

- First, the owner of an Atmos fitted with a LOCI who wants to create on the machine:
  games, drawings, programs.
- Then, through the `.TAP` output, any Oric owner: they receive what was created under
  CP/A and load it from a tape, without having CP/A.

## What matters, in this order

1. **Everything on the machine.** Write, draw, develop, compile, run, without going
   through a PC. The PC remains a workshop (building, tests), never a required step.
2. **Developing and compiling.** GRAPHER (interpreted to try things out, translated into
   assembler for speed) and ASM are the platform: games, but not only games.
3. **Open to the outside.** USB stick, network through the LOCI's WiFi modem, and the
   bridge to the basic Oric (`.TAP`, tape).
4. **The pleasure of use.** Same keys everywhere, menus, completion, history, clear
   messages: everything must be easy to pick up.
5. **Restraint.** Every resident addition must be justified, the rest goes into a `.COM`;
   everything works with a single drive.

## What CP/A is not

- An office suite: no word processor, no spreadsheet, no database. EDIT remains an editor
  (programs, scripts, data).
- A CP/M to catch up with function by function: we take from CP/M what is useful (user
  areas, IOBYTE: no).
- One more BASIC: the bridge goes towards the Oric's BASIC, not the other way round.
- A tool for the PC or for an emulator: the real Oric is the reference.

## Version 1.0

- **Creative workshop**: assisted drawing (more precise than the LOGO turtle), sprite and
  character editor, tiles.
- **GRAPHER as a platform**: a complete game written, drawn, debugged and translated on
  the Oric (game phases, tiles).
- **Bridge to the basic Oric**: a game made under CP/A loads on an Atmos without a disk
  drive, from a tape (`MKTAP`, `CASSETTE`).
- **Outside world**: file transfer and terminal through the LOCI's WiFi modem.
- Checked on the real hardware.

## How to decide

An idea enters the planned work (`docs/suite.md`) if it serves one of points 1 to 3
without betraying points 4 and 5. What serves none of the three waits, or is not done.

The pull-down menus and completion (file names and commands, `CPLCMD` option) are the
flagship features: they are what gives the Oric its flexibility, and the reason for CP/A
compared with SEDORIC. They are neither removed nor slimmed down to save space: space is
found elsewhere.

## Open questions

- Beyond its author: is CP/A offered to the Oric community (language of the messages and
  of the documentation, distribution)?
