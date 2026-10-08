; =====================================================================
;  TYPE.COM — affiche un fichier texte (TYPE fic)
;
;  Autrefois commande interne du CCP, passée en .COM pour libérer de la
;  place dans le système (piste J de la revue de place). Même conduite :
;  arrêt au ^Z, une touche interrompt, pause en fin d'écran (console).
; =====================================================================

#include "cpa.inc"

FIRST_COL = 2           ; première colonne de l'écran texte

        *= $0500
start
.(
        lda FCB1+1              ; un nom, sans jokers
        cmp #" "
        beq usage
        ldy #11
w       lda FCB1,y
        cmp #"?"
        beq usage
        dey
        bne w
        lda #<DEF_DMA
        ldy #>DEF_DMA
        ldx #F_SETDMA
        jsr BDOS
        lda #<FCB1
        ldy #>FCB1
        ldx #F_OPEN
        jsr BDOS
        cmp #$FF
        bne rec
        lda #<m_nf
        ldy #>m_nf
        jmp puts
rec     lda #<FCB1
        ldy #>FCB1
        ldx #F_READ
        jsr BDOS
        cmp #0
        bne end
        ldy #0
ch      lda DEF_DMA,y
        cmp #$1A                ; ^Z : fin du texte
        beq end
        jsr B_CONOUT
        iny
        bpl ch
        jsr B_CONST             ; une touche interrompt l'affichage
        cmp #0
        beq rec
        jsr B_CONIN
end     lda CON_CURX            ; retour à la ligne s'il le faut
        cmp #FIRST_COL
        beq r
        lda #13
        jsr B_CONOUT
        lda #10
        jmp B_CONOUT
r       rts
usage   lda #<m_use
        ldy #>m_use
.)
puts
.(
        sta $10
        sty $11
        ldy #0
l       lda ($10),y
        beq r
        jsr B_CONOUT
        iny
        bne l
r       rts
.)

m_use   .asc "TYPE fic : affiche un texte",13,10,0
m_nf    .asc "Fichier introuvable",13,10,0
