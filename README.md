# ΛΟΥΚΟΥΜΑΣ — Commodore 64

The C64 port of LOUKOUMAS, the overweight cat's great sausage chase, from the
Amstrad CPC original in `../LoukoumasCPC`. The plan is `loukc64.md`; working
notes are in `CLAUDE.md`.

![The disc inlay.](docs/cover-en-front.png)

The manual: [English](MANUAL.en.md) ([PDF](docs/manual-en.pdf)),
[Ελληνικά](MANUAL.el.md) ([PDF](docs/manual-el.pdf)).

## Build and run

Needs 64tass and VICE (x64sc); Python 3 with Pillow for the tools.

```bash
make
```

```bash
make run
```

```bash
make check
```

```bash
make profile
```

`build/loukoumas.prg` is the game, unpacked, for development. The disc,
`build/loukoumas.d64`, is what to play: `LOAD"*",8` and `RUN` - the loader
shows the REVIVE8BIT splash while it loads the packed game (`make rundisk`),
through its own fast loader on a 1541 and the KERNAL's on anything else.

## Controls

| | Joystick (port 2) | Keyboard |
|---|---|---|
| Left / right | ← → | O / P |
| Jump | ↑ or fire | Q or SPACE |
| Roll | ↓ | A |
| Belly-flop | ↓ + fire in the air | A + SPACE in the air |
| Language (title) | | L |
| Quit to title | | RUN/STOP |

## Where it stands (loukc64.md §12)

| | | |
|---|---|---|
| M0 | toolchain, ROMs off, vectors, raster IRQ | done |
| M1 | HUD (text) / room (bitmap) split | done |
| M2 | box renderer, colour allocator, `c64roomcheck.py` | done — room 1 matches the Python render byte for byte |
| M3 | the cat: sprites, controls, physics, platforms, roll, flop | done |
| M4 | enemies, collision, lives, grace, stun | done |
| M5 | pickups, HUD, BCD score, milk and flash, way out | done — the room-1 route passes |
| M6 | all 29 rooms, decals, roomcheck | done — no clash; every room finished on hard with no life lost in the Python model (`tools/c64route.py`, `tools/routes.txt`); rooms 1, 6 and 9 also played through in VICE |
| M7 | text in both languages, title, difficulty, game over, RUN/STOP | done — the title is the CPC's painting as a multicolour bitmap, lettered per language |
| M8 | SFX and music | done — the CPC's title tune, converted from its Arkos song; checked by pitch from a VICE recording, not yet by ear or on a 6581/8580 |
| M9 | profiling, CI | done — `make profile` plays all 29 rooms in VICE with no frame missed (worst step 225 of 312 lines); the way out now opens from a copy made at room load instead of a nine-frame repaint; the HUD split no longer slips a line under sprites; CI on every push (`make modelcheck`, and the VICE checks where VICE has ROMs) |
| M10 | .d64, packer, loader, NTSC | done — own LZ packer (66%), a loader showing the REVIVE8BIT splash, a fast loader of our own (about 23 s from power-on on a 1541, against 100 s; KERNAL fallback on other drives); NTSC |
| M11 | manuals, cover | done — `MANUAL.en.md`/`MANUAL.el.md` with the C64's keys and loading, A5 booklets, the disc inlay, and screen shots taken in VICE (`make manualshots covers manuals`) |
| M12 | real hardware | not started |
