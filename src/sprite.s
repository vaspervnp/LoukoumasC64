;; ===========================================================================
;; sprite.s - the shadow sprite registers.
;;
;; On the CPC this file was most of the frame: save the background, blit
;; through a mask, put the background back, in an order worked out fresh
;; every frame so the beam never caught a sprite half drawn. Here the VIC
;; does all of it. What is left is filling eight shadows the frame interrupt
;; copies into the chip in the border (irq.s), and that is the whole file.
;;
;; Sprite n's number goes in spr_n; a picture is always a pair - the overlay
;; with the second colour, in front, at n, and the body at n+1. The frame
;; descriptor says which blocks and which colours (src/sprites.s).
;;
;;   0, 1   the cat
;;   2..7   the three enemies, a pair each
;; ===========================================================================

bit_n   .byte 1, 2, 4, 8, 16, 32, 64, 128

;; ---------------------------------------------------------------------------
;; spr_pair - frmp = a frame, spr_n = the overlay's sprite number, spr_px,
;; spr_py = the picture's top left in play coordinates. spr_grey, if not 0,
;; is a colour both halves are drawn in instead of their own.
;; ---------------------------------------------------------------------------
spr_pair
        lda spr_px              ; X = 24 + 2 px, nine bits
        asl
        sta tmp
        lda #0
        rol
        sta tmp+1
        lda tmp
        clc
        adc #SPR_X0
        sta tmp
        bcc +
        inc tmp+1
+       lda spr_py
        clc
        adc #SPR_Y0
        clc
        adc shake_y             ; the picture slid down; so does the cast
        sta tmp+2

        ldx spr_n
        jsr _place
        inx
        jsr _place

        ldx spr_n
        ldy #1                  ; the overlay
        lda (frmp),y
        clc
        adc #SPR_PTR0
        sta spr_ptr,x
        ldy #3
        lda (frmp),y
        jsr _grey
        sta spr_col,x
        ldy #1
        lda (frmp),y
        beq +                   ; nothing in it: leave it off
        lda spr_en
        ora bit_n,x
        sta spr_en
        jmp _body
+       lda bit_n,x
        eor #$ff
        and spr_en
        sta spr_en
_body   inx
        ldy #0
        lda (frmp),y
        clc
        adc #SPR_PTR0
        sta spr_ptr,x
        ldy #2
        lda (frmp),y
        jsr _grey
        sta spr_col,x
        lda spr_en
        ora bit_n,x
        sta spr_en
        rts

_grey   ldy spr_grey
        beq +
        tya
+       rts

_place  lda tmp
        sta spr_xlo,x
        lda tmp+2
        sta spr_y,x
        lda tmp+1
        beq +
        lda spr_msb
        ora bit_n,x
        sta spr_msb
        rts
+       lda bit_n,x
        eor #$ff
        and spr_msb
        sta spr_msb
        rts

;; ---------------------------------------------------------------------------
;; spr_hide_pair - spr_n and the one after it, off.
;; ---------------------------------------------------------------------------
spr_hide_pair
        ldx spr_n
        lda bit_n,x
        ora bit_n+1,x
        eor #$ff
        and spr_en
        sta spr_en
        rts
