;; ===========================================================================
;; vars.s - every variable, in zero page or the workspace at WORK.
;;
;; Neither block costs a byte of the file: both are .virtual. Zero page holds
;; every pointer (the (zp),y addressing mode wants them there) and what the
;; inner loops touch; the arrays and the slower state live at WORK.
;;
;; With the KERNAL banked out, all of $02-$FF is ours.
;; ===========================================================================

        .virtual $02
;; --- pointers ---
ptr             .word ?
sptr            .word ?
cptr            .word ?
rowptr          .word ?
picp            .word ?
bufp            .word ?
msgp            .word ?
txtp            .word ?
fontp           .word ?
frmp            .word ?
cur_plat        .word ?
cur_saus        .word ?
cur_props       .word ?
roomp           .word ?
enemp           .word ?
propl           .word ?
boxl            .word ?
sfx_ptr         .word ?
scriptp         .word ?
mus_ptr         .word ?

;; --- the frame ---
frame_count     .byte ?
screen_on       .byte ?
shake_y         .byte ?

;; --- fill_box and the allocator ---
tmp             .fill 3
bx              .byte ?
by              .byte ?
bw              .byte ?
bh              .byte ?
bpen            .byte ?
bcol            .byte ?
bx1             .byte ?
by1             .byte ?
cr              .byte ?
cr0             .byte ?
cr1             .byte ?
cc              .byte ?
cc0             .byte ?
cc1             .byte ?
ly0             .byte ?
ly1             .byte ?
mask            .byte ?
nmask           .byte ?
pat             .byte ?
pres            .byte ?
clip_top        .byte ?
soft            .byte ?
best_d          .byte ?
best_s          .byte ?

;; --- the cat ---
cat_x           .byte ?
cat_xf          .byte ?
cat_y           .byte ?
cat_yf          .byte ?
cat_vy          .word ?
cat_h           .byte ?
cat_frame       .byte ?
cat_state       .byte ?
cat_stun        .byte ?
cat_anim        .byte ?
cat_moved       .byte ?
cat_invul       .byte ?
cat_ofeet       .byte ?
cat_nfeet       .byte ?
step            .word ?
best_top        .byte ?
plat_x0         .byte ?
plat_x1         .byte ?
plat_top        .byte ?
box_x           .byte ?
box_y           .byte ?
box_w           .byte ?
box_h           .byte ?

;; --- controls ---
ctl_scan        .byte ?
ctl_now         .byte ?
ctl_pressed     .byte ?
zp_end
        .endv
        .cerror zp_end > IRQ_TRAMPOLINE, "zero page is full"

        .virtual WORK
ptab            .fill 256       ; page aligned: which slots a byte shows

;; --- the display list and the shadow sprite registers (irq.s) ---
dl_idx          .byte ?
dl_count        .byte ?
dl_line         .fill 4
dl_d011         .fill 4
dl_d016         .fill 4
dl_d018         .fill 4
dl_shk          .fill 4
border_col      .byte ?
bg_col          .byte ?
spr_xlo         .fill 8
spr_y           .fill 8
spr_col         .fill 8
spr_ptr         .fill 8
spr_msb         .byte ?
spr_en          .byte ?
spr_n           .byte ?
spr_px          .byte ?
spr_py          .byte ?
spr_grey        .byte ?

;; --- sound ---
sfx_len         .byte ?
sfx_idx         .byte ?
sfx_cur_wave    .byte ?
mus_on          .byte ?
mus_tick        .byte ?
mus_p_lo        .fill 2
mus_p_hi        .fill 2
mus_lines       .fill 2
mus_gate        .fill 2

;; --- pictures and saved cells (video.s) ---
pic_w           .byte ?
pic_h           .byte ?
pic_x           .byte ?
pic_y           .byte ?
pic_i           .byte ?
run_x           .byte ?
run_pen         .byte ?
sv_cc           .byte ?
sv_cr           .byte ?
sv_nc           .byte ?
sv_nr           .byte ?
sv_dir          .byte ?
sv_r            .byte ?
sv_rn           .byte ?
sv_c            .byte ?
sv_cn           .byte ?
clash_count     .word ?
soft_count      .word ?

;; --- text ---
lang            .byte ?
txt_col         .byte ?
txt_row         .byte ?
txt_sx          .byte ?
txt_sy          .byte ?
txt_x           .byte ?
txt_y           .byte ?
txt_pen         .byte ?
txt_n           .byte ?
txt_cx          .byte ?
txt_cy          .byte ?
txt_gr          .byte ?
txt_gc          .byte ?
txt_rs          .byte ?
txt_bits        .byte ?

;; --- the difficulty: four bytes, in diff_tab's order ---
difficulty      .byte ?
walk_period     .byte ?
fly_period      .byte ?
stun_time       .byte ?
start_lives     .byte ?

;; --- the game ---
score           .fill 3         ; packed BCD, most significant first
game_over       .byte ?
cat_lives       .byte ?
cat_startx      .byte ?
cat_starty      .byte ?
cur_room        .byte ?
room_name       .byte ?
cur_nsaus       .byte ?
exit_px         .byte ?         ; these eight in room record order
exit_py         .byte ?
exit_x          .byte ?
exit_y          .byte ?
exit_w          .byte ?
exit_h          .byte ?
exit_shut       .byte ?
exit_open       .byte ?
milk_x          .byte ?
milk_y          .byte ?
room_light      .byte ?
room_floor      .byte ?
level_done      .byte ?
sausages_got    .byte ?
shake_timer     .byte ?
milk_flash      .byte ?
hud_dirty       .byte ?
prop_id         .byte ?
prop_x          .byte ?
prop_y          .byte ?
plat_i          .byte ?

;; --- pickups ---
pick_alive      .fill 7
pick_i          .byte ?
pk_x            .byte ?
pk_y            .byte ?
er_cc           .byte ?
er_cc1          .byte ?
er_cr           .byte ?
er_cr1          .byte ?
er_i            .byte ?

;; --- enemies, struct of arrays ---
en_type         .fill 3
en_x            .fill 3
en_y            .fill 3
en_dx           .fill 3
en_x0           .fill 3
en_x1           .fill 3
en_base         .fill 3
en_phase        .fill 3
en_stun         .fill 3
en_tick         .fill 3
en_i            .byte ?

;; --- scripted input ---
script_frame    .word ?
is_ntsc         .byte ?
ntsc_tick       .byte ?
ntsc_sfx        .byte ?
prof_t          .word ?
prof_s          .word ?
prof_max        .word ?
prof_room       .byte ?
prof_load       .byte ?
prof_load_t     .byte ?

PICK_BUFS       .fill 7*6*10      ; what each pickup is standing in front of
work_end
        .endv
        .cerror work_end > WORK_END, "the workspace runs into I/O"
