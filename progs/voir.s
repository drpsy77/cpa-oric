; =====================================================================
;  VOIR.COM — affiche une image ou joue une animation, puis revient au
;  texte à la première touche
;
;  VOIR NOM[.HIR]   image plein écran (240 x 200, 8 000 octets bruts)
;  VOIR NOM.HIZ     image plein écran compressée (tools/png2hir.py --hiz)
;  VOIR NOM.IMG     image du mode SPLIT (GSAVE, 240 x 128)
;  VOIR NOM.ANI [n] animation (tools/mkanim.py), jouée n fois (0 ou
;                   rien : jusqu'à une touche) ; flèches gauche/droite :
;                   déplacer la ligne de déchirure
;  Le nom peut commencer par un lecteur (B:TITRE).
; =====================================================================

#include "cpa.inc"

v_s     = $10           ; chaîne à afficher (page zéro)

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
        ldx #2                  ; .ANI : animation
v_ta    lda fcb+9,x
        cmp t_ani,x
        bne v_ti0
        dex
        bpl v_ta
        jmp v_anim
v_ti0   ldx #2                  ; .IMG : image du mode SPLIT
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
        bne v_err
        jsr h_key
        jmp h_text
v_err   cmp #3
        bne v_nf
        jsr h_text
        lda #<m_big
        ldy #>m_big
        jmp v_puts
v_nf    jsr h_text
v_nf2   ldx #F_PRINT
        lda #<m_nf
        ldy #>m_nf
        jmp BDOS

; animation : passages = 2e paramètre (nombre, 0 par défaut)
v_anim
.(
        lda #0
        sta v_n
        ldx #1
dg      lda FCB2,x
        cmp #"0"
        bcc go
        cmp #"9"+1
        bcs go
        and #$0F
        sta v_d
        lda v_n                 ; n = 10 n + chiffre
        asl
        sta v_t
        asl
        asl
        clc
        adc v_t
        clc
        adc v_d
        sta v_n
        inx
        cpx #9
        bne dg
go      jsr h_full
        lda #<fcb
        ldy #>fcb
        ldx v_n
        jsr a_play
        bcs er
        cmp #0
        bne tx                  ; arrêtée par une touche
        jsr h_key               ; passages finis : la dernière image reste
tx      jmp h_text
er      pha
        jsr h_text
        pla
        jsr a_msg
.)
; v_puts : chaîne A/Y (terminée par 0), puis retour à la ligne
v_puts
.(
        sta v_s
        sty v_s+1
l       ldy #0
        lda (v_s),y
        beq e
        ldx #F_CONOUT
        jsr BDOS
        inc v_s
        bne l
        inc v_s+1
        bne l
e       ldx #F_PRINT
        lda #<m_crlf
        ldy #>m_crlf
        jmp BDOS
.)

; a_fail : demandée par anim.inc (pour GRAPHER /A seulement)
a_fail  jmp v_puts

t_hir   .asc "HIR"
t_img   .asc "IMG"
t_ani   .asc "ANI"
m_use   .asc "VOIR NOM[.HIR|.HIZ|.IMG] : affiche",13,10
        .asc "une image, une touche pour revenir.",13,10
        .asc "VOIR NOM.ANI [n] : joue l'animation",13,10
        .asc "n fois (0 : jusqu'a une touche).",13,10,"$"
m_nf    .asc "Fichier introuvable",13,10,"$"
m_crlf  .asc 13,10,"$"
m_big   .asc "Image trop grande",0
v_n     .byt 0
v_d     .byt 0
v_t     .byt 0
fcb     .dsb 36,0

#include "anim.inc"
#include "hires.inc"
