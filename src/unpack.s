;; ===========================================================================
;; unpack.s - the decruncher for tools/pack64.py's format.
;;
;; lz_src = the stream, lz_dst = where it goes. Destroys A, X, Y, lz_m.
;; The stream (see the tool for the full description):
;;   0              the end
;;   1..127         that many literal bytes
;;   128..191       a match of (t & 63) + 2, one byte of distance - 1
;;   192..255       a match of (t & 63) + 3, two bytes of distance - 1
;; A match is copied forward out of the output, a byte at a time, so a short
;; distance repeats a pattern. Output may run up to the stream's own start
;; and no further: the loader puts a packed file so it ends where it does.
;; ===========================================================================

unpack
_token  ldy #0
        lda (lz_src),y
        jsr _next
        tax
        beq _done
        bmi _match
-       lda (lz_src),y          ; X literal bytes
        sta (lz_dst),y
        iny
        dex
        bne -
        tya
        clc
        adc lz_src
        sta lz_src
        bcc +
        inc lz_src+1
+       jmp _advance

_match  cmp #192
        bcs _far
        and #63                 ; near: length + 2, a byte of distance
        adc #2                  ; (carry is clear: A < 192)
        tax
        lda (lz_src),y
        jsr _next
        eor #$ff                ; m = dst - (d + 1) = dst + ~d, high byte $ff
        clc
        adc lz_dst
        sta lz_m
        lda lz_dst+1
        adc #$ff
        sta lz_m+1
        jmp _copy
_far    and #63                 ; far: length + 3, two bytes of distance
        clc
        adc #3
        tax
        lda (lz_src),y
        eor #$ff
        clc
        adc lz_dst
        sta lz_m
        iny
        lda (lz_src),y
        eor #$ff
        adc lz_dst+1
        sta lz_m+1
        jsr _next
        jsr _next
        ldy #0
_copy   lda (lz_m),y
        sta (lz_dst),y
        iny
        dex
        bne _copy
_advance
        tya
        clc
        adc lz_dst
        sta lz_dst
        bcc _token
        inc lz_dst+1
        jmp _token
_done   rts

_next   inc lz_src
        bne +
        inc lz_src+1
+       rts
