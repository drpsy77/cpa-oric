; =====================================================================
;  disk.s — pilote du contrôleur Microdisc (WD1793)
;  Compatible Microdisc d'origine, Cumulus et LOCI.
;
;  Interface (secteurs logiques de 256 octets, LSN 0..NSECT-1) :
;     dsk_lsn  : numéro de secteur logique (2 octets)
;     dsk_buf  : adresse du tampon de 256 octets
;     disk_read / disk_write -> A=0 si OK, A=1 si erreur (Z positionné)
;  Correspondance LSN -> piste physique :
;     piste logique = LSN / 17 ; cylindre = piste/2 ; face = piste and 1
;     secteur = LSN mod 17 + 1
; =====================================================================

CMD_RESTORE = $0B       ; retour piste 0, tête chargée, pas de 30 ms
CMD_SEEK    = $1F       ; positionnement avec vérification
CMD_READ    = $80
CMD_WRITE   = $A0
ST_ERRMASK  = $5C       ; protégé en écriture, non trouvé, CRC, perte de données

; fdc_issue : envoie la commande A puis attend la fin (commandes de type I)
fdc_issue
        sta FDC_CMD
        jsr fdc_delay
fdc_wait
        lda FDC_CMD
        lsr                     ; bit 0 = occupé
        bcs fdc_wait
        rts

fdc_delay
        ldy #8
fdd     dey
        bne fdd
        rts

; disk_home : ramène la tête en piste 0
disk_home
        php
        sei
        jsr fdc_wait
        lda #MD_BASE
        sta MD_CTRL
        lda #CMD_RESTORE
        jsr fdc_issue
        plp
        lda #0
        rts

; lsn_to_chs : dsk_lsn -> dsk_cyl, dsk_side, dsk_sec. C=1 si hors disque.
lsn_to_chs
.(
        lda dsk_lsn+1
        cmp #>NSECT
        bcc ok
        bne bad
        lda dsk_lsn
        cmp #<NSECT
        bcs bad
ok      lda dsk_lsn
        sta fs_t0
        lda dsk_lsn+1
        sta fs_t1
        ldx #0                  ; piste logique
loop    lda fs_t0
        sec
        sbc #SPT
        tay
        lda fs_t1
        sbc #0
        bcc done
        sta fs_t1
        sty fs_t0
        inx
        bne loop
done    lda fs_t0
        clc
        adc #1
        sta dsk_sec
        txa
        lsr
        sta dsk_cyl
        lda #0
        rol
        sta dsk_side
        clc
        rts
bad     sec
        rts
.)

disk_read
        lda #CMD_READ
        .byt $2C                ; BIT abs : saute l'instruction suivante
disk_write
        lda #CMD_WRITE
        sta dsk_op
.(
        php
        sei                     ; aucune interruption pendant le transfert
        jsr lsn_to_chs
        bcc chs_ok
        jmp fail
chs_ok  lda #4
        sta dsk_try
retry
        ; face et lecteur
        lda dsk_side
        asl
        asl
        asl
        asl
        ora #MD_BASE
        sta MD_CTRL
        ; positionnement si nécessaire
        jsr fdc_wait
        lda dsk_cyl
        cmp FDC_TRK
        beq trk_ok
        sta FDC_DATA
        lda #CMD_SEEK
        jsr fdc_issue
        and #$08                ; A = état décalé : bit 4 (erreur de seek) -> bit 3
        bne error
trk_ok
        lda dsk_sec
        sta FDC_SEC
        lda dsk_buf
        sta ZP_DSK
        lda dsk_buf+1
        sta ZP_DSK+1
        ldy #0
        lda dsk_op
        sta FDC_CMD
        cmp #CMD_WRITE
        beq wr

        ; --- lecture : ~20 cycles max entre DRQ et la lecture (32 µs dispo)
rd      lda MD_DRQ
        bmi rchk
        lda FDC_DATA
        sta (ZP_DSK),y
        iny
        bne rd
        beq fin
rchk    lda MD_CTRL             ; /INTRQ : commande terminée prématurément ?
        bmi rd
        bpl fin

        ; --- écriture
wr      lda MD_DRQ
        bmi wchk
        lda (ZP_DSK),y
        sta FDC_DATA
        iny
        bne wr
        beq fin
wchk    lda MD_CTRL
        bmi wr

fin     jsr fdc_wait
        lda FDC_CMD
        and #ST_ERRMASK
        bne error
        plp
        lda #0
        rts

error   dec dsk_try
        beq fail
        lda #CMD_RESTORE        ; on recalibre puis on recommence
        jsr fdc_issue
        jmp retry

fail    plp
        lda #1
        rts
.)

; ---------------------------------------------------------------------
; Points d'entrée BIOS (table en $C018-$C02A)
; ---------------------------------------------------------------------
bios_settrk
        lda #0
        rts
bios_setsec
        sta dsk_lsn
        sty dsk_lsn+1
        rts
bios_dskbuf
        sta dsk_buf
        sty dsk_buf+1
        rts
bios_read
        jsr bios_sync
        jmp disk_read
bios_write
        jsr bios_sync
        jmp disk_write
; le cache du BDOS est vidé puis oublié avant un accès direct
bios_sync
        lda dsk_lsn
        pha
        lda dsk_lsn+1
        pha
        lda dsk_buf
        pha
        lda dsk_buf+1
        pha
        jsr flush
        lda #0
        sta buf_ok
        pla
        sta dsk_buf+1
        pla
        sta dsk_buf
        pla
        sta dsk_lsn+1
        pla
        sta dsk_lsn
        rts
