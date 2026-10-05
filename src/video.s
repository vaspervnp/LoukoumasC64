;; ===========================================================================
;; video.s - the multicolour bitmap: clearing it, filling boxes into it, and
;; the colour allocator that makes that possible (loukc64.md 5.2).
;;
;; A multicolour cell is 4 x 8 pixels and can show four colours: the
;; background ($D021, bit pair 00), the two nibbles of its screen RAM byte
;; (01 high, 10 low) and its colour RAM nibble (11). The CPC could put any of
;; sixteen pens anywhere. So every box is drawn cell by cell, and in each cell
;; the box's colour is given a slot:
;;
;;   1. pen 0 is the room's light, the background: slot 0, nothing to take.
;;   2. a slot that already holds the colour is used as it is - 01, 10, 11
;;      in that order.
;;   3. otherwise the first of 01, 10 whose colour no pixel in the cell is
;;      still showing is taken. Pixels this very box is about to cover do
;;      not count: a white outline with a navy box inside it leaves white
;;      only on the rim, and the rim is what is still there.
;;   4. otherwise 11, the colour RAM, is taken - and if a pixel was still
;;      showing it, that is a clash: those pixels change colour. clash_count
;;      counts them, and tools/c64roomcheck.py, which runs this same
;;      algorithm on the same tables, refuses a room that has any.
;;   5. except for a pickup (soft set): a sausage never repaints the
;;      furniture it stands in front of. Its pixel takes whichever of the
;;      cell's four colours looks nearest instead, and soft_count counts
;;      that - a warning in the room check, not an error.
;;
;; The order of every choice above is part of the contract with the Python
;; copy. Change one and change the other, or the render check will say so.
;; ===========================================================================

;; Where each cell row starts, in the bitmap, the screen RAM and colour RAM.
bmp_row_lo      .for r = 0, r < 25, r += 1
                .byte <(BITMAP+r*320)
                .next
bmp_row_hi      .for r = 0, r < 25, r += 1
                .byte >(BITMAP+r*320)
                .next
scr_row_lo      .for r = 0, r < 25, r += 1
                .byte <(BMP_SCREEN+r*40)
                .next
scr_row_hi      .for r = 0, r < 25, r += 1
                .byte >(BMP_SCREEN+r*40)
                .next
col_row_lo      .for r = 0, r < 25, r += 1
                .byte <(COLOUR_RAM+r*40)
                .next
col_row_hi      .for r = 0, r < 25, r += 1
                .byte >(COLOUR_RAM+r*40)
                .next
txt_row_lo      .for r = 0, r < 25, r += 1
                .byte <(TEXT_SCREEN+r*40)
                .next
txt_row_hi      .for r = 0, r < 25, r += 1
                .byte >(TEXT_SCREEN+r*40)
                .next
cell8_lo        .for c = 0, c < 40, c += 1
                .byte <(c*8)
                .next
cell8_hi        .for c = 0, c < 40, c += 1
                .byte >(c*8)
                .next

;; A box's pixels inside one cell: the left edge at pixel 0-3 and the right.
lmask           .byte $ff, $3f, $0f, $03
rmask           .byte $c0, $f0, $fc, $ff
;; A cell byte with all four pixels in one slot.
slot_pat        .byte $00, $55, $aa, $ff

;; The CPC's sixteen pens as C64 colours (loukc64.md 5.5). Pen 0 is never
;; looked up - it is the background - and is here only to keep the index.
pen_colour      .byte 0         ;  0 the room's light
                .byte 10        ;  1 coral: paws, sausages -> light red
                .byte 7         ;  2 butter yellow: shelves -> yellow
                .byte 1         ;  3 white: outlines
                .byte 0         ;  4 black
                .byte 12        ;  5 grey: steel
                .byte 9         ;  6 olive: wood in shadow -> brown
                .byte 8         ;  7 orange: wood, brick
                .byte 5         ;  8 dark green
                .byte 13        ;  9 bright green
                .byte 11        ; 10 teal: deep water, tile -> dark grey
                .byte 3         ; 11 bright cyan: water, glass -> cyan
                .byte 2         ; 12 dark red -> red
                .byte 10        ; 13 bright red -> light red
                .byte 4         ; 14 purple
                .byte 15        ; 15 pale yellow: lamplight -> light grey

;; What lights a room: the C64 colour of the background and the border.
LIGHT_INDOOR    = 6             ; blue - a wall at three in the morning
LIGHT_DAY       = 14            ; light blue - nine o'clock outside a school
LIGHT_NIGHT     = 0             ; black - the roofs at midnight

;; ---------------------------------------------------------------------------
;; video_init - the tables the allocator wants, built once.
;;
;; ptab[b] has bit n set when any of the four pixels in byte b is in slot n.
;; ---------------------------------------------------------------------------
video_init
        ldx #0
_byte   lda #0
        sta tmp
        txa
        ldy #4
_pair   pha
        and #3
        sty tmp+1
        tay
        lda bit_of,y
        ora tmp
        sta tmp
        ldy tmp+1
        pla
        lsr
        lsr
        dey
        bne _pair
        lda tmp
        sta ptab,x
        inx
        bne _byte
        rts
bit_of  .byte 1, 2, 4, 8

;; ---------------------------------------------------------------------------
;; clear_all - bitmap, both screens and colour RAM to nothing. The text rows
;; are given white ink; the bitmap's colour RAM starts at 0.
;; ---------------------------------------------------------------------------
clear_all
        lda #<BITMAP
        sta ptr
        lda #>BITMAP
        sta ptr+1
        lda #0
        ldx #>8000              ; 31 whole pages, then the last 64 bytes:
        ldy #0                  ; past them, at $FFFA, are the vectors
-       sta (ptr),y
        iny
        bne -
        inc ptr+1
        dex
        bne -
        ldy #<8000-1
-       sta (ptr),y
        dey
        bpl -
        ldx #0
-       lda #0
        sta BMP_SCREEN,x
        sta BMP_SCREEN+$100,x
        sta BMP_SCREEN+$200,x
        sta BMP_SCREEN+$2e8,x   ; to $5FE7: the pointers above it are spared
        sta TEXT_SCREEN,x
        sta TEXT_SCREEN+$100,x
        sta TEXT_SCREEN+$200,x
        sta TEXT_SCREEN+$2e8,x
        sta COLOUR_RAM,x
        sta COLOUR_RAM+$100,x
        sta COLOUR_RAM+$200,x
        sta COLOUR_RAM+$2e8,x
        inx
        bne -
        lda #0
        sta clash_count
        sta clash_count+1
        sta soft_count
        sta soft_count+1
        sta soft
        rts

;; ---------------------------------------------------------------------------
;; text_ink - A = colour, X = first text row, Y = rows. Colour RAM for a band
;; of hires text.
;; ---------------------------------------------------------------------------
text_ink
        sta tmp
_row    lda col_row_lo,x
        sta cptr
        lda col_row_hi,x
        sta cptr+1
        sty tmp+1
        ldy #39
        lda tmp
-       sta (cptr),y
        dey
        bpl -
        ldy tmp+1
        inx
        dey
        bne _row
        rts

;; ---------------------------------------------------------------------------
;; clear_cells - X = first cell row, Y = rows: bitmap, screen and colour RAM
;; to nothing across the whole width. What a banner is drawn on.
;; ---------------------------------------------------------------------------
clear_cells
        sty tmp+1
_row    lda bmp_row_lo,x
        sta ptr
        lda bmp_row_hi,x
        sta ptr+1
        lda scr_row_lo,x
        sta sptr
        lda scr_row_hi,x
        sta sptr+1
        lda col_row_lo,x
        sta cptr
        lda col_row_hi,x
        sta cptr+1
        lda #0
        ldy #39
-       sta (sptr),y
        sta (cptr),y
        dey
        bpl -
        ldy #0                  ; 320 bitmap bytes: 256 and 64
-       sta (ptr),y
        iny
        bne -
        inc ptr+1
        ldy #63
-       sta (ptr),y
        dey
        bpl -
        inx
        dec tmp+1
        bne _row
        rts

;; ---------------------------------------------------------------------------
;; fill_box - bx, by, bw, bh, bpen: a filled rectangle in the room's pens.
;;
;; Clipped to the screen and to clip_top, which keeps the room out of the
;; bitmap rows under the HUD: they must stay empty, because the split is
;; written on their last line.
;; ---------------------------------------------------------------------------
fill_box
        lda bw
        beq _ret
        lda bh
        beq _ret
        lda bx                  ; right
        cmp #SCREEN_W
        bcs _ret
        clc
        adc bw
        bcs _clipr
        cmp #SCREEN_W+1
        bcc _okr
_clipr  lda #SCREEN_W
        sec
        sbc bx
        sta bw
_okr    lda by                  ; top
        cmp clip_top
        bcs _okt
        lda clip_top
        sec
        sbc by
        sta tmp
        lda bh
        sec
        sbc tmp
        bcc _ret
        beq _ret
        sta bh
        lda clip_top
        sta by
_okt    lda by                  ; bottom
        cmp #SCREEN_H
        bcs _ret
        clc
        adc bh
        bcs _clipb
        cmp #SCREEN_H+1
        bcc _okb
_clipb  lda #SCREEN_H
        sec
        sbc by
        sta bh
_okb    lda fb_measure
        bne fill_measure
        jmp fill_clipped
_ret    rts

;; fill_measure - the cells a clipped box would paint, added to ex_c0..ex_c1
;; and ex_r0..ex_r1, and nothing drawn: what exit_save asks of the open way
;; out before it draws it.
fill_measure
        lda bx
        lsr
        lsr
        cmp ex_c0
        bcs +
        sta ex_c0
+       lda bx
        clc
        adc bw
        sec
        sbc #1
        lsr
        lsr
        cmp ex_c1
        bcc +
        sta ex_c1
+       lda by
        lsr
        lsr
        lsr
        cmp ex_r0
        bcs +
        sta ex_r0
+       lda by
        clc
        adc bh
        sec
        sbc #1
        lsr
        lsr
        lsr
        cmp ex_r1
        bcc +
        sta ex_r1
+       rts

fill_clipped
        ldx bpen
        lda pen_colour,x
        sta bcol
        lda bx
        clc
        adc bw
        sec
        sbc #1
        sta bx1
        lsr
        lsr
        sta cc1
        lda by
        clc
        adc bh
        sec
        sbc #1
        sta by1
        lsr
        lsr
        lsr
        sta cr1
        lda bx
        lsr
        lsr
        sta cc0
        lda by
        lsr
        lsr
        lsr
        sta cr0
        sta cr

_row    ldx cr                  ; this cell row's three bases
        lda bmp_row_lo,x
        sta rowptr
        lda bmp_row_hi,x
        sta rowptr+1
        lda scr_row_lo,x
        sta sptr
        lda scr_row_hi,x
        sta sptr+1
        lda col_row_lo,x
        sta cptr
        lda col_row_hi,x
        sta cptr+1
        lda #0                  ; which of its eight lines the box covers
        cpx cr0
        bne +
        lda by
        and #7
+       sta ly0
        lda #7
        cpx cr1
        bne +
        lda by1
        and #7
+       sta ly1

        lda cc0
        sta cc
_col    ldx #0                  ; which of the cell's four pixels it covers
        lda cc
        cmp cc0
        bne +
        lda bx
        and #3
        tax
+       lda lmask,x
        sta mask
        ldx #3
        lda cc
        cmp cc1
        bne +
        lda bx1
        and #3
        tax
+       lda rmask,x
        and mask
        sta mask
        eor #$ff
        sta nmask

        ldx cc                  ; the cell's eight bytes
        lda rowptr
        clc
        adc cell8_lo,x
        sta ptr
        lda rowptr+1
        adc cell8_hi,x
        sta ptr+1

        jsr alloc
        tax
        lda slot_pat,x
        ldx mask
        cpx #$ff
        bne _part
        ldy ly0                 ; the whole width of the cell: just store
-       sta (ptr),y
        iny
        cpy ly1
        bcc -
        beq -
        jmp _next
_part   and mask
        sta pat
        ldy ly0
-       lda (ptr),y
        and nmask
        ora pat
        sta (ptr),y
        iny
        cpy ly1
        bcc -
        beq -
_next

        lda cc
        cmp cc1
        beq _rowdone
        inc cc
        jmp _col
_rowdone
        lda cr
        cmp cr1
        beq _done
        inc cr
        jmp _row
_done   rts

;; ---------------------------------------------------------------------------
;; alloc - the slot for bcol in cell cc of the current row. See the top of
;; the file for the rules; returns A = 0..3.
;; ---------------------------------------------------------------------------
alloc
        lda bpen
        bne +
        rts                     ; A = 0: the background
+       ldy cc
        lda (sptr),y
        lsr
        lsr
        lsr
        lsr
        cmp bcol
        bne +
        lda #1
        rts
+       lda (sptr),y
        and #$0f
        cmp bcol
        bne +
        lda #2
        rts
+       lda (cptr),y
        and #$0f
        cmp bcol
        bne +
        lda #3
        rts

+       lda #0                  ; which slots are still showing
        sta pres
        ldx mask                ; none, if this box covers the whole cell:
        inx                     ; that is most cells of a big box, and the
        bne _scan               ; answer the scan would give anyway
        ldx ly0
        bne _scan
        ldx ly1
        cpx #7
        beq _free
_scan   ldy #7
_line   lda (ptr),y
        cpy ly0
        bcc _keep
        cpy ly1
        beq _cover
        bcs _keep
_cover  and nmask               ; this box is about to paint over these
_keep   tax
        lda ptab,x
        ora pres
        sta pres
        dey
        bpl _line

_free   ldy cc
        lda pres
        and #2
        bne +
        lda (sptr),y            ; 01 is free
        and #$0f
        sta tmp
        lda bcol
        asl
        asl
        asl
        asl
        ora tmp
        sta (sptr),y
        lda #1
        rts
+       lda pres
        and #4
        bne +
        lda (sptr),y            ; 10 is free
        and #$f0
        ora bcol
        sta (sptr),y
        lda #2
        rts
+       lda pres
        and #8
        beq _take3
        lda soft                ; a pickup does not take a slot from the
        bne _nearest            ; furniture: it borrows the nearest colour
        inc clash_count         ; 11 was in use: those pixels change colour
        bne _take3
        inc clash_count+1
_take3  lda bcol
        sta (cptr),y
        lda #3
        rts

;; The slot - background included - whose colour looks most like bcol.
_nearest
        lda bcol
        asl
        asl
        asl
        asl
        sta tmp
        lda bg_col
        jsr _dist
        sta best_d
        lda #0
        sta best_s
        lda (sptr),y
        lsr
        lsr
        lsr
        lsr
        jsr _dist
        cmp best_d
        bcs +
        sta best_d
        lda #1
        sta best_s
+       lda (sptr),y
        and #$0f
        jsr _dist
        cmp best_d
        bcs +
        sta best_d
        lda #2
        sta best_s
+       lda (cptr),y
        and #$0f
        jsr _dist
        cmp best_d
        bcs +
        lda #3
        sta best_s
+       inc soft_count
        bne +
        inc soft_count+1
+       lda best_s
        rts
_dist   ora tmp
        tax
        lda colour_dist,x
        rts

;; ---------------------------------------------------------------------------
;; draw_pic - picp = a picture (width, height, pen nibbles), at pic_x, pic_y.
;; Each row is cut into runs of one pen and every run is a one-line box, so
;; a picture goes through exactly the same allocator as the furniture.
;; ---------------------------------------------------------------------------
draw_pic
        ldy #0
        lda (picp),y
        sta pic_w
        iny
        lda (picp),y
        sta pic_h
        lda picp
        clc
        adc #2
        sta picp
        bcc +
        inc picp+1
+
_row    lda #0
        sta run_x
        sta run_pen
        sta pic_i
_px     lda pic_i
        cmp pic_w
        beq _pen_end            ; past the end: flush with pen "none"
        lsr
        tay
        lda (picp),y
        bcs +                   ; odd pixel: the low nibble
        lsr
        lsr
        lsr
        lsr
+       and #$0f
        .byte $2c               ; BIT abs: skip the next two bytes
_pen_end
        lda #$ff
        cmp run_pen
        beq _same
        pha                     ; a new run starts here: draw the last one
        jsr pic_flush
        pla
        sta run_pen
        lda pic_i
        sta run_x
_same   lda pic_i
        cmp pic_w
        beq _rowdone
        inc pic_i
        jmp _px
_rowdone
        lda pic_w               ; next row of nibbles
        lsr
        clc
        adc picp
        sta picp
        bcc +
        inc picp+1
+       inc pic_y
        dec pic_h
        bne _row
        rts

pic_flush
        lda run_pen
        beq _none               ; transparent, or the start of the row
        cmp #$ff
        beq _none
        sta bpen
        lda pic_x
        clc
        adc run_x
        sta bx
        lda pic_i
        sec
        sbc run_x
        sta bw
        lda pic_y
        sta by
        lda #1
        sta bh
        jmp fill_box
_none   rts

;; ---------------------------------------------------------------------------
;; save_cells / restore_cells - sv_cc, sv_cr = the top-left cell, sv_nc x
;; sv_nr cells, to or from (bufp): 8 bitmap bytes, the screen byte and the
;; colour byte, ten a cell. What a pickup keeps of what is behind it.
;; ---------------------------------------------------------------------------
save_cells
        lda #0
        beq cells_go
restore_cells
        lda #1
cells_go
        sta sv_dir
        lda sv_cr
        sta sv_r
        lda sv_nr
        sta sv_rn
_row    ldx sv_r
        lda bmp_row_lo,x
        sta rowptr
        lda bmp_row_hi,x
        sta rowptr+1
        lda scr_row_lo,x
        sta sptr
        lda scr_row_hi,x
        sta sptr+1
        lda col_row_lo,x
        sta cptr
        lda col_row_hi,x
        sta cptr+1
        lda sv_cc
        sta sv_c
        lda sv_nc
        sta sv_cn
_cell   ldx sv_c
        lda rowptr
        clc
        adc cell8_lo,x
        sta ptr
        lda rowptr+1
        adc cell8_hi,x
        sta ptr+1
        ldy #7
        lda sv_dir
        bne _restore
-       lda (ptr),y
        sta (bufp),y
        dey
        bpl -
        ldy sv_c
        lda (sptr),y
        ldy #8
        sta (bufp),y
        ldy sv_c
        lda (cptr),y
        ldy #9
        sta (bufp),y
        jmp _next
_restore
-       lda (bufp),y
        sta (ptr),y
        dey
        bpl -
        ldy #8
        lda (bufp),y
        ldy sv_c
        sta (sptr),y
        ldy #9
        lda (bufp),y
        ldy sv_c
        sta (cptr),y
_next   lda bufp
        clc
        adc #10
        sta bufp
        bcc +
        inc bufp+1
+       inc sv_c
        dec sv_cn
        bne _cell
        inc sv_r
        dec sv_rn
        bne _row
        rts
