;; ===========================================================================
;; play.s - playing a room: the cat's physics, the pickups, damage, the HUD
;; and the way out. The CPC's play.asm, rule for rule (loukc64.md 2).
;;
;; Nothing here knows the flat's layout: every table it walks comes from the
;; room record room_load points it at.
;;
;; What is gone, and why (loukc64.md 1): the render every second frame, the
;; draw order, the erase/draw window, exit_pending, enemies_tangled. The VIC
;; draws the cast every frame and nothing it draws ever touches the bitmap, so
;; the bitmap can be changed whenever the game likes - the door opens the
;; moment the last sausage goes.
;; ===========================================================================

ST_GROUND       = 0
ST_AIR          = 1
ST_FLOP         = 2
ST_ROLL         = 3

FR_STAND        = 0
FR_WALK1        = 1
FR_WALK2        = 2
FR_ROLL         = 3
FR_FLAT         = 4

cat_frm_lo      .byte <frm_cat_stand, <frm_cat_walk1, <frm_cat_walk2, <frm_cat_roll, <frm_cat_flat
cat_frm_hi      .byte >frm_cat_stand, >frm_cat_walk1, >frm_cat_walk2, >frm_cat_roll, >frm_cat_flat
cat_frm_h       .byte SPR_CAT_STAND_H, SPR_CAT_WALK1_H, SPR_CAT_WALK2_H, SPR_CAT_ROLL_H, SPR_CAT_FLAT_H
        .cerror SPR_CAT_STAND_H != CAT_H, "the standing cat is not CAT_H tall"

;; --- The room record (rooms.s) ----------------------------------------------
R_NAME          = 0
R_PLAT          = 1
R_SAUS          = 3
R_NSAUS         = 5
R_ENEM          = 6
R_NENEM         = 8
R_PROPS         = 9
R_EXITPX        = 11
R_EXITPY        = 12
R_EXITX         = 13
R_EXITY         = 14
R_EXITW         = 15
R_EXITH         = 16
R_EXITSHUT      = 17
R_EXITOPEN      = 18
R_STARTX        = 19
R_STARTY        = 20
R_MILKX         = 21
R_MILKY         = 22
R_LIGHT         = 23
R_FLOOR         = 24
R_SIZE          = 25

ROOM_COUNT      = 29
SAUSAGE_MAX     = 6
PICK_MILK       = SAUSAGE_MAX           ; the saucer is pickup 6
PICK_COUNT      = SAUSAGE_MAX+1
PICK_CELLS      = 6                     ; 3 across, 2 down, at most
PICK_BUF        = PICK_CELLS*10

SAUSAGE_POINTS  = $01                   ; BCD, into the hundreds
MILK_POINTS     = $05

;; --- HUD: two rows of forty, captions from the string table -----------------
;; Columns leave room for the longer language: SCORE/ΣΚΟΡ, LIVES/ΖΩΕΣ,
;; SAUSAGES/ΛΟΥΚΑΝΙΚΑ, and sixteen for the room name.
HUD_LABEL_X     = 1
HUD_NUM_X       = 11
HUD_LABEL2_X    = 23
HUD_LIVES_X     = 30
HUD_ROOM_X      = 23
HUD_INK         = 1                     ; white captions
HUD_NUM_INK     = 7                     ; yellow numbers

BANNER_ROW      = 5                     ; cell rows 5-7, lines 40-63
BANNER_ROWS     = 3
BANNER_Y        = BANNER_ROW*8+5

;; ---------------------------------------------------------------------------
;; play_screen - walk the flat, one room at a time. Returns on RUN/STOP.
;; ---------------------------------------------------------------------------
play_screen
        jsr sfx_init
        lda #0
        sta score
        sta score+1
        sta score+2
        sta game_over
        lda start_lives
        sta cat_lives
        lda #STARTROOM
        sta cur_room

play_room
        jsr room_load

play_loop
        jsr wait_frame
        .if PROFILE != 0
        jsr prof_start
        .endif
        jsr cat_shadow          ; what the last step worked out, to the
        jsr enemies_shadow      ; shadows while the beam is still at the top
        lda is_ntsc             ; at 60 Hz, five steps of the 50 Hz game in
        beq +                   ; every six frames: the jump, the patrols and
        dec ntsc_tick           ; every timer keep their length in seconds
        bne +
        lda #6
        sta ntsc_tick
        jmp play_loop
+        jsr read_controls
        lda ctl_pressed
        and #CTL_QUIT
        bne play_quit

        lda game_over
        beq _alive
        lda ctl_pressed         ; the banner is up: fire starts again, and it
        and #CTL_FIRE           ; has to be a press, so holding fire through
        beq play_loop           ; the last life does not restart it at once
        jmp play_screen

_alive  jsr cat_update
        jsr enemies_update
        jsr check_sausages
        jsr check_enemies
        jsr shake_update
        jsr flash_update
        lda game_over           ; a robot may just have ended it
        bne play_loop
        jsr check_exit
        bcs _exit
        jsr update_hud
        .if PROFILE != 0
        jsr prof_end
        .endif
        jmp play_loop

_exit   inc cur_room            ; through the door
        lda cur_room
        cmp #ROOM_COUNT
        bcc play_room
        lda #1                  ; that was the last one
        sta game_over
        lda #MSG_WELLDONE
        jsr big_banner
        jmp play_loop

play_quit
        jsr sfx_init
        lda #0
        sta shake_y
        sta shake_timer
        rts

;; ---------------------------------------------------------------------------
;; prof_start / prof_end - in a PROFILE build, how many raster lines one
;; frame's logic took, the worst so far in prof_max (loukc64.md 6.4: it is
;; measured, not assumed). A PAL frame is 312 lines; the logic has all of it
;; but the frame interrupt's own.
;; ---------------------------------------------------------------------------
        .if PROFILE != 0
prof_line
        lda $d011               ; the nine-bit raster line, read so the two
        and #$80                ; halves belong together
        sta prof_t+1
        lda $d012
        cmp $d012
        bne prof_line
        sta prof_t
        lda $d011
        and #$80
        cmp prof_t+1
        bne prof_line
        asl prof_t+1
        rol prof_t+1            ; bit 7 -> bit 0
        lda prof_t+1
        and #1
        sta prof_t+1
        rts
prof_start
        jsr prof_line
        lda prof_t
        sta prof_s
        lda prof_t+1
        sta prof_s+1
        rts
prof_end
        jsr prof_line
        lda prof_t              ; lines = end - start, mod 312
        sec
        sbc prof_s
        sta prof_t
        lda prof_t+1
        sbc prof_s+1
        sta prof_t+1
        bcs +
        lda prof_t
        clc
        adc #<312
        sta prof_t
        lda prof_t+1
        adc #>312
        sta prof_t+1
+       lda prof_t+1            ; the worst
        cmp prof_max+1
        bcc _done
        bne +
        lda prof_t
        cmp prof_max
        bcc _done
+       lda prof_t
        sta prof_max
        lda prof_t+1
        sta prof_max+1
        lda cur_room
        sta prof_room
_done   rts
        .endif

;; ===========================================================================
;; Loading a room
;; ===========================================================================

room_load
        lda #0
        sta screen_on           ; build it unseen
        sta spr_en
        jsr wait_frame
        .if PROFILE != 0
        lda frame_count
        sta prof_load_t
        .endif

        lda #<rooms             ; roomp = rooms + cur_room * R_SIZE
        sta roomp
        lda #>rooms
        sta roomp+1
        ldx cur_room
        beq _found
-       lda roomp
        clc
        adc #R_SIZE
        sta roomp
        bcc +
        inc roomp+1
+       dex
        bne -
_found
        ldy #R_NAME
        lda (roomp),y
        sta room_name
        ldy #R_PLAT
        lda (roomp),y
        sta cur_plat
        iny
        lda (roomp),y
        sta cur_plat+1
        ldy #R_SAUS
        lda (roomp),y
        sta cur_saus
        iny
        lda (roomp),y
        sta cur_saus+1
        ldy #R_NSAUS
        lda (roomp),y
        sta cur_nsaus
        ldy #R_PROPS
        lda (roomp),y
        sta cur_props
        iny
        lda (roomp),y
        sta cur_props+1
        ldy #R_EXITPX           ; the eight exit bytes, in record order
        ldx #0
-       lda (roomp),y
        sta exit_px,x
        iny
        inx
        cpx #8
        bne -
        ldy #R_MILKX
        lda (roomp),y
        sta milk_x
        iny
        lda (roomp),y
        sta milk_y
        ldy #R_LIGHT
        lda (roomp),y
        sta room_light
        sta bg_col
        sta border_col
        ldy #R_FLOOR
        lda (roomp),y
        sta room_floor

        lda #FR_STAND           ; the picture first: setting it moves y to
        sta cat_frame           ; keep the feet, and y is about to be set
        lda #CAT_H
        sta cat_h
        ldy #R_STARTX
        lda (roomp),y
        sta cat_x
        sta cat_startx
        iny
        lda (roomp),y
        sta cat_y
        sta cat_starty

        lda #0
        sta cat_xf
        sta cat_yf
        sta cat_vy
        sta cat_vy+1
        sta cat_stun
        sta cat_state
        sta cat_anim
        sta cat_invul
        sta level_done
        sta sausages_got
        sta shake_timer
        sta shake_y
        sta milk_flash
        sta hud_dirty

        ldx #PICK_COUNT-1       ; a full larder
-       lda #0
        cpx cur_nsaus
        bcs +
        lda #1
+       sta pick_alive,x
        dex
        bpl -
        lda milk_x
        cmp #NO_MILK
        beq +
        lda #1
        sta pick_alive+PICK_MILK
+
        ldy #R_ENEM
        lda (roomp),y
        sta enemp
        iny
        lda (roomp),y
        sta enemp+1
        ldy #R_NENEM
        lda (roomp),y
        jsr enemies_init

        jsr dl_game
        lda #PLAY_TOP
        sta clip_top
        jsr clear_all
        ldx #0
        ldy #HUD_ROWS
        lda #HUD_INK
        jsr text_ink

        jsr draw_props          ; scenery and furniture, everything else on top
        jsr draw_platforms
        jsr draw_exit
        jsr pickups_init
        jsr draw_hud

        jsr cat_shadow
        jsr enemies_shadow
        .if PROFILE != 0
        lda frame_count         ; how many frames the room took to draw
        sec
        sbc prof_load_t
        cmp prof_load
        bcc +
        sta prof_load
+
        .endif
        jsr wait_frame
        lda #1
        sta screen_on
        rts

;; ---------------------------------------------------------------------------
;; draw_props - the room's furniture, painted once into the bitmap. A prop id
;; with bit 7 set is a decal, a picture; anything else is a list of boxes.
;; ---------------------------------------------------------------------------
DECAL           = $80

draw_props
        lda cur_props
        sta propl
        lda cur_props+1
        sta propl+1
_next   ldy #0
        lda (propl),y
        cmp #$ff
        beq _done
        sta prop_id
        iny
        lda (propl),y
        sta prop_x
        iny
        lda (propl),y
        sta prop_y
        lda propl
        clc
        adc #3
        sta propl
        bcc +
        inc propl+1
+       lda prop_id
        bpl _boxes
        and #$7f                ; a decal
        asl
        tax
        lda decal_table,x
        sta picp
        lda decal_table+1,x
        sta picp+1
        lda prop_x
        sta pic_x
        lda prop_y
        sta pic_y
        jsr draw_pic
        jmp _next
_boxes  jsr draw_prop
        jmp _next
_done   rts

;; draw_prop - prop_id at prop_x, prop_y.
draw_prop
        lda prop_id
        asl
        tax
        lda prop_boxes,x
        sta boxl
        lda prop_boxes+1,x
        sta boxl+1
_box    ldy #0
        lda (boxl),y
        cmp #$ff
        beq _done
        clc
        adc prop_x
        sta bx
        iny
        lda (boxl),y
        clc
        adc prop_y
        bcs _skip               ; past line 255: nothing of it is on screen
        sta by
        iny
        lda (boxl),y
        sta bw
        iny
        lda (boxl),y
        sta bh
        iny
        lda (boxl),y
        sta bpen
        jsr fill_box
_skip   lda boxl
        clc
        adc #5
        sta boxl
        bcc _box
        inc boxl+1
        jmp _box
_done   rts

;; ---------------------------------------------------------------------------
;; draw_platforms - the floor as a band, every platform as a shelf. Every
;; room's first platform is its floor.
;;
;; The floor gets the same yellow edge as the shelves, and its own colour
;; starts on the cell row below: the row the floor's top is in is also the
;; row the furniture's feet and the sausages on the floor are in, and the
;; floor's own colour there would be a fourth.
;; ---------------------------------------------------------------------------
draw_platforms
        lda #0
        sta bx
        lda #SCREEN_W
        sta bw
        lda #FLOOR_Y+SHELF_H
        sta by
        lda #FLOOR_H-SHELF_H
        sta bh
        lda room_floor
        sta bpen
        jsr fill_box

        ldy #0
_next   lda (cur_plat),y
        cmp #$ff
        beq _done
        sta bx
        iny
        lda (cur_plat),y
        sec
        sbc bx
        clc
        adc #1
        sta bw
        iny
        lda (cur_plat),y
        sta by
        iny
        sty plat_i
        lda #SHELF_H
        sta bh
        lda #2
        sta bpen
        jsr fill_box
        ldy plat_i
        jmp _next
_done   rts

;; ---------------------------------------------------------------------------
;; draw_exit - the way out, shut or open.
;; ---------------------------------------------------------------------------
draw_exit
        lda exit_px
        sta prop_x
        lda exit_py
        sta prop_y
        lda exit_shut
        ldx level_done
        beq +
        lda exit_open
+       sta prop_id
        jmp draw_prop

;; ---------------------------------------------------------------------------
;; check_exit - carry set once the cat has stepped into an open way out.
;; ---------------------------------------------------------------------------
check_exit
        lda level_done
        bne +
        clc
        rts
+       lda exit_x
        sta box_x
        lda exit_y
        sta box_y
        lda exit_w
        sta box_w
        lda exit_h
        sta box_h
        jmp cat_hits_box

;; ===========================================================================
;; Pickups (loukc64.md 5.4)
;;
;; Up to seven a room - five or six sausages and a saucer - and there are not
;; sprites for them, so they are painted into the bitmap. Each keeps the cells
;; it covers, exactly as they were before any pickup went down, and puts them
;; back when it is eaten. All of them are saved before any is drawn, so no
;; pickup's copy has another pickup in it; when two share a cell, eating one
;; draws the other again.
;; ===========================================================================

pickups_init
        ldx #0
_save   stx pick_i
        jsr pick_where
        bcc +
        jsr pick_bufp
        jsr save_cells
+       ldx pick_i
        inx
        cpx #PICK_COUNT
        bne _save
        ldx #0
_draw   stx pick_i
        lda pick_alive,x
        beq +
        jsr pick_draw
+       ldx pick_i
        inx
        cpx #PICK_COUNT
        bne _draw
        rts

;; pick_where - X = pickup. Its position into pk_x, pk_y and its cell block
;; into sv_*; carry clear if it is not in this room.
pick_where
        cpx #PICK_MILK
        beq _milk
        cpx cur_nsaus
        bcs _none
        txa
        asl
        tay
        lda (cur_saus),y
        sta pk_x
        iny
        lda (cur_saus),y
        sta pk_y
        jmp _cells
_milk   lda milk_x
        cmp #NO_MILK
        beq _none
        sta pk_x
        lda milk_y
        sta pk_y
_cells  lda pk_x
        lsr
        lsr
        sta sv_cc
        lda pk_x
        clc
        adc #PICK_W-1
        lsr
        lsr
        sec
        sbc sv_cc
        clc
        adc #1
        sta sv_nc
        lda pk_y
        lsr
        lsr
        lsr
        sta sv_cr
        lda pk_y
        clc
        adc #PICK_H-1
        lsr
        lsr
        lsr
        sec
        sbc sv_cr
        clc
        adc #1
        sta sv_nr
        sec
        rts
_none   clc
        rts

;; pick_bufp - bufp = PICK_BUFS + pick_i * PICK_BUF.
pick_bufp
        lda #<PICK_BUFS
        sta bufp
        lda #>PICK_BUFS
        sta bufp+1
        ldx pick_i
        beq _done
-       lda bufp
        clc
        adc #PICK_BUF
        sta bufp
        bcc +
        inc bufp+1
+       dex
        bne -
_done   rts

;; pick_draw - pickup pick_i, painted.
pick_draw
        ldx pick_i
        jsr pick_where
        lda #<pick_sausage
        ldy #>pick_sausage
        ldx pick_i
        cpx #PICK_MILK
        bne +
        lda #<pick_milk
        ldy #>pick_milk
+       sta picp
        sty picp+1
        lda pk_x
        sta pic_x
        lda pk_y
        sta pic_y
        lda #1
        sta soft
        jsr draw_pic
        lda #0
        sta soft
        rts

;; pick_erase - pickup pick_i, gone: its cells back, and anything that shared
;; them drawn again.
pick_erase
        ldx pick_i
        jsr pick_where
        jsr pick_bufp
        jsr restore_cells
        ldx pick_i              ; the block that was just put back
        jsr pick_where
        lda sv_cc
        sta er_cc
        clc
        adc sv_nc
        sta er_cc1
        lda sv_cr
        sta er_cr
        clc
        adc sv_nr
        sta er_cr1
        lda pick_i
        sta er_i
        ldx #0
_other  stx pick_i
        cpx er_i
        beq _next
        lda pick_alive,x
        beq _next
        jsr pick_where
        lda sv_cc               ; do the two blocks overlap?
        cmp er_cc1
        bcs _next
        clc
        adc sv_nc
        cmp er_cc
        beq _next
        bcc _next
        lda sv_cr
        cmp er_cr1
        bcs _next
        clc
        adc sv_nr
        cmp er_cr
        beq _next
        bcc _next
        jsr pick_draw
_next   ldx pick_i
        inx
        cpx #PICK_COUNT
        bne _other
        lda er_i
        sta pick_i
        rts

;; ---------------------------------------------------------------------------
;; check_sausages - what the cat is standing in front of, eaten.
;; ---------------------------------------------------------------------------
check_sausages
        jsr check_milk          ; before the early-out: the saucer is still
        lda level_done          ; there to be had after the last sausage
        bne _done
        ldx #0
_one    cpx cur_nsaus
        bcs _all
        stx pick_i
        lda pick_alive,x
        beq _next
        jsr pick_where
        jsr pick_box
        jsr cat_hits_box
        bcc _next
        ldx pick_i
        lda #0
        sta pick_alive,x
        lda #SFX_EAT
        jsr sfx_play
        jsr pick_erase
        inc sausages_got
        lda #SAUSAGE_POINTS
        jsr score_add
        lda #1
        sta hud_dirty
_next   ldx pick_i
        inx
        jmp _one
_all    lda sausages_got
        cmp cur_nsaus
        bne _done
        lda #1                  ; the way out opens - now: nothing the VIC is
        sta level_done          ; drawing has a copy of the shut door in it
        jsr draw_exit
_done   rts

pick_box
        lda pk_x
        sta box_x
        lda pk_y
        sta box_y
        lda #PICK_W
        sta box_w
        lda #PICK_H
        sta box_h
        rts

;; check_milk - a life back, up to what he started with, and points either
;; way. The way out does not wait for it.
check_milk
        lda pick_alive+PICK_MILK
        beq _done
        ldx #PICK_MILK
        stx pick_i
        jsr pick_where
        jsr pick_box
        jsr cat_hits_box
        bcc _done
        lda #0
        sta pick_alive+PICK_MILK
        jsr pick_erase
        lda level_done          ; a saucer in front of an open door put a
        beq +                   ; piece of the shut one back
        jsr draw_exit
+       lda cat_lives
        cmp start_lives
        bcs +                   ; already full: it is worth points instead
        inc cat_lives
+       lda #MILK_POINTS
        jsr score_add
        lda #1
        sta hud_dirty
        lda #MILK_FLASH_LEN
        sta milk_flash
_done   rts

;; ---------------------------------------------------------------------------
;; score_add - A = a BCD byte added to the hundreds. Packed BCD, most
;; significant byte first, so decimal mode does the arithmetic and printing
;; needs no division. The interrupt clears D itself (irq.s).
;; ---------------------------------------------------------------------------
score_add
        sed
        clc
        adc score+1
        sta score+1
        lda score
        adc #0
        sta score
        cld
        rts

;; ---------------------------------------------------------------------------
;; flash_update - the border, for a moment, when a life comes back.
;; ---------------------------------------------------------------------------
flash_update
        lda milk_flash
        beq _done
        dec milk_flash
        lda #MILK_FLASH_COL
        ldx milk_flash
        bne +
        lda room_light
+       sta border_col
_done   rts

;; ---------------------------------------------------------------------------
;; shake_update - the belly-flop's thud: the picture drops a few lines and
;; comes back, through YSCROLL in the split (irq.s, loukc64.md 5.6).
;; ---------------------------------------------------------------------------
shake_update
        lda shake_timer
        beq _done
        dec shake_timer
        ldx shake_timer
        lda shake_tab,x
        sta shake_y
_done   rts

shake_tab       .byte 0, 2, 2, 4, 4, 2          ; by the timer counting down
        .cerror * - shake_tab != SHAKE_LEN

;; ===========================================================================
;; The HUD
;; ===========================================================================

draw_hud
        ldy #0
        jsr clear_text_row
        ldy #1
        jsr clear_text_row
        lda #MSG_SCORE
        ldx #HUD_LABEL_X
        ldy #0
        jsr print_msg
        lda #MSG_LIVES
        ldx #HUD_LABEL2_X
        ldy #0
        jsr print_msg
        lda #MSG_SAUSAGES
        ldx #HUD_LABEL_X
        ldy #1
        jsr print_msg
        lda room_name
        ldx #HUD_ROOM_X
        ldy #1
        jsr print_msg
        ldx #HUD_NUM_X          ; the numbers in their own ink
        lda #HUD_NUM_INK
-       sta COLOUR_RAM,x
        sta COLOUR_RAM+40,x
        inx
        cpx #HUD_NUM_X+6
        bne -
        sta COLOUR_RAM+HUD_LIVES_X
        ;; fall through: the numbers

;; Only the numbers move, so only the numbers are rewritten.
hud_numbers
        lda #0
        sta txt_row
        lda #HUD_NUM_X
        sta txt_col
        lda score
        jsr print_bcd
        lda score+1
        jsr print_bcd
        lda score+2
        jsr print_bcd
        lda #HUD_LIVES_X
        sta txt_col
        lda cat_lives
        jsr print_digit
        lda #1
        sta txt_row
        lda #HUD_NUM_X
        sta txt_col
        lda sausages_got
        jsr print_digit
        lda #GL_SLASH
        jsr print_code
        lda cur_nsaus
        jmp print_digit

update_hud
        lda hud_dirty
        beq _done
        lda #0
        sta hud_dirty
        jmp hud_numbers
_done   rts

;; ---------------------------------------------------------------------------
;; big_banner - A = message, large, across a band of the bitmap cleared for
;; it. The cast stays where it is: it is drawn by the VIC, not into the
;; picture, so there is nothing to lift off first.
;; ---------------------------------------------------------------------------
big_banner
        pha
        jsr hud_numbers         ; the life that just went still has to show
        ldx #BANNER_ROW
        ldy #BANNER_ROWS
        jsr clear_cells
        lda #2
        sta txt_sx
        sta txt_sy
        lda #BANNER_Y
        sta txt_y
        lda #2                  ; butter yellow
        sta txt_pen
        pla
        jmp big_text_centre

;; ===========================================================================
;; The cat
;; ===========================================================================

cat_update
        lda cat_stun
        beq +
        dec cat_stun            ; flat on the floor, no input
        rts
+       lda cat_state
        cmp #ST_ROLL
        bne +
        jmp cat_roll
+       cmp #ST_GROUND
        bne +
        jmp cat_ground
+       jmp cat_air

;; cat_ground - walking, rolling, jumping, or stepping off an edge.
cat_ground
        lda #<WALK_STEP
        ldx #>WALK_STEP
        jsr cat_step_h
        lda ctl_now
        and #CTL_DOWN
        beq _jump
        lda #FR_ROLL            ; curl up
        jsr cat_set_frame
        lda #ST_ROLL
        sta cat_state
        rts
_jump   lda ctl_pressed
        and #CTL_FIRE|CTL_UP
        beq _support
        lda #SFX_JUMP
        jsr sfx_play
        lda #<JUMP_V
        sta cat_vy
        lda #>JUMP_V
        sta cat_vy+1
        lda #ST_AIR
        sta cat_state
        lda #FR_STAND
        jmp cat_set_frame
_support
        jsr cat_has_support
        bcs _anim
        lda #ST_AIR             ; walked off the edge
        sta cat_state
        lda #0
        sta cat_vy
        sta cat_vy+1
        rts
_anim   lda cat_moved
        beq _stand
        inc cat_anim
        lda cat_anim
        and #WALK_BIT
        beq +
        lda #FR_WALK2
        jmp cat_set_frame
+       lda #FR_WALK1
        jmp cat_set_frame
_stand  lda #0
        sta cat_anim
        lda #FR_STAND
        jmp cat_set_frame

;; cat_roll - faster, and short enough to fit under things.
cat_roll
        lda #<ROLL_STEP
        ldx #>ROLL_STEP
        jsr cat_step_h
        lda ctl_now
        and #CTL_DOWN
        bne _support
        lda #FR_STAND           ; stand back up
        jsr cat_set_frame
        lda #ST_GROUND
        sta cat_state
        rts
_support
        jsr cat_has_support
        bcc +
        rts
+       lda #ST_AIR
        sta cat_state
        lda #0
        sta cat_vy
        sta cat_vy+1
        rts

;; cat_air - gravity, air control, the belly-flop, and landing.
cat_air
        lda #<WALK_STEP
        ldx #>WALK_STEP
        jsr cat_step_h

        lda cat_state           ; down plus fire commits to the belly
        cmp #ST_FLOP
        beq _gravity
        lda ctl_now
        and #CTL_DOWN
        beq _gravity
        lda ctl_pressed
        and #CTL_FIRE
        beq _gravity
        lda #SFX_FLOP
        jsr sfx_play
        lda #<FLOP_V
        sta cat_vy
        lda #>FLOP_V
        sta cat_vy+1
        lda #ST_FLOP
        sta cat_state
        lda #FR_FLAT
        jsr cat_set_frame

_gravity
        lda cat_vy
        clc
        adc #<GRAVITY
        sta cat_vy
        lda cat_vy+1
        adc #>GRAVITY
        sta cat_vy+1
        bmi _velocity           ; still rising
        lda cat_vy              ; falling: no faster than MAX_FALL
        cmp #<MAX_FALL
        lda cat_vy+1
        sbc #>MAX_FALL
        bcc _velocity
        lda #<MAX_FALL
        sta cat_vy
        lda #>MAX_FALL
        sta cat_vy+1
_velocity
        lda cat_y               ; where the feet were
        clc
        adc cat_h
        sta cat_ofeet

        lda cat_yf              ; 8.8: y is the line, yf the fraction
        clc
        adc cat_vy
        sta cat_yf
        lda cat_y
        adc cat_vy+1
        bcs _moved              ; a carry out is no borrow
        ldx cat_vy+1
        bpl _moved              ; and a positive step cannot underflow
        lda #0                  ; rose past the top of the screen
        sta cat_yf
        sta cat_vy
        sta cat_vy+1
        lda #PLAY_TOP
_moved  sta cat_y
        cmp #PLAY_TOP
        bcs _land
        lda #PLAY_TOP           ; into the HUD: the ceiling
        sta cat_y
        lda #0
        sta cat_yf
        sta cat_vy
        sta cat_vy+1

_land   lda cat_vy+1
        bpl +
        rts                     ; rising: nothing to land on
+       lda cat_y
        clc
        adc cat_h
        sta cat_nfeet
        jsr cat_find_landing
        bcs +
        rts
+       sec                     ; A = the platform's top
        sbc cat_h
        sta cat_y
        lda #0
        sta cat_yf
        sta cat_vy
        sta cat_vy+1
        lda cat_state
        cmp #ST_FLOP
        bne _upright
        lda #SHAKE_LEN          ; the whole room feels it
        sta shake_timer
        lda #FLOP_STUN
        sta cat_stun
        lda #ST_GROUND
        sta cat_state
        jmp enemies_stun
_upright
        lda #ST_GROUND
        sta cat_state
        lda #FR_STAND
        jmp cat_set_frame

;; cat_step_h - A, X = the step, 8.8. Left wins over right. Sets cat_moved.
cat_step_h
        sta step
        stx step+1
        lda #0
        sta cat_moved
        lda ctl_now
        and #CTL_LEFT
        beq _right
        lda cat_x
        ora cat_xf
        beq _done               ; against the left wall
        lda cat_xf
        sec
        sbc step
        sta cat_xf
        lda cat_x
        sbc step+1
        bcs +
        lda #0                  ; past it: stop on it
        sta cat_xf
+       sta cat_x
        inc cat_moved
        rts
_right  lda ctl_now
        and #CTL_RIGHT
        beq _done
        lda cat_x
        cmp #SCREEN_W-CAT_W
        bcs _done               ; against the right wall
        lda cat_xf
        clc
        adc step
        sta cat_xf
        lda cat_x
        adc step+1
        cmp #SCREEN_W-CAT_W
        bcc +
        lda #0
        sta cat_xf
        lda #SCREEN_W-CAT_W
+       sta cat_x
        inc cat_moved
_done   rts

;; cat_set_frame - A = FR_*. Keeps the feet where they are when the height
;; changes, so curling up and standing back up neither sink nor hop.
cat_set_frame
        tax
        stx cat_frame
        lda cat_h
        sec
        sbc cat_frm_h,x         ; old - new
        clc
        adc cat_y
        sta cat_y
        lda cat_frm_h,x
        sta cat_h
        rts

;; cat_has_support - carry set if a platform is right under the feet.
cat_has_support
        lda cat_y
        clc
        adc cat_h
        sta cat_ofeet
        sta cat_nfeet
        ;; fall through

;; cat_find_landing - carry set, A = the highest platform top between
;; cat_ofeet and cat_nfeet that the cat overlaps across. One-way platforms:
;; only ever asked on the way down.
cat_find_landing
        lda #$ff
        sta best_top
        ldy #0
_next   lda (cur_plat),y
        cmp #$ff
        beq _done
        sta plat_x0
        iny
        lda (cur_plat),y
        sta plat_x1
        iny
        lda (cur_plat),y
        sta plat_top
        iny
        lda plat_x1             ; ends before the cat starts
        cmp cat_x
        bcc _next
        lda cat_x               ; or the cat ends before it starts
        clc
        adc #CAT_W-1
        cmp plat_x0
        bcc _next
        lda plat_top
        cmp cat_ofeet
        bcc _next               ; the feet were already past it
        lda cat_nfeet
        cmp plat_top
        bcc _next               ; still above it
        lda plat_top
        cmp best_top
        bcs _next               ; something higher already found
        sta best_top
        jmp _next
_done   lda best_top
        cmp #$ff
        beq +
        sec
        rts
+       clc
        rts

;; cat_hits_box - carry set if the cat overlaps box_x, box_y, box_w, box_h.
;; Sausages, the saucer, enemies and the way out all come through here.
;; Leaves X and Y alone.
cat_hits_box
        lda box_x
        clc
        adc box_w
        sec
        sbc #1
        cmp cat_x
        bcc _no                 ; the box ends before the cat starts
        lda cat_x
        clc
        adc #CAT_W-1
        cmp box_x
        bcc _no                 ; the cat ends before the box starts
        lda box_y
        clc
        adc box_h
        sec
        sbc #1
        cmp cat_y
        bcc _no
        lda cat_y
        clc
        adc cat_h
        sec
        sbc #1
        cmp box_y
        bcc _no
        sec
        rts
_no     clc
        rts

;; ---------------------------------------------------------------------------
;; check_enemies - a life on contact, unless the grace from the last one is
;; still running.
;; ---------------------------------------------------------------------------
check_enemies
        lda cat_invul
        beq +
        dec cat_invul
+       jsr enemies_hit_cat
        bcs +
        rts
+       lda cat_invul
        beq cat_dies
        rts                     ; touched, but it costs nothing yet

;; cat_dies - one life gone: back to the start of the room with a moment of
;; grace, or the end of the game.
cat_dies
        lda #SFX_DIE
        jsr sfx_play
        dec cat_lives
        lda #1
        sta hud_dirty
        lda cat_lives
        beq _over
        lda #FR_STAND
        jsr cat_set_frame
        lda cat_startx
        sta cat_x
        lda cat_starty
        sta cat_y
        lda #0
        sta cat_xf
        sta cat_yf
        sta cat_stun
        sta cat_state
        sta cat_vy
        sta cat_vy+1
        lda #INVUL_FRAMES
        sta cat_invul
        rts
_over   lda #1
        sta game_over
        lda #MSG_GAMEOVER
        jmp big_banner

;; ---------------------------------------------------------------------------
;; cat_shadow - the cat's two sprites, from his state. He blinks while the
;; grace after a lost life lasts.
;; ---------------------------------------------------------------------------
cat_shadow
        lda #0
        sta spr_n
        sta spr_grey
        lda cat_invul
        beq +
        lda frame_count
        and #4
        beq +
        jmp spr_hide_pair
+       ldx cat_frame
        lda cat_frm_lo,x
        sta frmp
        lda cat_frm_hi,x
        sta frmp+1
        lda cat_x
        sta spr_px
        lda cat_y
        sta spr_py
        jmp spr_pair
