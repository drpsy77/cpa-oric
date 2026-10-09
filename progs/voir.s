; =====================================================================
;  VOIR.COM — affiche une image, puis revient au texte à la première
;  touche
;
;  VOIR NOM[.HIR]   image plein écran (240 x 200, 8 000 octets bruts)
;  VOIR NOM.IMG     image du mode SPLIT (GSAVE, 240 x 128)
;  Le nom peut commencer par un lecteur (B:TITRE).
; =====================================================================

#include "cpa.inc"

        *= $0500

        lda FCB1+1
        cmp #" "
        bne v_arg
        ldx #F_PRINT
        lda #<m_use
        ldy #>m_use
        jmp BDOS
v_arg   ldx #11                 ; nom du paramètre
v_cp    lda FCB1,x
        sta fcb,x
        dex
        bpl v_cp
        lda fcb+9               ; type : HIR par défaut
        cmp #" "
        bne v_typ
        ldx #2
v_dt    lda t_hir,x
        sta fcb+9,x
        dex
        bpl v_dt
v_typ   ldx #F_OPEN             ; absent : on reste en mode texte
        lda #<fcb
        ldy #>fcb
        jsr BDOS
        cmp #$FF
        beq v_nf2
        ldx #2                  ; .IMG : image du mode SPLIT
v_ti    lda fcb+9,x
        cmp t_img,x
        bne v_full
        dex
        bpl v_ti
        jsr h_split
        jmp v_load
v_full  jsr h_full
v_load  lda #<fcb
        ldy #>fcb
        jsr h_load
        cmp #0
        bne v_nf
        jsr h_key
        jmp h_text
v_nf    jsr h_text
v_nf2   ldx #F_PRINT
        lda #<m_nf
        ldy #>m_nf
        jmp BDOS

t_hir   .asc "HIR"
t_img   .asc "IMG"
m_use   .asc "VOIR NOM[.HIR|.IMG] : affiche une",13,10
        .asc "image, une touche pour revenir.",13,10,"$"
m_nf    .asc "Fichier introuvable",13,10,"$"
fcb     .dsb 36,0

#include "hires.inc"
