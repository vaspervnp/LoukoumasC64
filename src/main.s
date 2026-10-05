;; ===========================================================================
;; main.s - LOUKOUMAS for the Commodore 64 (PAL).
;;
;; The CPC's loukoumas.asm: the machine set up, then title -> difficulty ->
;; game, round and round. One program, both languages; L changes language on
;; the title as it does on the CPC.
;;
;; Build: 64tass, one assembly unit - this file includes everything. The
;; result is a .prg that loads at $0801 and starts itself with SYS.
;;
;;   $0801-       BASIC stub, code, the read-only tables, and the sprites
;;                and font on their way to bank 3
;;   $9000-$BFFF  workspace built at run time (vars.s)
;;   $C000/$C400  text and bitmap screens   \
;;   $C800-$CFFF  the font                   |  VIC bank 3: everything
;;   $D000-$DFFF  sprite blocks, under I/O   |  the VIC shows lives here
;;   $E000-$FF3F  the bitmap, under KERNAL  /
;; ===========================================================================

        .cpu "6502"

        .include "config.s"
        .include "vars.s"

        * = $0801
        .word (+), 2026         ; 2026 SYS 2061
        .null $9e, format("%d", start)
+       .word 0

start
        sei
        ldx #$ff                ; the stack is ours: BASIC is not coming back
        txs
        jsr machine_init
        jsr detect_ntsc
        lda #6
        sta ntsc_sfx
        sta ntsc_tick
        lda #0
        sta script_frame
        sta script_frame+1
        sta prof_max
        sta prof_max+1
        sta prof_load
        jsr video_init
        jsr sfx_init
        lda #LANG_EL            ; it is a Greek cat
        sta lang
        lda #DIFF_HARD          ; the game as it was before there was a choice,
        sta difficulty          ; so the chooser only ever makes it kinder
        jsr difficulty_apply
        jsr dl_title            ; the clock first: everything after it waits
        jsr irq_start           ; for frames
        jsr title_draw

main_loop
        jsr title_loop
        jsr difficulty_loop
        jsr play_screen
        jsr title_draw
        jmp main_loop

;; ===========================================================================
;; The title
;;
;; Until the Koala picture exists (loukc64.md 5.7) the title is a room: the
;; window and the sofa from the lounge, a shelf, the cat on it, and the name
;; drawn large over it with a shadow. The footer is a band of hires text
;; split off the bottom of the bitmap, which is the CPC's footer without the
;; clearing it needed.
;; ===========================================================================

TITLE_Y         = 10
SUBTITLE_Y      = 38
TITLE_SHELF_Y   = 17*8+5                ; the cat stands here
ROW_PRESS       = 20
ROW_LANG        = 22
ROW_CREDIT      = 24
ROW_DIFF        = 20
ROW_DIFFNAME    = 22
ROW_DIFFHINT    = 24
BLINK_BIT       = $20                   ; frame_count bit: 0.64 s each way

title_draw
        lda #0
        sta screen_on
        sta spr_en
        jsr wait_frame
        jsr dl_title
        lda #0
        sta clip_top
        sta shake_y
        jsr clear_all
        lda #LIGHT_INDOOR
        sta bg_col
        sta border_col

        lda #PROP_WINDOW        ; a room for the name to hang in
        sta prop_id
        lda #106
        sta prop_x
        lda #60
        sta prop_y
        jsr draw_prop
        lda #PROP_SOFA
        sta prop_id
        lda #8
        sta prop_x
        lda #TITLE_SHELF_Y-44
        sta prop_y
        jsr draw_prop
        lda #0                  ; the shelf, all the way across
        sta bx
        lda #SCREEN_W
        sta bw
        lda #TITLE_SHELF_Y
        sta by
        lda #SHELF_H
        sta bh
        lda #2
        sta bpen
        jsr fill_box
        lda #<pick_sausage      ; and what he is here for
        sta picp
        lda #>pick_sausage
        sta picp+1
        lda #84
        sta pic_x
        lda #TITLE_SHELF_Y-PICK_H
        sta pic_y
        jsr draw_pic

        lda #<frm_cat_stand     ; the cat
        sta frmp
        lda #>frm_cat_stand
        sta frmp+1
        lda #0
        sta spr_n
        sta spr_grey
        lda #64
        sta spr_px
        lda #TITLE_SHELF_Y-CAT_H
        sta spr_py
        jsr spr_pair

        jsr title_text
        lda #1
        sta screen_on
        rts

;; The parts that change with the language.
title_text
        ldx #1                  ; the name's band of the bitmap
        ldy #5
        jsr clear_cells
        lda #2
        sta txt_sx
        lda #3
        sta txt_sy
        lda #TITLE_Y+2          ; the shadow, one pixel right and two down
        sta txt_y
        lda #4
        sta txt_pen
        lda #MSG_TITLE1
        jsr big_text_centre
        dec txt_y
        dec txt_y
        dec txt_x
        lda #2                  ; and the name over it, butter yellow
        sta txt_pen
        lda #MSG_TITLE1
        jsr big_text
        lda #1
        sta txt_sx
        sta txt_sy
        lda #SUBTITLE_Y
        sta txt_y
        lda #1                  ; coral
        sta txt_pen
        lda #MSG_TITLE2
        jsr big_text_centre
        ;; fall through: the footer

title_footer
        ldy #FOOT_ROW
-       tya
        pha
        jsr clear_text_row
        pla
        tay
        iny
        cpy #25
        bne -
        ldx #FOOT_ROW
        ldy #25-FOOT_ROW
        lda #1
        jsr text_ink
        lda #MSG_LANGHINT
        ldy #ROW_LANG
        jsr print_msg_centre
        lda #MSG_CREDIT
        ldy #ROW_CREDIT
        jsr print_msg_centre
        ldx #ROW_CREDIT
        ldy #1
        lda #15                 ; the credit quieter
        jsr text_ink
        ldx #ROW_PRESS
        ldy #1
        lda #7                  ; and the call to action yellow
        jmp text_ink

title_loop
        jsr wait_frame
        jsr read_controls
        lda ctl_pressed
        and #CTL_FIRE
        bne _done
        lda ctl_pressed
        and #CTL_LANG
        beq _blink
        lda lang                ; L: the other language
        eor #1
        sta lang
        jsr title_text
_blink  ldy #ROW_PRESS          ; PRESS FIRE, on and off
        jsr clear_text_row
        lda frame_count
        and #BLINK_BIT
        beq title_loop
        lda #MSG_PRESS
        ldy #ROW_PRESS
        jsr print_msg_centre
        jmp title_loop
_done   rts

;; ===========================================================================
;; How hard: the footer again, left and right to choose, fire to play.
;; ===========================================================================

DIFF_EASY       = 0
DIFF_MEDIUM     = 1
DIFF_HARD       = 2
DIFF_COUNT      = 3
DIFF_SIZE       = 4

;; walk period, fly period, flop stun, lives. Hard is the CPC's game as it
;; always was; the other two step the cast less often rather than less far.
diff_tab
        .byte 3, 3, 200, 9      ; easy: four seconds flat out, nine lives
        .byte 2, 2, 150, 6      ; medium
        .byte 1, 1, 100, 3      ; hard
diff_tab_end
        .cerror diff_tab_end-diff_tab != DIFF_COUNT*DIFF_SIZE
        .cerror MSG_DIFFMED != MSG_DIFFEASY+1 || MSG_DIFFHARD != MSG_DIFFEASY+2

difficulty_loop
        ldy #ROW_PRESS
        jsr clear_text_row
        ldy #ROW_LANG
        jsr clear_text_row
        ldy #ROW_CREDIT
        jsr clear_text_row
        ldx #FOOT_ROW
        ldy #25-FOOT_ROW
        lda #1
        jsr text_ink
        lda #MSG_DIFFICULTY
        ldy #ROW_DIFF
        jsr print_msg_centre
        lda #MSG_DIFFHINT
        ldy #ROW_DIFFHINT
        jsr print_msg_centre
        ldx #ROW_DIFFNAME
        ldy #1
        lda #7
        jsr text_ink
        jsr draw_difficulty
_frame  jsr wait_frame
        jsr read_controls
        lda ctl_pressed
        and #CTL_FIRE
        bne _done
        lda ctl_pressed
        and #CTL_LEFT
        beq +
        lda difficulty
        beq +
        dec difficulty
        jsr draw_difficulty
+       lda ctl_pressed
        and #CTL_RIGHT
        beq _frame
        lda difficulty
        cmp #DIFF_COUNT-1
        bcs _frame
        inc difficulty
        jsr draw_difficulty
        jmp _frame
_done   jmp difficulty_apply

draw_difficulty
        ldy #ROW_DIFFNAME
        jsr clear_text_row
        lda difficulty
        clc
        adc #MSG_DIFFEASY
        ldy #ROW_DIFFNAME
        jmp print_msg_centre

difficulty_apply
        lda difficulty
        asl
        asl
        tax
        ldy #0
-       lda diff_tab,x
        sta walk_period,y
        inx
        iny
        cpy #DIFF_SIZE
        bne -
        rts

;; ===========================================================================
;; The code
;; ===========================================================================
        .include "irq.s"
        .include "keys.s"
        .include "sound.s"
        .include "video.s"
        .include "text.s"
        .include "sprite.s"
        .include "play.s"
        .include "enemy.s"
        .if SCRIPT != 0
        .include "script.s"
        .endif

;; ===========================================================================
;; The tables, read-only
;; ===========================================================================
        .include "strings.s"
        .include "sprites.s"
        .include "art.s"
        .include "rooms.s"

code_end
        .cerror code_end > CODE_LIMIT, "the code and tables run into the workspace"

;; ===========================================================================
;; What the VIC shows, carried behind the tables and copied into bank 3 by
;; machine_init: the sprite blocks under the I/O, the font at CHARSET.
;; ===========================================================================
sprite_store
        .logical SPRITE_MEM
        .include "spriteblk.s"
        .cerror * > SPRITE_MEM+$1000, "too many sprite blocks"
        .endlogical
font_store
        .logical CHARSET
        .include "font.s"
        .cerror * > CHARSET+$800, "the font is more than 256 characters"
        .endlogical
store_end
        .cerror store_end > CODE_LIMIT, "the file runs into the workspace"
