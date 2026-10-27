; =====================================================================
;  ljok_inc.s — jokers dans les noms de la clé USB (docs/usb.md § 2.1) :
;  modèle comparé aux noms d'un répertoire, nom unique cherché. Inclus
;  par USBDIR et IMPORT avant loci.msg et loci_inc.s (dont il utilise
;  apath, dirent, les messages et les tampons) ; jamais assemblé seul.
; =====================================================================

; lp_last : X = début du dernier élément d'apath (après le dernier
;   « / ») ; C=1 s'il contient un joker (* ou ?)
lp_last
.(
        ldy #0
        ldx #0
ylp      lda apath,y
        beq ye
        iny
        cmp #"/"
        bne ylp
        tya
        tax
        bne ylp
ye       stx lt0
yw       lda apath,x
        beq yno
        inx
        cmp #"*"
        beq yy
        cmp #"?"
        bne yw
yy       sec
        ldx lt0
        rts
yno      clc
        ldx lt0
        rts
.)

; lp_cut : apath coupé avant son dernier élément (début X, de lp_last)
;   pour ouvrir le répertoire : le caractère enlevé est gardé (lp_sv,
;   lp_sx) et lp_back le remet
lp_cut
.(
        cpx lt2
        bne ynr
        inx                     ; racine : « 2:/ » gardé
ynr      dex
        stx lp_sx
        lda apath,x
        sta lp_sv
        lda #0
        sta apath,x
        rts
.)
lp_back
        ldx lp_sx
        lda lp_sv
        sta apath,x
        rts

; wmatch : Z=1 si le nom dirent+2 répond au modèle apath,X (jokers * et
;   ?, casse ignorée ; « .* » final accepte aussi un nom sans point)
wmatch
.(
        stx wm_p0
        lda #$FF
        sta wm_st
        ldy #0
ylp      lda dirent+2,y
        beq yse
        lda apath,x
        cmp #"*"
        bne ynst
        inx
        stx wm_st
        sty wm_mk
        jmp ylp
ynst     cmp #"?"
        beq yadv
        jsr lupc
        sta wm_c
        lda dirent+2,y
        jsr lupc
        cmp wm_c
        bne yback
yadv     inx
        iny
        bne ylp
yback    lda wm_st
        bmi yno
        tax
        inc wm_mk
        ldy wm_mk
        jmp ylp
yse      lda apath,x             ; fin du nom : reste « * », « . »
        beq yyes
        cmp #"*"
        beq ys1
        cmp #"."
        bne yno
ys1      inx
        bne yse
yyes     ldx wm_p0
        lda #0
        rts
yno      ldx wm_p0
        lda #1
        rts
.)

; lupc : A en majuscule
lupc
        cmp #"a"
        bcc lu_r
        cmp #"z"+1
        bcs lu_r
        and #$DF
lu_r    rts

; lp_find : le dernier élément d'apath a des jokers : il est remplacé
;   par le seul fichier qui y répond. Aucun : « Introuvable : X » ;
;   plusieurs : leurs noms (8 au plus), « Plusieurs fichiers : preciser ».
;   C=1 sauf pour un seul fichier.
lp_find
.(
        jsr lp_last
        bcs yfw
        rts                     ; sans joker : rien à chercher (C=0)
yfw      stx lp_p
        jsr lp_cut
        lda #<apath
        ldy #>apath
        jsr usb_opendir
        php
        sta lp_fd
        jsr lp_back
        plp
        bcc yop
        jsr usb_err
        sec
        rts
yop      lda #0
        sta lp_n
yrd      lda lp_fd
        jsr usb_readdir
        bcs ycl
        lda dirent+2
        beq ycl
        cmp #"."
        beq yrd
        lda dirent+66
        and #$16                ; répertoire, caché, système
        bne yrd
        ldx lp_p
        jsr wmatch
        bne yrd
        inc lp_n
        lda lp_n
        cmp #1
        bne ymore
        ldx #0                  ; premier : gardé
yc1      lda dirent+2,x
        sta lp_nm,x
        inx
        cpx #64
        bne yc1
        beq yrd
ymore    cmp #2
        bne ym3
        lda #<lp_nm
        ldy #>lp_nm
        jsr lputs
        jsr lcrlf
ym3      lda lp_n
        cmp #9
        bcs ydots
        lda #<dirent+2
        ldy #>dirent+2
        jsr lputs
        jsr lcrlf
        jmp yrd
ydots    bne yrd
        lda #<m_dots
        ldy #>m_dots
        jsr lputs
        jmp yrd
ycl      lda lp_fd
        jsr usb_closedir
        lda lp_n
        beq ynone
        cmp #1
        bne ymany
        ldx lp_p                ; le nom trouvé remplace le modèle
        ldy #0
yc2      lda lp_nm,y
        sta apath,x
        beq yone
        inx
        iny
        cpx #127
        bne yc2
        lda #<m_long
        ldy #>m_long
        jsr lputs
        sec
        rts
yone     clc
        rts
ynone    lda #<m_nfw
        ldy #>m_nfw
        jsr lputs
        ldx lp_p
ynf      lda apath,x
        beq ynfe
        jsr lputc
        inx
        bne ynf
ynfe     jsr lcrlf
        sec
        rts
ymany    lda #<m_many
        ldy #>m_many
        jsr lputs
        sec
        rts
.)

