; =====================================================================
;  disk.s — pilote du contrôleur Microdisc (WD1793)
;  Compatible Microdisc d'origine, Cumulus et LOCI.
;
;  Interface (secteurs logiques de 256 octets, LSN 0..NSECT-1) :
;     dsk_lsn  : numéro de secteur logique (2 octets)
;     dsk_buf  : adresse du tampon de 256 octets
;     buf_drv  : lecteur (0-3)
;     disk_read / disk_write -> A=0 si OK, A=1 si erreur (Z positionné)
;  Le WD1793 n'a qu'un registre de piste pour les 4 lecteurs : il est
;  rangé dans dsk_trk au changement de lecteur (drv_sel). Un lecteur
;  vide ou absent ne répond jamais : les attentes ont un délai maximal
;  (~2,9 s pour le premier octet d'un secteur, ~3 s pour un déplacement),
;  puis la commande est interrompue (Force Interrupt) et l'accès échoue.
;  Le premier octet d'un vrai Microdisc peut tarder ~1 s : après ~3 s
;  sans commande, le WD1793 lève la tête, qui commande aussi le moteur ;
;  le recharger et relancer le moteur prend ce temps (0,7 s ne suffisait
;  pas : « BDOS: disk I/O error » au premier accès après une pause, vu
;  dans Clock Signal). Sans effet sur le LOCI et Oricutron, qui répondent
;  aussitôt ; un lecteur absent échoue avant, au déplacement de tête.
;  LOCI : une commande pour un lecteur sans image n'y est jamais terminée,
;  et son contrôleur ne répond plus à rien (Force Interrupt compris)
;  jusqu'au redémarrage du LOCI (loci-firmware, src/mia/oric/dsk.c).
;  Avant de passer sur un autre lecteur, loci_abs lit donc dans la XRAM
;  du LOCI la liste des lecteurs montés : un lecteur vide est refusé
;  sans qu'aucune commande ne lui soit envoyée.
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
; fdc_wait : attend que le contrôleur soit libre ; A = état / 2. Après
;   ~3 s : commande interrompue, A = $FF et plus de nouvel essai
fdc_wait
.(
        ldx #0
        ldy #0
        lda #4
        sta dsk_to
loop    lda FDC_CMD
        lsr                     ; bit 0 = occupé
        bcc fw_r
        dey
        bne loop
        dex
        bne loop
        dec dsk_to
        bne loop
.)
; fdc_abort : interrompt la commande en cours ; plus de nouvel essai
fdc_abort
        lda #$D0                ; Force Interrupt
        sta FDC_CMD
        lda #1
        sta dsk_try
        lda #$FF
fw_r    rts

fdc_delay
        ldy #8
fdd     dey
        bne fdd
        rts

; disk_home : ramène la tête du lecteur buf_drv en piste 0
disk_home
        jsr loci_abs
        bcs dh_no
        php
        sei
        jsr md_sel
        lda #CMD_RESTORE
        jsr fdc_issue
        plp
        lda #0
        rts
dh_no   lda #1
        rts

; loci_abs : C=1 si le lecteur buf_drv n'a pas d'image sur le LOCI.
;   Rien à faire si c'est le lecteur en service (phy_drv), ou sans LOCI
;   ("L" en $0319 ; sans LOCI, $03A8-$03AB sont des registres du VIA :
;   on n'y touche pas). Le menu du LOCI range sa configuration dans la
;   XRAM ("LOCI" en $8000, octet mounts en $800B, mis à jour à chaque
;   éjection). Signature absente ou octet invraisemblable (A: non monté,
;   bits 6-7 non nuls : autre version du menu) : on laisse passer.
loci_abs
.(
        lda buf_drv
        cmp phy_drv
        beq ok                  ; lecteur déjà en service
        lda LOCI_ID
        cmp #"L"
        bne ok                  ; pas de LOCI
        lda #1
        sta MIA_STEP1
        lda #>LOCI_CFG
        sta MIA_ADDR1+1
        ldx #<LOCI_CFG
        stx MIA_ADDR1
sig     lda MIA_RW1             ; octet, puis adresse suivante
        cmp loci_sig,x
        bne ok
        inx
        cpx #4
        bne sig
        lda #<LOCI_MNT
        sta MIA_ADDR1
        lda MIA_RW1
        tay
        and #$C1
        cmp #1
        bne ok                  ; invraisemblable : on laisse passer
        tya
        ldx buf_drv
        and bitmask,x
        bne ok                  ; monté
        sec
        rts
ok      clc
        rts
.)
loci_sig .asc "LOCI"

; md_sel : lecteur buf_drv et face dsk_side, contrôleur libre, registre
;   de piste du lecteur (gardé dans dsk_trk au changement). C=1 si le
;   lecteur a changé : l'appelant fait alors toujours un déplacement de
;   tête, car Oricutron (et peut-être d'autres émulations) n'a qu'une
;   position de tête pour tous les lecteurs
md_sel
.(
        lda buf_drv
        asl
        ora dsk_side
        asl
        asl
        asl
        asl
        ora #MD_BASE
        sta MD_CTRL
        jsr fdc_wait
        lda buf_drv
        cmp phy_drv
        clc
        beq r
        ldx phy_drv
        lda FDC_TRK
        sta dsk_trk,x
        ldx buf_drv
        lda dsk_trk,x
        sta FDC_TRK
        stx phy_drv
        sec                     ; C=1 : lecteur changé
r       rts
.)

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
        bcs fl
        jsr loci_abs            ; LOCI : lecteur sans image refusé d'emblée
        bcc chs_ok
fl      jmp fail
chs_ok  lda #4
        sta dsk_try
retry
        jsr md_sel              ; lecteur, face ; positionnement si nécessaire
        lda dsk_cyl
        bcs seek                ; (lecteur changé : toujours)
        cmp FDC_TRK
        beq trk_ok
seek    sta FDC_DATA
        lda #CMD_SEEK
        jsr fdc_issue
        and #$08                ; A = état décalé : bit 4 (erreur de seek) -> bit 3
        beq trk_ok
        jmp error
trk_ok
        lda dsk_sec
        sta FDC_SEC
        lda dsk_buf
        sta ZP_DSK
        lda dsk_buf+1
        sta ZP_DSK+1
        ldy #0
        ldx #0
        stx dsk_to
        lda #4                  ; 4 x 256 x ~2,8 ms : ~2,9 s
        sta dsk_to2
        lda dsk_op
        sta FDC_CMD
        cmp #CMD_WRITE
        beq ww
        ; premier octet : attente limitée (~2,9 s), fin anticipée (INTRQ)
        ; vue toutes les 256 boucles ; ~18 cycles entre DRQ et la lecture
rw      lda MD_DRQ
        bpl rd1
        dex
        bne rw
        lda MD_CTRL
        bpl fin
        dec dsk_to
        bne rw
        dec dsk_to2
        bne rw
        beq tmo

        ; --- lecture : ~20 cycles max entre DRQ et la lecture (32 µs dispo)
rd      lda MD_DRQ
        bmi rchk
rd1     lda FDC_DATA
        sta (ZP_DSK),y
        iny
        bne rd
        beq fin
rchk    lda MD_CTRL             ; /INTRQ : commande terminée prématurément ?
        bmi rd
        bpl fin

        ; --- écriture (premier octet : même attente que la lecture)
ww      lda MD_DRQ
        bpl wr1
        dex
        bne ww
        lda MD_CTRL
        bpl fin
        dec dsk_to
        bne ww
        dec dsk_to2
        bne ww
tmo     jsr fdc_abort
        jmp error
wr      lda MD_DRQ
        bmi wchk
wr1     lda (ZP_DSK),y
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
; (le cache vidé, buf_drv reçoit le lecteur choisi par SELDSK)
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
        lda act_drv
        sta buf_drv
        pla
        sta dsk_buf+1
        pla
        sta dsk_buf
        pla
        sta dsk_lsn+1
        pla
        sta dsk_lsn
        rts
