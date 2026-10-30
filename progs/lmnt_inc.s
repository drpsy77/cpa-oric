; =====================================================================
;  lmnt_inc.s — montage des images du LOCI (docs/usb.md § 2.1) : API
;  mount, umount, getcwd, configuration du menu du LOCI en XRAM (lecteurs
;  montés, noms des images), refus (signature, image déjà montée).
;  Inclus par USBMOUNT et CMDER avant loci.msg et loci_inc.s (lupc,
;  lp_last, apath) ; sans message à lui. Jamais assemblé seul.
;
;  Configuration du menu (loci-rom, persist.c), fenêtre 1 de la XRAM :
;    $8000 "LOCI" ; $8004 fdc_on, $8005 tap_on, $8006 bit_on, $8007
;    mou_on, $8008 b11_on, $8009 ser_on, $800A ald_on ; $800B mounts
;    (bit n : lecteur n, 4 cassette, 5 ROM) ; $810D + 35 x n : nom seul
;    de l'image du lecteur n (32 caractères au plus).
;  Un montage par l'API n'écrit rien en XRAM : mt_ les écrit comme le
;  menu, sinon CP/A refuserait le lecteur (loci_abs, src/disk.s).
; =====================================================================

MIA_RW1     = $03A8
MIA_STEP1   = $03A9
MIA_ADDR1   = $03AA
OP_GETCWD   = $88
OP_MOUNT    = $90
OP_UMOUNT   = $91
OP_BOOT     = $A0
X_FDC       = $04       ; octets de la configuration (bas de $80xx)
X_TAP       = $05
X_BIT       = $06
X_B11       = $08
X_ALD       = $0A
X_MNT       = $0B

; mt_xa : fenêtre 1 de la XRAM en $80A (A = octet bas), pas de 1
mt_xa
        sta MIA_ADDR1
        lda #$80
        sta MIA_ADDR1+1
        lda #1
        sta MIA_STEP1
        rts

; mt_ok : C=0 si la configuration du menu est en XRAM (« LOCI »)
mt_ok
.(
        lda #0
        jsr mt_xa
        ldx #0
l       lda MIA_RW1
        cmp mt_sig,x
        bne no
        inx
        cpx #4
        bne l
        clc
        rts
no      sec
        rts
.)
mt_sig  .asc "LOCI"

; mt_get : A = octet $80A de la configuration ; mt_put : X dans $80A
mt_get
        jsr mt_xa
        lda MIA_RW1
        rts
mt_put
        jsr mt_xa
        stx MIA_RW1
        rts

; mt_bit : A = bit du lecteur X (1, 2, 4... $10 pour la cassette)
mt_bit
.(
        lda #1
        cpx #0
        beq r
        stx lt0
l       asl
        dec lt0
        bne l
r       rts
.)

; mt_on : Z=0 si le lecteur X est monté (d'après le menu)
mt_on
        lda #X_MNT
        jsr mt_get
        sta lt1
        jsr mt_bit
        and lt1
        rts

; mt_nxa : fenêtre 1 sur le nom du lecteur X ($810D + 35 x X)
mt_nxa
.(
        lda #$0D
        cpx #0
        beq s
        stx lt0
l       clc
        adc #35
        dec lt0
        bne l
s       sta MIA_ADDR1
        lda #$81
        sta MIA_ADDR1+1
        lda #1
        sta MIA_STEP1
        rts
.)

; mt_rname : nom de l'image du lecteur X -> mt_nm (vide si aucun)
mt_rname
.(
        jsr mt_nxa
        ldy #0
l       lda MIA_RW1
        sta mt_nm,y
        beq e
        iny
        cpy #32
        bne l
        lda #0
        sta mt_nm,y
e       rts
.)

; mt_wname : mt_nm (32 caractères au plus) devient le nom du lecteur X
mt_wname
.(
        jsr mt_nxa
        ldy #0
l       lda mt_nm,y
        beq z
        sta MIA_RW1
        iny
        cpy #32
        bne l
z       lda #0                  ; complété de zéros (35 octets)
zl      sta MIA_RW1
        iny
        cpy #35
        bne zl
        rts
.)

; mt_lname : mt_nm = dernier élément d'apath (32 caractères au plus)
mt_lname
.(
        jsr lp_last
        ldy #0
l       lda apath,x
        sta mt_nm,y
        beq e
        inx
        iny
        cpy #32
        bne l
        lda #0
        sta mt_nm,y
e       rts
.)

; mt_cwd : répertoire de l'image du lecteur X (getcwd) -> mt_path,
;   longueur dans mt_len ; C=1 si erreur (mt_path vide)
mt_cwd
.(
        stx MIA_A
        lda #0
        sta mt_path
        sta mt_len
        lda #OP_GETCWD
        jsr mia_call
        bcs r
        sta mt_len
        tay
        beq e
        cmp #126
        bcc rd
        lda #0                  ; trop long : pile d'échange vidée
        sta MIA_OP
        sec
        rts
rd      ldy #0
l       lda MIA_XSTACK
        sta mt_path,y
        iny
        cpy mt_len
        bne l
e       lda #0
        sta mt_path,y
        clc
r       rts
.)

; mt_full : chemin complet de l'image du lecteur X -> mt_path (getcwd
;   puis le nom du menu) ; mt_nm = le nom seul
mt_full
.(
        stx mt_x
        jsr mt_rname
        ldx mt_x
        jsr mt_cwd
        ldx mt_len
        ldy #0
l       lda mt_nm,y
        sta mt_path,x
        beq e
        inx
        iny
        cpx #159
        bne l
        lda #0
        sta mt_path,x
e       ldx mt_x
        rts
.)

; mt_where : C=1 et X = lecteur (0-4, sauf mt_d) où l'image apath est
;   déjà montée ; C=0 sinon. Casse ignorée (clé FAT).
mt_where
.(
        ldx #0
lp      cpx mt_d
        beq nx
        stx mt_x
        jsr mt_on
        beq nx0
        ldx mt_x
        jsr mt_full
        ldy #0
cm      lda mt_path,y
        jsr lupc
        sta wm_c
        lda apath,y
        jsr lupc
        cmp wm_c
        bne nx0
        cmp #0
        beq hit
        iny
        bne cm
hit     ldx mt_x
        sec
        rts
nx0     ldx mt_x
nx      inx
        cpx #5
        bne lp
        clc
        rts
.)

; mt_head : 8 premiers octets du fichier apath -> iobuf ; C=1 si
;   illisible ou plus court
mt_head
.(
        lda #<apath
        ldy #>apath
        ldx #O_RDONLY
        jsr usb_open
        bcs r
        sta mt_fd
        jsr usb_read
        php
        sta mt_len
        lda mt_fd
        jsr usb_close
        plp
        bcs r
        lda mt_len
        cmp #8                  ; C=0 : au moins 8 octets
        rol                     ; C <- 1 si plus court
        eor #1
        lsr
r       rts
.)

; mt_isdsk : Z=1 si iobuf commence par « MFM_DISK »
mt_isdsk
.(
        ldx #7
l       lda iobuf,x
        cmp mt_mfm,x
        bne r
        dex
        bpl l
        lda #0
r       rts
.)
mt_mfm  .asc "MFM_DISK"

; mt_pre : avant de changer l'image d'un lecteur : écritures en attente
;   faites, lecteurs à relire, A: en service (un lecteur sans image ne
;   doit jamais recevoir de commande : le contrôleur du LOCI se
;   bloquerait) ; le lecteur courant est gardé dans mt_cur
mt_pre
        ldx #F_CURDSK
        jsr BDOS
        sta mt_cur
        ldx #F_RESET
        jsr BDOS
        lda #0
        ldx #F_SELDSK
        jmp BDOS

; mt_post : après : lecteurs à relire, lecteur courant rendu (A: si le
;   sien n'a plus d'image)
mt_post
        ldx #F_RESET
        jsr BDOS
        lda mt_cur
        ldx #F_SELDSK
        jmp BDOS

; mt_mount : monte apath dans le lecteur mt_d (configuration du menu
;   mise à jour : lecteur monté, nom ; cassette : tap_on, ald_on comme
;   le menu) -> C=1 si le LOCI refuse (message affiché)
mt_mount
.(
        lda apath               ; image de la mémoire interne : refusée
        cmp #"0"                ; (le firmware ne vérifie pas l'ouverture
        bne mm                  ; d'un fichier de 0: avant de le lire)
        lda #<m_lfs
        ldy #>m_lfs
        jsr lputs
        sec
        rts
mm      lda mt_d
        sta MIA_A
        lda #<apath
        ldy #>apath
        jsr push_str
        lda #OP_MOUNT
        jsr mia_call
        bcc ok
        jsr usb_err
        sec
        rts
ok      jsr mt_ok
        bcs r0
        jsr mt_lname
        ldx mt_d
        jsr mt_wname
        lda #X_MNT
        jsr mt_get
        sta lt1
        ldx mt_d
        jsr mt_bit
        ora lt1
        tax
        lda #X_MNT
        jsr mt_put
        lda mt_d
        cmp #4
        bne r0
        ldx #1
        lda #X_TAP
        jsr mt_put
        ldx #1
        lda #X_ALD
        jsr mt_put
r0      clc
        rts
.)

; mt_eject : éjecte le lecteur mt_d (configuration du menu mise à jour) ;
;   le lecteur courant éjecté : A: le sera (mt_post)
mt_eject
.(
        lda mt_d
        cmp mt_cur
        bne nc
        lda #0
        sta mt_cur
nc      lda mt_d
        sta MIA_A
        lda #OP_UMOUNT
        jsr mia_call
        jsr mt_ok
        bcs r
        lda #0
        sta mt_nm
        ldx mt_d
        jsr mt_wname
        lda #X_MNT
        jsr mt_get
        sta lt1
        ldx mt_d
        jsr mt_bit
        eor #$FF
        and lt1
        tax
        lda #X_MNT
        jsr mt_put
r       rts
.)

; mt_drv : lettre du lecteur X (0-3 : A-D) ou « K7 », suivie de « : » et
;   d'un espace
mt_drv
.(
        cpx #4
        beq k
        txa
        clc
        adc #"A"
        jsr lputc
        jmp c
k       lda #"K"
        jsr lputc
        lda #"7"
        jsr lputc
c       lda #":"
        jsr lputc
        lda #" "
        jmp lputc
.)

; Tampons : le programme les place après loci_inc.s (xa ne calcule pas
; une constante d'après une étiquette encore inconnue), par exemple :
;   mt_nm   = lib_free          ; nom d'une image (33)
;   mt_path = lib_free+33       ; chemin complet d'une image (160)
;   mt_d    = lib_free+193      ; lecteur visé (0-3, 4 cassette)
;   mt_x    = lib_free+194
;   mt_len  = lib_free+195
;   mt_fd   = lib_free+196
;   mt_cur  = lib_free+197      ; (198 octets en tout)
