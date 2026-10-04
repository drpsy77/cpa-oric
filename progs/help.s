; =====================================================================
;  HELP.COM — aide de CP/A
;
;  HELP          commandes internes et liste des sujets
;  HELP sujet    TOUCHES PROGRAMMES EDIT HEX LOGO ASM DEBUG MEMOIRE
;                (les premières lettres suffisent)
;  Les textes viennent de tools/gen_readme_txt.py (help_tab.s), comme
;  README.TXT.
; =====================================================================

#include "cpa.inc"

ptr     = $10
key     = $12
wlen    = $14
idx     = $15

        *= $0500
start
.(
        ldx #0                  ; longueur du mot (nom de FCB1)
len     lda FCB1+1,x
        cmp #" "
        beq lend
        inx
        cpx #8
        bne len
lend    stx wlen
        lda #0
        sta idx
        cpx #0
        beq show                ; pas de sujet : texte par défaut
        lda #<help_keys
        sta key
        lda #>help_keys
        sta key+1
next    inc idx
        ldy #0
        lda (key),y
        beq unknown             ; fin de la table
cmp1    lda (key),y             ; compare jusqu'à la fin de la clé ou du mot
        beq found
        cpy wlen
        beq found
        cmp FCB1+1,y
        bne skip
        iny
        bne cmp1
skip    ldy #0                  ; clé suivante
sk      lda (key),y
        beq sk2
        iny
        bne sk
sk2     iny
        tya
        clc
        adc key
        sta key
        bcc next
        inc key+1
        bne next
unknown lda #<m_unknown
        ldy #>m_unknown
        jsr puts
        lda #0
        sta idx
show    lda idx
        asl
        tax
        lda help_ptrs,x
        ldy help_ptrs+1,x
        jsr puts
        rts
found   jmp show
.)

puts
.(
        sta ptr
        sty ptr+1
loop    ldy #0
        lda (ptr),y
        beq done
        ldx #F_CONOUT
        jsr BDOS
        inc ptr
        bne loop
        inc ptr+1
        bne loop
done    rts
.)

m_unknown .asc "Sujet inconnu.",13,10,13,10,0

#include "help_tab.s"
