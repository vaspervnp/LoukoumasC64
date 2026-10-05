# ΛΟΥΚΟΥΜΑΣ — Commodore 64

The C64 port of LOUKOUMAS, the overweight cat's great sausage chase, from the
Amstrad CPC original in `../LoukoumasCPC`. The plan is `loukc64.md`; working
notes are in `CLAUDE.md`.

## Build and run

Needs 64tass and VICE (x64sc, c1541); Python 3 with Pillow for the tools.

```bash
make
```

```bash
make run
```

```bash
make check
```

`build/loukoumas.prg` autostarts; `build/loukoumas.d64` has it as `LOUKOUMAS`.

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
| M9 | profiling | `PROFILE=1` build; room 1 peaks at 125 of 312 lines |
| M10 | .d64, packer, loader, NTSC | .d64 and NTSC; no packer or loader yet (exomizer is not installed) |
| M11-M12 | manuals, real hardware | not started |
