; =====================================================================
;  lcwp_inc.s — cw_put : changer le répertoire courant de CP/A sur la
;  clé USB (docs/usb.md § 2.1). À part de loci_inc.s, pour que les
;  programmes qui ne changent pas de répertoire (EXPORT, IMPORT,
;  USBMOUNT) ne le portent pas. Inclus par USBDIR et CMDER, avec
;  loci_inc.s (cwd, cwdesc, dv_open, dv_next, dv_close, cw_write).
; =====================================================================

; cw_put : le chemin A/Y (complet) devient le répertoire courant :
;   cwd, description du support, fichier 0:CPA.CWD (rien n'est écrit si
;   le répertoire ne change pas) ; C=1 si l'écriture échoue
cw_put
.(
        sta lptr
        sty lptr+1
        ldy #0
ycq      lda (lptr),y
        cmp cwd,y
        bne ydif
        iny
        cmp #0
        bne ycq
        clc                     ; inchangé : rien à écrire
        rts
ydif     ldy #0
ycp      lda (lptr),y
        sta cwd,y
        beq ycd
        iny
        cpy #127
        bne ycp
        lda #0
        sta cwd,y
ycd      lda #0
        sta cwdesc
        jsr dv_open
        bcs ywr
ysc      jsr dv_next
        bcs yscd
        ora #"0"
        cmp cwd
        bne ysc
        ldx #0
ydc      lda dirent+5,x
        sta cwdesc,x
        beq yscd
        inx
        cpx #63
        bne ydc
        lda #0
        sta cwdesc,x
yscd     jsr dv_close
ywr      jmp cw_write
.)

