; =====================================================================
;  REN.COM — renomme un fichier : REN nouveau=ancien
;
;  Comme sous CP/M 2.2 (REN B:LETTRE.BAK=LETTRE.TXT). Un lecteur donné
;  d'un seul côté vaut pour les deux. Refusé si le nouveau nom existe,
;  ou si le fichier est protégé (R/O). Autrefois commande interne du
;  CCP, passée en .COM pour libérer de la place dans le système.
; =====================================================================

#include "cpa.inc"

pp      = $10           ; 2 octets : nom à analyser
fp      = $12           ; 2 octets : FCB à remplir
t0      = $14
sptr    = $15           ; 2 octets

        *= $0500
start
.(
        ldx #31                 ; FCB : ancien nom en +0, nouveau en +16
        lda #0
z       sta fcb,x
        dex
        bpl z
        lda #<TAIL+1            ; nouveau nom
        sta pp
        lda #>TAIL+1
        sta pp+1
        lda #<newf
        sta fp
        lda #>newf
        sta fp+1
        jsr pname
        bcs usage
        lda (pp),y              ; puis « = »
        cmp #"="
        bne usage
        iny
        tya                     ; ancien nom, après le =
        clc
        adc pp
        sta pp
        bcc a1
        inc pp+1
a1      lda #<fcb
        sta fp
        lda #>fcb
        sta fp+1
        jsr pname
        bcs usage
        lda (pp),y              ; rien d'autre après
        beq lone
usage   lda #<m_use
        ldy #>m_use
        jmp puts
lone    lda fcb                 ; lecteurs : l'un vaut pour l'autre
        bne d1
        lda newf
        sta fcb
d1      lda newf
        bne d2
        lda fcb
        sta newf
d2      cmp fcb
        bne usage
        lda #<DEF_DMA           ; le nouveau nom existe-t-il ?
        ldy #>DEF_DMA
        ldx #F_SETDMA
        jsr BDOS
        lda #<newf
        ldy #>newf
        ldx #F_SFIRST
        jsr BDOS
        cmp #$FF
        beq go
        lda #<m_ex
        ldy #>m_ex
        jmp puts
go      lda #<fcb
        ldy #>fcb
        ldx #F_RENAME
        jsr BDOS
        cmp #$FE
        bne n1
        lda #<m_ro
        ldy #>m_ro
        jmp puts
n1      cmp #$FF
        bne r
        lda #<m_nf
        ldy #>m_nf
        jmp puts
r       rts
.)

; pname : nom en (pp) (espaces sautés ; fin : 0, espace ou =) -> FCB
;   (fp) : lecteur, nom, type ; Y = position après le nom (espaces
;   sautés). C=1 si vide, invalide ou avec un joker.
pname
.(
        ldy #11
        lda #" "
s       sta (fp),y
        dey
        bne s
        ldy #0
sk      lda (pp),y
        cmp #" "
        bne b
        iny
        bne sk
b       iny                     ; « B: » ?
        lda (pp),y
        dey
        cmp #":"
        bne nod
        lda (pp),y
        sec
        sbc #"A"-1
        beq bad
        cmp #5
        bcs bad
        sty t0
        ldy #0
        sta (fp),y
        ldy t0
        iny
        iny
nod     ldx #1                  ; position dans le FCB
n1      lda (pp),y
        jsr endc
        beq nend
        cmp #"."
        beq dot
        jsr okc
        bcs bad
        cpx #9
        bcs bad
        jsr put
        iny
        bne n1
dot     cpx #1
        beq bad
        ldx #9
        iny
e1      lda (pp),y
        jsr endc
        beq ok
        jsr okc
        bcs bad
        cpx #12
        bcs bad
        jsr put
        iny
        bne e1
nend    cpx #1
        beq bad
ok      lda (pp),y              ; espaces après le nom
        cmp #" "
        bne r
        iny
        bne ok
r       clc
        rts
bad     sec
        rts
put     sty t0                  ; (fp),X <- A
        pha
        txa
        tay
        pla
        sta (fp),y
        ldy t0
        inx
        rts
.)

; endc : Z=1 si A est la fin d'un nom (0, espace, =)
endc
.(
        cmp #0
        beq r
        cmp #" "
        beq r
        cmp #"="
r       rts
.)

; okc : C=1 si A n'est pas admis dans un nom (jokers compris)
okc
.(
        cmp #"!"
        bcc bad
        cmp #$7F
        bcs bad
        stx t0
        ldx #11
l       cmp badc,x
        beq bad2
        dex
        bpl l
        ldx t0
        clc
        rts
bad2    ldx t0
bad     sec
        rts
.)
badc    .asc "*?.,;:<>[]|/"

puts
.(
        sta sptr
        sty sptr+1
        ldy #0
l       lda (sptr),y
        beq r
        jsr B_CONOUT
        iny
        bne l
r       rts
.)

m_use   .asc "REN nouveau=ancien : renomme",13,10,0
m_ex    .asc "Le nouveau nom existe deja",13,10,0
m_ro    .asc "Fichier protege",13,10,0
m_nf    .asc "Fichier introuvable",13,10,0

fcb     .dsb 16,0       ; ancien nom (FCB de la fonction 23)
newf    .dsb 16,0       ; nouveau nom, en FCB+16
        .dsb 4,0
