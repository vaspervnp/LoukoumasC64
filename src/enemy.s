;; ===========================================================================
;; enemy.s - the three things in every room that are not the cat.
;;
;; The CPC's enemy.asm, without everything it needed because it had no
;; hardware sprites: no saved backgrounds, no erase, no draw order, no
;; enemy_tangled. What is left is the game - patrol a platform or fly an arc,
;; get flattened by a belly-flop, end a life on contact.
;;
;; Records are struct-of-arrays indexed by X, the enemy's number: en_x,x is
;; one instruction where the Z80 needed IY plus an offset (loukc64.md 6.2).
;; ===========================================================================

ENEMY_COUNT     = 3
ANIM_STEPS      = 4             ; an enemy changes picture every 4 steps
E_FROM_ROOM     = 7             ; type, x, y, dx, x0, x1, base: per room

EB_WALK         = 0             ; patrols a platform
EB_FLY          = 1             ; bounces across the room on a sine

ET_ROBOT        = 1
ET_CANARY       = 2
ET_DOG          = 3
ET_PIGEON       = 4
ET_WASP         = 5
ET_BALL         = 6
ET_PLANE        = 7
ET_MOP          = 8
ET_BLOB         = 9
ET_SYRINGE      = 10
ET_BAT          = 11
ET_STRAY        = 12
ET_COUNT        = 12

SINE_LEN        = 32
SINE_MASK       = SINE_LEN-1

;; What each type is: the frame facing right, the frame facing left, the
;; behaviour, and the size of the box that hurts. Indexed by type-1.
ek_right_lo     .byte <frm_robot, <frm_canary, <frm_dog, <frm_pigeon, <frm_wasp, <frm_ball
                .byte <frm_plane, <frm_mop, <frm_blob, <frm_syringe, <frm_bat, <frm_stray
ek_right_hi     .byte >frm_robot, >frm_canary, >frm_dog, >frm_pigeon, >frm_wasp, >frm_ball
                .byte >frm_plane, >frm_mop, >frm_blob, >frm_syringe, >frm_bat, >frm_stray
ek_left_lo      .byte <frm_robot_l, <frm_canary_l, <frm_dog_l, <frm_pigeon_l, <frm_wasp_l, <frm_ball_l
                .byte <frm_plane_l, <frm_mop_l, <frm_blob_l, <frm_syringe_l, <frm_bat_l, <frm_stray_l
ek_left_hi      .byte >frm_robot_l, >frm_canary_l, >frm_dog_l, >frm_pigeon_l, >frm_wasp_l, >frm_ball_l
                .byte >frm_plane_l, >frm_mop_l, >frm_blob_l, >frm_syringe_l, >frm_bat_l, >frm_stray_l
ek_behaviour    .byte EB_WALK, EB_FLY, EB_WALK, EB_FLY, EB_FLY, EB_WALK
                .byte EB_FLY, EB_WALK, EB_WALK, EB_FLY, EB_FLY, EB_WALK
ek_w            .byte SPR_ROBOT_W, SPR_CANARY_W, SPR_DOG_W, SPR_PIGEON_W, SPR_WASP_W, SPR_BALL_W
                .byte SPR_PLANE_W, SPR_MOP_W, SPR_BLOB_W, SPR_SYRINGE_W, SPR_BAT_W, SPR_STRAY_W
ek_h            .byte SPR_ROBOT_H, SPR_CANARY_H, SPR_DOG_H, SPR_PIGEON_H, SPR_WASP_H, SPR_BALL_H
                .byte SPR_PLANE_H, SPR_MOP_H, SPR_BLOB_H, SPR_SYRINGE_H, SPR_BAT_H, SPR_STRAY_H

;; A flyer's arc: the CPC's 32-step sine, 0..32 scanlines, times 3/4.
sine_tab
        .for k = 0, k < SINE_LEN, k += 1
        .byte round(12.0 + 12.0*sin(2.0*3.14159265*k/SINE_LEN))
        .next

;; ---------------------------------------------------------------------------
;; enemies_init - enemp = the room's enemy table, A = how many (0-3).
;; ---------------------------------------------------------------------------
enemies_init
        sta tmp
        ldx #0
        ldy #0
_one    cpx tmp
        bcs _empty
        lda (enemp),y
        sta en_type,x
        iny
        lda (enemp),y
        sta en_x,x
        iny
        lda (enemp),y
        sta en_y,x
        iny
        lda (enemp),y
        sta en_dx,x
        iny
        lda (enemp),y
        sta en_x0,x
        iny
        lda (enemp),y
        sta en_x1,x
        iny
        lda (enemp),y
        sta en_base,x
        iny
        lda #0
        sta en_phase,x
        sta en_stun,x
        sta en_tick,x
        txa                     ; out of step with each other
        asl
        sta en_anim,x
        jmp _next
_empty  lda #0
        sta en_type,x
_next   inx
        cpx #ENEMY_COUNT
        bne _one
        rts

;; ---------------------------------------------------------------------------
;; enemies_update - one 50 Hz step for all three.
;; ---------------------------------------------------------------------------
enemies_update
        ldx #ENEMY_COUNT-1
-       lda en_type,x
        beq +
        jsr enemy_update_one
+       dex
        bpl -
        rts

enemy_update_one
        lda en_stun,x
        beq +
        dec en_stun,x           ; still seeing stars
        rts
+       ldy en_type,x
        lda ek_behaviour-1,y
        beq enemy_walk

enemy_fly
        ;; en_phase is where it is in its arc, so a flyer counts its own
        ;; frames in en_tick to be slowed down by the difficulty.
        inc en_tick,x
        lda en_tick,x
        cmp fly_period
        bcs +
        rts
+       lda #0
        sta en_tick,x
        jsr enemy_bounce
        lda en_phase,x
        clc
        adc #1
        and #SINE_MASK
        sta en_phase,x
        tay
        lda en_base,x
        clc
        adc sine_tab,y
        sta en_y,x
        rts

enemy_walk
        ;; en_phase counts round walk_period frames, and the walker steps on
        ;; the first walk_steps of them: one in two on easy, two in three on
        ;; medium, every frame on hard (difficulty_apply, diff_tab).
        inc en_phase,x
        lda en_phase,x
        cmp walk_period
        bcc +
        lda #0
        sta en_phase,x
+       cmp walk_steps
        bcc +
        rts
+

;; One step along the patrol, turning at either end. Past the left end can
;; wrap below 0, which reads as past the right - so which end it went past
;; is decided by the way it was going, not by the number.
enemy_bounce
        inc en_anim,x           ; a step: the animation goes with it
        lda en_x,x
        clc
        adc en_dx,x
        sta en_x,x
        cmp en_x0,x
        bcc _turn
        cmp en_x1,x
        beq _ok
        bcs _turn
_ok     rts
_turn   lda en_dx,x
        bmi +
        lda en_x1,x
        jmp _clamp
+       lda en_x0,x
_clamp  sta en_x,x
        lda en_dx,x
        eor #$ff
        clc
        adc #1
        sta en_dx,x
        rts

;; ---------------------------------------------------------------------------
;; enemies_stun - the belly-flop landed. Everything within FLOP_REACH_Y of
;; the cat's height goes down, however far along the shelf it is: that is
;; what makes the flop the way past a robot that patrols a whole shelf.
;; ---------------------------------------------------------------------------
enemies_stun
        ldx #ENEMY_COUNT-1
_one    lda en_type,x
        beq _next
        lda cat_y
        sec
        sbc en_y,x
        bcs +
        eor #$ff                ; |dy|
        adc #1
+       cmp #FLOP_REACH_Y+1
        bcs _next
        lda stun_time
        sta en_stun,x
_next   dex
        bpl _one
        rts

;; ---------------------------------------------------------------------------
;; enemies_hit_cat - carry set if anything awake overlaps the cat.
;; ---------------------------------------------------------------------------
enemies_hit_cat
        ldx #ENEMY_COUNT-1
_one    lda en_type,x
        beq _next
        lda en_stun,x
        bne _next               ; flat on its back: scenery, not a threat
        ldy en_type,x
        lda ek_w-1,y
        sta box_w
        lda ek_h-1,y
        sta box_h
        lda en_x,x
        sta box_x
        lda en_y,x
        sta box_y
        jsr cat_hits_box
        bcs _hit
_next   dex
        bpl _one
        clc
_hit    rts

;; ---------------------------------------------------------------------------
;; enemies_shadow - the sprite shadows for all three: enemy n is sprites
;; 2n+2 (the overlay, in front) and 2n+3 (the body).
;;
;; A stunned enemy blinks grey, which the CPC could not afford and which
;; answers the commonest question anyone asks about the flop.
;; ---------------------------------------------------------------------------
enemies_shadow
        ldx #ENEMY_COUNT-1
_one    txa
        asl
        clc
        adc #2
        sta spr_n               ; the overlay's number
        lda en_type,x
        bne +
        jsr spr_hide_pair
        jmp _next
+       tay
        lda en_dx,x
        bmi _left
        lda ek_right_lo-1,y
        sta frmp
        lda ek_right_hi-1,y
        sta frmp+1
        jmp _pos
_left   lda ek_left_lo-1,y
        sta frmp
        lda ek_left_hi-1,y
        sta frmp+1
_pos    lda en_anim,x           ; every ANIM_STEPS steps, the other picture:
        and #ANIM_STEPS         ; it is the next two descriptors on
        beq +
        lda frmp
        clc
        adc #2*FRM_SIZE
        sta frmp
        bcc +
        inc frmp+1
+       lda en_x,x
        sta spr_px
        lda en_y,x
        sta spr_py
        lda #0
        sta spr_grey
        lda en_stun,x
        beq +
        lda frame_count
        and #4
        beq +
        lda #11                 ; dark grey every other four frames
        sta spr_grey
+       stx en_i                ; spr_pair has every register and tmp
        jsr spr_pair
        ldx en_i
_next   dex
        bpl _one
        rts
