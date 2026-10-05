;; ===========================================================================
;; keys.s - joystick in port 2 and the keyboard, folded into one set of
;; control bits (loukc64.md 6.5).
;;
;; ctl_now is the level - what is held this frame - and ctl_pressed the edge,
;; what went down since the last read. Jumps, the belly-flop and every menu
;; want the edge; walking and rolling want the level.
;;
;; The cursor keys on a C64 are two keys and a SHIFT each, which is no way to
;; play a platformer, so the keyboard is O/P/Q/A and SPACE like a hundred
;; other games. Port 1 shares its lines with the keyboard and invents key
;; presses, so the joystick is read from port 2 only.
;; ===========================================================================

CTL_UP          = %00000001         ; the low five are the joystick's own bits,
CTL_DOWN        = %00000010         ; so the stick needs no translating
CTL_LEFT        = %00000100
CTL_RIGHT       = %00001000
CTL_FIRE        = %00010000
CTL_QUIT        = %00100000         ; RUN/STOP
CTL_LANG        = %01000000         ; L

;; The keyboard matrix: a column is selected by pulling its $DC00 bit low,
;; and the keys in it read back as low bits of $DC01.
;;               column    row
KEY_O           = $1000 | $40       ; PA4, PB6
KEY_P           = $2000 | $02       ; PA5, PB1
KEY_Q           = $8000 | $40       ; PA7, PB6
KEY_A           = $0200 | $04       ; PA1, PB2
KEY_SPACE       = $8000 | $10       ; PA7, PB4
KEY_L           = $2000 | $04       ; PA5, PB2
KEY_STOP        = $8000 | $80       ; PA7, PB7

;; ---------------------------------------------------------------------------
;; read_controls - ctl_now and ctl_pressed for this frame.
;; ---------------------------------------------------------------------------
read_controls
        .if SCRIPT != 0
        jmp script_controls
        .endif
read_controls_live
        lda #$ff                ; no column selected: port A reads the stick
        sta $dc00
        lda $dc00
        eor #$ff                ; active low
        and #%00011111
        sta ctl_scan            ; the control bits are the stick's own
        ;; The keyboard. Each entry is a column select, a row bit and the
        ;; control bit it means.
        ldx #0
-       lda key_col,x
        beq _keys_done
        sta $dc00
        lda $dc01
        and key_row,x
        bne +                   ; high: not pressed
        lda key_ctl,x
        ora ctl_scan
        sta ctl_scan
+       inx
        bne -
_keys_done
        lda #$ff
        sta $dc00

        lda ctl_scan
controls_store
        tax
        eor ctl_now             ; what changed
        and ctl_scan            ; and is down now
        sta ctl_pressed
        stx ctl_now
        rts

key_col .byte (~KEY_O >> 8) & $ff, (~KEY_P >> 8) & $ff, (~KEY_Q >> 8) & $ff
        .byte (~KEY_A >> 8) & $ff, (~KEY_SPACE >> 8) & $ff, (~KEY_L >> 8) & $ff
        .byte (~KEY_STOP >> 8) & $ff, 0
key_row .byte KEY_O & $ff, KEY_P & $ff, KEY_Q & $ff, KEY_A & $ff
        .byte KEY_SPACE & $ff, KEY_L & $ff, KEY_STOP & $ff
key_ctl .byte CTL_LEFT, CTL_RIGHT, CTL_UP, CTL_DOWN, CTL_FIRE, CTL_LANG, CTL_QUIT
