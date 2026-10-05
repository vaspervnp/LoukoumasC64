;; ===========================================================================
;; text.s - messages, in two places (loukc64.md 7).
;;
;; Small text is hires character mode: the HUD along the top and the footer
;; along the bottom of the title, forty columns of the 8x8 font, written as
;; screen codes into TEXT_SCREEN. Nothing has to be cleared under it and a
;; digit is changed by writing one byte.
;;
;; Big text - the name on the title, GAME OVER, WELL DONE - is drawn into the
;; multicolour bitmap, a font pixel to txt_sx x txt_sy of the picture, through
;; fill_box and so through the colour allocator like everything else there.
;;
;; No literal text anywhere: every message is an id, looked up in the
;; language the player chose.
;; ===========================================================================

;; ---------------------------------------------------------------------------
;; msg_ptr - A = message id -> msgp = its length byte, in the current
;; language. Y = 0 on return.
;; ---------------------------------------------------------------------------
msg_ptr
        tay
        ldx lang
        lda lang_lo,x
        sta msgp
        lda lang_hi,x
        sta msgp+1
        lda (msgp),y            ; the low table, then MSG_COUNT on the high
        tax
        tya
        clc
        adc #MSG_COUNT
        tay
        lda (msgp),y
        sta msgp+1
        stx msgp
        ldy #0
        rts

;; ---------------------------------------------------------------------------
;; print_msg - A = message, X = column, Y = text row.
;; print_msg_centre - A = message, Y = text row: centred in 40 columns.
;; Both leave txt_col just past the message.
;; ---------------------------------------------------------------------------
print_msg_centre
        sty txt_row
        jsr msg_ptr
        lda #40
        sec
        sbc (msgp),y
        lsr
        sta txt_col
        jmp print_go
print_msg
        stx txt_col
        sty txt_row
        jsr msg_ptr
print_go
        ldx txt_row
        lda txt_row_lo,x
        clc
        adc txt_col
        sta txtp
        lda txt_row_hi,x
        adc #0
        sta txtp+1
        lda (msgp),y
        tax                     ; length
        beq _done
-       iny
        lda (msgp),y
        dey
        sta (txtp),y
        iny
        dex
        bne -
_done   tya
        clc
        adc txt_col
        sta txt_col
        rts

;; ---------------------------------------------------------------------------
;; print_code - A = screen code at txt_col, txt_row; advances txt_col.
;; print_digit - A = 0-9. print_bcd - A = a BCD byte, two digits.
;; ---------------------------------------------------------------------------
print_digit
        clc
        adc #GL_0
print_code
        pha
        ldx txt_row
        lda txt_row_lo,x
        sta txtp
        lda txt_row_hi,x
        sta txtp+1
        ldy txt_col
        pla
        sta (txtp),y
        inc txt_col
        rts

print_bcd
        pha
        lsr
        lsr
        lsr
        lsr
        jsr print_digit
        pla
        and #$0f
        jmp print_digit

;; ---------------------------------------------------------------------------
;; clear_text_row - Y = text row, to spaces.
;; ---------------------------------------------------------------------------
clear_text_row
        lda txt_row_lo,y
        sta txtp
        lda txt_row_hi,y
        sta txtp+1
        lda #GL_SPACE
        ldy #39
-       sta (txtp),y
        dey
        bpl -
        rts

;; ---------------------------------------------------------------------------
;; big_text_centre - A = message, drawn into the bitmap at line txt_y,
;; centred, txt_sx x txt_sy a font pixel, in pen txt_pen.
;; big_text - the same at txt_x.
;; ---------------------------------------------------------------------------
big_text_centre
        pha
        jsr msg_ptr
        lda (msgp),y            ; width = length * 6 * sx
        sta tmp
        lda #0
        ldx txt_sx
-       clc
        adc tmp
        dex
        bne -
        sta tmp                 ; length * sx
        asl                     ; * 6 = * 2 + * 4
        clc
        adc tmp
        asl
        sta tmp
        lda #SCREEN_W
        sec
        sbc tmp
        lsr
        sta txt_x
        pla
big_text
        jsr msg_ptr
        lda (msgp),y
        sta txt_n
        beq _done
        lda txt_x
        sta txt_cx
_char   inc msgp                ; the next screen code
        bne +
        inc msgp+1
+       ldy #0
        lda (msgp),y
        sta fontp               ; font + code * 8
        lda #0
        sta fontp+1
        asl fontp
        rol fontp+1
        asl fontp
        rol fontp+1
        asl fontp
        rol fontp+1
        lda fontp
        clc
        adc #<font
        sta fontp
        lda fontp+1
        adc #>font
        sta fontp+1
        jsr big_glyph
        lda txt_sx              ; advance six font pixels
        asl
        clc
        adc txt_sx
        asl
        clc
        adc txt_cx
        sta txt_cx
        dec txt_n
        bne _char
_done   rts

;; One glyph at txt_cx, txt_y: seven rows of five pixels, bits 6-2. Each run
;; of set pixels in a row is one box, which is a fifth of the boxes a pixel at
;; a time would be.
big_glyph
        lda txt_y
        sta txt_cy
        lda #0
        sta txt_gr
_row    ldy txt_gr
        lda (fontp),y
        asl                     ; bits 7-3 are the five pixels, left first,
        sta txt_bits            ; and a clear bit follows them to close a run
        ldx #0
        lda #$ff
        sta txt_rs              ; no run open
_px     cpx #6
        beq _rowdone
        asl txt_bits
        bcc _clear
        lda txt_rs
        bpl _next
        stx txt_rs              ; a run starts here
        jmp _next
_clear  lda txt_rs
        bmi _next
        stx txt_gc              ; a run ended: txt_rs up to x-1
        jsr glyph_box
        lda #$ff
        sta txt_rs
        ldx txt_gc
_next   inx
        jmp _px
_rowdone
        lda txt_cy
        clc
        adc txt_sy
        sta txt_cy
        inc txt_gr
        lda txt_gr
        cmp #7
        bne _row
        rts

;; The run txt_rs .. txt_gc-1 of row txt_gr, scaled.
glyph_box
        lda #0
        ldx txt_rs
        beq +
-       clc
        adc txt_sx
        dex
        bne -
+       clc
        adc txt_cx
        sta bx
        lda txt_gc
        sec
        sbc txt_rs
        tax
        lda #0
-       clc
        adc txt_sx
        dex
        bne -
        sta bw
        lda txt_cy
        sta by
        lda txt_sy
        sta bh
        lda txt_pen
        sta bpen
        jmp fill_box
