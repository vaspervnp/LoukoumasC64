;; ===========================================================================
;; sound.s - the four effects, on voice 3 of the SID (loukc64.md 8).
;;
;; The CPC's effects are a starting tone period, a signed step added to it
;; every 50 Hz frame, and a length; the volume is whatever is left of the
;; length, capped at 15, so everything fades as it runs out. That carries
;; over as it is, with two translations:
;;
;;  * A PSG period is the inverse of a frequency, and the SID wants the
;;    frequency. Rather than divide at run time, the assembler works out each
;;    frame's SID frequency from the CPC's period - 62500 / period Hz, times
;;    16777216 / 985248 for a PAL SID - and the effect is a table of them.
;;  * The SID has no volume per voice. There is no music yet, so the master
;;    volume in $D418 does the fade, exactly as the PSG's channel volume did.
;;    When the music arrives the fade moves to the envelope.
;;
;; sfx_update runs from the frame interrupt, not from the game logic, so an
;; effect cannot be forgotten half way when the game ends - which is what
;; held the CPC's death note for ever (its CLAUDE.md 10b).
;; ===========================================================================

SFX_JUMP        = 0
SFX_EAT         = 1
SFX_DIE         = 2
SFX_FLOP        = 3

SID             = $d400
V3_FREQ         = SID+14
V3_PW           = SID+16
V3_CTRL         = SID+18
V3_AD           = SID+19
V3_SR           = SID+20
SID_VOL         = SID+24

WAVE_PULSE      = $40
WAVE_NOISE      = $80

;; PAL: 985248 Hz into a 24-bit accumulator. A PSG period p is 62500/p Hz.
SID_PER_HZ      = 16777216.0/985248.0

;; sfx_freqs period, step, length: the SID frequency of each frame after the
;; first, which is the frame the CPC's sfx_update writes - one entry fewer
;; than the length, because the last frame is the one that shuts it up.
sfx_freqs .macro p0, step, len
        .for k = 1, k < \len, k += 1
        .word round(62500.0/(\p0 + \step*k)*SID_PER_HZ)
        .next
        .endm

sfx_jump_f      #sfx_freqs 400, -26, 8
sfx_eat_f       #sfx_freqs 190, -14, 5
sfx_die_f       #sfx_freqs 300, 44, 25
sfx_flop_f                              ; noise: one pitch, a thud
        .for k = 1, k < 10, k += 1
        .word $0a00
        .next

sfx_lo          .byte <sfx_jump_f, <sfx_eat_f, <sfx_die_f, <sfx_flop_f
sfx_hi          .byte >sfx_jump_f, >sfx_eat_f, >sfx_die_f, >sfx_flop_f
sfx_len_tab     .byte 8, 5, 25, 10
sfx_wave        .byte WAVE_PULSE, WAVE_PULSE, WAVE_PULSE, WAVE_NOISE

;; ---------------------------------------------------------------------------
;; sfx_init - every register silent, voice 3 ready to be gated.
;; ---------------------------------------------------------------------------
sfx_init
        lda #0
        sta sfx_len
        ldx #24
-       sta SID,x
        dex
        bpl -
        lda #$00
        sta V3_AD               ; no attack, no decay: full at once
        lda #$f0
        sta V3_SR               ; sustain full, the fade is the master volume
        lda #$08
        sta V3_PW+1             ; a square wave, like the PSG's
        rts

;; ---------------------------------------------------------------------------
;; sfx_play - A = effect. Interrupts off while the five bytes are written, so
;; the frame entry never steps half of an old effect and half of a new one.
;; ---------------------------------------------------------------------------
sfx_play
        tax
        php
        sei
        lda sfx_lo,x
        sta sfx_ptr
        lda sfx_hi,x
        sta sfx_ptr+1
        lda #0
        sta sfx_idx
        lda sfx_wave,x
        sta sfx_cur_wave
        sta V3_CTRL             ; gate off for a moment: retrigger
        lda sfx_len_tab,x
        sta sfx_len
        plp
        rts

;; ---------------------------------------------------------------------------
;; sfx_update - one 50 Hz step. Called from the frame interrupt.
;; ---------------------------------------------------------------------------
sfx_update
        lda sfx_len
        beq _done
        dec sfx_len
        bne _on
        lda sfx_cur_wave        ; the last frame: gate off, volume down
        sta V3_CTRL
        lda #0
        sta SID_VOL
_done
        rts
_on
        ldy sfx_idx
        lda (sfx_ptr),y
        sta V3_FREQ
        iny
        lda (sfx_ptr),y
        sta V3_FREQ+1
        iny
        sty sfx_idx
        lda sfx_cur_wave
        ora #1                  ; gate on
        sta V3_CTRL
        lda sfx_len             ; the volume is what is left of the length
        cmp #16
        bcc +
        lda #15
+       sta SID_VOL
        rts

;; ===========================================================================
;; The title music (loukc64.md 8): written for the SID in assets/music/title.txt
;; and compiled by tools/mkmusic64.py into the streams and instruments of
;; music.s, which tells the byte code. All three voices: it plays on the title
;; and the chooser, where there are no effects, and play_screen's sfx_init
;; silences the whole chip after music_stop when the game starts.
;;
;; Every tick (the frame interrupt, 50 Hz) each voice either takes its next
;; event or carries on with its note: the gate let go when it is time, the
;; chord's next note, a glide or a drop moved on, the pulse width swept, the
;; vibrato, and the frequency and pulse width written.
;; ===========================================================================

        .include "music.s"

voice_reg       .byte 0, 7, 14          ; each voice's registers, from $D400

;; ---------------------------------------------------------------------------
;; music_start - from the top. music_stop - silence, and leave the chip be.
;; ---------------------------------------------------------------------------
music_start
        php
        sei
        ldx #2
-       lda music_lo,x
        sta mus_p_lo,x
        lda music_hi,x
        sta mus_p_hi,x
        lda #1
        sta mus_cnt,x           ; the first tick reads an event
        lda #0
        sta mus_note,x
        sta mus_gate,x
        sta mus_inst,x
        ldy voice_reg,x
        sta SID+4,y             ; gate off
        dex
        bpl -
        lda #15
        sta SID_VOL
        lda #1
        sta mus_on
        plp
        rts

music_stop
        lda #0
        sta mus_on
        sta SID+4               ; every gate off
        sta SID+7+4
        sta SID+14+4
        rts

;; ---------------------------------------------------------------------------
;; music_play - one tick. Called from the frame interrupt.
;; ---------------------------------------------------------------------------
music_play
        lda mus_on
        beq _done
        ldx #2
_voice  stx mus_v
        lda voice_reg,x
        sta mus_r
        dec mus_cnt,x
        bne +
        jsr music_event
        jmp _next
+       jsr music_tick
_next   ldx mus_v
        dex
        bpl _voice
_done   rts

;; music_event - voice X's next note or rest, and any instrument before it.
music_event
        lda mus_p_lo,x
        sta mus_ptr
        lda mus_p_hi,x
        sta mus_ptr+1
        ldy #0
_read   lda (mus_ptr),y
        iny
        cmp #$ff
        bne +
        lda music_loop_lo,x     ; the end: round again from the loop point
        sta mus_ptr
        lda music_loop_hi,x
        sta mus_ptr+1
        ldy #0
        beq _read
+       cmp #$c0
        beq _glide
        cmp #$80
        bcc _note
        and #$3f                ; an instrument
        sta mus_inst,x
        jmp _read
_glide  lda #0                  ; from a note, moving by a delta each tick
        sta mus_age,x
        lda (mus_ptr),y
        iny
        sta mus_note,x
        lda (mus_ptr),y
        iny
        sta mus_cnt,x
        sta mus_sl_t,x
        lda (mus_ptr),y
        iny
        sta mus_sl_lo,x
        lda (mus_ptr),y
        iny
        sta mus_sl_hi,x
        jmp _start
_note   sta mus_note,x
        lda (mus_ptr),y
        iny
        sta mus_cnt,x
        lda #0
        sta mus_sl_t,x
_start  tya                     ; past the event
        clc
        adc mus_ptr
        sta mus_p_lo,x
        lda mus_ptr+1
        adc #0
        sta mus_p_hi,x
        lda mus_note,x
        bne music_note_on
        ldy mus_inst,x          ; a rest: the gate let go
        lda in_wave,y
        ldy mus_r
        sta SID+4,y
        rts

;; music_note_on - voice X's note from the start: the instrument's envelope,
;; pulse width and gate, and the gate on.
music_note_on
        ldy mus_inst,x
        lda in_gate,y           ; how long the gate is held: the
        bne +                   ; instrument's, or to a tick before the end
        lda mus_cnt,x
        sec
        sbc #1
+       sta mus_gate,x
        lda #0
        sta mus_age,x
        sta mus_arp,x
        sta mus_vb_lo,x
        sta mus_vb_hi,x
        lda in_vstep,y
        sta mus_vb_st,x
        lda in_vspeed,y
        lsr                     ; half a swing first, so it centres
        sta mus_vb_c,x
        lda in_pw_lo,y
        sta mus_pw_lo,x
        lda in_pw_hi,y
        sta mus_pw_hi,x
        lda in_sweep,y
        sta mus_sweep,x
        jsr music_pitch
        ldy mus_inst,x
        lda in_ad,y
        pha
        lda in_sr,y
        pha
        lda in_wave,y
        ldy mus_r
        sta SID+4,y             ; gate off a moment: a new attack
        pla
        sta SID+6,y
        pla
        sta SID+5,y
        jsr music_out
        ldy mus_inst,x
        lda in_wave,y
        ora #1
        ldy mus_r
        sta SID+4,y
        rts

;; music_pitch - mus_f from the note, and the chord's step if it has one.
music_pitch
        lda mus_note,x
        sec
        sbc #1
        sta mus_ptr             ; the note, C0 = 0 (mus_ptr is free by now)
        ldy mus_inst,x
        lda in_arp,y
        beq _plain
        clc
        adc mus_arp,x
        tay
        lda music_arps-1,y
        cmp #$ff
        bne +
        lda #0                  ; round the chord again
        sta mus_arp,x
        ldy mus_inst,x
        lda in_arp,y
        tay
        lda music_arps-1,y
+       clc
        adc mus_ptr
        sta mus_ptr
_plain  ldy mus_ptr
        lda music_freq_lo,y
        sta mus_f_lo,x
        lda music_freq_hi,y
        sta mus_f_hi,x
        rts

;; music_tick - a tick of voice X's note.
music_tick
        lda mus_note,x
        bne +
        rts                     ; resting
+       lda mus_gate,x
        beq +
        dec mus_gate,x
        bne +
        ldy mus_inst,x          ; time to let go
        lda in_wave,y
        ldy mus_r
        sta SID+4,y
+       lda mus_age,x
        cmp #255
        beq +
        inc mus_age,x
+       lda mus_sl_t,x          ; a glide
        beq _arp
        dec mus_sl_t,x
        lda mus_f_lo,x
        clc
        adc mus_sl_lo,x
        sta mus_f_lo,x
        lda mus_f_hi,x
        adc mus_sl_hi,x
        sta mus_f_hi,x
        jmp _drop
_arp    ldy mus_inst,x          ; a chord's next note
        lda in_arp,y
        beq _drop
        inc mus_arp,x
        jsr music_pitch
_drop   ldy mus_inst,x          ; a bonk, a snap
        lda in_drop_lo,y
        ora in_drop_hi,y
        beq _sweep
        lda mus_f_lo,x
        clc
        adc in_drop_lo,y
        sta mus_f_lo,x
        lda mus_f_hi,x
        adc in_drop_hi,y
        sta mus_f_hi,x
        lda in_drop_hi,y        ; (lda leaves the carry be)
        bmi _neg
        bcc _sweep              ; up, and not past the top
        lda #$ff                ; past it: stay there
        bne _clamp
_neg    bcs _sweep              ; down, and not through zero
        lda #0                  ; through it: stay at the bottom
_clamp  sta mus_f_lo,x
        sta mus_f_hi,x
_sweep  lda mus_sweep,x         ; the pulse width, turning at the ends
        beq _vib
        bmi _down
        clc
        adc mus_pw_lo,x
        sta mus_pw_lo,x
        bcc _vib
        inc mus_pw_hi,x
        lda mus_pw_hi,x
        cmp #$0e
        bcc _vib
        jmp _turn
_down   clc
        adc mus_pw_lo,x
        sta mus_pw_lo,x
        bcs _vib
        dec mus_pw_hi,x
        lda mus_pw_hi,x
        cmp #$02
        bcs _vib
_turn   lda mus_sweep,x
        eor #$ff
        clc
        adc #1
        sta mus_sweep,x
_vib    lda in_vstep,y          ; the vibrato, once the note has settled
        beq _out
        lda mus_age,x
        cmp in_vdelay,y
        bcc _out
        lda mus_vb_st,x         ; step, sign-extended
        bpl +
        dec mus_vb_hi,x
+       clc
        adc mus_vb_lo,x
        sta mus_vb_lo,x
        bcc +
        inc mus_vb_hi,x
+       dec mus_vb_c,x
        bne _out
        lda in_vspeed,y         ; turn round
        sta mus_vb_c,x
        lda mus_vb_st,x
        eor #$ff
        clc
        adc #1
        sta mus_vb_st,x
_out    ;; fall through

;; music_out - the frequency, with the vibrato, and the pulse width.
music_out
        ldy mus_r
        lda mus_f_lo,x
        clc
        adc mus_vb_lo,x
        sta SID,y
        lda mus_f_hi,x
        adc mus_vb_hi,x
        sta SID+1,y
        lda mus_pw_lo,x
        sta SID+2,y
        lda mus_pw_hi,x
        sta SID+3,y
        rts
