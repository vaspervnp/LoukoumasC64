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
;; The title music (loukc64.md 8): the CPC's Arkos song, notes converted by
;; tools/mkmusic64.py, on voices 1 and 2. Voice 3 stays the effects'.
;;
;; The CPC's one instrument starts at volume 15 and loses one a tick, so a
;; note is a short plucked blip whatever its length. The SID's nearest is no
;; attack, a 300 ms decay to nothing, and the gate let go two ticks in so the
;; release carries the note the rest of the way down - and so the next note
;; on the voice starts a new attack.
;;
;; It plays on the title and the chooser, as on the CPC, and stops when the
;; game starts: play_screen's sfx_init silences the whole chip after it.
;; ===========================================================================

MUSIC_WAVE      = WAVE_PULSE
MUSIC_AD        = $08           ; attack 2 ms, decay 300 ms
MUSIC_SR        = $08           ; sustain 0, release 300 ms
MUSIC_GATE      = 2             ; ticks the gate is held
MUSIC_VOICES    = 2

        .include "music.s"

music_start_lo  .byte <music_v1, <music_v2
music_start_hi  .byte >music_v1, >music_v2
voice_reg       .byte 0, 7              ; each voice's registers, from $D400

;; ---------------------------------------------------------------------------
;; music_start - from the top. music_stop - silence, and leave the chip be.
;; ---------------------------------------------------------------------------
music_start
        php
        sei
        ldx #MUSIC_VOICES-1
-       lda music_start_lo,x
        sta mus_p_lo,x
        lda music_start_hi,x
        sta mus_p_hi,x
        lda #0
        sta mus_lines,x
        sta mus_gate,x
        ldy voice_reg,x
        sta SID+4,y             ; gate off
        lda #$08
        sta SID+3,y             ; a square wave, like the PSG's
        lda #0
        sta SID+2,y
        lda #MUSIC_AD
        sta SID+5,y
        lda #MUSIC_SR
        sta SID+6,y
        dex
        bpl -
        lda #15
        sta SID_VOL
        lda #1
        sta mus_tick            ; the first call starts a line
        sta mus_on
        plp
        rts

music_stop
        lda #0
        sta mus_on
        sta SID+4               ; both gates off
        sta SID+7+4
        rts

;; ---------------------------------------------------------------------------
;; music_play - one tick. Called from the frame interrupt.
;; ---------------------------------------------------------------------------
music_play
        lda mus_on
        beq _done
        ldx #MUSIC_VOICES-1     ; the gates first: two ticks into a note
_gate   lda mus_gate,x
        beq +
        dec mus_gate,x
        bne +
        ldy voice_reg,x
        lda #MUSIC_WAVE
        sta SID+4,y
+       dex
        bpl _gate

        dec mus_tick            ; and a new line every MUSIC_SPEED ticks
        bne _done
        lda #MUSIC_SPEED
        sta mus_tick
        ldx #MUSIC_VOICES-1
_voice  lda mus_lines,x
        bne _held
        jsr music_event
_held   dec mus_lines,x
        dex
        bpl _voice
_done   rts

;; music_event - voice X's next (note, lines). $ff goes back to the start.
music_event
        lda mus_p_lo,x
        sta mus_ptr
        lda mus_p_hi,x
        sta mus_ptr+1
        ldy #0
        lda (mus_ptr),y
        cmp #$ff
        bne +
        lda music_start_lo,x
        sta mus_ptr
        lda music_start_hi,x
        sta mus_ptr+1
        lda (mus_ptr),y
+       pha
        iny
        lda (mus_ptr),y
        sta mus_lines,x
        lda mus_ptr             ; two bytes on
        clc
        adc #2
        sta mus_p_lo,x
        lda mus_ptr+1
        adc #0
        sta mus_p_hi,x
        pla
        beq _rest
        tay                     ; the note: its frequency, and the gate on
        lda music_notes_lo,y
        pha
        lda music_notes_hi,y
        ldy voice_reg,x
        sta SID+1,y
        pla
        sta SID,y
        lda #MUSIC_WAVE|1
        sta SID+4,y
        lda #MUSIC_GATE
        sta mus_gate,x
_rest   rts
