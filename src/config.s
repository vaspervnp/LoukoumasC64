;; ===========================================================================
;; config.s - the one place the machine layout and the level geometry live.
;;
;; Everything else derives its numbers from here, the way the CPC's
;; config.asm is the only place an overscan constant is written down. If a
;; 24 or a 181 turns up anywhere else in the sources, it is a bug.
;; ===========================================================================

;; --- Memory (loukc64.md 3) -------------------------------------------------
;; The VIC sees one 16 KB bank at a time and everything it shows has to live
;; in it: sprites, the charset, both screens and the bitmap. Bank 3, $C000-
;; $FFFF, is the one with nothing else in it: no shadow of the character ROM
;; (banks 0 and 2 have one), and the VIC reads the RAM under the I/O and under
;; the KERNAL, which the CPU has no other use for. That leaves $0801-$BFFF
;; whole for the program - loukc64.md 3 put the bank at $4000 and the code
;; did not fit under it.
VIC_BANK        = $C000
TEXT_SCREEN     = $C000         ; screen RAM while the beam is in a text band
BMP_SCREEN      = $C400         ; screen RAM while it is in the bitmap
CHARSET         = $C800         ; the HUD and footer font, 2 KB
SPRITE_MEM      = $D000         ; 64 blocks, in the RAM under the I/O
BITMAP          = $E000         ; 8000 bytes, in the RAM under the KERNAL
BITMAP_END      = BITMAP+8000
SPR_PTR0        = (SPRITE_MEM-VIC_BANK)/64      ; pointer of block 0
COLOUR_RAM      = $D800

;; In idle state the VIC shows the byte at the top of the bank, $FFFF - which
;; is the high byte of the IRQ vector. The shake's blank lines are idle lines,
;; so that byte must be 0: the vector points at a JMP in zero page (irq.s).
IDLE_BYTE       = VIC_BANK+$3FFF
IRQ_TRAMPOLINE  = $fd           ; $FD-$FF: JMP irq_handler

WORK            = $9000         ; RAM the program builds for itself, not in
WORK_END        = $C000         ; the file: tables, pickup buffers
CODE_LIMIT      = WORK          ; the code and its tables must end below this

;; $DD00 bits 0-1 select the bank, inverted: %00 is bank 3.
DD00_BANK       = %00

;; $D018: screen base in the high nibble (1 KB units), charset or bitmap in
;; the low (2 KB / 8 KB units), both relative to the bank.
D018_TEXT       = ((TEXT_SCREEN-VIC_BANK)/$400)<<4 | ((CHARSET-VIC_BANK)/$800)<<1
D018_BMP        = ((BMP_SCREEN-VIC_BANK)/$400)<<4 | ((BITMAP-VIC_BANK)/$2000)<<3

;; $D011: DEN (bit 4), 25 rows (bit 3), YSCROLL 3 - the standard picture.
;; Bit 5 is bitmap mode. $D016: 40 columns (bit 3), bit 4 multicolour.
D011_TEXT       = $1b
D011_BMP        = $3b
D016_TEXT       = $08
D016_BMP        = $18

;; --- The beam (PAL 6569) ---------------------------------------------------
;; 63 cycles a line, 312 lines a frame, 50.125 Hz. With YSCROLL 3 the first
;; displayed line is 51, so character row r begins at 51 + 8r and is a
;; badline there.
FIRST_LINE      = 51
LAST_LINE       = FIRST_LINE+200-1      ; 250
FRAME_IRQ_LINE  = LAST_LINE+1           ; in the bottom border

;; The HUD is two character rows of hires text over the bitmap's first two
;; rows, which are kept empty. The split is written on the last line of the
;; HUD, which is blank in every glyph, so a mode change in the middle of it
;; shows the same background either side.
HUD_ROWS        = 2
HUD_SPLIT_LINE  = FIRST_LINE+HUD_ROWS*8-1       ; 66

;; The title and the difficulty chooser are the other way up: the picture on
;; top and a footer of hires text along the bottom.
FOOT_ROW        = 19
FOOT_SPLIT_LINE = FIRST_LINE+FOOT_ROW*8-1

;; --- Sprites ---------------------------------------------------------------
;; A sprite at X = 24, Y = 50 has its top-left pixel on the first pixel of
;; the 320x200 picture. X is in hires pixels, so a multicolour pixel is two.
SPR_X0          = 24
SPR_Y0          = 50

;; --- The play area (loukc64.md 4.3) ----------------------------------------
;; 160 x 200 multicolour pixels. Lines 0-15 are the HUD, 16-199 the room.
;; Every x in the level data is a multicolour pixel, every y a line of it.
SCREEN_W        = 160
SCREEN_H        = 200
PLAY_TOP        = HUD_ROWS*8            ; 16

;; Shelves are a jump apart: 24 lines, three character rows. Their tops sit
;; on line 8k+5 so a shelf three lines thick stays inside one cell row - one
;; colour slot rather than two.
SHELF_STEP      = 24
SHELF_H         = 3
FLOOR_Y         = 22*8+5                ; 181
SHELF_1         = FLOOR_Y-SHELF_STEP
SHELF_2         = FLOOR_Y-SHELF_STEP*2
SHELF_3         = FLOOR_Y-SHELF_STEP*3
SHELF_4         = FLOOR_Y-SHELF_STEP*4
SHELF_5         = FLOOR_Y-SHELF_STEP*5
FLOOR_H         = SCREEN_H-FLOOR_Y

        .cerror (FLOOR_Y & 7) != 5, "the floor is not on the shelf grid"
        .cerror ((FLOOR_Y+SHELF_H) & 7) != 0, "the floor's colour must start a cell row"
        .cerror (SHELF_STEP & 7) != 0, "shelves must be whole cell rows apart"
        .cerror SHELF_4 < PLAY_TOP+24, "no headroom over the top shelf"

;; --- The cat's physics, 8.8 fixed point -------------------------------------
;; The CPC's numbers times 0.75 (loukc64.md 4.3): height is v^2/2g and time
;; is v/g, so scaling both by the same factor scales the jump's height and
;; keeps its duration. The CPC cleared 38 scanlines with shelves 32 apart;
;; this clears 28.7 with shelves 24 apart, in the same 17 frames up.
GRAVITY         = $0030                 ; 0.1875 px/frame/frame
JUMP_V          = -$0360                ; -3.375 px/frame
FLOP_V          = $0600                 ; +6.0 once the belly commits
MAX_FALL        = $0480                 ; +4.5 terminal velocity

;; The rise of a standing jump, in 1/256 lines: sum of v + kg for the frames
;; it is still going up. Worked out here so the asserts below are about the
;; physics, not about a number someone wrote down once.
JUMP_FRAMES     = -JUMP_V/GRAVITY
JUMP_RISE       = (-JUMP_V*JUMP_FRAMES - GRAVITY*JUMP_FRAMES*(JUMP_FRAMES+1)/2)/256
        .cerror JUMP_RISE < SHELF_STEP+2, "the jump does not clear one shelf"
        .cerror JUMP_RISE >= SHELF_STEP*2, "the jump clears two shelves"

;; Across: the CPC walked a byte - 2 of its 192 pixels - a frame. The same
;; fraction of 160 is 1.67, and the fraction byte makes that free.
WALK_STEP       = $01ab                 ; 1.67 px/frame
ROLL_STEP       = $0355                 ; twice that
WALK_BIT        = $04                   ; the walk cycle changes every 4 frames
FLOP_STUN       = 14                    ; frames flat on the floor after a flop

;; How far a belly-flop reaches up and down: one shelf either way, not two.
FLOP_REACH_Y    = 30
        .cerror FLOP_REACH_Y <= SHELF_STEP || FLOP_REACH_Y >= SHELF_STEP*2, "FLOP_REACH_Y must be one shelf"

;; The cat. Every picture of him is 12 pixels wide; only the height changes.
CAT_W           = 12
CAT_H           = 20                    ; standing, the height rooms seat him at
        .cerror CAT_H > 21, "the cat does not fit a sprite"

;; --- Game -------------------------------------------------------------------
LIVES_CEILING   = 9                     ; one digit in the HUD
INVUL_FRAMES    = 100                   ; two seconds of grace after a respawn
SHAKE_LEN       = 6
MILK_FLASH_LEN  = 12
MILK_FLASH_COL  = 7                     ; yellow
NO_MILK         = 255

;; Which room the game starts in. Always 0 in a build anyone plays; a test
;; build passes -D STARTROOM=n.
        .weak
STARTROOM       = 0
SCRIPT          = 0                     ; 1: input comes from script.s
PROFILE         = 0                     ; 1: play_loop measures itself
        .endweak
