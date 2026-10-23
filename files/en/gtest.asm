; GTEST.COM - test of the SPLIT mode and of the drawing functions
; Switches to SPLIT mode, draws in the picture, then returns
; (the picture stays on display above the prompt).
#include "cpa.inc"

        *= $0500
        ldx #0
loop    lda script,x            ; each command: 6 bytes
        cmp #$FF
        beq done
        txa
        pha
        clc                     ; A/Y = address of the command
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
        .byt G_MODE, 1, 0, 0, 0, 0              ; SPLIT mode, picture cleared
        .byt G_PEN, 1, 0, 0, 0, 0
        .byt G_BOX, 6, 1, 239, 127, 0           ; frame
        .byt G_LINE, 6, 1, 239, 127, 0          ; diagonals
        .byt G_LINE, 239, 1, 6, 127, 0
        .byt G_CIRCLE, 120, 64, 50, 0, 0        ; concentric circles
        .byt G_CIRCLE, 120, 64, 35, 0, 0
        .byt G_CIRCLE, 120, 64, 20, 0, 0
        .byt G_FBOX, 20, 10, 60, 30, 0          ; filled rectangle
        .byt G_PEN, 2, 0, 0, 0, 0               ; inverting
        .byt G_FBOX, 40, 20, 80, 40, 0          ; overlap, inverted
        .byt G_PEN, 1, 0, 0, 0, 0
        .byt G_TEXT, 26, 112, <title, >title, 0 ; text in the picture
        .byt G_ATTR, 30, 50, 80, 1, 0           ; red ink on the right
        .byt $FF

title   .asc "CP/A SPLIT",0
msg     .asc "Picture drawn.",13,10,"$"
