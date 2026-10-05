# CLAUDE.md — LoukoumasC64

Project guidance for the Commodore 64 port of LOUKOUMAS.
Target: **C64 PAL**, 6510 @ 0.985 MHz, VIC-II 6569/8565, SID 6581/8580.

The plan is `loukc64.md` (Greek). The game it ports is the Amstrad CPC version
in `../LoukoumasCPC`, whose own CLAUDE.md is the reference for what the game
*is*. This file is about what is different here, and why.

---

## 1. What does not come over — do not rebuild it

Half of the CPC's CLAUDE.md exists because the CPC has no hardware sprites
and sixteen kilobytes to spare. None of that applies, and none of it is to be
reintroduced "for safety":

| CPC | C64 |
|---|---|
| Overscan, CRTC registers, CRTC types, rupture, `line_tab` | Gone. The VIC shows 320x200; `video.s` has tables of cell rows. |
| Software sprites: save/restore/blit, draw order, `FRAMES_PER_RENDER` | Gone. Hardware sprites; shadow registers copied in the border. **Render and logic both at 50 Hz.** |
| `enemy_tangled`, `enemies_tangled`, `--debris`, `--beam`, `exit_pending` | Gone. Sprites never touch the bitmap, so the door is painted the moment it opens. |
| The erase/draw "window" for background changes | Gone. Only pickups change the bitmap, and they keep their own cells. |
| Packed tables, `DATA_ORG,DATA_STORE`, LZSS onto the screen | Gone. The sprites and font travel behind the code and are copied into the VIC bank at boot. |
| Shake through R7 | YSCROLL in the HUD split (`irq.s`), plus the same offset on every sprite. |
| PSG through the PPI, mixer bit 6 | SID voice 3 for effects, voices 1-2 for the title music. Both step in the frame interrupt. |

## 2. Memory

`$01 = $35`: RAM everywhere, I/O at `$D000`. The KERNAL is never coming back.

| Address | What |
|---|---|
| `$02-$5F` | zero page: pointers, the allocator's state, the cat |
| `$FD-$FF` | `JMP irq_handler` — the IRQ vector points here (see below) |
| `$0801-` | BASIC stub, code, read-only tables (the title picture is 10 KB of them), then the sprite blocks and font on their way to bank 3 |
| `$9000-$BFFF` | workspace (`vars.s`, `.virtual` — not in the file) |
| `$C000` / `$C400` | text screen / bitmap screen RAM |
| `$C800-$CFFF` | the font (charset), 55 glyphs |
| `$D000-$DFFF` | sprite blocks, in the RAM under the I/O |
| `$E000-$FF3F` | the multicolour bitmap, in the RAM under the KERNAL |
| `$FFFA-$FFFF` | NMI and IRQ vectors — **`clear_all` must stop at `$FF3F`** |

- **VIC bank 3, not bank 1.** `loukc64.md` §3 put the bank at `$4000`; the code
  and tables came to 14.4 KB and did not fit under it. Bank 3 has no
  character-ROM shadow and leaves `$0801-$BFFF` whole.
- **The idle byte is `$FFFF`, which is the IRQ vector's high byte.** The VIC
  shows it on idle lines — and the shake makes idle lines. So the vector points
  at a `JMP` in zero page (`$FD`) and its high byte is 0.
- Sprite blocks live under the I/O: `machine_init` banks the I/O out (`$01 =
  $34`) to copy them. Pointer `SPR_PTR0 + n` is block `n`.
- Asserts at the bottom of `main.s` and `vars.s` keep code, file and workspace
  inside their regions. Keep them.

## 3. The screen

- **The display list** (`irq.s`): up to four `(line, $D011, $D016, $D018)`
  entries walked in a ring. Entry 0 is in the bottom border (line 251) and is
  also the frame: shadow sprite registers → VIC, `sfx_update`, `frame_count`.
  - play: 251 hires text (the HUD) → 66 multicolour bitmap
  - title: 251 multicolour bitmap → 202 hires text (the footer)
- **Split write order is `$D011`, `$D016`, `$D018`.** For a few cycles the VIC
  is half in one mode; in this order every half-state is blank on the split
  line. The other order put sprite data on the title's footer line.
- The line a split is written on must be blank in both modes: bitmap rows 0-1
  are kept empty under the HUD (`clip_top`), and every glyph's 8th row is blank.
- **Never write a colour register that has not changed.** On an 8565 every
  write shows a grey dot where the beam is. `frame_work` compares first.
- The logic never writes the VIC. It fills shadows; the frame entry copies
  them while the beam is in the border.

## 4. Geometry (`config.s`, the only place it is written down)

| | CPC | C64 |
|---|---|---|
| play area | 192 x 252 | 160 x 184 (lines 16-199) |
| shelves | 32 apart | **24 apart, top on line 8k+5** |
| floor | 236 | **181** (`FLOOR_Y`) |
| jump | v −4.5, g 0.25: 38 lines | v −3.375, g 0.1875: **28.7 lines**, same 17 frames |
| walk / roll | 1 / 2 bytes a frame | 1.67 / 3.33 px (8.8 fixed point, `cat_xf`) |
| cat | 12 x 24 / 16 / 12 | 12 x 20 / 14 / 10 |
| `FLOP_REACH_Y` | 40 | 30 |

Rooms are in multicolour pixels across (0-159) and lines down (0-199).
`config.s` asserts the jump clears one shelf and not two, from the physics
constants themselves.

## 5. Colour (the real difficulty — loukc64.md §5.2)

A multicolour cell is 4x8 and shows four colours: the room's light (`$D021`,
pen 0) and three slots. `video.s` fills every box cell by cell and gives its
colour a slot; the rules, in order, are at the top of `video.s` and **are a
contract with `tools/c64roomcheck.py`**, which runs the same algorithm in
Python. Change one, change the other — `make check` compares the two renders
of room 1 byte for byte.

- A slot whose colour no surviving pixel shows is free. "Surviving" excludes the
  pixels the current box is about to cover: an outline-then-fill leaves the
  outline's colour only where the outline still is.
- **A clash is judged on the finished picture**: a cell where some pixel shows a
  colour other than the one last painted there. Damage later painted over
  (a car's wheels under the floor band) is not a clash. `make check` fails on
  one clashing cell.
- **Pickups never damage furniture.** A sausage that finds its cell full
  borrows the nearest of the cell's colours instead (`soft`, `colour_dist`).
  That is a warning (`c64roomcheck.py -v`), not a failure.
- Pickups are **5 lines tall**, so on a shelf at 8k+5 they sit in lines
  8k..8k+4 — the shelf's own cell row and nothing above it. Their highlight is
  pen 2, the shelf's yellow, so a pickup on a bare shelf costs two colours.
- The floor has the shelves' yellow edge (lines 181-183) and its own colour
  from 184: the row the floor's top is in is also the row of every piece of
  furniture's feet.
- Decals that could not fit three colours to a cell are recoloured in
  `tools/mksprite64.py` (`DECAL_REMAP`); the CPC's PNGs stay as they are.
- Room and prop edits made for colour are marked `(C64: ...)` in `rooms.s`.
- Hard-won rules for the next room: align the parts of a prop that differ in
  colour to multiples of 4 across where you can; don't let a shelf cross a
  prop that already has three colours in that cell row; two props of three
  colours each must not share a cell column at the same height.

## 6. Sprites

- Shared multicolour colours: `$D025` black, `$D026` white. Each picture is a
  **pair**: the body (own colour, plus black and white) and an overlay sprite
  in front carrying a second colour. A third colour is mapped to the nearest
  and `mksprite64.py` says so.
- 0-1 the cat; 2-7 the three enemies, a pair each. **All eight are in use**, so
  the plan's stun stars became a grey blink of the stunned enemy instead.
- The cat blinks during his grace after a lost life (`INVUL_FRAMES`).
- Collision is software, boxes as on the CPC (`cat_hits_box`).

## 7. Text

- No literal text in the sources: `tools/mktext64.py` turns `text/*.txt` and
  `assets/font.txt` (copied from the CPC) into `font.s` and `strings.s`. The
  glyph index is the screen code.
- HUD and footer: hires text, 40 columns. Big text (title, ΤΕΛΟΣ, ΜΠΡΑΒΟ!) is
  drawn into the bitmap through `fill_box`, a run of font pixels per box.
- One program, both languages; it starts in Greek and `L` switches on the title.

## 7a. Music

The CPC's title tune is an Arkos Tracker 3 song (`src/loukmus.asm` there);
AKG has no 6502 player, so `tools/mkmusic64.py` decodes the exported tracks
into (note, lines) lists for `music_play` in `sound.s`: voices 1 and 2,
speed 5, Arkos note 57 = A-4. The one instrument (15 down to 1, a step a
tick) becomes attack 0 / decay 300 ms with the gate let go after two ticks.
It plays on the title and the chooser; `play_screen` stops it and the effects
own the chip. The master volume is the effects' fade too, which is fine only
because the two never sound at once - if music ever plays in the game, the
effects' fade has to move to their envelope. To check it without ears:
`x64sc -sounddev wav -soundarg x.wav ...` and look at onsets and pitch.

## 7b. The title picture

`tools/mktitle64.py` turns the CPC's painting (`assets/art/title.jpg`) into
`src/title.s`: cropped, scaled to 160x168 (cell rows 0-20), every pixel to
its nearest C64 colour, then each cell keeps the three colours (besides the
shared background, chosen to make the whole picture cheapest) that cost
least. The name and subtitle go in first as locked pixels, so the lettering
never loses a cell to the painting; the subtitle has a black rim to read over
the wall tiles. Rows 0-4 exist once per language (10.4 KB in all), rows 5-20
once. Row 21 is empty and the footer is rows 22-24 (`FOOT_ROW`): the split's
line must be blank, and so must bitmap byte 7, which text mode reads there.
Judge it with `--preview` (build/title-<lang>.png, 2:1) or in VICE - its
yellow is warmer than the preview's.

## 8. Testing

- `make check`: `tools/c64check.py` — the static room check, the room-1 render
  compared with VICE's memory, and the room-1 route in the Python model and in
  VICE. **Room 1's collision geometry is frozen while that route passes.**
- `tools/c64sim.py` is the game's logic in Python (cat physics, enemies,
  pickups). Plan routes there — it is milliseconds a run — then confirm in VICE.
  It has matched VICE frame for frame; when they disagree, the sim is wrong.
- `tools/c64run.py --play ROUTE --frames N --peek var ... --shot x.png`:
  builds with `-D SCRIPT=1 -D PROFILE=1`, plays the route in x64sc, halts the
  program at frame N (`script_halt`) and reads memory through the label file.
  Route frames in `--play` are room frames; the menus are 91 frames in front.
- `PROFILE=1` keeps the worst frame's logic time in raster lines in `prof_max`,
  and the longest room draw in frames in `prof_load`. Room 1: 125 of 312 lines
  on a frame a sausage is eaten; rooms draw in 44-53 frames with the screen
  blanked. Most of that is per-cell overhead in `fill_box` on nested boxes
  (the door is four full boxes deep); the allocator skips its presence scan
  for a cell the box covers whole, which gives the same answer.
- `tools/c64route.py ROOM` (or `--all`, ~30 min) beam-searches the model for
  a clean run on hard. All 29 rooms have one: 26 found by the search, rooms 6
  and 9 by hand (`tools/routes.txt`) - both need a belly-flop timed to land on
  the top shelf, because the canary's arc sweeps it, as it did on the CPC.
- `tools/vicemon.py` is a bare remote-monitor client for poking at a running
  build; `tools/roomview.py N` draws a room's render with the cell grid.
- VICE autostart gives up if the monitor breaks in while it injects; the
  harness waits three seconds before it connects, and retries.

## 9. PAL and NTSC

`detect_ntsc` watches the raster counter at boot (PAL reaches line 311, NTSC
262). On NTSC the display list is unchanged - the picture is lines 51-250 on
both - and the 50 Hz game keeps its timing by skipping one logic step in six
(`ntsc_tick` in `play_loop`) and one sound step in six (`frame_work`). A
skipped step does not read the controls either, so no key edge is lost and a
scripted run reads the same input on both. `c64run.py --ntsc` runs one.

## 10. Building

`make` (64tass) → `build/loukoumas.prg` and `.d64` (c1541). Generated sources
are committed; `make gen` regenerates them (Python 3 + Pillow). `src/rooms.s`
was generated once by `tools/convrooms.py` from the CPC build and is hand-edited
source now — `make` never regenerates it, and re-running the converter throws
away every `(C64: ...)` edit.

exomizer is not installed here; the `.prg` is 29 KB unpacked.

## 11. Conventions

- Comment the reason, not the instruction, as in the CPC sources.
- Every user-visible number in the level comes from `config.s` or `rooms.s`.
- Each milestone stays runnable on its own (`STARTROOM`, `SCRIPT`, `PROFILE`).
- Real hardware is the authority when it disagrees with VICE; record what was
  verified where in `docs/`.
