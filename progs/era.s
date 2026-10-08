; =====================================================================
;  ERA.COM — efface des fichiers, après confirmation
;
;  ERA afn [/Q]
;    montre les fichiers qui vont être effacés, puis demande
;    « Effacer n fichier(s) (O/N) ? » ; les fichiers protégés (R/O)
;    sont gardés et seulement comptés
;    /Q  sans question (pour un script)
;
;  Autrefois commande interne du CCP (qui ne demandait rien, sauf pour
;  *.*), passée en .COM : place libérée dans le système, et une
;  confirmation contre les effacements par erreur (nom complété par ESC).
; =====================================================================

#include "cpa.inc"

MAXF    = 128

ptr     = $10           ; 2 octets
cnt     = $12           ; fichiers à effacer
nro     = $13           ; fichiers protégés
i       = $14
col     = $15
quiet   = $16
sptr    = $17           ; 2 octets
pch     = $19

        *= $0500
start
.(
        lda FCB1+1
        cmp #" "
        bne s1
usage   lda #<m_use
        ldy #>m_use
        jmp puts
s1      lda #0                  ; /Q quelque part dans la ligne ?
        sta quiet
        ldx #0
q       lda TAIL+1,x
        beq q2
        cmp #"/"
        bne qn
        lda TAIL+2,x
        cmp #"Q"
        bne usage
        inc quiet
qn      inx
        bne q
q2
        ldx #11                 ; recherche : premier extent de chaque
cp      lda FCB1,x              ; fichier
        sta fcb,x
        dex
        bpl cp
        lda #0
        sta fcb+12
        sta cnt
        sta nro
        lda #<DEF_DMA
        ldy #>DEF_DMA
        ldx #F_SETDMA
        jsr BDOS
        lda #<fcb
        ldy #>fcb
        ldx #F_SFIRST
        jsr BDOS
sl      cmp #$FF
        beq listed
        lda DEF_DMA+9           ; R/O : gardé, seulement compté
        bpl keep
        inc nro
        bne nx
keep    lda cnt
        cmp #MAXF
        bcs nx
        jsr nptr
        ldy #1
c2      lda DEF_DMA,y
        and #$7F
        dey
        sta (ptr),y
        iny
        iny
        cpy #12
        bne c2
        inc cnt
nx      ldx #F_SNEXT
        jsr BDOS
        jmp sl
listed  lda cnt
        ora nro
        bne some
        lda #<m_nf
        ldy #>m_nf
        jmp puts
some    lda cnt
        bne any
        jmp ro_only
any     lda quiet
        bne del
        lda #0                  ; liste, 3 noms par ligne comme DIR
        sta i
        sta col
ln      lda i
        jsr nptr
        ldy #0
n8      lda (ptr),y
        jsr putc
        iny
        cpy #8
        bne n8
        lda #"."
        jsr putc
n3      lda (ptr),y
        jsr putc
        iny
        cpy #11
        bne n3
        inc col
        lda col
        cmp #3
        beq nl                  ; 3e colonne : retour à la ligne de lui-même
        lda #" "
        jsr putc
        jmp nn
nl      lda #0
        sta col
nn      inc i
        lda i
        cmp cnt
        bne ln
        lda col
        beq nocr
        jsr crlf
nocr    jsr pro                 ; « 2 protege(s), garde(s) »
        lda #<m_ask1
        ldy #>m_ask1
        jsr puts
        lda cnt
        jsr pnum8
        lda #<m_ask2
        ldy #>m_ask2
        jsr puts
        jsr B_CONIN
        and #$DF
        pha
        cmp #" "
        bcc noecho
        jsr putc
noecho  jsr crlf
        pla
        cmp #"O"
        beq del
        lda #<m_abort
        ldy #>m_abort
        jmp puts
del     lda #<FCB1              ; jokers admis ; les protégés restent
        ldy #>FCB1
        ldx #F_DELETE
        jsr BDOS
        lda cnt
        jsr pnum8
        lda #<m_done
        ldy #>m_done
        jsr puts
        lda quiet
        beq r
        jmp pro
r       rts
ro_only jsr pro
        lda #<m_none
        ldy #>m_none
        jmp puts
.)

; pro : « n protege(s), garde(s) » s'il y en a
pro
.(
        lda nro
        beq r
        jsr pnum8
        lda #<m_ro
        ldy #>m_ro
        jmp puts
r       rts
.)

; nptr : ptr <- liste + 11 x A
nptr
.(
        tax
        lda #<list
        sta ptr
        lda #>list
        sta ptr+1
        cpx #0
        beq r
l       lda ptr
        clc
        adc #11
        sta ptr
        bcc n
        inc ptr+1
n       dex
        bne l
r       rts
.)

; pnum8 : A (0-255) en décimal
pnum8
.(
        ldx #0
        stx pch
        ldy #2
d       ldx #0
s       cmp p10,y
        bcc o
        sbc p10,y
        inx
        bne s
o       pha
        txa
        bne pr
        lda pch
        bne pr
        cpy #0
        bne nx
pr      txa
        ora #"0"
        jsr putc
        inc pch
nx      pla
        dey
        bpl d
        rts
.)
p10     .byt 1,10,100

putc    jmp B_CONOUT
crlf    lda #13
        jsr putc
        lda #10
        jmp putc
puts
.(
        sta sptr
        sty sptr+1
        ldy #0
l       lda (sptr),y
        beq r
        jsr putc
        iny
        bne l
r       rts
.)

m_use   .asc "ERA afn [/Q] : efface (jokers admis)",13,10
        .asc "apres confirmation ; /Q sans question",13,10,0
m_nf    .asc "Fichier introuvable",13,10,0
m_ro    .asc " protege(s), garde(s)",13,10,0
m_none  .asc "Rien a effacer",13,10,0
m_ask1  .asc "Effacer ",0
m_ask2  .asc " fichier(s) (O/N) ? ",0
m_abort .asc "Abandon",13,10,0
m_done  .asc " fichier(s) efface(s)",13,10,0

fcb     .dsb 36,0
list                            ; noms (11 octets chacun)
