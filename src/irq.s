;; ===========================================================================
;; irq.s - the raster interrupts: the screen splits, the frame tick, and
;; everything that has to be written to the chips once a frame.
;;
;; The screen is a short display list: up to four entries of (raster line,
;; $D011, $D016, $D018), walked in a ring. Entry 0 is always in the bottom
;; border, and it is the frame: after its mode registers it copies the
;; shadow sprite registers into the VIC, steps the sound and bumps
;; frame_count. The others are mode splits and do nothing else.
;;
;;   in play     251: hires text (the HUD)     66: multicolour bitmap
;;   title       251: multicolour bitmap      FOOT: hires text (the footer)
;;
;; The logic never writes a sprite register itself. It fills the shadows and
;; the frame entry copies them while the beam is in the border, so a sprite
;; never moves half way down the picture and tears.
;;
;; No KERNAL: $01 = $35 maps RAM over both ROMs and leaves I/O, so the
;; hardware vectors at $FFFA-$FFFF are ours and must be written before CLI.
;; ===========================================================================

DL_MAX          = 4

;; ---------------------------------------------------------------------------
;; machine_init - ROMs off, CIA interrupts off, VIC bank 1, vectors in place.
;; ---------------------------------------------------------------------------
machine_init
        sei
        cld
        lda #$35                ; RAM everywhere but I/O
        sta $01

        lda #$7f                ; no CIA interrupts: the raster is the clock
        sta $dc0d
        sta $dd0d
        lda $dc0d               ; and nothing left pending from the KERNAL
        lda $dd0d

        lda #$4c                ; JMP irq_handler, in zero page, so the
        sta IRQ_TRAMPOLINE      ; vector's high byte - which is also the
        lda #<irq_handler       ; byte the VIC shows on an idle line - is 0
        sta IRQ_TRAMPOLINE+1
        lda #>irq_handler
        sta IRQ_TRAMPOLINE+2
        lda #<IRQ_TRAMPOLINE    ; the vectors, before anything can interrupt
        sta $fffe
        lda #0
        sta $ffff
        lda #<nmi_handler       ; RESTORE goes nowhere
        sta $fffa
        lda #>nmi_handler
        sta $fffb

        ;; The sprites and the font travel in the file behind the tables and
        ;; go to where the VIC can see them. The sprite blocks live under the
        ;; I/O, so the I/O is banked out while they are written.
        lda #$34
        sta $01
        lda #<sprite_store
        sta ptr
        lda #>sprite_store
        sta ptr+1
        lda #<SPRITE_MEM
        sta sptr
        lda #>SPRITE_MEM
        sta sptr+1
        ldx #>(sprite_blocks_end-sprite_blocks+255)
        jsr copy_pages
        lda #0                  ; the whole charset slot: a screen code past
        tay                     ; the font is read on the split line, and its
-       sta CHARSET,y           ; last row has to be blank like theirs
        sta CHARSET+$100,y
        sta CHARSET+$200,y
        sta CHARSET+$300,y
        sta CHARSET+$400,y
        sta CHARSET+$500,y
        sta CHARSET+$600,y
        sta CHARSET+$700,y
        iny
        bne -
        lda #<font_store
        sta ptr
        lda #>font_store
        sta ptr+1
        lda #<CHARSET
        sta sptr
        lda #>CHARSET
        sta sptr+1
        ldx #>(font_end-font+255)
        jsr copy_pages
        lda #$35
        sta $01

        lda $dd02               ; bank select bits are outputs
        ora #%00000011
        sta $dd02
        lda $dd00
        and #%11111100
        ora #DD00_BANK
        sta $dd00

        lda #0
        sta $d015               ; no sprites until something fills the shadows
        sta $d017               ; no expansion
        sta $d01d
        sta $d01b               ; sprites in front of the picture
        sta screen_on
        sta frame_count
        sta shake_y
        sta spr_en
        ldx #7                  ; shadows that point nowhere visible
-       sta spr_xlo,x
        sta spr_y,x
        sta spr_ptr,x
        sta spr_col,x
        dex
        bpl -
        sta spr_msb
        lda #$ff
        sta $d01c               ; every sprite multicolour
        lda #0
        sta $d025               ; the shared pair: black outlines
        lda #1
        sta $d026               ; and white eyes
        lda #0
        sta $d020
        sta $d021
        sta border_col
        sta bg_col
        rts

;; copy_pages - X pages from (ptr) to (sptr).
copy_pages
        ldy #0
-       lda (ptr),y
        sta (sptr),y
        iny
        bne -
        inc ptr+1
        inc sptr+1
        dex
        bne -
        rts

;; ---------------------------------------------------------------------------
;; detect_ntsc - is_ntsc = 1 on a 60 Hz machine (loukc64.md 11).
;;
;; A PAL frame is 312 lines, so the raster counter's low byte reaches $37
;; while bit 8 is set; NTSC's 263 (or 262) never get past $07. Two frames of
;; watching is enough. Interrupts are off: nothing is running yet.
;; ---------------------------------------------------------------------------
detect_ntsc
        lda #0
        sta tmp                 ; the highest line seen past 255
        ldx #0
        ldy #$c0                ; 48 K samples, about four frames
-       lda $d011
        bpl +
        lda $d012
        cmp tmp
        bcc +
        sta tmp
+       inx
        bne -
        iny
        bne -
        lda tmp
        cmp #$20
        lda #0
        bcs +
        lda #1
+       sta is_ntsc
        rts

;; ---------------------------------------------------------------------------
;; irq_start - with a display list in place, turn the raster interrupt on.
;; ---------------------------------------------------------------------------
irq_start
        sei
        lda #0
        sta dl_idx
        lda dl_line
        sta $d012
        lda #D011_TEXT          ; raster bit 8 clear: every line we use is < 256
        and #$7f
        sta $d011
        lda #$01
        sta $d01a               ; raster interrupts only
        sta $d019               ; and none pending
        cli
        rts

;; ---------------------------------------------------------------------------
;; dl_game / dl_title - load one of the two display lists. Interrupts are off
;; while the ring is rewritten so the handler never sees half of each.
;; ---------------------------------------------------------------------------
dl_game
        ldx #dl_game_tab-dl_tables
        jmp dl_load
dl_title
        ldx #dl_title_tab-dl_tables
dl_load
        sei
        ldy #0
-       lda dl_tables,x
        sta dl_line,y
        lda dl_tables+1,x
        sta dl_d011,y
        lda dl_tables+2,x
        sta dl_d016,y
        lda dl_tables+3,x
        sta dl_d018,y
        lda dl_tables+4,x
        sta dl_shk,y
        txa
        clc
        adc #5
        tax
        iny
        cpy #2
        bne -
        sty dl_count
        lda #0
        sta dl_idx
        lda dl_line
        sec
        sbc #1
        sta $d012
        cli
        rts

;; line, $D011, $D016, $D018, whether the shake applies
dl_tables
dl_game_tab
        .byte FRAME_IRQ_LINE, D011_TEXT, D016_TEXT, D018_TEXT, 0
        .byte HUD_SPLIT_LINE, D011_BMP,  D016_BMP,  D018_BMP,  1
dl_title_tab
        .byte FRAME_IRQ_LINE,  D011_BMP,  D016_BMP,  D018_BMP,  0
        .byte FOOT_SPLIT_LINE, D011_TEXT, D016_TEXT, D018_TEXT, 0

;; ---------------------------------------------------------------------------
;; irq_handler
;;
;; The split writes have to be in before the next line, a badline that
;; fetches the next row's screen RAM. Taken from the interrupt on the split
;; line itself they finished about 66 cycles in - on time only just, and late
;; whenever sprites on that line took their cycles first: the first line of
;; the room under the HUD came out black. So the interrupt comes a line early,
;; the values are worked out, and the three writes go in back to back once
;; the split line begins, in its first 30 cycles whatever the sprites do.
;; ---------------------------------------------------------------------------
irq_handler
        pha
        txa
        pha
        tya
        pha
        cld                     ; the NMOS 6502 does not clear D on interrupt,
                                ; and the main loop does BCD arithmetic
        ;; Memory last, and the mode bits in the order that keeps every
        ;; half-state blank. The writes land on the split line while the beam
        ;; is drawing it, so between them the VIC shows a mix of two modes:
        ;;  - into the bitmap (HUD, line 66): multicolour first. Multicolour
        ;;    text shows the glyphs' 8th line, empty; then bitmap mode still
        ;;    pointed at the text screen reads its rows 8-15, empty in play;
        ;;    then the bitmap's own line, empty under the HUD (clip_top).
        ;;    Bitmap mode first showed hires bitmap for a moment, each cell in
        ;;    the colours of the HUD's screen codes.
        ;;  - into text (title footer): the mode first. Text mode still pointed
        ;;    at the bitmap reads glyph 0 from bitmap row 0, which the title
        ;;    leaves empty, because the screen codes are the colours of bitmap
        ;;    row 18 - 0. The other order showed the sprite blocks there.
        ldx dl_idx
        lda dl_d011,x
        ldy dl_shk,x
        beq +
        clc
        adc shake_y             ; YSCROLL 3 + 0..4: the picture slides down
+       ldy screen_on
        bne +
        and #%11101111          ; DEN off: the whole frame is border
+       and #$7f
        sta irq_d011
        ldy dl_line,x           ; now wait for the split line itself
-       cpy $d012
        beq +
        bcs -                   ; not there yet (and never wait if late)
+       and #$20                ; BMM: into the bitmap?
        beq _text
        lda dl_d016,x
        sta $d016
        lda irq_d011
        sta $d011
        jmp _mem
_text   lda irq_d011
        sta $d011
        lda dl_d016,x
        sta $d016
_mem    lda dl_d018,x
        sta $d018

        inx                     ; the next entry
        cpx dl_count
        bcc +
        ldx #0
+       stx dl_idx
        lda dl_line,x
        sec
        sbc #1                  ; a line early: see above
        sta $d012
        lda #$01
        sta $d019               ; acknowledged

        cpx #1                  ; was that entry 0, the frame?
        bne irq_done
        jsr frame_work

irq_done
        pla
        tay
        pla
        tax
        pla
nmi_handler
        rti

;; ---------------------------------------------------------------------------
;; frame_work - once a frame, in the bottom border: the shadows go to the
;; chips, the sound steps, and the main loop is told a frame has gone.
;; ---------------------------------------------------------------------------
frame_work
        ;; Only when they change: on a VIC-II 8565 (every C64C) a write to a
        ;; colour register shows one light grey pixel where the beam is - the
        ;; "grey dot" - and this would draw one in the border every frame.
        lda $d020               ; the top nibble reads back as ones
        and #$0f
        cmp border_col
        beq +
        lda border_col
        sta $d020
+       lda $d021
        and #$0f
        cmp bg_col
        beq +
        lda bg_col
        sta $d021
+
        ldx #7
-       lda spr_xlo,x
        ldy spr_reg,x
        sta $d000,y
        lda spr_y,x
        sta $d001,y
        lda spr_col,x
        sta $d027,x
        lda spr_ptr,x           ; the pointers sit at the end of screen RAM,
        sta TEXT_SCREEN+$3f8,x  ; and the VIC reads them from whichever screen
        sta BMP_SCREEN+$3f8,x   ; is current on the line - so both carry them
        dex
        bpl -
        lda spr_msb
        sta $d010
        lda spr_en
        sta $d015

        lda is_ntsc             ; at 60 Hz the effects skip a step in six,
        beq +                   ; so they last as long as they do at 50
        dec ntsc_sfx
        bne +
        lda #6
        sta ntsc_sfx
        jmp ++
+       jsr sfx_update
        jsr music_play
+       inc frame_count
        rts

spr_reg .byte 0, 2, 4, 6, 8, 10, 12, 14

;; ---------------------------------------------------------------------------
;; wait_frame - until the frame entry has run again.
;; ---------------------------------------------------------------------------
wait_frame
        lda frame_count
-       cmp frame_count
        beq -
        rts
