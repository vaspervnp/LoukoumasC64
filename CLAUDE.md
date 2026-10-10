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
| `$C800-$C9FF` | the font (charset), 55 glyphs |
| `$CA00-$CFFF` | sprite blocks 64-87, the enemies' second frames (`SPRITE_MEM2`) |
| `$D000-$DFFF` | sprite blocks 0-63, in the RAM under the I/O |
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
- **Each split's interrupt comes a line early** and waits for its line, so the
  three writes go in within the split line's first 30 cycles whatever the
  sprites take. Raised on the split line itself they finished about 66 cycles
  in, and with sprites on the line slipped into the next one, a badline: the
  room's first line under the HUD came out black.
- **Write order: into the bitmap `$D016`, `$D011`, `$D018`; into text `$D011`,
  `$D016`, `$D018`.** The writes land while the beam draws the split line,
  and between them the VIC is half in one mode; in these orders every
  half-state is blank. Bitmap mode first, into the bitmap, showed hires
  bitmap in the HUD's screen-code colours; multicolour first, into text, put
  sprite data on the title's footer line.
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
- **Every enemy has two pictures**: the CPC's, and a second drawn for the
  C64 in `assets/sprites.txt` (`NAME2`: wings up, legs apart, a ball's seams
  turned), the same size and colours. Four descriptors in a row - right,
  left, second right, second left - and `enemies_shadow` adds 8 every
  `ANIM_STEPS` steps (`en_anim`, counted in `enemy_bounce`): a stunned enemy
  holds its pose, and on easy they all move their legs slower.
- 75 blocks: 64 under the I/O and the rest past the font in the charset slot
  (`SPRITE_MEM2`). No split reads that part of the slot since the write
  orders in §3; descriptors hold the VIC's own pointer values, 0 for no
  overlay.
- The cat blinks during his grace after a lost life (`INVUL_FRAMES`).
- Collision is software, boxes as on the CPC (`cat_hits_box`).

## 7. Text

- No literal text in the sources: `tools/mktext64.py` turns `text/*.txt` and
  `assets/font.txt` (copied from the CPC) into `font.s` and `strings.s`. The
  glyph index is the screen code.
- HUD and footer: hires text, 40 columns. Big text (title, ΤΕΛΟΣ, ΜΠΡΑΒΟ!) is
  drawn into the bitmap through `fill_box`, a run of font pixels per box.
- One program, both languages; it starts in English and `L` switches on the title.

## 7a. Music

The title music is written for the SID, in `assets/music/title.txt` (the
format is at its top), and compiled by `tools/mkmusic64.py` into `music.s`:
a byte-code stream per voice - notes, rests, glides, instrument changes -
and a table of instruments. `music_play` in `sound.s` steps it every frame:
waveform, envelope, pulse sweep, vibrato after a delay, a fixed gate length
for staccato, chords as one-note-a-tick arpeggios, glides and pitch drops
(the bonk, the snare's snap). Every bar is checked to be 8 rows (16ths) and
the voices to loop at the same row.

It uses **all three voices**: it plays only on the title and the chooser,
where there are no effects, and `play_screen` stops it and `sfx_init`
silences the chip before the game. If music ever plays in the game, voice 3
and the master volume (the effects' fade) have to be shared out first. To
check it without ears: `x64sc -sounddev wav -soundarg x.wav` - not in warp,
which writes no sound - and look at onsets and pitch.

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
- `PROFILE=1` keeps the worst step's logic time in raster lines in
  `prof_max` (whole frames included: a step that runs past the next frame
  entry counts more than 312), every frame the game loop missed in
  `prof_over`, and the longest room draw in frames in `prof_load`. A room's
  drawing and the game-over banners are not counted as missed frames.
- **`make profile` (`tools/c64profile.py`, loukc64.md M9)** plays every room's
  route in VICE, stopping on the frame the model says the cat goes out on,
  and fails on a room not finished, a life lost or a frame missed. All 29
  pass; the worst step is 225 of 312 lines (room 5), most are 180-195. Rooms
  draw in 41-79 frames with the screen blanked: per-cell overhead in
  `fill_box`, and the open way out drawn and kept as well (`exit_save`).
- **The way out opens from a copy.** Painting it open through the allocator
  on the frame of the fifth sausage took up to nine frames. `room_load` now
  measures the cells the open exit covers (`fill_box` with `fb_measure`),
  draws it open, keeps those cells (`EXIT_OPEN_BUF`, up to `EXIT_CELLS`) and
  puts the shut one back; `exit_step` copies it in three cell rows a frame.
  `c64roomcheck.py` checks every open exit for clashes and for size.
- `make modelcheck` is the same without VICE: the room check and every route
  in the model (`c64profile.py --sim`). CI (`.github/workflows/check.yml`)
  runs it on every push, and `make check profile` too when its VICE has the
  C64 ROMs.
- `tools/routes.txt` holds a clean run on hard for all 29 rooms: rooms 1, 6
  and 9 by hand - 6 and 9 need a belly-flop timed to land on the top shelf,
  because the canary's arc sweeps it, as it did on the CPC - and the rest
  from `tools/c64route.py ROOM` (or `--all`, ~30 min), a beam search on the
  model. A route goes on pressing after the exit: replay it to the exit
  frame, not its last input.
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

`make` (64tass) → `build/loukoumas.prg` and `.d64` (`tools/d64.py`). Generated sources
are committed; `make gen` regenerates them (Python 3 + Pillow). `src/rooms.s`
was generated once by `tools/convrooms.py` from the CPC build and is hand-edited
source now — `make` never regenerates it, and re-running the converter throws
away every `(C64: ...)` edit.

### The disc (loukc64.md 10)

`tools/mkdisk64.py` builds `build/loukoumas.d64` with three files:

- `LOUKOUMAS` (`src/loader.s`, 6 blocks): the only file the KERNAL must
  load, so it is kept small. It copies its last part (the game's unpacking)
  to `$C000`, blanks the screen, starts the fast loader, loads `SPLASH`,
  unpacks it into bank 3 and shows it, loads `LOUKC64`, banks the ROMs out,
  unpacks the game to `$0801` and jumps to its `start`.
- `SPLASH`: the REVIVE8BIT splash (the CPC's `revive8b.scr`, converted by
  `tools/mksplash64.py` - a mode 0 screen is a multicolour bitmap's shape),
  packed, loading at `$1000`.
- `LOUKC64`: the game packed by `tools/pack64.py`, with a load address that
  ends it at `$BFFF`. Its start overlaps the end of the unpacked game; that is
  safe while no output byte lands on stream still to be read, which
  `pack64.lowest_start` checks token by token. `mkdisk64.py` refuses a build
  that breaks it.

exomizer is not installed, so `pack64.py` is a byte-aligned LZ of our own
(66% on the game; the title painting is most of what does not pack) with an
80-byte decruncher, `src/unpack.s`.

**The fast loader** (`src/fastload.s`, read its header): drive code uploaded
with M-W and started with M-E finds `SPLASH` and `LOUKC64` in the directory
itself and sends them a sector at a time, two bits per ATN toggle on CLK and
DATA. The C64 clocks it and only ever reads late, never early, so badlines
(the splash is on screen) do not matter and nothing counts cycles. A drive
whose ROM does not say "1541" at `$E5C5` (SD2IEC, 1571, VICE's virtual drive)
gets the KERNAL's LOAD instead - checked in VICE for the 1571 and the virtual
drive.

- With true drive emulation the game is in memory about 23 s after power-on
  (PAL and NTSC), against about 100 s with the KERNAL's load.
- A sector takes 45 ms to send; the DOS wants a read job in long before its
  sector comes round, so the two files are written with an interleave of 12
  (`tools/d64.py` writes the disc, not c1541, for that). At 10, the DOS's,
  every other sector is missed by a turn; at 11 it works in VICE with under
  2 ms in hand; 12 tolerates 8 ms of added delay.
- The drive writes ATNA ($1800 bit 4) equal to ATN in every value it puts on
  the bus, or the 1541's hardware ATN acknowledge pulls DATA low.
- VICE breakpoints set while autostart is still typing can be lost; time the
  disc with `-limitcycles N -exitscreenshot`, or connect the monitor about
  1 s into a warp run and break in the drive (`device 8:`).

- **64tass `-a` makes upper-case ASCII shifted PETSCII.** A file name written
  `"LOUKC64"` came out `$CC $CF...` and the drive said FILE NOT FOUND; write
  names in lower case.
- The game image in memory after the loader matches `loukoumas.prg` byte for
  byte (checked with a VICE memory dump).

### The manuals and the inlay (loukc64.md M11)

`MANUAL.en.md` and `MANUAL.el.md` are the source; `make manuals` lays them out
as the A5 booklet (`tools/mkmanual.py`, the CPC's in the inlay's colours,
needs fpdf2), `make covers` draws the inlay (`tools/mkcover64.py`, the CPC's
with the C64's machine strip, loading box and features) and
`make manualshots` retakes the screen shots (`tools/mkshots64.py`). All of
`docs/` is committed. The shots are scripted runs in VICE through
`c64run.py`: Greek presses `L` on the title, rooms are played on hard along
`c64route.py` routes (the lounge is `routes.txt`'s room 9), and the game over
is a poke (`--poke cat_lives=1@5`, which `mkscript.py` turns into a write at
the start of that frame). The manual's facts are the C64's, not the CPC's:
the border flashes only when the milk gives a life back, a stunned enemy
blinks grey, and easy and medium slow walkers to a half and two thirds and
flyers to a third and a half, the CPC's rates (`diff_tab`: a walker steps on
`walk_steps` frames of every `walk_period`, because on hard it steps every
frame, where the CPC's stepped every other).

## 11. Conventions

- Comment the reason, not the instruction, as in the CPC sources.
- Every user-visible number in the level comes from `config.s` or `rooms.s`.
- Each milestone stays runnable on its own (`STARTROOM`, `SCRIPT`, `PROFILE`).
- Real hardware is the authority when it disagrees with VICE; record what was
  verified where in `docs/`.
