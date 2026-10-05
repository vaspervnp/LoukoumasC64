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
