; GTEST.COM — test du mode SPLIT et des primitives graphiques
; Passe en mode SPLIT, dessine dans l'image puis rend la main
; (l'image reste affichée au-dessus du prompt).
#include "cpa.inc"

        *= $0500
        ldx #0
loop    lda script,x            ; chaque commande : 6 octets
        cmp #$FF
        beq done
        txa
        pha
        clc                     ; A/Y = adresse de la commande
        adc #<script
        pha
        lda #>script
        adc #0
        tay
        pla
        ldx #F_GFX
        jsr BDOS
        pla
        clc
        adc #6
        tax
        bne loop
done    ldx #F_PRINT
        lda #<msg
        ldy #>msg
        jmp BDOS

script
        .byt G_MODE, 1, 0, 0, 0, 0              ; mode SPLIT, image effacée
        .byt G_PEN, 1, 0, 0, 0, 0
        .byt G_BOX, 6, 1, 239, 127, 0           ; cadre
        .byt G_LINE, 6, 1, 239, 127, 0          ; diagonales
        .byt G_LINE, 239, 1, 6, 127, 0
        .byt G_CIRCLE, 120, 64, 50, 0, 0        ; cercles concentriques
        .byt G_CIRCLE, 120, 64, 35, 0, 0
        .byt G_CIRCLE, 120, 64, 20, 0, 0
        .byt G_FBOX, 20, 10, 60, 30, 0          ; rectangle plein
        .byt G_PEN, 2, 0, 0, 0, 0               ; inversion
        .byt G_FBOX, 40, 20, 80, 40, 0          ; recouvrement en inverse
        .byt G_PEN, 1, 0, 0, 0, 0
        .byt G_TEXT, 26, 112, <title, >title, 0 ; texte dans l'image
        .byt G_ATTR, 30, 50, 80, 1, 0           ; encre rouge à droite
        .byt $FF

title   .asc "CP/A SPLIT",0
msg     .asc "Image dessinee.",13,10,"$"
