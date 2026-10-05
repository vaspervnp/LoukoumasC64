;; ===========================================================================
;; fastload.s - load the disc's files through code of our own in the 1541.
;;
;; The KERNAL moves a byte over the serial bus with a handshake per bit, about
;; 400 bytes a second. This uploads a program to the drive (M-W, M-E) that
;; finds each file in the directory itself, reads it a sector at a time
;; through the drive's job queue, and sends each sector two bits at a time on
;; CLK and DATA - about ten times faster.
;;
;; The drive is given the list of files once (drv_names) and sends them one
;; after the other; the C64 takes each with fast_get when it is ready for it,
;; and the drive waits as long as that takes. After the last it resets, and
;; the bus is the DOS's again.
;;
;; The protocol is clocked by the C64, on ATN:
;;
;;   * The drive holds CLK low while it reads a sector (busy), and when the
;;     sector is in its buffer it releases CLK and pulls DATA (ready). Neither
;;     is what an idle DOS leaves on the bus.
;;   * The C64 then toggles ATN 1024 times. After each toggle the drive puts
;;     the next two bits of the sector on the lines - bit 0 on CLK, bit 1 on
;;     DATA, low bits of each byte first - and the C64 reads them FAST_WAIT
;;     cycles later. The drive answers within 13 cycles and is always waiting
;;     by the time the next toggle comes, and nothing interrupts it; the C64
;;     can only be late (a badline - the splash is on screen), and late is
;;     harmless. So neither side counts cycles to stay in step.
;;   * One more toggle ends the sector: the drive goes busy, the C64 lets ATN
;;     go and copies the sector out. A sector whose link track is 0 is a
;;     file's last.
;;
;; ATN is not just a wire on a 1541: the drive pulls DATA low in hardware
;; while ATN is asserted and its ATNA bit ($1800 bit 4) is not, and raises an
;; interrupt on every ATN edge. So the drive writes ATNA equal to ATN with
;; every value it puts on the bus, and turns the ATN interrupt off first.
;;
;; A sector takes about 45 ms to send and copy. tools/d64.py writes the
;; files this loads with an interleave of 12 rather than the DOS's 10, so the
;; drive's next read job is in well before that sector comes round, rather
;; than a whole turn later (tools/mkdisk64.py has the numbers).
;;
;; Only a 1541 (or a 1541-II) runs this: fast_load asks the drive for the
;; "54" of "1541" in its ROM first, and returns with carry set when it is not
;; there - an SD2IEC, a 1581 - so the loader falls back to the KERNAL.
;; ===========================================================================

OPEN            = $ffc0
CLOSE           = $ffc3
CHKIN           = $ffc6
CHKOUT          = $ffc9
CLRCHN          = $ffcc
CHRIN           = $ffcf
CHROUT          = $ffd2

DRIVE_CODE      = $0500         ; buffer 2 in the 1541
SECBUF          = $c300         ; a sector, on the C64

;; C64 $DD00: bank 3 is %00 in bits 0-1; bit 3 ATN out; bits 6, 7 CLK and
;; DATA in. Writing 0 releases every line.
ATN_ON          = $08
ATN_OFF         = $00

;; From the toggle to the read: ldx, FAST_WAIT times round a 5-cycle loop, and
;; the read's own four cycles - 25 cycles for 4, against the drive's 13.
FAST_WAIT       = 4

;; ---------------------------------------------------------------------------
;; fast_load - upload the drive code and start it. Carry set: not a 1541,
;; nothing done, the command channel closed again; load the slow way.
;; ---------------------------------------------------------------------------
fast_load
        lda #0                  ; the command channel: OPEN 15,dev,15,""
        jsr SETNAM
        lda #15
        ldx fl_dev
        ldy #15
        jsr SETLFS
        jsr OPEN
        bcs _not

        ldx #15                 ; M-R $E5C5, two bytes: "54" on a 1541
        jsr CHKOUT
        bcs _close
        ldx #0
-       lda mr_cmd,x
        jsr CHROUT
        inx
        cpx #mr_cmd_end-mr_cmd
        bne -
        jsr CLRCHN
        ldx #15
        jsr CHKIN
        jsr CHRIN
        sta fl_tmp
        jsr CHRIN
        sta fl_tmp+1
        jsr CLRCHN
        lda fl_tmp
        cmp #"5"
        bne _close
        lda fl_tmp+1
        cmp #"4"
        bne _close

        lda #<drv_image         ; the drive code, 32 bytes an M-W
        sta fl_p
        lda #>drv_image
        sta fl_p+1
        lda #<DRIVE_CODE
        sta fl_at
        lda #>DRIVE_CODE
        sta fl_at+1
_upload ldx #15
        jsr CHKOUT
        ldx #0
-       lda mw_cmd,x
        jsr CHROUT
        inx
        cpx #mw_cmd_end-mw_cmd
        bne -
        lda fl_at
        jsr CHROUT
        lda fl_at+1
        jsr CHROUT
        lda #32
        jsr CHROUT
        ldy #0
-       lda (fl_p),y
        jsr CHROUT
        iny
        cpy #32
        bne -
        jsr CLRCHN
        lda fl_p
        clc
        adc #32
        sta fl_p
        bcc +
        inc fl_p+1
+       lda fl_at
        clc
        adc #32
        sta fl_at
        bcc +
        inc fl_at+1
+       lda fl_p
        cmp #<drv_image_end
        lda fl_p+1
        sbc #>drv_image_end
        bcc _upload

        ldx #15                 ; M-E: and from here the drive is ours
        jsr CHKOUT
        ldx #0
-       lda me_cmd,x
        jsr CHROUT
        inx
        cpx #me_cmd_end-me_cmd
        bne -
        jsr CLRCHN
-       lda $dd00               ; until it says busy: CLK low, DATA high
        and #$c0
        cmp #$80
        bne -
        clc
        rts

_close  lda #15
        jsr CLOSE
_not    sec
        rts

mr_cmd  .text "m-r"
        .byte <$e5c5, >$e5c5, 2
mr_cmd_end
mw_cmd  .text "m-w"
mw_cmd_end
me_cmd  .text "m-e"
        .byte <DRIVE_CODE, >DRIVE_CODE
me_cmd_end

;; ---------------------------------------------------------------------------
;; fast_get - the drive's next file, to its load address. Interrupts off: the
;; KERNAL's would only make the C64 later, which is harmless, but it would
;; also be the KERNAL's, and the ROMs may be out.
;; ---------------------------------------------------------------------------
fast_get
        sei
        lda #1
        sta fl_first
_sector
-       lda $dd00               ; ready: CLK high, DATA low
        and #$c0
        cmp #$40
        bne -
        ldy #0
_byte   lda #ATN_ON             ; bits 0-1
        sta $dd00
        ldx #FAST_WAIT
-       dex
        bne -
        lda $dd00
        and #$c0
        lsr
        lsr
        sta fl_acc
        lda #ATN_OFF            ; bits 2-3
        sta $dd00
        ldx #FAST_WAIT
-       dex
        bne -
        lda $dd00
        and #$c0
        ora fl_acc
        lsr
        lsr
        sta fl_acc
        lda #ATN_ON             ; bits 4-5
        sta $dd00
        ldx #FAST_WAIT
-       dex
        bne -
        lda $dd00
        and #$c0
        ora fl_acc
        lsr
        lsr
        sta fl_acc
        lda #ATN_OFF            ; bits 6-7
        sta $dd00
        ldx #FAST_WAIT
-       dex
        bne -
        lda $dd00
        and #$c0
        ora fl_acc
        eor #$ff                ; a line the drive pulled reads 0
        sta SECBUF,y
        iny
        bne _byte

        lda #ATN_ON             ; the end of the sector: the drive goes busy
        sta $dd00
-       lda $dd00
        and #$c0
        cmp #$80
        bne -
        lda #ATN_OFF
        sta $dd00

        lda #0                  ; the bytes to copy end at the link byte + 1 in
        ldy SECBUF              ; the last sector, at the end in the others
        bne +
        ldy SECBUF+1
        iny
        tya
+       sta fl_end
        ldx #2                  ; and start at 2 - or at 4 in a file's first,
        lda fl_first            ; after its load address
        beq _copy
        lda SECBUF+2
        sta fl_p
        lda SECBUF+3
        sta fl_p+1
        lda #0
        sta fl_first
        ldx #4
        lda SECBUF
        bne _copy
        cpx fl_end              ; one sector, and nothing in it: not there
        bcc _copy
        jmp failed

_copy   ldy #0
-       lda SECBUF,x
        sta (fl_p),y
        iny
        inx
        cpx fl_end
        bne -
        tya
        clc
        adc fl_p
        sta fl_p
        bcc +
        inc fl_p+1
+       lda SECBUF
        beq +
        jmp _sector
+       rts

;; ===========================================================================
;; The drive's side, assembled to run at $0500 in the 1541.
;;
;; Zero page there is the DOS's: $00 is buffer 0's job, $06/$07 its track and
;; sector, and buffer 0 is $0300. $1800 is the serial port: bit 1 DATA out,
;; bit 3 CLK out, bit 4 ATNA, bit 7 ATN in. Writing a 1 pulls a line low.
;; ===========================================================================
drv_image
        .logical DRIVE_CODE
drv_start
        sei
        lda #$02                ; no interrupt from ATN: we use it as a clock
        sta $180e
        lda #$08                ; busy
        sta $1800
-       bit $1800               ; until the C64 has let ATN go after M-E
        bmi -
        lda #0
        sta drv_nofs

drv_find
        lda #18                 ; the directory: 18/1 on
        sta $06
        lda #1
        sta $07
_dir    jsr drv_read
        ldx #0
_entry  stx drv_ent
        lda $0302,x
        cmp #$82                ; a closed PRG
        bne _next
        ldy drv_nofs
-       lda $0305,x
        cmp drv_names,y
        bne _next
        inx
        iny
        tya
        and #15
        bne -
        ldx drv_ent             ; found: its first track and sector
        lda $0303,x
        sta $06
        lda $0304,x
        sta $07
        jmp drv_file
_next   lda drv_ent
        clc
        adc #32
        tax
        bne _entry
        lda $0300               ; the next directory sector, if there is one
        beq drv_missing
        sta $06
        lda $0301
        sta $07
        jmp _dir

drv_missing                     ; not there: one empty, last sector
        lda #0
        sta $0300
        lda #1
        sta $0301
        jmp drv_send

drv_file
        jsr drv_read
drv_send
-       bit $1800               ; ATN let go, then ready
        bmi -
        lda #$02
        sta $1800
        ldx #0
_byte   lda $0300,x             ; four times two bits, low first
        sta drv_cur
        and #3
        tay
        lda drv_enc_a,y
-       bit $1800
        bpl -
        sta $1800
        lda drv_cur
        lsr
        lsr
        sta drv_cur
        and #3
        tay
        lda drv_enc_r,y
-       bit $1800
        bmi -
        sta $1800
        lda drv_cur
        lsr
        lsr
        sta drv_cur
        and #3
        tay
        lda drv_enc_a,y
-       bit $1800
        bpl -
        sta $1800
        lda drv_cur
        lsr
        lsr
        tay
        lda drv_enc_r,y
-       bit $1800
        bmi -
        sta $1800
        inx
        bne _byte
-       bit $1800               ; the end of the sector
        bpl -
        lda #$18                ; busy, ATNA with the asserted ATN
        sta $1800
-       bit $1800               ; and when the C64 has seen it, busy
        bmi -
        lda #$08
        sta $1800
        lda $0300
        beq _eof
        sta $06
        lda $0301
        sta $07
        jmp drv_file

_eof    lda drv_nofs            ; the next file, if there is one
        clc
        adc #16
        sta drv_nofs
        cmp #drv_names_end-drv_names
        bne drv_find
        lda #0                  ; no more: the bus back as we found it, and
        sta $1800               ; the DOS started again from the top
        jmp ($fffc)

drv_read
        lda #$80                ; READ, buffer 0, $06/$07
        sta $00
        cli                     ; the job runs in the drive's interrupt
-       lda $00
        bmi -
        sei
        cmp #$01                ; OK
        bne drv_read
        rts

;; Two bits to the port: bit 0 -> CLK ($08), bit 1 -> DATA ($02), and ATNA
;; ($10) equal to ATN: asserted for the first and third pair, not the others.
drv_enc_a       .byte $10, $18, $12, $1a
drv_enc_r       .byte $00, $08, $02, $0a
drv_cur         .byte 0
drv_ent         .byte 0
drv_nofs        .byte 0

;; The files, in the order fast_get takes them: names padded with shifted
;; spaces as the directory has them.
drv_names
        .for n in FILE_NAMES
        .text n
        .fill 16-len(n), $a0
        .next
drv_names_end
        .cerror * > $0700, "the drive code is more than two buffers"
        .endlogical
drv_image_end
