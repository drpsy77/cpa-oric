; =====================================================================
;  USBMOUNT.COM — monte une image de la clé USB du LOCI (docs/usb.md)
;
;  USBMOUNT               ce qui est monté (A: à D:, K7:)
;  USBMOUNT B:            chemin complet de l'image de B: (K7: : la cassette)
;  USBMOUNT B: JEU.DSK    monte JEU.DSK en B: (C:, D:) ; JE*.DSK : le seul
;                         qui répond
;  USBMOUNT B: /E         éjecte (K7: /E : la cassette)
;  USBMOUNT JEU.TAP [/B]  monte la cassette ; /B : puis démarre le BASIC 1.1
;                         du LOCI, cassette en service, chargement
;                         automatique (CP/A est quitté sans question)
;  Noms relatifs au répertoire courant de CP/A (docs/usb.md § 1.1).
;  Refusés : A: (disquette système), une image déjà montée dans un autre
;  lecteur, un fichier qui n'est pas une image de disquette (signature
;  MFM_DISK) ou de cassette (octet $16). Les noms affichés sont ceux de
;  la configuration du menu du LOCI, que USBMOUNT tient à jour comme lui.
; =====================================================================

#include "cpa.inc"

; ne crée aucun fichier : sans le détour de usb_open ni cw_put (loci_inc.s)
#define LOCI_SANS_CREATION

w1      = $10           ; position des mots dans args ($FF : absent)
w2      = $11
oe      = $12           ; 1 = /E
ob      = $13           ; 1 = /B
ii      = $14

VIA_IER = $030E

        *= $0500
start
.(
        jsr get_args
        lda #$FF
        sta w1
        sta w2
        lda #0
        sta oe
        sta ob
        ldx #0
wd      jsr skipsp
        lda args,x
        beq parsed
        cmp #"/"
        bne nm
        lda args+2,x
        beq o1
        cmp #" "
        bne usage
o1      lda args+1,x
        and #$DF
        cmp #"E"
        bne o2
        inc oe
        bne nx
o2      cmp #"B"
        bne usage
        inc ob
        bne nx
nm      lda w1
        cmp #$FF
        bne n2
        stx w1
        beq nx
n2      lda w2
        cmp #$FF
        bne usage
        stx w2
nx      jsr skipw
        jmp wd
usage   lda #<m_use
        ldy #>m_use
        jmp lputs

parsed  jsr mia_chk
        bcc lk
        rts
lk      jsr cw_get
        ldx w1
        cpx #$FF
        bne hw
        jmp list
hw      jsr drvw
        sta mt_d
        cmp #$FF
        bne isd
        lda oe                  ; un nom seul : la cassette
        bne usage
        ldx w1
        lda #<FCB1
        ldy #>FCB1
        jmp tape
isd     lda oe
        beq ne
        lda mt_d
        beq sysa
        jmp eject
ne      ldx w2
        cpx #$FF
        bne mn
        jmp show
mn      lda mt_d
        beq sysa
        cmp #4
        bne dsk
        lda #<FCB2
        ldy #>FCB2
        jmp tape
dsk     jmp mountd
sysa    lda #<m_sysa
        ldy #>m_sysa
        jmp lputs
.)

; drvw : le mot args,X est-il un lecteur ? A = 0-3 (A: à D:), 4 (K7:),
;   $FF sinon
drvw
.(
        lda args,x
        and #$DF
        cmp #"K"
        beq k7
        sec
        sbc #"A"
        cmp #4
        bcs no
        sta ii
        lda args+1,x
        cmp #":"
        bne no
        lda args+2,x
        jsr endw
        bne no
        lda ii
        rts
k7      lda args+1,x
        cmp #"7"
        bne no
        lda args+2,x
        cmp #":"
        bne no
        lda args+3,x
        jsr endw
        bne no
        lda #4
        rts
no      lda #$FF
        rts
.)

; endw : Z=1 si A finit un mot (0 ou espace)
endw
        cmp #0
        beq ew
        cmp #" "
ew      rts

; list : USBMOUNT seul
list
.(
        jsr mt_ok
        bcs noc
        ldx #0
lp      stx ii
        jsr pdrv
        ldx ii
        inx
        cpx #5
        bne lp
        rts
noc     lda #<m_nocfg
        ldy #>m_nocfg
        jmp lputs
.)

; pdrv : « B: nom » (« B: - » sans image) du lecteur X
pdrv
.(
        stx mt_x
        jsr mt_drv
        ldx mt_x
        jsr mt_on
        beq no
        ldx mt_x
        jsr mt_rname
        lda mt_nm
        beq no
        lda #<mt_nm
        ldy #>mt_nm
        jsr lputs
        jmp lcrlf
no      lda #"-"
        jsr lputc
        jmp lcrlf
.)

; show : USBMOUNT B: : chemin complet de l'image
show
.(
        ldx mt_d
        jsr mt_on
        bne on
        ldx mt_d
        jmp pdrv
on      ldx mt_d
        jsr mt_drv
        ldx mt_d
        jsr mt_full
        lda #<mt_path
        ldy #>mt_path
        jsr lputs
        jmp lcrlf
.)

; mountd : USBMOUNT B: nom (mot w2)
mountd
.(
        ldx w2
        jsr lpath_a
        bcs rt
        jsr lp_findx
        bcs rt
        jsr mt_head
        bcs nd
        jsr mt_isdsk
        bne nd
        jsr mt_where
        bcs twice
        jsr mt_pre
        jsr mt_mount
        php
        jsr mt_post
        plp
        bcs rt
        jmp mdone
nd      lda #<m_notdsk
        ldy #>m_notdsk
        jmp lputs
twice   jmp ptwice
rt      rts
.)

; mdone : « B: nom » du lecteur mt_d (nom pris dans apath)
mdone
        ldx mt_d
        jsr mt_drv
        jsr mt_lname
        lda #<mt_nm
        ldy #>mt_nm
        jsr lputs
        jmp lcrlf

; ptwice : « Deja montee en C: » (lecteur X)
ptwice
        stx ii
        lda #<m_twice
        ldy #>m_twice
        jsr lputs
        ldx ii
        jsr mt_drv
        jmp lcrlf

; eject : USBMOUNT B: /E
eject
.(
        lda mt_d
        cmp #4
        beq k7
        jsr mt_pre
        jsr mt_eject
        jsr mt_post
        jmp ok
k7      jsr mt_eject
ok      ldx mt_d
        jmp pdrv
.)

; tape : USBMOUNT nom [/B] (mot args,X ; A/Y = son FCB, pour savoir s'il
;   est sur une disquette de CP/A)
tape
.(
        sta lptr
        sty lptr+1
        ldy #35                 ; FCB recopié (recherche sur la disquette)
z       lda #0
        cpy #12
        bcs zz
        lda (lptr),y
zz      sta fcb,y
        dey
        bpl z
        lda #4
        sta mt_d
        jsr lpath_a
        bcs rt
        jsr lp_last             ; une image de disquette : il faut un lecteur
        jsr isdskn
        bne nt
        lda #<m_drvq
        ldy #>m_drvq
        jmp lputs
nt      jsr lp_findx
        bcc fd
        lda #<fcb               ; sur une disquette de CP/A ?
        ldy #>fcb
        ldx #F_SFIRST
        jsr BDOS
        cmp #$FF
        beq rt
        lda #<m_exp
        ldy #>m_exp
        jsr lputs
        jsr lp_last
pe      lda apath,x
        beq pee
        jsr lputc
        inx
        bne pe
pee     jmp lcrlf
fd      jsr mt_head
        bcs ntp
        lda iobuf
        cmp #$16
        bne ntp
        jsr mt_where
        bcs tw
        jsr mt_mount
        bcs rt
        jsr mdone
        lda ob
        beq rt
        jmp boot
ntp     lda #<m_nottap
        ldy #>m_nottap
        jmp lputs
tw      jmp ptwice
rt      rts
.)

; isdskn : Z=1 si le dernier élément d'apath (début X) finit par .DSK
isdskn
.(
        ldy #0
l       lda apath,x
        beq e
        inx
        iny
        bne l
e       cpy #4
        bcc no
        ldy #0
c       lda apath-4,x
        jsr lupc
        cmp m_dske,y
        bne r
        inx
        iny
        cpy #4
        bne c
        lda #0
r       rts
no      lda #1
        rts
.)
m_dske  .asc ".DSK"

; boot : /B : configuration du menu (BASIC 1.1, cassette en service,
;   chargement automatique, sans le contrôleur de disquettes : les
;   disquettes restent montées), puis démarrage par le LOCI. Ne revient
;   que si le LOCI refuse.
boot
.(
        ldx #F_RESET            ; écritures en attente faites
        jsr BDOS
        jsr mt_ok
        bcc cf
        lda #0
        beq fl
cf      ldx #0
        lda #X_FDC
        jsr mt_put
        ldx #1                  ; (tap_on, ald_on : posés par le montage)
        lda #X_B11
        jsr mt_put
        lda #X_BIT              ; mode bit à bit du menu gardé
        jsr mt_get
        and #1
fl      asl
        asl
        asl
        ora #$80+$10+$04+$02    ; rapide, chargement auto., BASIC 1.1, cassette
        sta MIA_A
        lda #0
        sta MIA_A+2             ; X
        lda VIA_IER
        sta ii
        sei
        lda #$7F                ; interruptions du VIA coupées (comme le menu)
        sta VIA_IER
        lda #OP_BOOT
        jsr mia_call
        lda ii                  ; refusé : on reste dans CP/A
        ora #$80
        sta VIA_IER
        cli
        jmp usb_err
.)

#include "usbmount.msg"

#include "lmnt_inc.s"
#include "ljok_inc.s"
#include "loci.msg"         ; avant loci_inc.s, dont les tampons suivent la fin
#include "loci_inc.s"

; tampons de lmnt_inc.s, puis du programme
mt_nm   = lib_free          ; nom d'une image (33)
mt_path = lib_free+33       ; chemin complet d'une image (160)
mt_d    = lib_free+193      ; lecteur visé (0-3, 4 cassette)
mt_x    = lib_free+194
mt_len  = lib_free+195
mt_fd   = lib_free+196
mt_cur  = lib_free+197
fcb     = lib_free+198      ; FCB d'un nom de CP/A (36)
