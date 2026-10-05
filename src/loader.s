;; ===========================================================================
;; loader.s - LOUKOUMAS on the disc: the splash, then the game.
;;
;; The CPC's loader (louk.bas) puts the REVIVE8BIT screen up and then runs the
;; game. This does the same on the C64 (loukc64.md 10):
;;
;;   1. its last part - the game's unpacking - goes to $C000, out of the way
;;      of the game it unpacks over this;
;;   2. SPLASH, the splash packed, is loaded, unpacked and shown - a
;;      multicolour bitmap in VIC bank 3, where the game's own bitmap will be;
;;   3. LOUKC64, the packed game, is loaded. It sits so that it ends at $BFFF,
;;      above the end of the game it unpacks to, so the output never reaches
;;      the stream it is reading;
;;   4. ROMs out, the game unpacked to $0801, and its own start runs.
;;
;; The two files come through the fast loader (fastload.s) on a 1541, and
;; through the KERNAL's LOAD on anything else - an SD2IEC, a 1581. This part
;; is kept small, because the KERNAL loads it whatever the drive.
;;
;; Assembled on its own by tools/mkdisk64.py:
;;   64tass -D GAME_START=... -D GAME_LZ_AT=... -D SPLASH_LZ_AT=...
;; ===========================================================================

        .cpu "6502"

        .include "config.s"

lz_src          = $f9           ; KERNAL-free zero page: the RS-232 pointers
lz_dst          = $fb
lz_m            = $fd
fl_p            = $f7           ; the fast loader's pointer: RS-232 too
fl_acc          = $02           ; and its byte being put together
SPLASH_TMP      = $9000         ; the splash unpacks here, then is spread out

SETLFS          = $ffba
SETNAM          = $ffbd
LOAD            = $ffd5

FILE_NAMES      = ("splash", "loukc64")   ; in the order they are loaded

        * = $0801
        .word (+), 2026
        .null $9e, format("%d", boot)
+       .word 0

boot
        ldx #0                  ; the last part, to $C000
-       lda body_store,x
        sta loaded,x
        inx
        bne -
        stx $d020               ; a black screen until there is a picture
        stx $d011

        ldx $ba                 ; the drive it was loaded from
        bne +
        ldx #8
+       stx fl_dev
        jsr fast_load
        ror fl_slow             ; bit 7: not a 1541

        ldx #0                  ; the splash
        jsr get_file
        sei
        lda #$35                ; KERNAL and BASIC out while it unpacks: the
        sta $01                 ; decruncher reads back what it wrote
        lda #<SPLASH_LZ_AT
        sta lz_src
        lda #>SPLASH_LZ_AT
        sta lz_src+1
        lda #<SPLASH_TMP
        sta lz_dst
        lda #>SPLASH_TMP
        sta lz_dst+1
        jsr unpack

        ldx #0                  ; spread it: 8000 bitmap, 1000 screen, 1000 colour
-
        .for p = 0, p < 31, p += 1
        lda SPLASH_TMP+p*256,x
        sta BITMAP+p*256,x
        .next
        cpx #64
        bcs +
        lda SPLASH_TMP+31*256,x
        sta BITMAP+31*256,x
+
        .for p = 0, p < 4, p += 1
        lda SPLASH_TMP+8000+p*250,x
        sta BMP_SCREEN+p*250,x
        lda SPLASH_TMP+9000+p*250,x
        sta COLOUR_RAM+p*250,x
        .next
        inx
        bne -
        lda SPLASH_TMP+10000    ; the background

        sta $d020
        sta $d021
        lda $dd00               ; VIC bank 3, leaving the serial bus bits be
        and #%11111100
        ora #DD00_BANK
        sta $dd00
        lda #D018_BMP
        sta $d018
        lda #D016_BMP
        sta $d016
        lda #D011_BMP
        sta $d011
        lda #0
        sta $d015

        ldx #1                  ; and the game
        jsr get_file
        jmp loaded

;; get_file - file X of FILE_NAMES to its load address, the fast way or the
;; KERNAL's.
get_file
        bit fl_slow
        bmi +
        jmp fast_get
+       lda #$37                ; the KERNAL back, and its interrupt
        sta $01
        cli
        lda name_len,x
        pha
        ldy name_hi,x
        lda name_lo,x
        tax
        pla
        jsr SETNAM
        lda #1
        ldx fl_dev
        ldy #1                  ; to the address in the file
        jsr SETLFS
        lda #0
        jsr LOAD
        bcs failed
        rts

        .include "fastload.s"

fl_dev          .byte 0
fl_slow         .byte 0
fl_at           .word 0
fl_tmp          .word 0
fl_first        .byte 0
fl_end          .byte 0

names   .for n in FILE_NAMES
        .text n
        .next
name_len .byte len(FILE_NAMES[0]), len(FILE_NAMES[1])
name_lo  .byte <names, <(names+len(FILE_NAMES[0]))
name_hi  .byte >names, >(names+len(FILE_NAMES[0]))

body_store
        .logical $c000
loaded  sei
        lda #$35                ; the game's map: RAM, and I/O
        sta $01
        lda #<GAME_LZ_AT
        sta lz_src
        lda #>GAME_LZ_AT
        sta lz_src+1
        lda #<$0801
        sta lz_dst
        lda #>$0801
        sta lz_dst+1
        jsr unpack
        jmp GAME_START

failed  inc $d020               ; the file is not there: say so, in the border
        jmp failed

        .include "unpack.s"
        .cerror * > SECBUF, "the loader runs into the fast loader's sector"
        .cerror * > $c100, "the loader's last part is more than a page"
        .cerror * > BMP_SCREEN, "the loader runs into the splash's screen"
        .endlogical

        .cerror body_store+$100 > SPLASH_LZ_AT, "the loader runs into where the splash loads"
