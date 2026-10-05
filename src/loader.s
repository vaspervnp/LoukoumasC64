;; ===========================================================================
;; loader.s - LOUKOUMAS on the disc: the splash, then the game.
;;
;; The CPC's loader (louk.bas) puts the REVIVE8BIT screen up and then runs the
;; game. This does the same on the C64 (loukc64.md 10):
;;
;;   1. its own working part goes to $C000, out of the way of everything;
;;   2. the splash is unpacked and shown - a multicolour bitmap in VIC bank 3,
;;      where the game's own bitmap will be;
;;   3. the KERNAL loads LOUKC64, the packed game, which sits so that it ends
;;      at $BFFF - above the end of the game it unpacks to, so the output
;;      never reaches the stream it is reading;
;;   4. ROMs out, the game unpacked to $0801, and its own start runs.
;;
;; It uses the KERNAL's serial LOAD, so it works with any drive and any
;; SD2IEC; a fast loader is the next step if the wait wants shortening.
;; Assembled on its own: 64tass -D GAME_START=... -D GAME_LZ_AT=...
;; ===========================================================================

        .cpu "6502"

        .include "config.s"

lz_src          = $f9           ; KERNAL-free zero page: the RS-232 pointers
lz_dst          = $fb
lz_m            = $fd
SPLASH_TMP      = $9000         ; the splash unpacks here, then is spread out

SETLFS          = $ffba
SETNAM          = $ffbd
LOAD            = $ffd5

        * = $0801
        .word (+), 2026
        .null $9e, format("%d", boot)
+       .word 0

boot
        sei
        ldx #0                  ; the working part, to $C000
-       lda body_store,x
        sta body,x
        lda body_store+$100,x
        sta body+$100,x
        inx
        bne -
        jmp body

splash_lz
        .binary "../build/splash.lz"

body_store
        .logical $c000
body
        lda #$35                ; KERNAL and BASIC out while it unpacks: the
        sta $01                 ; decruncher reads back what it wrote
        lda #<splash_lz
        sta lz_src
        lda #>splash_lz
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

        lda #$37                ; the KERNAL back, and its interrupt
        sta $01
        cli
        lda #name_end-name
        ldx #<name
        ldy #>name
        jsr SETNAM
        ldx $ba                 ; the drive it was loaded from
        bne +
        ldx #8
+       lda #1
        ldy #1                  ; to the address in the file
        jsr SETLFS
        lda #0
        jsr LOAD
        bcs failed

        sei
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

name    .text "loukc64"         ; 64tass -a: lower case is PETSCII upper case
name_end

        .include "unpack.s"
        .cerror * > $c200, "the loader's working part is more than two pages"
        .cerror * > BMP_SCREEN, "the loader runs into the splash's screen"
        .endlogical
